-- ==============================================================================
-- Migration 042: Subscriptions, Commercial Billing & Invoicing Engine
-- Description: Adds subscription tiers, school subscriptions, automated invoicing,
--              payment tracking, and trial/grace period enforcement.
-- Safety: Strictly additive. Backfills active trials for existing schools.
-- ==============================================================================

-- 1. Extend schools table for branding, status, and tenant identification
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS code TEXT,
  ADD COLUMN IF NOT EXISTS primary_color TEXT DEFAULT '#0052CC',
  ADD COLUMN IF NOT EXISTS secondary_color TEXT DEFAULT '#172B4D',
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT TRUE;

CREATE UNIQUE INDEX IF NOT EXISTS idx_schools_code ON public.schools(code) WHERE code IS NOT NULL;

-- Auto-populate code for existing schools if null
DO $$
BEGIN
  UPDATE public.schools
  SET code = LOWER(REGEXP_REPLACE(name, '[^a-zA-Z0-9]', '', 'g'))
  WHERE code IS NULL;
END $$;

-- 2. Create Enums safely
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'subscription_status') THEN
    CREATE TYPE subscription_status AS ENUM ('trial', 'active', 'past_due', 'suspended', 'cancelled');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'invoice_status') THEN
    CREATE TYPE invoice_status AS ENUM ('draft', 'issued', 'paid', 'overdue', 'void');
  END IF;
END $$;

-- 3. Subscription Plans Catalog
CREATE TABLE IF NOT EXISTS public.subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT UNIQUE NOT NULL, -- 'starter', 'standard', 'premium'
    name TEXT NOT NULL,
    description TEXT,
    price_tnd_monthly NUMERIC(10, 2) NOT NULL,
    price_tnd_yearly NUMERIC(10, 2) NOT NULL,
    price_eur_monthly NUMERIC(10, 2) NOT NULL,
    max_students INT NOT NULL,
    max_storage_gb NUMERIC(6, 2) NOT NULL DEFAULT 10.0,
    daily_ai_messages_per_student INT NOT NULL DEFAULT 30,
    monthly_ai_token_budget_school BIGINT NOT NULL DEFAULT 5000000,
    has_white_label BOOLEAN NOT NULL DEFAULT FALSE,
    has_priority_support BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed Default Plans if not present
INSERT INTO public.subscription_plans (
    code, name, description, 
    price_tnd_monthly, price_tnd_yearly, price_eur_monthly, 
    max_students, max_storage_gb, daily_ai_messages_per_student, 
    monthly_ai_token_budget_school, has_white_label, has_priority_support
) VALUES 
(
    'starter', 
    'Starter', 
    'Pour les petits établissements scolaires ou centres de formation débutants.',
    350.00, 3500.00, 110.00,
    200, 10.0, 30,
    5000000, FALSE, FALSE
),
(
    'standard', 
    'Standard (Recommandé)', 
    'Solution complète avec personnalisation du logo et quota IA étendu.',
    850.00, 8500.00, 260.00,
    600, 30.0, 60,
    15000000, TRUE, FALSE
),
(
    'premium', 
    'Premium Institution', 
    'Pour les grandes institutions et universités privées avec support dédié 24/7.',
    1800.00, 18000.00, 550.00,
    1500, 100.0, 120,
    50000000, TRUE, TRUE
)
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    price_tnd_monthly = EXCLUDED.price_tnd_monthly,
    price_tnd_yearly = EXCLUDED.price_tnd_yearly,
    price_eur_monthly = EXCLUDED.price_eur_monthly,
    max_students = EXCLUDED.max_students,
    max_storage_gb = EXCLUDED.max_storage_gb,
    daily_ai_messages_per_student = EXCLUDED.daily_ai_messages_per_student,
    monthly_ai_token_budget_school = EXCLUDED.monthly_ai_token_budget_school,
    has_white_label = EXCLUDED.has_white_label,
    has_priority_support = EXCLUDED.has_priority_support;

-- 4. School Subscriptions
CREATE TABLE IF NOT EXISTS public.school_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE UNIQUE,
    plan_id UUID NOT NULL REFERENCES public.subscription_plans(id),
    status subscription_status NOT NULL DEFAULT 'trial',
    billing_cycle TEXT NOT NULL DEFAULT 'monthly' CHECK (billing_cycle IN ('monthly', 'yearly')),
    trial_ends_at TIMESTAMPTZ,
    current_period_start TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    current_period_end TIMESTAMPTZ NOT NULL,
    grace_period_days INT NOT NULL DEFAULT 7,
    auto_renew BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_school_subscriptions_status ON public.school_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_school_subscriptions_period_end ON public.school_subscriptions(current_period_end);

-- Backfill existing schools into Standard plan on active trial (30 days)
DO $$
DECLARE
  standard_plan_id UUID;
  sch RECORD;
