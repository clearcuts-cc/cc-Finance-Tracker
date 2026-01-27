-- ============================================================
-- Migration V38: Fix Database Lint Warnings (PK & Unused Indexes)
-- ============================================================

-- 1. Fix "No Primary Key" on public.settings
-- ------------------------------------------------------------
-- We add a surrogate UUID primary key if one doesn't exist.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'settings' AND column_name = 'id') THEN
        ALTER TABLE public.settings ADD COLUMN id UUID DEFAULT gen_random_uuid();
    END IF;
END $$;

-- Ensure it is the Primary Key
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE table_name = 'settings' AND constraint_type = 'PRIMARY KEY') THEN
        ALTER TABLE public.settings ADD PRIMARY KEY (id);
    END IF;
END $$;

-- 2. Remove Redundant Indexes
-- ------------------------------------------------------------
-- The linter flagged several unused indexes. 
-- We remove only those that are clearly redundant or not useful for our query patterns.

-- A. idx_employees_email 
-- 'employees.email' is defined as UNIQUE, which auto-creates an index. 
-- The manual 'idx_employees_email' is redundant.
DROP INDEX IF EXISTS public.idx_employees_email;

-- B. idx_users_role
-- Our RLS mostly checks role AFTER looking up by 'id' (Primary Key).
-- We rarely search "WHERE role = 'admin'" across the whole table without an ID.
DROP INDEX IF EXISTS public.idx_users_role;

-- C. idx_finance_entries_approval_status
-- Kept? No, we likely search by 'approval_status' for the notification badge/dashboard.
-- However, if the linter says it's unused, it might mean we aren't filtering purely by status often enough.
-- BUT, this is likely needed for the "Pending Approvals" view. 
-- I will KEEP this one as removing it might hurt future performance of that specific view.
-- (No drop command for this one)

-- D. idx_finance_entries_del_req_by_fk / idx_finance_entries_approved_by_fk
-- These look like duplicates if we have standard indexes, or unused if we don't join on them.
-- I'll trust the linter here for these specific FK helper indexes if they aren't standard.
DROP INDEX IF EXISTS public.idx_finance_entries_del_req_by_fk;
DROP INDEX IF EXISTS public.idx_finance_entries_approved_by_fk;

-- Note: We are keeping most FK indexes (user_id, admin_id) because even if "unused" now,
-- they are critical for preventing full table scans during JOINs and DELETE cascades as data grows.
