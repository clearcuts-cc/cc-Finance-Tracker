/**
 * FinanceFlow - Supabase Data Layer
 * Direct connection to Supabase - No backend required
 */

// Helper functions to convert between JS camelCase and database snake_case
const toDbEntry = (entry) => ({
    date: entry.date,
    client_name: entry.clientName,
    description: entry.description,
    amount: entry.amount,
    type: entry.type,
    status: entry.status,
    payment_mode: entry.paymentMode
});

const fromDbEntry = (row) => ({
    id: row.id,
    date: row.date,
    clientName: row.client_name,
    description: row.description,
    amount: row.amount,
    type: row.type,
    status: row.status,
    paymentMode: row.payment_mode,
    userId: row.user_id,
    createdAt: row.created_at
});

const toDbInvoice = (invoice) => ({
    invoice_number: invoice.invoiceNumber,
    invoice_date: invoice.invoiceDate,
    due_date: invoice.dueDate,
    client_name: invoice.clientName,
    client_address: invoice.clientAddress,
    client_phone: invoice.clientPhone,
    agency_name: invoice.agencyName,
    agency_contact: invoice.agencyContact,
    agency_address: invoice.agencyAddress,
    agency_logo: invoice.agencyLogo,
    subtotal: invoice.subtotal,
    tax_percent: invoice.taxPercent,
    tax_amount: invoice.taxAmount,
    discount_percent: invoice.discountPercent,
    discount_amount: invoice.discountAmount,
    grand_total: invoice.grandTotal,
    payment_status: invoice.paymentStatus
});

const fromDbInvoice = (row) => ({
    id: row.id,
    invoiceNumber: row.invoice_number,
    invoiceDate: row.invoice_date,
    dueDate: row.due_date,
    clientName: row.client_name,
    clientAddress: row.client_address,
    clientPhone: row.client_phone,
    agencyName: row.agency_name,
    agencyContact: row.agency_contact,
    agencyAddress: row.agency_address,
    agencyLogo: row.agency_logo,
    subtotal: row.subtotal,
    taxPercent: row.tax_percent,
    taxAmount: row.tax_amount,
    discountPercent: row.discount_percent,
    discountAmount: row.discount_amount,
    grandTotal: row.grand_total,
    paymentStatus: row.payment_status,
    services: row.invoice_services?.map(s => ({
        id: s.id,
        name: s.name,
        quantity: s.quantity,
        rate: s.rate,
        amount: s.amount
    })) || [],
    createdAt: row.created_at
});

class DataLayerAPI {
    constructor() {
        this.listeners = new Map();
    }

    /**
     * Initialize the data layer
     */
    async init() {
        console.log('Supabase DataLayer initialized');

        // Check authentication status
        const { data: { session } } = await supabaseClient.auth.getSession();
        if (!session) {
            const isAuthPage = window.location.pathname.includes('login.html') ||
                window.location.pathname.includes('signup.html');
            if (!isAuthPage) {
                console.warn('No active session, redirecting to login');
                window.location.href = 'login.html';
                return;
            }
        }

        return Promise.resolve();
    }

    /**
     * Get current user ID
     */
    async getCurrentUserId() {
        const { data: { session } } = await supabaseClient.auth.getSession();
        return session?.user?.id || null;
    }

    /**
     * Handle Supabase errors
     */
    handleError(error, context = 'Operation') {
        console.error(`${context} error:`, error);
        if (error.code === 'PGRST301' || error.message?.includes('JWT')) {
            // Auth error - redirect to login
            localStorage.removeItem('user');
            window.location.href = 'login.html';
        }
        throw new Error(error.message || `${context} failed`);
    }

    /**
     * Add a change listener
     */
    subscribe(storeName, callback) {
        if (!this.listeners.has(storeName)) {
            this.listeners.set(storeName, new Set());
        }
        this.listeners.get(storeName).add(callback);

        return () => {
            this.listeners.get(storeName).delete(callback);
        };
    }

