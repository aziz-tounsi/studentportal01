-- ============================================================================
-- MIGRATION 041: AI PROXY TELEMETRY & QUOTA ENFORCEMENT
-- ============================================================================
-- Description:
--   1. Creates `platform_settings` table for global AI controls & default models.
--   2. Creates `ai_school_quotas` table for per-school monthly budgets & rate limits.
--   3. Creates `ai_usage_logs` table for financial telemetry & audit of every AI call.
--   4. Creates RPC `public.record_ai_usage` for atomic logging and quota increments.
--   5. Creates RPC `public.check_student_daily_ai_limit` to enforce rate limits.
--   6. Configures multi-tenant Row Level Security (RLS) policies.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- STEP 1: PLATFORM SETTINGS TABLE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.platform_settings (
    id INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    global_ai_kill_switch BOOLEAN NOT NULL DEFAULT FALSE,
    default_ai_model TEXT NOT NULL DEFAULT 'google/gemini-2.0-flash-exp:free',
    fallback_ai_model TEXT NOT NULL DEFAULT 'deepseek/deepseek-chat',
    support_email TEXT NOT NULL DEFAULT 'support@pythagore.tn',
    platform_fee_currency TEXT NOT NULL DEFAULT 'TND',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed row 1 if absent
INSERT INTO public.platform_settings (id, global_ai_kill_switch, default_ai_model, fallback_ai_model)
VALUES (1, false, 'google/gemini-2.0-flash-exp:free', 'deepseek/deepseek-chat')
ON CONFLICT (id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- STEP 2: AI SCHOOL QUOTAS TABLE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.ai_school_quotas (
    school_id UUID PRIMARY KEY REFERENCES public.schools(id) ON DELETE CASCADE,
    monthly_budget_usd NUMERIC(8, 2) NOT NULL DEFAULT 20.00,
    spent_current_month_usd NUMERIC(8, 4) NOT NULL DEFAULT 0.0000,
    tokens_current_month BIGINT NOT NULL DEFAULT 0,
    daily_messages_per_student INT NOT NULL DEFAULT 30,
    is_quota_exceeded BOOLEAN NOT NULL DEFAULT FALSE,
    kill_switch_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed quota records for all existing schools
INSERT INTO public.ai_school_quotas (school_id, monthly_budget_usd, daily_messages_per_student)
SELECT id, 20.00, 30 FROM public.schools
ON CONFLICT (school_id) DO NOTHING;

-- ----------------------------------------------------------------------------
-- STEP 3: AI USAGE LOGS TABLE
-- ----------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.ai_usage_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id UUID NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    model TEXT NOT NULL,
    prompt_tokens INT NOT NULL DEFAULT 0,
    completion_tokens INT NOT NULL DEFAULT 0,
    total_tokens INT NOT NULL DEFAULT 0,
    cost_usd NUMERIC(10, 6) NOT NULL DEFAULT 0.000000,
    latency_ms INT,
    status TEXT NOT NULL DEFAULT 'success' CHECK (status IN ('success', 'rate_limited', 'flagged', 'error')),
    flagged_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_school_date ON public.ai_usage_logs(school_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_usage_student_date ON public.ai_usage_logs(student_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_usage_daily_count ON public.ai_usage_logs(student_id, created_at);

-- ----------------------------------------------------------------------------
-- STEP 4: RPC FUNCTIONS
-- ----------------------------------------------------------------------------

-- 4.1 Record AI Usage & Increment Quota Atomically
CREATE OR REPLACE FUNCTION public.record_ai_usage(
    p_school_id UUID,
    p_student_id UUID,
    p_model TEXT,
    p_prompt_tokens INT,
    p_completion_tokens INT,
    p_total_tokens INT,
    p_cost_usd NUMERIC,
    p_latency_ms INT,
    p_status TEXT DEFAULT 'success',
    p_flagged_reason TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_log_id UUID;
    v_spent NUMERIC;
    v_budget NUMERIC;
BEGIN
    -- 1. Insert telemetry row
    INSERT INTO public.ai_usage_logs (
        school_id, student_id, model, prompt_tokens, completion_tokens,
        total_tokens, cost_usd, latency_ms, status, flagged_reason
    ) VALUES (
        p_school_id, p_student_id, p_model, p_prompt_tokens, p_completion_tokens,
        p_total_tokens, p_cost_usd, p_latency_ms, p_status, p_flagged_reason
    ) RETURNING id INTO v_log_id;

    -- 2. Update monthly consumption atomically
    INSERT INTO public.ai_school_quotas (
        school_id, spent_current_month_usd, tokens_current_month, updated_at
    ) VALUES (
        p_school_id, p_cost_usd, p_total_tokens, NOW()
    )
    ON CONFLICT (school_id) DO UPDATE SET
        spent_current_month_usd = public.ai_school_quotas.spent_current_month_usd + p_cost_usd,
        tokens_current_month = public.ai_school_quotas.tokens_current_month + p_total_tokens,
        updated_at = NOW();

    -- 3. Flag quota if budget exceeded
    SELECT spent_current_month_usd, monthly_budget_usd
    INTO v_spent, v_budget
    FROM public.ai_school_quotas
    WHERE school_id = p_school_id;

    IF v_spent >= v_budget THEN
        UPDATE public.ai_school_quotas
        SET is_quota_exceeded = TRUE
        WHERE school_id = p_school_id;
    END IF;

    RETURN v_log_id;
END;
$$;

-- 4.2 Check Student Daily AI Limit & School Quota
CREATE OR REPLACE FUNCTION public.check_student_daily_ai_limit(
    p_student_id UUID,
    p_school_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_global_kill BOOLEAN;
    v_school_exceeded BOOLEAN;
    v_school_kill BOOLEAN;
    v_daily_limit INT;
    v_today_count INT;
BEGIN
    -- Check platform global kill switch
    SELECT global_ai_kill_switch INTO v_global_kill FROM public.platform_settings WHERE id = 1;
    IF COALESCE(v_global_kill, false) THEN
        RETURN jsonb_build_object('allowed', false, 'reason', 'global_kill_switch');
    END IF;

    -- Check school quota & kill switch
    SELECT is_quota_exceeded, kill_switch_enabled, daily_messages_per_student
    INTO v_school_exceeded, v_school_kill, v_daily_limit
    FROM public.ai_school_quotas
    WHERE school_id = p_school_id;

    IF COALESCE(v_school_kill, false) THEN
        RETURN jsonb_build_object('allowed', false, 'reason', 'school_kill_switch');
    END IF;

    IF COALESCE(v_school_exceeded, false) THEN
        RETURN jsonb_build_object('allowed', false, 'reason', 'school_quota_exceeded');
    END IF;

    v_daily_limit := COALESCE(v_daily_limit, 30);

    -- Count successful messages sent today by this student
    SELECT COUNT(*) INTO v_today_count
    FROM public.ai_usage_logs
    WHERE student_id = p_student_id
      AND status = 'success'
      AND created_at >= CURRENT_DATE;

    IF v_today_count >= v_daily_limit THEN
        RETURN jsonb_build_object(
            'allowed', false, 
            'reason', 'daily_limit_reached',
            'daily_limit', v_daily_limit,
            'messages_used', v_today_count
        );
    END IF;

    RETURN jsonb_build_object(
        'allowed', true,
        'daily_limit', v_daily_limit,
        'messages_used', v_today_count
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_ai_usage TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.check_student_daily_ai_limit TO authenticated, anon;

-- ----------------------------------------------------------------------------
-- STEP 5: ROW LEVEL SECURITY POLICIES
-- ----------------------------------------------------------------------------

-- Platform Settings RLS
ALTER TABLE public.platform_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "platform_settings_read_authenticated" ON public.platform_settings
    FOR SELECT TO authenticated
    USING (true);

CREATE POLICY "platform_settings_super_admin_manage" ON public.platform_settings
    FOR ALL TO authenticated
    USING (public.is_super_admin())
    WITH CHECK (public.is_super_admin());

-- AI School Quotas RLS
ALTER TABLE public.ai_school_quotas ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ai_school_quotas_select" ON public.ai_school_quotas
    FOR SELECT TO authenticated
    USING (
        (public.is_school_admin() AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    );

CREATE POLICY "ai_school_quotas_super_admin_manage" ON public.ai_school_quotas
    FOR ALL TO authenticated
    USING (public.is_super_admin())
    WITH CHECK (public.is_super_admin());

-- AI Usage Logs RLS
ALTER TABLE public.ai_usage_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ai_usage_logs_select" ON public.ai_usage_logs
    FOR SELECT TO authenticated
    USING (
        (student_id = auth.uid() AND school_id = public.get_user_school_id())
        OR (public.is_school_admin() AND school_id = public.get_user_school_id())
        OR public.is_super_admin()
    );

CREATE POLICY "ai_usage_logs_insert" ON public.ai_usage_logs
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

-- Immutable: cannot alter or delete telemetry history
CREATE POLICY "ai_usage_logs_no_update" ON public.ai_usage_logs
    FOR UPDATE TO authenticated
    USING (false);

CREATE POLICY "ai_usage_logs_no_delete" ON public.ai_usage_logs
    FOR DELETE TO authenticated
    USING (false);

-- ============================================================================
-- END OF MIGRATION 041
-- ============================================================================
