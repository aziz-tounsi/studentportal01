-- ============================================
-- COMPLETE TUNISIAN STUDENTS SEED FILE
-- Adds 4 realistic Tunisian students to every existing active class.
-- DOES NOT drop existing data.
-- Each student is seeded like a real app user: profile, enrollments,
-- payments, grades, absences, suggestions (with replies), password-reset
-- request, user settings, plus global app config (thresholds, pricing, contact).
-- Run this after all migrations and existing seeds.
-- ============================================

-- Helper: deterministic pseudo-random integer from a string seed (1..max)
CREATE OR REPLACE FUNCTION _seed_idx(p_input TEXT, p_max INT)
RETURNS INT AS $$
BEGIN
    RETURN 1 + ((('x' || substr(md5(p_input), 1, 8))::bit(32)::bigint) % p_max)::int;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

DO $$
DECLARE
    v_class RECORD;
    v_academic_year_id UUID;
    v_previous_year_id UUID;
    v_school_id UUID;
    v_admin_id UUID;
    v_semester RECORD;
    v_subject_offering RECORD;
    v_component RECORD;
    v_group_id UUID;
    v_previous_class_id UUID;
    v_student_index INT;
    v_payment_index INT;
    v_absence_index INT;
    v_suggestion_index INT;
    v_user_id UUID;
    v_enrollment_id UUID;
    v_previous_enrollment_id UUID;
    v_suggestion_id UUID;
    v_payment_plan_id UUID;
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
    v_inserted_count INT := 0;

    -- Tunisian mock data pools
    v_male_names TEXT[] := ARRAY['Yassine', 'Omar', 'Mehdi', 'Amine', 'Karim', 'Nader', 'Hatem', 'Bilel', 'Firas', 'Anis', 'Ahmed', 'Mohamed', 'Rami', 'Sami', 'Aymen'];
    v_female_names TEXT[] := ARRAY['Ines', 'Salma', 'Nour', 'Rania', 'Lina', 'Yasmine', 'Sarra', 'Aya', 'Mariem', 'Rihab', 'Asma', 'Hela', 'Yosra', 'Khadija', 'Emna'];
    v_last_names TEXT[] := ARRAY['Khelifi', 'Bouazizi', 'Hamdi', 'Mansour', 'Dridi', 'Mejri', 'Sassi', 'Ben Ahmed', 'Chaabane', 'Jelassi', 'Brahmi', 'Mzoughi', 'Riahi', 'Gharbi', 'Jendoubi', 'Trabelsi', 'Cherif', 'Belhadj', 'Feki', 'Guerfali'];
    v_cities TEXT[] := ARRAY['Tunis', 'Sfax', 'Sousse', 'Kairouan', 'Bizerte', 'Gabès', 'Nabeul', 'Monastir', 'Mahdia', 'Tozeur', 'Gafsa', 'Kébili', 'Médenine', 'Tataouine', 'Béja', 'Jendouba', 'Le Kef', 'Siliana', 'Zaghouan', 'Ben Arous'];
    v_streets TEXT[] := ARRAY['Avenue Habib Bourguiba', 'Rue de la République', 'Avenue de Carthage', 'Rue Ibn Khaldoun', 'Avenue Mohammed V', 'Rue Farhat Hached', 'Avenue de la Liberté', 'Rue Ali Belhouane', 'Avenue des Martyrs', 'Rue El Jazira'];
    v_phone_prefixes TEXT[] := ARRAY['+216 55', '+216 56', '+216 58', '+216 70', '+216 71', '+216 72', '+216 98', '+216 99'];
    v_categories TEXT[] := ARRAY['scolarite', 'transport', 'cantine', 'activites', 'autres'];
    v_plan_types TEXT[] := ARRAY['annual', 'semester', 'monthly'];
    v_payment_methods TEXT[] := ARRAY['Espèces', 'Virement bancaire', 'Carte bancaire', 'Chèque', 'D17'];
    v_suggestion_types TEXT[] := ARRAY['general', 'administrative', 'complaint', 'request'];
    v_themes TEXT[] := ARRAY['light', 'dark'];
    v_languages TEXT[] := ARRAY['fr', 'ar', 'en'];

    v_first_name TEXT;
    v_last_name TEXT;
    v_gender CHAR(1);
    v_email TEXT;
    v_phone TEXT;
    v_dob DATE;
    v_city TEXT;
    v_address TEXT;
    v_student_code TEXT;
    v_photo_url TEXT;
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
BEGIN
    -- Use the admin's school_id so seeded students appear on the Users page
    SELECT u.school_id INTO v_school_id
    FROM users u
    WHERE u.role = 'admin' AND u.is_active = TRUE
    ORDER BY u.created_at
    LIMIT 1;

    -- Fallback to current academic year's school if no admin found
    IF v_school_id IS NULL THEN
        SELECT ay.school_id INTO v_school_id
        FROM academic_years ay
        WHERE ay.is_current = TRUE
        ORDER BY ay.start_date DESC
        LIMIT 1;
    END IF;

    -- Get the current academic year
    SELECT ay.id INTO v_academic_year_id
    FROM academic_years ay
    WHERE ay.is_current = TRUE
    ORDER BY ay.start_date DESC
    LIMIT 1;

    IF v_academic_year_id IS NULL THEN
        RAISE EXCEPTION 'No current academic year found. Please create one first.';
    END IF;

    -- Find a previous academic year for history
    SELECT ay.id INTO v_previous_year_id
    FROM academic_years ay
    WHERE ay.id <> v_academic_year_id
    ORDER BY ay.start_date DESC
    LIMIT 1;

    -- Use the first admin/owner as the replier for suggestions
    SELECT u.id INTO v_admin_id
    FROM users u
    WHERE u.role = 'admin' AND u.is_active = TRUE
    ORDER BY u.created_at
    LIMIT 1;

    RAISE NOTICE 'Seeding students for academic year %, school %', v_academic_year_id, v_school_id;

    -- =====================================================
    -- GLOBAL APP CONFIG (idempotent)
    -- =====================================================
    IF NOT EXISTS (SELECT 1 FROM absence_thresholds WHERE school_id = v_school_id) THEN
        INSERT INTO absence_thresholds (id, school_id, warning_percent, critical_percent, elimination_percent)
        VALUES (gen_random_uuid(), v_school_id, 20.00, 30.00, 50.00);
    END IF;

    INSERT INTO app_settings (key, value, description)
    VALUES (
        'contact_info',
        jsonb_build_object(
            'phone', '+216 71 123 456',
            'email', 'contact@pythagore.tn',
            'address', 'Avenue Habib Bourguiba, Tunis, Tunisie',
            'facebook', 'https://facebook.com/centrepythagore',
            'maps', 'https://maps.google.com/?q=Centre+Pythagore+Tunis',
            'website', 'https://pythagore.tn',
            'hours', 'Lun - Ven: 08:00 - 17:00'
        ),
        'School contact information displayed in the student app'
    )
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

    -- Payment pricing per niveau/section/category (skip if already seeded)
    IF NOT EXISTS (SELECT 1 FROM payment_pricing WHERE school_id = v_school_id AND academic_year_id = v_academic_year_id LIMIT 1) THEN
        INSERT INTO payment_pricing (id, school_id, academic_year_id, category, niveau_id, section_id, amount, is_active)
        SELECT
            gen_random_uuid(),
            v_school_id,
            v_academic_year_id,
            cat,
            c.niveau_id,
            c.section_id,
            CASE cat
                WHEN 'scolarite' THEN 3200
                WHEN 'transport' THEN 650
                WHEN 'cantine' THEN 480
                WHEN 'activites' THEN 220
                ELSE 150
            END,
            TRUE
        FROM (SELECT DISTINCT niveau_id, section_id FROM classes WHERE is_active = TRUE) c
        CROSS JOIN unnest(ARRAY['scolarite', 'transport', 'cantine', 'activites', 'autres']) AS cat;
    END IF;

    -- =====================================================
    -- LOOP: 4 students per active class
    -- =====================================================
    FOR v_class IN
        SELECT c.id AS class_id, c.name AS class_name, c.niveau_id, c.section_id
        FROM classes c
        WHERE c.is_active = TRUE
        ORDER BY c.name
    LOOP
        RAISE NOTICE 'Class %: generating 4 students', v_class.class_name;

        -- Pick a group for this class
        SELECT g.id INTO v_group_id
        FROM groups g
        WHERE g.class_id = v_class.class_id
        LIMIT 1;

        -- Find a plausible previous class for academic history (same niveau/section if possible)
        SELECT c.id INTO v_previous_class_id
        FROM classes c
        WHERE c.is_active = TRUE
          AND c.niveau_id = v_class.niveau_id
          AND (c.section_id IS NOT DISTINCT FROM v_class.section_id)
          AND c.id <> v_class.class_id
        LIMIT 1;
        IF v_previous_class_id IS NULL THEN
            SELECT c.id INTO v_previous_class_id
            FROM classes c
            WHERE c.is_active = TRUE AND c.id <> v_class.class_id
            LIMIT 1;
        END IF;

        FOR v_student_index IN 1..4 LOOP
            v_last_name := v_last_names[_seed_idx(v_class.class_id::text || v_student_index::text, array_length(v_last_names, 1))];
            v_gender := CASE WHEN v_student_index IN (1, 3) THEN 'M' ELSE 'F' END;
            v_first_name := CASE v_gender
                WHEN 'M' THEN v_male_names[_seed_idx(v_class.class_id::text || v_student_index::text || 'm', array_length(v_male_names, 1))]
                ELSE v_female_names[_seed_idx(v_class.class_id::text || v_student_index::text || 'f', array_length(v_female_names, 1))]
            END;

            v_email := lower(regexp_replace(v_first_name, '[^a-zA-Z]', '', 'g')) || '.' || lower(regexp_replace(v_last_name, '[^a-zA-Z]', '', 'g')) || '.' || substr(md5(v_class.class_id::text || v_student_index::text), 1, 4) || '@student.pythagore.tn';
            v_phone := v_phone_prefixes[_seed_idx(v_class.class_id::text || v_student_index::text, array_length(v_phone_prefixes, 1))]
                || ' ' || lpad((_seed_idx(v_class.class_id::text || v_student_index::text || 'p1', 899) + 100)::text, 3, '0')
                || ' ' || lpad((_seed_idx(v_class.class_id::text || v_student_index::text || 'p2', 89) + 10)::text, 2, '0');
            v_dob := (DATE '2008-01-01' + _seed_idx(v_class.class_id::text || v_student_index::text || 'dob', 1825))::date;
            v_city := v_cities[_seed_idx(v_class.class_id::text || v_student_index::text || 'c', array_length(v_cities, 1))];
            v_address := v_streets[_seed_idx(v_class.class_id::text || v_student_index::text || 's', array_length(v_streets, 1))] || ', ' || v_city || ', Tunisie';
            v_student_code := 'STU-' || to_char(NOW(), 'YYYY') || '-' || upper(substr(md5(v_class.class_id::text || v_student_index::text), 1, 6));
            v_photo_url := 'https://ui-avatars.com/api/?name=' || replace(v_first_name || ' ' || v_last_name, ' ', '+') || '&background=' || CASE v_gender WHEN 'M' THEN '3B82F6' ELSE 'EC4899' END || '&color=fff&size=256&format=png';

            -- Avoid duplicates by email (idempotent)
            IF EXISTS (SELECT 1 FROM auth.users WHERE email = v_email) THEN
                CONTINUE;
            END IF;

            v_user_id := gen_random_uuid();
            v_inserted_count := v_inserted_count + 1;

            -- 1. auth.users
            INSERT INTO auth.users (
                id, email, encrypted_password, email_confirmed_at, created_at, updated_at,
                raw_app_meta_data, raw_user_meta_data, aud, role
            ) VALUES (
                v_user_id, v_email, crypt('Test123!', gen_salt('bf')), NOW(), NOW(), NOW(),
                '{"provider":"email","providers":["email"]}'::jsonb,
                jsonb_build_object('full_name', v_first_name || ' ' || v_last_name),
                'authenticated', 'authenticated'
            );

            -- 2. public.users
            INSERT INTO users (
                id, school_id, role, full_name, email, phone, photo_url,
                student_code, date_of_birth, address, gender, nationality,
                niveau_id, section_id, is_active, created_at
            ) VALUES (
                v_user_id, v_school_id, 'student', v_first_name || ' ' || v_last_name,
                v_email, v_phone, v_photo_url, v_student_code, v_dob, v_address,
                v_gender, 'Tunisienne', v_class.niveau_id, v_class.section_id, TRUE, NOW()
            );

            -- 3. current enrollment
            v_enrollment_id := gen_random_uuid();
            INSERT INTO enrollments (
                id, user_id, class_id, group_id, academic_year_id,
                is_active, student_code, created_at
            ) VALUES (
                v_enrollment_id, v_user_id, v_class.class_id, v_group_id,
                v_academic_year_id, TRUE, v_student_code, NOW()
            )
            ON CONFLICT DO NOTHING;

            -- If enrollment failed (e.g. duplicate student_code), skip this student
            IF NOT EXISTS (SELECT 1 FROM enrollments WHERE id = v_enrollment_id) THEN
                CONTINUE;
            END IF;

            -- 4. previous-year inactive enrollment (academic history)
            IF v_previous_year_id IS NOT NULL AND v_previous_class_id IS NOT NULL THEN
                v_previous_enrollment_id := gen_random_uuid();
                INSERT INTO enrollments (
                    id, user_id, class_id, group_id, academic_year_id,
                    is_active, student_code, created_at
                ) VALUES (
                    v_previous_enrollment_id, v_user_id, v_previous_class_id, v_group_id,
                    v_previous_year_id, FALSE,
                    'STU-' || to_char(NOW() - INTERVAL '1 year', 'YYYY') || '-' || upper(substr(md5(v_class.class_id::text || v_student_index::text || 'prev'), 1, 6)),
                    NOW() - INTERVAL '1 year'
                )
                ON CONFLICT DO NOTHING;
            END IF;

            -- 5. payment plans + payments
            FOREACH v_category IN ARRAY v_categories LOOP
                IF v_category = 'activites' AND v_student_index = 4 THEN CONTINUE; END IF;
                IF v_category = 'autres' AND v_student_index IN (2, 4) THEN CONTINUE; END IF;

                v_plan_type := v_plan_types[_seed_idx(v_category || v_enrollment_id::text, array_length(v_plan_types, 1))];

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
                    v_payment_plan_id, v_enrollment_id, v_plan_type::payment_plan_type, v_plan_amount, 'TND',
                    'Plan ' || v_category || ' - ' || v_first_name || ' ' || v_last_name,
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
                        CASE WHEN v_payment_status = 'paid' THEN v_payment_methods[_seed_idx(v_payment_plan_id::text || v_payment_index::text, array_length(v_payment_methods, 1))] ELSE NULL END,
                        v_payment_status::payment_status,
                        'REF-' || upper(substr(md5(v_payment_plan_id::text || v_payment_index::text), 1, 8)),
                        'Paiement généré automatiquement pour tests', NOW(), v_user_id
                    );
                END LOOP;
            END LOOP;

            -- 6. grades + absences
            FOR v_semester IN
                SELECT s.id AS semester_id, s.number AS semester_number
                FROM semesters s
                WHERE s.academic_year_id = v_academic_year_id
                ORDER BY s.number
            LOOP
                FOR v_subject_offering IN
                    SELECT so.id AS subject_offering_id, so.coefficient
                    FROM subject_offerings so
                    WHERE so.class_id = v_class.class_id
                      AND so.semester_id = v_semester.semester_id
                LOOP
                    FOR v_component IN
                        SELECT gc.id AS component_id, gc.name, gc.weight_percent
                        FROM grade_components gc
                        WHERE gc.subject_offering_id = v_subject_offering.subject_offering_id
                    LOOP
                        v_grade_value := CASE v_student_index
                            WHEN 1 THEN 12 + _seed_idx(v_component.component_id::text || v_user_id::text, 7)
                            WHEN 2 THEN 9 + _seed_idx(v_component.component_id::text || v_user_id::text, 8)
                            WHEN 3 THEN 5 + _seed_idx(v_component.component_id::text || v_user_id::text, 8)
                            ELSE 8 + _seed_idx(v_component.component_id::text || v_user_id::text, 11)
                        END;

                        -- occasional missing grade for realism
                        IF _seed_idx(v_component.component_id::text || v_user_id::text || 'miss', 10) = 1 THEN
                            v_status := 'ND';
                            v_grade_value := NULL;
                        ELSE
                            v_status := CASE WHEN v_grade_value >= 10 THEN 'OK' ELSE 'NP' END;
                        END IF;

                        INSERT INTO grades (
                            id, enrollment_id, subject_offering_id, component_id,
                            grade_value, status, graded_at, created_at, updated_at, student_id
                        ) VALUES (
                            gen_random_uuid(), v_enrollment_id, v_subject_offering.subject_offering_id,
                            v_component.component_id, v_grade_value, v_status::grade_status,
                            NOW(), NOW(), NOW(), v_user_id
                        );
                    END LOOP;

                    -- More absences for student 3 to cross thresholds
                    FOR v_absence_index IN 1..(v_student_index * 3 + 1) LOOP
                        v_absence_date := (DATE '2025-09-20' + (v_absence_index * 5) + _seed_idx(v_user_id::text || v_absence_index::text, 5))::date;
                        v_hours := 1 + _seed_idx(v_subject_offering.subject_offering_id::text || v_absence_index::text, 2);
                        v_justified := (v_student_index = 1) OR (v_absence_index % 3 = 0);

                        INSERT INTO absence_records (
                            id, enrollment_id, subject_offering_id, date, hours_absent,
                            session_type, reason, justified, created_at, student_id
                        ) VALUES (
                            gen_random_uuid(), v_enrollment_id, v_subject_offering.subject_offering_id,
                            v_absence_date, v_hours,
                            (CASE WHEN v_absence_index % 2 = 0 THEN 'CI' ELSE 'TP' END)::session_type,
                            CASE WHEN v_justified THEN 'Certificat médical' ELSE 'Absent sans justification' END,
                            v_justified, NOW(), v_user_id
                        );
                    END LOOP;
                END LOOP;
            END LOOP;

            -- 7. suggestions (2 per student: one open, one replied)
            FOR v_suggestion_index IN 1..2 LOOP
                v_suggestion_id := gen_random_uuid();
                INSERT INTO suggestions (
                    id, student_id, subject, message, title, body, status, created_at,
                    suggestion_type, class_id, enrollment_id, student_code,
                    student_name, class_name, school_id, is_read, read_at
                ) VALUES (
                    v_suggestion_id, v_user_id,
                    v_suggestion_subjects[_seed_idx(v_user_id::text || v_suggestion_index::text, array_length(v_suggestion_subjects, 1))],
                    v_suggestion_messages[_seed_idx(v_user_id::text || v_suggestion_index::text || 'msg', array_length(v_suggestion_messages, 1))],
                    v_suggestion_subjects[_seed_idx(v_user_id::text || v_suggestion_index::text, array_length(v_suggestion_subjects, 1))],
                    v_suggestion_messages[_seed_idx(v_user_id::text || v_suggestion_index::text || 'msg', array_length(v_suggestion_messages, 1))],
                    (CASE WHEN v_suggestion_index = 1 AND v_admin_id IS NOT NULL THEN 'replied' ELSE 'sent' END)::suggestion_status,
                    NOW() - ((v_suggestion_index * 3) || ' days')::interval,
                    v_suggestion_types[_seed_idx(v_user_id::text || v_suggestion_index::text, array_length(v_suggestion_types, 1))],
                    v_class.class_id, v_enrollment_id, v_student_code,
                    v_first_name || ' ' || v_last_name, v_class.class_name, v_school_id,
                    v_suggestion_index = 1 AND v_admin_id IS NOT NULL,
                    CASE WHEN v_suggestion_index = 1 AND v_admin_id IS NOT NULL THEN NOW() - ((v_suggestion_index * 2) || ' days')::interval ELSE NULL END
                );

                -- Admin reply for the first suggestion
                IF v_suggestion_index = 1 AND v_admin_id IS NOT NULL THEN
                    INSERT INTO suggestion_replies (
                        id, suggestion_id, admin_id, message, created_at
                    ) VALUES (
                        gen_random_uuid(), v_suggestion_id, v_admin_id,
                        v_reply_texts[_seed_idx(v_suggestion_id::text, array_length(v_reply_texts, 1))],
                        NOW() - ((v_suggestion_index * 2) || ' days')::interval
                    );
                END IF;
            END LOOP;

            -- 8. password reset request for one student per class
            IF v_student_index = 2 THEN
                INSERT INTO password_reset_requests (
                    id, user_id, email, full_name, status, requested_at,
                    created_at
                ) VALUES (
                    gen_random_uuid(), v_user_id, v_email,
                    v_first_name || ' ' || v_last_name, 'pending',
                    NOW() - '2 days'::interval, NOW()
                );
            END IF;

            -- 9. user settings (varied)
            INSERT INTO user_settings (
                user_id, language, theme, notifications_enabled
            ) VALUES (
                v_user_id,
                v_languages[_seed_idx(v_user_id::text || 'lang', array_length(v_languages, 1))],
                v_themes[_seed_idx(v_user_id::text || 'theme', array_length(v_themes, 1))],
                _seed_idx(v_user_id::text || 'notif', 3) <> 1
            )
            ON CONFLICT (user_id) DO NOTHING;

        END LOOP;
    END LOOP;

    RAISE NOTICE 'Done. New students inserted: %', v_inserted_count;
END $$;

-- Optionally drop the helper after use (uncomment if desired)
-- DROP FUNCTION IF EXISTS _seed_idx(TEXT, INT);
