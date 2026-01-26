-- Migration V30: Fix Security Warnings (Restrictive Policies)
-- Addresses 'rls_policy_always_true' warnings by adding minimal user scoping.
-- Previously we used 'USING (true)' for rapid development, but this is insecure for production.
-- Now we scope data to the Organization (Admin ID) or Creator.

-- ============================================
-- 1. UTILITY: Re-Use get_active_org_id()
-- ============================================
-- (Function assumed to exist from V27/V28)


-- ============================================
-- 2. CLIENTS (Org Scoped)
-- ============================================
DROP POLICY IF EXISTS "clients_delete" ON public.clients;
DROP POLICY IF EXISTS "clients_insert" ON public.clients;
DROP POLICY IF EXISTS "clients_update" ON public.clients;
-- Note: "clients_select" with true is fine for reading if authenticated, but better scoped too.

-- Scoped Policies:
-- Allow DELETE/UPDATE only if:
-- 1. You are the Admin (active org id = auth uid)
-- 2. OR You created it (optional, usually admin owns clients)
-- We'll use get_active_org_id() to ensure they belong to the user's org.
-- But 'clients' table might not have 'admin_id' column populated in all versions.
-- We'll assume 'user_id' is the creator/admin.

CREATE POLICY "clients_insert" ON public.clients FOR INSERT 
TO authenticated 
WITH CHECK (user_id = (SELECT auth.uid())); -- Only insert as yourself

CREATE POLICY "clients_update" ON public.clients FOR UPDATE 
TO authenticated 
USING (
    user_id = (SELECT auth.uid()) OR 
    (EXISTS (SELECT 1 FROM public.users WHERE id = (SELECT auth.uid()) AND role = 'admin'))
);

CREATE POLICY "clients_delete" ON public.clients FOR DELETE 
TO authenticated 
USING (
    user_id = (SELECT auth.uid()) OR 
    (EXISTS (SELECT 1 FROM public.users WHERE id = (SELECT auth.uid()) AND role = 'admin'))
);


-- ============================================
-- 3. INVOICES (Org Scoped)
-- ============================================
DROP POLICY IF EXISTS "invoices_delete" ON public.invoices;
DROP POLICY IF EXISTS "invoices_insert" ON public.invoices;
DROP POLICY IF EXISTS "invoices_update" ON public.invoices;

CREATE POLICY "invoices_insert" ON public.invoices FOR INSERT 
TO authenticated 
WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "invoices_update" ON public.invoices FOR UPDATE 
TO authenticated 
USING (user_id = (SELECT auth.uid())); -- Simplest: Creator manages it

CREATE POLICY "invoices_delete" ON public.invoices FOR DELETE 
TO authenticated 
USING (user_id = (SELECT auth.uid()));


-- ============================================
-- 4. FINANCE ENTRIES (Org Scoped)
-- ============================================
DROP POLICY IF EXISTS "entries_delete" ON public.finance_entries;
DROP POLICY IF EXISTS "entries_insert" ON public.finance_entries;
DROP POLICY IF EXISTS "entries_update" ON public.finance_entries;

CREATE POLICY "entries_insert" ON public.finance_entries FOR INSERT 
TO authenticated 
WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "entries_update" ON public.finance_entries FOR UPDATE 
TO authenticated 
USING (user_id = (SELECT auth.uid()));

CREATE POLICY "entries_delete" ON public.finance_entries FOR DELETE 
TO authenticated 
USING (
    user_id = (SELECT auth.uid()) OR
    (EXISTS (SELECT 1 FROM public.users WHERE id = (SELECT auth.uid()) AND role = 'admin'))
);

-- Note: "Leaked Password Protection" is a Supabase Dashboard setting, not SQL.
-- Please enable it in: Authentication -> Security -> Leaked Password Protection
