-- Migration: Fix grade_components to support all exam types
-- This migration changes grade_components to use exam_type_id (foreign key) 
-- instead of the restricted enum grade_component_type

-- Step 1: Add exam_type_id column to grade_components
ALTER TABLE grade_components 
ADD COLUMN IF NOT EXISTS exam_type_id UUID REFERENCES exam_types(id);

-- Step 2: Add a display_name column (TEXT) to store the name without enum restriction
ALTER TABLE grade_components 
ADD COLUMN IF NOT EXISTS display_name TEXT;

-- Step 3: Migrate existing data - copy name to display_name
UPDATE grade_components 
SET display_name = name::TEXT 
WHERE display_name IS NULL;

-- Step 4: Try to link existing grade_components to exam_types by matching name/code
-- Get school_id through subject_offerings -> classes
UPDATE grade_components gc
SET exam_type_id = et.id
FROM exam_types et
JOIN subject_offerings so ON gc.subject_offering_id = so.id
JOIN classes c ON so.class_id = c.id
WHERE gc.exam_type_id IS NULL
  AND et.school_id = c.school_id
  AND (
    UPPER(et.code) = UPPER(gc.name::TEXT)
    OR UPPER(et.name) = UPPER(gc.name::TEXT)
  );

-- Step 5: For grade_components that couldn't be matched, create exam_types entries
-- First, identify unique names that don't have matching exam_types
INSERT INTO exam_types (id, school_id, name, code, is_active, created_at)
SELECT 
  gen_random_uuid(),
  c.school_id,
  gc.name::TEXT,
  UPPER(gc.name::TEXT),
  true,
  NOW()
FROM grade_components gc
JOIN subject_offerings so ON gc.subject_offering_id = so.id
JOIN classes c ON so.class_id = c.id
WHERE gc.exam_type_id IS NULL
  AND gc.name IS NOT NULL
GROUP BY c.school_id, gc.name
ON CONFLICT DO NOTHING;

-- Step 6: Now link the newly created exam_types
UPDATE grade_components gc
SET exam_type_id = et.id
FROM exam_types et
JOIN subject_offerings so ON gc.subject_offering_id = so.id
JOIN classes c ON so.class_id = c.id
WHERE gc.exam_type_id IS NULL
  AND et.school_id = c.school_id
  AND (
    UPPER(et.code) = UPPER(gc.name::TEXT)
    OR UPPER(et.name) = UPPER(gc.name::TEXT)
  );

-- Step 7: Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_grade_components_exam_type_id 
ON grade_components(exam_type_id);

-- Step 8: Verify the migration
SELECT 
  'grade_components with exam_type_id' as metric,
  COUNT(*) FILTER (WHERE exam_type_id IS NOT NULL) as with_exam_type,
  COUNT(*) FILTER (WHERE exam_type_id IS NULL) as without_exam_type,
  COUNT(*) as total
FROM grade_components;

-- Note: After verifying everything works, you can optionally drop the old 'name' column
-- ALTER TABLE grade_components DROP COLUMN name;
-- But keep it for now as a backup
