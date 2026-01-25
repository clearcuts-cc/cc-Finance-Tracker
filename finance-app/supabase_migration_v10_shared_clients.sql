-- ============================================================
-- Migration v10: Shared Visibility for Clients & Invoices
-- ============================================================

-- 1. Add admin_id to clients and invoices
ALTER TABLE clients ADD COLUMN IF NOT EXISTS admin_id UUID REFERENCES auth.users(id);
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS admin_id UUID REFERENCES auth.users(id);

-- 2. Backfill admin_id from user_id (for existing users)
UPDATE clients SET admin_id = user_id WHERE admin_id IS NULL;
UPDATE invoices SET admin_id = user_id WHERE admin_id IS NULL;

-- 3. Reset and Fix Policies for Clients
DROP POLICY IF EXISTS "clients_select" ON clients;
CREATE POLICY "clients_select" ON clients FOR SELECT TO authenticated 
    USING (admin_id = (SELECT COALESCE(
        (SELECT admin_id FROM employees WHERE user_id = (SELECT auth.uid())),
        (SELECT auth.uid())
    )));

DROP POLICY IF EXISTS "clients_insert" ON clients;
CREATE POLICY "clients_insert" ON clients FOR INSERT TO authenticated 
    WITH CHECK (true);

DROP POLICY IF EXISTS "clients_update" ON clients;
CREATE POLICY "clients_update" ON clients FOR UPDATE TO authenticated 
    USING (admin_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "clients_delete" ON clients;
CREATE POLICY "clients_delete" ON clients FOR DELETE TO authenticated 
    USING (EXISTS (SELECT 1 FROM users WHERE id = (SELECT auth.uid()) AND role = 'admin'));

-- 4. Reset and Fix Policies for Invoices
DROP POLICY IF EXISTS "invoices_select" ON invoices;
CREATE POLICY "invoices_select" ON invoices FOR SELECT TO authenticated 
    USING (admin_id = (SELECT COALESCE(
        (SELECT admin_id FROM employees WHERE user_id = (SELECT auth.uid())),
        (SELECT auth.uid())
    )));

DROP POLICY IF EXISTS "invoices_insert" ON invoices;
CREATE POLICY "invoices_insert" ON invoices FOR INSERT TO authenticated 
    WITH CHECK (true);

DROP POLICY IF EXISTS "invoices_update" ON invoices;
CREATE POLICY "invoices_update" ON invoices FOR UPDATE TO authenticated 
    USING (admin_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "invoices_delete" ON invoices;
CREATE POLICY "invoices_delete" ON invoices FOR DELETE TO authenticated 
    USING (EXISTS (SELECT 1 FROM users WHERE id = (SELECT auth.uid()) AND role = 'admin'));
