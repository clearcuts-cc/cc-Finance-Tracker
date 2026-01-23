-- ============================================
-- Enable Row Level Security on all public tables
-- Migration v5: Fix RLS disabled errors
-- ============================================

-- 1. SETTINGS TABLE
-- Enable RLS
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to read settings
CREATE POLICY "Allow authenticated users to read settings"
ON public.settings FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert settings
CREATE POLICY "Allow authenticated users to insert settings"
ON public.settings FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update settings
CREATE POLICY "Allow authenticated users to update settings"
ON public.settings FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- 2. LOGIN_HISTORY TABLE
-- Enable RLS
ALTER TABLE public.login_history ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see their own login history
CREATE POLICY "Users can view their own login history"
ON public.login_history FOR SELECT
TO authenticated
USING (user_id::text = auth.uid()::text OR user_id::text = (SELECT id::text FROM public.users WHERE id = auth.uid()));

-- Policy: System can insert login history for authenticated users
CREATE POLICY "System can insert login history"
ON public.login_history FOR INSERT
TO authenticated
WITH CHECK (true);

-- 3. CLIENTS TABLE
-- Enable RLS
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to read all clients (shared resource)
CREATE POLICY "Allow authenticated users to read clients"
ON public.clients FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert clients
CREATE POLICY "Allow authenticated users to insert clients"
ON public.clients FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update clients
CREATE POLICY "Allow authenticated users to update clients"
ON public.clients FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy: Allow authenticated users to delete clients
CREATE POLICY "Allow authenticated users to delete clients"
ON public.clients FOR DELETE
TO authenticated
USING (true);

-- 4. FINANCE_ENTRIES TABLE
-- Enable RLS
ALTER TABLE public.finance_entries ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to read all finance entries (for dashboard)
CREATE POLICY "Allow authenticated users to read finance entries"
ON public.finance_entries FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert finance entries
CREATE POLICY "Allow authenticated users to insert finance entries"
ON public.finance_entries FOR INSERT
TO authenticated
WITH CHECK (auth.uid() IS NOT NULL);

-- Policy: Allow authenticated users to update finance entries
CREATE POLICY "Allow authenticated users to update finance entries"
ON public.finance_entries FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy: Allow authenticated users to delete finance entries
CREATE POLICY "Allow authenticated users to delete finance entries"
ON public.finance_entries FOR DELETE
TO authenticated
USING (true);

-- 5. INVOICES TABLE
-- Enable RLS
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to read all invoices
CREATE POLICY "Allow authenticated users to read invoices"
ON public.invoices FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert invoices
CREATE POLICY "Allow authenticated users to insert invoices"
ON public.invoices FOR INSERT
TO authenticated
WITH CHECK (auth.uid() IS NOT NULL);

-- Policy: Allow authenticated users to update invoices
CREATE POLICY "Allow authenticated users to update invoices"
ON public.invoices FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy: Allow authenticated users to delete invoices
CREATE POLICY "Allow authenticated users to delete invoices"
ON public.invoices FOR DELETE
TO authenticated
USING (true);

-- 6. INVOICE_SERVICES TABLE
-- Enable RLS
ALTER TABLE public.invoice_services ENABLE ROW LEVEL SECURITY;

-- Policy: Allow authenticated users to read all invoice services
CREATE POLICY "Allow authenticated users to read invoice services"
ON public.invoice_services FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert invoice services
CREATE POLICY "Allow authenticated users to insert invoice services"
ON public.invoice_services FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update invoice services
CREATE POLICY "Allow authenticated users to update invoice services"
ON public.invoice_services FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy: Allow authenticated users to delete invoice services
CREATE POLICY "Allow authenticated users to delete invoice services"
ON public.invoice_services FOR DELETE
TO authenticated
USING (true);
