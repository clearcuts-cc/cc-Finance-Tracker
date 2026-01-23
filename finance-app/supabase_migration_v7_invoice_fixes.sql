-- ============================================
-- Fix All Issues Migration v7
-- 1. Add user_id to invoices table
-- 2. Fix RLS policies for invoices and invoice_services
-- ============================================

-- Add user_id column to invoices table
ALTER TABLE public.invoices 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- ============================================
-- INVOICES TABLE POLICIES
-- ============================================

-- Drop existing policies
DROP POLICY IF EXISTS "Allow authenticated users to insert invoices" ON public.invoices;
DROP POLICY IF EXISTS "Allow authenticated users to read invoices" ON public.invoices;
DROP POLICY IF EXISTS "Only admins can update invoices" ON public.invoices;
DROP POLICY IF EXISTS "Only admins can delete invoices" ON public.invoices;

-- Users can insert their own invoices
CREATE POLICY "Users can insert their own invoices"
ON public.invoices FOR INSERT
TO authenticated
WITH CHECK (user_id = (select auth.uid()) OR user_id IS NULL);

-- Users can read their own invoices
CREATE POLICY "Users can read their own invoices"
ON public.invoices FOR SELECT
TO authenticated
USING (user_id = (select auth.uid()) OR user_id IS NULL);

-- Users can update their own invoices
CREATE POLICY "Users can update their own invoices"
ON public.invoices FOR UPDATE
TO authenticated
USING (user_id = (select auth.uid()) OR user_id IS NULL OR public.is_admin())
WITH CHECK (user_id = (select auth.uid()) OR user_id IS NULL OR public.is_admin());

-- Users can delete their own invoices
CREATE POLICY "Users can delete their own invoices"
ON public.invoices FOR DELETE
TO authenticated
USING (user_id = (select auth.uid()) OR user_id IS NULL OR public.is_admin());

-- ============================================
-- INVOICE_SERVICES TABLE POLICIES
-- ============================================

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Only admins can insert invoice services" ON public.invoice_services;
DROP POLICY IF EXISTS "Only admins can update invoice services" ON public.invoice_services;
DROP POLICY IF EXISTS "Only admins can delete invoice services" ON public.invoice_services;

-- Allow authenticated users to manage invoice services
CREATE POLICY "Users can insert invoice services"
ON public.invoice_services FOR INSERT
TO authenticated
WITH CHECK ((select auth.uid()) IS NOT NULL);

CREATE POLICY "Users can update invoice services"
ON public.invoice_services FOR UPDATE
TO authenticated
USING ((select auth.uid()) IS NOT NULL)
WITH CHECK ((select auth.uid()) IS NOT NULL);

CREATE POLICY "Users can delete invoice services"
ON public.invoice_services FOR DELETE
TO authenticated
USING ((select auth.uid()) IS NOT NULL);
