-- Add weekly_hours column to curriculum table
-- This represents the expected hours per week that a subject should be taught

ALTER TABLE public.curriculum
ADD COLUMN IF NOT EXISTS weekly_hours numeric DEFAULT 0;

COMMENT ON COLUMN public.curriculum.weekly_hours IS 'Expected hours per week for this subject in this niveau/section';
