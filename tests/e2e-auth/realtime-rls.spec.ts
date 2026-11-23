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

/** Tries to join an organisation's private channel; returns what it received and whether it joined. */
async function listenToOrganisation(client: SupabaseClient, orgId: string) {
  const seen: unknown[] = [];
  await client.realtime.setAuth();
  const channel = client
    .channel(`organization:${orgId}`, { config: { private: true } })
    .on("broadcast", { event: "status" }, ({ payload }) => seen.push(payload));
  const joined = await new Promise<boolean>((resolve) => {
    channel.subscribe((status) => {
      if (status === "SUBSCRIBED") resolve(true);
      if (status === "CHANNEL_ERROR" || status === "TIMED_OUT" || status === "CLOSED") resolve(false);
    });
  });
  return { seen, channel, joined };
}

/** Any subscriber to postgres_changes on organizations (no filter) — must receive nothing. */
async function listenToTable(client: SupabaseClient) {
  const seen: unknown[] = [];
  await client.realtime.setAuth();
  const channel = client
    .channel(`table-${Math.random()}`)
    .on("postgres_changes", { event: "*", schema: "public", table: "organizations" }, (p) => seen.push(p));
  await new Promise<void>((resolve) => channel.subscribe(() => resolve()));
  return { seen, channel };
}

test("organisation status updates reach only that organisation's members", async () => {
  const admin = createClient(url, serviceKey, { auth: { persistSession: false } });
  const a = await partnerWithOrg(admin, "a");
  const b = await partnerWithOrg(admin, "b");

  const aOwn = await listenToOrganisation(a.client, a.orgId);
  expect(aOwn.joined).toBe(true);
  // B tries to listen to A's (soon approved, hence public) organisation channel
  const bSpy = await listenToOrganisation(b.client, a.orgId);
  const bTable = await listenToTable(b.client);

  const { error } = await admin.from("organizations").update({ status: "approved" }).eq("id", a.orgId);
  expect(error).toBeNull();

  await expect.poll(() => aOwn.seen, { timeout: 15_000 }).toContainEqual({ id: a.orgId, status: "approved" });
  await new Promise((r) => setTimeout(r, 3000)); // give B every chance to (wrongly) receive it
  expect(bSpy.seen).toEqual([]);
  expect(bTable.seen).toEqual([]);

  for (const c of [aOwn, bSpy, bTable]) await (c === aOwn ? a : b).client.removeChannel(c.channel);
});
