-- ==============================================================================
-- Rollback for Migration 042: Subscriptions & Invoicing Engine
-- ==============================================================================

DROP TRIGGER IF EXISTS trigger_school_subscription_auto ON public.schools;
DROP FUNCTION IF EXISTS public.on_new_school_created_subscription();

DROP POLICY IF EXISTS "Super admin manages all payments" ON public.invoice_payments;
DROP POLICY IF EXISTS "School admin can insert payment proof" ON public.invoice_payments;
DROP POLICY IF EXISTS "School admin can view own invoice payments" ON public.invoice_payments;

DROP POLICY IF EXISTS "Super admin manages all invoices" ON public.invoices;
DROP POLICY IF EXISTS "School admin can view own invoices" ON public.invoices;

DROP POLICY IF EXISTS "Super admin manages all school subscriptions" ON public.school_subscriptions;
DROP POLICY IF EXISTS "School staff can view own subscription" ON public.school_subscriptions;

DROP POLICY IF EXISTS "Super admin manages subscription plans" ON public.subscription_plans;
DROP POLICY IF EXISTS "Anyone authenticated can view active subscription plans" ON public.subscription_plans;

DROP FUNCTION IF EXISTS public.check_school_subscription_status(UUID);
DROP FUNCTION IF EXISTS public.verify_invoice_payment(UUID, UUID);
DROP FUNCTION IF EXISTS public.generate_invoice_number();

DROP TABLE IF EXISTS public.invoice_payments CASCADE;
DROP TABLE IF EXISTS public.invoices CASCADE;
DROP TABLE IF EXISTS public.school_subscriptions CASCADE;
DROP TABLE IF EXISTS public.subscription_plans CASCADE;

DROP TYPE IF EXISTS invoice_status CASCADE;
DROP TYPE IF EXISTS subscription_status CASCADE;

ALTER TABLE public.schools
  DROP COLUMN IF EXISTS is_active,
  DROP COLUMN IF EXISTS secondary_color,
  DROP COLUMN IF EXISTS primary_color,
  DROP COLUMN IF EXISTS code;
