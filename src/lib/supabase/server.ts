import "server-only";
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import { requireSupabasePublicEnv } from "./env";

/** Supabase client for Server Components, Server Actions and Route Handlers (acts as the signed-in user, RLS applies). */
export async function createClient() {
  const { url, key } = requireSupabasePublicEnv();
  const cookieStore = await cookies();

  return createServerClient(url, key, {
    cookies: {
      getAll() {
        return cookieStore.getAll();
      },
      setAll(cookiesToSet) {
        try {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookieStore.set(name, value, options),
          );
        } catch {
          // Called from a Server Component: cookies are read-only there.
          // Session refresh will happen in the proxy (Phase 1).
        }
      },
    },
  });
}
