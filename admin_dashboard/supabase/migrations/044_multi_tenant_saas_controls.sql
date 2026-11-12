-- Migration 044: Multi-Tenant SaaS Controls
-- 1. Student account_status ('active' | 'paused_unpaid') & force_password_change
-- 2. Tenant + student payment kill-switch helper functions & restrictive RLS
-- 3. Password reset request RPC supporting email OR student_code (matricule)

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS account_status TEXT NOT NULL DEFAULT 'active'
    CHECK (account_status IN ('active', 'paused_unpaid'));

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS force_password_change BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_users_account_status
  ON public.users(account_status);

-- Helper: Is the school's SaaS subscription active (not suspended & school active)?
CREATE OR REPLACE FUNCTION public.is_school_subscription_active(p_school_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(
    (
      SELECT s.is_active
        AND NOT EXISTS (
          SELECT 1
          FROM public.school_subscriptions ss
          WHERE ss.school_id = s.id
            AND ss.status = 'suspended'
        )
      FROM public.schools s
      WHERE s.id = p_school_id
      LIMIT 1
    ),
    false
  );
$$;

-- Helper: Is the currently authenticated user allowed to access tenant resources?
-- - super_admin: always true
-- - admin/staff/owner/teacher: true while their school is not suspended
-- - student: true while account_status = 'active', is_active = true, AND school not suspended
CREATE OR REPLACE FUNCTION public.is_current_user_access_active()
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user RECORD;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  SELECT id, role, school_id, is_active, COALESCE(account_status, 'active') AS account_status
  INTO v_user
  FROM public.users
  WHERE id = auth.uid()
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_user.role = 'super_admin' THEN
    RETURN true;
  END IF;

  IF NOT public.is_school_subscription_active(v_user.school_id) THEN
    RETURN false;
  END IF;

  IF v_user.role = 'student' THEN
    RETURN COALESCE(v_user.is_active, true) AND v_user.account_status = 'active';
  END IF;

  RETURN COALESCE(v_user.is_active, true);
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_school_subscription_active(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_current_user_access_active() TO authenticated;

-- Restrictive RLS enforcement on student-facing academic tables
-- (Blocks paused_unpaid students and suspended schools at the database level)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'grades') THEN
    DROP POLICY IF EXISTS "grades_active_access_restrictive" ON public.grades;
    CREATE POLICY "grades_active_access_restrictive" ON public.grades
      AS RESTRICTIVE FOR SELECT TO authenticated
      USING (public.is_current_user_access_active());
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'absence_records') THEN
    DROP POLICY IF EXISTS "absences_active_access_restrictive" ON public.absence_records;
    CREATE POLICY "absences_active_access_restrictive" ON public.absence_records
      AS RESTRICTIVE FOR SELECT TO authenticated
      USING (public.is_current_user_access_active());
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'timetable_slots') THEN
    DROP POLICY IF EXISTS "timetable_slots_active_access_restrictive" ON public.timetable_slots;
    CREATE POLICY "timetable_slots_active_access_restrictive" ON public.timetable_slots
      AS RESTRICTIVE FOR SELECT TO authenticated
      USING (public.is_current_user_access_active());
  END IF;

  IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'documents') THEN
    DROP POLICY IF EXISTS "documents_active_access_restrictive" ON public.documents;
    CREATE POLICY "documents_active_access_restrictive" ON public.documents
      AS RESTRICTIVE FOR SELECT TO authenticated
      USING (public.is_current_user_access_active());
  END IF;
END $$;

-- RPC: Create password reset request by email OR student_code (matricule)
-- Never persists raw/plaintext new passwords in the database.
DROP FUNCTION IF EXISTS public.create_password_reset_request(TEXT);
CREATE OR REPLACE FUNCTION public.create_password_reset_request(p_email TEXT)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_identifier TEXT := LOWER(TRIM(COALESCE(p_email, '')));
  v_user       RECORD;
  v_req_id     UUID;
BEGIN
  IF v_identifier = '' THEN
    RAISE EXCEPTION 'Email or matricule is required';
  END IF;

  SELECT id, email, full_name
  INTO v_user
  FROM public.users
  WHERE LOWER(email) = v_identifier
     OR LOWER(COALESCE(student_code, '')) = v_identifier
  LIMIT 1;

  INSERT INTO public.password_reset_requests (
    id,
    user_id,
    email,
    full_name,
    status,
    requested_at,
    created_at
  )
  VALUES (
    gen_random_uuid(),
    v_user.id,
    COALESCE(v_user.email, v_identifier),
    COALESCE(v_user.full_name, 'Élève (' || v_identifier || ')'),
    'pending',
    NOW(),
    NOW()
  )
  RETURNING id INTO v_req_id;

  RETURN v_req_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_password_reset_request(TEXT) TO anon, authenticated;
