-- Fix Auth RLS Performance and Duplicate Policy Warnings
-- This script consolidates permissions into efficient policies and removes duplicates.

-- ==========================================
-- 1. Invoices Table
-- ==========================================
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing/conflicting policies to fix "Multiple Permissive Policies" warning
DROP POLICY IF EXISTS "invoice_access_policy" ON invoices;
DROP POLICY IF EXISTS "invoices_select" ON invoices;
DROP POLICY IF EXISTS "invoices_insert" ON invoices;
DROP POLICY IF EXISTS "invoices_update" ON invoices;
DROP POLICY IF EXISTS "invoices_delete" ON invoices;
DROP POLICY IF EXISTS "Enable read access for owners" ON invoices;
DROP POLICY IF EXISTS "Enable insert for authenticated users" ON invoices;

-- Create Single Optimized Policy using (select auth.uid()) for performance
CREATE POLICY "invoice_access_policy" ON invoices
FOR ALL
USING (
  (select auth.uid()) = user_id OR 
  (select auth.uid()) = admin_id
)
WITH CHECK (
  (select auth.uid()) = user_id OR 
  (select auth.uid()) = admin_id
);

-- ==========================================
-- 2. Invoice Services Table
-- ==========================================
ALTER TABLE invoice_services ENABLE ROW LEVEL SECURITY;

-- Drop ALL existing/conflicting policies to fix "Multiple Permissive Policies" warning
DROP POLICY IF EXISTS "invoice_services_access_policy" ON invoice_services;
DROP POLICY IF EXISTS "invoice_services_select" ON invoice_services;
DROP POLICY IF EXISTS "invoice_services_insert" ON invoice_services;
DROP POLICY IF EXISTS "Users can update invoice services" ON invoice_services;
DROP POLICY IF EXISTS "Users can delete invoice services" ON invoice_services;
DROP POLICY IF EXISTS "Enable service access for invoice owners" ON invoice_services;

-- Create Single Optimized Policy
CREATE POLICY "invoice_services_access_policy" ON invoice_services
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM invoices 
        WHERE id = invoice_services.invoice_id 
        AND (user_id = (select auth.uid()) OR admin_id = (select auth.uid()))
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM invoices 
        WHERE id = invoice_services.invoice_id 
        AND (user_id = (select auth.uid()) OR admin_id = (select auth.uid()))
    )
);
