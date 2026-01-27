-- ============================================================
-- Migration V36: Fix RLS Performance (Database Linter Warnings)
-- ============================================================

-- Issue: The previous RLS policies for finance_entries and clients used `auth.uid()` directly.
-- This can cause Postgres to re-evaluate the function for every row, leading to poor performance.
-- Remediation: Wrap `auth.uid()` in `(select auth.uid())` to force single evaluation.

-- ------------------------------------------------------------
-- 1. Fix Policies for public.finance_entries
-- ------------------------------------------------------------

-- Drop existing policies
DROP POLICY IF EXISTS "entries_delete_comprehensive" ON public.finance_entries;
DROP POLICY IF EXISTS "entries_update_comprehensive" ON public.finance_entries;

-- Re-create DELETE policy
CREATE POLICY "entries_delete_comprehensive" 
ON public.finance_entries 
FOR DELETE 
TO authenticated 
USING (
    user_id = (select auth.uid()) 
    OR 
    admin_id = (select auth.uid())
    OR
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE users.id = (select auth.uid()) 
        AND users.role = 'admin'
    )
);

-- Re-create UPDATE policy
CREATE POLICY "entries_update_comprehensive" 
ON public.finance_entries 
FOR UPDATE 
TO authenticated 
USING (
    user_id = (select auth.uid()) 
    OR 
    admin_id = (select auth.uid())
    OR
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE users.id = (select auth.uid()) 
        AND users.role = 'admin'
    )
);

-- ------------------------------------------------------------
-- 2. Fix Policies for public.clients
-- ------------------------------------------------------------

-- Drop existing policies
DROP POLICY IF EXISTS "clients_delete_comprehensive" ON public.clients;
DROP POLICY IF EXISTS "clients_update_comprehensive" ON public.clients;

-- Re-create DELETE policy
CREATE POLICY "clients_delete_comprehensive" 
ON public.clients 
FOR DELETE 
TO authenticated 
USING (
    user_id = (select auth.uid()) 
    OR 
    admin_id = (select auth.uid())
    OR
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE users.id = (select auth.uid()) 
        AND users.role = 'admin'
    )
);

-- Re-create UPDATE policy
CREATE POLICY "clients_update_comprehensive" 
ON public.clients 
FOR UPDATE 
TO authenticated 
USING (
    user_id = (select auth.uid()) 
    OR 
    admin_id = (select auth.uid())
    OR
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE users.id = (select auth.uid()) 
        AND users.role = 'admin'
    )
);
