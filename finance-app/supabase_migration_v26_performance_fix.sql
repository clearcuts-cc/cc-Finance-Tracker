-- Migration V26: Fix RLS Performance Warnings (Stable Functions)
-- Replaces subqueries in RLS policies with STABLE functions to fix Supabase performance warnings.

-- ============================================
-- 1. Helper Function: get_active_org_id()
-- ============================================
-- Returns the Organization ID (Admin's User ID) for the current user.
-- If user is Admin: returns their own ID.
-- If user is Employee: returns their linked Admin ID.
-- Marked STABLE to cache the result per statement/transaction (Performance Fix).

CREATE OR REPLACE FUNCTION public.get_active_org_id()
RETURNS UUID AS $$
DECLARE
    v_role TEXT;
    v_admin_id UUID;
BEGIN
    -- Check if user is admin (optimize by checking metadata or users table)
    -- We'll check the users table which is authoritative
    SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
    
    IF v_role = 'admin' THEN
        RETURN auth.uid();
    ELSE
        -- Helper for employees
        SELECT admin_id INTO v_admin_id FROM public.employees WHERE user_id = auth.uid();
        RETURN v_admin_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================
-- 2. Update INVESTMENTS Policies
-- ============================================

DROP POLICY IF EXISTS "Admins can view org investments" ON public.investments;
DROP POLICY IF EXISTS "Employees can view own investments" ON public.investments;

-- Unified Read Policy (Performance Optimized)
-- Users can see investments that belong to their Active Org OR were created by them.
CREATE POLICY "Users can view org investments"
ON public.investments FOR SELECT
TO authenticated
USING (
    admin_id = public.get_active_org_id() OR
    created_by = auth.uid()
);

-- ============================================
-- 3. Update SETTINGS Policies
-- ============================================

DROP POLICY IF EXISTS "Authenticated users can read org settings" ON public.settings;

-- Optimized Read Policy
CREATE POLICY "Users can read org settings"
ON public.settings FOR SELECT
TO authenticated
USING (
    admin_id = public.get_active_org_id() OR
    admin_id IS NULL
);

-- ============================================
-- 4. Ensure Indexes (in case V25 was skipped)
-- ============================================
CREATE INDEX IF NOT EXISTS idx_employees_user_id ON public.employees(user_id);
CREATE INDEX IF NOT EXISTS idx_investments_admin_id ON public.investments(admin_id);
CREATE INDEX IF NOT EXISTS idx_settings_admin_id ON public.settings(admin_id);
