-- Migration V29: Fix Database Lints (Performance & Redundancy)
-- 1. Wraps auth.uid() in (SELECT ...) to fix 'auth_rls_initplan' performance warnings.
-- 2. Splits 'FOR ALL' policies into explicit actions to fix 'multiple_permissive_policies' warnings.
-- 3. Drops duplicate indexes.

-- ============================================
-- 1. DROP DUPLICATE INDEXES
-- ============================================
-- The linter identified these as identical. We keep the most descriptive one or the FK one.

DROP INDEX IF EXISTS public.idx_investments_created_by; -- Duplicate of _fk
DROP INDEX IF EXISTS public.idx_invoices_created_by;    -- Duplicate of _fk
DROP INDEX IF EXISTS public.idx_settings_admin_id;      -- Duplicate of idx_settings_lookup

-- ============================================
-- 2. RESET POLICIES (Clean Slate)
-- ============================================
DO $$ 
DECLARE 
    r RECORD;
BEGIN 
    FOR r IN 
        SELECT schemaname, tablename, policyname 
        FROM pg_policies 
        WHERE tablename IN ('investments', 'settings', 'users', 'finance_entries', 'employees', 'clients', 'invoices')
    LOOP 
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I', r.policyname, r.schemaname, r.tablename); 
    END LOOP; 
END $$;

-- ============================================
-- 3. OPTIMIZED POLICIES
-- ============================================

-- A. USERS
-- -------------------
CREATE POLICY "users_select" ON public.users FOR SELECT 
TO authenticated USING (true);

-- Fix: Use (select auth.uid())
CREATE POLICY "users_update" ON public.users FOR UPDATE 
TO authenticated 
USING (id = (SELECT auth.uid())) 
WITH CHECK (id = (SELECT auth.uid()));


-- B. SETTINGS
-- -------------------
-- Read
CREATE POLICY "settings_select" ON public.settings FOR SELECT 
TO authenticated 
USING (
    admin_id IS NULL OR 
    admin_id = (SELECT public.get_active_org_id())
);

-- Write (Split ALL to specifically avoid SELECT overlap)
CREATE POLICY "settings_insert" ON public.settings FOR INSERT 
TO authenticated 
WITH CHECK ((SELECT auth.uid()) = admin_id);

CREATE POLICY "settings_update" ON public.settings FOR UPDATE 
TO authenticated 
USING ((SELECT auth.uid()) = admin_id);

CREATE POLICY "settings_delete" ON public.settings FOR DELETE 
TO authenticated 
USING ((SELECT auth.uid()) = admin_id);


-- C. INVESTMENTS
-- -------------------
-- Read
CREATE POLICY "investments_select" ON public.investments FOR SELECT 
TO authenticated 
USING (
    admin_id = (SELECT public.get_active_org_id()) OR 
    created_by = (SELECT auth.uid())
);

-- Insert
CREATE POLICY "investments_insert" ON public.investments FOR INSERT 
TO authenticated 
WITH CHECK (created_by = (SELECT auth.uid()));

-- Update (Admin OR Own Pending)
CREATE POLICY "investments_update" ON public.investments FOR UPDATE 
TO authenticated 
USING (
    admin_id = (SELECT auth.uid()) OR 
    (created_by = (SELECT auth.uid()) AND status = 'pending')
);

-- Delete (Admin OR Own Pending)
CREATE POLICY "investments_delete" ON public.investments FOR DELETE 
TO authenticated 
USING (
    admin_id = (SELECT auth.uid()) OR 
    (created_by = (SELECT auth.uid()) AND status = 'pending')
);


-- D. EMPLOYEES
-- -------------------
CREATE POLICY "employees_select" ON public.employees FOR SELECT 
TO authenticated USING (true);

CREATE POLICY "employees_insert" ON public.employees FOR INSERT 
TO authenticated WITH CHECK (admin_id = (SELECT auth.uid()));

CREATE POLICY "employees_update" ON public.employees FOR UPDATE 
TO authenticated USING (admin_id = (SELECT auth.uid()));

CREATE POLICY "employees_delete" ON public.employees FOR DELETE 
TO authenticated USING (admin_id = (SELECT auth.uid()));


-- E. CLIENTS
-- -------------------
CREATE POLICY "clients_select" ON public.clients FOR SELECT TO authenticated USING (true);
CREATE POLICY "clients_insert" ON public.clients FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "clients_update" ON public.clients FOR UPDATE TO authenticated USING (true);
CREATE POLICY "clients_delete" ON public.clients FOR DELETE TO authenticated USING (true);


-- F. INVOICES
-- -------------------
CREATE POLICY "invoices_select" ON public.invoices FOR SELECT TO authenticated USING (true);
CREATE POLICY "invoices_insert" ON public.invoices FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "invoices_update" ON public.invoices FOR UPDATE TO authenticated USING (true);
CREATE POLICY "invoices_delete" ON public.invoices FOR DELETE TO authenticated USING (true);


-- G. FINANCE ENTRIES
-- -------------------
CREATE POLICY "entries_select" ON public.finance_entries FOR SELECT TO authenticated USING (true);
CREATE POLICY "entries_insert" ON public.finance_entries FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "entries_update" ON public.finance_entries FOR UPDATE TO authenticated USING (true);
CREATE POLICY "entries_delete" ON public.finance_entries FOR DELETE TO authenticated USING (true);