BEGIN
  SELECT id INTO standard_plan_id FROM public.subscription_plans WHERE code = 'standard' LIMIT 1;
  IF standard_plan_id IS NOT NULL THEN
    FOR sch IN SELECT id FROM public.schools LOOP
      INSERT INTO public.school_subscriptions (
        school_id, plan_id, status, billing_cycle,
        trial_ends_at, current_period_start, current_period_end
      ) VALUES (
        sch.id,
        standard_plan_id,
        'trial',
        'monthly',
        NOW() + INTERVAL '30 days',
        NOW(),
        NOW() + INTERVAL '30 days'
      ) ON CONFLICT (school_id) DO NOTHING;
    END LOOP;
  END IF;
END $$;

-- 5. Invoices & Invoice Payments
CREATE TABLE IF NOT EXISTS public.invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_number TEXT UNIQUE NOT NULL,
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    subscription_id UUID REFERENCES public.school_subscriptions(id) ON DELETE SET NULL,
    amount NUMERIC(10, 2) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'TND',
    status invoice_status NOT NULL DEFAULT 'issued',
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE NOT NULL,
    paid_at TIMESTAMPTZ,
    pdf_url TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invoices_school_id ON public.invoices(school_id);
CREATE INDEX IF NOT EXISTS idx_invoices_status ON public.invoices(status);

CREATE TABLE IF NOT EXISTS public.invoice_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    payment_method TEXT NOT NULL, -- 'bank_transfer', 'cheque', 'd17', 'flouci', 'konnect'
    transaction_ref TEXT,
    verified_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    verified_at TIMESTAMPTZ,
    is_verified BOOLEAN NOT NULL DEFAULT FALSE,
    receipt_url TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_invoice_payments_invoice ON public.invoice_payments(invoice_id);

-- 6. Helper Functions & Automation

-- Function: Generate Next Invoice Number (INV-YYYY-XXXX)
CREATE OR REPLACE FUNCTION public.generate_invoice_number()
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_yr TEXT := TO_CHAR(NOW(), 'YYYY');
  seq_num INT;
  res TEXT;
BEGIN
  SELECT COUNT(*) + 1 INTO seq_num
  FROM public.invoices
  WHERE invoice_number LIKE 'INV-' || current_yr || '-%';

  res := 'INV-' || current_yr || '-' || LPAD(seq_num::TEXT, 4, '0');
  RETURN res;
END;
$$;

-- Function: Verify Invoice Payment & Extend Subscription
CREATE OR REPLACE FUNCTION public.verify_invoice_payment(
    p_payment_id UUID,
    p_verifier_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_inv_id UUID;
  v_payment RECORD;
  v_inv RECORD;
  v_sub RECORD;
  v_total_paid NUMERIC(10, 2);
  v_extension_interval INTERVAL;
BEGIN
  -- 1. Fetch payment
  SELECT * INTO v_payment FROM public.invoice_payments WHERE id = p_payment_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Payment not found');
  END IF;

  -- 2. Mark payment verified
  UPDATE public.invoice_payments
  SET is_verified = TRUE,
      verified_by = p_verifier_id,
      verified_at = NOW()
  WHERE id = p_payment_id;

  -- 3. Calculate total verified paid for invoice
  SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
  FROM public.invoice_payments
  WHERE invoice_id = v_payment.invoice_id AND is_verified = TRUE;

  -- 4. Check if invoice is satisfied
  SELECT * INTO v_inv FROM public.invoices WHERE id = v_payment.invoice_id;
  IF v_total_paid >= v_inv.amount THEN
    UPDATE public.invoices
    SET status = 'paid',
        paid_at = NOW()
    WHERE id = v_inv.id;

    -- 5. Extend school subscription
    IF v_inv.subscription_id IS NOT NULL THEN
      SELECT * INTO v_sub FROM public.school_subscriptions WHERE id = v_inv.subscription_id;
      IF FOUND THEN
        IF v_sub.billing_cycle = 'yearly' THEN
          v_extension_interval := INTERVAL '1 year';
        ELSE
          v_extension_interval := INTERVAL '1 month';
        END IF;

        UPDATE public.school_subscriptions
        SET status = 'active',
            current_period_start = GREATEST(current_period_end, NOW()),
            current_period_end = GREATEST(current_period_end, NOW()) + v_extension_interval,
            updated_at = NOW()
        WHERE id = v_sub.id;

        -- Ensure school quota exceeded flag is cleared on renewal
        UPDATE public.ai_school_quotas
        SET is_quota_exceeded = FALSE,
            kill_switch_enabled = FALSE
        WHERE school_id = v_sub.school_id;
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true, 
    'invoice_id', v_inv.id,
    'total_paid', v_total_paid,
    'invoice_status', CASE WHEN v_total_paid >= v_inv.amount THEN 'paid' ELSE 'issued' END
  );
END;
$$;

