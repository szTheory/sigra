import { test, expect, type Page, type TestInfo } from "@playwright/test";
// otplib: imported for future TOTP challenge integration. The example app
// currently uses MFA as step-up auth (not login challenge per golden-path.spec.ts:141),
// so authenticator.generate(DEMO_TOTP_B32) is not called at runtime. Retained
// for documentation and quick activation if mfa.check_fn is added to sigra_config().
// eslint-disable-next-line @typescript-eslint/no-unused-vars
import { authenticator } from "otplib";
import { adminUsersEmailLocator } from "../helpers/adminUsersIndex";

// Phase 143 Plan 2: evaluator-facing demo showcase spec.
//
// Exercises the nine seeded demo personas using structural assertions
// (data-testid and email-based locators — never display-name text) and
// captures four committed PNG baselines for evaluator-facing screenshots.
//
// Runs exclusively in the `demo-showcase-chromium` project partition;
// excluded from `chromium` and `mobile` via testIgnore in playwright.config.ts.
//
// PW-01: structural persona assertions in isolated partition.
// PW-02: four committed PNG baselines under tests/demo-showcase.spec.ts-snapshots/.

// Demo-only deterministic secret — matches Personas.demo_totp_secret/0
const DEMO_TOTP_B32 = "CSIL7ZDJ7RGXDGXRGIV3Q6CZIBOESTCW";
const DEMO_ADMIN_EMAIL = "admin@demo.vaultr.test";
const DEMO_ADMIN_PASSWORD = "DemoAdmin1!SecurePass";
const DEMO_ALICE_EMAIL = "alice@demo.vaultr.test";
const DEMO_ALICE_PASSWORD = "AliceDemoPass1!";
const EVALUATOR_FLOW_MAX_MS = 10 * 60 * 1000;
const DEMO_EMAILS = [
  "admin@demo.vaultr.test",
  "alice@demo.vaultr.test",
  "bob@demo.vaultr.test",
  "carol@demo.vaultr.test",
  "dave@demo.vaultr.test",
  "frank@demo.vaultr.test",
  "morgan@demo.vaultr.test",
  "pat@demo.vaultr.test",
  "grace@demo.vaultr.test",
];
const DEMO_LOCALS = [
  "admin",
  "alice",
  "bob",
  "carol",
  "dave",
  "frank",
  "morgan",
  "pat",
  "grace",
];

function rgbChannels(value: string): [number, number, number] {
  if (value.trim().startsWith("oklab(")) {
    const channels = value.match(/[-+]?(?:\d*\.)?\d+(?:e[-+]?\d+)?%?/gi);

    if (!channels || channels.length < 3) {
      throw new Error(`Could not parse CSS color: ${value}`);
    }

    const [l, a, b] = channels.slice(0, 3).map((channel, index) => {
      if (channel.endsWith("%")) {
        const percent = Number(channel.slice(0, -1)) / 100;
        return index === 0 ? percent : percent;
      }

      return Number(channel);
    });

    const lPrime = l + 0.3963377774 * a + 0.2158037573 * b;
    const mPrime = l - 0.1055613458 * a - 0.0638541728 * b;
    const sPrime = l - 0.0894841775 * a - 1.291485548 * b;

    const lCubed = lPrime ** 3;
    const mCubed = mPrime ** 3;
    const sCubed = sPrime ** 3;

    const linear = [
      4.0767426289 * lCubed - 3.3075493988 * mCubed + 0.2305761934 * sCubed,
      -1.2684394339 * lCubed + 2.6095177195 * mCubed - 0.3407375479 * sCubed,
      -0.0041889335 * lCubed - 0.7022194941 * mCubed + 1.7047037238 * sCubed,
    ];

    return linear.map((channel) => {
      const srgb =
        channel <= 0.0031308
          ? 12.92 * channel
          : 1.055 * Math.pow(channel, 1 / 2.4) - 0.055;

      return Math.min(255, Math.max(0, srgb * 255));
    }) as [number, number, number];
  }

  const channels = value
    .match(/[-+]?(?:\d*\.)?\d+(?:e[-+]?\d+)?/gi)
    ?.slice(0, 3)
    .map(Number);

  if (!channels || channels.length < 3) {
    throw new Error(`Could not parse CSS color: ${value}`);
  }

  const rgb = channels.some((channel) => channel > 1)
    ? channels
    : channels.map((channel) => channel * 255);

  return [rgb[0], rgb[1], rgb[2]];
}

