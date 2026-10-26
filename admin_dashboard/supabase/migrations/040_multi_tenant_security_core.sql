-- ============================================================================
-- MIGRATION 040: MULTI-TENANT SECURITY & ISOLATION CORE
-- ============================================================================
-- Description:
--   1. Expands user roles to support 'super_admin' and 'owner'.
--   2. Creates security definer functions for safe school and role resolution.
--   3. Adds direct `school_id` foreign keys to all high-volume tenant tables.
--   4. Performs non-destructive backfills of `school_id` from parent tables.
--   5. Creates B-tree indexes on `school_id` across all tenant tables.
--   6. Implements auto-populating triggers for `school_id` to protect legacy writes.
--   7. Creates an append-only `audit_logs` table and triggers on sensitive tables.
--   8. Drops insecure/cross-tenant policies (including the leaky `authenticated_read_users`).
--   9. Establishes airtight Row Level Security (RLS) policies enforcing multi-school isolation.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: EXPAND USER ROLES
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    BEGIN
        ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'super_admin';
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
    BEGIN
        ALTER TYPE public.user_role ADD VALUE IF NOT EXISTS 'owner';
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
END $$;

-- ----------------------------------------------------------------------------
-- STEP 2: HELPER FUNCTIONS (SECURITY DEFINER WITH SEARCH_PATH=PUBLIC)
-- ----------------------------------------------------------------------------

-- Returns current user's school_id without causing RLS recursion
CREATE OR REPLACE FUNCTION public.get_user_school_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT school_id FROM public.users WHERE id = auth.uid() LIMIT 1;
$$;

-- Drop previous get_user_role() if return type was enum user_role to prevent 42P13 error
DROP FUNCTION IF EXISTS public.get_user_role() CASCADE;

-- Returns current user's role safely
CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role::TEXT FROM public.users WHERE id = auth.uid() LIMIT 1;
$$;

-- Maintain backward-compatibility for legacy is_admin callers
DROP FUNCTION IF EXISTS public.is_admin() CASCADE;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(public.get_user_role() IN ('super_admin', 'owner', 'admin'), false);
$$;

-- Checks if the authenticated user is the SaaS platform super admin
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(public.get_user_role() = 'super_admin', false);
$$;

-- Checks if user has school administrative privileges (super_admin, owner, admin, staff)
CREATE OR REPLACE FUNCTION public.is_school_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(public.get_user_role() IN ('super_admin', 'owner', 'admin', 'staff'), false);
$$;

GRANT EXECUTE ON FUNCTION public.get_user_school_id() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_user_role() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_super_admin() TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.is_school_admin() TO authenticated, anon;

-- ----------------------------------------------------------------------------
-- STEP 3: ADD DIRECT school_id COLUMNS & INDEXES TO HIGH-VOLUME TABLES
-- ----------------------------------------------------------------------------

-- 3.1 enrollments
ALTER TABLE public.enrollments 
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_enrollments_school_id ON public.enrollments(school_id);

-- 3.2 groups
ALTER TABLE public.groups 
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_groups_school_id ON public.groups(school_id);

-- 3.3 subject_offerings
ALTER TABLE public.subject_offerings 
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_subject_offerings_school_id ON public.subject_offerings(school_id);

-- 3.4 grade_components
ALTER TABLE public.grade_components 
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_grade_components_school_id ON public.grade_components(school_id);

-- 3.5 grades
ALTER TABLE public.grades 
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_grades_school_id ON public.grades(school_id);

-- 3.6 absence_records
ALTER TABLE public.absence_records 
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_absence_records_school_id ON public.absence_records(school_id);

-- 3.7 payment_plans
ALTER TABLE public.payment_plans 
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_payment_plans_school_id ON public.payment_plans(school_id);

-- 3.8 payments
ALTER TABLE public.payments 
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_payments_school_id ON public.payments(school_id);

-- 3.9 timetable_slots
ALTER TABLE public.timetable_slots 
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_timetable_slots_school_id ON public.timetable_slots(school_id);

