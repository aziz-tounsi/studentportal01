-- ==============================================================================
-- Migration 043: Bug Reports Table (Super Admin Platform Console)
-- Description: Dedicated bug report storage separated from student suggestions
--              and school admin dashboard. Visible exclusively to Super Admins.
-- ==============================================================================

CREATE TABLE IF NOT EXISTS public.bug_reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    school_id UUID REFERENCES public.schools(id) ON DELETE SET NULL,
    student_name TEXT,
    student_code TEXT,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    category TEXT,
    attachment_urls TEXT[] DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'open', -- 'open', 'in_progress', 'resolved', 'closed'
    severity TEXT DEFAULT 'medium',
    app_version TEXT,
    device_info JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index on school_id and created_at
CREATE INDEX IF NOT EXISTS idx_bug_reports_school_id ON public.bug_reports(school_id);
CREATE INDEX IF NOT EXISTS idx_bug_reports_created_at ON public.bug_reports(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_bug_reports_status ON public.bug_reports(status);

-- Enable RLS
ALTER TABLE public.bug_reports ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to insert bug reports
CREATE POLICY "bug_reports_insert_auth" ON public.bug_reports
    FOR INSERT TO authenticated
    WITH CHECK (true);

-- Allow super admins full access
CREATE POLICY "bug_reports_super_admin_all" ON public.bug_reports
    FOR ALL TO authenticated
    USING (public.is_super_admin())
    WITH CHECK (public.is_super_admin());

-- Allow reporting user to view own reports
CREATE POLICY "bug_reports_user_select_own" ON public.bug_reports
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());
