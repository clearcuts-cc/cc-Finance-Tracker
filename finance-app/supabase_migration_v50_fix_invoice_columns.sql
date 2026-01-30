-- Migration V50: Fix Invoices Table Schema
-- Adds missing columns expected by the application logic
-- Specifically addresses "Could not find the 'client_email' column" error.

ALTER TABLE IF EXISTS public.invoices 
ADD COLUMN IF NOT EXISTS invoice_number TEXT,
ADD COLUMN IF NOT EXISTS invoice_date DATE,
ADD COLUMN IF NOT EXISTS due_date DATE,
ADD COLUMN IF NOT EXISTS client_name TEXT,
ADD COLUMN IF NOT EXISTS client_email TEXT,
ADD COLUMN IF NOT EXISTS client_address TEXT,
ADD COLUMN IF NOT EXISTS client_phone TEXT,
ADD COLUMN IF NOT EXISTS client_id BIGINT REFERENCES public.clients(id),
ADD COLUMN IF NOT EXISTS agency_name TEXT,
ADD COLUMN IF NOT EXISTS agency_contact TEXT,
ADD COLUMN IF NOT EXISTS agency_address TEXT,
ADD COLUMN IF NOT EXISTS agency_logo TEXT,
ADD COLUMN IF NOT EXISTS subtotal NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS tax_percent NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS tax_amount NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS discount_percent NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS discount_amount NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS grand_total NUMERIC DEFAULT 0,
ADD COLUMN IF NOT EXISTS payment_status TEXT DEFAULT 'pending',
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS admin_id UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES auth.users(id),
ADD COLUMN IF NOT EXISTS created_by_name TEXT,
ADD COLUMN IF NOT EXISTS created_by_email TEXT;

-- Ensure the secondary table also has proper RLS
ALTER TABLE IF EXISTS public.invoice_services ENABLE ROW LEVEL SECURITY;

-- Post-migration notice:
-- After running this in Supabase SQL Editor, please refresh the application.
