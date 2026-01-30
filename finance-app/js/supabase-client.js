/**
 * Supabase Client Initialization for FinanceFlow
 * Direct connection to Supabase - No backend required
 */

const SUPABASE_URL = 'https://sszcnspfllikptetsdoe.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNzemNuc3BmbGxpa3B0ZXRzZG9lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5MDgwMjEsImV4cCI6MjA4NDQ4NDAyMX0.WaWbVXrGD_jvlK-ZBBvaZNwX_a14wXLI1tfifPTrybA';

// Create Supabase client instance
const supabaseClient = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
window.supabaseClient = supabaseClient;

console.log('Supabase client initialized');
