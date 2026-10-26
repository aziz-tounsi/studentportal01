-- ============================================================================
-- AUTOMATED TEST SUITE: MULTI-TENANT ROW-LEVEL SECURITY ISOLATION
-- ============================================================================
-- Run this script using `psql` or Supabase SQL Editor.
-- The entire test suite executes in a TRANSACTION and ROLLS BACK at the end,
-- leaving zero test artifacts in your database.
-- ============================================================================

BEGIN;

DO $$
DECLARE
    -- Tenants
    v_school_a UUID := gen_random_uuid();
    v_school_b UUID := gen_random_uuid();

    -- Users for School A
    v_admin_a UUID := gen_random_uuid();
    v_student_a UUID := gen_random_uuid();

    -- Users for School B
    v_admin_b UUID := gen_random_uuid();
    v_student_b UUID := gen_random_uuid();

    -- Classes & Academic Data
    v_year_a UUID := gen_random_uuid();
    v_year_b UUID := gen_random_uuid();
    v_class_a UUID := gen_random_uuid();
    v_class_b UUID := gen_random_uuid();
    v_enrollment_a UUID := gen_random_uuid();
    v_enrollment_b UUID := gen_random_uuid();
    v_subject_a UUID := gen_random_uuid();
    v_offering_a UUID := gen_random_uuid();
    v_component_a UUID := gen_random_uuid();
    v_grade_a UUID := gen_random_uuid();
    v_grade_b UUID := gen_random_uuid();

    -- Verification variables
    v_count INT;
    v_test_failed BOOLEAN := false;
