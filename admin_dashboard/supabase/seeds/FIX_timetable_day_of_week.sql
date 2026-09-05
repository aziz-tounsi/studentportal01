-- ============================================
-- MIGRATION: Convert integer day_of_week to string
-- Some timetable_slots have day_of_week stored as integers (1-7)
-- instead of strings ('monday'-'sunday'). This converts them.
-- ============================================

UPDATE timetable_slots
SET day_of_week = CASE day_of_week::text
  WHEN '1' THEN 'monday'
  WHEN '2' THEN 'tuesday'
  WHEN '3' THEN 'wednesday'
  WHEN '4' THEN 'thursday'
  WHEN '5' THEN 'friday'
  WHEN '6' THEN 'saturday'
  WHEN '7' THEN 'sunday'
  ELSE day_of_week::text
END
WHERE day_of_week::text ~ '^[0-7]$';
