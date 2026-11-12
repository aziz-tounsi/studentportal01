-- Migration 049: Multi-tenant SaaS school logo management & RLS permissions
-- Allows Super Admin (any school) AND each school's own owner/admin/staff (own school only)
-- to manage school logo & info, while protecting SaaS-level columns (code, is_active).

-- 1. Allow school owner/admin/staff to update their own school's branding/profile
DROP POLICY IF EXISTS schools_owner_admin_update_own ON public.schools;
CREATE POLICY schools_owner_admin_update_own ON public.schools
    FOR UPDATE TO authenticated
    USING (
        id = public.get_user_school_id()
        AND EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
              AND u.role::text IN ('owner', 'admin', 'staff')
        )
    )
    WITH CHECK (
        id = public.get_user_school_id()
        AND EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid()
              AND u.role::text IN ('owner', 'admin', 'staff')
        )
    );

-- 2. Guard SaaS-controlled columns against non-super-admin mutation
CREATE OR REPLACE FUNCTION public.fn_guard_school_tenant_update()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF auth.uid() IS NOT NULL AND NOT public.is_super_admin() THEN
        IF NEW.id IS DISTINCT FROM OLD.id THEN
            RAISE EXCEPTION 'Cannot change school id';
        END IF;
        IF NEW.code IS DISTINCT FROM OLD.code THEN
            RAISE EXCEPTION 'Only platform super admin can change school code';
        END IF;
        IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
            RAISE EXCEPTION 'Only platform super admin can change school active status';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_school_tenant_update ON public.schools;
CREATE TRIGGER trg_guard_school_tenant_update
    BEFORE UPDATE ON public.schools
    FOR EACH ROW EXECUTE FUNCTION public.fn_guard_school_tenant_update();

-- 3. Ensure staff/owner/admin/super_admin can update & delete logo objects in profiles bucket
DROP POLICY IF EXISTS "School admins can update school logos" ON storage.objects;
CREATE POLICY "School admins can update school logos"
ON storage.objects FOR UPDATE TO authenticated
USING (
    bucket_id = 'profiles'
    AND (storage.foldername(name))[1] = 'logos'
    AND EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND u.role::text IN ('super_admin', 'owner', 'admin', 'staff')
    )
)
WITH CHECK (
    bucket_id = 'profiles'
    AND (storage.foldername(name))[1] = 'logos'
);

DROP POLICY IF EXISTS "School admins can delete school logos" ON storage.objects;
CREATE POLICY "School admins can delete school logos"
ON storage.objects FOR DELETE TO authenticated
USING (
    bucket_id = 'profiles'
    AND (storage.foldername(name))[1] = 'logos'
    AND EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid()
          AND u.role::text IN ('super_admin', 'owner', 'admin', 'staff')
    )
);

-- 4. Publish schools table updates to Realtime so student & admin apps refresh logos live
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime'
          AND schemaname = 'public'
          AND tablename = 'schools'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.schools;
    END IF;
END $$;
