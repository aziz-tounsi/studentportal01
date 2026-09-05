-- ============================================
-- BACKFILL: Add missing data for existing students
-- Fills in grades, absences, payments, suggestions
-- for students who have enrollments but no other data.
-- DOES NOT drop or modify existing data.
-- ============================================

CREATE OR REPLACE FUNCTION _backfill_idx(p_input TEXT, p_max INT)
RETURNS INT AS $$
BEGIN
    RETURN 1 + ((('x' || substr(md5(p_input), 1, 8))::bit(32)::bigint) % p_max)::int;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

DO $$
DECLARE
    v_student RECORD;
    v_enrollment RECORD;
    v_semester RECORD;
    v_subject_offering RECORD;
    v_component RECORD;
    v_admin_id UUID;
    v_payment_plan_id UUID;
    v_suggestion_id UUID;
    v_plan_type TEXT;
    v_plan_amount NUMERIC;
    v_category TEXT;
    v_payment_status TEXT;
    v_due_date DATE;
    v_paid_at TIMESTAMPTZ;
    v_amount NUMERIC;
    v_grade_value NUMERIC;
    v_status TEXT;
    v_absence_date DATE;
    v_hours NUMERIC;
    v_justified BOOLEAN;
    v_student_index INT;
    v_payment_index INT;
    v_absence_index INT;
    v_suggestion_index INT;

    v_categories TEXT[] := ARRAY['scolarite', 'transport', 'cantine', 'activites', 'autres'];
    v_plan_types TEXT[] := ARRAY['annual', 'semester', 'monthly'];
    v_payment_methods TEXT[] := ARRAY['Espèces', 'Virement bancaire', 'Carte bancaire', 'Chèque', 'D17'];
    v_suggestion_types TEXT[] := ARRAY['general', 'administrative', 'complaint', 'request'];
    v_suggestion_subjects TEXT[] := ARRAY[
        'Demande de relevé de notes',
        'Problème de transport scolaire',
        'Question sur les frais de scolarité',
        'Demande de certificat de scolarité',
        'Suggestion pour une activité parascolaire',
        'Retard de l''enseignant',
        'Demande de changement de groupe',
        'Problème avec le cantine'
    ];
    v_suggestion_messages TEXT[] := ARRAY[
        'Bonjour, je souhaiterais obtenir une copie de mon relevé de notes du premier semestre. Merci.',
        'Le bus scolaire est souvent en retard le matin. Pourriez-vous vérifier l''horaire?',
        'J''ai une question concernant l''échéancier des paiements pour le deuxième trimestre.',
        'Je voudrais demander un certificat de scolarité pour mon dossier administratif.',
        'Serait-il possible d''organiser plus d''activités sportives après les cours?',
        'Le professeur de mathématiques est en retard de 20 minutes depuis une semaine.',
        'Je souhaite changer de groupe pour des raisons familiales. Est-ce possible?',
        'Le repas du mercredi n''est pas conforme au menu affiché. Merci de vérifier.'
    ];
    v_reply_texts TEXT[] := ARRAY[
        'Bonjour, votre demande a été traitée. Vous pouvez récupérer votre document au secrétariat.',
        'Merci pour votre retour. Nous avons pris note du problème et nous allons le résoudre rapidement.',
        'Votre suggestion a été transmise à l''administration. Nous vous tiendrons informé.',
        'Le paiement peut être échelonné sur 3 mois. Contactez le service comptable.'
    ];
    v_backfilled INT := 0;
