import dotenv from 'dotenv';

dotenv.config();

// Environment variables (ensure they're loaded properly before using)
export const SUPABASE_URL = process.env.SUPABASE_URL as string;
export const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY as string;

export const PLAID_CLIENT_ID = process.env.PLAID_CLIENT_ID as string;
export const PLAID_CLIENT_SECRET = process.env.PLAID_CLIENT_SECRET as string;
