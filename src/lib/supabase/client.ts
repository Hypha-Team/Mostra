"use client";

import { createBrowserClient } from "@supabase/ssr";
import { requireSupabasePublicEnv } from "./env";

/** Supabase client for Client Components (anon/publishable key only, RLS applies). */
export function createClient() {
  const { url, key } = requireSupabasePublicEnv();
  return createBrowserClient(url, key);
}