function relativeLuminance(value: string) {
  const [red, green, blue] = rgbChannels(value).map((channel) => {
    const normalized = channel / 255;
    return normalized <= 0.03928
      ? normalized / 12.92
      : Math.pow((normalized + 0.055) / 1.055, 2.4);
  });

  return red * 0.2126 + green * 0.7152 + blue * 0.0722;
}

function contrastRatio(foreground: string, background: string) {
  const lighter = Math.max(
    relativeLuminance(foreground),
    relativeLuminance(background),
  );
  const darker = Math.min(
    relativeLuminance(foreground),
    relativeLuminance(background),
  );

  return (lighter + 0.05) / (darker + 0.05);
}

async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector("[data-phx-session].phx-connected", {
    state: "attached",
  });
}

/**
 * CI-aware screenshot baseline comparison for the demo showcase lane.
 * No axe assertions — this lane is PW-02 evaluator screenshots, not a11y gate.
 * Tolerances mirror the admin-checkpoints pattern (D-08):
 *   - CI: maxDiffPixels 200_000 / maxDiffPixelRatio 0.22
 *   - Local: maxDiffPixels 30_000 / maxDiffPixelRatio 0.06
 */
async function assertDemoScreenshot(
  page: Page,
  _testInfo: TestInfo,
  slug: string,
) {
  const ci = process.env.CI === "true";
  await expect(page).toHaveScreenshot(`${slug}.png`, {
    fullPage: false,
    maxDiffPixels: ci ? 200_000 : 30_000,
    maxDiffPixelRatio: ci ? 0.22 : 0.06,
  });
}

/**
 * Log in as the demo admin persona.
 *
 * The example app's sigra_config() does not set mfa.check_fn, so the login
 * flow creates a :standard session (not :mfa_pending), regardless of the
 * user's TOTP enrollment state. The admin lands directly at "/" on successful
 * login — no MFA challenge redirect.
 *
 * The DEMO_TOTP_B32 constant is declared above for documentation purposes
 * (it is the correct base32 encoding of Personas.demo_totp_secret/0) and
 * is available if a future change adds mfa.check_fn to the example app's
 * sigra_config, at which point the loginDemoAdmin function would need to
 * complete the TOTP challenge by clicking button[phx-click="show_totp"]
 * and filling #mfa_totp_code with authenticator.generate(DEMO_TOTP_B32).
 *
 * Reference: golden-path.spec.ts:141 — "the example app uses MFA as step-up
 * auth (sudo mode), not as a login challenge."
 *
 * Sequence:
 *   1. Navigate to /users/log_in — a plain controller page (not a LiveView)
 *   2. Fill #login_form (password form) — multiple forms exist on the page
 *   3. Submit — redirects to "/" with :standard session
 *   4. Wait for redirect away from /users/log_in
 */
async function loginDemoUser(page: Page, email: string, password: string) {
  // /users/log_in is a plain controller page (not a LiveView) — do NOT call
  // waitForLiveViewReady here. Fill the form directly and submit.
  await page.goto("/users/log_in");
  // The login page has multiple forms (passkey, magic link, password).
  // Scope fills to #login_form to target the password form specifically.
  await page.fill('#login_form input[name="user[email]"]', email);
  await page.fill('#login_form input[name="user[password]"]', password);
  await page.click('#login_form button:has-text("Log in")');
  // No MFA challenge — example app creates a :standard session without check_fn.
  await expect(page).not.toHaveURL(/\/users\/log_in/);
}

async function loginDemoAdmin(page: Page) {
  await loginDemoUser(page, DEMO_ADMIN_EMAIL, DEMO_ADMIN_PASSWORD);
}

