-- ============================================================================
-- ROLLBACK MIGRATION 041: AI PROXY TELEMETRY DOWN
-- ============================================================================

DROP POLICY IF EXISTS "ai_usage_logs_no_delete" ON public.ai_usage_logs;
DROP POLICY IF EXISTS "ai_usage_logs_no_update" ON public.ai_usage_logs;
DROP POLICY IF EXISTS "ai_usage_logs_insert" ON public.ai_usage_logs;
DROP POLICY IF EXISTS "ai_usage_logs_select" ON public.ai_usage_logs;

DROP POLICY IF EXISTS "ai_school_quotas_super_admin_manage" ON public.ai_school_quotas;
DROP POLICY IF EXISTS "ai_school_quotas_select" ON public.ai_school_quotas;

DROP POLICY IF EXISTS "platform_settings_super_admin_manage" ON public.platform_settings;
DROP POLICY IF EXISTS "platform_settings_read_authenticated" ON public.platform_settings;

DROP FUNCTION IF EXISTS public.check_student_daily_ai_limit(UUID, UUID);
DROP FUNCTION IF EXISTS public.record_ai_usage(UUID, UUID, TEXT, INT, INT, INT, NUMERIC, INT, TEXT, TEXT);

DROP TABLE IF EXISTS public.ai_usage_logs;
DROP TABLE IF EXISTS public.ai_school_quotas;
DROP TABLE IF EXISTS public.platform_settings;
