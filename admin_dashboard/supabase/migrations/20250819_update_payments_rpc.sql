-- Update get_payments_for_student RPC to include category field
CREATE OR REPLACE FUNCTION public.get_payments_for_student(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'plan_id', pp.id,
      'plan_type', pp.plan_type,
      'amount_total', pp.amount_total,
      'currency', pp.currency,
      'description', pp.description,
      'category', pp.category,
      'academic_year', ay.name,
      'payments', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'id', p.id,
          'amount', p.amount,
          'due_date', p.due_date,
          'paid_at', p.paid_at,
          'method', p.method,
          'status', p.status,
          'reference', p.reference,
          'notes', p.notes
        ) ORDER BY p.due_date)
        FROM public.payments p
        WHERE p.payment_plan_id = pp.id
      ), '[]'::jsonb),
      'total_paid', (
        SELECT COALESCE(SUM(p.amount), 0)
        FROM public.payments p
        WHERE p.payment_plan_id = pp.id AND p.status = 'paid'
      ),
      'remaining', pp.amount_total - COALESCE((
        SELECT SUM(p.amount)
        FROM public.payments p
        WHERE p.payment_plan_id = pp.id AND p.status = 'paid'
      ), 0)
    )
  )
  INTO v_result
  FROM public.payment_plans pp
  JOIN public.enrollments e ON pp.enrollment_id = e.id
  JOIN public.academic_years ay ON e.academic_year_id = ay.id
  WHERE e.user_id = p_user_id
    AND e.is_active = true;

  RETURN COALESCE(v_result, '[]'::jsonb);
END $$;

GRANT EXECUTE ON FUNCTION public.get_payments_for_student(uuid) TO authenticated;
