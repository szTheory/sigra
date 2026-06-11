import AxeBuilder from "@axe-core/playwright";
import { test, expect, type Page } from "@playwright/test";
import { TEST_PASSWORD } from "../helpers/fixtures";

const DESKTOP_VIEWPORT = { width: 1280, height: 900 };
const MOBILE_VIEWPORT = { width: 390, height: 844 };

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
  return email;
}

async function dispatchPageLoading(
  page: Page,
  name: "phx:page-loading-start" | "phx:page-loading-stop",
  kind: "initial" | "patch" | "redirect" | "element" | "error",
) {
  await page.evaluate(
    ({ eventName, loadingKind }) => {
      window.dispatchEvent(
        new CustomEvent(eventName, {
          detail: { kind: loadingKind, to: "/admin/users" },
        }),
      );
    },
    { eventName: name, loadingKind: kind },
  );
}

async function lockUserByFailedLogins(page: Page, email: string) {
  await page.context().clearCookies();

  for (let attempt = 0; attempt < 5; attempt += 1) {
    await page.goto("/users/log_in");
    await page.fill('#login_form input[name="user[email]"]', email);
    await page.fill(
      '#login_form input[name="user[password]"]',
      "not-the-password",
    );
    await page.locator("#login_form").evaluate((form) => {
      (form as HTMLFormElement).requestSubmit();
    });
    await expect(page).toHaveURL(/\/users\/log_in/);
  }

  await page.context().clearCookies();
}

async function shellTheme(page: Page) {
  return page.locator(".sg-admin-shell").evaluate((el) => ({
    theme: el.getAttribute("data-theme"),
    preference: el.getAttribute("data-theme-preference"),
    colorScheme: getComputedStyle(el).colorScheme,
    background: getComputedStyle(el).backgroundColor,
  }));
}

async function shellLockupOpacity(page: Page) {
  return page.locator(".sg-brand-mark").evaluate((el) => {
    const light = el.querySelector(
      ".sg-brand-mark__image--light",
    ) as HTMLElement | null;
    const dark = el.querySelector(
      ".sg-brand-mark__image--dark",
    ) as HTMLElement | null;

    if (!light || !dark) {
      throw new Error("Expected light and dark Sigra lockup assets");
    }

    return {
      lightSrc: light.getAttribute("src"),
      darkSrc: dark.getAttribute("src"),
      lightOpacity: getComputedStyle(light).opacity,
      darkOpacity: getComputedStyle(dark).opacity,
    };
  });
}

async function expectShellLockupTheme(page: Page, theme: "light" | "dark") {
  const expected =
    theme === "dark"
      ? { lightOpacity: "0", darkOpacity: "1" }
      : { lightOpacity: "1", darkOpacity: "0" };

  const lockup = await shellLockupOpacity(page);
  expect(lockup.lightSrc).toBe("/images/sigra-logo-primary.svg");
  expect(lockup.darkSrc).toBe("/images/sigra-logo-primary-dark.svg");

  await expect
    .poll(async () => (await shellLockupOpacity(page)).lightOpacity)
    .toBe(expected.lightOpacity);
  await expect
    .poll(async () => (await shellLockupOpacity(page)).darkOpacity)
    .toBe(expected.darkOpacity);
}