-- Function: Check School Subscription and Limits
CREATE OR REPLACE FUNCTION public.check_school_subscription_status(p_school_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_sub RECORD;
  v_plan RECORD;
  v_quota RECORD;
  v_is_valid BOOLEAN := FALSE;
  v_days_left INT := 0;
BEGIN
  SELECT * INTO v_sub FROM public.school_subscriptions WHERE school_id = p_school_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'has_subscription', false,
      'is_valid', false,
      'status', 'none',
      'reason', 'No subscription found for school'
    );
  END IF;

  SELECT * INTO v_plan FROM public.subscription_plans WHERE id = v_sub.plan_id;
  SELECT * INTO v_quota FROM public.ai_school_quotas WHERE school_id = p_school_id;

  v_days_left := EXTRACT(DAY FROM (v_sub.current_period_end - NOW()))::INT;

  -- Active or trial within grace period
  IF v_sub.status IN ('active', 'trial') AND v_sub.current_period_end + (v_sub.grace_period_days || ' days')::INTERVAL >= NOW() THEN
    v_is_valid := TRUE;
  END IF;

  RETURN jsonb_build_object(
    'has_subscription', true,
    'is_valid', v_is_valid,
    'status', v_sub.status,
    'plan_code', v_plan.code,
    'plan_name', v_plan.name,
    'days_left', v_days_left,
    'current_period_end', v_sub.current_period_end,
    'max_students', v_plan.max_students,
    'daily_ai_messages_per_student', v_plan.daily_ai_messages_per_student,
    'ai_quota_exceeded', COALESCE(v_quota.is_quota_exceeded, false)
  );
END;
$$;

-- Trigger: When new school is registered, auto-attach trial subscription
CREATE OR REPLACE FUNCTION public.on_new_school_created_subscription()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  standard_plan_id UUID;
BEGIN
  SELECT id INTO standard_plan_id FROM public.subscription_plans WHERE code = 'standard' LIMIT 1;
  IF standard_plan_id IS NOT NULL THEN
    INSERT INTO public.school_subscriptions (
      school_id, plan_id, status, billing_cycle,
      trial_ends_at, current_period_start, current_period_end
    ) VALUES (
      NEW.id,
      standard_plan_id,
      'trial',
      'monthly',
      NOW() + INTERVAL '30 days',
      NOW(),
      NOW() + INTERVAL '30 days'
    ) ON CONFLICT (school_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_school_subscription_auto ON public.schools;
CREATE TRIGGER trigger_school_subscription_auto
  AFTER INSERT ON public.schools
  FOR EACH ROW
  EXECUTE FUNCTION public.on_new_school_created_subscription();

-- 7. Row Level Security Policies

ALTER TABLE public.subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_payments ENABLE ROW LEVEL SECURITY;

-- subscription_plans: Authenticated users can view active plans; Super Admin manages all
DROP POLICY IF EXISTS "Anyone authenticated can view active subscription plans" ON public.subscription_plans;
CREATE POLICY "Anyone authenticated can view active subscription plans"
  ON public.subscription_plans
  FOR SELECT
  TO authenticated
  USING (is_active = TRUE OR public.is_super_admin());

DROP POLICY IF EXISTS "Super admin manages subscription plans" ON public.subscription_plans;
CREATE POLICY "Super admin manages subscription plans"
  ON public.subscription_plans
  FOR ALL
  TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

-- school_subscriptions: School staff can view own; Super Admin manages all
DROP POLICY IF EXISTS "School staff can view own subscription" ON public.school_subscriptions;
CREATE POLICY "School staff can view own subscription"
  ON public.school_subscriptions
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin() OR 
    school_id = public.get_user_school_id()
  );

DROP POLICY IF EXISTS "Super admin manages all school subscriptions" ON public.school_subscriptions;
CREATE POLICY "Super admin manages all school subscriptions"
  ON public.school_subscriptions
  FOR ALL
  TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

-- invoices: School admin can view own invoices; Super Admin manages all
DROP POLICY IF EXISTS "School admin can view own invoices" ON public.invoices;
CREATE POLICY "School admin can view own invoices"
  ON public.invoices
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin() OR 
    (school_id = public.get_user_school_id() AND public.is_school_admin())
  );

DROP POLICY IF EXISTS "Super admin manages all invoices" ON public.invoices;
CREATE POLICY "Super admin manages all invoices"
  ON public.invoices
  FOR ALL
  TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

-- invoice_payments: School admin can view and upload payment proof; Super Admin verifies and manages
DROP POLICY IF EXISTS "School admin can view own invoice payments" ON public.invoice_payments;
CREATE POLICY "School admin can view own invoice payments"
  ON public.invoice_payments
  FOR SELECT
  TO authenticated
  USING (
    public.is_super_admin() OR 
    EXISTS (
      SELECT 1 FROM public.invoices i
      WHERE i.id = invoice_id 
        AND i.school_id = public.get_user_school_id()
        AND public.is_school_admin()
    )
  );

DROP POLICY IF EXISTS "School admin can insert payment proof" ON public.invoice_payments;
CREATE POLICY "School admin can insert payment proof"
  ON public.invoice_payments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    public.is_super_admin() OR 
    EXISTS (
      SELECT 1 FROM public.invoices i
      WHERE i.id = invoice_id 
        AND i.school_id = public.get_user_school_id()
        AND public.is_school_admin()
    )
  );

DROP POLICY IF EXISTS "Super admin manages all payments" ON public.invoice_payments;
CREATE POLICY "Super admin manages all payments"
  ON public.invoice_payments
  FOR ALL
  TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());
