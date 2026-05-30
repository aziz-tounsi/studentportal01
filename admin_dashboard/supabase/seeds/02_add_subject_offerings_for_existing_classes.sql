-- ============================================
-- Add Subject Offerings and Grade Components for Existing Classes
-- This ensures all classes have their subjects with exam types
-- ============================================

-- First, let's add subject offerings for class 9B-2 (if it exists)
-- We'll use the same subjects from the seed data

-- Get the class ID for 9B-2 (we'll need to check what ID it has)
-- For now, we'll create a general script that adds subjects to all active classes

DO $$
DECLARE
    v_class RECORD;
    v_semester RECORD;
    v_subject RECORD;
    v_subject_offering_id UUID;
    v_school_id UUID;
BEGIN
    -- Get the school ID (assume first school)
    SELECT id INTO v_school_id FROM schools LIMIT 1;
    
    -- Loop through all active classes that don't have subject offerings yet
    FOR v_class IN 
        SELECT c.id as class_id, c.name as class_name, c.niveau_id
        FROM classes c
        WHERE c.is_active = true
        AND NOT EXISTS (
            SELECT 1 FROM subject_offerings so 
            WHERE so.class_id = c.id
        )
    LOOP
        RAISE NOTICE 'Processing class: %', v_class.class_name;
        
        -- Get semesters for current academic year
        FOR v_semester IN
            SELECT s.id as semester_id, s.number as semester_number
            FROM semesters s
            JOIN academic_years ay ON s.academic_year_id = ay.id
            WHERE ay.is_current = true
            ORDER BY s.number
        LOOP
            RAISE NOTICE '  Adding subjects for semester %', v_semester.semester_number;
            
            -- Add core subjects for all classes (adjust based on niveau if needed)
            -- Arabic
            INSERT INTO subject_offerings (id, semester_id, class_id, subject_id, coefficient, total_hours, weekly_ci_hours, weekly_tp_hours, weeks)
            SELECT 
                gen_random_uuid(),
                v_semester.semester_id,
                v_class.class_id,
                s.id,
                2.0, -- Default coefficient
                28, -- Default total hours
                2, -- Weekly CI hours
                0, -- Weekly TP hours
                14 -- Weeks
            FROM subjects s
            WHERE s.code = 'ARABE' AND s.school_id = v_school_id
            ON CONFLICT DO NOTHING
            RETURNING id INTO v_subject_offering_id;
            
            -- Add grade components for Arabic if subject offering was created
            IF v_subject_offering_id IS NOT NULL THEN
                INSERT INTO grade_components (id, subject_offering_id, name, weight_percent)
                VALUES 
                    (gen_random_uuid(), v_subject_offering_id, 'ORALE', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'CC', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'SYNTHESE', 50.00);
            END IF;
            
            -- Mathematics
            INSERT INTO subject_offerings (id, semester_id, class_id, subject_id, coefficient, total_hours, weekly_ci_hours, weekly_tp_hours, weeks)
            SELECT 
                gen_random_uuid(),
                v_semester.semester_id,
                v_class.class_id,
                s.id,
                3.0,
                42,
                3,
                0,
                14
            FROM subjects s
            WHERE s.code = 'MATH' AND s.school_id = v_school_id
            ON CONFLICT DO NOTHING
            RETURNING id INTO v_subject_offering_id;
            
            IF v_subject_offering_id IS NOT NULL THEN
                INSERT INTO grade_components (id, subject_offering_id, name, weight_percent)
                VALUES 
                    (gen_random_uuid(), v_subject_offering_id, 'ORALE', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'CC', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'SYNTHESE', 50.00);
            END IF;
            
            -- French
            INSERT INTO subject_offerings (id, semester_id, class_id, subject_id, coefficient, total_hours, weekly_ci_hours, weekly_tp_hours, weeks)
            SELECT 
                gen_random_uuid(),
                v_semester.semester_id,
                v_class.class_id,
                s.id,
                2.0,
                28,
                2,
                0,
                14
            FROM subjects s
            WHERE s.code = 'FRANCAIS' AND s.school_id = v_school_id
            ON CONFLICT DO NOTHING
            RETURNING id INTO v_subject_offering_id;
            
            IF v_subject_offering_id IS NOT NULL THEN
                INSERT INTO grade_components (id, subject_offering_id, name, weight_percent)
                VALUES 
                    (gen_random_uuid(), v_subject_offering_id, 'ORALE', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'CC', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'SYNTHESE', 50.00);
            END IF;
            
            -- Physics
            INSERT INTO subject_offerings (id, semester_id, class_id, subject_id, coefficient, total_hours, weekly_ci_hours, weekly_tp_hours, weeks)
            SELECT 
                gen_random_uuid(),
                v_semester.semester_id,
                v_class.class_id,
                s.id,
                3.0,
                42,
                2,
                1,
                14
            FROM subjects s
            WHERE s.code = 'PHYS' AND s.school_id = v_school_id
            ON CONFLICT DO NOTHING
            RETURNING id INTO v_subject_offering_id;
            
            IF v_subject_offering_id IS NOT NULL THEN
                INSERT INTO grade_components (id, subject_offering_id, name, weight_percent)
                VALUES 
                    (gen_random_uuid(), v_subject_offering_id, 'ORALE', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'CC', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'SYNTHESE', 50.00);
            END IF;
            
            -- SVT (Sciences)
            INSERT INTO subject_offerings (id, semester_id, class_id, subject_id, coefficient, total_hours, weekly_ci_hours, weekly_tp_hours, weeks)
            SELECT 
                gen_random_uuid(),
                v_semester.semester_id,
                v_class.class_id,
                s.id,
                2.0,
                28,
                2,
                0,
                14
            FROM subjects s
            WHERE s.code = 'SVT' AND s.school_id = v_school_id
            ON CONFLICT DO NOTHING
            RETURNING id INTO v_subject_offering_id;
            
            IF v_subject_offering_id IS NOT NULL THEN
                INSERT INTO grade_components (id, subject_offering_id, name, weight_percent)
                VALUES 
                    (gen_random_uuid(), v_subject_offering_id, 'ORALE', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'CC', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'SYNTHESE', 50.00);
            END IF;
            
            -- English
            INSERT INTO subject_offerings (id, semester_id, class_id, subject_id, coefficient, total_hours, weekly_ci_hours, weekly_tp_hours, weeks)
            SELECT 
                gen_random_uuid(),
                v_semester.semester_id,
                v_class.class_id,
                s.id,
                2.0,
                28,
                2,
                0,
                14
            FROM subjects s
            WHERE s.code = 'ANGLAIS' AND s.school_id = v_school_id
            ON CONFLICT DO NOTHING
            RETURNING id INTO v_subject_offering_id;
            
            IF v_subject_offering_id IS NOT NULL THEN
                INSERT INTO grade_components (id, subject_offering_id, name, weight_percent)
                VALUES 
                    (gen_random_uuid(), v_subject_offering_id, 'ORALE', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'CC', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'SYNTHESE', 50.00);
            END IF;
            
            -- History
            INSERT INTO subject_offerings (id, semester_id, class_id, subject_id, coefficient, total_hours, weekly_ci_hours, weekly_tp_hours, weeks)
            SELECT 
                gen_random_uuid(),
                v_semester.semester_id,
                v_class.class_id,
                s.id,
                1.0,
                14,
                1,
                0,
                14
            FROM subjects s
            WHERE s.code = 'HISTOIRE' AND s.school_id = v_school_id
            ON CONFLICT DO NOTHING
            RETURNING id INTO v_subject_offering_id;
            
            IF v_subject_offering_id IS NOT NULL THEN
                INSERT INTO grade_components (id, subject_offering_id, name, weight_percent)
                VALUES 
                    (gen_random_uuid(), v_subject_offering_id, 'ORALE', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'CC', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'SYNTHESE', 50.00);
            END IF;
            
            -- Geography
            INSERT INTO subject_offerings (id, semester_id, class_id, subject_id, coefficient, total_hours, weekly_ci_hours, weekly_tp_hours, weeks)
            SELECT 
                gen_random_uuid(),
                v_semester.semester_id,
                v_class.class_id,
                s.id,
                1.0,
                14,
                1,
                0,
                14
            FROM subjects s
            WHERE s.code = 'GEO' AND s.school_id = v_school_id
            ON CONFLICT DO NOTHING
            RETURNING id INTO v_subject_offering_id;
            
            IF v_subject_offering_id IS NOT NULL THEN
                INSERT INTO grade_components (id, subject_offering_id, name, weight_percent)
                VALUES 
                    (gen_random_uuid(), v_subject_offering_id, 'ORALE', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'CC', 25.00),
                    (gen_random_uuid(), v_subject_offering_id, 'SYNTHESE', 50.00);
            END IF;
            
        END LOOP;
    END LOOP;
    
    RAISE NOTICE 'Subject offerings and grade components added successfully!';
END $$;
