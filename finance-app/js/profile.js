/**
 * Profile Manager - Handles Profile Page Logic
 * Using Supabase Auth and Database
 */
class ProfileManager {
    constructor() {
        this.currentUser = null;
        this.avatarBase64 = null;
    }

    /**
     * Initialize Profile Manager
     */
    async init() {
        // Bind Form Submit
        const form = document.getElementById('fullProfileForm');
        if (form) {
            form.addEventListener('submit', (e) => {
                e.preventDefault();
                this.saveProfile();
            });
        }

        // Bind File Input
        const avatarInput = document.getElementById('pageAvatarInput');
        if (avatarInput) {
            avatarInput.addEventListener('change', (e) => this.handleAvatarChange(e));
        }

        // Load user data from localStorage first (immediate), then refresh from API
        this.loadFromLocalStorage();
        this.updateHeaderAvatar();

        // If we are already on profile page (or it was restored), render it
        if (document.getElementById('profilePage') &&
            document.getElementById('profilePage').classList.contains('active')) {
            this.renderProfilePage();
        }

        // Then fetch fresh data from Supabase
        await this.loadCurrentUser();
    }

    /**
     * Load user from localStorage (for immediate display)
     */
    loadFromLocalStorage() {
        try {
            const storedUser = localStorage.getItem('user');
            if (storedUser) {
                this.currentUser = JSON.parse(storedUser);
            }
        } catch (e) {
            console.warn('Could not parse stored user:', e);
        }
    }

    /**
     * Load current user data from Supabase
     */
    async loadCurrentUser() {
        try {
            // Get authenticated user from Supabase Auth
            const { data: { user }, error: authError } = await supabaseClient.auth.getUser();

            if (authError || !user) {
                console.warn('Not authenticated:', authError);
                return;
            }

            // Get user profile from users table
            const { data: profile, error: profileError } = await supabaseClient
                .from('users')
                .select('*')
                .eq('id', user.id)
                .single();

            if (profileError) {
                console.warn('Could not fetch user profile:', profileError);
            }

            // Determine role - check profile first, then metadata, then default
            let role = profile?.role || user.user_metadata?.role;
            if (!role) {
                // Check if user is employee
                const { data: empData } = await supabaseClient
                    .from('employees')
                    .select('id')
                    .eq('user_id', user.id)
                    .single();
                role = empData ? 'employee' : 'admin';
            }

            // Merge auth user with profile data
            this.currentUser = {
                id: user.id,
                email: user.email,
                name: profile?.name || user.user_metadata?.name || 'User',
                avatar: profile?.avatar || null,
                role: role,
                created_at: user.created_at
            };

            // Update localStorage with fresh data
            localStorage.setItem('user', JSON.stringify(this.currentUser));

            this.updateHeaderAvatar();

            // If profile page is active, render it
            if (document.getElementById('profilePage') &&
                document.getElementById('profilePage').classList.contains('active')) {
                this.renderProfilePage();
            }
        } catch (error) {
            console.warn('Failed to load user data from Supabase, using localStorage:', error);
            this.updateHeaderAvatar();

            // If profile page is active, render it with local data
            if (document.getElementById('profilePage') &&
                document.getElementById('profilePage').classList.contains('active')) {
                this.renderProfilePage();
            }
        }
    }

    /**
     * Update Header Avatar
     */
    updateHeaderAvatar() {
        const avatarEl = document.querySelector('.user-profile .avatar');
        if (!avatarEl || !this.currentUser) return;

        if (this.currentUser.avatar) {
            avatarEl.innerHTML = `<img src="${this.currentUser.avatar}" alt="${this.currentUser.name}" style="width: 100%; height: 100%; object-fit: cover; border-radius: 50%;">`;
        } else {
            avatarEl.innerHTML = `<span>${this.getInitials(this.currentUser.name)}</span>`;
        }
    }

    /**
     * Render Profile Page Content
     */
    renderProfilePage() {
        if (!this.currentUser) {
            this.loadFromLocalStorage();
            if (!this.currentUser) {
                this.loadCurrentUser();
                return;
            }
        }

        // Update Identity Card
        const nameEl = document.getElementById('displayProfileName');
        const emailEl = document.getElementById('displayProfileEmail');
        const joinedEl = document.getElementById('displayJoinedDate');

        if (nameEl) nameEl.textContent = this.currentUser.name;
        if (emailEl) emailEl.textContent = this.currentUser.email;
        if (joinedEl) joinedEl.textContent = this.formatDate(this.currentUser.created_at);

        this.renderPageAvatar(this.currentUser.avatar, this.currentUser.name);

        // Update Form Fields
        const fName = document.getElementById('pageProfileName');
        const fEmail = document.getElementById('pageProfileEmail');

        if (fName) {
            fName.value = this.currentUser.name || '';
            fName.readOnly = true;
            fName.disabled = true;
            fName.style.opacity = "0.7";
            fName.style.cursor = "not-allowed";
        }

        if (fEmail) {
            fEmail.value = this.currentUser.email || '';
            // Bug #1: Ensure email is unchangeable
            fEmail.readOnly = true;
            fEmail.disabled = true; // Use disabled for stronger visual cue
            fEmail.style.opacity = "0.6";
            fEmail.style.cursor = "not-allowed";
            fEmail.style.backgroundColor = "var(--color-bg-tertiary)"; // Visually distinct
        }
    }

