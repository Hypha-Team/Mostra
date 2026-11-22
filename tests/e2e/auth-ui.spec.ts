import { expect, test } from "./fixtures";

// These run without a Supabase backend (CI "checks" job). The full magic-link flows
// live in tests/e2e-auth and run against a local Supabase.

const MAGENTA = "rgb(212, 43, 135)";

async function magentaCount(page: import("@playwright/test").Page) {
  return page.evaluate((magenta) => {
    return [...document.querySelectorAll<HTMLElement>("a, button")].filter(
      (el) => getComputedStyle(el).backgroundColor === magenta && el.offsetParent !== null,
    ).length;
  }, MAGENTA);
}

test("welcome: one magenta action, organisation entry, powered by", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByTestId("enter-university")).toHaveText("entrar com o email da universidade");
  await expect(page.getByTestId("enter-organisation")).toHaveText("sou uma galeria, estúdio ou organização");
  expect(await magentaCount(page)).toBe(1);
  await expect(page.getByAltText("HYPHA")).toBeVisible();
  await page.getByTestId("enter-university").click();
  await expect(page).toHaveURL(/\/sign-in$/);
  await expect(page.getByRole("heading", { level: 1, name: "entrar" })).toBeVisible();
});

test("sign-in: labelled fields, consent required, email validated", async ({ page }) => {
  await page.goto("/en/sign-in");
  expect(await magentaCount(page)).toBe(1);
  const email = page.getByLabel("email");
  await expect(email).toBeVisible();

  await email.fill("not-an-email");
  await page.getByLabel(/privacy notice/).check();
  await page.getByRole("button", { name: "send sign-in link" }).click();
  await expect(page.getByTestId("form-error")).toHaveText("Enter a valid email.");

  await page.getByLabel("email").fill("someone@example.com");
  await page.getByLabel(/privacy notice/).uncheck();
  await page.getByRole("button", { name: "send sign-in link" }).click();
  await expect(page.getByTestId("form-error")).toHaveText("To continue, accept the privacy notice.");
});

test("organisation sign-in asks for a name and links back", async ({ page }) => {
  await page.goto("/sign-in/organisation");
  await expect(page.getByRole("heading", { level: 1, name: "entrar como organização" })).toBeVisible();
  await expect(page.getByLabel("o seu nome")).toBeVisible();
  await page.getByRole("link", { name: /É estudante ou docente/ }).click();
  await expect(page).toHaveURL(/\/sign-in$/);
});

test("expired link message", async ({ page }) => {
  await page.goto("/sign-in?error=link");
  await expect(page.getByTestId("link-error")).toHaveText("O link expirou ou já foi usado. Peça um novo.");
});

test("signed-out visitors are sent to sign-in", async ({ page }) => {
  await page.goto("/account");
  await expect(page).toHaveURL(/\/sign-in$/);
  await page.goto("/en/admin/organizations");
  await expect(page).toHaveURL(/\/en\/sign-in$/);
  await page.goto("/account/organisation");
  await expect(page).toHaveURL(/\/sign-in\/organisation$/);
});

test("privacy notice is reachable from the consent label", async ({ page }) => {
  await page.goto("/sign-in");
  await page.getByRole("link", { name: "aviso de privacidade" }).click();
  await expect(page.getByRole("heading", { level: 1, name: "aviso de privacidade" })).toBeVisible();
});

test("auth callback without a code goes back to sign-in", async ({ page }) => {
  await page.goto("/api/auth/confirm?next=/en/account");
  await expect(page).toHaveURL(/\/en\/sign-in\?error=link$/);
});

test("auth callback refuses open redirects", async ({ request }) => {
  const res = await request.get("/api/auth/confirm?next=//evil.example", { maxRedirects: 0 });
  expect(res.status()).toBe(307);
  expect(new URL(res.headers()["location"]).host).not.toBe("evil.example");
});
