-- ============================================================
-- Migration v18: Fix Invoice Permissions and Visibility
-- ============================================================

-- ------------------------------------------------------------
-- 1. Fix Invoice Saving (Bug 6)
-- ------------------------------------------------------------
-- Ensure Employees and Admins can INSERT into 'invoices' and 'invoice_services'
-- Previous policies might have been too restrictive or missing.

DROP POLICY IF EXISTS "invoices_insert" ON invoices;
CREATE POLICY "invoices_insert" ON invoices FOR INSERT TO authenticated 
    WITH CHECK (
        -- User can insert their own invoice
        user_id = (SELECT auth.uid()) OR
        -- Admin can insert for their org (though usually it is their own user_id anyway)
        admin_id = (SELECT auth.uid())
    );

DROP POLICY IF EXISTS "invoice_services_insert" ON invoice_services;
CREATE POLICY "invoice_services_insert" ON invoice_services FOR INSERT TO authenticated 
    WITH CHECK (
        -- Can insert services if they have access to the parent invoice
        EXISTS (
            SELECT 1 FROM invoices 
            WHERE id = invoice_services.invoice_id 
            AND (
                user_id = (SELECT auth.uid()) OR 
                admin_id = (SELECT auth.uid())
            )
        )
    );

-- ------------------------------------------------------------
-- 2. Fix Invoice Visibility (Bug 8)
-- ------------------------------------------------------------
-- Admins see ALL in their org. Employees see ONLY their own.

DROP POLICY IF EXISTS "invoices_select" ON invoices;
CREATE POLICY "invoices_select" ON invoices FOR SELECT TO authenticated 
    USING (
        -- Option A: It's my own invoice
        user_id = (SELECT auth.uid()) 
        OR
        -- Option B: I am the Admin of this invoice (it belongs to my org)
        admin_id = (SELECT auth.uid())
    );

-- Update invoice_services visibility to match parent invoice
DROP POLICY IF EXISTS "invoice_services_select" ON invoice_services;
CREATE POLICY "invoice_services_select" ON invoice_services FOR SELECT TO authenticated 
    USING (
        EXISTS (
            SELECT 1 FROM invoices 
            WHERE id = invoice_services.invoice_id 
            AND (
                user_id = (SELECT auth.uid()) -- It's my invoice
                OR 
                admin_id = (SELECT auth.uid()) -- I'm the admin
            )
        )
    );

-- ------------------------------------------------------------
-- 3. Fix Profile Updates (Bug 1 - Backend Support)
-- ------------------------------------------------------------
-- Ensure users can update their own profile (name, phone, avatar)
-- Re-asserting this policy just in case it was weak
DROP POLICY IF EXISTS "users_update_own" ON users;
CREATE POLICY "users_update_own" ON users FOR UPDATE TO authenticated 
    USING (id = (SELECT auth.uid()));