test.describe("demo-showcase", () => {
  test("the real login is locked to Vaultr — server-rendered, ignores the brand cookie", async ({
    browser,
    baseURL,
  }) => {
    const resolvedBaseURL =
      baseURL ?? process.env.SIGRA_EXAMPLE_URL ?? "http://localhost:4000";

    // The homepage brand-lab preview can set the sigra_demo_brand cookie, but the
    // real /users/log_in is the Vaultr app's own auth surface (plain Vaultr palette
    // + OS light/dark, like the homepage) and must stay Vaultr regardless — even on
    // first paint, before demo JS runs. app.js is blocked to prove the server render.
    const assertVaultrLogin = async (
      brandCookie: string | null,
      themeCookie: string | null = null,
    ) => {
      const context = await browser.newContext({
        baseURL: resolvedBaseURL,
        colorScheme: "dark",
      });

      try {
        const cookies = [];
        if (brandCookie)
          cookies.push({
            name: "sigra_demo_brand",
            value: brandCookie,
            url: resolvedBaseURL,
            sameSite: "Lax" as const,
          });
        if (themeCookie)
          cookies.push({
            name: "sigra_demo_theme",
            value: themeCookie,
            url: resolvedBaseURL,
            sameSite: "Lax" as const,
          });
        if (cookies.length) await context.addCookies(cookies);

        const page = await context.newPage();
        await page.route("**/assets/js/app.js*", (route) => route.abort());
        await page.goto("/users/log_in");

        const login = page.locator('[data-testid="vaultr-login"]');
        // Always Vaultr, never another brand, with no demo-brand switcher hooks.
        await expect(login).toContainText("Log in to Vaultr");
        await expect(login).not.toContainText("Night Ops");
        await expect(login).not.toContainText("Meridian");
        await expect(login.locator("img.vt-brand__mark")).toHaveAttribute(
          "src",
          "/images/vaultr-mark.svg",
        );
        const hasBrandHook = await login.evaluate((el) =>
          [...el.attributes].some((a) => a.name.startsWith("data-demo-brand")),
        );
        expect(hasBrandHook).toBe(false);

        // Brand-agnostic cascade check: the auth surface's --vt-color-* tokens (the
        // global Vaultr palette, dark under this dark context) reach its controls —
        // the login button uses --vt-color-primary / --vt-color-on-primary and the
        // remember toggle uses --vt-color-panel.
        const probe = async (selector: string) =>
          login.locator(selector).evaluate((element) => {
            const styles = getComputedStyle(element);
            const auth = element.closest(".vt-auth");
            if (!auth) throw new Error("auth surface missing");
            const authStyles = getComputedStyle(auth);
            const span = document.createElement("span");
            const resolveColor = (value: string) => {
              span.style.color = value;
              document.body.appendChild(span);
              const color = getComputedStyle(span).color;
              span.remove();
              return color;
            };
            return {
              backgroundColor: styles.backgroundColor,
              color: styles.color,
              colorScheme: styles.colorScheme,
              expectedPrimary: resolveColor(
                authStyles.getPropertyValue("--vt-color-primary").trim(),
              ),
              expectedOnPrimary: resolveColor(
                authStyles.getPropertyValue("--vt-color-on-primary").trim(),
              ),
              expectedPanel: resolveColor(
                authStyles.getPropertyValue("--vt-color-panel").trim(),
              ),
            };
          });

        const button = await probe('#login_form button:has-text("Log in")');
        expect(button.backgroundColor).toBe(button.expectedPrimary);
        expect(button.color).toBe(button.expectedOnPrimary);
        // Follows the OS color-scheme (dark here) without an explicit data-theme.
        expect(button.colorScheme).toBe("dark");
      } finally {
        await context.close();
      }
    };

    await assertVaultrLogin(null);
    await assertVaultrLogin("meridian"); // brand cookie ignored
    await assertVaultrLogin("night-ops", "dark"); // brand + theme cookie ignored
  });

  test("home page orients evaluators before login", async ({ page }) => {
    await page.goto("/");

    await expect(
      page.locator('[data-testid="home-evaluator-doorway"]'),
    ).toBeVisible();
    await expect(
      page.getByText("Vaultr demo app · secured by Sigra"),
    ).toBeVisible();
    await expect(
      page.getByText("Evaluate Sigra inside a distinct customer app."),
    ).toBeVisible();

    // Vaultr mini-brand typography guard: the demo host app must render in its
    // OWN fonts — Fraunces (serif display/wordmark) + Inter (body) — and NEVER
    // the Sigra brand font (Space Grotesk). Without this, the word "Sigra" in the
    // hero copy renders in the Sigra logo typeface and looks confusable.
    const titleFont = await page
      .locator(".vt-title")
      .evaluate((el) => getComputedStyle(el).fontFamily);
    expect(titleFont).toContain("Fraunces");
    expect(titleFont).not.toContain("Space Grotesk");
    const bodyFont = await page
      .locator(".vt-subtitle")
      .first()
      .evaluate((el) => getComputedStyle(el).fontFamily);
    expect(bodyFont).toContain("Inter");
    expect(bodyFont).not.toContain("Space Grotesk");

    await expect(
      page.locator('[data-testid="home-domain-context"]'),
    ).toContainText("demo.vaultr.test");
    await expect(page.getByText("One login, two jobs.")).toBeVisible();
    await expect(
      page.getByText("admin@demo.vaultr.test").first(),
    ).toBeVisible();
    await expect(page.getByText("@demo.vaultr.test").first()).toBeVisible();
    const operatorPanel = page.locator(
      '[data-testid="home-shared-login-copy"]',
    );
    const operatorStyles = await operatorPanel.evaluate((element) => {
      const styles = getComputedStyle(element);
      const title = element.querySelector(".vt-panel__title");

      if (!title) {
        throw new Error("operator panel title missing");
      }

      return {
        backgroundColor: styles.backgroundColor,
        color: getComputedStyle(title).color,
      };
    });

    expect(
      contrastRatio(operatorStyles.color, operatorStyles.backgroundColor),
      "operator panel title should remain readable against its panel background",
    ).toBeGreaterThanOrEqual(4.5);
    const brandLab = page.locator('[data-testid="demo-brand-lab"]');
    const brandLabHeading = brandLab.getByRole("heading", {
      name: "Switch the auth brand",
    });
    const brandLabHeadingContrast = async () => {
      const styles = await brandLab.evaluate((element) => {
        const surfaceStyles = getComputedStyle(element);
        const title = element.querySelector(".vt-panel__title");

        if (!title) {
          throw new Error("brand lab title missing");
        }

        const probe = document.createElement("span");

        const resolveColor = (value: string) => {
          probe.style.color = value;
          document.body.appendChild(probe);
          const color = getComputedStyle(probe).color;
          probe.remove();

          return color;
        };

        const expectedColor = resolveColor(
          surfaceStyles.getPropertyValue("--vt-color-ink").trim(),
        );

        return {
          backgroundColor: resolveColor(
            surfaceStyles.getPropertyValue("--vt-color-panel").trim(),
          ),
          color: getComputedStyle(title).color,
          expectedColor,
        };
      });

      if (styles.color !== styles.expectedColor) {
        return 0;
      }

      return contrastRatio(styles.color, styles.backgroundColor);
    };

    await expect(brandLab).toBeVisible();
    const expectBrandControlsWithinBounds = async () => {
      const bounds = await brandLab.evaluate((element) => {
        const controls = element.querySelector(".vt-brand-controls");

        if (!controls) {
          throw new Error("brand controls missing");
        }

        const containerRect = element.getBoundingClientRect();
        const controlsRect = controls.getBoundingClientRect();

        return {
          containerLeft: containerRect.left,
          containerRight: containerRect.right,
          controlsLeft: controlsRect.left,
          controlsRight: controlsRect.right,
        };
      });

      expect(
        bounds.controlsLeft,
        "brand controls should not spill past the left edge",
      ).toBeGreaterThanOrEqual(bounds.containerLeft - 1);
      expect(
        bounds.controlsRight,
        "brand controls should not spill past the right edge",
      ).toBeLessThanOrEqual(bounds.containerRight + 1);
    };

    await expectBrandControlsWithinBounds();
    await page.setViewportSize({ width: 1024, height: 900 });
    await expectBrandControlsWithinBounds();
    await page.setViewportSize({ width: 390, height: 844 });
    await expectBrandControlsWithinBounds();
    await page.setViewportSize({ width: 1280, height: 900 });

    expect(
      await brandLabHeadingContrast(),
      "brand lab heading should remain readable against its panel background",
    ).toBeGreaterThanOrEqual(4.5);
    const emailAddressChipContrast = async () => {
      const styles = await page
        .locator(
          '[data-demo-email-preview] [data-demo-brand-text="email_from_address"]',
        )
        .evaluate((element) => {
          const chipStyles = getComputedStyle(element);
          const preview = element.closest("[data-demo-email-preview]");

          if (!preview) {
            throw new Error("email preview missing");
          }

          const previewStyles = getComputedStyle(preview);
          const probe = document.createElement("span");

          const resolveColor = (value: string) => {
            probe.style.color = value;
            document.body.appendChild(probe);
            const color = getComputedStyle(probe).color;
            probe.remove();

            return color;
          };

          const expectedColor = resolveColor(
            previewStyles.getPropertyValue("--sigra-auth-text").trim(),
          );

          return {
            backgroundColor: chipStyles.backgroundColor,
            color: chipStyles.color,
            expectedColor,
          };
        });

      if (styles.color !== styles.expectedColor) {
        return 0;
      }

      return contrastRatio(styles.color, styles.backgroundColor);
    };

    const brandSelect = page.getByLabel("Brand preset");
    const authPreview = page.locator("[data-demo-auth-preview]");

    // Brand-lab now DEFAULTS to Vaultr (matching the app), then previews others.
    await expect(brandSelect).toHaveValue("vaultr");
    await expect(brandLab.getByLabel("Light")).toBeChecked();
    await expect(authPreview).toHaveAttribute("data-theme", "light");
    await expect(brandLab).toContainText("Vaultr");
    await expect(
      brandLab.getByRole("heading", { name: "Log in to Vaultr" }),
    ).toBeVisible();
    await brandSelect.selectOption("meridian");
    await expect
      .poll(async () => {
        const cookie = (await page.context().cookies()).find(
          (candidate) => candidate.name === "sigra_demo_brand",
        );

        return cookie?.value;
      })
      .toBe("meridian");
    await expect(brandLab.getByLabel("System")).toBeChecked();
    await expect(authPreview).toHaveAttribute("data-theme", "system");
    await expect(brandLab).toContainText("Meridian Health");
    await expect(
      brandLab.getByRole("heading", { name: "Log in to Meridian Health" }),
    ).toBeVisible();
    await expect(
      page.locator(
        '[data-demo-email-preview] [data-demo-brand-text="email_from_address"]',
      ),
    ).toHaveText("care@meridian.test");
    await expect
      .poll(emailAddressChipContrast, {
        message:
          "Meridian email-address chip should remain readable against its chip background",
      })
      .toBeGreaterThanOrEqual(4.5);
    await brandLab.getByLabel("Dark").check();
    await expect
      .poll(async () => {
        const cookie = (await page.context().cookies()).find(
          (candidate) => candidate.name === "sigra_demo_theme",
        );

        return cookie?.value;
      })
      .toBe("dark");
    await expect(authPreview).toHaveAttribute("data-theme", "dark");
    await expect
      .poll(() =>
        authPreview.evaluate((element) =>
          getComputedStyle(element).getPropertyValue("--sigra-auth-bg").trim(),
        ),
      )
      .toBe("#071b14");
    await brandSelect.selectOption("rail-accent");
    await expect(brandLab.getByLabel("Dark")).toBeChecked();
    await expect(authPreview).toHaveAttribute("data-theme", "dark");
    await expect
      .poll(() =>
        authPreview.evaluate((element) =>
          getComputedStyle(element).getPropertyValue("--sigra-auth-bg").trim(),
        ),
      )
      .toBe("#171614");
    await expect(
      brandLab.locator("[data-demo-brand-logo]").first(),
    ).toHaveAttribute("src", "/images/rail-accent-mark-dark.svg");
    await brandSelect.selectOption("night-ops");
    await expect
      .poll(async () => {
        const cookie = (await page.context().cookies()).find(
          (candidate) => candidate.name === "sigra_demo_brand",
        );

        return cookie?.value;
      })
      .toBe("night-ops");
    await expect(brandLab).toContainText("Night Ops");
    await expect(
      brandLab.getByRole("heading", { name: "Log in to Night Ops" }),
    ).toBeVisible();
    await expect
      .poll(brandLabHeadingContrast, {
        message:
          "brand lab heading should remain readable after switching brands",
      })
      .toBeGreaterThanOrEqual(4.5);
    await expect
      .poll(() =>
        authPreview.evaluate((element) =>
          getComputedStyle(element).getPropertyValue("--sigra-auth-bg").trim(),
        ),
      )
      .toBe("#07171d");
    // KEY GUARD: the brand-lab wrote sigra_demo_brand=night-ops for its own preview
    // persistence — but the REAL login must ignore it and stay Vaultr. Switching the
    // homepage brand never re-skins the actual auth surface.
    await page.reload();
    await expect(page.getByLabel("Brand preset")).toHaveValue("night-ops");
    await page.goto("/users/log_in");
    const login = page.locator('[data-testid="vaultr-login"]');
    await expect(login).toContainText("Log in to Vaultr");
    await expect(login).toContainText("New to Vaultr?");
    await expect(login).not.toContainText("Night Ops");
    expect(await login.getAttribute("data-demo-brand-default")).toBeNull();
    await expect(login.locator("[data-demo-brand-logo]")).toHaveCount(0);
    await expect(login.locator("img.vt-brand__mark")).toHaveAttribute(
      "src",
      "/images/vaultr-mark.svg",
    );
    await expect(login.getByText("Secured by Sigra")).toHaveCount(0);
    await expect(login.getByText("Use your email and password")).toHaveCount(0);
    await page.emulateMedia({ colorScheme: "dark" });
    await page.goto("/users/log_in");
    const loginButton = page.locator('#login_form button:has-text("Log in")');
    const loginButtonBaseStyles = await loginButton.evaluate((element) => {
      const styles = getComputedStyle(element);

      return {
        backgroundColor: styles.backgroundColor,
        boxShadow: styles.boxShadow,
        color: styles.color,
        transform: styles.transform,
        transitionProperty: styles.transitionProperty,
      };
    });

    expect(loginButtonBaseStyles.transitionProperty).toContain("box-shadow");
    await loginButton.hover();
    await expect
      .poll(() =>
        loginButton.evaluate((element) => getComputedStyle(element).transform),
      )
      .not.toBe(loginButtonBaseStyles.transform);
    await expect
      .poll(() =>
        loginButton.evaluate((element) => getComputedStyle(element).boxShadow),
      )
      .not.toBe(loginButtonBaseStyles.boxShadow);
    const loginButtonHoverStyles = await loginButton.evaluate((element) => {
      const styles = getComputedStyle(element);

      return {
        backgroundColor: styles.backgroundColor,
        color: styles.color,
      };
    });

    expect(
      relativeLuminance(loginButtonHoverStyles.backgroundColor),
      "primary login hover should brighten subtly instead of darkening",
    ).toBeGreaterThan(relativeLuminance(loginButtonBaseStyles.backgroundColor));
    expect(
      contrastRatio(
        loginButtonHoverStyles.color,
        loginButtonHoverStyles.backgroundColor,
      ),
      "primary login hover text should stay readable",
    ).toBeGreaterThanOrEqual(4.5);

    await page.getByText("Email me a magic link").click();
    const magicLinkButton = page.getByRole("button", {
      name: "Send magic link",
    });
    await expect(magicLinkButton).toBeVisible();
    const magicLinkBaseStyles = await magicLinkButton.evaluate((element) => {
      const styles = getComputedStyle(element);

      return {
        backgroundColor: styles.backgroundColor,
        boxShadow: styles.boxShadow,
        transform: styles.transform,
      };
    });

    await magicLinkButton.hover();
    await expect
      .poll(() =>
        magicLinkButton.evaluate(
          (element) => getComputedStyle(element).backgroundColor,
        ),
      )
      .not.toBe(magicLinkBaseStyles.backgroundColor);
    await expect
      .poll(() =>
        magicLinkButton.evaluate(
          (element) => getComputedStyle(element).boxShadow,
        ),
      )
      .toBe("none");
    await expect
      .poll(() =>
        magicLinkButton.evaluate(
          (element) => getComputedStyle(element).transform,
        ),
      )
      .toBe(magicLinkBaseStyles.transform);

    const remember = page.getByLabel("Keep me signed in");
    await expect(remember).toBeVisible();
    await expect(remember).not.toBeChecked();
    const rememberUncheckedStyles = await remember.evaluate((element) => {
      const styles = getComputedStyle(element);
      const before = getComputedStyle(element, "::before");
      const after = getComputedStyle(element, "::after");
      const auth = element.closest(".vt-auth");

      if (!auth) {
        throw new Error("auth surface missing");
      }

      const authStyles = getComputedStyle(auth);
      const probe = document.createElement("span");

      const resolveColor = (value: string) => {
        probe.style.color = value;
        document.body.appendChild(probe);
        const color = getComputedStyle(probe).color;
        probe.remove();

        return color;
      };

      const expectedSurface = resolveColor(
        authStyles.getPropertyValue("--vt-color-panel").trim(),
      );
      const expectedAccent = resolveColor(
        authStyles.getPropertyValue("--vt-color-primary").trim(),
      );

      return {
        appearance: styles.appearance,
        backgroundColor: styles.backgroundColor,
        backgroundImage: styles.backgroundImage,
        borderColor: styles.borderColor,
        colorScheme: styles.colorScheme,
        expectedAccent,
        expectedSurface,
        beforeContent: before.content,
        beforeDisplay: before.display,
        afterOpacity: after.opacity,
      };
    });

    expect(rememberUncheckedStyles.appearance).toBe("none");
    expect(rememberUncheckedStyles.colorScheme).toBe("dark");
    expect(rememberUncheckedStyles.backgroundColor).toBe(
      rememberUncheckedStyles.expectedSurface,
    );
    expect(rememberUncheckedStyles.backgroundImage).toBe("none");
    expect(rememberUncheckedStyles.beforeContent).toBe("none");
    expect(rememberUncheckedStyles.beforeDisplay).toBe("none");
    expect(rememberUncheckedStyles.afterOpacity).toBe("0");

    await page.getByText("Keep me signed in").click();
    await expect(remember).toBeChecked();
    await expect
      .poll(() =>
        remember.evaluate(
          (element) => getComputedStyle(element, "::after").opacity,
        ),
      )
      .toBe("1");
    const rememberCheckedStyles = await remember.evaluate((element) => {
      const styles = getComputedStyle(element);
      const before = getComputedStyle(element, "::before");
      const after = getComputedStyle(element, "::after");
      const auth = element.closest(".vt-auth");

      if (!auth) {
        throw new Error("auth surface missing");
      }

      const authStyles = getComputedStyle(auth);
      const probe = document.createElement("span");

      const resolveColor = (value: string) => {
        probe.style.color = value;
        document.body.appendChild(probe);
        const color = getComputedStyle(probe).color;
        probe.remove();

        return color;
      };

      const expectedAccent = resolveColor(
        authStyles.getPropertyValue("--vt-color-primary").trim(),
      );
      const expectedOnAccent = resolveColor(
        authStyles.getPropertyValue("--vt-color-on-primary").trim(),
      );

      return {
        appearance: styles.appearance,
        backgroundColor: styles.backgroundColor,
        beforeContent: before.content,
        beforeDisplay: before.display,
        afterBackgroundColor: after.backgroundColor,
        afterOpacity: after.opacity,
        expectedAccent,
        expectedOnAccent,
      };
    });

    expect(rememberCheckedStyles.appearance).toBe("none");
    // FLAKE-01: exact rgb equality flakes per-channel (sub-pixel/color-resolve rounding on :checked paint).
    // The expectedAccent probe resolves --vt-color-primary in document.body context while the
    // checked background is computed inside .vt-auth — different cascade contexts produce a
    // systematic per-channel offset (up to ~6 units locally, 1-2 in CI). De-flake with ±10
    // per-channel tolerance using the in-file rgbChannels() parser (line 52).
    // NOTE: both operands derive from the same live --vt-color-primary token, so this is a
    // paint-fidelity check (the :checked background renders the primary token within rendering
    // tolerance), NOT a brand-identity check — it cannot detect a wrong-token swap since both
    // sides move together. Wide enough to survive env-specific rendering deltas without retries,
    // tight enough to catch a broken/dropped accent paint.
    const [br, bg, bb] = rgbChannels(rememberCheckedStyles.backgroundColor);
    const [er, eg, eb] = rgbChannels(rememberCheckedStyles.expectedAccent);
    expect(Math.abs(br - er)).toBeLessThanOrEqual(10);
    expect(Math.abs(bg - eg)).toBeLessThanOrEqual(10);
    expect(Math.abs(bb - eb)).toBeLessThanOrEqual(10);
    expect(rememberCheckedStyles.beforeContent).toBe("none");
    expect(rememberCheckedStyles.beforeDisplay).toBe("none");
    expect(rememberCheckedStyles.afterBackgroundColor).toBe(
      rememberCheckedStyles.expectedOnAccent,
    );
    expect(rememberCheckedStyles.afterOpacity).toBe("1");
    await page.goto("/");
    await expect(
      page.locator('[data-testid="home-stat-personas"]'),
    ).toContainText("9");
    await expect(
      page.locator('[data-testid="home-featured-personas"]'),
    ).toContainText("morgan@demo.vaultr.test");
    await expect(
      page.getByRole("link", { name: "Open Sigra Admin" }),
    ).toHaveAttribute("href", "/admin");
  });

  test("documented evaluator path reaches authenticated flow within ten minutes", async ({
    page,
  }) => {
    const startedAt = Date.now();

    await page.goto("/demo/credentials");
    await waitForLiveViewReady(page);

    await expect(
      page.locator('[data-testid="demo-persona-row-alice"]'),
    ).toBeVisible();
    await expect(page.getByText(DEMO_ALICE_EMAIL)).toBeVisible();

    await loginDemoUser(page, DEMO_ALICE_EMAIL, DEMO_ALICE_PASSWORD);

    await page.goto("/users/sessions");
    await waitForLiveViewReady(page);
    await expect(
      page.getByText(/active|just now|current/i).first(),
    ).toBeVisible();

    const elapsedMs = Date.now() - startedAt;
    expect(
      elapsedMs,
      "documented evaluator path should reach an authenticated auth surface within 10 minutes",
    ).toBeLessThanOrEqual(EVALUATOR_FLOW_MAX_MS);
  });

  test("demo personas structural assertions and evaluator screenshots", async ({
    page,
  }, testInfo) => {
    // ──────────────────────────────────────────────────────────────────
    // Step 1: /demo/credentials — assert all 9 persona rows by data-testid
    // ──────────────────────────────────────────────────────────────────
    await page.goto("/demo/credentials");
    await waitForLiveViewReady(page);

    for (const local of DEMO_LOCALS) {
      await expect(
        page.locator(`[data-testid="demo-persona-row-${local}"]`),
      ).toBeVisible();
    }

    await assertDemoScreenshot(page, testInfo, "demo-credentials");

    // ──────────────────────────────────────────────────────────────────
    // Step 2: Login as demo admin (standard session — no MFA challenge)
    // ──────────────────────────────────────────────────────────────────
    await loginDemoAdmin(page);

    // ──────────────────────────────────────────────────────────────────
    // Step 3: /admin/users?q=demo.vaultr.test — assert all 9 demo emails
    // ──────────────────────────────────────────────────────────────────
    await page.goto("/admin/users?q=demo.vaultr.test");
    await waitForLiveViewReady(page);

    for (const email of DEMO_EMAILS) {
      await expect(adminUsersEmailLocator(page, email)).toBeVisible();
    }

    await assertDemoScreenshot(page, testInfo, "admin-user-list");

    // ──────────────────────────────────────────────────────────────────
    // Step 4: /admin/users/{admin-id} — assert MFA + passkey row
    // ──────────────────────────────────────────────────────────────────
    await page.goto(`/admin/users?q=${encodeURIComponent(DEMO_ADMIN_EMAIL)}`);
    await waitForLiveViewReady(page);
    await page.getByRole("link", { name: "Open user" }).first().click();
    await expect(page).toHaveURL(/\/admin\/users\/[^?]+/);
    await waitForLiveViewReady(page);

    const securityPanel = page.locator(".sg-detail-panel", { hasText: "MFA" });
    await expect(securityPanel.getByText("Enabled")).toBeVisible();
    await expect(securityPanel.getByText("1 passkey")).toBeVisible();

    await assertDemoScreenshot(page, testInfo, "admin-user-detail");

    // ──────────────────────────────────────────────────────────────────
    // Step 5: /admin/audit — assert non-empty audit event rows
    // ──────────────────────────────────────────────────────────────────
    await page.goto("/admin/audit");
    await waitForLiveViewReady(page);

    // Audit table renders rows in <table class="table w-full"> <tbody> <tr>
    const auditRowCount = await page.locator("table tbody tr").count();
    expect(
      auditRowCount,
      "Expected audit log to have at least one row",
    ).toBeGreaterThan(0);

    await assertDemoScreenshot(page, testInfo, "audit-explorer");
  });
});
