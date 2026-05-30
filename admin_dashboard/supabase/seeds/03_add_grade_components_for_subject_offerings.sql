-- ============================================
-- Add Grade Components for Subject Offerings that don't have them
-- Run this in Supabase SQL Editor
-- ============================================

-- This script adds ORALE (25%), CC (25%), SYNTHESE (50%) for each subject_offering
-- that doesn't have any grade_components

DO $$
DECLARE
    v_offering RECORD;
    v_count INTEGER := 0;
BEGIN
    -- Loop through all subject_offerings that don't have grade_components
    FOR v_offering IN 
        SELECT so.id, so.class_id, so.semester_id, s.name as subject_name, c.name as class_name
        FROM subject_offerings so
        JOIN subjects s ON so.subject_id = s.id
        JOIN classes c ON so.class_id = c.id
        WHERE so.is_active = true
        AND NOT EXISTS (
            SELECT 1 FROM grade_components gc 
            WHERE gc.subject_offering_id = so.id
        )
    LOOP
        RAISE NOTICE 'Adding grade components for % in class %', v_offering.subject_name, v_offering.class_name;
        
        -- Add the 3 standard grade components
        INSERT INTO grade_components (id, subject_offering_id, name, weight_percent)
        VALUES 
            (gen_random_uuid(), v_offering.id, 'ORALE', 25.00),
            (gen_random_uuid(), v_offering.id, 'CC', 25.00),
            (gen_random_uuid(), v_offering.id, 'SYNTHESE', 50.00);
        
        v_count := v_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Added grade components for % subject offerings', v_count;
END $$;

-- Verify results
SELECT 
    c.name as class_name,
    s.name as subject_name,
    COUNT(gc.id) as component_count
FROM subject_offerings so
JOIN classes c ON so.class_id = c.id
JOIN subjects s ON so.subject_id = s.id
LEFT JOIN grade_components gc ON gc.subject_offering_id = so.id
WHERE so.is_active = true
GROUP BY c.name, s.name
ORDER BY c.name, s.name;
