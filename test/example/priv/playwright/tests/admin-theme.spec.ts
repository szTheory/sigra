import AxeBuilder from "@axe-core/playwright";
import { test, expect, type Page } from "@playwright/test";
import { TEST_PASSWORD } from "../helpers/fixtures";

async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector("[data-phx-session].phx-connected", {
    state: "attached",
  });
}

async function registerUser(page: Page, email: string, password: string) {
  await page.goto("/users/register");
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page
    .locator('form:has(input[name="user[password]"])')
    .first()
    .evaluate((form) => {
      (form as HTMLFormElement).requestSubmit();
    });
  await expect(page).not.toHaveURL(/\/users\/register/);
}

async function logInAsPlatformAdmin(page: Page) {
  const email = `platform-admin+theme-${Date.now()}@example.test`;
  await registerUser(page, email, TEST_PASSWORD);
}

async function shellTheme(page: Page) {
  return page.locator(".sg-admin-shell").evaluate((el) => ({
    theme: el.getAttribute("data-theme"),
    preference: el.getAttribute("data-theme-preference"),
    colorScheme: getComputedStyle(el).colorScheme,
    background: getComputedStyle(el).backgroundColor,
    coreStroke: getComputedStyle(
      el.querySelector(".sg-brand-mark__core") as Element,
    ).stroke,
  }));
}

function rgbChannels(value: string): [number, number, number] {
  const channels = value
    .match(/[\d.]+/g)
    ?.slice(0, 3)
    .map(Number);
  if (!channels || channels.length < 3) {
    throw new Error(`Expected a CSS rgb color, got ${value}`);
  }

  const rgb = channels.some((channel) => channel > 1)
    ? channels
    : channels.map((channel) => channel * 255);

  return [rgb[0], rgb[1], rgb[2]];
}

function relativeLuminance([r, g, b]: [number, number, number]) {
  const [sr, sg, sb] = [r, g, b].map((channel) => {
    const value = channel / 255;
    return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });

  return 0.2126 * sr + 0.7152 * sg + 0.0722 * sb;
}

function contrastRatio(foreground: string, background: string) {
  const foregroundLuminance = relativeLuminance(rgbChannels(foreground));
  const backgroundLuminance = relativeLuminance(rgbChannels(background));
  const lighter = Math.max(foregroundLuminance, backgroundLuminance);
  const darker = Math.min(foregroundLuminance, backgroundLuminance);

  return (lighter + 0.05) / (darker + 0.05);
}

