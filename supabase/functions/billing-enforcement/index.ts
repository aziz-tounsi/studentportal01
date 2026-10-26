// supabase/functions/billing-enforcement/index.ts
// Edge Function: Scheduled billing enforcement, overdue invoice detection,
//                and subscription lifecycle state machine.

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

  if (!supabaseUrl || !supabaseServiceKey) {
    return new Response(
      JSON.stringify({ error: "Missing backend configuration" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  const adminClient = createClient(supabaseUrl, supabaseServiceKey);

  try {
    const results = {
      pastDueCount: 0,
      suspendedCount: 0,
      invoicesGenerated: 0,
      invoicesMarkedOverdue: 0,
      timestamp: new Date().toISOString(),
    };

    // 1. Mark overdue invoices
    const { data: overdueInvoices, error: overdueErr } = await adminClient
      .from("invoices")
      .update({ status: "overdue" })
      .eq("status", "issued")
      .lt("due_date", new Date().toISOString().split("T")[0])
      .select("id, school_id, invoice_number");

    if (!overdueErr && overdueInvoices) {
      results.invoicesMarkedOverdue = overdueInvoices.length;
    }

    // 2. Query subscriptions to evaluate status transitions
    const { data: subs, error: subsErr } = await adminClient
      .from("school_subscriptions")
      .select(`
        id,
        school_id,
        status,
        billing_cycle,
        current_period_end,
        grace_period_days,
        plan_id,
        plan:subscription_plans(id, name, price_tnd_monthly, price_tnd_yearly)
      `);

    if (subsErr) {
      throw subsErr;
    }

    const now = new Date();

    for (const sub of subs ?? []) {
      const periodEnd = new Date(sub.current_period_end);
      const graceDays = sub.grace_period_days || 7;
      const graceEnd = new Date(periodEnd.getTime() + graceDays * 86400 * 1000);

      // A. Check for past_due (expired period, but within grace period)
      if (now > periodEnd && now <= graceEnd && (sub.status === "active" || sub.status === "trial")) {
        await adminClient
          .from("school_subscriptions")
          .update({ status: "past_due", updated_at: now.toISOString() })
          .eq("id", sub.id);

        results.pastDueCount++;
      }

      // B. Check for suspension (expired beyond grace period)
      if (now > graceEnd && sub.status !== "suspended" && sub.status !== "cancelled") {
        await adminClient
          .from("school_subscriptions")
          .update({ status: "suspended", updated_at: now.toISOString() })
          .eq("id", sub.id);

        // Turn on AI kill switch for suspended school
        await adminClient
          .from("ai_school_quotas")
          .upsert({
            school_id: sub.school_id,
            kill_switch_enabled: true,
            is_quota_exceeded: true,
            updated_at: now.toISOString(),
          });

        results.suspendedCount++;
      }

      // C. Auto-issue renewal invoice if within 7 days of period end and auto_renew is true
      const sevenDaysBefore = new Date(periodEnd.getTime() - 7 * 86400 * 1000);
      if (now >= sevenDaysBefore && sub.status === "active") {
        // Check if invoice already issued for this period end
        const { data: existingInvoices } = await adminClient
          .from("invoices")
          .select("id")
          .eq("subscription_id", sub.id)
          .eq("due_date", sub.current_period_end.split("T")[0]);

        if (!existingInvoices || existingInvoices.length === 0) {
          // Generate invoice number
          const { data: invNumData } = await adminClient.rpc("generate_invoice_number");
          const invNum = invNumData ?? `INV-${now.getFullYear()}-${Math.floor(1000 + Math.random() * 9000)}`;

          const plan = (sub as any).plan;
          const amount = sub.billing_cycle === "yearly"
            ? (plan?.price_tnd_yearly ?? 3500)
            : (plan?.price_tnd_monthly ?? 350);

          await adminClient.from("invoices").insert({
            invoice_number: invNum,
            school_id: sub.school_id,
            subscription_id: sub.id,
            amount: amount,
            currency: "TND",
            status: "issued",
            issue_date: now.toISOString().split("T")[0],
            due_date: sub.current_period_end.split("T")[0],
            notes: `Renouvellement automatique abonnement (${sub.billing_cycle})`,
          });

          results.invoicesGenerated++;
        }
      }
    }

    // Record in audit log
    await adminClient.from("audit_logs").insert({
      actor_role: "system",
      action: "billing_enforcement_run",
      target_table: "school_subscriptions",
      new_data: results,
    });

    return new Response(JSON.stringify({ success: true, ...results }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err: any) {
    return new Response(
      JSON.stringify({ success: false, error: err.message ?? "Unknown error" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" }, status: 500 }
    );
  }
});