-- 3.10 suggestions
ALTER TABLE public.suggestions 
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_suggestions_school_id ON public.suggestions(school_id);

-- 3.11 suggestion_replies
ALTER TABLE public.suggestion_replies 
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_suggestion_replies_school_id ON public.suggestion_replies(school_id);

-- 3.12 announcements_class
ALTER TABLE public.announcements_class 
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_announcements_class_school_id ON public.announcements_class(school_id);

-- 3.13 floors (physical structure)
ALTER TABLE public.floors 
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_floors_school_id ON public.floors(school_id);

-- 3.14 rooms (physical structure)
ALTER TABLE public.rooms 
  ADD COLUMN IF NOT EXISTS school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE;
CREATE INDEX IF NOT EXISTS idx_rooms_school_id ON public.rooms(school_id);

-- ----------------------------------------------------------------------------
-- STEP 4: BACKFILL school_id DATA FROM EXISTING RELATIONS
-- ----------------------------------------------------------------------------

-- 4.1 enrollments from classes
UPDATE public.enrollments e
SET school_id = c.school_id
FROM public.classes c
WHERE e.class_id = c.id AND e.school_id IS NULL;

-- 4.2 groups from classes
UPDATE public.groups g
SET school_id = c.school_id
FROM public.classes c
WHERE g.class_id = c.id AND g.school_id IS NULL;

-- 4.3 subject_offerings from classes
UPDATE public.subject_offerings so
SET school_id = c.school_id
FROM public.classes c
WHERE so.class_id = c.id AND so.school_id IS NULL;

-- 4.4 grade_components from subject_offerings
UPDATE public.grade_components gc
SET school_id = so.school_id
FROM public.subject_offerings so
WHERE gc.subject_offering_id = so.id AND gc.school_id IS NULL;

-- 4.5 grades from enrollments
UPDATE public.grades g
SET school_id = e.school_id
FROM public.enrollments e
WHERE g.enrollment_id = e.id AND g.school_id IS NULL;

-- 4.6 absence_records from enrollments
UPDATE public.absence_records a
SET school_id = e.school_id
FROM public.enrollments e
WHERE a.enrollment_id = e.id AND a.school_id IS NULL;

-- 4.7 payment_plans from enrollments
UPDATE public.payment_plans pp
SET school_id = e.school_id
FROM public.enrollments e
WHERE pp.enrollment_id = e.id AND pp.school_id IS NULL;

-- 4.8 payments from payment_plans
UPDATE public.payments p
SET school_id = pp.school_id
FROM public.payment_plans pp
WHERE p.payment_plan_id = pp.id AND p.school_id IS NULL;

-- 4.9 timetable_slots from subject_offerings
UPDATE public.timetable_slots ts
SET school_id = so.school_id
FROM public.subject_offerings so
WHERE ts.subject_offering_id = so.id AND ts.school_id IS NULL;

-- 4.10 suggestions from users
UPDATE public.suggestions s
SET school_id = u.school_id
FROM public.users u
WHERE s.student_id = u.id AND s.school_id IS NULL;

-- 4.11 suggestion_replies from suggestions
UPDATE public.suggestion_replies sr
SET school_id = s.school_id
FROM public.suggestions s
WHERE sr.suggestion_id = s.id AND sr.school_id IS NULL;

-- 4.12 announcements_class from classes
UPDATE public.announcements_class ac
SET school_id = c.school_id
FROM public.classes c
WHERE ac.class_id = c.id AND ac.school_id IS NULL;

-- 4.13 floors from buildings
UPDATE public.floors f
SET school_id = b.school_id
FROM public.buildings b
WHERE f.building_id = b.id AND f.school_id IS NULL;

-- 4.14 rooms from floors
UPDATE public.rooms r
SET school_id = f.school_id
FROM public.floors f
WHERE r.floor_id = f.id AND r.school_id IS NULL;

-- Fallback backfill for any orphaned rows using the primary school
DO $$
DECLARE
    v_first_school_id UUID;
