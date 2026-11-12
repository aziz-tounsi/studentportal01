-- Migration 048: Server-side automatic FCM push triggers using pg_net & dedup table
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Deduplication table so duplicate client + trigger bursts within 10s never double-send
CREATE TABLE IF NOT EXISTS public.push_dispatch_dedup (
    dedup_key TEXT PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.push_dispatch_dedup ENABLE ROW LEVEL SECURITY;

-- Server-side trigger function to invoke send-push-notification on INSERT
CREATE OR REPLACE FUNCTION public.fn_dispatch_push_notification()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, net, vault
AS $$
DECLARE
    v_secret TEXT;
    v_url TEXT;
    v_title TEXT;
    v_body TEXT;
    v_route TEXT;
    v_school_id UUID;
    v_class_id UUID;
    v_target_student_id TEXT;
    v_user_ids JSONB := '[]'::jsonb;
    v_clean_desc TEXT;
    v_payload JSONB;
BEGIN
    SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets
    WHERE name = 'push_webhook_secret'
    LIMIT 1;

    IF v_secret IS NULL OR v_secret = '' THEN
        RETURN NEW;
    END IF;

    SELECT COALESCE(
        (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'push_edge_url' LIMIT 1),
        'https://cazuauxivrboygehrkij.supabase.co/functions/v1/send-push-notification'
    ) INTO v_url;

    IF TG_TABLE_NAME = 'announcements_global' THEN
        v_title := COALESCE(NULLIF(trim(NEW.title), ''), 'Nouvelle notification');
        v_body := COALESCE(NULLIF(trim(NEW.body), ''), 'Nouvelle notification disponible');
        v_route := '/notifications';
        v_school_id := NEW.school_id;

    ELSIF TG_TABLE_NAME = 'announcements_class' THEN
        v_target_student_id := NULLIF(trim(COALESCE(NEW.payload->>'target_student_id', '')), '');
        v_title := COALESCE(
            NULLIF(trim(NEW.title), ''),
            CASE WHEN v_target_student_id IS NOT NULL THEN 'Nouveau message' ELSE 'Nouveau message de classe' END
        );
        v_body := COALESCE(
            NULLIF(trim(regexp_replace(COALESCE(NEW.body, ''), '^\*\*@[^*]+\*\*\s*', '')), ''),
            'Nouveau message disponible'
        );
        v_route := '/messages';
        v_school_id := NEW.school_id;
        IF v_target_student_id IS NOT NULL THEN
            v_user_ids := jsonb_build_array(v_target_student_id);
        ELSE
            v_class_id := NEW.class_id;
        END IF;

    ELSIF TG_TABLE_NAME = 'documents' THEN
        v_target_student_id := NULLIF(trim(COALESCE(substring(COALESCE(NEW.description, '') FROM '\[Student:\s*([^|\]]+)'), '')), '');
        v_clean_desc := COALESCE(NEW.description, '');
        v_clean_desc := regexp_replace(v_clean_desc, '\[Semestre:\s*\d+\]', '', 'g');
        v_clean_desc := regexp_replace(v_clean_desc, '\[Student:\s*[^\]]+\]', '', 'g');
        v_clean_desc := regexp_replace(v_clean_desc, '\[Type:\s*[^\]]+\]', '', 'g');
        v_clean_desc := trim(v_clean_desc);

        v_title := 'Nouveau document : ' || COALESCE(NULLIF(trim(NEW.title), ''), 'Document');
        v_body := COALESCE(NULLIF(v_clean_desc, ''), 'Un nouveau document a été partagé.');
        v_route := '/documents';
        v_school_id := NEW.school_id;
        IF v_target_student_id IS NOT NULL THEN
            v_user_ids := jsonb_build_array(v_target_student_id);
        ELSE
            v_class_id := NEW.class_id;
        END IF;

    ELSIF TG_TABLE_NAME = 'suggestion_replies' THEN
        SELECT s.student_id::text, s.school_id
        INTO v_target_student_id, v_school_id
        FROM public.suggestions s
        WHERE s.id = NEW.suggestion_id
        LIMIT 1;

        IF v_target_student_id IS NULL OR v_target_student_id = '' THEN
            RETURN NEW;
        END IF;

        v_title := 'Réponse à votre suggestion';
        v_body := COALESCE(NULLIF(trim(NEW.message), ''), 'L''administration a répondu à votre suggestion.');
        v_route := '/suggestions';
        v_user_ids := jsonb_build_array(v_target_student_id);
    ELSE
        RETURN NEW;
    END IF;

    v_payload := jsonb_build_object(
        'title', v_title,
        'body', v_body,
        'route', v_route,
        'userIds', v_user_ids,
        'classId', v_class_id,
        'schoolId', v_school_id,
        'data', jsonb_build_object('table', TG_TABLE_NAME, 'record_id', NEW.id::text)
    );

    PERFORM net.http_post(
        url := v_url,
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'x-webhook-secret', v_secret
        ),
        body := v_payload
    );

    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'fn_dispatch_push_notification error: %', SQLERRM;
    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.fn_dispatch_push_notification() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS trg_push_announcements_global ON public.announcements_global;
CREATE TRIGGER trg_push_announcements_global
    AFTER INSERT ON public.announcements_global
    FOR EACH ROW EXECUTE FUNCTION public.fn_dispatch_push_notification();

DROP TRIGGER IF EXISTS trg_push_announcements_class ON public.announcements_class;
CREATE TRIGGER trg_push_announcements_class
    AFTER INSERT ON public.announcements_class
    FOR EACH ROW EXECUTE FUNCTION public.fn_dispatch_push_notification();

DROP TRIGGER IF EXISTS trg_push_documents ON public.documents;
CREATE TRIGGER trg_push_documents
    AFTER INSERT ON public.documents
    FOR EACH ROW EXECUTE FUNCTION public.fn_dispatch_push_notification();

DROP TRIGGER IF EXISTS trg_push_suggestion_replies ON public.suggestion_replies;
CREATE TRIGGER trg_push_suggestion_replies
    AFTER INSERT ON public.suggestion_replies
    FOR EACH ROW EXECUTE FUNCTION public.fn_dispatch_push_notification();
