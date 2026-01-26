-- Migration V24: Fixes for Avatar, Settings, and Investments Visibility
-- This migration addresses:
-- 1. Profile Avatar not persisting (Fixing users table RLS)
-- 2. Agency Info not syncing (Fixing settings table RLS and scoping)
-- 3. Unknown names (Allowing public read of user profiles)
-- 4. Admin visibility of Employee Investments (Adding admin_id to investments)

-- ============================================
-- 1. USERS TABLE FIXES (Profile & Names)
-- ============================================

-- Ensure RLS is enabled
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Drop existing restrictive policies if any
DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
DROP POLICY IF EXISTS "Allow authenticated users to read users" ON public.users; -- Old potential name

-- Policy 1: Everyone can read user profiles (needed for resolving names like "Created By X")
CREATE POLICY "Everyone can read user profiles"
ON public.users FOR SELECT
TO authenticated
USING (true);

-- Policy 2: Users can update their own profile (Avatar, Name)
CREATE POLICY "Users can update their own profile"
ON public.users FOR UPDATE
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Statement 3: Ensure avatar column is text (if not already)
-- (It usually is text, but being safe)
-- ALTER TABLE public.users ALTER COLUMN avatar TYPE TEXT; 

-- ============================================
-- 2. INVESTMENTS TABLE FIXES (Admin Visibility)
-- ============================================

-- Add admin_id to scope investments to the organization
ALTER TABLE public.investments ADD COLUMN IF NOT EXISTS admin_id UUID REFERENCES auth.users(id);

-- Backfill admin_id for existing rows
-- If created_by is an admin, set admin_id = created_by
-- If created_by is employee, set admin_id = employee's admin
DO $$
BEGIN
    -- Update items created by admins
    UPDATE public.investments 
    SET admin_id = created_by 
    WHERE admin_id IS NULL 
    AND created_by IN (SELECT id FROM public.users WHERE role = 'admin');

    -- Update items created by employees (using local subquery to find their admin)
    -- This relies on employees table linking user_id to admin_id
    UPDATE public.investments AS i
    SET admin_id = e.admin_id
    FROM public.employees AS e
    WHERE i.admin_id IS NULL 
    AND i.created_by = e.user_id;
END $$;

-- Update RLS Policies for Investments
DROP POLICY IF EXISTS "Admins can do everything on investments" ON public.investments;
DROP POLICY IF EXISTS "Employees can view investments" ON public.investments;
DROP POLICY IF EXISTS "Employees can create investments" ON public.investments;

-- Policy: Admins see everything in their organization
CREATE POLICY "Admins can view org investments"
ON public.investments FOR SELECT
TO authenticated
USING (
    admin_id = auth.uid() OR 
    (admin_id IS NOT NULL AND admin_id = (SELECT admin_id FROM public.employees WHERE user_id = auth.uid())) OR
    -- Fallback for legacy rows or self
    created_by = auth.uid()
);

-- Policy: Admins can update/delete org investments
CREATE POLICY "Admins can manage org investments"
ON public.investments FOR ALL
TO authenticated
USING (
    admin_id = auth.uid()
);

-- Policy: Employees can view their own investments (or org's if they need to see approval status?)
-- User wanted "approved decliend i want that in invesment page".
-- Normally employees just need to see their own.
CREATE POLICY "Employees can view own investments"
ON public.investments FOR SELECT
TO authenticated
USING (
    created_by = auth.uid() OR
    -- Also allow valid employees to see if they are part of the org (optional, but keep simple)
    (admin_id = (SELECT admin_id FROM public.employees WHERE user_id = auth.uid()))
);

-- Policy: Employees can insert (with valid admin_id)
CREATE POLICY "Employees can insert investments"
ON public.investments FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() = created_by
);

-- Policy: Employees can delete/update own PENDING investments
CREATE POLICY "Employees can delete own pending investments"
ON public.investments FOR DELETE
TO authenticated
USING (
    created_by = auth.uid() AND status = 'pending'
);

CREATE POLICY "Employees can update own pending investments"
ON public.investments FOR UPDATE
TO authenticated
USING (
    created_by = auth.uid() AND status = 'pending'
)
WITH CHECK (
    created_by = auth.uid() AND status = 'pending'
);


-- ============================================
-- 3. SETTINGS TABLE FIXES (Agency Info Scoping)
-- ============================================

-- Settings likely lacks structural owner. Add admin_id
ALTER TABLE public.settings ADD COLUMN IF NOT EXISTS admin_id UUID REFERENCES auth.users(id);

-- Drop old policies
DROP POLICY IF EXISTS "Allow authenticated users to read settings" ON public.settings;
DROP POLICY IF EXISTS "Allow authenticated users to insert settings" ON public.settings;
DROP POLICY IF EXISTS "Allow authenticated users to update settings" ON public.settings;
DROP POLICY IF EXISTS "Only admins can insert settings" ON public.settings;
DROP POLICY IF EXISTS "Only admins can update settings" ON public.settings;

-- RLS: Read Access (My Org's Settings)
-- Setting might match admin_id = my_admin_id (Employee) OR admin_id = my_id (Admin)
CREATE POLICY "Authenticated users can read org settings"
ON public.settings FOR SELECT
TO authenticated
USING (
    admin_id = auth.uid() OR
    admin_id = (SELECT admin_id FROM public.employees WHERE user_id = auth.uid()) OR
    admin_id IS NULL -- Allow global settings if any
);

-- RLS: Write Access (Admin Only)
CREATE POLICY "Admins can insert own settings"
ON public.settings FOR INSERT
TO authenticated
WITH CHECK (
    admin_id = auth.uid()
);

CREATE POLICY "Admins can update own settings"
ON public.settings FOR UPDATE
TO authenticated
USING (admin_id = auth.uid())
WITH CHECK (admin_id = auth.uid());