function rgbChannels(value: string): [number, number, number] {
  if (value.startsWith("oklab(")) {
    return oklabChannels(value);
  }

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

function oklabChannels(value: string): [number, number, number] {
  const channels = value
    .match(/[-\d.]+/g)
    ?.slice(0, 3)
    .map(Number);

  if (!channels || channels.length < 3) {
    throw new Error(`Expected a CSS oklab color, got ${value}`);
  }

  const [lightness, a, b] = channels;
  const longL = lightness + 0.3963377774 * a + 0.2158037573 * b;
  const longM = lightness - 0.1055613458 * a - 0.0638541728 * b;
  const longS = lightness - 0.0894841775 * a + 1.291485548 * b;
  const l = longL ** 3;
  const m = longM ** 3;
  const s = longS ** 3;

  return [
    linearSrgbToChannel(2.4885527 * l - 2.4230963 * m + 0.4353387 * s),
    linearSrgbToChannel(-0.8139603 * l + 1.987769 * m - 0.1734407 * s),
    linearSrgbToChannel(0.0275693 * l - 0.1525687 * m + 1.152175 * s),
  ];
}

function linearSrgbToChannel(value: number) {
  const bounded = Math.min(Math.max(value, 0), 1);
  const srgb =
    bounded <= 0.0031308
      ? 12.92 * bounded
      : 1.055 * bounded ** (1 / 2.4) - 0.055;

  return srgb * 255;
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

async function expectPaletteFieldsAligned(
  page: Page,
  paletteName: "Light palette" | "Dark palette",
  fieldNames: string[],
) {
  const palette = page.getByRole("group", { name: paletteName });
  await expect(palette).toBeVisible();
  await expect(palette.locator(".sg-color-grid")).toHaveCSS("display", "grid");

  for (const fieldName of fieldNames) {
    const field = palette.locator(
      `label.sg-color-field:has(input[name="branding[${fieldName}]"])`,
    );
    await expect(field).toBeVisible();

    const metrics = await field.evaluate((label) => {
      const control = label.querySelector(
        ".sg-color-field__control",
      ) as HTMLElement | null;
      const input = label.querySelector(
        ".sg-color-field__input",
      ) as HTMLElement | null;
      const value = label.querySelector(
        ".sg-color-field__value",
      ) as HTMLElement | null;

      if (!control || !input || !value) {
        throw new Error("Expected color field control, input, and value");
      }

      const controlRect = control.getBoundingClientRect();
      const inputRect = input.getBoundingClientRect();
      const valueRect = value.getBoundingClientRect();

      return {
        controlDisplay: getComputedStyle(control).display,
        controlOverflow: control.scrollWidth - control.clientWidth,
        inputCenterY: inputRect.top + inputRect.height / 2,
        inputRight: inputRect.right,
        valueCenterY: valueRect.top + valueRect.height / 2,
        valueLeft: valueRect.left,
        valueRight: valueRect.right,
        controlRight: controlRect.right,
      };
    });

    expect(metrics.controlDisplay).toBe("grid");
    expect(
      Math.abs(metrics.inputCenterY - metrics.valueCenterY),
    ).toBeLessThanOrEqual(2);
    expect(metrics.valueLeft).toBeGreaterThan(metrics.inputRight);
    expect(metrics.valueRight).toBeLessThanOrEqual(metrics.controlRight + 1);
    expect(metrics.controlOverflow).toBeLessThanOrEqual(1);
  }
}

async function expectMetricTextRowsAligned(page: Page, selectors: string[]) {
  const metrics = await Promise.all(
    selectors.map(async (selector) =>
      page.locator(selector).evaluate((card, metricSelector) => {
        const value = card.querySelector(
          ".sg-metric__value",
        ) as HTMLElement | null;
        const caption = card.querySelector(
          ".sg-metric__caption",
        ) as HTMLElement | null;
        const subvalue = card.querySelector(
          ".sg-metric__subvalue",
        ) as HTMLElement | null;

        if (!value || !caption) {
          throw new Error(
            `Expected metric value and caption inside ${metricSelector}`,
          );
        }

        const cardRect = card.getBoundingClientRect();
        const valueRect = value.getBoundingClientRect();
        const captionRect = caption.getBoundingClientRect();
        const subvalueRect = subvalue?.getBoundingClientRect();

        if (
          subvalueRect &&
          subvalueRect.top <= captionRect.top + captionRect.height / 2
        ) {
          throw new Error(
            `Expected metric subvalue to render below caption inside ${metricSelector}`,
          );
        }

        return {
          selector: metricSelector as string,
          cardTop: cardRect.top,
          valueTop: valueRect.top,
          captionTop: captionRect.top,
          subvalueTop: subvalueRect?.top ?? null,
        };
      }, selector),
    ),
  );

  const rows: (typeof metrics)[] = [];

  for (const metric of [...metrics].sort((a, b) => a.cardTop - b.cardTop)) {
    const row = rows.find(
      (candidate) => Math.abs(candidate[0].cardTop - metric.cardTop) <= 1,
    );

    if (row) {
      row.push(metric);
    } else {
      rows.push([metric]);
    }
  }

  const expectLineAligned = (
    row: (typeof metrics)[number][],
    line: "valueTop" | "captionTop" | "subvalueTop",
  ) => {
    const tops = row
      .map((metric) => metric[line])
      .filter((top): top is number => top !== null);

    if (tops.length <= 1) {
      return;
    }

    const delta = Math.max(...tops) - Math.min(...tops);
    expect(
      delta,
      `Metric ${line} rows should align: ${row.map((metric) => metric.selector).join(", ")}`,
    ).toBeLessThanOrEqual(1);
  };

  for (const row of rows.filter((candidate) => candidate.length > 1)) {
    expectLineAligned(row, "valueTop");
    expectLineAligned(row, "captionTop");
    expectLineAligned(row, "subvalueTop");
  }
}

async function setColorInput(page: Page, fieldName: string, value: string) {
  await page
    .locator(`input[name="branding[${fieldName}]"]`)
    .evaluate((input, nextValue) => {
      const colorInput = input as HTMLInputElement;
      colorInput.value = nextValue as string;
      colorInput.dispatchEvent(new Event("input", { bubbles: true }));
      colorInput.dispatchEvent(new Event("change", { bubbles: true }));
    }, value);
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
    await expectShellLockupTheme(page, "dark");

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
    await expectShellLockupTheme(page, "light");

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

  test("overview notice action link is visibly actionable", async ({
    page,
  }) => {
    const targetEmail = `notice-risk-${Date.now()}@example.test`;

    await registerUser(page, targetEmail, TEST_PASSWORD);
    await lockUserByFailedLogins(page, targetEmail);
    await logInAsPlatformAdmin(page);
    await page.goto("/admin");
    await waitForLiveViewReady(page);

    const action = page.locator(".sg-notice__action");
    await expect(action).toHaveText("Review accounts");
    await expect(action).toHaveAttribute(
      "href",
      "/admin/users?needs_review=true",
    );

    const readStyles = async () =>
      action.evaluate((link) => {
        const notice = link.closest(".sg-notice") as HTMLElement | null;

        if (!notice) {
          throw new Error("Expected notice action inside .sg-notice");
        }

        const linkStyles = getComputedStyle(link);
        const noticeStyles = getComputedStyle(notice);

        return {
          color: linkStyles.color,
          backgroundColor: linkStyles.backgroundColor,
          noticeBackground: noticeStyles.backgroundColor,
          decorationColor: linkStyles.textDecorationColor,
          decorationLine: linkStyles.textDecorationLine,
          fontWeight: linkStyles.fontWeight,
          boxShadow: linkStyles.boxShadow,
        };
      });

    const lightStyles = await readStyles();
    expect(lightStyles.decorationLine).toContain("underline");
    expect(Number(lightStyles.fontWeight)).toBeGreaterThanOrEqual(600);
    expect(lightStyles.backgroundColor).toBe("rgba(0, 0, 0, 0)");
    await expect
      .poll(async () => {
        const styles = await readStyles();
        return contrastRatio(styles.color, styles.noticeBackground);
      })
      .toBeGreaterThanOrEqual(4.5);

    await action.hover();
    await expect
      .poll(async () => (await readStyles()).backgroundColor)
      .toBe("rgba(0, 0, 0, 0)");
    await expect
      .poll(async () => (await readStyles()).color)
      .not.toBe(lightStyles.color);
    await expect
      .poll(async () => (await readStyles()).decorationColor)
      .not.toBe(lightStyles.decorationColor);
    await expect
      .poll(async () => {
        const styles = await readStyles();
        return contrastRatio(styles.color, styles.noticeBackground);
      })
      .toBeGreaterThanOrEqual(4.5);

    await action.focus();
    await expect
      .poll(async () => (await readStyles()).boxShadow)
      .not.toBe("none");

    await page.getByRole("radio", { name: "Dark" }).click();
    await expect(page.locator(".sg-admin-shell")).toHaveAttribute(
      "data-theme",
      "dark",
    );

    await expect
      .poll(async () => {
        const styles = await readStyles();
        return contrastRatio(styles.color, styles.noticeBackground);
      })
      .toBeGreaterThanOrEqual(4.5);
    const darkStyles = await readStyles();
    expect(darkStyles.decorationLine).toContain("underline");

    await action.hover();
    await expect
      .poll(async () => (await readStyles()).backgroundColor)
      .toBe("rgba(0, 0, 0, 0)");
    await expect
      .poll(async () => (await readStyles()).color)
      .not.toBe(darkStyles.color);
    await expect
      .poll(async () => {
        const styles = await readStyles();
        return contrastRatio(styles.color, styles.noticeBackground);
      })
      .toBeGreaterThanOrEqual(4.5);

    await action.click();
    await expect(page).toHaveURL(/\/admin\/users\?needs_review=true/);
  });

  test("users summary metrics expose accessible help on desktop and mobile", async ({
    page,
  }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin/users");
    await waitForLiveViewReady(page);

    const metric = page.locator("#users-metric-mfa");
    const help = page.locator("#users-metric-mfa-help");

    await expect(
      page.getByRole("heading", { name: "User health" }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Find users" }),
    ).toBeVisible();
    await expect(page.locator("#users-metric-total")).toContainText(
      "total users",
    );
    await expect(page.locator("#users-metric-total")).not.toHaveAttribute(
      "aria-describedby",
      /.+/,
    );
    await expect(metric).toContainText("MFA enabled");
    await expect(metric).toContainText(/% of total users/);
    await expect(
      page.locator("#users-metric-total .sg-metric__subvalue"),
    ).toHaveCount(0);
    await expectMetricTextRowsAligned(page, [
      "#users-metric-total",
      "#users-metric-confirmed",
      "#users-metric-mfa",
      "#users-metric-passkeys",
      "#users-metric-locked",
      "#users-metric-deletion",
    ]);
    await expect(metric).toHaveAttribute(
      "aria-describedby",
      "users-metric-mfa-help",
    );
    await expect(metric).toHaveAttribute("tabindex", "0");
    await expect(metric.locator("[data-sg-metric-help-trigger]")).toHaveCount(
      0,
    );
    await expect(help).toBeHidden();
    await expect(
      page.locator("#users-metric-confirmed .sg-metric__icon"),
    ).toHaveAttribute("data-icon", "check");
    await expect(metric.locator(".sg-metric__icon")).toHaveAttribute(
      "data-icon",
      "mfa",
    );
    await expect(metric.locator(".sg-metric__icon-text")).toHaveText("MFA");
    await expect(metric.locator(".sg-metric__icon-svg")).toHaveCount(0);
    await expect(
      page.locator("#users-metric-passkeys .sg-metric__icon"),
    ).toHaveAttribute("data-icon", "fingerprint");
    const iconSizes = await page.evaluate(() => {
      const checkSvg = document.querySelector(
        "#users-metric-confirmed .sg-metric__icon-svg",
      ) as SVGElement | null;
      const fingerprintSvg = document.querySelector(
        "#users-metric-passkeys .sg-metric__icon-svg",
      ) as SVGElement | null;

      if (!checkSvg || !fingerprintSvg) {
        throw new Error("Expected confirmed and passkey metric SVG icons");
      }

      return {
        checkWidth: checkSvg.getBoundingClientRect().width,
        fingerprintWidth: fingerprintSvg.getBoundingClientRect().width,
      };
    });
    expect(iconSizes.checkWidth).toBeGreaterThan(17);
    expect(iconSizes.fingerprintWidth).toBeGreaterThan(17);
    await expect
      .poll(async () =>
        page
          .locator("#users-metric-locked")
          .evaluate((el) => getComputedStyle(el).boxShadow.includes("inset")),
      )
      .toBe(false);

    const metricContrast = async () =>
      metric.evaluate((el) => {
        const value = el.querySelector(".sg-metric__value") as HTMLElement;
        const styles = getComputedStyle(value);
        return {
          color: styles.color,
          background: getComputedStyle(el).backgroundColor,
        };
      });

    await expect
      .poll(async () => {
        const styles = await metricContrast();
        return contrastRatio(styles.color, styles.background);
      })
      .toBeGreaterThanOrEqual(4.5);

    await metric.focus();
    await expect(help).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(help).toBeHidden();

    await metric.hover();
    await expect(help).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(help).toBeHidden();

    await page.getByRole("radio", { name: "Dark" }).click();
    await expect(page.locator(".sg-admin-shell")).toHaveAttribute(
      "data-theme",
      "dark",
    );
    await expect
      .poll(async () => {
        const styles = await metricContrast();
        return contrastRatio(styles.color, styles.background);
      })
      .toBeGreaterThanOrEqual(4.5);

    await page.setViewportSize(MOBILE_VIEWPORT);
    await page.goto("/admin/users");
    await waitForLiveViewReady(page);
    await expect(metric).toBeVisible();

    await metric.click();
    await expect(help).toBeVisible();

    await metric.click();
    await expect(help).toBeHidden();

    await metric.click();
    await expect(help).toBeVisible();

    await page.locator("body").click({ position: { x: 4, y: 4 } });
    await expect(help).toBeHidden();

    const overflow = await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth,
    );
    expect(overflow).toBeLessThanOrEqual(1);
  });

  test("workspace navigation stays inside the LiveView session", async ({
    page,
  }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin/users");
    await waitForLiveViewReady(page);

    const documentRequests: string[] = [];
    page.on("request", (request) => {
      if (request.resourceType() === "document") {
        documentRequests.push(request.url());
      }
    });

    const nav = page.locator('nav[aria-label="Admin navigation"]');

    await nav.getByRole("link", { name: "Audit" }).click();
    await expect(page).toHaveURL(/\/admin\/audit$/);
    await waitForLiveViewReady(page);
    await expect(page.getByRole("heading", { name: "Audit" })).toBeVisible();

    await nav.getByRole("link", { name: "Branding" }).click();
    await expect(page).toHaveURL(/\/admin\/auth-branding$/);
    await waitForLiveViewReady(page);
    await expect(
      page.getByRole("heading", { name: "Auth forms and emails" }),
    ).toBeVisible();

    await nav.getByRole("link", { name: "Users" }).click();
    await expect(page).toHaveURL(/\/admin\/users$/);
    await waitForLiveViewReady(page);
    await expect(page.getByRole("heading", { name: "Users" })).toBeVisible();

    expect(documentRequests).toEqual([]);
  });

  test("admin page loading rail follows route-level LiveView navigation", async ({
    page,
  }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin");
    await waitForLiveViewReady(page);

    const root = page.locator("html");
    const shell = page.locator(".sg-admin-shell");
    const rail = page.locator("[data-sg-admin-loading-bar]");
    const railFillScale = async () =>
      rail.evaluate((el) => {
        const transform = window.getComputedStyle(el, "::before").transform;
        if (transform === "none") return 1;
        return new DOMMatrixReadOnly(transform).a;
      });

    await expect(rail).toHaveCount(1);
    await expect(root).not.toHaveAttribute(
      "data-sg-admin-page-loading",
      "true",
    );
    await expect(shell).not.toHaveAttribute("aria-busy", "true");

    await dispatchPageLoading(page, "phx:page-loading-start", "redirect");
    await expect(shell).toHaveAttribute("aria-busy", "true");
    await expect(root).toHaveAttribute("data-sg-admin-page-loading", "true");
    await expect
      .poll(async () =>
        rail.evaluate((el) => window.getComputedStyle(el).opacity),
      )
      .toBe("1");
    await expect
      .poll(async () =>
        rail.evaluate((el) => Math.round(el.getBoundingClientRect().top)),
      )
      .toBe(0);
    await expect.poll(railFillScale).toBeGreaterThanOrEqual(0.99);
    await expect
      .poll(async () =>
        rail.evaluate(
          (el) => window.getComputedStyle(el, "::before").animationName,
        ),
      )
      .toBe("none");

    await dispatchPageLoading(page, "phx:page-loading-stop", "redirect");
    await expect(root).not.toHaveAttribute("data-sg-admin-page-loading", /.+/);
    await expect(shell).not.toHaveAttribute("aria-busy", "true");

    await dispatchPageLoading(page, "phx:page-loading-start", "element");
    await expect(root).not.toHaveAttribute(
      "data-sg-admin-page-loading",
      "true",
    );
    await expect(shell).not.toHaveAttribute("aria-busy", "true");
    await dispatchPageLoading(page, "phx:page-loading-stop", "element");

    await dispatchPageLoading(page, "phx:page-loading-start", "redirect");
    await dispatchPageLoading(page, "phx:page-loading-start", "initial");
    await expect(root).toHaveAttribute("data-sg-admin-page-loading", "true");
    await dispatchPageLoading(page, "phx:page-loading-stop", "redirect");
    await expect(root).toHaveAttribute("data-sg-admin-page-loading", "true");
    await expect(shell).toHaveAttribute("aria-busy", "true");
    await dispatchPageLoading(page, "phx:page-loading-stop", "initial");
    await expect(root).not.toHaveAttribute("data-sg-admin-page-loading", /.+/);
    await expect(shell).not.toHaveAttribute("aria-busy", "true");

    await dispatchPageLoading(page, "phx:page-loading-start", "redirect");
    await expect(root).toHaveAttribute("data-sg-admin-page-loading", "true");
    await dispatchPageLoading(page, "phx:page-loading-start", "error");
    await expect(root).not.toHaveAttribute("data-sg-admin-page-loading", /.+/);
    await expect(shell).not.toHaveAttribute("aria-busy", "true");

    await page.emulateMedia({ reducedMotion: "reduce" });
    await dispatchPageLoading(page, "phx:page-loading-start", "patch");
    await expect(root).toHaveAttribute("data-sg-admin-page-loading", "true");
    await expect.poll(railFillScale).toBeGreaterThanOrEqual(0.99);
    await expect
      .poll(async () =>
        rail.evaluate(
          (el) => window.getComputedStyle(el, "::before").animationName,
        ),
      )
      .toBe("none");
    await dispatchPageLoading(page, "phx:page-loading-stop", "patch");
    await expect(root).not.toHaveAttribute("data-sg-admin-page-loading", /.+/);
  });

  test("user detail uses breadcrumbs for filtered list context", async ({
    page,
  }) => {
    const email = await logInAsPlatformAdmin(page);
    await page.goto("/admin/users?order_by=inserted_at&order_direction=desc");
    await waitForLiveViewReady(page);

    await page.getByRole("link", { name: "Open user" }).first().click();
    await expect(page).toHaveURL(/\/admin\/users\/[^/]+\?return_to=/);
    await waitForLiveViewReady(page);

    const breadcrumb = page.getByRole("navigation", { name: "Breadcrumb" });
    await expect(
      breadcrumb.getByRole("link", { name: "Overview" }),
    ).toHaveAttribute("href", "/admin");
    await expect(
      breadcrumb.getByRole("link", { name: "Users" }),
    ).toHaveAttribute(
      "href",
      "/admin/users?order_by=inserted_at&order_direction=desc",
    );
    await expect(breadcrumb.locator('[aria-current="page"]')).toHaveText(email);
    await expect(page.getByRole("link", { name: "Back to users" })).toHaveCount(
      0,
    );
  });

  test("overview keeps notices and task cards without duplicate info sections", async ({
    page,
  }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin");
    await waitForLiveViewReady(page);

    await expect(page.locator(".sg-notice")).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Find a user" }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Investigate an event" }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Review risky accounts" }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "User snapshot" }),
    ).toBeVisible();
    await expect(page.locator("#overview-metric-total-users")).toContainText(
      "total users",
    );
    await expect(page.locator("#overview-metric-new-users")).toContainText(
      "new this week",
    );
    await expect(page.locator("#overview-metric-auth-coverage")).toContainText(
      "MFA coverage",
    );
    await expectMetricTextRowsAligned(page, [
      "#overview-metric-total-users",
      "#overview-metric-new-users",
      "#overview-metric-active-users",
      "#overview-metric-auth-coverage",
    ]);
    await expect(page.locator(".sg-posture-strip")).toHaveCount(0);
    await expect(
      page.getByRole("heading", { name: "What Sigra can do" }),
    ).toHaveCount(0);
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
    await page.goto("/admin/auth-branding?panel=details");
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

  test("auth branding details field help works on hover, keyboard, and touch", async ({
    page,
  }) => {
    await page.setViewportSize(DESKTOP_VIEWPORT);
    await logInAsPlatformAdmin(page);
    await page.goto("/admin/auth-branding?panel=details");
    await waitForLiveViewReady(page);

    const logoHelpTrigger = page.getByRole("button", {
      name: "Help: Logo URL",
    });
    const logoHelp = page.locator("#branding-logo-url-help");

    await expect(logoHelpTrigger).toHaveAttribute(
      "aria-controls",
      "branding-logo-url-help",
    );
    await expect(logoHelpTrigger).toHaveAttribute("aria-expanded", "false");
    await expect(logoHelp).toBeHidden();

    await logoHelpTrigger.hover();
    await expect(logoHelp).toBeVisible();
    await expect(logoHelp).toContainText(
      "Shown on generated auth screens and email headers when set.",
    );
    await expect(logoHelpTrigger).toHaveAttribute("aria-expanded", "true");

    await page.mouse.move(2, 2);
    await expect(logoHelp).toBeHidden();

    await logoHelpTrigger.focus();
    await expect(logoHelp).toBeVisible();
    await page.keyboard.press("Escape");
    await expect(logoHelp).toBeHidden();
    await expect(logoHelpTrigger).toHaveAttribute("aria-expanded", "false");

    await page.setViewportSize(MOBILE_VIEWPORT);
    await page.goto("/admin/auth-branding?panel=details");
    await waitForLiveViewReady(page);

    const replyToHelpTrigger = page.getByRole("button", {
      name: "Help: Reply-to",
    });
    const replyToHelp = page.locator("#branding-email-reply-to-help");

    await replyToHelpTrigger.click();
    await expect(replyToHelp).toBeVisible();
    await expect(replyToHelp).toContainText(
      "Replies go to this address when set.",
    );

    await page.locator("body").click({ position: { x: 1, y: 1 } });
    await expect(replyToHelp).toBeHidden();
  });

  test("auth branding color changes update local previews before save", async ({
    page,
  }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin/auth-branding?panel=light");
    await waitForLiveViewReady(page);

    const loginPreview = page.locator(
      '[data-testid="admin-auth-preview"] .sigra-auth',
    );

    await setColorInput(page, "accent_color", "#14532d");
    await expect(page.getByText("Unsaved preview")).toBeVisible();
    await expect
      .poll(() =>
        loginPreview.evaluate((preview) =>
          getComputedStyle(preview)
            .getPropertyValue("--sigra-auth-light-accent")
            .trim(),
        ),
      )
      .toBe("#14532d");

    await page.getByRole("link", { name: "Dark" }).click();
    await expect(page).toHaveURL(/panel=dark/);

    await setColorInput(page, "dark_surface_color", "#111827");
    await expect
      .poll(() =>
        page
          .locator('[data-testid="admin-auth-preview"] .sigra-auth')
          .evaluate((preview) =>
            getComputedStyle(preview)
              .getPropertyValue("--sigra-auth-dark-surface")
              .trim(),
          ),
      )
      .toBe("#111827");
  });

  test("auth branding color input updates previews before a LiveView round trip", async ({
    page,
  }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin/auth-branding?panel=light");
    await waitForLiveViewReady(page);

    await page.evaluate(() => {
      const liveSocket = (
        window as unknown as {
          liveSocket?: {
            enableLatencySim?: (latencyMs: number) => void;
          };
        }
      ).liveSocket;
      liveSocket?.enableLatencySim?.(300);
    });

    const localResult = await page.evaluate(() => {
      const form = document.querySelector(
        "#auth-branding-form",
      ) as HTMLFormElement;
      const input = form.querySelector(
        'input[name="branding[accent_color]"]',
      ) as HTMLInputElement;
      const preview = document.querySelector(
        '[data-testid="admin-auth-preview"] .sigra-auth',
      ) as HTMLElement;
      const valueLabel = form.querySelector(
        '[data-sg-auth-branding-color-value="accent_color"]',
      ) as HTMLElement;

      input.value = "#14532d";
      input.dispatchEvent(new Event("input", { bubbles: true }));

      return {
        previewAccent: getComputedStyle(preview)
          .getPropertyValue("--sigra-auth-light-accent")
          .trim(),
        valueLabel: valueLabel.textContent?.trim(),
        formIsLoading: form.classList.contains("phx-change-loading"),
        unsavedVisible: document.body.textContent?.includes("Unsaved preview"),
      };
    });

    expect(localResult).toEqual({
      previewAccent: "#14532d",
      valueLabel: "#14532d",
      formIsLoading: false,
      unsavedVisible: false,
    });

    await page
      .locator('input[name="branding[accent_color]"]')
      .dispatchEvent("change", { bubbles: true });
    await expect(page.getByText("Unsaved preview")).toBeVisible();

    await page.evaluate(() => {
      const liveSocket = (
        window as unknown as {
          liveSocket?: {
            disableLatencySim?: () => void;
          };
        }
      ).liveSocket;
      liveSocket?.disableLatencySim?.();
    });
  });

  test("auth branding save toast can be dismissed", async ({ page }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin/auth-branding?panel=details");
    await waitForLiveViewReady(page);

    await page.getByRole("button", { name: "Save profile" }).click();

    const flash = page.locator("#flash-info[data-flash]");
    await expect(flash).toContainText("Auth branding profile saved.");

    await flash.getByRole("button", { name: "close" }).click();
    await expect(flash).toBeHidden();

    await page.getByRole("link", { name: "Light" }).click();
    await expect(page).toHaveURL(/panel=light/);
    await expect(flash).toBeHidden();
  });

  test("auth branding restore defaults is explicit and confirmed", async ({
    page,
  }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin/auth-branding?panel=details");
    await waitForLiveViewReady(page);

    await expect(page.getByRole("button", { name: "Reset" })).toHaveCount(0);
    const restoreButton = page.getByRole("button", {
      name: "Restore config defaults",
    });

    if ((await restoreButton.count()) > 0) {
      await restoreButton.click();
      await page.getByRole("button", { name: "Restore defaults" }).click();
      await expect(restoreButton).toHaveCount(0);
    }

    await expect(restoreButton).toHaveCount(0);

    await page.getByRole("button", { name: "Save profile" }).click();
    await expect(page.locator("#flash-info[data-flash]")).toContainText(
      "Auth branding profile saved.",
    );

    await expect(restoreButton).toBeVisible();

    await restoreButton.click();
    const confirmDialog = page.getByRole("dialog", {
      name: "Restore defaults?",
    });
    await expect(confirmDialog).toBeVisible();
    await expect(page.locator(".sg-confirm-overlay")).toBeVisible();
    await expect(page.locator(".modal[open]")).toHaveCount(0);
    await expect(page.locator("dialog.modal")).toHaveCount(0);
    await expect(
      page.getByText("This removes the saved admin branding changes"),
    ).toBeVisible();

    const confirmBox = await confirmDialog.boundingBox();
    const viewport = page.viewportSize();
    expect(confirmBox).not.toBeNull();
    expect(viewport).not.toBeNull();
    expect(
      Math.abs(confirmBox!.x + confirmBox!.width / 2 - viewport!.width / 2),
    ).toBeLessThan(80);
    expect(confirmBox!.y).toBeGreaterThan(40);

    await page.getByRole("button", { name: "Cancel" }).click();
    await expect(confirmDialog).toBeHidden();
    await expect(page.locator(".sg-confirm-overlay")).toHaveCount(0);
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await expect
      .poll(() => page.evaluate(() => window.scrollY))
      .toBeGreaterThan(0);
    await page.evaluate(() => window.scrollTo(0, 0));
    await expect.poll(() => page.evaluate(() => window.scrollY)).toBe(0);
    await expect(restoreButton).toBeVisible();

    await restoreButton.click();
    await page.getByRole("button", { name: "Restore defaults" }).click();
    await expect(page.locator("#flash-info[data-flash]")).toContainText(
      "Auth branding restored to config defaults.",
    );
    await expect(
      page.getByRole("button", { name: "Restore config defaults" }),
    ).toHaveCount(0);
    await expect(page.getByText("Source: Config defaults")).toBeVisible();
  });

  test("auth branding discard changes only clears the unsaved preview", async ({
    page,
  }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin/auth-branding?panel=details");
    await waitForLiveViewReady(page);

    await page.getByRole("button", { name: "Save profile" }).click();
    await expect(page.locator("#flash-info[data-flash]")).toContainText(
      "Auth branding profile saved.",
    );

    const productName = page.locator(
      '#auth-branding-form input[name="branding[product_name]"]',
    );
    const initialProductName = await productName.inputValue();

    await productName.fill("Draft Only");
    await productName.dispatchEvent("input");
    await expect(page.getByText("Unsaved preview")).toBeVisible();

    await page.getByRole("button", { name: "Discard changes" }).click();
    await expect(page.locator("#flash-info[data-flash]")).toContainText(
      "Unsaved branding changes discarded.",
    );
    await expect(page.getByText("Unsaved preview")).toBeHidden();
    await expect(productName).toHaveValue(initialProductName);
    await expect(
      page.getByRole("button", { name: "Restore config defaults" }),
    ).toBeVisible();
  });

  test("auth branding color palettes keep swatches and hex values aligned", async ({
    page,
  }) => {
    await page.setViewportSize(DESKTOP_VIEWPORT);
    await logInAsPlatformAdmin(page);
    await page.goto("/admin/auth-branding?panel=light");
    await waitForLiveViewReady(page);

    await expectPaletteFieldsAligned(page, "Light palette", [
      "accent_color",
      "accent_foreground",
      "background_color",
      "surface_color",
    ]);

    await page.getByRole("link", { name: "Dark" }).click();
    await expect(page).toHaveURL(/panel=dark/);
    await expectPaletteFieldsAligned(page, "Dark palette", [
      "dark_accent_color",
      "dark_accent_foreground",
      "dark_background_color",
      "dark_surface_color",
    ]);

    await page.setViewportSize(MOBILE_VIEWPORT);
    await page.goto("/admin/auth-branding?panel=light");
    await waitForLiveViewReady(page);

    const gridOverflow = await page
      .locator(".sg-branding-panel:not([hidden]) .sg-color-grid")
      .evaluateAll((grids) =>
        grids.map((grid) => {
          const element = grid as HTMLElement;
          return element.scrollWidth - element.clientWidth;
        }),
      );

    for (const overflow of gridOverflow) {
      expect(overflow).toBeLessThanOrEqual(1);
    }
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