test.describe("admin theme switch", () => {
  test("renders stable topbar controls and overview notice before deferred app JS", async ({
    page,
  }) => {
    await logInAsPlatformAdmin(page);
    await page.addInitScript(() => {
      window.localStorage.setItem("sigra.admin.theme", "dark");
    });
    await page.route("**/assets/js/app.js*", (route) => route.abort());

    await page.goto("/admin");

    await expect(page.locator("html")).toHaveAttribute(
      "data-sg-admin-js",
      "true",
    );
    await expect(page.locator("html")).toHaveAttribute(
      "data-sg-admin-theme",
      "dark",
    );
    await expect(page.locator("html")).toHaveAttribute(
      "data-sg-admin-theme-preference",
      "dark",
    );
    await expect(page.getByRole("radiogroup", { name: "Theme" })).toBeVisible();
    await expect(
      page.getByRole("button", { name: "Open command palette" }),
    ).toBeVisible();

    const notice = page.locator(".sg-notice");
    await expect(notice).toHaveCount(1);
    await expect(notice).toBeVisible();
    await expect(notice).toContainText(/accounts need review|All clear/);
    await expect(notice).not.toHaveAttribute("role", /.+/);
    await expect(notice).not.toHaveAttribute("data-phx-id", /.+/);
  });

  test("persists Light, Dark, and System without global DaisyUI theme state", async ({
    page,
  }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin");
    await waitForLiveViewReady(page);

    const notice = page.locator(".sg-notice");
    await expect(notice).toHaveCount(1);
    await expect(notice).toContainText(/accounts need review|All clear/);
    await expect(notice).not.toHaveAttribute("role", /.+/);

    const switcher = page.getByRole("radiogroup", { name: "Theme" });
    await expect(switcher).toBeVisible();
    await expect(page.getByRole("radio", { name: "System" })).toHaveAttribute(
      "aria-checked",
      "true",
    );

    await page.getByRole("radio", { name: "Dark" }).click();
    await expect(page.locator(".sg-admin-shell")).toHaveAttribute(
      "data-theme",
      "dark",
    );
    await expect(page.locator(".sg-admin-shell")).toHaveAttribute(
      "data-theme-preference",
      "dark",
    );
    await expect(page.getByRole("radio", { name: "Dark" })).toHaveAttribute(
      "aria-checked",
      "true",
    );
    await expect(page.locator("html")).toHaveAttribute(
      "data-sg-admin-theme",
      "dark",
    );
    await expect(page.locator("html")).not.toHaveAttribute("data-theme", /.+/);
    expect(
      await page.evaluate(() => localStorage.getItem("sigra.admin.theme")),
    ).toBe("dark");
    const dark = await shellTheme(page);
    expect(dark.colorScheme).toContain("dark");
    expect(dark.coreStroke).toBe("rgb(244, 241, 235)");

    await page.goto("/admin/users");
    await waitForLiveViewReady(page);
    await expect(page.locator(".sg-admin-shell")).toHaveAttribute(
      "data-theme",
      "dark",
    );
    expect((await shellTheme(page)).colorScheme).toContain("dark");

    await page.getByRole("radio", { name: "Light" }).click();
    await expect(page.locator(".sg-admin-shell")).toHaveAttribute(
      "data-theme",
      "light",
    );
    await expect(page.locator("html")).toHaveAttribute(
      "data-sg-admin-theme",
      "light",
    );
    expect(
      await page.evaluate(() => localStorage.getItem("sigra.admin.theme")),
    ).toBe("light");
    const light = await shellTheme(page);
    expect(light.colorScheme).toContain("light");
    expect(light.coreStroke).toBe("rgb(154, 52, 18)");

    await page.getByRole("radio", { name: "System" }).click();
    await expect(page.locator(".sg-admin-shell")).not.toHaveAttribute(
      "data-theme",
      /.+/,
    );
    await expect(page.locator(".sg-admin-shell")).toHaveAttribute(
      "data-theme-preference",
      "system",
    );
    await expect(page.locator("html")).not.toHaveAttribute(
      "data-sg-admin-theme",
      /.+/,
    );
    expect(
      await page.evaluate(() => localStorage.getItem("sigra.admin.theme")),
    ).toBeNull();

    const { violations } = await new AxeBuilder({ page })
      .withTags(["wcag2a", "wcag2aa"])
      .analyze();
    expect(violations).toHaveLength(0);
  });

  test("keeps primary button hover contrast readable in dark mode", async ({
    page,
  }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin/users");
    await waitForLiveViewReady(page);

    await page.getByRole("radio", { name: "Dark" }).click();

    const search = page.getByRole("button", { name: "Search" });
    await search.hover();

    const styles = await search.evaluate((el) => {
      const computed = window.getComputedStyle(el);
      return {
        background: computed.backgroundColor,
        color: computed.color,
      };
    });

    expect(
      contrastRatio(styles.color, styles.background),
    ).toBeGreaterThanOrEqual(4.5);
  });

  test("auth branding theme picker updates login and email previews", async ({
    page,
  }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin/auth-branding");
    await waitForLiveViewReady(page);

    const themeSelect = page.locator(
      '#auth-branding-form select[name="branding[theme]"]',
    );
    const loginPreview = page.locator(
      '[data-testid="admin-auth-preview"] .sigra-auth',
    );
    const loginPanel = loginPreview.locator(".sigra-auth__panel");
    const emailPreview = page.locator(
      '[data-testid="admin-email-preview-surface"]',
    );

    await themeSelect.selectOption("light");
    await expect(loginPreview).toHaveAttribute("data-theme", "light");
    await expect(emailPreview).toHaveAttribute("data-theme", "light");

    const readPreviewStyles = async () =>
      loginPanel.evaluate((panel) => {
        const auth = panel.closest(".sigra-auth") as HTMLElement;
        const email = document.querySelector(
          '[data-testid="admin-email-preview-surface"]',
        ) as HTMLElement;
        const panelStyles = getComputedStyle(panel);

        return {
          panelBackground: panelStyles.backgroundColor,
          panelTransition: panelStyles.transitionProperty,
          authBgToken: getComputedStyle(auth)
            .getPropertyValue("--sigra-auth-bg")
            .trim(),
          emailBackground: getComputedStyle(email).backgroundColor,
          emailTransition: getComputedStyle(email).transitionProperty,
        };
      });

    const lightStyles = await readPreviewStyles();

    await themeSelect.selectOption("dark");
    await expect(loginPreview).toHaveAttribute("data-theme", "dark");
    await expect(emailPreview).toHaveAttribute("data-theme", "dark");

    await expect
      .poll(async () => (await readPreviewStyles()).authBgToken)
      .not.toBe(lightStyles.authBgToken);
    await expect
      .poll(async () => (await readPreviewStyles()).panelBackground)
      .not.toBe(lightStyles.panelBackground);
    await expect
      .poll(async () => (await readPreviewStyles()).emailBackground)
      .not.toBe(lightStyles.emailBackground);

    const darkStyles = await readPreviewStyles();

    expect(darkStyles.panelTransition).toContain("background");
    expect(darkStyles.emailTransition).toContain("background");
  });

  test("keyboard navigation uses radiogroup semantics", async ({ page }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin");
    await waitForLiveViewReady(page);

    const system = page.getByRole("radio", { name: "System" });
    await system.focus();
    await page.keyboard.press("ArrowLeft");
    await expect(page.getByRole("radio", { name: "Dark" })).toBeFocused();
    await expect(page.getByRole("radio", { name: "Dark" })).toHaveAttribute(
      "aria-checked",
      "true",
    );
    await page.keyboard.press("Home");
    await expect(page.getByRole("radio", { name: "Light" })).toBeFocused();
    await expect(page.getByRole("radio", { name: "Light" })).toHaveAttribute(
      "aria-checked",
      "true",
    );
    await page.keyboard.press("End");
    await expect(page.getByRole("radio", { name: "System" })).toBeFocused();
    await expect(page.getByRole("radio", { name: "System" })).toHaveAttribute(
      "aria-checked",
      "true",
    );
  });
});
