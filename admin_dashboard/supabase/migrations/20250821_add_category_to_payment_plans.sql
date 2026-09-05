-- Add category column to payment_plans table
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name = 'payment_plans'
        AND column_name = 'category'
    ) THEN
        ALTER TABLE public.payment_plans ADD COLUMN category text DEFAULT 'scolarite';
        RAISE NOTICE 'Added category column to payment_plans';
    ELSE
        RAISE NOTICE 'category column already exists';
    END IF;
END $$;

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_payment_plans_category ON public.payment_plans(category);
