-- ============================================================
-- Migration V39: Comprehensive Cleanup of Unused Indexes
-- ============================================================

-- Issue: Supabase Performance Advisor reports multiple "Unused Index" warnings.
-- Cause: Postgres Query Planner determines these indexes are not being used for current query patterns
--        or the dataset is small enough that Sequential Scans are faster.
-- Resolution: Remove them to clear warnings and reduce write overhead.

-- 1. Finance Entries Indexes
DROP INDEX IF EXISTS public.idx_finance_entries_approval_status;
DROP INDEX IF EXISTS public.idx_finance_entries_admin_id;
DROP INDEX IF EXISTS public.idx_finance_entries_user_id;
DROP INDEX IF EXISTS public.idx_finance_entries_date;
DROP INDEX IF EXISTS public.idx_finance_entries_created_by; -- if exists
DROP INDEX IF EXISTS public.idx_finance_entries_del_req_by_fk;
DROP INDEX IF EXISTS public.idx_finance_entries_approved_by_fk;

-- 2. Employees/Users Indexes
DROP INDEX IF EXISTS public.idx_employees_user_id;
DROP INDEX IF EXISTS public.idx_employees_email;
DROP INDEX IF EXISTS public.idx_users_role;

-- 3. Investments Indexes
DROP INDEX IF EXISTS public.idx_investments_status;
DROP INDEX IF EXISTS public.idx_investments_admin_id;
DROP INDEX IF EXISTS public.idx_investments_date_bought;
DROP INDEX IF EXISTS public.idx_investments_lookup;

-- 4. Invoices & Services Indexes
DROP INDEX IF EXISTS public.idx_invoices_user_id;
DROP INDEX IF EXISTS public.idx_invoice_services_invoice_id;

-- 5. Clients & Settings Indexes
DROP INDEX IF EXISTS public.idx_clients_approval_status;
DROP INDEX IF EXISTS public.idx_settings_lookup;

-- 6. Ensure Primary Key on Settings (Idempotent Check from V38)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'id') THEN
        ALTER TABLE public.settings ADD COLUMN id UUID DEFAULT gen_random_uuid();
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_name = 'settings' AND constraint_type = 'PRIMARY KEY') THEN
        ALTER TABLE public.settings ADD PRIMARY KEY (id);
    END IF;
END $$;

-- 7. Fix Duplicate RLS Policies on public.users
-- ------------------------------------------------------------
-- Two SELECT policies exist: "users_read_all" and "users_select". Drop redundant one.
DROP POLICY IF EXISTS "users_select" ON public.users;
DROP POLICY IF EXISTS "users_update" ON public.users;

-- 8. Add Covering Index for Foreign Key
-- ------------------------------------------------------------
-- The FK employees_user_id_fkey needs an index for optimal DELETE/UPDATE cascade performance.
CREATE INDEX IF NOT EXISTS idx_employees_user_id_fk ON public.employees(user_id);
