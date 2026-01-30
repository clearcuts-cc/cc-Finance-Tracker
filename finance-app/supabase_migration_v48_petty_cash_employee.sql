-- Add employee tracking and status workflow to petty cash entries
ALTER TABLE petty_cash_entries ADD COLUMN IF NOT EXISTS employee_id uuid;
ALTER TABLE petty_cash_entries ADD COLUMN IF NOT EXISTS employee_name text;
ALTER TABLE petty_cash_entries ADD COLUMN IF NOT EXISTS status text DEFAULT 'approved'; -- pending, approved, declined

-- Update existing entries to have a status
UPDATE petty_cash_entries SET status = 'approved' WHERE status IS NULL;
