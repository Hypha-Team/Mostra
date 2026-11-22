import { expect, test, type Page } from "@playwright/test";
import { magicLinkFor, mailCount } from "./mail";

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

test("partner registers an organisation, admin approves it", async ({ browser }, info) => {
  const partnerEmail = `galeria.${run}.${info.project.name}@mail.test`;
  const orgName = `Galeria E2E ${run} ${info.project.name}`;

  const partner = await (await browser.newContext()).newPage();
  await signIn(partner, "/sign-in/organisation", partnerEmail, "Rita");
  await expect(partner).toHaveURL(/\/account$/);
  await expect(partner.getByTestId("account-roles").locator('[data-role="partner"]')).toBeVisible();
  await partner.getByRole("link", { name: "registar organização" }).click();

  await partner.getByLabel("nome da organização").fill(orgName);
  await partner.getByLabel("tipo").selectOption("gallery");
  await partner.getByLabel("site (opcional)").fill("ftp://nope");
  await partner.getByRole("button", { name: "enviar para aprovação" }).click();
  await expect(partner.getByTestId("form-error")).toHaveText("O site deve começar por https://");
  await partner.getByLabel("site (opcional)").fill("https://galeria.example");
  await partner.getByRole("button", { name: "enviar para aprovação" }).click();
  await expect(partner.getByTestId("form-error")).not.toHaveText("O site deve começar por https://");
  if (await partner.getByTestId("form-error").isVisible()) {
    throw new Error(`organisation form: ${await partner.getByTestId("form-error").textContent()}`);
  }

  await expect(partner).toHaveURL(/\/account$/);
  await expect(partner.getByTestId("organisation-status")).toHaveAttribute("data-status", "pending");
  await partner.goto("/admin/organizations");
  await expect(partner.getByRole("heading", { name: "página não encontrada" })).toBeVisible();

  const admin = await (await browser.newContext()).newPage();
  await signIn(admin, "/sign-in", "admin@admin.test");
  await expect(admin.getByTestId("account-roles").locator('[data-role="admin"]')).toBeVisible();
  await admin.getByRole("link", { name: "aprovar organizações" }).click();
  const row = admin.getByTestId("pending-organisation").filter({ hasText: orgName });
  await expect(row).toBeVisible();
  await row.getByRole("button", { name: "aprovar" }).click();
  await expect(admin.getByTestId("pending-organisation").filter({ hasText: orgName })).toHaveCount(0);
  await expect(admin.getByTestId("decided-organisation").filter({ hasText: orgName })).toContainText("aprovada");

  await partner.goto("/account");
  await expect(partner.getByTestId("organisation-status")).toHaveAttribute("data-status", "approved");
});