    /**
     * Notify listeners of changes
     */
    notifyListeners(storeName) {
        if (this.listeners.has(storeName)) {
            this.listeners.get(storeName).forEach(callback => callback());
        }
    }

    // ==================== Finance Entries ====================

    async addEntry(entry) {
        const userId = await this.getCurrentUserId();
        const dbEntry = toDbEntry(entry);
        const { data, error } = await supabaseClient
            .from('finance_entries')
            .insert({ ...dbEntry, user_id: userId })
            .select()
            .single();

        if (error) this.handleError(error, 'Add entry');
        this.notifyListeners(DATA_STORES.ENTRIES);
        return fromDbEntry(data);
    }

    async updateEntry(id, entry) {
        const dbEntry = toDbEntry(entry);
        const { data, error } = await supabaseClient
            .from('finance_entries')
            .update(dbEntry)
            .eq('id', id)
            .select()
            .single();

        if (error) this.handleError(error, 'Update entry');
        this.notifyListeners(DATA_STORES.ENTRIES);
        return fromDbEntry(data);
    }

    async deleteEntry(id) {
        const { error } = await supabaseClient
            .from('finance_entries')
            .delete()
            .eq('id', id);

        if (error) this.handleError(error, 'Delete entry');
        this.notifyListeners(DATA_STORES.ENTRIES);
        return true;
    }

    async getEntry(id) {
        const { data, error } = await supabaseClient
            .from('finance_entries')
            .select('*')
            .eq('id', id)
            .single();

        if (error) this.handleError(error, 'Get entry');
        return fromDbEntry(data);
    }

    async getAllEntries() {
        const userId = await this.getCurrentUserId();
        const { data, error } = await supabaseClient
            .from('finance_entries')
            .select('*')
            .eq('user_id', userId)
            .order('date', { ascending: false });

        if (error) this.handleError(error, 'Get all entries');
        return (data || []).map(fromDbEntry);
    }

    async getFilteredEntries(filters = {}) {
        const userId = await this.getCurrentUserId();
        let query = supabaseClient.from('finance_entries').select('*').eq('user_id', userId);

        if (filters.startDate) {
            query = query.gte('date', filters.startDate);
        }
        if (filters.endDate) {
            query = query.lte('date', filters.endDate);
        }
        if (filters.type) {
            query = query.eq('type', filters.type);
        }
        if (filters.status) {
            query = query.eq('status', filters.status);
        }
        if (filters.paymentMode) {
            query = query.eq('payment_mode', filters.paymentMode);
        }
        if (filters.search) {
            query = query.or(`client_name.ilike.%${filters.search}%,description.ilike.%${filters.search}%`);
        }

        // Handle month/year filtering
        if (filters.month !== '' && filters.month !== undefined && filters.year) {
            const month = parseInt(filters.month) + 1; // JS months are 0-indexed
            const year = parseInt(filters.year);
            const startDate = `${year}-${String(month).padStart(2, '0')}-01`;
            const endDate = new Date(year, month, 0).toISOString().split('T')[0];
            query = query.gte('date', startDate).lte('date', endDate);
        } else if (filters.year) {
            query = query.gte('date', `${filters.year}-01-01`).lte('date', `${filters.year}-12-31`);
        }

        query = query.order('date', { ascending: false });

        const { data, error } = await query;
        if (error) this.handleError(error, 'Filter entries');
        return (data || []).map(fromDbEntry);
    }

    async getFinancialSummary(filters = {}) {
        const entries = await this.getFilteredEntries(filters);

        let totalIncome = 0;
        let totalExpense = 0;
        let pendingAmount = 0;
        let receivedAmount = 0;

        entries.forEach(entry => {
            const amount = parseFloat(entry.amount) || 0;
            if (entry.type === 'income') {
                totalIncome += amount;
            } else {
                totalExpense += amount;
            }
            if (entry.status === 'pending') {
                pendingAmount += amount;
            } else {
                receivedAmount += amount;
            }
        });

        return {
            totalIncome,
            totalExpense,
            pendingAmount,
            receivedAmount,
            netBalance: totalIncome - totalExpense
        };
    }

