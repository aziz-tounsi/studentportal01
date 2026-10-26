-- ==============================================================================
-- Migration 099: Commercial SaaS Demo School Seed Generator
-- Description: Creates a pre-populated, production-ready demo school for pitch demos.
-- School: Lycée Pilote Pythagore (Démo) [code: demo]
-- ==============================================================================

DO $$
DECLARE
  v_demo_school_id UUID;
  v_standard_plan_id UUID;
  v_director_id UUID := gen_random_uuid();
  v_class_id UUID := gen_random_uuid();
  v_acad_year_id UUID := gen_random_uuid();
  v_student_id UUID := gen_random_uuid();
  v_subject_math_id UUID := gen_random_uuid();
  v_subject_phys_id UUID := gen_random_uuid();
  v_offering_math_id UUID := gen_random_uuid();
  v_offering_phys_id UUID := gen_random_uuid();
  v_inv_id UUID := gen_random_uuid();
  v_sub_id UUID;
BEGIN
  -- 1. Ensure Standard Plan exists
  SELECT id INTO v_standard_plan_id FROM public.subscription_plans WHERE code = 'standard' LIMIT 1;

  -- 2. Create or Get Demo School
  INSERT INTO public.schools (
    name, code, email, phone, address, primary_color, secondary_color, is_active
  ) VALUES (
    'Lycée Pilote Pythagore (Démo)',
    'demo',
    'contact@demo-school.tn',
    '+216 71 000 111',
    'Avenue Habib Bourguiba, Tunis',
    '#2563EB',
    '#0D1321',
    TRUE
  )
  ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    is_active = TRUE
  RETURNING id INTO v_demo_school_id;

  -- 3. Set School AI Quota
  INSERT INTO public.ai_school_quotas (
    school_id, monthly_budget_usd, spent_current_month_usd, tokens_current_month, is_quota_exceeded, kill_switch_enabled
  ) VALUES (
    v_demo_school_id, 30.00, 2.45, 85000, FALSE, FALSE
  )
  ON CONFLICT (school_id) DO UPDATE SET
    monthly_budget_usd = 30.00,
    spent_current_month_usd = 2.45,
    tokens_current_month = 85000,
    is_quota_exceeded = FALSE,
    kill_switch_enabled = FALSE;

  -- 4. Set School Subscription (Active Standard Plan)
  INSERT INTO public.school_subscriptions (
    school_id, plan_id, status, billing_cycle,
    current_period_start, current_period_end, grace_period_days, auto_renew
  ) VALUES (
    v_demo_school_id, v_standard_plan_id, 'active', 'monthly',
    NOW(), NOW() + INTERVAL '30 days', 7, TRUE
  )
  ON CONFLICT (school_id) DO UPDATE SET
    status = 'active',
    current_period_end = NOW() + INTERVAL '30 days'
  RETURNING id INTO v_sub_id;

  -- 5. Seed Sample Invoices
  INSERT INTO public.invoices (
    id, invoice_number, school_id, subscription_id, amount, currency, status, issue_date, due_date, paid_at, notes
  ) VALUES (
    v_inv_id,
    'INV-2026-0001',
    v_demo_school_id,
    v_sub_id,
    850.00,
    'TND',
    'paid',
    CURRENT_DATE - INTERVAL '15 days',
    CURRENT_DATE + INTERVAL '15 days',
    NOW() - INTERVAL '14 days',
    'Souscription mensuelle Formule Standard — Règlement par virement BIAT'
  )
  ON CONFLICT (invoice_number) DO NOTHING;

  -- 6. Seed Sample AI Telemetry Logs
  INSERT INTO public.ai_usage_logs (
    school_id, student_id, model, prompt_tokens, completion_tokens, total_tokens, cost_usd, latency_ms, status
  ) VALUES
  (v_demo_school_id, v_student_id, 'poolside/laguna-s-2.1:free', 450, 120, 570, 0.000114, 380, 'success'),
  (v_demo_school_id, v_student_id, 'google/gemini-2.0-flash-exp:free', 620, 280, 900, 0.000180, 520, 'success'),
  (v_demo_school_id, v_student_id, 'poolside/laguna-s-2.1:free', 310, 85, 395, 0.000079, 290, 'success');

  -- 7. Seed Sample Audit Log
  INSERT INTO public.audit_logs (
    school_id, actor_role, action, target_table, new_data
  ) VALUES (
    v_demo_school_id, 'super_admin', 'seed_demo_school', 'schools', jsonb_build_object('code', 'demo', 'plan', 'standard')
  );

  RAISE NOTICE 'Demo School Seed completed successfully: %', v_demo_school_id;
END $$;
