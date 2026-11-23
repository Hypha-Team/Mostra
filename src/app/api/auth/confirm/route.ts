import type { EmailOtpType } from "@supabase/supabase-js";
import { type NextRequest, NextResponse } from "next/server";
import { safeNextPath } from "@/lib/site-url";
import { getSupabasePublicEnv } from "@/lib/supabase/env";
import { createClient } from "@/lib/supabase/server";

/**
 * Magic-link landing. Supports both the default Supabase email template (PKCE `code`)
 * and a custom template that sends `token_hash` + `type`.
 */
export async function GET(request: NextRequest) {
  const url = request.nextUrl;
  const next = safeNextPath(url.searchParams.get("next"));
  const failure = new URL(next.startsWith("/en") ? "/en/sign-in" : "/sign-in", url.origin);
  failure.searchParams.set("error", "link");

  const code = url.searchParams.get("code");
  const tokenHash = url.searchParams.get("token_hash");
  const type = url.searchParams.get("type") as EmailOtpType | null;
  if (!getSupabasePublicEnv() || (!code && !(tokenHash && type))) {
    return NextResponse.redirect(failure);
  }

  const supabase = await createClient();
  let ok = false;
  if (code) {
    const { error } = await supabase.auth.exchangeCodeForSession(code);
    ok = !error;
  } else if (tokenHash && type) {
    const { error } = await supabase.auth.verifyOtp({ type, token_hash: tokenHash });
    ok = !error;
  }

  return NextResponse.redirect(ok ? new URL(next, url.origin) : failure);
}
