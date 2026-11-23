import { expect, test, type Page } from "@playwright/test";
import { magicLinkFor, mailCount, waitForMailContaining } from "./mail";

// Requires (set up by CI): university domains alunos.test / docentes.test and admin@admin.test
// in private.admin_emails on the local Supabase. See .github/workflows/ci.yml › supabase.

const run = `${Date.now()}${Math.floor(Math.random() * 1000)}`;

async function signIn(page: Page, path: string, email: string, name?: string) {
  await page.goto(path);
  if (name) await page.getByLabel(/o seu nome|your name/).fill(name);
  await page.getByLabel(/^email$/).fill(email);
  await page.getByRole("checkbox").check();
  await page.getByRole("button", { name: /enviar link de acesso|send sign-in link/ }).click();
  await expect(page.getByTestId("link-sent")).toBeVisible();
  await page.goto(await magicLinkFor(email));
}

test("student signs in with the university email and is verified", async ({ page }, info) => {
  const email = `ana.${run}.${info.project.name}@alunos.test`;
  await signIn(page, "/sign-in", email);
  await expect(page).toHaveURL(/\/account$/);
  await expect(page.getByTestId("account-email")).toHaveText(email);
  await expect(page.getByTestId("account-roles").locator('[data-role="student"]')).toHaveText("estudante");
  await expect(page.getByTestId("verified")).toBeVisible();

  // not an admin
  await page.goto("/admin/organizations");
  await expect(page.getByRole("heading", { name: "página não encontrada" })).toBeVisible();

  // sign out
  await page.goto("/account");
  await page.getByRole("button", { name: "sair" }).click();
  await expect(page).toHaveURL(/\/$/);
  await page.goto("/account");
  await expect(page).toHaveURL(/\/sign-in$/);
});

test("English sign-in lands on the English account page", async ({ page }, info) => {
  const email = `bea.${run}.${info.project.name}@docentes.test`;
  await signIn(page, "/en/sign-in", email);
  await expect(page).toHaveURL(/\/en\/account$/);
  await expect(page.getByTestId("account-roles").locator('[data-role="professor"]')).toHaveText("professor");
});

test("a non-university email is refused on the student path and gets no email", async ({ page }, info) => {
  const email = `someone.${run}.${info.project.name}@mail.test`;
  await page.goto("/sign-in");
  await page.getByLabel(/^email$/).fill(email);
  await page.getByRole("checkbox").check();
  await page.getByRole("button", { name: "enviar link de acesso" }).click();
  await expect(page.getByTestId("form-error")).toContainText("não pertence a um domínio da universidade");
  expect(await mailCount(email)).toBe(0);
});

/** Holds server-action POSTs to a page so the loading state is observable. */
async function slowActions(page: Page, ms = 1200) {
  await page.route(
    (url) => url.pathname.includes("/admin/organizations"),
    async (route) => {
      if (route.request().method() === "POST") await new Promise((r) => setTimeout(r, ms));
      await route.continue();
    },
  );
}

/** Marks the document so we can prove a later check happened without a reload. */
async function markNoReload(page: Page) {
  await page.evaluate(() => ((window as unknown as { __noReload: boolean }).__noReload = true));
}
async function expectNoReload(page: Page) {
  expect(await page.evaluate(() => (window as unknown as { __noReload?: boolean }).__noReload)).toBe(true);
}

async function registerOrganisation(page: Page, email: string, orgName: string) {
  await signIn(page, "/sign-in/organisation", email, "Rita");
  await expect(page).toHaveURL(/\/account$/);
  await expect(page.getByTestId("account-roles").locator('[data-role="partner"]')).toBeVisible();
  await page.getByRole("link", { name: "registar organização" }).click();
  await page.getByLabel("nome da organização").fill(orgName);
  await page.getByLabel("tipo").selectOption("gallery");
  await page.getByRole("button", { name: "enviar para aprovação" }).click();
  await page.waitForURL(/\/account$/).catch(async () => {
    const shown = await page.getByTestId("form-error").textContent({ timeout: 1000 }).catch(() => null);
    throw new Error(`organisation form did not submit: ${shown ?? "no error shown"}`);
  });
  await expect(page.getByTestId("organisation-status")).toHaveAttribute("data-status", "pending");
}

