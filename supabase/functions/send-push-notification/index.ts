// supabase/functions/send-push-notification/index.ts
// Edge Function: Dispatches push notifications via Firebase Cloud Messaging HTTP v1 API
//                using a Firebase Service Account JSON stored in FIREBASE_SERVICE_ACCOUNT.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

interface ServiceAccount {
  project_id: string;
  private_key: string;
  client_email: string;
}

function base64UrlEncode(data: Uint8Array | string): string {
  const bytes = typeof data === "string" ? new TextEncoder().encode(data) : data;
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const cleaned = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binary = atob(cleaned);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

async function getFcmAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claimSet = base64UrlEncode(
    JSON.stringify({
      iss: sa.client_email,
      sub: sa.client_email,
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
    })
  );

  const signingInput = `${header}.${claimSet}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(sa.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(signingInput)
  );

  const jwt = `${signingInput}.${base64UrlEncode(new Uint8Array(signature))}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  if (!tokenRes.ok) {
    const errText = await tokenRes.text();
    throw new Error(`Failed to obtain Google OAuth2 token: ${tokenRes.status} ${errText}`);
  }

  const tokenJson = await tokenRes.json();
  if (!tokenJson.access_token) {
    throw new Error("OAuth2 response missing access_token");
  }
  return tokenJson.access_token as string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const rawServiceAccount = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";

  if (!supabaseUrl || !supabaseServiceKey) {
    return new Response(
      JSON.stringify({ error: "Missing Supabase configuration" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  // 1. Authenticate caller JWT & verify role
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(
      JSON.stringify({ error: "Missing Authorization header" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const callerClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user: callerUser }, error: authErr } = await callerClient.auth.getUser();
  if (authErr || !callerUser) {
    return new Response(
      JSON.stringify({ error: "Invalid or expired session" }),
      { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const adminClient = createClient(supabaseUrl, supabaseServiceKey);

  const { data: callerProfile, error: profileErr } = await adminClient
    .from("users")
    .select("id, school_id, role")
    .eq("id", callerUser.id)
    .maybeSingle();

  const allowedRoles = ["super_admin", "owner", "admin", "staff", "teacher"];
  if (profileErr || !callerProfile || !allowedRoles.includes(callerProfile.role)) {
    return new Response(
      JSON.stringify({ error: "Forbidden: insufficient permissions to send notifications" }),
      { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  if (!rawServiceAccount) {
    return new Response(
      JSON.stringify({
        error:
          "Missing FIREBASE_SERVICE_ACCOUNT secret in Supabase Edge Function secrets. Download the service account JSON from Firebase Console -> Project Settings -> Service accounts.",
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  let serviceAccount: ServiceAccount;
  try {
    serviceAccount = JSON.parse(rawServiceAccount);
    if (!serviceAccount.project_id || !serviceAccount.private_key || !serviceAccount.client_email) {
      throw new Error("Incomplete service account JSON fields");
    }
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return new Response(
      JSON.stringify({ error: `Invalid FIREBASE_SERVICE_ACCOUNT JSON: ${msg}` }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    const payload = await req.json();
    const { title, body, userIds = [], route = "/notifications", data = {} } = payload;

    if (!title || !body) {
      return new Response(
        JSON.stringify({ error: "Missing title or body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Resolve eligible user IDs scoped to caller's school (unless super_admin)
    let scopedUserIds: string[] = Array.isArray(userIds)
      ? userIds.filter((id): id is string => typeof id === "string" && id.length > 0)
      : [];

    if (callerProfile.role !== "super_admin") {
      if (!callerProfile.school_id) {
        return new Response(
          JSON.stringify({ error: "Caller is not associated with a school" }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      let usersQuery = adminClient
        .from("users")
        .select("id")
        .eq("school_id", callerProfile.school_id);

      if (scopedUserIds.length > 0) {
        usersQuery = usersQuery.in("id", scopedUserIds);
      } else {
        usersQuery = usersQuery.eq("role", "student");
      }

      const { data: schoolUsers, error: usersErr } = await usersQuery;
      if (usersErr) {
        return new Response(
          JSON.stringify({ error: usersErr.message }),
          { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      scopedUserIds = (schoolUsers || []).map((u: { id: string }) => u.id);
    }

    if (callerProfile.role !== "super_admin" && scopedUserIds.length === 0) {
      return new Response(
        JSON.stringify({ success: true, tokensFound: 0, sentCount: 0, message: "No matching users in school" }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Fetch device FCM tokens
    let tokenQuery = adminClient.from("user_fcm_tokens").select("id, token, user_id");
    if (scopedUserIds.length > 0) {
      tokenQuery = tokenQuery.in("user_id", scopedUserIds);
    }

    const { data: tokenRecords, error: tokenErr } = await tokenQuery;
    if (tokenErr) {
      return new Response(
        JSON.stringify({ error: tokenErr.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const validRecords = (tokenRecords || []).filter(
      (r: { id: string; token: string }) => Boolean(r.token)
    );

    if (validRecords.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          message: "No registered device tokens found",
          tokensFound: 0,
          sentCount: 0,
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. Obtain OAuth2 access token for FCM HTTP v1 API
    const accessToken = await getFcmAccessToken(serviceAccount);
    const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;

    // FCM v1 requires all data payload values to be strings
    const stringData: Record<string, string> = {
      route: String(route),
      title: String(title),
      body: String(body),
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    };
    if (data && typeof data === "object") {
      for (const [k, v] of Object.entries(data as Record<string, unknown>)) {
        if (v !== undefined && v !== null) {
          stringData[k] = typeof v === "string" ? v : JSON.stringify(v);
        }
      }
    }

    let sentCount = 0;
    let failedCount = 0;
    const staleTokenIds: string[] = [];
    const errors: string[] = [];

    // Send in batches of 20 concurrently
    const batchSize = 20;
    for (let i = 0; i < validRecords.length; i += batchSize) {
      const batch = validRecords.slice(i, i + batchSize);
      await Promise.all(
        batch.map(async (rec: { id: string; token: string }) => {
          try {
            const fcmRes = await fetch(fcmEndpoint, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${accessToken}`,
              },
              body: JSON.stringify({
                message: {
                  token: rec.token,
                  notification: {
                    title: String(title),
                    body: String(body),
                  },
                  data: stringData,
                  android: {
                    priority: "HIGH",
                    notification: {
                      channel_id: "student_portal_channel",
                      sound: "default",
                      click_action: "FLUTTER_NOTIFICATION_CLICK",
                    },
                  },
                  apns: {
                    headers: {
                      "apns-priority": "10",
                    },
                    payload: {
                      aps: {
                        sound: "default",
                      },
                    },
                  },
                },
              }),
            });

            if (fcmRes.ok) {
              sentCount++;
            } else {
              failedCount++;
              const errBody = await fcmRes.text();
              if (
                errBody.includes("UNREGISTERED") ||
                errBody.includes("Requested entity was not found") ||
                errBody.includes("registration-token-not-registered")
              ) {
                staleTokenIds.push(rec.id);
              }
              if (errors.length < 5) {
                errors.push(`HTTP ${fcmRes.status}: ${errBody.slice(0, 200)}`);
              }
            }
          } catch (e) {
            failedCount++;
            if (errors.length < 5) {
              errors.push(e instanceof Error ? e.message : String(e));
            }
          }
        })
      );
    }

    // Remove unregistered/expired tokens
    if (staleTokenIds.length > 0) {
      await adminClient.from("user_fcm_tokens").delete().in("id", staleTokenIds);
    }

    return new Response(
      JSON.stringify({
        success: sentCount > 0 || failedCount === 0,
        tokensFound: validRecords.length,
        sentCount,
        failedCount,
        cleanedStaleTokens: staleTokenIds.length,
        ...(errors.length > 0 ? { errors } : {}),
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(
      JSON.stringify({ error: message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

