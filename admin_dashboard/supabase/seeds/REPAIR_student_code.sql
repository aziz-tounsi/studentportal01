-- ============================================
-- REPAIR: Copy student_code from enrollments to users
-- For seeded test students where users.student_code is NULL
-- ============================================

-- 1. See students missing student_code in users table
SELECT u.id, u.full_name, u.email, u.student_code, e.student_code AS enrollment_code
FROM users u
JOIN enrollments e ON e.user_id = u.id AND e.is_active = TRUE
WHERE u.role = 'student'
  AND (u.student_code IS NULL OR u.student_code = '')
  AND (u.email LIKE '%@student.pythagore.tn' OR u.email LIKE '%@school.tn')
LIMIT 50;

-- 2. Copy enrollment student_code to users.student_code
UPDATE users u
SET student_code = e.student_code
FROM enrollments e
WHERE e.user_id = u.id
  AND e.is_active = TRUE
  AND u.role = 'student'
  AND (u.student_code IS NULL OR u.student_code = '')
  AND (u.email LIKE '%@student.pythagore.tn' OR u.email LIKE '%@school.tn');

-- 3. Verify
SELECT
    CASE WHEN u.student_code IS NULL OR u.student_code = '' THEN 'missing' ELSE 'has_code' END AS status,
    COUNT(*) AS count
FROM users u
WHERE u.role = 'student'
  AND (u.email LIKE '%@student.pythagore.tn' OR u.email LIKE '%@school.tn')
GROUP BY status;
