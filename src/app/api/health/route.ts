import { connection, NextResponse } from "next/server";
import { getSupabasePublicEnv } from "@/lib/supabase/env";

type Health = {
  app: "ok";
  env: string;
  supabase: "ok" | "missing_env" | "unreachable";
  supabaseStatus?: number;
};

/** Reports whether the deployment can reach Supabase. Never returns keys or URLs. */
export async function GET() {
  await connection();
  const body: Health = {
    app: "ok",
    env: process.env.VERCEL_ENV ?? "local",
    supabase: "missing_env",
  };

  const env = getSupabasePublicEnv();
  if (env) {
    try {
      const res = await fetch(`${env.url}/auth/v1/health`, {
        headers: { apikey: env.key },
        cache: "no-store",
        signal: AbortSignal.timeout(5000),
      });
      body.supabase = res.ok ? "ok" : "unreachable";
      body.supabaseStatus = res.status;
    } catch {
      body.supabase = "unreachable";
    }
  }

  return NextResponse.json(body, {
    status: body.supabase === "ok" || body.supabase === "missing_env" ? 200 : 503,
    headers: { "cache-control": "no-store" },
  });
}
