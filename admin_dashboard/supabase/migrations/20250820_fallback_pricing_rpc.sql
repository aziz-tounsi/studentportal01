-- Update get_payments_for_student RPC to use payment_pricing as fallback when amount_total is 0
CREATE OR REPLACE FUNCTION public.get_payments_for_student(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_result jsonb;
  v_pricing_amount numeric;
  v_payment_count integer;
BEGIN
  SELECT jsonb_agg(
    jsonb_build_object(
      'plan_id', pp.id,
      'plan_type', pp.plan_type,
      'amount_total', 
        CASE 
          WHEN pp.amount_total > 0 THEN pp.amount_total
          ELSE COALESCE((
            SELECT pr.amount
            FROM public.payment_pricing pr
            WHERE pr.school_id = c.school_id
              AND pr.category = COALESCE(pp.category, 'scolarite')
              AND (pr.niveau_id IS NULL OR pr.niveau_id = c.niveau_id)
              AND (pr.section_id IS NULL OR pr.section_id = c.section_id)
              AND (pr.academic_year_id IS NULL OR pr.academic_year_id = e.academic_year_id)
              AND pr.is_active = true
            ORDER BY pr.section_id NULLS LAST
            LIMIT 1
          ), 0)
        END,
      'currency', pp.currency,
      'description', pp.description,
      'category', pp.category,
      'academic_year', ay.name,
      'payments', COALESCE((
        SELECT jsonb_agg(jsonb_build_object(
          'id', p.id,
          'amount', 
            CASE 
              WHEN p.amount > 0 THEN p.amount
              WHEN pp.amount_total > 0 THEN p.amount
              ELSE 
                COALESCE((
                  SELECT pr.amount / GREATEST(
                    (SELECT COUNT(*)::numeric FROM public.payments WHERE payment_plan_id = pp.id),
                    1
                  )
                  FROM public.payment_pricing pr
                  WHERE pr.school_id = c.school_id
                    AND pr.category = COALESCE(pp.category, 'scolarite')
                    AND (pr.niveau_id IS NULL OR pr.niveau_id = c.niveau_id)
                    AND (pr.section_id IS NULL OR pr.section_id = c.section_id)
                    AND (pr.academic_year_id IS NULL OR pr.academic_year_id = e.academic_year_id)
                    AND pr.is_active = true
                  ORDER BY pr.section_id NULLS LAST
                  LIMIT 1
                ), 0)
            END,
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
      'remaining', 
        (CASE 
          WHEN pp.amount_total > 0 THEN pp.amount_total
          ELSE COALESCE((
            SELECT pr.amount
            FROM public.payment_pricing pr
            WHERE pr.school_id = c.school_id
              AND pr.category = COALESCE(pp.category, 'scolarite')
              AND (pr.niveau_id IS NULL OR pr.niveau_id = c.niveau_id)
              AND (pr.section_id IS NULL OR pr.section_id = c.section_id)
              AND (pr.academic_year_id IS NULL OR pr.academic_year_id = e.academic_year_id)
              AND pr.is_active = true
            ORDER BY pr.section_id NULLS LAST
            LIMIT 1
          ), 0)
        END) - COALESCE((
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
  JOIN public.classes c ON c.id = e.class_id
  WHERE e.user_id = p_user_id
    AND e.is_active = true;

  RETURN COALESCE(v_result, '[]'::jsonb);
END $$;

GRANT EXECUTE ON FUNCTION public.get_payments_for_student(uuid) TO authenticated;
