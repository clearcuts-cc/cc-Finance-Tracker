-- Migration V55: Force Role Identification in Users Table
-- This migration ensures that every user in the 'users' table is correctly 
-- identified as 'admin' or 'employee' based on the 'employees' table.

-- 1. Ensure the role column is set correctly for all existing users
-- First, default everyone to 'admin'
UPDATE public.users SET role = 'admin';

-- Then, set role to 'employee' for those present in the employees table
UPDATE public.users u
SET role = 'employee'
FROM public.employees e
WHERE u.id = e.user_id;

-- 2. Create a function to automatically sync roles
CREATE OR REPLACE FUNCTION public.sync_user_role_from_employees()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.user_id IS NOT NULL THEN
        -- If a user is added/updated in employees table, set their role to 'employee'
        UPDATE public.users SET role = 'employee' WHERE id = NEW.user_id;
    ELSIF (TG_OP = 'DELETE') AND OLD.user_id IS NOT NULL THEN
        -- If an employee record is removed, they revert to 'admin' (or basic user)
        UPDATE public.users SET role = 'admin' WHERE id = OLD.user_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Bind trigger to employees table
DROP TRIGGER IF EXISTS tr_sync_employee_role ON public.employees;
CREATE TRIGGER tr_sync_employee_role
AFTER INSERT OR UPDATE OR DELETE ON public.employees
FOR EACH ROW EXECUTE FUNCTION public.sync_user_role_from_employees();

-- 4. Improve the handle_new_user trigger to check employees table immediately
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
DECLARE
    v_role TEXT := 'admin';
BEGIN
    -- Check if this new user's email is already in the employees table
    IF EXISTS (SELECT 1 FROM public.employees WHERE email = NEW.email) THEN
        v_role := 'employee';
    END IF;

    -- Also check metadata (passed from frontend)
    IF NEW.raw_user_meta_data->>'role' IS NOT NULL THEN
        v_role := NEW.raw_user_meta_data->>'role';
    END IF;

    INSERT INTO public.users (id, email, name, role, created_at, updated_at)
    VALUES (
        NEW.id, 
        NEW.email, 
        COALESCE(NEW.raw_user_meta_data->>'name', SPLIT_PART(NEW.email, '@', 1)),
        v_role,
        NEW.created_at,
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        role = EXCLUDED.role,
        email = EXCLUDED.email,
        updated_at = NOW();

    -- If the user is an employee, also update their user_id in the employees table
    IF v_role = 'employee' THEN
        UPDATE public.employees SET user_id = NEW.id WHERE email = NEW.email;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- 5. Final check: Ensure all employees have their user_id linked if their email exists in users
UPDATE public.employees e
SET user_id = u.id
FROM public.users u
WHERE e.email = u.email AND e.user_id IS NULL;
