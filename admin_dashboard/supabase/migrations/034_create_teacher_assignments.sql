-- Migration: Create teacher_assignments table
-- Links teachers to subjects, niveaux, and classes
-- A teacher can teach multiple subjects, at multiple niveaux, in multiple classes

CREATE TABLE IF NOT EXISTS public.teacher_assignments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL,
  teacher_id uuid NOT NULL,
  subject_id uuid NOT NULL,
  niveau_id uuid,
  class_id uuid,
  is_active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT teacher_assignments_pkey PRIMARY KEY (id),
  CONSTRAINT teacher_assignments_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id) ON DELETE CASCADE,
  CONSTRAINT teacher_assignments_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT teacher_assignments_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id) ON DELETE CASCADE,
  CONSTRAINT teacher_assignments_niveau_id_fkey FOREIGN KEY (niveau_id) REFERENCES public.niveaux(id) ON DELETE SET NULL,
  CONSTRAINT teacher_assignments_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id) ON DELETE SET NULL
);

-- Prevent duplicate assignments
CREATE UNIQUE INDEX IF NOT EXISTS teacher_assignments_unique_idx 
  ON public.teacher_assignments (school_id, teacher_id, subject_id, COALESCE(niveau_id, '00000000-0000-0000-0000-000000000000'), COALESCE(class_id, '00000000-0000-0000-0000-000000000000'))
  WHERE is_active = true;

-- Index for fast lookups by teacher
CREATE INDEX IF NOT EXISTS idx_teacher_assignments_teacher 
  ON public.teacher_assignments (teacher_id) WHERE is_active = true;

-- Index for fast lookups by subject
CREATE INDEX IF NOT EXISTS idx_teacher_assignments_subject 
  ON public.teacher_assignments (subject_id) WHERE is_active = true;

-- Index for fast lookups by school
CREATE INDEX IF NOT EXISTS idx_teacher_assignments_school 
  ON public.teacher_assignments (school_id) WHERE is_active = true;

-- RLS Policies
ALTER TABLE public.teacher_assignments ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to read teacher assignments for their school
CREATE POLICY "Users can view teacher assignments for their school"
  ON public.teacher_assignments FOR SELECT
  USING (
    school_id IN (
      SELECT school_id FROM public.users WHERE id = auth.uid()
    )
  );

-- Allow admins to insert teacher assignments
CREATE POLICY "Admins can insert teacher assignments"
  ON public.teacher_assignments FOR INSERT
  WITH CHECK (
    school_id IN (
      SELECT school_id FROM public.users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Allow admins to update teacher assignments
CREATE POLICY "Admins can update teacher assignments"
  ON public.teacher_assignments FOR UPDATE
  USING (
    school_id IN (
      SELECT school_id FROM public.users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Allow admins to delete teacher assignments
CREATE POLICY "Admins can delete teacher assignments"
  ON public.teacher_assignments FOR DELETE
  USING (
    school_id IN (
      SELECT school_id FROM public.users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
