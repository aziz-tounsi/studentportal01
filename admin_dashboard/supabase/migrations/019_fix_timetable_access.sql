-- ============================================================================
-- FIX TIMETABLE ACCESS FOR STUDENTS
-- This migration ensures students can access their class timetable
-- ============================================================================

-- STEP 1: Ensure get_my_role() function exists
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT COALESCE(
        (SELECT role::text FROM public.users WHERE id = auth.uid()),
        'anonymous'
    );
$$;

-- STEP 2: Create helper function to get student's class_id
CREATE OR REPLACE FUNCTION public.get_my_class_id()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT e.class_id 
    FROM enrollments e 
    WHERE e.user_id = auth.uid() 
    AND e.is_active = true
    LIMIT 1;
$$;

-- STEP 3: Fix subject_offerings RLS - allow all authenticated users to read
DO $$
BEGIN
    DROP POLICY IF EXISTS "all_see_subject_offerings" ON subject_offerings;
    DROP POLICY IF EXISTS "users_subject_offerings_select" ON subject_offerings;
    DROP POLICY IF EXISTS "admins_manage_subject_offerings" ON subject_offerings;
    
    ALTER TABLE subject_offerings ENABLE ROW LEVEL SECURITY;
    
    -- All authenticated users can read subject offerings
    CREATE POLICY "authenticated_read_subject_offerings" ON subject_offerings
        FOR SELECT TO authenticated
        USING (true);
    
    -- Admins can manage
    CREATE POLICY "admins_manage_subject_offerings" ON subject_offerings
        FOR ALL TO authenticated
        USING (public.get_my_role() IN ('admin', 'staff'))
        WITH CHECK (public.get_my_role() IN ('admin', 'staff'));

    RAISE NOTICE 'Fixed subject_offerings RLS policies';
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Error fixing subject_offerings RLS: %', SQLERRM;
END $$;

-- STEP 4: Fix timetable_slots RLS - students see their class timetable
DO $$
BEGIN
    DROP POLICY IF EXISTS "users_see_class_timetable" ON timetable_slots;
    DROP POLICY IF EXISTS "students_class_timetable_select" ON timetable_slots;
    DROP POLICY IF EXISTS "students_timetable_select" ON timetable_slots;
    DROP POLICY IF EXISTS "admins_manage_timetable" ON timetable_slots;
    DROP POLICY IF EXISTS "admin_manage_timetable" ON timetable_slots;
    
    ALTER TABLE timetable_slots ENABLE ROW LEVEL SECURITY;
    
    -- Students can read timetable slots for their class
    -- Using a simpler policy that checks via the get_my_class_id function
    CREATE POLICY "students_read_class_timetable" ON timetable_slots
        FOR SELECT TO authenticated
        USING (
            -- Check if the slot's subject_offering belongs to the student's class
            subject_offering_id IN (
                SELECT id FROM subject_offerings 
                WHERE class_id = public.get_my_class_id()
            )
            OR public.get_my_role() IN ('admin', 'staff', 'teacher')
        );
    
    -- Admins can manage all timetable slots
    CREATE POLICY "admins_manage_timetable" ON timetable_slots
        FOR ALL TO authenticated
        USING (public.get_my_role() IN ('admin', 'staff'))
        WITH CHECK (public.get_my_role() IN ('admin', 'staff'));

    RAISE NOTICE 'Fixed timetable_slots RLS policies';
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Error fixing timetable_slots RLS: %', SQLERRM;
END $$;

-- STEP 5: Fix subjects RLS - allow all authenticated to read
DO $$
BEGIN
    DROP POLICY IF EXISTS "all_see_subjects" ON subjects;
    DROP POLICY IF EXISTS "authenticated_read_subjects" ON subjects;
    
    ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
    
    -- All authenticated users can read subjects
    CREATE POLICY "authenticated_read_subjects" ON subjects
        FOR SELECT TO authenticated
        USING (true);
    
    -- Admins can manage
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'subjects' AND policyname = 'admins_manage_subjects'
    ) THEN
        CREATE POLICY "admins_manage_subjects" ON subjects
            FOR ALL TO authenticated
            USING (public.get_my_role() IN ('admin', 'staff'))
            WITH CHECK (public.get_my_role() IN ('admin', 'staff'));
    END IF;

    RAISE NOTICE 'Fixed subjects RLS policies';
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Error fixing subjects RLS: %', SQLERRM;
END $$;

-- STEP 6: Fix semesters RLS - allow all authenticated to read
DO $$
BEGIN
    DROP POLICY IF EXISTS "all_see_semesters" ON semesters;
    DROP POLICY IF EXISTS "authenticated_read_semesters" ON semesters;
    
    ALTER TABLE semesters ENABLE ROW LEVEL SECURITY;
    
    -- All authenticated users can read semesters
    CREATE POLICY "authenticated_read_semesters" ON semesters
        FOR SELECT TO authenticated
        USING (true);
    
    -- Admins can manage
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'semesters' AND policyname = 'admins_manage_semesters'
    ) THEN
        CREATE POLICY "admins_manage_semesters" ON semesters
            FOR ALL TO authenticated
            USING (public.get_my_role() IN ('admin', 'staff'))
            WITH CHECK (public.get_my_role() IN ('admin', 'staff'));
    END IF;

    RAISE NOTICE 'Fixed semesters RLS policies';
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Error fixing semesters RLS: %', SQLERRM;
END $$;

-- STEP 7: Diagnostic query - run this to check student enrollment
-- SELECT 
--     u.id, u.full_name, u.email, u.role,
--     e.class_id, c.name as class_name,
--     (SELECT COUNT(*) FROM timetable_slots ts 
--      JOIN subject_offerings so ON ts.subject_offering_id = so.id 
--      WHERE so.class_id = e.class_id) as timetable_count
-- FROM users u
-- LEFT JOIN enrollments e ON e.user_id = u.id AND e.is_active = true
-- LEFT JOIN classes c ON c.id = e.class_id
-- WHERE u.role = 'student'
-- ORDER BY u.full_name;

RAISE NOTICE 'Timetable access fix complete. Make sure students have active enrollments.';
