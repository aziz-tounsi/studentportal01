-- ============================================
-- REPAIR: Fix school_id for seeded test students
-- Run this if students appear on Payments page
-- but NOT on Users page
-- ============================================

-- 1. First, see the mismatch
SELECT
    'admin' AS role,
    u.full_name,
    u.email,
    u.school_id
FROM users u
WHERE u.role = 'admin' AND u.is_active = TRUE

UNION ALL

SELECT
    'student' AS role,
    u.full_name,
    u.email,
    u.school_id
FROM users u
WHERE u.role = 'student'
  AND (u.email LIKE '%@student.pythagore.tn' OR u.email LIKE '%@school.tn')
ORDER BY role, full_name
LIMIT 50;

-- 2. Fix school_id for seeded test students
WITH admin_school AS (
    SELECT school_id
    FROM users
    WHERE role = 'admin' AND is_active = TRUE
    ORDER BY created_at
    LIMIT 1
)
UPDATE users
SET school_id = (SELECT school_id FROM admin_school)
WHERE role = 'student'
  AND school_id IS DISTINCT FROM (SELECT school_id FROM admin_school)
  AND (email LIKE '%@student.pythagore.tn' OR email LIKE '%@school.tn');

-- 3. Verify the fix
SELECT
    u.school_id,
    COUNT(*) AS student_count
FROM users u
WHERE u.role = 'student'
GROUP BY u.school_id;