    async getMonthlyData(year) {
        const userId = await this.getCurrentUserId();
        const { data, error } = await supabaseClient
            .from('finance_entries')
            .select('*')
            .eq('user_id', userId)
            .gte('date', `${year}-01-01`)
            .lte('date', `${year}-12-31`);

        if (error) this.handleError(error, 'Get monthly data');

        // Aggregate by month
        const monthlyData = Array(12).fill(null).map(() => ({ income: 0, expense: 0 }));

        (data || []).forEach(entry => {
            const month = new Date(entry.date).getMonth();
            const amount = parseFloat(entry.amount) || 0;
            if (entry.type === 'income') {
                monthlyData[month].income += amount;
            } else {
                monthlyData[month].expense += amount;
            }
        });

        return monthlyData;
    }

    async getPaymentModeDistribution() {
        const entries = await this.getAllEntries();
        const distribution = {};

        entries.forEach(entry => {
            const mode = entry.payment_mode || 'unknown';
            const amount = parseFloat(entry.amount) || 0;
            distribution[mode] = (distribution[mode] || 0) + amount;
        });

        return distribution;
    }

    async getStatusDistribution() {
        const entries = await this.getAllEntries();
        let pending = 0;
        let received = 0;

        entries.forEach(entry => {
            const amount = parseFloat(entry.amount) || 0;
            if (entry.status === 'pending') {
                pending += amount;
            } else {
                received += amount;
            }
        });

        return { pending, received };
    }

    async getYearlyRevenue() {
        const entries = await this.getAllEntries();
        const yearlyData = {};

        entries.forEach(entry => {
            const year = new Date(entry.date).getFullYear();
            const amount = parseFloat(entry.amount) || 0;
            if (!yearlyData[year]) {
                yearlyData[year] = { income: 0, expense: 0 };
            }
            if (entry.type === 'income') {
                yearlyData[year].income += amount;
            } else {
                yearlyData[year].expense += amount;
            }
        });

        return yearlyData;
    }

    // ==================== Invoices ====================

    async addInvoice(invoice) {
        const userId = await this.getCurrentUserId();
        const { services, ...invoiceData } = invoice;
        const dbInvoice = toDbInvoice(invoiceData);

        // Insert invoice
        const { data: invoiceResult, error: invoiceError } = await supabaseClient
            .from('invoices')
            .insert({ ...dbInvoice, user_id: userId })
            .select()
            .single();

        if (invoiceError) this.handleError(invoiceError, 'Add invoice');

        // Insert services if present
        if (services && services.length > 0) {
            const servicesWithInvoiceId = services.map(s => ({
                name: s.name,
                quantity: s.quantity,
                rate: s.rate,
                amount: s.amount,
                invoice_id: invoiceResult.id
            }));

            const { error: servicesError } = await supabaseClient
                .from('invoice_services')
                .insert(servicesWithInvoiceId);

            if (servicesError) {
                console.warn('Error inserting services:', servicesError);
            }
        }

        this.notifyListeners(DATA_STORES.INVOICES);
        return fromDbInvoice({ ...invoiceResult, invoice_services: services || [] });
    }

