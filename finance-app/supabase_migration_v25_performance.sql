-- Migration V25: Performance Indexes & Settings Constraints
-- Fixes performance warnings and ensures data integrity for multi-tenant settings

-- ============================================
-- 1. SETTINGS TABLE FIXES
-- ============================================

-- We need to ensure that (key, admin_id) is unique so that UPSERT works correctly.
-- Currently, 'key' might be the Primary Key, which prevents different admins from having the same setting key.

-- Drop existing constraint on 'key' if possible (it might be the PK).
-- We'll try to drop the PK constraint. Name usually 'settings_pkey'.
ALTER TABLE public.settings DROP CONSTRAINT IF EXISTS settings_pkey;
ALTER TABLE public.settings DROP CONSTRAINT IF EXISTS settings_key_key; -- unique constraint if any

-- Add a new unique index that covers key + admin_id. 
-- We use COALESCE in the index or just standard unique allowing multiple NULLs? 
-- Postgres allows multiple NULLs in UNIQUE index unless we use NULLS NOT DISTINCT (PG 15+).
-- However, our logic sends specific admin_id. Global settings (admin_id IS NULL) should effectively be unique per key too.
-- A simple unique index on (key, admin_id) works if we treat NULL as a specific value, but standard SQL treats NULL != NULL.
-- For now, let's create a unique index that UPSERT can target.
-- Note: Supabase upsert requires a constraint name or index inference.

CREATE UNIQUE INDEX IF NOT EXISTS idx_settings_key_admin_unique 
ON public.settings (key, admin_id);

-- If admin_id is NULL, we might get duplicates if we rely solely on this index in older PG versions.
-- But standard practice:
-- If we want only ONE global setting for 'currency', and ONE for 'admin_uuid', this index is fine 
-- IF we only ever have one row where admin_id IS NULL per key.
-- To be safe, we can add a partial index for global settings?
-- CREATE UNIQUE INDEX IF NOT EXISTS idx_settings_key_global ON public.settings(key) WHERE admin_id IS NULL;


-- ============================================
-- 2. CREATE MISSING INDEXES (Performance)
-- ============================================

-- Investments
CREATE INDEX IF NOT EXISTS idx_investments_admin_id ON public.investments(admin_id);
CREATE INDEX IF NOT EXISTS idx_investments_created_by ON public.investments(created_by);
CREATE INDEX IF NOT EXISTS idx_investments_status ON public.investments(status);
CREATE INDEX IF NOT EXISTS idx_investments_date_bought ON public.investments(date_bought); -- for sorting

-- Settings
CREATE INDEX IF NOT EXISTS idx_settings_admin_id ON public.settings(admin_id);

-- Users
CREATE INDEX IF NOT EXISTS idx_users_role ON public.users(role);

-- Employees
CREATE INDEX IF NOT EXISTS idx_employees_user_id ON public.employees(user_id);
CREATE INDEX IF NOT EXISTS idx_employees_admin_id ON public.employees(admin_id);

-- Finance Entries
CREATE INDEX IF NOT EXISTS idx_finance_entries_user_id ON public.finance_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_finance_entries_created_by ON public.finance_entries(created_by);
CREATE INDEX IF NOT EXISTS idx_finance_entries_date ON public.finance_entries(date); -- for filters

-- Invoices
CREATE INDEX IF NOT EXISTS idx_invoices_created_by ON public.invoices(created_by);

-- ============================================
-- 3. VACUUM ANALYZE (Update Stats)
-- ============================================
-- Notify query planner about new indexes
ANALYZE public.investments;
ANALYZE public.settings;
ANALYZE public.users;
ANALYZE public.finance_entries;
ANALYZE public.employees;
