# Materials Weekly Hours - Updated Logic

## Overview
The weekly hours system follows a logical workflow from curriculum definition to timetable creation.

### Workflow
1. **Manager sets expected hours** in curriculum:
   - When creating a material assignment (affectation), manager specifies how many hours per week this subject should be taught
   - This is stored in `curriculum.weekly_hours`

2. **Timetable creation uses this data**:
   - When creating a timetable for a class, the system will show:
     * Which subjects need to be taught for that class's niveau/section
     * How many hours per week each subject requires (from `curriculum.weekly_hours`)
     * How many hours are already scheduled (sum of `timetable_slots` for that subject/class)
     * How many hours are still needed (expected - scheduled)

3. **Section filtering**:
   - In the assignment dialog and list view, the section field only appears if the selected niveau has sections
   - If a niveau doesn't have sections (like "7ème année de base"), no section selector or column is shown

## Database Schema
```sql
-- Already exists
ALTER TABLE public.curriculum
ADD COLUMN IF NOT EXISTS weekly_hours numeric DEFAULT 0;

COMMENT ON COLUMN public.curriculum.weekly_hours IS 'Expected hours per week for this subject in this niveau/section';
```

## Timetable Integration Logic

### When Building Timetable for a Class

```sql
-- Get subjects for a class with their expected and scheduled hours
SELECT 
  c.id as curriculum_id,
  s.id as subject_id,
  s.name as subject_name,
  s.code as subject_code,
  c.weekly_hours as expected_hours,
  COALESCE(
    (
      SELECT SUM(
        EXTRACT(EPOCH FROM (ts.end_time - ts.start_time)) / 3600
      )
      FROM timetable_slots ts
      JOIN subject_offerings so ON ts.subject_offering_id = so.id
      WHERE so.subject_id = s.id
        AND so.class_id = :class_id
        AND ts.group_id = :group_id -- if applicable
    ), 
    0
  ) as scheduled_hours,
  c.weekly_hours - COALESCE(
    (
      SELECT SUM(
        EXTRACT(EPOCH FROM (ts.end_time - ts.start_time)) / 3600
      )
      FROM timetable_slots ts
      JOIN subject_offerings so ON ts.subject_offering_id = so.id
      WHERE so.subject_id = s.id
        AND so.class_id = :class_id
        AND ts.group_id = :group_id
    ), 
    0
  ) as remaining_hours
FROM curriculum c
JOIN subjects s ON c.subject_id = s.id
JOIN classes cl ON c.niveau_id = cl.niveau_id 
  AND (c.section_id IS NULL OR c.section_id = cl.section_id)
WHERE cl.id = :class_id
  AND c.is_active = true
  AND c.weekly_hours > 0
ORDER BY s.name;
```

### UI Display for Timetable Creation

When manager is creating timetable for a class, show:

```
📚 Matières à Planifier pour Classe 7A1

┌──────────────────────┬──────────┬──────────┬──────────┐
│ Matière              │ Prévu    │ Planifié │ Restant  │
├──────────────────────┼──────────┼──────────┼──────────┤
│ Mathématiques        │ 5h       │ 3h       │ 2h ⚠️    │
│ Sciences Physiques   │ 4h       │ 4h       │ ✅ 0h    │
│ Français             │ 4h       │ 0h       │ 4h ❌    │
│ Arabe                │ 3h       │ 1h       │ 2h ⚠️    │
└──────────────────────┴──────────┴──────────┴──────────┘

Total: 16h prévues, 8h planifiées, 8h restantes
```

### Smart Suggestions
- ✅ Green check: All hours scheduled
- ⚠️ Orange warning: Partially scheduled
- ❌ Red alert: No hours scheduled yet

### Validation Rules
1. Cannot create more timetable slots than expected hours (warning)
2. System highlights subjects with 0 scheduled hours
3. System shows progress bar for each subject

## Implementation in Timetable Module

When creating a new timetable slot:

```dart
// 1. Load subjects with their hours info
final subjectsInfo = await loadSubjectsWithHoursForClass(classId);

// 2. Show in dropdown/list with remaining hours
for (final info in subjectsInfo) {
  DropdownItem(
    value: info.subjectId,
    child: Row(
      children: [
        Text(info.subjectName),
        Spacer(),
        if (info.remainingHours > 0)
          Chip(
            label: Text('${info.remainingHours}h restantes'),
            backgroundColor: Colors.orange,
          )
        else
          Chip(
            label: Text('✅ Complet'),
            backgroundColor: Colors.green,
          ),
      ],
    ),
  );
}

// 3. Calculate slot duration
final slotDurationHours = calculateHoursDifference(startTime, endTime);

// 4. Warn if exceeding expected hours
if (info.scheduledHours + slotDurationHours > info.expectedHours) {
  showWarning(
    'Attention: Cette matière dépassera les heures prévues '
    '(${info.expectedHours}h) de ${info.scheduledHours + slotDurationHours - info.expectedHours}h'
  );
}

// 5. After saving, show updated status
showSuccess(
  'Créneaux ajouté. ${info.subjectName}: '
  '${info.scheduledHours + slotDurationHours}h / ${info.expectedHours}h planifiées'
);
```

## Benefits
- ✅ Logical flow: define requirements first, then schedule
- ✅ Clear expectations: managers know exactly how many hours each subject needs
- ✅ Easy tracking: can see at a glance which subjects are under/over scheduled
- ✅ Flexible: can adjust expected hours as needed without touching timetable
- ✅ Smart UI: hide section fields/columns when niveau doesn't have sections
- ✅ Validation: prevent over-scheduling or missing subjects

## User Experience Flow

### Step 1: Define Curriculum (Current Screen)
Manager sets up what should be taught:
- Select niveau → Select matière → Set coefficient → **Set weekly hours**
- Section field only appears for niveaux with sections (lycée)

### Step 2: Create Timetable (Future/External Module)
System helps manager schedule the classes:
- Shows all subjects that need hours for the selected class
- Displays remaining hours for each subject
- Highlights subjects that aren't fully scheduled
- Warns when trying to exceed expected hours

### Step 3: Monitor & Adjust
- Dashboard shows curriculum vs timetable alignment
- Reports show which classes/subjects are under/over scheduled
- Easy to adjust either curriculum hours or timetable slots
