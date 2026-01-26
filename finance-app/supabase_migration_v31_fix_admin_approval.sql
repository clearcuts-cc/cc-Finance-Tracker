-- Migration V31: Fix Admin Approval Permissions
-- The previous security fix (V30) inadvertently restricted UPDATE access to ONLY the creator.
-- This prevented Admins from approving/editing entries and invoices created by employees.
-- This migration restores Admin UPDATE permissions.

-- ============================================
-- 1. FINANCE ENTRIES (Fix Update)
-- ============================================
DROP POLICY IF EXISTS "entries_update" ON public.finance_entries;

CREATE POLICY "entries_update" ON public.finance_entries FOR UPDATE 
TO authenticated 
USING (
    -- Creator can update (e.g. fix edits before approval)
    user_id = (SELECT auth.uid()) OR 
    -- Admin can update (Approvals, corrections)
    (EXISTS (SELECT 1 FROM public.users WHERE id = (SELECT auth.uid()) AND role = 'admin'))
);

-- ============================================
-- 2. INVOICES (Fix Update)
-- ============================================
DROP POLICY IF EXISTS "invoices_update" ON public.invoices;

CREATE POLICY "invoices_update" ON public.invoices FOR UPDATE 
TO authenticated 
USING (
    -- Creator can update (Drafts)
    user_id = (SELECT auth.uid()) OR 
    -- Admin can update (Status changes, corrections)
    (EXISTS (SELECT 1 FROM public.users WHERE id = (SELECT auth.uid()) AND role = 'admin'))
);

-- ============================================
-- 3. CLIENTS (Fix Update - Just in case)
-- ============================================
-- V30 already had admin check for clients_update, but re-verifying to be safe.
-- (V30: clients_update included admin check. It is fine.)
