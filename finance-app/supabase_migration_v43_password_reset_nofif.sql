-- Migration V43: Password Reset Notifications
-- This enables the system to notify Admins when an Employee forgets their password.

-- 1. Add metadata column to notifications if not exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='notifications' AND column_name='metadata') THEN
        ALTER TABLE notifications ADD COLUMN metadata jsonb DEFAULT '{}'::jsonb;
    END IF;
END $$;

-- 2. Create RPC function for unauthenticated users to request password reset
-- SECURITY DEFINER allows this to run with privileges of the creator (postgres/admin)
-- enabling 'anon' users to write to the notifications table via this function.

CREATE OR REPLACE FUNCTION request_employee_password_reset_notification(target_email text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid;
    v_admin_id uuid;
    v_user_name text;
BEGIN
    -- 1. Find the user (employee)
    SELECT id, admin_id, name INTO v_user_id, v_admin_id, v_user_name
    FROM users
    WHERE email = target_email
    LIMIT 1;

    -- If no user found, return false (or true to prevent enumeration, but let's be helpful for now)
    IF v_user_id IS NULL THEN
        RETURN false;
    END IF;

    -- If no admin_id (e.g., this IS the admin, or standalone user), they should use standard reset
    IF v_admin_id IS NULL THEN
        RETURN false; -- Standard reset applies
    END IF;

    -- 2. Check if a pending request already exists to prevent spam
    IF EXISTS (
        SELECT 1 FROM notifications 
        WHERE user_id = v_user_id 
          AND type = 'password_reset_request' 
          AND is_read = false
    ) THEN
        RETURN true; -- Pretend we sent it, avoiding duplicates
    END IF;

    -- 3. Insert Notification for the Admin
    INSERT INTO notifications (
        user_id,
        admin_id,
        title,
        message,
        type,
        metadata
    ) VALUES (
        v_user_id,
        v_admin_id,
        'Password Reset Request',
        coalesce(v_user_name, 'Employee') || ' (' || target_email || ') requested a password reset.',
        'password_reset_request',
        jsonb_build_object('email', target_email)
    );

    RETURN true;
END;
$$;
