import AxeBuilder from "@axe-core/playwright";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test, expect, type Locator, type Page } from "@playwright/test";
import { contrastRatio, rgbChannels } from "../helpers/brandContrast";
import { assertBrandFontsLoaded } from "../helpers/brandFonts";
import { brandTokensJson, repoRoot, tokenValue } from "../helpers/brandSource";
import { TEST_PASSWORD } from "../helpers/fixtures";
import {
  assertGenericRegistrationResponse,
  signInManually,
} from "../helpers/registration";

const DESKTOP_VIEWPORT = { width: 1280, height: 900 };
const MOBILE_VIEWPORT = { width: 390, height: 844 };

test("converts the OKLab blue reference vector correctly", () => {
  const [red, green, blue] = rgbChannels("oklab(45.2% -0.0325 -0.3115)");

  expect(red).toBeLessThan(1);
  expect(green).toBeLessThan(1);
  expect(blue).toBeGreaterThan(254);
});

interface IcoEntry {
  size: number;
  png: Buffer;
}

interface InkRegion {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

interface InkBox {
  box: InkRegion | null;
  inkCount: number;
  columns: number[];
  colorsByRegion: Record<"square" | "stem" | "other", string[]>;
  otherInkRows: number[];
  antialiasedRows: number[];
  fullAlphaColors: string[];
}

function parseIco(bytes: Buffer): IcoEntry[] {
  if (bytes.length < 6 || bytes.readUInt16LE(0) !== 0 || bytes.readUInt16LE(2) !== 1) {
    throw new Error("Expected a valid ICO header");
  }

  const entryCount = bytes.readUInt16LE(4);
  if (entryCount === 0 || bytes.length < 6 + entryCount * 16) {
    throw new Error("ICO directory is empty or truncated");
  }

  return Array.from({ length: entryCount }, (_, index) => {
    const entryOffset = 6 + index * 16;
    const width = bytes.readUInt8(entryOffset) || 256;
    const height = bytes.readUInt8(entryOffset + 1) || 256;
    const imageByteLength = bytes.readUInt32LE(entryOffset + 8);
    const imageOffset = bytes.readUInt32LE(entryOffset + 12);
    const imageEnd = imageOffset + imageByteLength;
    if (imageOffset < 6 + entryCount * 16 || imageEnd > bytes.length) {
      throw new Error(`ICO ${width}x${height} entry points outside the file`);
    }
    if (width !== height) throw new Error(`Expected a square ICO entry, got ${width}x${height}`);

    return { size: width, png: bytes.subarray(imageOffset, imageEnd) };
  });
}

function sha256(bytes: Buffer): string {
  return createHash("sha256").update(bytes).digest("hex");
}

function readBrandIcon(name: string): Buffer {
  return readFileSync(join(repoRoot(), "brand", "assets", "icon", name));
}

function pngDataUrl(bytes: Buffer): string {
  return `data:image/png;base64,${bytes.toString("base64")}`;
}

function svgDataUrl(bytes: Buffer): string {
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(bytes.toString("utf8"))}`;
}

function declaredSvgSize(bytes: Buffer): { width: number; height: number } {
  const openingTag = /^<svg\b[^>]*>/s.exec(bytes.toString("utf8"))?.[0];
  const width = openingTag && /\bwidth="(\d+)"/.exec(openingTag)?.[1];
  const height = openingTag && /\bheight="(\d+)"/.exec(openingTag)?.[1];
  if (!width || !height) throw new Error("Favicon SVG must declare its size");
  return { width: Number(width), height: Number(height) };
}

async function drawToPixels(
  page: Page,
  source: string,
  width: number,
  height: number,
): Promise<number[]> {
  return page.evaluate(
    ({ dataUrl, drawWidth, drawHeight }) =>
      new Promise<number[]>((resolve, reject) => {
        const image = new Image();
        image.onerror = () => reject(new Error("Could not decode favicon image"));
        image.onload = () => {
          const canvas = document.createElement("canvas");
          canvas.width = drawWidth;
          canvas.height = drawHeight;
          const context = canvas.getContext("2d", { willReadFrequently: true });
          if (!context) {
            reject(new Error("Canvas 2D context is unavailable"));
            return;
          }
          context.drawImage(image, 0, 0, drawWidth, drawHeight);
          resolve(Array.from(context.getImageData(0, 0, drawWidth, drawHeight).data));
        };
        image.src = dataUrl;
      }),
    { dataUrl: source, drawWidth: width, drawHeight: height },
  );
}

function inkBox(pixels: number[], width: number, height: number): InkBox {
  if (pixels.length !== width * height * 4) {
    throw new Error(`Expected ${width}x${height} RGBA pixels`);
  }

  const regions: Record<"square" | "stem", InkRegion> =
    width === 16 && height === 16
      ? {
          square: { left: 6, top: 1, right: 10, bottom: 5 },
          stem: { left: 6, top: 7, right: 10, bottom: 15 },
        }
      : width === 32 && height === 32
        ? {
            square: { left: 12, top: 2, right: 20, bottom: 10 },
            stem: { left: 12, top: 13, right: 20, bottom: 30 },
          }
        : (() => {
            throw new Error(`No expected favicon grid for ${width}x${height}`);
          })();
  const box: InkRegion = {
    left: width,
    top: height,
    right: 0,
    bottom: 0,
  };
  let inkCount = 0;
  let hasInk = false;
  const columns = new Set<number>();
  const otherInkRows = new Set<number>();
  const antialiasedRows = new Set<number>();
  const fullAlphaColors = new Set<string>();
  const colorsByRegion = {
    square: new Set<string>(),
    stem: new Set<string>(),
    other: new Set<string>(),
  };

  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const offset = (y * width + x) * 4;
      const [red, green, blue, alpha] = pixels.slice(offset, offset + 4);
      if (alpha === 0) continue;

      hasInk = true;
      inkCount += 1;
      columns.add(x);
      box.left = Math.min(box.left, x);
      box.top = Math.min(box.top, y);
      box.right = Math.max(box.right, x + 1);
      box.bottom = Math.max(box.bottom, y + 1);
      const color = `#${[red, green, blue]
        .map((channel) => channel.toString(16).padStart(2, "0"))
        .join("")
        .toUpperCase()}`;
      const region = (Object.entries(regions) as ["square" | "stem", InkRegion][]).find(
        ([, bounds]) =>
          x >= bounds.left &&
          x < bounds.right &&
          y >= bounds.top &&
          y < bounds.bottom,
      )?.[0];
      if (region) {
        colorsByRegion[region].add(color);
      } else {
        colorsByRegion.other.add(color);
        otherInkRows.add(y);
      }
      if (alpha < 255) antialiasedRows.add(y);
      if (alpha === 255) fullAlphaColors.add(color);
    }
  }

  return {
    box: hasInk ? box : null,
    inkCount,
    columns: [...columns].sort((left, right) => left - right),
    colorsByRegion: {
      square: [...colorsByRegion.square].sort(),
      stem: [...colorsByRegion.stem].sort(),
      other: [...colorsByRegion.other].sort(),
    },
    otherInkRows: [...otherInkRows].sort((left, right) => left - right),
    antialiasedRows: [...antialiasedRows].sort((left, right) => left - right),
    fullAlphaColors: [...fullAlphaColors].sort(),
  };
}

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
  await assertGenericRegistrationResponse(page);
  await signInManually(page, email, password);
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

async function readNoticeStyles(notice: Locator) {
  return notice.evaluate((el) => {
    const inner = el.querySelector(".sg-text-sm") as HTMLElement | null;
    if (!inner) throw new Error("Expected .sg-text-sm inside .sg-notice");
    return {
      color: getComputedStyle(inner).color,
      background: getComputedStyle(el).backgroundColor,
    };
  });
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
    await expect(notice).toContainText(/users need review|No flagged accounts/);
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
    await expect(notice).toContainText(/users need review|No flagged accounts/);
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
    await expect(action).toHaveText("Review users");
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

    // User health intentionally renders only decision-bearing metrics. Locked
    // users is the accessible, actionable metric that owns this help behavior.
    const metric = page.locator("#users-metric-locked");
    const help = page.locator("#users-metric-locked-help");

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
    await expect(metric).toContainText("Locked users");
    await expect(metric).toContainText("locked out");
    await expect(metric).toContainText(/% of total users/);
    await expect(
      page.locator("#users-metric-total .sg-metric__subvalue"),
    ).toHaveCount(0);
    await expectMetricTextRowsAligned(page, [
      "#users-metric-total",
      "#users-metric-locked",
      "#users-metric-deletion",
    ]);
    await expect(metric).toHaveAttribute(
      "aria-describedby",
      "users-metric-locked-help",
    );
    await expect(metric).toHaveAttribute("tabindex", "0");
    await expect(metric.locator("[data-sg-metric-help-trigger]")).toHaveCount(
      0,
    );
    await expect(help).toBeHidden();
    await expect(metric.locator(".sg-metric__icon")).toHaveAttribute(
      "data-icon",
      "lock",
    );
    await expect(metric.locator(".sg-metric__icon-svg")).toBeVisible();
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

    // Escape deliberately suppresses the synthetic mouseover produced by a
    // collapsing metric. Move the pointer to a different target first, then
    // exercise a genuine hover-to-reopen path.
    await page.getByRole("heading", { name: "Find users" }).hover();
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
    await expect(
      page.getByRole("heading", { name: "Users", exact: true }),
    ).toBeVisible();

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
    await logInAsPlatformAdmin(page);
    await page.goto("/admin/users?order_by=inserted_at&order_direction=desc");
    await waitForLiveViewReady(page);

    const openUser = page.getByRole("link", { name: "Open user" }).first();
    const targetEmail = await openUser
      .locator("xpath=ancestor::tr")
      .locator('span[title*="@"]')
      .textContent();

    if (!targetEmail) {
      throw new Error(
        "Expected the selected user row to expose an email address",
      );
    }

    await openUser.click();
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
    await expect(breadcrumb.locator('[aria-current="page"]')).toHaveText(
      targetEmail,
    );
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
      page.getByRole("heading", { name: "Review users" }),
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "User snapshot" }),
    ).toBeVisible();
    await expect(page.locator("#overview-metric-new-users")).toContainText(
      "new this week",
    );
    await expect(
      page.locator('#overview-metric-new-users [data-icon="sparkles"]'),
    ).toBeVisible();
    await expect(
      page.locator('#overview-metric-new-users [data-icon="calendar-plus"]'),
    ).toHaveCount(0);
    await expect(page.locator("#overview-metric-active-users")).toContainText(
      "active this week",
    );
    await expectMetricTextRowsAligned(page, [
      "#overview-metric-new-users",
      "#overview-metric-active-users",
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

    // Switching theme and hovering both start the 140ms colour transition
    // (`--sg-transition-tone`). With the Kiln tokens the label changes from white
    // to near-black across that switch, so a computed read taken mid-transition
    // lands between the two and measures a frame nobody sees (observed 1.2 to 3.5
    // against the 4.5 bar). The contract is the settled hover state: wait for the
    // element's transitions to finish, then read it. The 4.5 threshold is unchanged.
    await search.evaluate((el) =>
      Promise.all(el.getAnimations().map((animation) => animation.finished.catch(() => null))),
    );

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

  // BTOK-03 (Phase 261): the SHOWN theme (the admin choice, or the OS scheme when
  // the choice is System) decides the brand tokens, the focus ring and the lockup.
  // Two of the six combinations are the ones a token restated in only some of its
  // four declaration places breaks: OS dark with Light chosen, and OS light with
  // Dark chosen. There the prefers-color-scheme block and the explicit block
  // disagree, so a token missing from the explicit block shows the OS theme.
  test("theme matrix: shown theme drives brand tokens, focus ring and lockup", async ({
    page,
  }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin");
    await waitForLiveViewReady(page);

    const lower = (value: string) => value.trim().toLowerCase();
    // The ring assertion can only tell the themes apart if their grounds differ.
    for (const name of ["--sg-color-subtle", "--sg-color-brand-strong"]) {
      expect(lower(tokenValue("light", name)), `${name} differs per theme`).not.toBe(
        lower(tokenValue("dark", name)),
      );
    }

    let combinations = 0;
    for (const os of ["light", "dark"] as const) {
      for (const choice of ["light", "dark", "system"] as const) {
        combinations += 1;
        const label = `OS ${os}, admin choice ${choice}`;
        const shown = choice === "system" ? os : choice;
        const hidden = shown === "light" ? "dark" : "light";

        await page.emulateMedia({ colorScheme: os });
        await page.evaluate((next) => {
          const shell = document.querySelector(".sg-admin-shell")!;
          if (next === "system") {
            document.documentElement.removeAttribute("data-sg-admin-theme");
            shell.removeAttribute("data-theme");
          } else {
            document.documentElement.setAttribute("data-sg-admin-theme", next);
            shell.setAttribute("data-theme", next);
          }
        }, choice);

        const computed = await page.locator(".sg-admin-shell").evaluate((el) => {
          const style = getComputedStyle(el);
          return {
            brand: style.getPropertyValue("--sg-color-brand"),
            onBrand: style.getPropertyValue("--sg-color-on-brand"),
            ring: style.getPropertyValue("--sg-focus-ring"),
          };
        });
        expect(lower(computed.brand), `${label}: --sg-color-brand`).toBe(
          lower(tokenValue(shown, "--sg-color-brand")),
        );
        expect(lower(computed.onBrand), `${label}: --sg-color-on-brand`).toBe(
          lower(tokenValue(shown, "--sg-color-on-brand")),
        );
        expect(lower(computed.ring), `${label}: --sg-focus-ring gap layer`).toContain(
          lower(tokenValue(shown, "--sg-color-subtle")),
        );
        expect(lower(computed.ring), `${label}: --sg-focus-ring ring layer`).toContain(
          lower(tokenValue(shown, "--sg-color-brand-strong")),
        );

        // The lockup swap is a 140ms opacity transition: poll, never read at once.
        await expect(
          page.locator(`.sg-brand-mark__image--${shown}`),
          `${label}: the ${shown} lockup is shown`,
        ).toHaveCSS("opacity", "1");
        await expect(
          page.locator(`.sg-brand-mark__image--${hidden}`),
          `${label}: the ${hidden} lockup is hidden`,
        ).toHaveCSS("opacity", "0");
      }
    }

    expect(combinations, "OS scheme (2) x admin choice (3)").toBe(6);
  });

  test("lockup keeps 2T clear space at 96px minimum in Light and Dark", async ({
    page,
  }) => {
    await page.setViewportSize(DESKTOP_VIEWPORT);
    await logInAsPlatformAdmin(page);
    await page.goto("/admin");
    await waitForLiveViewReady(page);

    for (const theme of ["light", "dark"] as const) {
      await page.emulateMedia({ colorScheme: theme });
      await page.evaluate((next) => {
        const shell = document.querySelector(".sg-admin-shell");
        if (!shell) throw new Error("Expected .sg-admin-shell");
        document.documentElement.setAttribute("data-sg-admin-theme", next);
        shell.setAttribute("data-theme", next);
      }, theme);

      const image = page.locator(`.sg-brand-mark__image--${theme}`);
      await expect(image).toHaveCSS("opacity", "1");

      const geometry = await page.evaluate((shownTheme) => {
        const image = document.querySelector(
          `.sg-brand-mark__image--${shownTheme}`,
        );
        const lockup = document.querySelector(".sg-brand-mark__lockup");
        const section = document.querySelector(".sg-brand-mark__section");
        const topbar = document.querySelector(".sg-admin-topbar");
        if (!image || !lockup || !section || !topbar) {
          throw new Error("Expected the admin lockup, label, and topbar");
        }

        const imageRect = image.getBoundingClientRect();
        const sectionRect = section.getBoundingClientRect();
        const topbarRect = topbar.getBoundingClientRect();
        const paintedWidth = Math.min(
          imageRect.width,
          imageRect.height * (2305.3 / 935),
        );
        const paintedHeight = paintedWidth / (2305.3 / 935);
        const paintedTop = imageRect.top + (imageRect.height - paintedHeight) / 2;

        return {
          paintedWidth,
          T: (paintedWidth * 150) / 2305.3,
          gapAdmin: sectionRect.left - (imageRect.left + paintedWidth),
          gapTop: paintedTop - topbarRect.top,
          gapBottom: topbarRect.bottom - (paintedTop + paintedHeight),
          gapLeft: imageRect.left,
          transform: getComputedStyle(lockup).transform,
          topbarHeight: topbarRect.height,
        };
      }, theme);
      expect(geometry.paintedWidth, `${theme}: painted width`).toBeGreaterThanOrEqual(
        95.99,
      );
      // 0.25px covers 12.53px contract clearance vs 12.49px minimum after 1/64px snapping.
      const minimumGap = 2 * geometry.T - 0.25;
      for (const [name, gap] of [
        ["Admin label", geometry.gapAdmin],
        ["topbar top", geometry.gapTop],
        ["topbar bottom", geometry.gapBottom],
        ["viewport left", geometry.gapLeft],
      ] as const) {
        expect(gap, `${theme}: ${name} clearance`).toBeGreaterThanOrEqual(
          minimumGap,
        );
      }
      expect(geometry.transform, `${theme}: lockup transform`).toBe("none");
      expect(geometry.topbarHeight, `${theme}: topbar height`).toBeGreaterThanOrEqual(
        63,
      );
      expect(geometry.topbarHeight, `${theme}: topbar height`).toBeLessThanOrEqual(
        65,
      );
    }
  });

  test("favicon links render on Sigra-owned pages only", async ({ page }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin");
    await waitForLiveViewReady(page);

    const links = await page.locator("link[rel=icon]").evaluateAll((elements) =>
      elements.map((element) => ({
        href: element.getAttribute("href"),
        sizes: element.getAttribute("sizes"),
        type: element.getAttribute("type"),
      })),
    );
    expect(links).toEqual([
      {
        href: "/images/sigra-favicon.ico",
        sizes: "16x16 32x32",
        type: null,
      },
      { href: "/favicon.svg", sizes: null, type: "image/svg+xml" },
    ]);

    await page.context().clearCookies();
    await page.goto("/users/log_in");
    await expect(page.locator("link[rel=icon]")).toHaveCount(0);
  });

  test("favicon assets are the book bytes and root favicon stays unchanged", async ({
    page,
  }) => {
    const bookSvg = readBrandIcon("favicon.svg");
    const bookIco = readBrandIcon("favicon.ico");
    const rootFavicon = readFileSync(
      join(repoRoot(), "test", "example", "priv", "static", "favicon.ico"),
    );

    const svgResponse = await page.request.get("/favicon.svg");
    expect(svgResponse.status()).toBe(200);
    const servedSvg = await svgResponse.body();
    expect(sha256(servedSvg)).toBe(sha256(bookSvg));
    expect(servedSvg).toEqual(bookSvg);

    const icoResponse = await page.request.get("/images/sigra-favicon.ico");
    expect(icoResponse.status()).toBe(200);
    const servedIco = await icoResponse.body();
    expect(sha256(servedIco)).toBe(sha256(bookIco));
    expect(servedIco).toEqual(bookIco);

    const rootResponse = await page.request.get("/favicon.ico");
    expect(rootResponse.status()).toBe(200);
    const servedRootFavicon = await rootResponse.body();
    expect(servedRootFavicon).toEqual(rootFavicon);
  });

  test("favicon renders pixel-exact at 16px and 32px and is distinct from the retired mark", async ({
    page,
  }) => {
    await page.emulateMedia({ colorScheme: "light" });

    const expectedRegions = {
      16: {
        box: { left: 6, top: 1, right: 10, bottom: 15 },
        square: "#C2410C",
        stem: "#1F1A17",
        inkCount: 48,
      },
      32: {
        box: { left: 12, top: 2, right: 20, bottom: 30 },
        square: "#C2410C",
        stem: "#1F1A17",
        inkCount: 200,
      },
    } as const;
    const expectExactGrid = (pixels: number[], size: 16 | 32, label: string) => {
      const result = inkBox(pixels, size, size);
      const expected = expectedRegions[size];
      expect(result.box, `${label}: ${size}px drawn grid`).toEqual(expected.box);
      expect(result.inkCount, `${label}: ${size}px grid ink count`).toBe(
        expected.inkCount,
      );
      expect(result.colorsByRegion.square, `${label}: square pixels`).toEqual([
        expected.square,
      ]);
      expect(result.colorsByRegion.stem, `${label}: stem pixels`).toEqual([
        expected.stem,
      ]);
      expect(result.colorsByRegion.other, `${label}: pixels outside grid`).toEqual(
        [],
      );
      expect(result.antialiasedRows, `${label}: fully opaque grid`).toEqual([]);
      expect(result.fullAlphaColors, `${label}: brand colors`).toEqual([
        "#1F1A17",
        "#C2410C",
      ]);
    };

    const icoBytes = readBrandIcon("favicon.ico");
    const icoEntries = parseIco(icoBytes);
    expect(icoEntries.map(({ size }) => size).sort((a, b) => a - b)).toEqual([
      16, 32,
    ]);
    const ico16 = icoEntries.find(({ size }) => size === 16);
    const ico32 = icoEntries.find(({ size }) => size === 32);
    if (!ico16 || !ico32) throw new Error("Expected 16px and 32px ICO entries");

    const ico16Pixels = await drawToPixels(page, pngDataUrl(ico16.png), 16, 16);
    const ico32Pixels = await drawToPixels(page, pngDataUrl(ico32.png), 32, 32);
    expectExactGrid(ico16Pixels, 16, "ICO");
    expectExactGrid(ico32Pixels, 32, "ICO");

    for (const size of [16, 32] as const) {
      const assetBytes = readBrandIcon(`favicon-${size}-light.svg`);
      expect(declaredSvgSize(assetBytes)).toEqual({ width: size, height: size });
      const pixels = await drawToPixels(page, svgDataUrl(assetBytes), size, size);
      expectExactGrid(pixels, size, `light SVG`);
    }

    const responsiveSvg = readBrandIcon("favicon.svg");
    const responsive32 = await drawToPixels(
      page,
      svgDataUrl(responsiveSvg),
      32,
      32,
    );
    expectExactGrid(responsive32, 32, "responsive SVG");

    const responsive16 = await drawToPixels(
      page,
      svgDataUrl(responsiveSvg),
      16,
      16,
    );
    const responsive16Result = inkBox(responsive16, 16, 16);
    expect(responsive16Result.inkCount, "responsive SVG is non-blank").toBeGreaterThan(
      0,
    );
    expect(responsive16Result.columns, "responsive SVG 16px ink columns").toEqual([
      6, 7, 8, 9,
    ]);
    expect(
      responsive16Result.antialiasedRows.length,
      "responsive SVG has at most one antialiased row",
    ).toBeLessThanOrEqual(1);
    expect(
      responsive16Result.fullAlphaColors,
      "responsive SVG opaque colors stay on brand",
    ).toEqual(["#1F1A17", "#C2410C"]);
    expect(
      responsive16Result.otherInkRows.every((row) =>
        responsive16Result.antialiasedRows.includes(row),
      ),
      "responsive SVG ink outside the drawn grid is antialiased only",
    ).toBe(true);

    const rootResponse = await page.request.get("/favicon.ico");
    expect(rootResponse.status()).toBe(200);
    const rootBytes = await rootResponse.body();
    const pngSignature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
    expect(rootBytes.subarray(0, 8), "retired root favicon is a PNG payload").toEqual(
      pngSignature,
    );
    expect(sha256(rootBytes), "new ICO differs from the retired root favicon").not.toBe(
      sha256(icoBytes),
    );

    const rootPixels = await drawToPixels(page, pngDataUrl(rootBytes), 16, 16);
    const differentPixelCount = Array.from({ length: 16 * 16 }, (_, index) => {
      const offset = index * 4;
      return rootPixels.slice(offset, offset + 4).some((channel, channelIndex) =>
        channel !== ico16Pixels[offset + channelIndex],
      );
    }).filter(Boolean).length;
    expect(differentPixelCount, "new and retired 16px pixels differ").toBeGreaterThan(
      0,
    );
    expect(inkBox(ico16Pixels, 16, 16).inkCount, "new 16px render is non-blank").toBe(
      48,
    );
  });

  // BTOK-06 (Phase 261): with default tokens the admin shell takes the host's own
  // face. `--sg-font-sans: inherit` is a CSS-wide keyword on a custom property, so
  // the token is effectively unset and the usage-site fallback supplies the
  // inheritance; that is subtle enough that the oracle is this computed-style
  // probe, not the reasoning. The example's opt-in stylesheet is the only thing
  // that makes the shell Instrument Sans.
  test("font tokens: defaults inherit the host face and the example opts in", async ({
    page,
  }) => {
    await logInAsPlatformAdmin(page);
    await page.goto("/admin");
    await waitForLiveViewReady(page);
    await assertBrandFontsLoaded(page);

    const families = () =>
      page.evaluate(() => {
        const family = (selector: string) =>
          getComputedStyle(document.querySelector(selector)!).fontFamily;
        const shell = document.querySelector(".sg-admin-shell")!;
        return {
          shell: family(".sg-admin-shell"),
          parent: getComputedStyle(shell.parentElement!).fontFamily,
          button: family("#font-probe-button"),
          input: family("#font-probe-input"),
          code: family("#font-probe-code"),
        };
      });

    await page.evaluate(() => {
      const probe = document.createElement("div");
      probe.id = "font-probe";
      probe.innerHTML =
        '<code class="sg-code" id="font-probe-code">0O</code>' +
        '<button class="sg-btn" id="font-probe-button" type="button">Probe</button>' +
        '<input id="font-probe-input" aria-label="probe" />';
      document.querySelector(".sg-admin-shell")!.appendChild(probe);
    });

    try {
      // With the opt-in stylesheet present the shell is Instrument Sans and
      // differs from its parent, so the comparison below can tell the two apart.
      const optedIn = await families();
      expect(optedIn.shell.replace(/["']/g, "")).toMatch(/^Instrument Sans/);
      expect(optedIn.shell, "opted in: the shell differs from its parent").not.toBe(
        optedIn.parent,
      );
      expect(optedIn.code.replace(/["']/g, "")).toMatch(/^Red Hat Mono/);

      // Default tokens: take the opt-in stylesheet off the page.
      await page.evaluate(() => {
        const link = document.querySelector(
          'link[rel="stylesheet"][href*="sigra_admin_brand"]',
        );
        if (!link) throw new Error("the example opt-in stylesheet link is missing");
        (window as unknown as { __brandLink: Element }).__brandLink = link;
        link.remove();
      });
      const defaults = await families();
      expect(defaults.shell, "default: the shell inherits the host face").toBe(
        defaults.parent,
      );
      expect(defaults.button, "default: .sg-btn takes the shell face").toBe(defaults.shell);
      expect(defaults.input, "default: an input takes the shell face").toBe(defaults.shell);
      expect(defaults.code, "default: code.sg-code takes the system mono stack").toContain(
        "ui-monospace",
      );

      // Restore the stylesheet and confirm the opt-in applies again.
      await page.evaluate(
        () =>
          new Promise<void>((resolve) => {
            const link = (window as unknown as { __brandLink: HTMLLinkElement })
              .__brandLink;
            link.addEventListener("load", () => resolve(), { once: true });
            document.head.appendChild(link);
          }),
      );
      const restored = await families();
      expect(restored.shell.replace(/["']/g, "")).toMatch(/^Instrument Sans/);
      await assertBrandFontsLoaded(page);
    } finally {
      await page.evaluate(() => document.getElementById("font-probe")?.remove());
    }
  });

  // UI Considerations: the topbar (96px lockup, Admin label, scope switcher,
  // theme switch) must fit the smallest supported phone widths.
  test("topbar does not overflow at 375 and 390 wide", async ({ page }) => {
    await logInAsPlatformAdmin(page);

    for (const width of [375, 390]) {
      await page.setViewportSize({ width, height: 844 });
      await page.goto("/admin");
      await waitForLiveViewReady(page);

      const fit = await page.evaluate(() => {
        const lockup = document.querySelector(".sg-brand-mark__image--light")!;
        return {
          scrollWidth: document.documentElement.scrollWidth,
          innerWidth: window.innerWidth,
          lockupWidth: lockup.getBoundingClientRect().width,
        };
      });
      expect(fit.scrollWidth, `${width}px: no horizontal page overflow`).toBeLessThanOrEqual(
        fit.innerWidth,
      );
      expect(fit.lockupWidth, `${width}px: the lockup keeps its 96px minimum`).toBeGreaterThanOrEqual(
        96,
      );
    }
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

  test("tone notice and status chip pairs meet WCAG AA in light and dark (axe-skipped soft backgrounds)", async ({
    page,
  }) => {
    // This test covers color pairs that axe skips because the backgrounds are
    // alpha-composited color-mix() values resolved at render time. The four
    // tone notices and the brand-soft metric icon are the critical surfaces.
    await logInAsPlatformAdmin(page);
    await page.goto("/admin/_design");
    await waitForLiveViewReady(page);

    const tones = ["ok", "warn", "risk", "info"] as const;

    // --- Light mode: four tone-on-soft notice pairs ---
    for (const tone of tones) {
      const notice = page.locator(`.sg-notice[data-tone="${tone}"]`).first();
      await expect(notice).toBeVisible();

      await expect
        .poll(async () => {
          const styles = await readNoticeStyles(notice);
          return contrastRatio(styles.color, styles.background);
        })
        .toBeGreaterThanOrEqual(4.5);
    }

    // --- Switch to dark mode ---
    await page.getByRole("radio", { name: "Dark" }).click();
    await expect(page.locator(".sg-admin-shell")).toHaveAttribute(
      "data-theme",
      "dark",
    );

    // --- Dark mode: four tone-on-soft notice pairs ---
    for (const tone of tones) {
      const notice = page.locator(`.sg-notice[data-tone="${tone}"]`).first();
      await expect(notice).toBeVisible();

      await expect
        .poll(async () => {
          const styles = await readNoticeStyles(notice);
          return contrastRatio(styles.color, styles.background);
        })
        .toBeGreaterThanOrEqual(4.5);
    }

    // --- Dark mode: brand-strong text on brand-soft background (metric icon) ---
    // The .sg-metric__icon element uses background: --sg-color-brand-soft and
    // color: --sg-color-brand-strong. Dark brand-strong text on the brand-soft
    // tint, composited over the panel this page reports, must clear 4.5:1.
    // We read the custom-property values on the shell in dark context directly
    // rather than relying on computed element styles, which Chromium reports in
    // oklab format with alpha that our contrastRatio() helper cannot composite
    // reliably. The composited ground is
    //   alpha * brand-soft-rgb + (1 - alpha) * panel-rgb
    // and the ratio is computed from the values the page itself reports, so no
    // colour literal is pinned here.
    const darkTokenPair = await page.evaluate(() => {
      const shell = document.querySelector(".sg-admin-shell");
      if (!shell) throw new Error("No .sg-admin-shell found");
      const cs = getComputedStyle(shell);
      return {
        brandStrong: cs.getPropertyValue("--sg-color-brand-strong").trim(),
        brandSoft: cs.getPropertyValue("--sg-color-brand-soft").trim(),
        panel: cs.getPropertyValue("--sg-color-panel").trim(),
      };
    });

    // The dark brand-strong token is the book's dark accent (kiln-bright in
    // brand/tokens.json, color.dark). The expected hex is read from the book
    // when the check runs; custom properties keep the case they were written
    // in, so the comparison ignores case. Reading nothing fails the test.
    const bookDarkBrandStrong =
      brandTokensJson().color.dark["kiln-bright"].$value.hex;
    expect(darkTokenPair.brandStrong.toLowerCase()).toBe(
      bookDarkBrandStrong.toLowerCase(),
    );

    // Composite the brand-soft tint (parse its alpha) over the panel the page
    // reports, then assert the brand-strong text clears 4.5:1 on that ground.
    const brandSoftRgbaMatch = darkTokenPair.brandSoft.match(
      /rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([\d.]+))?\)/,
    );
    const panelHex = darkTokenPair.panel;
    const panelRgbMatch = panelHex.startsWith("#")
      ? [
          null,
          String(parseInt(panelHex.slice(1, 3), 16)),
          String(parseInt(panelHex.slice(3, 5), 16)),
          String(parseInt(panelHex.slice(5, 7), 16)),
        ]
      : panelHex.match(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/);

    expect(brandSoftRgbaMatch).not.toBeNull();
    expect(panelRgbMatch).not.toBeNull();

    if (brandSoftRgbaMatch && panelRgbMatch) {
      const [, rs, gs, bs, as_] = brandSoftRgbaMatch.map(Number);
      // Number(undefined) is NaN, and `NaN ?? 1` is NaN — guard with isFinite
      // so a colour with no alpha group composites at full opacity.
      const alpha = Number.isFinite(as_) ? as_ : 1;
      const [, rp, gp, bp] = panelRgbMatch.map(Number);
      const cr = Math.round(alpha * rs + (1 - alpha) * rp);
      const cg = Math.round(alpha * gs + (1 - alpha) * gp);
      const cb = Math.round(alpha * bs + (1 - alpha) * bp);
      const compositedBgRgb = `rgb(${cr}, ${cg}, ${cb})`;

      const brandStrongHex = darkTokenPair.brandStrong;
      const brandStrongRgb = brandStrongHex.startsWith("#")
        ? `rgb(${parseInt(brandStrongHex.slice(1, 3), 16)}, ${parseInt(brandStrongHex.slice(3, 5), 16)}, ${parseInt(brandStrongHex.slice(5, 7), 16)})`
        : brandStrongHex;

      const ratio = contrastRatio(brandStrongRgb, compositedBgRgb);
      expect(ratio).toBeGreaterThanOrEqual(4.5);
    }
  });
});
