-- ============================================================
-- Migration v20: simplify_schema (Remove Phone, Global Invoice Seq)
-- ============================================================

-- ------------------------------------------------------------
-- 1. Remove Phone Number Columns (Ass requested)
-- ------------------------------------------------------------
-- Removing from users and employees to simplify data model
ALTER TABLE users DROP COLUMN IF EXISTS phone;
ALTER TABLE employees DROP COLUMN IF EXISTS phone;

-- ------------------------------------------------------------
-- 2. Global Invoice Numbering Logic
-- ------------------------------------------------------------
-- We want a sequential number for the organization (Admin + their Employees)
-- Create a function to get the next number safely

CREATE OR REPLACE FUNCTION get_next_invoice_number(org_admin_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    max_num INTEGER;
    next_num INTEGER;
BEGIN
    -- Find the highest existing invoice number for this organization (admin_id)
    SELECT MAX(CAST(regexp_replace(invoice_number, '\D', '', 'g') AS INTEGER))
    INTO max_num
    FROM invoices
    WHERE admin_id = org_admin_id;

    -- If null (no invoices yet), start at 1
    IF max_num IS NULL THEN
        next_num := 1;
    ELSE
        next_num := max_num + 1;
    END IF;

    RETURN next_num;
END;
$$;
