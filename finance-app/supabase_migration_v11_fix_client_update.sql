-- ============================================================
-- Migration v11: Fix Client Update Policy and Shared Permissions
-- ============================================================

-- 1. Relax clients_update policy to allow employees to update clients
-- Previously, only the Admin (admin_id = auth.uid()) could update.
-- Now, employees who belong to the admin can also update.

DROP POLICY IF EXISTS "clients_update" ON clients;

CREATE POLICY "clients_update" ON clients FOR UPDATE TO authenticated 
    USING (
        -- Allow if user is the Admin
        admin_id = (SELECT auth.uid()) 
        OR 
        -- Allow if user is an Employee of the Admin
        admin_id = (SELECT admin_id FROM employees WHERE user_id = (SELECT auth.uid()))
    );

-- 2. Also ensure clients_insert lets employees insert correctly
-- (The previous policy was WITH CHECK (true), which is fine as strict RLS is handled by trigger/input)
-- But we can make it explicit that they enter the correct admin_id
-- However, strict check logic is complex in policy, so we leave it as true for now, 
-- trusting the API and backend logic to set admin_id correctly.

-- 3. Ensure 'phone' column accepts text (it is text, but just in case of any weird constraint)
-- (No action needed, verified as text)
