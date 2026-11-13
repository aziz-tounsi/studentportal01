-- Migration 050: Add bio description to schools table
ALTER TABLE public.schools ADD COLUMN IF NOT EXISTS bio TEXT;
