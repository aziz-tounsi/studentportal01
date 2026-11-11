-- Table to store device FCM push tokens for background notifications
CREATE TABLE IF NOT EXISTS public.user_fcm_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    token TEXT NOT NULL,
    device_type TEXT DEFAULT 'android',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT user_fcm_tokens_user_token_key UNIQUE(user_id, token)
);

ALTER TABLE public.user_fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Students can manage their own device tokens
DROP POLICY IF EXISTS "Users can manage their own FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Users can manage their own FCM tokens"
ON public.user_fcm_tokens
FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Admins and staff can view tokens to dispatch push notifications
DROP POLICY IF EXISTS "Admins can view all FCM tokens" ON public.user_fcm_tokens;
CREATE POLICY "Admins can view all FCM tokens"
ON public.user_fcm_tokens
FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid() AND role::text IN ('admin', 'staff')
    )
);
