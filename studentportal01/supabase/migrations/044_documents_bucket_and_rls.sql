-- ============================================================================
-- MIGRATION 044: DOCUMENTS STORAGE BUCKET & TENANT RLS POLICIES
-- ============================================================================

-- 1. Ensure the public 'documents' storage bucket exists
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('documents', 'documents', true, 52428800)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 52428800;

-- 2. Storage RLS policies for 'documents' bucket
DROP POLICY IF EXISTS "Public read access for documents bucket" ON storage.objects;
CREATE POLICY "Public read access for documents bucket"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'documents');

DROP POLICY IF EXISTS "School staff can upload to documents bucket" ON storage.objects;
CREATE POLICY "School staff can upload to documents bucket"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'documents'
  AND EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND u.role::TEXT IN ('super_admin', 'owner', 'admin', 'staff', 'teacher')
  )
);

DROP POLICY IF EXISTS "School staff can update documents bucket objects" ON storage.objects;
CREATE POLICY "School staff can update documents bucket objects"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'documents'
  AND EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND u.role::TEXT IN ('super_admin', 'owner', 'admin', 'staff', 'teacher')
  )
);

DROP POLICY IF EXISTS "School staff can delete documents bucket objects" ON storage.objects;
CREATE POLICY "School staff can delete documents bucket objects"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'documents'
  AND EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND u.role::TEXT IN ('super_admin', 'owner', 'admin', 'staff', 'teacher')
  )
);

-- 3. Ensure tenant-isolated RLS policies exist on public.documents
ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "users_see_documents" ON public.documents;
DROP POLICY IF EXISTS "admins_manage_documents" ON public.documents;
DROP POLICY IF EXISTS "documents_select_tenant" ON public.documents;
DROP POLICY IF EXISTS "documents_manage_tenant" ON public.documents;

CREATE POLICY "documents_select_tenant" ON public.documents
  FOR SELECT TO authenticated
  USING (
    school_id = (SELECT u.school_id FROM public.users u WHERE u.id = auth.uid() LIMIT 1)
    OR EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role::TEXT = 'super_admin'
    )
  );

CREATE POLICY "documents_manage_tenant" ON public.documents
  FOR ALL TO authenticated
  USING (
    (
      school_id = (SELECT u.school_id FROM public.users u WHERE u.id = auth.uid() LIMIT 1)
      AND EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.role::TEXT IN ('super_admin', 'owner', 'admin', 'staff', 'teacher')
      )
    )
    OR EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role::TEXT = 'super_admin'
    )
  )
  WITH CHECK (
    (
      school_id = (SELECT u.school_id FROM public.users u WHERE u.id = auth.uid() LIMIT 1)
      AND EXISTS (
        SELECT 1 FROM public.users u
        WHERE u.id = auth.uid() AND u.role::TEXT IN ('super_admin', 'owner', 'admin', 'staff', 'teacher')
      )
    )
    OR EXISTS (
      SELECT 1 FROM public.users u
      WHERE u.id = auth.uid() AND u.role::TEXT = 'super_admin'
    )
  );