BEGIN
    SELECT id INTO v_first_school_id FROM public.schools ORDER BY created_at ASC LIMIT 1;
    IF v_first_school_id IS NOT NULL THEN
        UPDATE public.enrollments SET school_id = v_first_school_id WHERE school_id IS NULL;
        UPDATE public.groups SET school_id = v_first_school_id WHERE school_id IS NULL;
        UPDATE public.subject_offerings SET school_id = v_first_school_id WHERE school_id IS NULL;
        UPDATE public.grade_components SET school_id = v_first_school_id WHERE school_id IS NULL;
        UPDATE public.grades SET school_id = v_first_school_id WHERE school_id IS NULL;
        UPDATE public.absence_records SET school_id = v_first_school_id WHERE school_id IS NULL;
        UPDATE public.payment_plans SET school_id = v_first_school_id WHERE school_id IS NULL;
        UPDATE public.payments SET school_id = v_first_school_id WHERE school_id IS NULL;
        UPDATE public.timetable_slots SET school_id = v_first_school_id WHERE school_id IS NULL;
        UPDATE public.suggestions SET school_id = v_first_school_id WHERE school_id IS NULL;
        UPDATE public.suggestion_replies SET school_id = v_first_school_id WHERE school_id IS NULL;
        UPDATE public.announcements_class SET school_id = v_first_school_id WHERE school_id IS NULL;
        UPDATE public.floors SET school_id = v_first_school_id WHERE school_id IS NULL;
        UPDATE public.rooms SET school_id = v_first_school_id WHERE school_id IS NULL;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- STEP 5: AUTOMATIC school_id POPULATION TRIGGERS
-- ----------------------------------------------------------------------------
-- Prevents missing school_id bugs when legacy client code inserts new records.

CREATE OR REPLACE FUNCTION public.trg_auto_populate_school_id()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NEW.school_id IS NULL THEN
        NEW.school_id := public.get_user_school_id();
    END IF;
    RETURN NEW;
END;
$$;

DO $$
DECLARE
    t TEXT;
    tbls TEXT[] := ARRAY[
        'enrollments', 'groups', 'subject_offerings', 'grade_components', 
        'grades', 'absence_records', 'payment_plans', 'payments', 
        'timetable_slots', 'suggestions', 'suggestion_replies', 
        'announcements_class', 'floors', 'rooms'
    ];
BEGIN
    FOREACH t IN ARRAY tbls LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_set_school_id_%I ON public.%I', t, t);
        EXECUTE format('CREATE TRIGGER trg_set_school_id_%I BEFORE INSERT ON public.%I FOR EACH ROW EXECUTE FUNCTION public.trg_auto_populate_school_id()', t, t);
    END LOOP;
END $$;

