-- ============================================================================
-- MIGRATION 047: ANNOUNCEMENT ATTACHMENTS TABLE & STORAGE BUCKET
-- ============================================================================

-- 1. Create table for announcement attachments
CREATE TABLE IF NOT EXISTS public.announcement_attachments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    announcement_id UUID NOT NULL,
    scope TEXT NOT NULL DEFAULT 'global',
    file_name TEXT NOT NULL,
    display_name TEXT,
    file_url TEXT NOT NULL,
    file_type TEXT,
    file_size BIGINT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_announcement_attachments_announcement_id 
ON public.announcement_attachments(announcement_id);

ALTER TABLE public.announcement_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public select on announcement_attachments" ON public.announcement_attachments;
CREATE POLICY "Public select on announcement_attachments"
ON public.announcement_attachments FOR SELECT
TO authenticated
USING (true);

DROP POLICY IF EXISTS "Staff manage announcement_attachments" ON public.announcement_attachments;
CREATE POLICY "Staff manage announcement_attachments"
ON public.announcement_attachments FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role::text IN ('admin', 'staff', 'teacher', 'super_admin')
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role::text IN ('admin', 'staff', 'teacher', 'super_admin')
    )
);

-- 2. Create the public 'announcement-attachments' storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('announcement-attachments', 'announcement-attachments', true, 52428800)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 52428800;

-- 3. Storage RLS policies for 'announcement-attachments' bucket
DROP POLICY IF EXISTS "Public read access for announcement-attachments bucket" ON storage.objects;
CREATE POLICY "Public read access for announcement-attachments bucket"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'announcement-attachments');

DROP POLICY IF EXISTS "Staff can upload to announcement-attachments bucket" ON storage.objects;
CREATE POLICY "Staff can upload to announcement-attachments bucket"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'announcement-attachments'
  AND EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND u.role::TEXT IN ('super_admin', 'owner', 'admin', 'staff', 'teacher')
  )
);

DROP POLICY IF EXISTS "Staff can update announcement-attachments bucket objects" ON storage.objects;
CREATE POLICY "Staff can update announcement-attachments bucket objects"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'announcement-attachments'
  AND EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND u.role::TEXT IN ('super_admin', 'owner', 'admin', 'staff', 'teacher')
  )
);

DROP POLICY IF EXISTS "Staff can delete announcement-attachments bucket objects" ON storage.objects;
CREATE POLICY "Staff can delete announcement-attachments bucket objects"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'announcement-attachments'
  AND EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = auth.uid()
      AND u.role::TEXT IN ('super_admin', 'owner', 'admin', 'staff', 'teacher')
  )
);
