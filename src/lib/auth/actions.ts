"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { routing } from "@/i18n/routing";
import { getSupabasePublicEnv } from "@/lib/supabase/env";
import { createClient } from "@/lib/supabase/server";
import { requestOrigin } from "@/lib/site-url";
import { ORGANIZATION_KINDS, type OrganizationKind } from "./types";

export type LinkState =
  | { status: "idle" }
  | { status: "sent"; email: string }
  | {
      status: "error";
      error: "invalidEmail" | "consent" | "notUniversity" | "unavailable" | "sendFailed";
      email?: string;
    };

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function localePath(locale: FormDataEntryValue | null, path: string): string {
  return locale === "en" ? `/en${path}` : path;
}

async function sendLink(
  formData: FormData,
  kind: "university" | "partner",
): Promise<LinkState> {
  const email = String(formData.get("email") ?? "").trim().toLowerCase();
  const consent = formData.get("consent") === "on";
  const locale = formData.get("locale");
  const fullName = String(formData.get("full_name") ?? "").trim();

  if (!EMAIL_RE.test(email)) return { status: "error", error: "invalidEmail", email };
  if (!consent) return { status: "error", error: "consent", email };
  if (!getSupabasePublicEnv()) return { status: "error", error: "unavailable", email };

  const supabase = await createClient();

  if (kind === "university") {
    const { data, error } = await supabase.rpc("email_signin_kind", { p_email: email });
    if (error) return { status: "error", error: "unavailable", email };
    if (data !== "university") return { status: "error", error: "notUniversity", email };
  }

  const origin = await requestOrigin();
  const next = localePath(locale, "/account");
  const { error } = await supabase.auth.signInWithOtp({
    email,
    options: {
      shouldCreateUser: true,
      emailRedirectTo: `${origin}/api/auth/confirm?next=${encodeURIComponent(next)}`,
      data: {
        privacy_consent: "true",
        locale: routing.locales.includes(locale as "pt" | "en") ? locale : routing.defaultLocale,
        ...(kind === "partner" ? { signup_as: "partner" } : {}),
        ...(fullName ? { full_name: fullName } : {}),
      },
    },
  });
  if (error) return { status: "error", error: "sendFailed", email };
  return { status: "sent", email };
}

export async function requestUniversityLink(_prev: LinkState, formData: FormData): Promise<LinkState> {
  return sendLink(formData, "university");
}

export async function requestPartnerLink(_prev: LinkState, formData: FormData): Promise<LinkState> {
  return sendLink(formData, "partner");
}

export async function signOut(formData: FormData) {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect(localePath(formData.get("locale"), "/"));
}

export type OrganisationState =
  | { status: "idle" }
  | { status: "error"; error: "name" | "kind" | "website" | "failed" };

export async function registerOrganisation(
  _prev: OrganisationState,
  formData: FormData,
): Promise<OrganisationState> {
  const name = String(formData.get("name") ?? "").trim();
  const kind = String(formData.get("kind") ?? "") as OrganizationKind;
  const website = String(formData.get("website") ?? "").trim();
  const nif = String(formData.get("nif") ?? "").trim();
  const locale = formData.get("locale");

  if (!name) return { status: "error", error: "name" };
  if (!ORGANIZATION_KINDS.includes(kind)) return { status: "error", error: "kind" };
  if (website && !/^https:\/\/\S+\.\S+/.test(website)) return { status: "error", error: "website" };

  const supabase = await createClient();
  const { error } = await supabase.rpc("create_organization", {
    p_name: name,
    p_kind: kind,
    p_website: website || null,
    p_nif: nif || null,
  });
  if (error) {
    console.error("create_organization failed", { code: error.code, message: error.message });
    return { status: "error", error: "failed" };
  }

  redirect(localePath(locale, "/account"));
}

/** Admin decision. RLS + the status trigger reject non-admins regardless of the UI. */
export async function reviewOrganisation(formData: FormData) {
  const id = String(formData.get("id") ?? "");
  const decision = String(formData.get("decision") ?? "");
  if (!id || (decision !== "approved" && decision !== "rejected")) return;

  const supabase = await createClient();
  await supabase.from("organizations").update({ status: decision }).eq("id", id);
  revalidatePath("/[locale]/admin/organizations", "page");
}
