-- Vacation and exam period tables for school calendar
CREATE TABLE IF NOT EXISTS public.vacation_periods (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL,
  academic_year_id uuid NOT NULL,
  name text,
  start_date date NOT NULL,
  end_date date NOT NULL,
  type text NOT NULL DEFAULT 'manual' CHECK (type IN ('auto_gap', 'manual')),
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT vacation_periods_pkey PRIMARY KEY (id),
  CONSTRAINT vacation_periods_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE CASCADE,
  CONSTRAINT vacation_periods_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES public.academic_years(id) ON DELETE CASCADE,
  CONSTRAINT vacation_periods_date_order CHECK (start_date <= end_date)
);

CREATE TABLE IF NOT EXISTS public.exam_periods (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL,
  academic_year_id uuid NOT NULL,
  name text,
  start_date date NOT NULL,
  end_date date NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT exam_periods_pkey PRIMARY KEY (id),
  CONSTRAINT exam_periods_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE CASCADE,
  CONSTRAINT exam_periods_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES public.academic_years(id) ON DELETE CASCADE,
  CONSTRAINT exam_periods_date_order CHECK (start_date <= end_date)
);

CREATE INDEX IF NOT EXISTS idx_vacation_periods_school ON public.vacation_periods(school_id);
CREATE INDEX IF NOT EXISTS idx_vacation_periods_year ON public.vacation_periods(academic_year_id);
CREATE INDEX IF NOT EXISTS idx_vacation_periods_dates ON public.vacation_periods(start_date, end_date);

CREATE INDEX IF NOT EXISTS idx_exam_periods_school ON public.exam_periods(school_id);
CREATE INDEX IF NOT EXISTS idx_exam_periods_year ON public.exam_periods(academic_year_id);
CREATE INDEX IF NOT EXISTS idx_exam_periods_dates ON public.exam_periods(start_date, end_date);

-- Helper function to check if a date is inside a vacation period
CREATE OR REPLACE FUNCTION public.is_date_vacation(
  p_school_id uuid,
  p_date date
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.vacation_periods
    WHERE school_id = p_school_id
      AND p_date BETWEEN start_date AND end_date
  );
$$;

-- RLS
ALTER TABLE public.vacation_periods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_periods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow read vacation periods for school users" ON public.vacation_periods;
CREATE POLICY "Allow read vacation periods for school users"
  ON public.vacation_periods
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
        AND users.school_id = vacation_periods.school_id
        AND users.is_active = true
    )
  );

DROP POLICY IF EXISTS "Allow manage vacation periods for school admins" ON public.vacation_periods;
CREATE POLICY "Allow manage vacation periods for school admins"
  ON public.vacation_periods
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
        AND users.school_id = vacation_periods.school_id
        AND users.role = 'admin'
        AND users.is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
        AND users.school_id = vacation_periods.school_id
        AND users.role = 'admin'
        AND users.is_active = true
    )
  );

DROP POLICY IF EXISTS "Allow read exam periods for school users" ON public.exam_periods;
CREATE POLICY "Allow read exam periods for school users"
  ON public.exam_periods
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
        AND users.school_id = exam_periods.school_id
        AND users.is_active = true
    )
  );

DROP POLICY IF EXISTS "Allow manage exam periods for school admins" ON public.exam_periods;
CREATE POLICY "Allow manage exam periods for school admins"
  ON public.exam_periods
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
        AND users.school_id = exam_periods.school_id
        AND users.role = 'admin'
        AND users.is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
        AND users.school_id = exam_periods.school_id
        AND users.role = 'admin'
        AND users.is_active = true
    )
  );

GRANT EXECUTE ON FUNCTION public.is_date_vacation(uuid, date) TO authenticated;
