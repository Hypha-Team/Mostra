/**
 * Public Supabase config. Both values are safe for the browser.
 * Set by the Vercel ↔ Supabase integration (or by hand on Vercel / in .env.local).
 * The service-role / secret key is never read here.
 */
export function getSupabasePublicEnv(): { url: string; key: string } | null {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key =
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !key) return null;
  return { url, key };
}

export function requireSupabasePublicEnv(): { url: string; key: string } {
  const env = getSupabasePublicEnv();
  if (!env) {
    throw new Error(
      "Supabase env missing: set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY (or NEXT_PUBLIC_SUPABASE_ANON_KEY).",
    );
  }
  return env;
}
