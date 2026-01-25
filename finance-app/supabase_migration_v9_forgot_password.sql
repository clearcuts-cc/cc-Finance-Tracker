-- Migration V9: Helper function for Forgot Password Role Check

-- Secure function to check user role by email
-- Security Definer allows it to run with elevated privileges (to read users table which might be restricted)
CREATE OR REPLACE FUNCTION public.get_user_role_by_email(email_input TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_role TEXT;
BEGIN
    -- trim and lowercase to ensure match
    SELECT role INTO user_role
    FROM public.users
    WHERE lower(email) = lower(email_input)
    LIMIT 1;

    RETURN user_role;
END;
$$ SET search_path = public;

-- Grant execute permission to everyone (since forgot password is public)
GRANT EXECUTE ON FUNCTION public.get_user_role_by_email(TEXT) TO anon, authenticated, service_role;
