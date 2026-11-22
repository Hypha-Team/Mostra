import { createServerClient } from "@supabase/ssr";
import type { NextRequest, NextResponse } from "next/server";
import { getSupabasePublicEnv } from "./env";

/**
 * Refreshes the Supabase session cookie on every page request and writes any
 * updated auth cookies onto the (already built) next-intl response.
 */
export async function updateSession(request: NextRequest, response: NextResponse) {
  const env = getSupabasePublicEnv();
  if (!env) return response;

  const supabase = createServerClient(env.url, env.key, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet, headers) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options),
        );
        Object.entries(headers ?? {}).forEach(([key, value]) => response.headers.set(key, value));
      },
    },
  });

  // Triggers token refresh when needed. Do not put logic between client creation and this call.
  await supabase.auth.getClaims();
  return response;
}
