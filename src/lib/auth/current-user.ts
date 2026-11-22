import "server-only";
import { cache } from "react";
import { getSupabasePublicEnv } from "@/lib/supabase/env";
import { createClient } from "@/lib/supabase/server";
import type { CurrentUser, Organization, Profile } from "./types";

/**
 * The signed-in user with profile and organizations, or null.
 * Reads cookies: call it only inside a <Suspense> boundary (Cache Components).
 * Authorization is enforced by RLS; this is for rendering and redirects.
 */
export const getCurrentUser = cache(async (): Promise<CurrentUser | null> => {
  if (!getSupabasePublicEnv()) return null;
  const supabase = await createClient();
  const { data: claimsData } = await supabase.auth.getClaims();
  const claims = claimsData?.claims;
  if (!claims?.sub) return null;

  const [{ data: profile }, { data: memberships }] = await Promise.all([
    supabase
      .from("profiles")
      .select("id, full_name, roles, verified, university_id, is_demo")
      .eq("id", claims.sub)
      .maybeSingle<Profile>(),
    supabase
      .from("organization_members")
      .select("organizations(id, name, kind, website, nif, status, created_at, approved_at)")
      .eq("profile_id", claims.sub),
  ]);

  let universityName: string | null = null;
  if (profile?.university_id) {
    const { data: uni } = await supabase
      .from("universities")
      .select("name")
      .eq("id", profile.university_id)
      .maybeSingle<{ name: string }>();
    universityName = uni?.name ?? null;
  }

  const organizations = ((memberships ?? []) as unknown as { organizations: Organization | null }[])
    .map((m) => m.organizations)
    .filter((o): o is Organization => o !== null);

  return {
    id: claims.sub,
    email: typeof claims.email === "string" ? claims.email : null,
    profile: profile ?? null,
    organizations,
    universityName,
  };
});

export function isAdmin(user: CurrentUser | null): boolean {
  return !!user?.profile?.roles.includes("admin");
}
