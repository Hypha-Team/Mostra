import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { expect, test } from "@playwright/test";

// Realtime must respect RLS: a partner subscribed to ALL organization changes (no filter)
// still only receives its own organization's update. Runs in Node against the local Supabase.

const url = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const anonKey = (process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ?? process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY)!;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;

test.skip(!url || !anonKey || !serviceKey, "needs a local Supabase (CI › supabase job)");
test.describe.configure({ mode: "serial" });

const run = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
const password = `pw-${run}-Aa1!`;

async function partnerWithOrg(admin: SupabaseClient, who: string) {
  const email = `${who}.rt.${run}@mail.test`;
  const { error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { signup_as: "partner" },
  });
  expect(error).toBeNull();
  const client = createClient(url, anonKey, { auth: { persistSession: false } });
  const { error: signInError } = await client.auth.signInWithPassword({ email, password });
  expect(signInError).toBeNull();
  const { data: orgId, error: orgError } = await client.rpc("create_organization", {
    p_name: `Realtime ${who} ${run}`,
    p_kind: "gallery",
  });
  expect(orgError).toBeNull();
  return { client, orgId: orgId as string };
}

async function listenToAllOrganisations(client: SupabaseClient) {
  const seen: string[] = [];
  await client.realtime.setAuth();
  const channel = client.channel(`all-orgs-${Math.random()}`, {
    config: { postgres_changes_options: { wait: true } },
  });
  channel.on("postgres_changes", { event: "*", schema: "public", table: "organizations" }, (payload) => {
    seen.push((payload.new as { id?: string })?.id ?? "?");
  });
  await new Promise<void>((resolve, reject) => {
    channel.subscribe((status, err) => {
      if (status === "SUBSCRIBED") resolve();
      if (status === "CHANNEL_ERROR" || status === "TIMED_OUT") reject(err ?? new Error(status));
    });
  });
  return { seen, channel };
}

test("a partner only receives realtime updates for its own organization", async () => {
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const a = await partnerWithOrg(admin, "a");
  const b = await partnerWithOrg(admin, "b");

  const listenA = await listenToAllOrganisations(a.client);
  const listenB = await listenToAllOrganisations(b.client);

  const { error } = await admin.from("organizations").update({ status: "approved" }).eq("id", a.orgId);
  expect(error).toBeNull();

  await expect.poll(() => listenA.seen, { timeout: 15_000 }).toContain(a.orgId);
  // give B every chance to (wrongly) receive it
  await new Promise((r) => setTimeout(r, 3000));
  expect(listenB.seen).not.toContain(a.orgId);
  expect(listenB.seen).toEqual([]);

  await a.client.removeChannel(listenA.channel);
  await b.client.removeChannel(listenB.channel);
});
