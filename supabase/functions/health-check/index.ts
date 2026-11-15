// supabase/functions/health-check/index.ts
// ==============================================================================
// Outside-In Multi-Region Synthetic Health Check Edge Function
// Designed for UptimeRobot, BetterStack, Checkly, and Console Control Dashboard
// ==============================================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-request-id",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

interface ComponentHealth {
  status: "up" | "degraded" | "down";
  latency_ms: number;
  error?: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = performance.now();
  const requestId = req.headers.get("x-request-id") ?? crypto.randomUUID();

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

  if (!supabaseUrl || !supabaseServiceKey) {
    return new Response(
      JSON.stringify({
        status: "down",
        error: "Missing Supabase environment configuration",
        request_id: requestId,
        timestamp: new Date().toISOString(),
      }),
      { status: 503, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const adminClient = createClient(supabaseUrl, supabaseServiceKey);
  const checks: Record<string, ComponentHealth> = {};

  // 1. Synthetic Database Check (Read platform_settings & measure latency)
  const dbStart = performance.now();
  try {
    const { data, error } = await adminClient
      .from("platform_settings")
      .select("id, global_ai_kill_switch")
      .eq("id", 1)
      .maybeSingle();

    const dbLatency = Math.round(performance.now() - dbStart);
    if (error) {
      checks["database"] = {
        status: "degraded",
        latency_ms: dbLatency,
        error: error.message,
      };
    } else {
      checks["database"] = {
        status: "up",
        latency_ms: dbLatency,
      };
    }
  } catch (err: any) {
    checks["database"] = {
      status: "down",
      latency_ms: Math.round(performance.now() - dbStart),
      error: err?.message ?? "Database ping failed",
    };
  }

  // 2. Auth Service Responsiveness Check
  const authStart = performance.now();
  try {
    const anonClient = createClient(supabaseUrl, supabaseAnonKey || supabaseServiceKey);
    const { error } = await anonClient.auth.getSession();
    const authLatency = Math.round(performance.now() - authStart);

    checks["auth"] = {
      status: error ? "degraded" : "up",
      latency_ms: authLatency,
      ...(error ? { error: error.message } : {}),
    };
  } catch (err: any) {
    checks["auth"] = {
      status: "down",
      latency_ms: Math.round(performance.now() - authStart),
      error: err?.message ?? "Auth ping failed",
    };
  }

  // 3. Storage Service Accessibility Check
  const storageStart = performance.now();
  try {
    const { data: buckets, error: storageErr } = await adminClient.storage.listBuckets();
    const storageLatency = Math.round(performance.now() - storageStart);

    checks["storage"] = {
      status: storageErr ? "degraded" : "up",
      latency_ms: storageLatency,
      ...(storageErr ? { error: storageErr.message } : {}),
    };
  } catch (err: any) {
    checks["storage"] = {
      status: "down",
      latency_ms: Math.round(performance.now() - storageStart),
      error: err?.message ?? "Storage ping failed",
    };
  }

  // Determine overall status
  const overallLatency = Math.round(performance.now() - startTime);
  const isHealthy = Object.values(checks).every((c) => c.status === "up");
  const isDown = Object.values(checks).some((c) => c.status === "down");

  const responseStatus = isDown ? 503 : (isHealthy ? 200 : 200);
  const payload = {
    status: isHealthy ? "healthy" : (isDown ? "unhealthy" : "degraded"),
    timestamp: new Date().toISOString(),
    version: "2.0.0",
    request_id: requestId,
    overall_latency_ms: overallLatency,
    checks,
    slo: {
      target_availability: 99.9,
      unit: "percent",
      evaluation_window: "rolling_30d",
    },
  };

  return new Response(JSON.stringify(payload, null, 2), {
    status: responseStatus,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      "x-request-id": requestId,
      "Cache-Control": "no-cache, no-store, must-revalidate",
    },
  });
});
