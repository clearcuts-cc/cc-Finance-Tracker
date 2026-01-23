-- ============================================
-- Fix Permissive RLS Policies v2
-- Replace USING(true) with proper user-based checks
-- Migration v6: Strict RLS Policies
-- ============================================

-- Helper function to check if user is admin (with fixed search_path)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public;

-- ============================================
-- 1. CLIENTS TABLE - Fix INSERT, UPDATE, DELETE
-- clients.user_id is UUID (nullable)
-- ============================================

-- Drop existing permissive policies
DROP POLICY IF EXISTS "Allow authenticated users to insert clients" ON public.clients;
DROP POLICY IF EXISTS "Allow authenticated users to update clients" ON public.clients;
DROP POLICY IF EXISTS "Allow authenticated users to delete clients" ON public.clients;

-- INSERT: Users can insert clients and set their user_id or leave null
CREATE POLICY "Users can insert their own clients"
ON public.clients FOR INSERT
TO authenticated
WITH CHECK (
  user_id IS NULL OR user_id = auth.uid() OR public.is_admin()
);

-- UPDATE: Users can update clients they created or admins can update any
CREATE POLICY "Users can update their own clients or admins"
ON public.clients FOR UPDATE
TO authenticated
USING (user_id IS NULL OR user_id = auth.uid() OR public.is_admin())
WITH CHECK (user_id IS NULL OR user_id = auth.uid() OR public.is_admin());

-- DELETE: Only admins can delete clients
CREATE POLICY "Only admins can delete clients"
ON public.clients FOR DELETE
TO authenticated
USING (public.is_admin());

-- ============================================
-- 2. FINANCE_ENTRIES TABLE - Fix UPDATE, DELETE
-- finance_entries.user_id is UUID
-- ============================================

-- Drop existing permissive policies
DROP POLICY IF EXISTS "Allow authenticated users to update finance entries" ON public.finance_entries;
DROP POLICY IF EXISTS "Allow authenticated users to delete finance entries" ON public.finance_entries;

-- UPDATE: Users can update their own entries or admins can update any
CREATE POLICY "Users can update their own entries or admins"
ON public.finance_entries FOR UPDATE
TO authenticated
USING (user_id = auth.uid() OR public.is_admin())
WITH CHECK (user_id = auth.uid() OR public.is_admin());

-- DELETE: Only admins can delete entries
CREATE POLICY "Only admins can delete finance entries"
ON public.finance_entries FOR DELETE
TO authenticated
USING (public.is_admin());

-- ============================================
-- 3. INVOICES TABLE - Fix UPDATE, DELETE
-- invoices table has NO user_id, so use admin-only for modifications
-- ============================================

-- Drop existing permissive policies
DROP POLICY IF EXISTS "Allow authenticated users to update invoices" ON public.invoices;
DROP POLICY IF EXISTS "Allow authenticated users to delete invoices" ON public.invoices;

-- UPDATE: Only admins can update invoices
CREATE POLICY "Only admins can update invoices"
ON public.invoices FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- DELETE: Only admins can delete invoices
CREATE POLICY "Only admins can delete invoices"
ON public.invoices FOR DELETE
TO authenticated
USING (public.is_admin());

-- ============================================
-- 4. INVOICE_SERVICES TABLE - Fix INSERT, UPDATE, DELETE
-- Linked to invoices via invoice_id, no direct user ownership
-- ============================================

-- Drop existing permissive policies
DROP POLICY IF EXISTS "Allow authenticated users to insert invoice services" ON public.invoice_services;
DROP POLICY IF EXISTS "Allow authenticated users to update invoice services" ON public.invoice_services;
DROP POLICY IF EXISTS "Allow authenticated users to delete invoice services" ON public.invoice_services;

-- INSERT: Only admins can insert invoice services
CREATE POLICY "Only admins can insert invoice services"
ON public.invoice_services FOR INSERT
TO authenticated
WITH CHECK (public.is_admin());

-- UPDATE: Only admins can update invoice services
CREATE POLICY "Only admins can update invoice services"
ON public.invoice_services FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- DELETE: Only admins can delete invoice services
CREATE POLICY "Only admins can delete invoice services"
ON public.invoice_services FOR DELETE
TO authenticated
USING (public.is_admin());

-- ============================================
-- 5. SETTINGS TABLE - Fix INSERT, UPDATE
-- Settings are global/shared - admin only
-- ============================================

-- Drop existing permissive policies
DROP POLICY IF EXISTS "Allow authenticated users to insert settings" ON public.settings;
DROP POLICY IF EXISTS "Allow authenticated users to update settings" ON public.settings;

-- INSERT: Only admins can insert settings
CREATE POLICY "Only admins can insert settings"
ON public.settings FOR INSERT
TO authenticated
WITH CHECK (public.is_admin());

-- UPDATE: Only admins can update settings
CREATE POLICY "Only admins can update settings"
ON public.settings FOR UPDATE
TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- ============================================
-- 6. LOGIN_HISTORY TABLE - Fix INSERT
-- login_history.user_id is INTEGER (not UUID)
-- ============================================

-- Drop existing permissive policy
DROP POLICY IF EXISTS "System can insert login history" ON public.login_history;

-- INSERT: All authenticated users can log their login
CREATE POLICY "Authenticated users can insert login history"
ON public.login_history FOR INSERT
TO authenticated
WITH CHECK (auth.uid() IS NOT NULL);
