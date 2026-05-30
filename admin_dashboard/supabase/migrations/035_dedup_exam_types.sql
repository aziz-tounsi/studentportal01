-- ============================================================================
-- 035_dedup_exam_types.sql
-- CLEANUP: Merge duplicate exam_types and enforce unique constraint
-- ============================================================================
-- Problem: Duplicate exam types exist with the same (school_id, code).
--   e.g. two "TP" entries — one without description, one with.
-- This migration:
--   1. For each (school_id, code) group with duplicates, picks the "best" row
--      (prefers the one with a description, then earliest created_at).
--   2. Repoints all FK references (subject_exam_config, grade_components) to the keeper.
--   3. Deletes the duplicates.
--   4. Ensures the UNIQUE constraint on (school_id, code) exists.
-- ============================================================================

DO $$
DECLARE
  rec RECORD;
  keeper_id UUID;
  dupe_ids UUID[];
BEGIN
  RAISE NOTICE '=== Starting exam_types deduplication ===';

  FOR rec IN
    SELECT
      school_id,
      code,
      array_agg(
        id ORDER BY
          -- Prefer rows that have a description
          (CASE WHEN description IS NOT NULL AND description <> '' THEN 0 ELSE 1 END),
          -- Then earliest created
          created_at,
          id
      ) AS ids,
      COUNT(*) AS cnt
    FROM public.exam_types
    WHERE code IS NOT NULL
    GROUP BY school_id, code
    HAVING COUNT(*) > 1
  LOOP
    keeper_id := rec.ids[1];
    dupe_ids  := rec.ids[2 : array_length(rec.ids, 1)];

    RAISE NOTICE 'Code "%" (school %): keeping %, deleting %',
      rec.code, rec.school_id, keeper_id, dupe_ids;

    -- Repoint subject_exam_config FKs
    UPDATE public.subject_exam_config
       SET exam_type_id = keeper_id
     WHERE exam_type_id = ANY(dupe_ids);

    -- Repoint grade_components FKs
    UPDATE public.grade_components
       SET exam_type_id = keeper_id
     WHERE exam_type_id = ANY(dupe_ids);

    -- Delete the duplicates
    DELETE FROM public.exam_types
     WHERE id = ANY(dupe_ids);
  END LOOP;

  RAISE NOTICE '=== Deduplication complete ===';
END $$;

-- Ensure the UNIQUE constraint exists (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'exam_types_school_code_key'
  ) THEN
    ALTER TABLE public.exam_types
      ADD CONSTRAINT exam_types_school_code_key UNIQUE (school_id, code);
    RAISE NOTICE 'Added UNIQUE constraint exam_types_school_code_key';
  ELSE
    RAISE NOTICE 'UNIQUE constraint exam_types_school_code_key already exists';
  END IF;
END $$;

-- Verify: show remaining exam_types
SELECT id, school_id, code, name, description, is_active
  FROM public.exam_types
 ORDER BY school_id, code;
