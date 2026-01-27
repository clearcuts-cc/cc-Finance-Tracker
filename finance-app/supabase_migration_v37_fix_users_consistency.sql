-- ============================================================
-- Migration V37: Fix User Profile Consistency & Avatar Updates
-- ============================================================

-- Issue: Profile updates (avatar) were appearing to succeed in UI but not persisting.
-- Root Cause: Users existed in Auth but were missing from the `public.users` table,
-- causing UPDATE queries to affect 0 rows (silent success).
-- Remediation: Backfill missing users and set up auto-sync trigger.

-- ------------------------------------------------------------
-- 1. Ensure Schema Completeness
-- ------------------------------------------------------------
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'admin';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS name TEXT;

-- ------------------------------------------------------------
-- 2. Backfill Missing Users
-- ------------------------------------------------------------
-- Pushes any users from auth.users that aren't in public.users
INSERT INTO public.users (id, email, name, role, created_at, updated_at)
SELECT 
    au.id, 
    au.email, 
    COALESCE(au.raw_user_meta_data->>'name', 'User'),
    COALESCE(au.raw_user_meta_data->>'role', 'admin'),
    au.created_at,
    NOW()
FROM auth.users au
LEFT JOIN public.users pu ON au.id = pu.id
WHERE pu.id IS NULL;

-- ------------------------------------------------------------
-- 3. Setup Auto-Sync Trigger (Future Proofing)
-- ------------------------------------------------------------
-- Automatically creates a public.users row when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name, role, created_at, updated_at)
  VALUES (
    NEW.id, 
    NEW.email, 
    COALESCE(NEW.raw_user_meta_data->>'name', 'User'),
    COALESCE(NEW.raw_user_meta_data->>'role', 'admin'),
    NEW.created_at,
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- Bind the trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ------------------------------------------------------------
-- 4. Optimize RLS Policies (Performance Fix)
-- ------------------------------------------------------------
-- Uses scalar subquery (select auth.uid()) to avoid re-evaluation warning
DROP POLICY IF EXISTS "users_update_own" ON public.users;
CREATE POLICY "users_update_own" ON public.users 
FOR UPDATE 
TO authenticated 
USING (id = (select auth.uid()))
WITH CHECK (id = (select auth.uid()));

-- Read policy (allow all authenticated to read, needed for finding admins/employees)
DROP POLICY IF EXISTS "users_read_all" ON public.users;
CREATE POLICY "users_read_all" ON public.users 
FOR SELECT 
TO authenticated 
USING (true);
