// supabase/functions/send-push-notification/index.ts
// Edge Function: Dispatches background push notifications via Firebase Cloud Messaging (FCM)
//                to students whose apps are closed/swiped away.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const fcmServerKey = Deno.env.get("FCM_SERVER_KEY") ?? "";

  if (!supabaseUrl || !supabaseServiceKey) {
    return new Response(
      JSON.stringify({ error: "Missing Supabase configuration" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const adminClient = createClient(supabaseUrl, supabaseServiceKey);

  try {
    const payload = await req.json();
    const { title, body, userIds = [], route = "/notifications", data = {} } = payload;

    if (!title || !body) {
      return new Response(
        JSON.stringify({ error: "Missing title or body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Fetch device FCM tokens
    let tokenQuery = adminClient.from("user_fcm_tokens").select("token, user_id");
    if (Array.isArray(userIds) && userIds.length > 0) {
      tokenQuery = tokenQuery.in("user_id", userIds);
    }

    const { data: tokenRecords, error: tokenErr } = await tokenQuery;
    if (tokenErr) {
      return new Response(
        JSON.stringify({ error: tokenErr.message }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const tokens: string[] = (tokenRecords || [])
      .map((r: { token: string }) => r.token)
      .filter((t: string) => Boolean(t));

    if (tokens.length === 0) {
      return new Response(
        JSON.stringify({ message: "No registered device tokens found", sentCount: 0 }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. Dispatch push notifications via FCM legacy/HTTP endpoint or batch
    let sentCount = 0;
    if (fcmServerKey) {
      for (const token of tokens) {
        try {
          const fcmResponse = await fetch("https://fcm.googleapis.com/fcm/send", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `key=${fcmServerKey}`,
            },
            body: JSON.stringify({
              to: token,
              notification: {
                title: title,
                body: body,
                sound: "default",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
              data: {
                ...data,
                route: route,
                title: title,
                body: body,
              },
              priority: "high",
            }),
          });
          if (fcmResponse.ok) {
            sentCount++;
          }
        } catch (e) {
          console.error(`Error sending push to token ${token}:`, e);
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        tokensFound: tokens.length,
        sentCount: sentCount,
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
