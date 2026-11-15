-- Migration 052: Allow 'student' scope in announcement_attachments
ALTER TABLE public.announcement_attachments DROP CONSTRAINT IF EXISTS announcement_attachments_scope_check;
ALTER TABLE public.announcement_attachments ADD CONSTRAINT announcement_attachments_scope_check CHECK (scope IN ('global', 'class', 'student'));
