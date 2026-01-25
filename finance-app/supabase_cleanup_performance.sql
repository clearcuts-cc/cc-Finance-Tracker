-- ============================================================
-- PERFORMANCE & SECURITY OPTIMIZATION (FINAL CLEANUP)
-- FIXED: Syntax error, Consolidated policies, and Secure Checks
-- ============================================================

-- 1. CLEANUP: Drop ALL old and conflicting policies first
DO $$ 
DECLARE 
    policy_record RECORD;
BEGIN
    FOR policy_record IN 
        SELECT policyname, tablename 
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename IN ('clients', 'investments', 'notifications', 'employees', 'finance_entries', 'invoices')
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON %I', policy_record.policyname, policy_record.tablename);
    END LOOP;
END $$;

-- 2. OPTIMIZED POLICIES FOR 'clients'
CREATE POLICY "clients_select" ON clients FOR SELECT TO authenticated 
    USING (true);
    
CREATE POLICY "clients_insert" ON clients FOR INSERT TO authenticated 
    WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "clients_update" ON clients FOR UPDATE TO authenticated 
    USING (EXISTS (SELECT 1 FROM users WHERE id = (SELECT auth.uid()) AND role = 'admin'));

CREATE POLICY "clients_delete" ON clients FOR DELETE TO authenticated 
    USING (EXISTS (SELECT 1 FROM users WHERE id = (SELECT auth.uid()) AND role = 'admin'));


-- 3. OPTIMIZED POLICIES FOR 'investments'
CREATE POLICY "investments_select" ON investments FOR SELECT TO authenticated 
    USING (true);

CREATE POLICY "investments_insert" ON investments FOR INSERT TO authenticated 
    WITH CHECK (created_by = (SELECT auth.uid()));

CREATE POLICY "investments_update" ON investments FOR UPDATE TO authenticated 
    USING (EXISTS (SELECT 1 FROM users WHERE id = (SELECT auth.uid()) AND role = 'admin'));

CREATE POLICY "investments_delete" ON investments FOR DELETE TO authenticated 
    USING (EXISTS (SELECT 1 FROM users WHERE id = (SELECT auth.uid()) AND role = 'admin'));


-- 4. OPTIMIZED POLICIES FOR 'notifications'
CREATE POLICY "notifications_select" ON notifications FOR SELECT TO authenticated 
    USING (admin_id = (SELECT auth.uid()));

CREATE POLICY "notifications_delete" ON notifications FOR DELETE TO authenticated 
    USING (admin_id = (SELECT auth.uid()));

CREATE POLICY "notifications_insert" ON notifications FOR INSERT TO authenticated 
    WITH CHECK (
        -- User can only insert if they are the sender
        (user_id = (SELECT auth.uid())) OR
        -- Or if they are authenticated (for anonymous but session-bound reset requests handled by server logic)
        ((SELECT auth.role()) = 'authenticated')
    );


-- 5. OPTIMIZED POLICIES FOR 'employees'
CREATE POLICY "employees_select" ON employees FOR SELECT TO authenticated 
    USING (true);


-- 6. OPTIMIZED POLICIES FOR 'finance_entries'
CREATE POLICY "entries_select" ON finance_entries FOR SELECT TO authenticated 
    USING (true);

CREATE POLICY "entries_insert" ON finance_entries FOR INSERT TO authenticated 
    WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "entries_update" ON finance_entries FOR UPDATE TO authenticated 
    USING (
        (user_id = (SELECT auth.uid())) OR 
        EXISTS (SELECT 1 FROM users WHERE id = (SELECT auth.uid()) AND role = 'admin')
    )
    WITH CHECK (
        (user_id = (SELECT auth.uid())) OR 
        EXISTS (SELECT 1 FROM users WHERE id = (SELECT auth.uid()) AND role = 'admin')
    );

CREATE POLICY "entries_delete" ON finance_entries FOR DELETE TO authenticated 
    USING (EXISTS (SELECT 1 FROM users WHERE id = (SELECT auth.uid()) AND role = 'admin'));


-- 7. OPTIMIZED POLICIES FOR 'invoices'
CREATE POLICY "invoices_select" ON invoices FOR SELECT TO authenticated 
    USING (true);

CREATE POLICY "invoices_insert" ON invoices FOR INSERT TO authenticated 
    WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "invoices_update" ON invoices FOR UPDATE TO authenticated 
    USING (EXISTS (SELECT 1 FROM users WHERE id = (SELECT auth.uid()) AND role = 'admin'));

CREATE POLICY "invoices_delete" ON invoices FOR DELETE TO authenticated 
    USING (EXISTS (SELECT 1 FROM users WHERE id = (SELECT auth.uid()) AND role = 'admin'));
