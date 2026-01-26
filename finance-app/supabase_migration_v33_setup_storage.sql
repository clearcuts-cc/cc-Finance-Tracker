-- ============================================================
-- Migration V33: Setup Storage for Avatars (Fixed)
-- ============================================================

-- 1. Create the 'avatars' bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Note: We removed 'ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY'
-- because that table is managed by Supabase and already has security enabled.
-- Trying to modify it causes "must be owner of table" error.

-- 2. Drop existing policies to avoid conflicts if re-running
DROP POLICY IF EXISTS "Avatar Public View" ON storage.objects;
DROP POLICY IF EXISTS "Avatar Upload Own" ON storage.objects;
DROP POLICY IF EXISTS "Avatar Update Own" ON storage.objects;
DROP POLICY IF EXISTS "Avatar Delete Own" ON storage.objects;

-- 3. Create Policies

-- Allow Public View (Anyone can view profile pictures)
CREATE POLICY "Avatar Public View"
ON storage.objects FOR SELECT
USING ( bucket_id = 'avatars' );

-- Allow Authenticated Users to Upload (INSERT)
CREATE POLICY "Avatar Upload Own"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'avatars' AND
    auth.uid() = owner
);

-- Allow Users to Update their own avatars
CREATE POLICY "Avatar Update Own"
ON storage.objects FOR UPDATE
TO authenticated
USING (
    bucket_id = 'avatars' AND
    auth.uid() = owner
);

-- Allow Users to Delete their own avatars
CREATE POLICY "Avatar Delete Own"
ON storage.objects FOR DELETE
TO authenticated
USING (
    bucket_id = 'avatars' AND
    auth.uid() = owner
);
