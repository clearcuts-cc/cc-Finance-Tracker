-- Migration V27: Fix Function Security Warnings & Polish
-- Addresses the "missing search_path" warning for SECURITY DEFINER functions.
-- Ensures policies use the secure function correctly.

-- ============================================
-- 1. SECURE FUNCTION DEFINITION
-- ============================================

-- Drop first to ensure a clean replace if signature changed (though it hasn't)
DROP FUNCTION IF EXISTS public.get_active_org_id();

-- Re-create with 'SET search_path' to prevent hijacking (Security Best Practice)
CREATE OR REPLACE FUNCTION public.get_active_org_id()
RETURNS UUID AS $$
DECLARE
    v_role TEXT;
    v_admin_id UUID;
BEGIN
    -- Securely fetch role
    SELECT role INTO v_role FROM public.users WHERE id = auth.uid();
    
    IF v_role = 'admin' THEN
        RETURN auth.uid();
    ELSE
        -- Fetch admin_id for employee
        SELECT admin_id INTO v_admin_id FROM public.employees WHERE user_id = auth.uid();
        RETURN v_admin_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE
SET search_path = public, pg_temp; -- <--- FIX: This resolves the security warning

-- ============================================
-- 2. RE-APPLY POLICIES (To use the new function oid)
-- ============================================

-- Settings
DROP POLICY IF EXISTS "Users can read org settings" ON public.settings;
CREATE POLICY "Users can read org settings"
ON public.settings FOR SELECT
TO authenticated
USING (
    admin_id = public.get_active_org_id() OR
    admin_id IS NULL
);

-- Investments
DROP POLICY IF EXISTS "Users can view org investments" ON public.investments;
CREATE POLICY "Users can view org investments"
ON public.investments FOR SELECT
TO authenticated
USING (
    -- Admin sees their org's data
    admin_id = public.get_active_org_id() OR
    -- Fallback: User sees what they created (useful if admin_id was missed in legacy)
    created_by = auth.uid() OR
    -- Fallback: Employee sees what belongs to their admin explicitly if function returns null?
    -- (The function handles this, but being robust)
    admin_id = (SELECT admin_id FROM public.employees WHERE user_id = auth.uid())
);
