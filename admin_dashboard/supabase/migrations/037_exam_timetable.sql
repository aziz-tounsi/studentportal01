-- Add timetable_type and exam_period_id to timetable_slots
-- 'regular' = normal semester timetable, 'exam' = exam period timetable

ALTER TABLE public.timetable_slots
  ADD COLUMN IF NOT EXISTS timetable_type text NOT NULL DEFAULT 'regular'
    CHECK (timetable_type IN ('regular', 'exam'));

ALTER TABLE public.timetable_slots
  ADD COLUMN IF NOT EXISTS exam_period_id uuid
    REFERENCES public.exam_periods(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_timetable_slots_type ON public.timetable_slots(timetable_type);
CREATE INDEX IF NOT EXISTS idx_timetable_slots_exam_period ON public.timetable_slots(exam_period_id);

-- Helper: check if a date is inside any exam period for the school
CREATE OR REPLACE FUNCTION public.is_date_exam_period(
  p_school_id uuid,
  p_date date
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.exam_periods
    WHERE school_id = p_school_id
      AND p_date BETWEEN start_date AND end_date
  );
$$;

-- Helper: get the active exam period id for a school on a given date (or null)
CREATE OR REPLACE FUNCTION public.get_active_exam_period(
  p_school_id uuid,
  p_date date
)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT id FROM public.exam_periods
  WHERE school_id = p_school_id
    AND p_date BETWEEN start_date AND end_date
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.is_date_exam_period(uuid, date) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_active_exam_period(uuid, date) TO authenticated;
