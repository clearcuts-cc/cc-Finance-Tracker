-- Migration V32: Final Fix for Admin Approvals
-- Relaxes UPDATE policy to be Org-based rather than Role-based to avoid subquery issues.
-- Ensures that Admins can modify any row in their organization (matching admin_id).

-- ============================================
-- 1. FINANCE ENTRIES (Simplified & Robust)
-- ============================================
DROP POLICY IF EXISTS "entries_update" ON public.finance_entries;

CREATE POLICY "entries_update" ON public.finance_entries FOR UPDATE 
TO authenticated 
USING (
    -- User can update their own
    user_id = (SELECT auth.uid()) OR 
    -- Admin can update anything in their org (where they are the admin)
    admin_id = (SELECT auth.uid()) OR
    -- Fallback: Use helper function if admin_id is missing (should not happen, but safe)
    admin_id = (SELECT public.get_active_org_id())
);

-- ============================================
-- 2. INVOICES (Simplified & Robust)
-- ============================================
DROP POLICY IF EXISTS "invoices_update" ON public.invoices;

CREATE POLICY "invoices_update" ON public.invoices FOR UPDATE 
TO authenticated 
USING (
    user_id = (SELECT auth.uid()) OR 
    admin_id = (SELECT auth.uid()) OR
    admin_id = (SELECT public.get_active_org_id())
);

-- ============================================
-- 3. INVESTMENTS (Aligning for consistency)
-- ============================================
-- Just ensuring the update policy matches the pattern
DROP POLICY IF EXISTS "investments_update" ON public.investments;

CREATE POLICY "investments_update" ON public.investments FOR UPDATE 
TO authenticated 
USING (
    created_by = (SELECT auth.uid()) OR 
    admin_id = (SELECT auth.uid()) OR
    admin_id = (SELECT public.get_active_org_id())
);
