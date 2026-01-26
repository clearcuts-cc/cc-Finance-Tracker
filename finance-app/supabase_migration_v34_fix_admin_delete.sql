-- ============================================================
-- Migration V34: Fix Admin Delete Permissions
-- ============================================================

-- Issue: Admins were unable to delete entries created by employees because
-- the RLS policy only allowed deletion if 'user_id' matched the deleter.
-- We need to expand the DELETE policy to allow deletion if 'admin_id' matches too.

-- 1. Drop the existing strict/incorrect DELETE policy for finance_entries
DROP POLICY IF EXISTS "entries_delete" ON public.finance_entries;
DROP POLICY IF EXISTS "finance_entries_delete_policy" ON public.finance_entries;

-- 2. Create a Correct, Comprehensive DELETE Policy
-- Allows deletion if:
-- a) You are the creator (standard user deleting their own, if allowed)
-- b) You are the Admin of the entry (matching admin_id)
-- c) You are an Admin user in the system (fallback role check)

CREATE POLICY "entries_delete_comprehensive" 
ON public.finance_entries 
FOR DELETE 
TO authenticated 
USING (
    -- 1. Creator can delete (though UI might block this for employees, DB allows it if logic persists)
    user_id = auth.uid() 
    OR 
    -- 2. The Admin of this entry can delete it (Critical for Employee Deletion Requests)
    admin_id = auth.uid()
    OR
    -- 3. Any Admin role user can delete (Safety net)
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE users.id = auth.uid() 
        AND users.role = 'admin'
    )
);

-- 3. Ensure UPDATE policy allows Admins to approve/decline things they don't own
-- (Just in case "entries_update" was also too strict)
DROP POLICY IF EXISTS "entries_update" ON public.finance_entries;
DROP POLICY IF EXISTS "finance_entries_update_policy" ON public.finance_entries;

CREATE POLICY "entries_update_comprehensive" 
ON public.finance_entries 
FOR UPDATE 
TO authenticated 
USING (
    -- User can update their own
    user_id = auth.uid() 
    OR 
    -- Admin of the entry can update (to approve/decline)
    admin_id = auth.uid()
    OR
    -- Admin role check
    EXISTS (
        SELECT 1 FROM public.users 
        WHERE users.id = auth.uid() 
        AND users.role = 'admin'
    )
);
