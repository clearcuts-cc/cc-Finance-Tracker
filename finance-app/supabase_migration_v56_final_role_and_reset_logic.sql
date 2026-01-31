-- Migration V56: Consolidated Password Reset & Role Sync Logic (SECURE VERSION)
-- This migration combines all fixes for role identification and password reset flow.
-- Fixed: "Function Search Path Mutable" security warning.

-- 1. THE CHECK FUNCTION: Identifies if an email belongs to an employee
CREATE OR REPLACE FUNCTION public.is_employee_email(check_email TEXT)
RETURNS BOOLEAN 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public -- SECURE: Explicit search path
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM employees WHERE email = check_email
    ) OR EXISTS (
        SELECT 1 FROM users WHERE email = check_email AND role = 'employee'
    );
END;
$$;

-- 2. THE NOTIFICATION FUNCTION: Sends a request to the admin
CREATE OR REPLACE FUNCTION public.request_employee_password_reset_notification(target_email text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public -- SECURE: Explicit search path
AS $$
DECLARE
    v_user_id uuid;
    v_admin_id uuid;
    v_user_name text;
BEGIN
    SELECT user_id, admin_id, name INTO v_user_id, v_admin_id, v_user_name
    FROM employees
    WHERE email = target_email
    LIMIT 1;

    IF v_admin_id IS NULL THEN
        RETURN false;
    END IF;

    IF EXISTS (
        SELECT 1 FROM notifications 
        WHERE admin_id = v_admin_id 
          AND type = 'password_reset_request' 
          AND metadata->>'email' = target_email
          AND created_at > (now() - interval '1 hour')
          AND is_read = false
    ) THEN
        RETURN true;
    END IF;

    INSERT INTO notifications (
        admin_id, user_id, title, message, type, metadata, is_read, created_at
    ) VALUES (
        v_admin_id, v_user_id, 'Password Reset Request',
        coalesce(v_user_name, 'Employee') || ' (' || target_email || ') requested a password reset. Please provide them with new credentials.',
        'password_reset_request',
        jsonb_build_object('email', target_email, 'name', v_user_name),
        false, now()
    );

    RETURN true;
END;
$$;

-- 3. PERMISSIONS: Allow anyone (even logged out) to call these
GRANT EXECUTE ON FUNCTION public.is_employee_email(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.is_employee_email(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.request_employee_password_reset_notification(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.request_employee_password_reset_notification(TEXT) TO authenticated;

-- 4. ROLE IDENTIFICATION SYNC: Ensure users table always reflects the employee status
CREATE OR REPLACE FUNCTION public.sync_user_role_from_employees()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') AND NEW.user_id IS NOT NULL THEN
        UPDATE public.users SET role = 'employee' WHERE id = NEW.user_id;
    ELSIF (TG_OP = 'DELETE') AND OLD.user_id IS NOT NULL THEN
        UPDATE public.users SET role = 'admin' WHERE id = OLD.user_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public; -- SECURE: Explicit search path added to fix warning

DROP TRIGGER IF EXISTS tr_sync_employee_role ON public.employees;
CREATE TRIGGER tr_sync_employee_role
AFTER INSERT OR UPDATE OR DELETE ON public.employees
FOR EACH ROW EXECUTE FUNCTION public.sync_user_role_from_employees();

-- 5. INITIAL SYNC: Fix all existing roles right now
UPDATE public.users SET role = 'admin' WHERE role IS NULL;
UPDATE public.users u SET role = 'employee' FROM public.employees e WHERE u.id = e.user_id;
