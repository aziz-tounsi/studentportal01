-- Add missing payment plan type enum values used by the admin dashboard UI.
-- The UI distinguishes:
--   - Trimestriel (3 payments) -> key 'semester' mapped to DB value 'trimester'
--   - Semestriel  (2 payments) -> key 'semesterly' mapped to DB value 'semesterly'
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_enum e ON t.oid = e.enumtypid
    WHERE t.typname = 'payment_plan_type'
      AND e.enumlabel = 'semesterly'
  ) THEN
    ALTER TYPE public.payment_plan_type ADD VALUE 'semesterly';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type t
    JOIN pg_enum e ON t.oid = e.enumtypid
    WHERE t.typname = 'payment_plan_type'
      AND e.enumlabel = 'trimester'
  ) THEN
    ALTER TYPE public.payment_plan_type ADD VALUE 'trimester';
  END IF;
END $$;
