# Implementation Plan - FinanceFlow Updates

## 1. UI & State Fixes
- **Profile Data Persistence**: Fix profile data disappearing on refresh by ensuring `ProfileManager` correctly handles session restoration and `localStorage` syncing in `js/profile.js`.
- **Sidebar Arrow Alignment**: Adjust CSS in `css/styles.css` to align the sidebar popup arrow with the design line as requested.
- **Navbar Sticky**: Add `position: sticky` to the navbar in `css/styles.css`.
- **Networth UI Fix**: Fix high number cutoff in dashboard by adjusting font sizes or container width in `css/styles.css`.

## 2. Invoice Module Updates
- **Stop Email Sending**: Temporarily disable the email sending function in `js/invoices.js` by commenting out the API call.
- **Invoice "Created By"**: Add `created_by` and `created_by_email` fields to `invoices` table and saving logic in `js/invoices.js`. Display this in the invoice history.
- **Default Due Date**: Set default due date to 3 days from current date (instead of 30) in `js/invoices.js`.
- **Save Bug Fix**: Investigate and fix the admin save invoice error (likely RLS or payload issue).

## 3. Client & Employee Visibility (Permissions)
- **Shared Client Visibility**: Ensure `clients` table RLS policies allow both Admin and Employees to view all clients. Update `js/clients.js` if necessary to fetch all.
- **Invoice "Unknown" Fix**: Display the creator's name/email on invoices.

## 4. Deletion Logic (Admin vs Employee)
- **Admin**: Immediate deletion.
- **Employee**: Deletion request logic.
  - **Strategy**: Add `deletion_requested` (boolean) and `deletion_requested_by` columns to `finance_entries` table.
  - **Employee Action**: When employee deletes, set flag instead of deleting.
  - **Admin Action**: Admin sees "Deletion Requests" (or filtered view). Admin approval deletes the record. Admin decline clears the flag.

## 5. New Modules
- **Available Balance Module**:
  - Logic: `Available = Total Income (Received) - Total Expenses`.
  - Display "Pending" separately.
  - Ensure "Available" does not include Pending amounts.
- **Investment Module**:
  - **Database**: Create `investments` table (`id`, `item_name`, `type`, `amount`, `buy_date`, `purpose`, `created_by`, `status` [pending/approved]).
  - **UI**: New "Investments" page/section.
  - **Logic**: 
    - Employee adds -> Status 'pending'.
    - Admin adds -> Status 'approved'.
    - Admin approves/declines employee entries.
  - **PDF**: Add download feature for investment list.

## 6. Execution Steps
1.  **Immediate Fixes**: Stop Email, Profile Refresh, UI Tweaks (Navbar, Sidebar, Networth).
2.  **Database Updates**: Run SQL migrations for `investments`, `invoices` modifications, and RLS updates for Clients.
3.  **Logic Implementation**: Update `data-api.js` for new calculations and deletion logic.
4.  **UI Implementation**: Add Investment pages, Update Dashboard for "Available", Add "Created By" in Invoice.
5.  **Review**: Verify all constraints (Employee restrictions, Admin powers).