-- ----------------------------------------------------------------------------
-- STEP 6: AUDIT LOGS TABLE & TRIGGER
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID REFERENCES public.schools(id) ON DELETE CASCADE,
    actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    actor_role TEXT NOT NULL DEFAULT 'unknown',
    action TEXT NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
    target_table TEXT NOT NULL,
    target_id UUID,
    old_data JSONB,
    new_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs_school ON public.audit_logs(school_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_target ON public.audit_logs(target_table, target_id);

CREATE OR REPLACE FUNCTION public.process_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_school_id UUID;
    v_actor_id UUID := auth.uid();
    v_actor_role TEXT := public.get_user_role();
    v_target_id UUID;
    v_old JSONB := NULL;
    v_new JSONB := NULL;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_target_id := OLD.id;
        v_school_id := OLD.school_id;
        v_old := to_jsonb(OLD);
    ELSIF TG_OP = 'UPDATE' THEN
        v_target_id := NEW.id;
        v_school_id := NEW.school_id;
        v_old := to_jsonb(OLD);
        v_new := to_jsonb(NEW);
    ELSIF TG_OP = 'INSERT' THEN
        v_target_id := NEW.id;
        v_school_id := NEW.school_id;
        v_new := to_jsonb(NEW);
    END IF;

    IF v_school_id IS NULL THEN
        v_school_id := public.get_user_school_id();
    END IF;

    INSERT INTO public.audit_logs (
        school_id, actor_id, actor_role, action, target_table, target_id, old_data, new_data
    ) VALUES (
        v_school_id, v_actor_id, COALESCE(v_actor_role, 'system'), TG_OP, TG_TABLE_NAME, v_target_id, v_old, v_new
    );

    RETURN COALESCE(NEW, OLD);
END;
$$;

-- Attach audit log triggers to sensitive tables
DROP TRIGGER IF EXISTS trg_audit_grades ON public.grades;
CREATE TRIGGER trg_audit_grades
    AFTER INSERT OR UPDATE OR DELETE ON public.grades
    FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

DROP TRIGGER IF EXISTS trg_audit_payments ON public.payments;
CREATE TRIGGER trg_audit_payments
    AFTER INSERT OR UPDATE OR DELETE ON public.payments
    FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

DROP TRIGGER IF EXISTS trg_audit_users ON public.users;
CREATE TRIGGER trg_audit_users
    AFTER INSERT OR UPDATE OR DELETE ON public.users
    FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

-- ----------------------------------------------------------------------------
-- STEP 7: DROP INSECURE / PERMISSIVE POLICIES
-- ----------------------------------------------------------------------------

-- Drop the cross-tenant data leak policy
DROP POLICY IF EXISTS "authenticated_read_users" ON public.users;
DROP POLICY IF EXISTS "admins_read_all_users" ON public.users;
DROP POLICY IF EXISTS "users_read_own" ON public.users;
DROP POLICY IF EXISTS "users_update_own" ON public.users;
DROP POLICY IF EXISTS "admins_insert_users" ON public.users;
DROP POLICY IF EXISTS "admins_delete_users" ON public.users;

-- Drop previous policies on tenant tables
DROP POLICY IF EXISTS "users_see_own_school" ON public.schools;
DROP POLICY IF EXISTS "admins_manage_schools" ON public.schools;
DROP POLICY IF EXISTS "users_see_own_enrollments" ON public.enrollments;
DROP POLICY IF EXISTS "admins_manage_enrollments" ON public.enrollments;
DROP POLICY IF EXISTS "users_see_enrolled_classes" ON public.classes;
DROP POLICY IF EXISTS "admins_manage_classes" ON public.classes;
DROP POLICY IF EXISTS "users_see_class_groups" ON public.groups;
DROP POLICY IF EXISTS "admins_manage_groups" ON public.groups;
DROP POLICY IF EXISTS "all_see_subjects" ON public.subjects;
DROP POLICY IF EXISTS "admins_manage_subjects" ON public.subjects;
DROP POLICY IF EXISTS "all_see_subject_offerings" ON public.subject_offerings;
DROP POLICY IF EXISTS "admins_manage_subject_offerings" ON public.subject_offerings;
DROP POLICY IF EXISTS "all_see_grade_components" ON public.grade_components;
DROP POLICY IF EXISTS "admins_manage_grade_components" ON public.grade_components;
DROP POLICY IF EXISTS "users_see_own_grades" ON public.grades;
DROP POLICY IF EXISTS "staff_manage_grades" ON public.grades;
DROP POLICY IF EXISTS "users_see_own_absences" ON public.absence_records;
DROP POLICY IF EXISTS "staff_manage_absences" ON public.absence_records;
DROP POLICY IF EXISTS "all_see_payment_plans" ON public.payment_plans;
DROP POLICY IF EXISTS "admins_manage_payment_plans" ON public.payment_plans;
DROP POLICY IF EXISTS "users_see_own_payments" ON public.payments;
DROP POLICY IF EXISTS "admins_manage_payments" ON public.payments;
DROP POLICY IF EXISTS "all_see_global_announcements" ON public.announcements_global;
DROP POLICY IF EXISTS "admins_manage_global_announcements" ON public.announcements_global;
DROP POLICY IF EXISTS "users_see_class_announcements" ON public.announcements_class;
DROP POLICY IF EXISTS "staff_manage_class_announcements" ON public.announcements_class;
DROP POLICY IF EXISTS "users_manage_own_suggestions" ON public.suggestions;
DROP POLICY IF EXISTS "users_see_suggestion_replies" ON public.suggestion_replies;
DROP POLICY IF EXISTS "admins_manage_suggestion_replies" ON public.suggestion_replies;
DROP POLICY IF EXISTS "users_see_class_timetable" ON public.timetable_slots;
DROP POLICY IF EXISTS "admins_manage_timetable" ON public.timetable_slots;
DROP POLICY IF EXISTS "users_see_documents" ON public.documents;
DROP POLICY IF EXISTS "admins_manage_documents" ON public.documents;
DROP POLICY IF EXISTS "all_see_academic_years" ON public.academic_years;
DROP POLICY IF EXISTS "admins_manage_academic_years" ON public.academic_years;
DROP POLICY IF EXISTS "all_see_semesters" ON public.semesters;
DROP POLICY IF EXISTS "admins_manage_semesters" ON public.semesters;
DROP POLICY IF EXISTS "authenticated_read_buildings" ON public.buildings;
DROP POLICY IF EXISTS "admins_manage_buildings" ON public.buildings;
DROP POLICY IF EXISTS "authenticated_read_floors" ON public.floors;
DROP POLICY IF EXISTS "admins_manage_floors" ON public.floors;
DROP POLICY IF EXISTS "authenticated_read_rooms" ON public.rooms;
DROP POLICY IF EXISTS "admins_manage_rooms" ON public.rooms;

-- ----------------------------------------------------------------------------
-- STEP 8: REWRITE AIRTIGHT MULTI-TENANT RLS POLICIES
-- ----------------------------------------------------------------------------

-- ==================== 8.1 USERS ====================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Select: Read own profile, or same school members, or super_admin
CREATE POLICY "users_select_tenant_isolation" ON public.users
    FOR SELECT TO authenticated
    USING (
        id = auth.uid()
        OR public.is_super_admin()
        OR (school_id = public.get_user_school_id() AND school_id IS NOT NULL)
    );

-- Insert: Super admin or school admin inserting into their own school
CREATE POLICY "users_insert_tenant_isolation" ON public.users
    FOR INSERT TO authenticated
    WITH CHECK (
        public.is_super_admin()
        OR (public.is_school_admin() AND school_id = public.get_user_school_id())
    );

-- Update: Update own profile, or school admin updating user in own school, or super_admin
CREATE POLICY "users_update_tenant_isolation" ON public.users
    FOR UPDATE TO authenticated
    USING (
        id = auth.uid()
        OR public.is_super_admin()
        OR (public.is_school_admin() AND school_id = public.get_user_school_id())
    )
    WITH CHECK (
        id = auth.uid()
        OR public.is_super_admin()
        OR (public.is_school_admin() AND school_id = public.get_user_school_id())
    );

-- Delete: Super admin or school admin deleting user in own school
CREATE POLICY "users_delete_tenant_isolation" ON public.users
    FOR DELETE TO authenticated
    USING (
        public.is_super_admin()
        OR (public.is_school_admin() AND school_id = public.get_user_school_id())
    );

-- ==================== 8.2 SCHOOLS ====================
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;

CREATE POLICY "schools_select_tenant_isolation" ON public.schools
    FOR SELECT TO authenticated
    USING (
        id = public.get_user_school_id()
        OR public.is_super_admin()
    );

CREATE POLICY "schools_manage_super_admin_only" ON public.schools
    FOR ALL TO authenticated
    USING (public.is_super_admin())
    WITH CHECK (public.is_super_admin());

-- ==================== 8.3 ACADEMIC YEARS & SEMESTERS ====================
ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.semesters ENABLE ROW LEVEL SECURITY;

CREATE POLICY "academic_years_select_tenant" ON public.academic_years
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "academic_years_manage_tenant" ON public.academic_years
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

CREATE POLICY "semesters_select_tenant" ON public.semesters
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "semesters_manage_tenant" ON public.semesters
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

-- ==================== 8.4 CLASSES & GROUPS ====================
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;

CREATE POLICY "classes_select_tenant" ON public.classes
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "classes_manage_tenant" ON public.classes
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

CREATE POLICY "groups_select_tenant" ON public.groups
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "groups_manage_tenant" ON public.groups
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

-- ==================== 8.5 ENROLLMENTS ====================
ALTER TABLE public.enrollments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "enrollments_select_tenant" ON public.enrollments
    FOR SELECT TO authenticated
    USING (
        (user_id = auth.uid() AND school_id = public.get_user_school_id())
        OR (public.get_user_role() IN ('teacher', 'staff', 'admin', 'owner') AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    );

CREATE POLICY "enrollments_manage_tenant" ON public.enrollments
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

-- ==================== 8.6 SUBJECTS & OFFERINGS ====================
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subject_offerings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grade_components ENABLE ROW LEVEL SECURITY;

CREATE POLICY "subjects_select_tenant" ON public.subjects
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "subjects_manage_tenant" ON public.subjects
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

CREATE POLICY "subject_offerings_select_tenant" ON public.subject_offerings
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "subject_offerings_manage_tenant" ON public.subject_offerings
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

CREATE POLICY "grade_components_select_tenant" ON public.grade_components
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "grade_components_manage_tenant" ON public.grade_components
    FOR ALL TO authenticated
    USING (
        ((public.is_school_admin() OR public.get_user_role() = 'teacher') AND school_id = public.get_user_school_id()) 
        OR public.is_super_admin()
    )
    WITH CHECK (
        ((public.is_school_admin() OR public.get_user_role() = 'teacher') AND school_id = public.get_user_school_id()) 
        OR public.is_super_admin()
    );

-- ==================== 8.7 GRADES & ABSENCES ====================
ALTER TABLE public.grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.absence_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.absence_thresholds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "grades_select_tenant" ON public.grades
    FOR SELECT TO authenticated
    USING (
        (enrollment_id IN (SELECT id FROM public.enrollments WHERE user_id = auth.uid()) AND school_id = public.get_user_school_id())
        OR (public.get_user_role() IN ('teacher', 'staff', 'admin', 'owner') AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    );

CREATE POLICY "grades_manage_tenant" ON public.grades
    FOR ALL TO authenticated
    USING (
        ((public.is_school_admin() OR public.get_user_role() = 'teacher') AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    )
    WITH CHECK (
        ((public.is_school_admin() OR public.get_user_role() = 'teacher') AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    );

CREATE POLICY "absences_select_tenant" ON public.absence_records
    FOR SELECT TO authenticated
    USING (
        (enrollment_id IN (SELECT id FROM public.enrollments WHERE user_id = auth.uid()) AND school_id = public.get_user_school_id())
        OR (public.get_user_role() IN ('teacher', 'staff', 'admin', 'owner') AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    );

CREATE POLICY "absences_manage_tenant" ON public.absence_records
    FOR ALL TO authenticated
    USING (
        ((public.is_school_admin() OR public.get_user_role() = 'teacher') AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    )
    WITH CHECK (
        ((public.is_school_admin() OR public.get_user_role() = 'teacher') AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    );

CREATE POLICY "absence_thresholds_select_tenant" ON public.absence_thresholds
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "absence_thresholds_manage_tenant" ON public.absence_thresholds
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

-- ==================== 8.8 PAYMENTS & PAYMENT PLANS ====================
ALTER TABLE public.payment_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "payment_plans_select_tenant" ON public.payment_plans
    FOR SELECT TO authenticated
    USING (
        (school_id = public.get_user_school_id() AND (
            public.is_school_admin() 
            OR enrollment_id IN (SELECT id FROM public.enrollments WHERE user_id = auth.uid())
        ))
        OR public.is_super_admin()
    );

CREATE POLICY "payment_plans_manage_tenant" ON public.payment_plans
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

CREATE POLICY "payments_select_tenant" ON public.payments
    FOR SELECT TO authenticated
    USING (
        (school_id = public.get_user_school_id() AND (
            public.is_school_admin() 
            OR payment_plan_id IN (
                SELECT pp.id FROM public.payment_plans pp
                JOIN public.enrollments e ON pp.enrollment_id = e.id
                WHERE e.user_id = auth.uid()
            )
        ))
        OR public.is_super_admin()
    );

CREATE POLICY "payments_manage_tenant" ON public.payments
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

-- ==================== 8.9 TIMETABLES ====================
ALTER TABLE public.timetable_slots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "timetable_slots_select_tenant" ON public.timetable_slots
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "timetable_slots_manage_tenant" ON public.timetable_slots
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

-- ==================== 8.10 ANNOUNCEMENTS ====================
ALTER TABLE public.announcements_global ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements_class ENABLE ROW LEVEL SECURITY;

CREATE POLICY "announcements_global_select_tenant" ON public.announcements_global
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "announcements_global_manage_tenant" ON public.announcements_global
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

CREATE POLICY "announcements_class_select_tenant" ON public.announcements_class
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "announcements_class_manage_tenant" ON public.announcements_class
    FOR ALL TO authenticated
    USING (
        ((public.is_school_admin() OR public.get_user_role() = 'teacher') AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    )
    WITH CHECK (
        ((public.is_school_admin() OR public.get_user_role() = 'teacher') AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    );

-- ==================== 8.11 SUGGESTIONS & REPLIES ====================
ALTER TABLE public.suggestions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suggestion_replies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "suggestions_select_tenant" ON public.suggestions
    FOR SELECT TO authenticated
    USING (
        (student_id = auth.uid() AND school_id = public.get_user_school_id())
        OR (public.is_school_admin() AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    );

CREATE POLICY "suggestions_insert_tenant" ON public.suggestions
    FOR INSERT TO authenticated
    WITH CHECK (
        (student_id = auth.uid() AND school_id = public.get_user_school_id())
        OR (public.is_school_admin() AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    );

CREATE POLICY "suggestions_update_tenant" ON public.suggestions
    FOR UPDATE TO authenticated
    USING (
        (student_id = auth.uid() AND school_id = public.get_user_school_id())
        OR (public.is_school_admin() AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    )
    WITH CHECK (
        (student_id = auth.uid() AND school_id = public.get_user_school_id())
        OR (public.is_school_admin() AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    );

CREATE POLICY "suggestions_delete_tenant" ON public.suggestions
    FOR DELETE TO authenticated
    USING (
        (student_id = auth.uid() AND school_id = public.get_user_school_id())
        OR (public.is_school_admin() AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    );

CREATE POLICY "suggestion_replies_select_tenant" ON public.suggestion_replies
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "suggestion_replies_manage_tenant" ON public.suggestion_replies
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

-- ==================== 8.12 BUILDINGS, FLOORS, ROOMS ====================
ALTER TABLE public.buildings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.floors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY "buildings_select_tenant" ON public.buildings
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "buildings_manage_tenant" ON public.buildings
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

CREATE POLICY "floors_select_tenant" ON public.floors
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "floors_manage_tenant" ON public.floors
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

CREATE POLICY "rooms_select_tenant" ON public.rooms
    FOR SELECT TO authenticated
    USING (school_id = public.get_user_school_id() OR public.is_super_admin());

CREATE POLICY "rooms_manage_tenant" ON public.rooms
    FOR ALL TO authenticated
    USING ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin())
    WITH CHECK ((public.is_school_admin() AND school_id = public.get_user_school_id()) OR public.is_super_admin());

-- ==================== 8.13 AUDIT LOGS ====================
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "audit_logs_select_tenant" ON public.audit_logs
    FOR SELECT TO authenticated
    USING (
        (public.is_school_admin() AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    );

CREATE POLICY "audit_logs_insert_authenticated" ON public.audit_logs
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

-- Strict append-only: no updates or deletions allowed on audit_logs
CREATE POLICY "audit_logs_no_update" ON public.audit_logs
    FOR UPDATE TO authenticated
    USING (false);

CREATE POLICY "audit_logs_no_delete" ON public.audit_logs
    FOR DELETE TO authenticated
    USING (false);

-- ============================================================================
-- END OF MIGRATION 040
-- ============================================================================
