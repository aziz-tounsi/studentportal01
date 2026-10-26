-- ============================================================================
-- ROLLBACK MIGRATION 040: MULTI-TENANT SECURITY CORE DOWN
-- ============================================================================

-- 1. Remove Audit Triggers & Table
DROP TRIGGER IF EXISTS trg_audit_grades ON public.grades;
DROP TRIGGER IF EXISTS trg_audit_payments ON public.payments;
DROP TRIGGER IF EXISTS trg_audit_users ON public.users;
DROP FUNCTION IF EXISTS public.process_audit_log();
DROP TABLE IF EXISTS public.audit_logs;

-- 2. Remove Auto-Populate Triggers
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
    END LOOP;
END $$;
DROP FUNCTION IF EXISTS public.trg_auto_populate_school_id();

-- 3. Drop Tenant-Isolated Policies
DROP POLICY IF EXISTS "users_select_tenant_isolation" ON public.users;
DROP POLICY IF EXISTS "users_insert_tenant_isolation" ON public.users;
DROP POLICY IF EXISTS "users_update_tenant_isolation" ON public.users;
DROP POLICY IF EXISTS "users_delete_tenant_isolation" ON public.users;
DROP POLICY IF EXISTS "schools_select_tenant_isolation" ON public.schools;
DROP POLICY IF EXISTS "schools_manage_super_admin_only" ON public.schools;
DROP POLICY IF EXISTS "academic_years_select_tenant" ON public.academic_years;
DROP POLICY IF EXISTS "academic_years_manage_tenant" ON public.academic_years;
DROP POLICY IF EXISTS "semesters_select_tenant" ON public.semesters;
DROP POLICY IF EXISTS "semesters_manage_tenant" ON public.semesters;
DROP POLICY IF EXISTS "classes_select_tenant" ON public.classes;
DROP POLICY IF EXISTS "classes_manage_tenant" ON public.classes;
DROP POLICY IF EXISTS "groups_select_tenant" ON public.groups;
DROP POLICY IF EXISTS "groups_manage_tenant" ON public.groups;
DROP POLICY IF EXISTS "enrollments_select_tenant" ON public.enrollments;
DROP POLICY IF EXISTS "enrollments_manage_tenant" ON public.enrollments;
DROP POLICY IF EXISTS "subjects_select_tenant" ON public.subjects;
DROP POLICY IF EXISTS "subjects_manage_tenant" ON public.subjects;
DROP POLICY IF EXISTS "subject_offerings_select_tenant" ON public.subject_offerings;
DROP POLICY IF EXISTS "subject_offerings_manage_tenant" ON public.subject_offerings;
DROP POLICY IF EXISTS "grade_components_select_tenant" ON public.grade_components;
DROP POLICY IF EXISTS "grade_components_manage_tenant" ON public.grade_components;
DROP POLICY IF EXISTS "grades_select_tenant" ON public.grades;
DROP POLICY IF EXISTS "grades_manage_tenant" ON public.grades;
DROP POLICY IF EXISTS "absences_select_tenant" ON public.absence_records;
DROP POLICY IF EXISTS "absences_manage_tenant" ON public.absence_records;
DROP POLICY IF EXISTS "absence_thresholds_select_tenant" ON public.absence_thresholds;
DROP POLICY IF EXISTS "absence_thresholds_manage_tenant" ON public.absence_thresholds;
DROP POLICY IF EXISTS "payment_plans_select_tenant" ON public.payment_plans;
DROP POLICY IF EXISTS "payment_plans_manage_tenant" ON public.payment_plans;
DROP POLICY IF EXISTS "payments_select_tenant" ON public.payments;
DROP POLICY IF EXISTS "payments_manage_tenant" ON public.payments;
DROP POLICY IF EXISTS "timetable_slots_select_tenant" ON public.timetable_slots;
DROP POLICY IF EXISTS "timetable_slots_manage_tenant" ON public.timetable_slots;
DROP POLICY IF EXISTS "announcements_global_select_tenant" ON public.announcements_global;
DROP POLICY IF EXISTS "announcements_global_manage_tenant" ON public.announcements_global;
DROP POLICY IF EXISTS "announcements_class_select_tenant" ON public.announcements_class;
DROP POLICY IF EXISTS "announcements_class_manage_tenant" ON public.announcements_class;
DROP POLICY IF EXISTS "suggestions_select_tenant" ON public.suggestions;
DROP POLICY IF EXISTS "suggestions_insert_tenant" ON public.suggestions;
DROP POLICY IF EXISTS "suggestions_update_tenant" ON public.suggestions;
DROP POLICY IF EXISTS "suggestions_delete_tenant" ON public.suggestions;
DROP POLICY IF EXISTS "suggestion_replies_select_tenant" ON public.suggestion_replies;
DROP POLICY IF EXISTS "suggestion_replies_manage_tenant" ON public.suggestion_replies;
DROP POLICY IF EXISTS "buildings_select_tenant" ON public.buildings;
DROP POLICY IF EXISTS "buildings_manage_tenant" ON public.buildings;
DROP POLICY IF EXISTS "floors_select_tenant" ON public.floors;
DROP POLICY IF EXISTS "floors_manage_tenant" ON public.floors;
DROP POLICY IF EXISTS "rooms_select_tenant" ON public.rooms;
DROP POLICY IF EXISTS "rooms_manage_tenant" ON public.rooms;

-- 4. Re-establish Basic Permissive Baseline
CREATE POLICY "users_read_own" ON public.users FOR SELECT USING (id = auth.uid());
CREATE POLICY "admins_read_all_users" ON public.users FOR SELECT USING (public.get_my_role() IN ('admin', 'staff'));
CREATE POLICY "users_update_own" ON public.users FOR UPDATE USING (id = auth.uid());
CREATE POLICY "admins_insert_users" ON public.users FOR INSERT WITH CHECK (public.get_my_role() IN ('admin', 'staff'));
CREATE POLICY "admins_delete_users" ON public.users FOR DELETE USING (public.get_my_role() = 'admin');

-- Note: school_id columns and indexes are left intact as safe additive metadata.