    async updateInvoice(id, invoice) {
        const { services, ...invoiceData } = invoice;
        const dbInvoice = toDbInvoice(invoiceData);

        const { data, error } = await supabaseClient
            .from('invoices')
            .update(dbInvoice)
            .eq('id', id)
            .select()
            .single();

        if (error) this.handleError(error, 'Update invoice');

        // Update services if provided
        if (services) {
            // Delete existing services
            await supabaseClient.from('invoice_services').delete().eq('invoice_id', id);

            // Insert new services
            if (services.length > 0) {
                const servicesWithInvoiceId = services.map(s => ({
                    name: s.name,
                    quantity: s.quantity,
                    rate: s.rate,
                    amount: s.amount,
                    invoice_id: id
                }));
                await supabaseClient.from('invoice_services').insert(servicesWithInvoiceId);
            }
        }

        this.notifyListeners(DATA_STORES.INVOICES);
        return fromDbInvoice({ ...data, invoice_services: services || [] });
    }

    async deleteInvoice(id) {
        // Delete services first (cascade might be configured in DB)
        await supabaseClient.from('invoice_services').delete().eq('invoice_id', id);

        const { error } = await supabaseClient
            .from('invoices')
            .delete()
            .eq('id', id);

        if (error) this.handleError(error, 'Delete invoice');
        this.notifyListeners(DATA_STORES.INVOICES);
        return true;
    }

    async importInvoices(invoices) {
        const userId = await this.getCurrentUserId();
        const results = [];

        for (const invoice of invoices) {
            try {
                const result = await this.addInvoice({ ...invoice, user_id: userId });
                results.push(result);
            } catch (err) {
                console.warn('Error importing invoice:', err);
            }
        }

        this.notifyListeners(DATA_STORES.INVOICES);
        return results;
    }

    async getInvoice(id) {
        const { data, error } = await supabaseClient
            .from('invoices')
            .select('*, invoice_services(*)')
            .eq('id', id)
            .single();

        if (error) this.handleError(error, 'Get invoice');
        return fromDbInvoice(data);
    }

    async getAllInvoices() {
        const userId = await this.getCurrentUserId();
        const { data, error } = await supabaseClient
            .from('invoices')
            .select('*, invoice_services(*)')
            .eq('user_id', userId)
            .order('created_at', { ascending: false });

        if (error) this.handleError(error, 'Get all invoices');
        return (data || []).map(fromDbInvoice);
    }

    async getNextInvoiceNumber() {
        const userId = await this.getCurrentUserId();
        const { data, error } = await supabaseClient
            .from('invoices')
            .select('invoice_number')
            .eq('user_id', userId)
            .order('created_at', { ascending: false })
            .limit(1);

        if (error || !data || data.length === 0) {
            return 'INV-001';
        }

        const lastNumber = data[0].invoice_number;
        const match = lastNumber.match(/INV-(\d+)/);
        if (match) {
            const nextNum = parseInt(match[1]) + 1;
            return `INV-${String(nextNum).padStart(3, '0')}`;
        }
        return 'INV-001';
    }

    // ==================== Clients ====================

    async addClient(client) {
        const userId = await this.getCurrentUserId();
        const { data, error } = await supabaseClient
            .from('clients')
            .insert({ ...client, user_id: userId })
            .select()
            .single();

        if (error) this.handleError(error, 'Add client');
        this.notifyListeners(DATA_STORES.CLIENTS);
        return data;
    }

    async updateClient(id, client) {
        const { data, error } = await supabaseClient
            .from('clients')
            .update(client)
            .eq('id', id)
            .select()
            .single();

        if (error) this.handleError(error, 'Update client');
        this.notifyListeners(DATA_STORES.CLIENTS);
        return data;
    }

    async deleteClient(id) {
        const { error } = await supabaseClient
            .from('clients')
            .delete()
            .eq('id', id);

        if (error) this.handleError(error, 'Delete client');
        this.notifyListeners(DATA_STORES.CLIENTS);
        return true;
    }

    async getClient(id) {
        const { data, error } = await supabaseClient
            .from('clients')
            .select('*')
            .eq('id', id)
            .single();

        if (error) this.handleError(error, 'Get client');
        return data;
    }

    async getAllClients() {
        const userId = await this.getCurrentUserId();
        const { data, error } = await supabaseClient
            .from('clients')
            .select('*')
            .eq('user_id', userId)
            .order('name', { ascending: true });

        if (error) this.handleError(error, 'Get all clients');
        return data || [];
    }

