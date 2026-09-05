-- ============================================
-- DIAGNOSTIC: Compare student counts across the app
-- Run this to see WHERE students exist and WHERE they don't
-- ============================================

-- 1. Total students in auth.users
SELECT 'auth.users (total)' AS source, COUNT(*) AS count
FROM auth.users
WHERE email LIKE '%@student.pythagore.tn'
UNION ALL

-- 2. Total students in public.users
SELECT 'public.users (role=student)', COUNT(*)
FROM users
WHERE role = 'student'
UNION ALL

-- 3. Students with active enrollments
SELECT 'enrollments (active)', COUNT(DISTINCT user_id)
FROM enrollments
WHERE is_active = TRUE
UNION ALL

-- 4. Students with payment plans (what payments page sees)
SELECT 'payment_plans (has enrollment)', COUNT(DISTINCT pp.enrollment_id)
FROM payment_plans pp
JOIN enrollments e ON e.id = pp.enrollment_id
UNION ALL

-- 5. Students visible in grades/results
SELECT 'grades (has student)', COUNT(DISTINCT g.student_id)
FROM grades g
WHERE g.student_id IS NOT NULL
UNION ALL

-- 6. Students visible in absences
SELECT 'absence_records (has student)', COUNT(DISTINCT ar.student_id)
FROM absence_records ar
WHERE ar.student_id IS NOT NULL
UNION ALL

-- 7. Students with suggestions
SELECT 'suggestions (has student)', COUNT(DISTINCT s.student_id)
FROM suggestions s
UNION ALL

-- 8. Students with user_settings
SELECT 'user_settings (has user)', COUNT(*)
FROM user_settings
UNION ALL

-- 9. Active subject_offerings (classes with subjects)
SELECT 'subject_offerings (active classes)', COUNT(DISTINCT so.class_id)
FROM subject_offerings so
WHERE so.is_active = TRUE
UNION ALL

-- 10. Classes with timetable slots
SELECT 'timetable_slots (groups)', COUNT(DISTINCT ts.group_id)
FROM timetable_slots ts;

-- ============================================
-- DETAILED: Students per class
-- ============================================
SELECT
    c.name AS class_name,
    (SELECT COUNT(*) FROM enrollments e WHERE e.class_id = c.id AND e.is_active = TRUE) AS enrolled,
    (SELECT COUNT(DISTINCT pp.enrollment_id)
     FROM payment_plans pp
     JOIN enrollments e ON e.id = pp.enrollment_id
     WHERE e.class_id = c.id) AS with_payments,
    (SELECT COUNT(DISTINCT g.student_id)
     FROM grades g
     JOIN enrollments e ON e.id = g.enrollment_id
     WHERE e.class_id = c.id) AS with_grades,
    (SELECT COUNT(DISTINCT ar.student_id)
     FROM absence_records ar
     JOIN enrollments e ON e.id = ar.enrollment_id
     WHERE e.class_id = c.id) AS with_absences
FROM classes c
WHERE c.is_active = TRUE
ORDER BY c.name;

-- ============================================
-- MISSING DATA: Students without key records
-- ============================================
SELECT
    u.full_name,
    u.email,
    (SELECT COUNT(*) FROM enrollments e WHERE e.user_id = u.id AND e.is_active = TRUE) AS enrollments,
    (SELECT COUNT(*) FROM payment_plans pp
     JOIN enrollments e ON e.id = pp.enrollment_id
     WHERE e.user_id = u.id) AS payment_plans,
    (SELECT COUNT(*) FROM grades g WHERE g.student_id = u.id) AS grades,
    (SELECT COUNT(*) FROM absence_records ar WHERE ar.student_id = u.id) AS absences,
    (SELECT COUNT(*) FROM suggestions s WHERE s.student_id = u.id) AS suggestions,
    (SELECT COUNT(*) FROM user_settings us WHERE us.user_id = u.id) AS settings
FROM users u
WHERE u.role = 'student' AND u.is_active = TRUE
ORDER BY u.full_name
LIMIT 50;