    /**
     * Render Avatar on Page
     */
    renderPageAvatar(src, name) {
        const img = document.getElementById('pageAvatarPreview');
        const placeholder = document.getElementById('pageAvatarPlaceholder');

        if (!img || !placeholder) return;

        if (src) {
            img.src = src;
            img.style.display = 'block';
            img.classList.remove('hidden');

            placeholder.style.display = 'none';
            placeholder.classList.add('hidden');
        } else {
            img.style.display = 'none';
            img.classList.add('hidden');

            placeholder.style.display = 'flex';
            placeholder.classList.remove('hidden');
            placeholder.textContent = this.getInitials(name);
        }
    }

    /**
     * Handle File Input Change
     */
    /**
     * Handle File Input Change
     */
    handleAvatarChange(e) {
        const file = e.target.files[0];
        if (!file) return;

        if (file.size > 5 * 1024 * 1024) {
            showToast('Image size should be less than 5MB', 'error');
            return;
        }

        // Store the file object for uploading during save
        this.pendingAvatarFile = file;

        // Create local preview immediately (Optimistic UI)
        const reader = new FileReader();
        reader.onload = (event) => {
            this.avatarBase64 = event.target.result; // Keep for preview
            this.renderPageAvatar(this.avatarBase64, document.getElementById('pageProfileName').value);
        };
        reader.readAsDataURL(file);
    }

    /**
     * Save Profile Changes
     */
    async saveProfile() {
        // Strict Rule: Only Avatar can be changed. Name is Read-Only.
        if (!this.pendingAvatarFile && !this.avatarBase64) {
            showToast('No changes to save.', 'info');
            return;
        }

        try {
            showToast('Updating profile...', 'info');

            const { data: { user } } = await supabaseClient.auth.getUser();
            if (!user) {
                showToast('Not authenticated', 'error');
                return;
            }

            let avatarUrl = this.currentUser.avatar;

            // 1. If we have a new file to upload
            if (this.pendingAvatarFile) {
                const file = this.pendingAvatarFile;
                const fileExt = file.name.split('.').pop();
                const fileName = `${user.id}/${Date.now()}.${fileExt}`;

                // Upload to Supabase Storage
                const { error: uploadError } = await supabaseClient
                    .storage
                    .from('avatars')
                    .upload(fileName, file, {
                        cacheControl: '3600',
                        upsert: false
                    });

                if (uploadError) {
                    throw new Error('Upload failed: ' + uploadError.message);
                }

                // Get Public URL
                const { data: { publicUrl } } = supabaseClient
                    .storage
                    .from('avatars')
                    .getPublicUrl(fileName);

                avatarUrl = publicUrl;
            }

            // 2. Update user profile in users table with the URL
            const updateData = { avatar: avatarUrl };

            console.log('Sending update to users table:', updateData);

            const { data: updateResult, error: updateError } = await supabaseClient
                .from('users')
                .update(updateData)
                .eq('id', user.id)
                .select();

            if (updateError) {
                console.error('Supabase update error:', updateError);
                throw updateError;
            }

            showToast('Profile updated successfully', 'success');

            // Update local state with the NEW URL (not the base64 preview)
            // This ensures if they refresh, they get the real URL
            this.currentUser.avatar = avatarUrl;
            localStorage.setItem('user', JSON.stringify(this.currentUser));

            // Update UI Final State
            this.updateHeaderAvatar();
            this.renderProfilePage();

            // Reset pending state
            this.pendingAvatarFile = null;
            this.avatarBase64 = null;

        } catch (error) {
            console.error('Profile Update Error:', error);
            showToast(error.message || 'Failed to update profile', 'error');
        }
    }

    getInitials(name) {
        return name ? name.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase() : '?';
    }

    formatDate(dateString) {
        if (!dateString) return '-';
        return new Date(dateString).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    }
}

// Create instance and expose to window
window.profileManager = new ProfileManager();