test("organisation form keeps what was typed after a validation error", async ({ page }, info) => {
  await signIn(page, "/sign-in/organisation", `form.${run}.${info.project.name}@mail.test`, "Rita");
  await page.getByRole("link", { name: "registar organização" }).click();
  await page.getByLabel("nome da organização").fill("Galeria Campos");
  await page.getByLabel("tipo").selectOption("studio");
  await page.getByLabel("site (opcional)").fill("ftp://nope");
  await page.getByRole("button", { name: "enviar para aprovação" }).click();
  await expect(page.getByTestId("form-error")).toHaveText("O site deve começar por https://");
  await expect(page.getByLabel("nome da organização")).toHaveValue("Galeria Campos");
  await expect(page.getByLabel("tipo")).toHaveValue("studio");
});

test("approval: instant feedback for the admin, live update and email for the gallery", async ({ browser }, info) => {
  const partnerEmail = `galeria.${run}.${info.project.name}@mail.test`;
  const orgName = `Galeria E2E ${run} ${info.project.name}`;

  // The gallery waits on its account page.
  const partner = await (await browser.newContext()).newPage();
  await registerOrganisation(partner, partnerEmail, orgName);
  await expect(partner.getByTestId("verified")).toHaveCount(0);
  await expect(partner.getByTestId("not-verified")).toHaveCount(0);
  await expect(partner.getByTestId("org-live")).toHaveAttribute("data-realtime", "subscribed", { timeout: 20_000 });
  await markNoReload(partner);

  await partner.goto("/admin/organizations");
  await expect(partner.getByRole("heading", { name: "página não encontrada" })).toBeVisible();
  await partner.goto("/account");
  await expect(partner.getByTestId("org-live")).toHaveAttribute("data-realtime", "subscribed", { timeout: 20_000 });
  await markNoReload(partner);

  // The admin approves.
  const admin = await (await browser.newContext()).newPage();
  await signIn(admin, "/sign-in", "admin@admin.test");
  await expect(admin.getByTestId("account-roles").locator('[data-role="admin"]')).toBeVisible();
  await admin.getByRole("link", { name: "aprovar organizações" }).click();
  await markNoReload(admin);
  await slowActions(admin);
  const row = admin.getByTestId("pending-organisation").filter({ hasText: orgName });
  await row.getByRole("button", { name: "aprovar" }).click();

  // 1 · immediate feedback, then the result without reloading
  await expect(row.getByRole("button", { name: "a aprovar…" })).toBeDisabled();
  await expect(row.getByRole("button", { name: "recusar" })).toBeDisabled();
  await expect(admin.getByTestId("pending-organisation").filter({ hasText: orgName })).toHaveCount(0);
  await expect(admin.getByTestId("decided-organisation").filter({ hasText: orgName })).toContainText("aprovada");
  await expectNoReload(admin);

  // 2 · the gallery's page updates by itself, in real time
  await expect(partner.getByTestId("organisation-status")).toHaveAttribute("data-status", "approved", {
    timeout: 15_000,
  });
  await expect(partner.getByTestId("verified")).toBeVisible();
  await expect(partner.getByTestId("org-live")).toHaveAttribute("data-realtime-events", "1");
  await expectNoReload(partner);

  // 2 · and gets an email
  await waitForMailContaining(partnerEmail, "foi aprovada pela Faculdade de Belas-Artes");
});

test("rejection: instant feedback and the organisation leaves the pending list", async ({ browser }, info) => {
  const orgName = `Estudio E2E ${run} ${info.project.name}`;
  const partner = await (await browser.newContext()).newPage();
  await registerOrganisation(partner, `estudio.${run}.${info.project.name}@mail.test`, orgName);

  const admin = await (await browser.newContext()).newPage();
  await signIn(admin, "/sign-in", "admin@admin.test");
  await admin.goto("/admin/organizations");
  await markNoReload(admin);
  await slowActions(admin);
  const row = admin.getByTestId("pending-organisation").filter({ hasText: orgName });
  await row.getByRole("button", { name: "recusar" }).click();
  await expect(row.getByRole("button", { name: "a recusar…" })).toBeDisabled();
  await expect(admin.getByTestId("pending-organisation").filter({ hasText: orgName })).toHaveCount(0);
  await expect(admin.getByTestId("decided-organisation").filter({ hasText: orgName })).toContainText("recusada");
  await expectNoReload(admin);

  await expect(partner.getByTestId("organisation-status")).toHaveAttribute("data-status", "rejected", {
    timeout: 15_000,
  });
});