    async getClientByName(name) {
        const clients = await this.getAllClients();
        return clients.find(c => c.name.toLowerCase() === name.toLowerCase());
    }

    // ==================== Settings ====================

    async getSetting(key) {
        const { data, error } = await supabaseClient
            .from('settings')
            .select('value')
            .eq('key', key)
            .single();

        if (error && error.code !== 'PGRST116') {
            console.warn('Get setting error:', error);
        }
        return data?.value ?? null;
    }

    async setSetting(key, value) {
        const { error } = await supabaseClient
            .from('settings')
            .upsert({ key, value }, { onConflict: 'key' });

        if (error) this.handleError(error, 'Set setting');
        return true;
    }

    async getAllSettings() {
        const { data, error } = await supabaseClient
            .from('settings')
            .select('*');

        if (error) this.handleError(error, 'Get all settings');
        return data || [];
    }

    // ==================== Export/Import ====================

    async exportData() {
        const entries = await this.getAllEntries();
        const invoices = await this.getAllInvoices();
        const clients = await this.getAllClients();
        const settings = await this.getAllSettings();

        return { entries, invoices, clients, settings };
    }

    async importData(data) {
        if (data.clients) {
            for (const client of data.clients) {
                try {
                    await this.addClient(client);
                } catch (e) { console.warn('Import client error:', e); }
            }
        }
        if (data.entries) {
            for (const entry of data.entries) {
                try {
                    await this.addEntry(entry);
                } catch (e) { console.warn('Import entry error:', e); }
            }
        }
        if (data.invoices) {
            await this.importInvoices(data.invoices);
        }

        this.notifyListeners(DATA_STORES.ENTRIES);
        this.notifyListeners(DATA_STORES.INVOICES);
        this.notifyListeners(DATA_STORES.CLIENTS);

        return true;
    }

    async clearAll() {
        // This is a destructive operation - only clears current user's data
        const userId = await this.getCurrentUserId();
        console.warn('Clear all data requested for user:', userId);

        // Get user's invoices to delete their services
        const { data: userInvoices } = await supabaseClient
            .from('invoices')
            .select('id')
            .eq('user_id', userId);

        if (userInvoices && userInvoices.length > 0) {
            const invoiceIds = userInvoices.map(inv => inv.id);
            await supabaseClient.from('invoice_services').delete().in('invoice_id', invoiceIds);
        }

        await supabaseClient.from('invoices').delete().eq('user_id', userId);
        await supabaseClient.from('finance_entries').delete().eq('user_id', userId);
        await supabaseClient.from('clients').delete().eq('user_id', userId);

        this.notifyListeners(DATA_STORES.ENTRIES);
        this.notifyListeners(DATA_STORES.INVOICES);
        this.notifyListeners(DATA_STORES.CLIENTS);

        return true;
    }

    async clearStore(storeName) {
        console.warn(`Clear store ${storeName} requested`);
        return this.clearAll();
    }
}

// Store names (kept for compatibility)
const DATA_STORES = {
    ENTRIES: 'finance_entries',
    INVOICES: 'invoices',
    CLIENTS: 'clients',
    SETTINGS: 'settings'
};

// Create and export singleton instance
const dataLayer = new DataLayerAPI();

// Helper functions for formatting (kept from original)
const formatCurrency = (amount, currency = '₹') => {
    const num = parseFloat(amount) || 0;
    return `${currency}${num.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
};

const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-IN', {
        day: '2-digit',
        month: 'short',
        year: 'numeric'
    });
};

const formatPaymentMode = (mode) => {
    const modes = {
        cash: 'Cash',
        upi: 'UPI',
        bank_transfer: 'Bank Transfer',
        card: 'Card',
        cheque: 'Cheque'
    };
    return modes[mode] || mode;
};