BEGIN
    -- Find admin for suggestion replies
    SELECT u.id INTO v_admin_id
    FROM users u
    WHERE u.role = 'admin' AND u.is_active = TRUE
    ORDER BY u.created_at
    LIMIT 1;

    -- Loop through students who have enrollments but NO grades
    FOR v_student IN
        SELECT u.id AS user_id, u.full_name, u.email, u.school_id
        FROM users u
        WHERE u.role = 'student'
          AND u.is_active = TRUE
          AND NOT EXISTS (SELECT 1 FROM grades g WHERE g.student_id = u.id)
          AND EXISTS (SELECT 1 FROM enrollments e WHERE e.user_id = u.id AND e.is_active = TRUE)
        ORDER BY u.full_name
    LOOP
        RAISE NOTICE 'Backfilling: % (%)', v_student.full_name, v_student.email;

        -- Find their active enrollment
        SELECT e.* INTO v_enrollment
        FROM enrollments e
        WHERE e.user_id = v_student.user_id AND e.is_active = TRUE
        LIMIT 1;

        IF v_enrollment.id IS NULL THEN
            CONTINUE;
        END IF;

        v_student_index := _backfill_idx(v_student.user_id::text, 4) + 1;

        -- 1. Payment plans + payments
        FOREACH v_category IN ARRAY v_categories LOOP
            IF v_category = 'activites' AND v_student_index = 4 THEN CONTINUE; END IF;
            IF v_category = 'autres' AND v_student_index IN (2, 4) THEN CONTINUE; END IF;

            v_plan_type := v_plan_types[_backfill_idx(v_category || v_enrollment.id::text, array_length(v_plan_types, 1))];

            v_plan_amount := CASE v_category
                WHEN 'scolarite' THEN CASE v_plan_type
                    WHEN 'annual' THEN 3200 + (v_student_index * 100)
                    WHEN 'semester' THEN 1700 + (v_student_index * 50)
                    ELSE 650 + (v_student_index * 25)
                END
                WHEN 'transport' THEN 600 + (v_student_index * 50)
                WHEN 'cantine' THEN 450 + (v_student_index * 30)
                WHEN 'activites' THEN 200 + (v_student_index * 20)
                ELSE 150 + (v_student_index * 10)
            END;

            v_payment_plan_id := gen_random_uuid();
            INSERT INTO payment_plans (
                id, enrollment_id, plan_type, amount_total, currency,
                description, category, created_at
            ) VALUES (
                v_payment_plan_id, v_enrollment.id, v_plan_type::payment_plan_type, v_plan_amount, 'TND',
                'Plan ' || v_category || ' - ' || v_student.full_name,
                v_category, NOW()
            );

            FOR v_payment_index IN 1..CASE v_plan_type
                WHEN 'annual' THEN 1
                WHEN 'semester' THEN 2
                ELSE 3 + (v_student_index % 3)
            END LOOP
                v_due_date := (DATE '2025-09-15' + (v_payment_index * 30) + (v_student_index * 7))::date;

                IF v_student_index = 1 THEN
                    v_payment_status := 'paid';
                ELSIF v_student_index = 2 THEN
                    v_payment_status := CASE WHEN v_payment_index = 1 THEN 'paid' ELSE 'pending' END;
                ELSIF v_student_index = 3 THEN
                    v_payment_status := CASE WHEN v_payment_index = 1 THEN 'paid' WHEN v_due_date < CURRENT_DATE THEN 'overdue' ELSE 'pending' END;
                ELSE
                    v_payment_status := CASE WHEN v_payment_index IN (1, 2) THEN 'paid' ELSE 'pending' END;
                END IF;

                v_amount := round(v_plan_amount / CASE v_plan_type
                    WHEN 'annual' THEN 1
                    WHEN 'semester' THEN 2
                    ELSE 3 + (v_student_index % 3)
                END, 2);

                v_paid_at := CASE WHEN v_payment_status = 'paid' THEN NOW() - ((v_payment_index * 5) || ' days')::interval ELSE NULL END;

                INSERT INTO payments (
                    id, payment_plan_id, amount, due_date, paid_at,
                    method, status, reference, notes, created_at, student_id
                ) VALUES (
                    gen_random_uuid(), v_payment_plan_id, v_amount, v_due_date, v_paid_at,
                    CASE WHEN v_payment_status = 'paid' THEN v_payment_methods[_backfill_idx(v_payment_plan_id::text || v_payment_index::text, array_length(v_payment_methods, 1))] ELSE NULL END,
                    v_payment_status::payment_status,
                    'REF-' || upper(substr(md5(v_payment_plan_id::text || v_payment_index::text), 1, 8)),
                    'Backfill payment', NOW(), v_student.user_id
                );
            END LOOP;
        END LOOP;

        -- 2. Grades + absences
        FOR v_semester IN
            SELECT s.id AS semester_id, s.number AS semester_number
            FROM semesters s
            JOIN academic_years ay ON ay.id = s.academic_year_id
            WHERE ay.is_current = TRUE
            ORDER BY s.number
        LOOP
            FOR v_subject_offering IN
                SELECT so.id AS subject_offering_id, so.coefficient
                FROM subject_offerings so
                WHERE so.class_id = v_enrollment.class_id
                  AND so.semester_id = v_semester.semester_id
            LOOP
                FOR v_component IN
                    SELECT gc.id AS component_id, gc.name, gc.weight_percent
                    FROM grade_components gc
                    WHERE gc.subject_offering_id = v_subject_offering.subject_offering_id
                LOOP
                    v_grade_value := CASE v_student_index
                        WHEN 1 THEN 12 + _backfill_idx(v_component.component_id::text || v_student.user_id::text, 7)
                        WHEN 2 THEN 9 + _backfill_idx(v_component.component_id::text || v_student.user_id::text, 8)
                        WHEN 3 THEN 5 + _backfill_idx(v_component.component_id::text || v_student.user_id::text, 8)
                        ELSE 8 + _backfill_idx(v_component.component_id::text || v_student.user_id::text, 11)
                    END;

                    IF _backfill_idx(v_component.component_id::text || v_student.user_id::text || 'miss', 10) = 1 THEN
                        v_status := 'ND';
                        v_grade_value := NULL;
                    ELSE
                        v_status := CASE WHEN v_grade_value >= 10 THEN 'OK' ELSE 'NP' END;
                    END IF;

                    INSERT INTO grades (
                        id, enrollment_id, subject_offering_id, component_id,
                        grade_value, status, graded_at, created_at, updated_at, student_id
                    ) VALUES (
                        gen_random_uuid(), v_enrollment.id, v_subject_offering.subject_offering_id,
                        v_component.component_id, v_grade_value, v_status::grade_status,
                        NOW(), NOW(), NOW(), v_student.user_id
                    );
                END LOOP;

                FOR v_absence_index IN 1..(v_student_index * 3 + 1) LOOP
                    v_absence_date := (DATE '2025-09-20' + (v_absence_index * 5) + _backfill_idx(v_student.user_id::text || v_absence_index::text, 5))::date;
                    v_hours := 1 + _backfill_idx(v_subject_offering.subject_offering_id::text || v_absence_index::text, 2);
                    v_justified := (v_student_index = 1) OR (v_absence_index % 3 = 0);

                    INSERT INTO absence_records (
                        id, enrollment_id, subject_offering_id, date, hours_absent,
                        session_type, reason, justified, created_at, student_id
                    ) VALUES (
                        gen_random_uuid(), v_enrollment.id, v_subject_offering.subject_offering_id,
                        v_absence_date, v_hours,
                        (CASE WHEN v_absence_index % 2 = 0 THEN 'CI' ELSE 'TP' END)::session_type,
                        CASE WHEN v_justified THEN 'Certificat médical' ELSE 'Absent sans justification' END,
                        v_justified, NOW(), v_student.user_id
                    );
                END LOOP;
            END LOOP;
        END LOOP;

        -- 3. Suggestions (2 per student)
        FOR v_suggestion_index IN 1..2 LOOP
            v_suggestion_id := gen_random_uuid();
            INSERT INTO suggestions (
                id, student_id, subject, message, title, body, status, created_at,
                suggestion_type, class_id, enrollment_id, student_code,
                student_name, class_name, school_id, is_read, read_at
            ) VALUES (
                v_suggestion_id, v_student.user_id,
                v_suggestion_subjects[_backfill_idx(v_student.user_id::text || v_suggestion_index::text, array_length(v_suggestion_subjects, 1))],
                v_suggestion_messages[_backfill_idx(v_student.user_id::text || v_suggestion_index::text || 'msg', array_length(v_suggestion_messages, 1))],
                v_suggestion_subjects[_backfill_idx(v_student.user_id::text || v_suggestion_index::text, array_length(v_suggestion_subjects, 1))],
                v_suggestion_messages[_backfill_idx(v_student.user_id::text || v_suggestion_index::text || 'msg', array_length(v_suggestion_messages, 1))],
                (CASE WHEN v_suggestion_index = 1 AND v_admin_id IS NOT NULL THEN 'replied' ELSE 'sent' END)::suggestion_status,
                NOW() - ((v_suggestion_index * 3) || ' days')::interval,
                v_suggestion_types[_backfill_idx(v_student.user_id::text || v_suggestion_index::text, array_length(v_suggestion_types, 1))],
                v_enrollment.class_id, v_enrollment.id, v_enrollment.student_code,
                v_student.full_name,
                (SELECT name FROM classes WHERE id = v_enrollment.class_id),
                v_student.school_id,
                v_suggestion_index = 1 AND v_admin_id IS NOT NULL,
                CASE WHEN v_suggestion_index = 1 AND v_admin_id IS NOT NULL THEN NOW() - ((v_suggestion_index * 2) || ' days')::interval ELSE NULL END
            );

            IF v_suggestion_index = 1 AND v_admin_id IS NOT NULL THEN
                INSERT INTO suggestion_replies (
                    id, suggestion_id, admin_id, message, created_at
                ) VALUES (
                    gen_random_uuid(), v_suggestion_id, v_admin_id,
                    v_reply_texts[_backfill_idx(v_suggestion_id::text, array_length(v_reply_texts, 1))],
                    NOW() - ((v_suggestion_index * 2) || ' days')::interval
                );
            END IF;
        END LOOP;

        -- 4. User settings (if missing)
        INSERT INTO user_settings (user_id, language, theme, notifications_enabled)
        VALUES (v_student.user_id, 'fr', 'light', TRUE)
        ON CONFLICT (user_id) DO NOTHING;

        v_backfilled := v_backfilled + 1;
    END LOOP;

    RAISE NOTICE 'Backfill complete. Students updated: %', v_backfilled;
END $$;

DROP FUNCTION IF EXISTS _backfill_idx(TEXT, INT);
