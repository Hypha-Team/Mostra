import { expect, test } from "./fixtures";

test.describe("i18n", () => {
  test("Portuguese is the default at /", async ({ page }) => {
    await page.goto("/");
    await expect(page).toHaveURL(/\/$/);
    await expect(page.locator("html")).toHaveAttribute("lang", "pt");
    await expect(page.getByText("Os trabalhos dos estudantes de Belas-Artes")).toBeVisible();
  });

  test("English lives at /en", async ({ page }) => {
    await page.goto("/en");
    await expect(page.locator("html")).toHaveAttribute("lang", "en");
    await expect(page.getByText("The work of Belas-Artes students")).toBeVisible();
    await expect(page.getByTestId("enter-university")).toHaveText("enter with your university email");
  });

  test("/pt redirects to /", async ({ page }) => {
    await page.goto("/pt");
    await expect(page).toHaveURL(/^[^?]*\/$/);
    await expect(page.locator("html")).toHaveAttribute("lang", "pt");
  });

  test("language switcher toggles pt ↔ en", async ({ page }) => {
    await page.goto("/");
    await page.getByRole("link", { name: "English" }).click();
    await expect(page).toHaveURL(/\/en$/);
    await expect(page.locator("html")).toHaveAttribute("lang", "en");
    await page.getByRole("link", { name: "Português" }).click();
    await expect(page.locator("html")).toHaveAttribute("lang", "pt");
    await expect(page).toHaveURL(/\/$/);
  });

  test("an English browser still gets Portuguese at /", async ({ browser }) => {
    const context = await browser.newContext({ locale: "en-US" });
    const page = await context.newPage();
    await page.goto("/");
    await expect(page).toHaveURL(/^[^?]*\/$/);
    await expect(page.locator("html")).toHaveAttribute("lang", "pt");
    await context.close();
  });

  test("unknown route shows the localized 404", async ({ page, consoleErrors }) => {
    const res = await page.goto("/en/does-not-exist");
    // The browser logs the 404 document itself; that one is expected.
    consoleErrors.splice(0, consoleErrors.length, ...consoleErrors.filter((e) => !/404/.test(e)));
    expect(res?.status()).toBe(404);
    await expect(page.getByRole("heading", { name: "page not found" })).toBeVisible();
  });
});

test.describe("design system", () => {
  test("ground, ink and Instrument Sans are applied", async ({ page }) => {
    await page.goto("/");
    const body = page.locator("body");
    await expect(body).toHaveCSS("background-color", "rgb(250, 250, 248)");
    await expect(body).toHaveCSS("color", "rgb(17, 17, 17)");
    const family = await body.evaluate((el) => getComputedStyle(el).fontFamily);
    expect(family).toMatch(/Instrument Sans/i);
    await page.evaluate(() => document.fonts.ready);
    const loaded = await page.evaluate(() =>
      [...document.fonts].some((f) => /Instrument Sans/i.test(f.family) && f.status === "loaded"),
    );
    expect(loaded).toBe(true);
  });

  test("tokens page: magenta pill button, 44px min height", async ({ page }) => {
    await page.goto("/dev/tokens");
    const primary = page.getByTestId("btn-primary");
    await expect(primary).toHaveCSS("background-color", "rgb(212, 43, 135)");
    await expect(primary).toHaveCSS("color", "rgb(255, 255, 255)");
    const box = await primary.boundingBox();
    expect(box!.height).toBeGreaterThanOrEqual(44);
    await expect(page.getByTestId("section-title-sample")).toHaveCSS("font-weight", "600");
  });

  test("faculty and HYPHA logos load", async ({ page }) => {
    await page.goto("/");
    for (const img of await page.locator("img").all()) {
      await expect(img).toHaveAttribute("alt", /.+/);
      const ok = await img.evaluate((el: HTMLImageElement) => el.complete && el.naturalWidth > 0);
      expect(ok).toBe(true);
    }
  });

  test("no horizontal scroll", async ({ page }) => {
    for (const path of ["/", "/en", "/dev/tokens"]) {
      await page.goto(path);
      const overflow = await page.evaluate(
        () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
      );
      expect(overflow, path).toBeLessThanOrEqual(0);
    }
  });
});

test("health endpoint responds without leaking config", async ({ request }) => {
  const res = await request.get("/api/health");
  const body = await res.json();
  expect(body.app).toBe("ok");
  expect(["ok", "missing_env", "unreachable"]).toContain(body.supabase);
  expect(JSON.stringify(body)).not.toMatch(/supabase\.co|sb_|eyJ/);
});