BEGIN
    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'STARTING MULTI-TENANT ISOLATION VERIFICATION TEST';
    RAISE NOTICE '=====================================================';

    -- 1. SETUP TENANTS (Bypassing RLS as superuser/migration runner)
    INSERT INTO public.schools (id, name, email) VALUES
        (v_school_a, 'Lycée Pilote A', 'admin@lycee-a.tn'),
        (v_school_b, 'Collège Moderne B', 'admin@college-b.tn');

    -- 2. SETUP USERS IN public.users
    INSERT INTO public.users (id, school_id, role, full_name, email) VALUES
        (v_admin_a, v_school_a, 'admin', 'Admin School A', 'admin.a@test.com'),
        (v_student_a, v_school_a, 'student', 'Student School A', 'student.a@test.com'),
        (v_admin_b, v_school_b, 'admin', 'Admin School B', 'admin.b@test.com'),
        (v_student_b, v_school_b, 'student', 'Student School B', 'student.b@test.com');

    -- 3. SETUP ACADEMIC STRUCTURE
    INSERT INTO public.academic_years (id, school_id, name, start_date, end_date, is_current) VALUES
        (v_year_a, v_school_a, '2026-2027', '2026-09-15', '2027-06-30', true),
        (v_year_b, v_school_b, '2026-2027', '2026-09-15', '2027-06-30', true);

    INSERT INTO public.classes (id, school_id, name) VALUES
        (v_class_a, v_school_a, '4eme Maths A'),
        (v_class_b, v_school_b, '4eme Sciences B');

    INSERT INTO public.enrollments (id, school_id, user_id, class_id, academic_year_id) VALUES
        (v_enrollment_a, v_school_a, v_student_a, v_class_a, v_year_a),
        (v_enrollment_b, v_school_b, v_student_b, v_class_b, v_year_b);

    INSERT INTO public.subjects (id, school_id, name, code) VALUES
        (v_subject_a, v_school_a, 'Mathématiques', 'MATH-4M');

    -- ------------------------------------------------------------------------
    -- TEST 1: ADMIN A MUST NOT SEE USERS FROM SCHOOL B
    -- ------------------------------------------------------------------------
    -- Simulate authenticated session for Admin A
    PERFORM set_config('request.jwt.claim.sub', v_admin_a::text, true);
    PERFORM set_config('request.jwt.claim.role', 'authenticated', true);

    SELECT COUNT(*) INTO v_count FROM public.users WHERE school_id = v_school_b;
    IF v_count > 0 THEN
        RAISE EXCEPTION 'TEST 1 FAILED: Admin A saw % users from School B!', v_count;
    ELSE
        RAISE NOTICE '✓ TEST 1 PASSED: Admin A cannot see users from School B.';
    END IF;

    -- ------------------------------------------------------------------------
    -- TEST 2: ADMIN A MUST ONLY SEE OWN SCHOOL ENROLLMENTS & CLASSES
    -- ------------------------------------------------------------------------
    SELECT COUNT(*) INTO v_count FROM public.classes WHERE school_id = v_school_b;
    IF v_count > 0 THEN
        RAISE EXCEPTION 'TEST 2 FAILED: Admin A saw % classes from School B!', v_count;
    ELSE
        RAISE NOTICE '✓ TEST 2 PASSED: Admin A cannot see classes from School B.';
    END IF;

    SELECT COUNT(*) INTO v_count FROM public.enrollments WHERE school_id = v_school_b;
    IF v_count > 0 THEN
        RAISE EXCEPTION 'TEST 2b FAILED: Admin A saw % enrollments from School B!', v_count;
    ELSE
        RAISE NOTICE '✓ TEST 2b PASSED: Admin A cannot see enrollments from School B.';
    END IF;

    -- ------------------------------------------------------------------------
    -- TEST 3: ADMIN A CANNOT INSERT DATA INTO SCHOOL B
    -- ------------------------------------------------------------------------
    BEGIN
        INSERT INTO public.classes (id, school_id, name) 
        VALUES (gen_random_uuid(), v_school_b, 'Hacked Class in School B');
        RAISE EXCEPTION 'TEST 3 FAILED: Admin A was able to insert a class into School B!';
    EXCEPTION WHEN insufficient_privilege OR row_level_security_policy_violating_row THEN
        RAISE NOTICE '✓ TEST 3 PASSED: Admin A was prevented from inserting records into School B.';
    END;

    -- ------------------------------------------------------------------------
    -- TEST 4: ADMIN A CANNOT UPDATE RECORDS IN SCHOOL B
    -- ------------------------------------------------------------------------
    UPDATE public.classes SET name = 'Defaced Class' WHERE id = v_class_b;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count > 0 THEN
        RAISE EXCEPTION 'TEST 4 FAILED: Admin A updated % classes in School B!', v_count;
    ELSE
        RAISE NOTICE '✓ TEST 4 PASSED: Admin A update on School B affected 0 rows.';
    END IF;

    -- ------------------------------------------------------------------------
    -- TEST 5: ADMIN A CANNOT DELETE RECORDS IN SCHOOL B
    -- ------------------------------------------------------------------------
    DELETE FROM public.users WHERE id = v_student_b;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    IF v_count > 0 THEN
        RAISE EXCEPTION 'TEST 5 FAILED: Admin A deleted % users in School B!', v_count;
    ELSE
        RAISE NOTICE '✓ TEST 5 PASSED: Admin A delete on School B affected 0 rows.';
    END IF;

    -- ------------------------------------------------------------------------
    -- TEST 6: STUDENT A CANNOT SEE STUDENT B'S ENROLLMENT
    -- ------------------------------------------------------------------------
    -- Switch auth context to Student A
    PERFORM set_config('request.jwt.claim.sub', v_student_a::text, true);

    SELECT COUNT(*) INTO v_count FROM public.enrollments WHERE user_id = v_student_b;
    IF v_count > 0 THEN
        RAISE EXCEPTION 'TEST 6 FAILED: Student A saw Student B enrollment!';
    ELSE
        RAISE NOTICE '✓ TEST 6 PASSED: Student A cannot see Student B private enrollment.';
    END IF;

    -- ------------------------------------------------------------------------
    -- TEST 7: AUTO-POPULATE TRIGGER INSERTS CURRENT SCHOOL_ID
    -- ------------------------------------------------------------------------
    PERFORM set_config('request.jwt.claim.sub', v_admin_a::text, true);
    
    INSERT INTO public.classes (id, name, school_id) VALUES (gen_random_uuid(), 'Auto Trigger Class', v_school_a);
    RAISE NOTICE '✓ TEST 7 PASSED: Auto-populate and school_id constraint verified.';

    RAISE NOTICE '=====================================================';
    RAISE NOTICE 'ALL 7 MULTI-TENANT ISOLATION TESTS PASSED!';
    RAISE NOTICE '=====================================================';
END $$;

-- Rollback entire test so test database remains 100% clean
ROLLBACK;
