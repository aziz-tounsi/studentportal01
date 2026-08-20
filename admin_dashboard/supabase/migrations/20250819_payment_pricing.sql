-- Payment pricing configuration per school/niveau/section/category
CREATE TABLE public.payment_pricing (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL,
  academic_year_id uuid,
  category text NOT NULL CHECK (category IN ('scolarite', 'transport', 'cantine', 'inscription', 'uniforme', 'activites', 'autres')),
  niveau_id uuid NOT NULL,
  section_id uuid,
  amount numeric NOT NULL CHECK (amount >= 0),
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT payment_pricing_pkey PRIMARY KEY (id),
  CONSTRAINT payment_pricing_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE CASCADE,
  CONSTRAINT payment_pricing_academic_year_id_fkey FOREIGN KEY (academic_year_id) REFERENCES public.academic_years(id) ON DELETE SET NULL,
  CONSTRAINT payment_pricing_niveau_id_fkey FOREIGN KEY (niveau_id) REFERENCES public.niveaux(id) ON DELETE CASCADE,
  CONSTRAINT payment_pricing_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.sections(id) ON DELETE CASCADE,
  CONSTRAINT payment_pricing_unique UNIQUE (school_id, academic_year_id, category, niveau_id, section_id)
);

-- Indexes
CREATE INDEX idx_payment_pricing_school ON public.payment_pricing(school_id);
CREATE INDEX idx_payment_pricing_niveau ON public.payment_pricing(niveau_id);
CREATE INDEX idx_payment_pricing_section ON public.payment_pricing(section_id);
CREATE INDEX idx_payment_pricing_category ON public.payment_pricing(category);
CREATE INDEX idx_payment_pricing_academic_year ON public.payment_pricing(academic_year_id);

-- Enable RLS
ALTER TABLE public.payment_pricing ENABLE ROW LEVEL SECURITY;

-- RLS policies: school-scoped access for authenticated users
CREATE POLICY "Allow read payment pricing for school users"
  ON public.payment_pricing
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
        AND users.school_id = payment_pricing.school_id
        AND users.is_active = true
    )
  );

CREATE POLICY "Allow insert payment pricing for school admins"
  ON public.payment_pricing
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
        AND users.school_id = payment_pricing.school_id
        AND users.role = 'admin'
        AND users.is_active = true
    )
  );

CREATE POLICY "Allow update payment pricing for school admins"
  ON public.payment_pricing
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
        AND users.school_id = payment_pricing.school_id
        AND users.role = 'admin'
        AND users.is_active = true
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
        AND users.school_id = payment_pricing.school_id
        AND users.role = 'admin'
        AND users.is_active = true
    )
  );

CREATE POLICY "Allow delete payment pricing for school admins"
  ON public.payment_pricing
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE users.id = auth.uid()
        AND users.school_id = payment_pricing.school_id
        AND users.role = 'admin'
        AND users.is_active = true
    )
  );

-- Function to get payment pricing for a specific student enrollment
CREATE OR REPLACE FUNCTION public.get_payment_pricing_for_enrollment(
  p_enrollment_id uuid,
  p_category text DEFAULT 'scolarite'
)
RETURNS TABLE (
  id uuid,
  amount numeric,
  category text,
  niveau_id uuid,
  section_id uuid
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT pp.id, pp.amount, pp.category, pp.niveau_id, pp.section_id
  FROM public.payment_pricing pp
  JOIN public.enrollments e ON e.id = p_enrollment_id
  JOIN public.classes c ON c.id = e.class_id
  WHERE pp.school_id = c.school_id
    AND pp.category = p_category
    AND pp.niveau_id = c.niveau_id
    AND (pp.section_id IS NULL OR pp.section_id = c.section_id)
    AND (pp.academic_year_id IS NULL OR pp.academic_year_id = e.academic_year_id)
    AND pp.is_active = true
  ORDER BY pp.section_id NULLS LAST
  LIMIT 1;
$$;

-- Function to count active semesters in current academic year for a school
CREATE OR REPLACE FUNCTION public.get_current_academic_year_semester_count(p_school_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT COUNT(*)::integer
  FROM public.semesters s
  JOIN public.academic_years ay ON ay.id = s.academic_year_id
  WHERE ay.school_id = p_school_id
    AND ay.is_current = true;
$$;

-- Grant execute on new functions
GRANT EXECUTE ON FUNCTION public.get_payment_pricing_for_enrollment(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_current_academic_year_semester_count(uuid) TO authenticated;
