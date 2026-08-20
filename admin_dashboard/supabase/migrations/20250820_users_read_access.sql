-- Allow authenticated users to read from users table (for teacher names/photos in timetable joins)
DO $$
BEGIN
    -- Check if users table has RLS enabled
    IF NOT EXISTS (
        SELECT 1 FROM pg_tables 
        WHERE tablename = 'users' AND schemaname = 'public' AND rowsecurity = true
    ) THEN
        ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
    END IF;

    -- Drop existing restrictive policies if any
    DROP POLICY IF EXISTS "authenticated_read_users" ON public.users;

    -- Allow all authenticated users to read basic user info (needed for timetable teacher joins)
    CREATE POLICY "authenticated_read_users" ON public.users
        FOR SELECT TO authenticated
        USING (true);

    RAISE NOTICE 'Added authenticated_read_users policy';
EXCEPTION
    WHEN others THEN
        RAISE NOTICE 'Error: %', SQLERRM;
END $$;
