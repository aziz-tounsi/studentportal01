-- =================================================================
-- 039: REPAIR AUTH USERS, TOKENS, PASSWORDS AND IDENTITIES
-- Fixes "Database error querying schema" (HTTP 500 on login)
-- =================================================================

-- 1. Reset any empty string phone back to NULL (to satisfy UNIQUE constraint "users_phone_key")
UPDATE auth.users
SET phone = NULL
WHERE phone = '';

-- 2. Fix all NULL token and boolean columns in auth.users so GoTrue stops crashing
UPDATE auth.users
SET 
    instance_id = '00000000-0000-0000-0000-000000000000'::uuid,
    aud = 'authenticated',
    role = 'authenticated',
    is_super_admin = COALESCE(is_super_admin, FALSE),
    is_sso_user = COALESCE(is_sso_user, FALSE),
    is_anonymous = COALESCE(is_anonymous, FALSE),
    confirmation_token = COALESCE(confirmation_token, ''),
    email_change = COALESCE(email_change, ''),
    email_change_token_new = COALESCE(email_change_token_new, ''),
    email_change_token_current = COALESCE(email_change_token_current, ''),
    recovery_token = COALESCE(recovery_token, ''),
    phone_change = COALESCE(phone_change, ''),
    phone_change_token = COALESCE(phone_change_token, ''),
    reauthentication_token = COALESCE(reauthentication_token, ''),
    email_change_confirm_status = COALESCE(email_change_confirm_status, 0),
    email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE 
    instance_id IS NULL 
    OR aud IS NULL
    OR role IS NULL
    OR confirmation_token IS NULL 
    OR email_change IS NULL 
    OR email_change_token_new IS NULL 
    OR recovery_token IS NULL 
    OR phone_change IS NULL 
    OR reauthentication_token IS NULL
    OR is_sso_user IS NULL
    OR is_anonymous IS NULL;

-- 3. Sync encrypted_password with initial_password for all students
-- This ensures passwords like 3EYt5Qa5QJU& and SC5pYJ@vN&z3 work immediately!
UPDATE auth.users a
SET encrypted_password = crypt(u.initial_password, gen_salt('bf'))
FROM public.users u
WHERE a.id = u.id AND u.initial_password IS NOT NULL AND u.initial_password != '';

-- 4. Clean up any duplicate identities per user before linking
DELETE FROM auth.identities
WHERE id IN (
    SELECT id
    FROM (
        SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id, provider ORDER BY created_at DESC) as rn
        FROM auth.identities
    ) sub
    WHERE rn > 1
);

-- 5. Safely update provider_id to user_id for email provider where not already taken
UPDATE auth.identities
SET provider_id = user_id::text
WHERE provider = 'email'
  AND provider_id != user_id::text
  AND NOT EXISTS (
      SELECT 1 FROM auth.identities i2 
      WHERE i2.provider = 'email' AND i2.provider_id = auth.identities.user_id::text
  );

-- Remove any remaining invalid duplicates
DELETE FROM auth.identities
WHERE provider = 'email' AND provider_id != user_id::text;

-- 6. Create missing identities for any user that lacks one
INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
)
SELECT
    u.id,
    u.id,
    jsonb_build_object('sub', u.id::text, 'email', u.email),
    'email',
    u.id::text,
    NOW(),
    NOW(),
    NOW()
FROM auth.users u
WHERE NOT EXISTS (
    SELECT 1 FROM auth.identities i 
    WHERE i.user_id = u.id OR (i.provider = 'email' AND i.provider_id = u.id::text)
)
ON CONFLICT (provider, provider_id) DO NOTHING;
