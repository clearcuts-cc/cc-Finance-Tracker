-- ============================================================
-- Migration v13: Security and Performance Fixes
-- ============================================================

-- 1. SECURITY: Fix Function Search Path Mutable
-- Set a secure search_path for the trigger function
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = '';

-- 2. PERFORMANCE: Add Indexes for Foreign Keys
-- Adding indices to foreign keys improves join performance and prevents locking issues

-- Clients
CREATE INDEX IF NOT EXISTS idx_clients_admin_id_fk ON clients(admin_id);

-- Employees
CREATE INDEX IF NOT EXISTS idx_employees_user_id_fk ON employees(user_id);

-- Finance Entries
CREATE INDEX IF NOT EXISTS idx_finance_entries_approved_by_fk ON finance_entries(approved_by);
CREATE INDEX IF NOT EXISTS idx_finance_entries_del_req_by_fk ON finance_entries(deletion_requested_by);

-- Investments
CREATE INDEX IF NOT EXISTS idx_investments_created_by_fk ON investments(created_by);

-- Invoices
CREATE INDEX IF NOT EXISTS idx_invoices_admin_id_fk ON invoices(admin_id);
CREATE INDEX IF NOT EXISTS idx_invoices_created_by_fk ON invoices(created_by);

-- Notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_id_fk ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_admin_id_fk ON notifications(admin_id);

-- 3. PERFORMANCE: Optimize RLS Policy for Users
-- Wrap auth.uid() in (select auth.uid()) for better query planning
-- (Dropping and recreating the policy from v12)

DROP POLICY IF EXISTS "users_update_own" ON users;

CREATE POLICY "users_update_own" ON users FOR UPDATE TO authenticated 
    USING (id = (SELECT auth.uid()))
    WITH CHECK (id = (SELECT auth.uid()));
