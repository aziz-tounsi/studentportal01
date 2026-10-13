-- Migration 038: Prevent duplicate and overlapping semesters

-- 1. Create a function and trigger to enforce no overlapping semesters and bounds checking
CREATE OR REPLACE FUNCTION public.check_semester_integrity()
RETURNS TRIGGER AS $$
DECLARE
    v_year_start DATE;
    v_year_end DATE;
    v_conflict_name TEXT;
    v_conflict_start DATE;
    v_conflict_end DATE;
BEGIN
    -- Validate start_date <= end_date
    IF NEW.start_date > NEW.end_date THEN
        RAISE EXCEPTION 'La date de début (%) doit être antérieure ou égale à la date de fin (%)', NEW.start_date, NEW.end_date;
    END IF;

    -- Fetch academic year bounds
    SELECT start_date, end_date INTO v_year_start, v_year_end
    FROM public.academic_years
    WHERE id = NEW.academic_year_id;

    IF v_year_start IS NOT NULL AND v_year_end IS NOT NULL THEN
        IF NEW.start_date < v_year_start OR NEW.end_date > v_year_end THEN
            RAISE EXCEPTION 'La période doit être comprise dans les limites de l''année scolaire (% à %)', v_year_start, v_year_end;
        END IF;
    END IF;

    -- Check for duplicate name in the same school and academic year
    IF EXISTS (
        SELECT 1 FROM public.semesters
        WHERE school_id = NEW.school_id
          AND academic_year_id = NEW.academic_year_id
          AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
          AND LOWER(TRIM(name)) = LOWER(TRIM(NEW.name))
    ) THEN
        RAISE EXCEPTION 'Une période avec le nom "%" existe déjà dans cette année scolaire', NEW.name;
    END IF;

    -- Check for overlapping periods in the same school and academic year
    SELECT name, start_date, end_date INTO v_conflict_name, v_conflict_start, v_conflict_end
    FROM public.semesters
    WHERE school_id = NEW.school_id
      AND academic_year_id = NEW.academic_year_id
      AND id != COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
      AND NOT (NEW.start_date > end_date OR NEW.end_date < start_date)
    LIMIT 1;

    IF v_conflict_name IS NOT NULL THEN
        RAISE EXCEPTION 'Chevauchement interdit : la période chevauche avec "%" (du % au %)', v_conflict_name, v_conflict_start, v_conflict_end;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if any
DROP TRIGGER IF EXISTS trg_check_semester_integrity ON public.semesters;

-- Attach trigger before INSERT or UPDATE on semesters
CREATE TRIGGER trg_check_semester_integrity
    BEFORE INSERT OR UPDATE ON public.semesters
    FOR EACH ROW
    EXECUTE FUNCTION public.check_semester_integrity();
