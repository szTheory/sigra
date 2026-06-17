/**
 * Phase 190 shared flow utilities. Import into admin-flow-*.spec.ts files.
 *
 * Provides: login helpers (pre-seeded demo personas), LiveView readiness,
 * scope chrome assertion, no-flash theme seeding, theme attribute assertions,
 * and reduced-motion CSS-effect assertion.
 *
 * D-10: reducedMotion MUST be set at test.use() context level in the describe
 * block — never call page.emulateMedia({ reducedMotion }) after page.goto
 * (playwright#31328: Firefox drops it after navigation).
 */

import { expect, type Page } from '@playwright/test';

// ---------------------------------------------------------------------------
// Demo persona credentials
// All passwords are public-by-design per personas.ex:12
// ("Never use in production"). Dev server only.
// ---------------------------------------------------------------------------

/** Platform admin persona email. */
export const DEMO_ADMIN_EMAIL = 'admin@demo.vaultr.test';

/** Platform admin persona password. */
export const DEMO_ADMIN_PASSWORD = 'DemoAdmin1!SecurePass';

/** Org admin persona email (morgan — scoped to Acme Corp). */
export const DEMO_MORGAN_EMAIL = 'morgan@demo.vaultr.test';

/** Org admin persona password. */
export const DEMO_MORGAN_PASSWORD = 'MorganDemo1!OrgAdmin';

// ---------------------------------------------------------------------------
// LiveView readiness
// ---------------------------------------------------------------------------

/**
 * Waits for any LiveView on the page to finish mounting (phx-connected).
 *
 * NOTE: do NOT call this on `/users/log_in` — that page is a plain controller
 * page, not a LiveView. Call it only after navigating to LiveView routes
 * (e.g. `/admin`, `/admin/users`, `/users/register`).
 */
export async function waitForLiveViewReady(page: Page): Promise<void> {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}

// ---------------------------------------------------------------------------
// Login helpers — pre-seeded demo personas
// ---------------------------------------------------------------------------

/**
 * Logs in as any pre-seeded demo persona using the password login form.
 *
 * The login page `/users/log_in` is a plain controller page (not a LiveView)
 * so waitForLiveViewReady is NOT called here. The form is submitted directly.
 *
 * No MFA challenge fires: the example app has no `mfa.check_fn` configured,
 * so Sigra creates a `:standard` session for all personas, including those
 * with TOTP enrolled (e.g. admin@demo.vaultr.test). This is safe to rely on
 * in all nine demo personas.
 */
export async function loginDemoUser(
  page: Page,
  email: string,
  password: string,
): Promise<void> {
  // /users/log_in is a plain controller page (not a LiveView) — do NOT call
  // waitForLiveViewReady here. Fill the form directly and submit.
  await page.goto('/users/log_in');
  // The login page has multiple forms (passkey, magic link, password).
  // Scope fills to #login_form to target the password form specifically.
  await page.fill('#login_form input[name="user[email]"]', email);
  await page.fill('#login_form input[name="user[password]"]', password);
  await page.click('#login_form button:has-text("Log in")');
  // No MFA challenge — example app creates a :standard session without check_fn.
  await expect(page).not.toHaveURL(/\/users\/log_in/);
}

/**
 * Logs in as the platform admin persona (admin@demo.vaultr.test).
 *
 * Convenience wrapper around loginDemoUser using DEMO_ADMIN_EMAIL and
 * DEMO_ADMIN_PASSWORD. The admin persona has TOTP enrolled but no
 * mfa.check_fn is configured, so login creates a :standard session directly.
 */
export async function loginDemoAdmin(page: Page): Promise<void> {
  await loginDemoUser(page, DEMO_ADMIN_EMAIL, DEMO_ADMIN_PASSWORD);
}

/**
 * Logs in as the org admin persona (morgan@demo.vaultr.test, Acme Corp).
 *
 * Convenience wrapper around loginDemoUser using DEMO_MORGAN_EMAIL and
 * DEMO_MORGAN_PASSWORD. Morgan has org-scoped admin access only — attempting
 * to access /admin (platform scope) returns 403.
 */
export async function loginDemoMorgan(page: Page): Promise<void> {
  await loginDemoUser(page, DEMO_MORGAN_EMAIL, DEMO_MORGAN_PASSWORD);
}

// ---------------------------------------------------------------------------
// Admin scope chrome assertion
// ---------------------------------------------------------------------------

/**
 * Asserts the admin scope ribbon ("chrome") is visible in the page header.
 *
 * Locates the first `header` element and asserts it contains the literal
 * text "Admin" (exact match) and the `scopeLabel` text (substring match).
 *
 * Usage:
 *   - `await assertScopeChrome(page, 'Global')` — platform admin global posture
 *   - `await assertScopeChrome(page, 'Acme Corp')` — org-scoped admin posture
 *
 * Source: admin-user-operations.spec.ts:62-69 (`expectScopeChrome`).
 */
export async function assertScopeChrome(
  page: Page,
  scopeLabel: string,
): Promise<void> {
  const header = page.locator('header').first();
  await expect(header.getByText('Admin', { exact: true })).toBeVisible();
  // Org scope renders a tenant-marked chip ("Org · {name}"); global stays "Global".
  // Substring match keeps the scope label assertion robust to that prefix/glyph.
  await expect(header.getByText(scopeLabel, { exact: false }).first()).toBeVisible();
}

// ---------------------------------------------------------------------------
// Theme: no-flash seed + attribute assertions
// ---------------------------------------------------------------------------

/**
 * Seeds localStorage with the given theme BEFORE navigation and asserts the
 * inline applyTheme script in admin_shell.ex fires synchronously before paint.
 *
 * Implementation:
 *   1. Calls page.addInitScript to write `sigra.admin.theme` to localStorage
 *      (runs before any page JS, including the inline script).
 *   2. Navigates to /admin.
 *   3. Asserts `html[data-sg-admin-theme]` equals the theme — proving the
 *      synchronous inline `<script>` block in admin_shell.ex:24-42 applied
 *      the theme before paint (no flash of unstyled content / FOUC).
 *
 * NOTE: The script being asserted is the inline `<script>` block embedded in
 * the admin_shell.ex template (admin_shell.ex:24-42), NOT a `<script src>`
 * element served from admin_hooks.js. The inline script runs synchronously
 * during HTML parsing — before any deferred or async JS.
 *
 * Source: admin-theme.spec.ts:364-394.
 */
export async function seedThemeAndAssertNoFlash(
  page: Page,
  theme: 'dark' | 'light',
): Promise<void> {
  await page.addInitScript((t) => {
    window.localStorage.setItem('sigra.admin.theme', t);
  }, theme);
  await page.goto('/admin');
  await expect(page.locator('html')).toHaveAttribute('data-sg-admin-theme', theme);
}

/**
 * Asserts that the admin shell theme attributes and localStorage state match
 * the expected theme value.
 *
 * For `'dark'` or `'light'`:
 *   - `.sg-admin-shell[data-theme]` equals theme
 *   - `html[data-sg-admin-theme]` equals theme
 *   - `localStorage.getItem("sigra.admin.theme")` equals theme
 *
 * For `'system'`:
 *   - `html[data-sg-admin-theme-preference]` equals `"system"` (the user's
 *      recorded selection — this is the source of truth for the preference)
 *   - `html` does NOT have `data-sg-admin-theme` (the resolved-theme attribute
 *      is only emitted for explicit light/dark; in system mode the page follows
 *      the OS scheme via CSS so no resolved override is written)
 *   - `.sg-admin-shell` does NOT have `data-theme` (same rationale)
 *   - `localStorage.getItem("sigra.admin.theme")` equals `"system"`
 *
 * NOTE: The live app ALWAYS sets `data-sg-admin-theme` to the RESOLVED theme for
 * explicit light/dark choices, and records the user's selection separately in
 * `data-sg-admin-theme-preference`. The `system` preference is therefore verified
 * via the preference attribute + the ABSENCE of an explicit resolved override.
 *
 * Uses web-first auto-retrying `expect(locator).toHaveAttribute(...)` for
 * theme assertions — never toHaveCSS (computed colors vary by OS).
 *
 * Source: admin-theme.spec.ts:415-479; live DOM model verified against the
 * running example server (data-sg-admin-theme-preference="system").
 */
export async function assertThemeAttributes(
  page: Page,
  theme: 'dark' | 'light' | 'system',
): Promise<void> {
  if (theme === 'system') {
    // System preference is recorded in the dedicated preference attribute.
    await expect(page.locator('html')).toHaveAttribute(
      'data-sg-admin-theme-preference',
      'system',
    );
    // No explicit resolved-theme override is emitted in system mode.
    await expect(page.locator('html')).not.toHaveAttribute(
      'data-sg-admin-theme',
      /.+/,
    );
    await expect(page.locator('.sg-admin-shell')).not.toHaveAttribute(
      'data-theme',
      /.+/,
    );
    expect(
      await page.evaluate(() => localStorage.getItem('sigra.admin.theme')),
    ).toBe('system');
  } else {
    await expect(page.locator('.sg-admin-shell')).toHaveAttribute(
      'data-theme',
      theme,
    );
    await expect(page.locator('html')).toHaveAttribute(
      'data-sg-admin-theme',
      theme,
    );
    expect(
      await page.evaluate(() => localStorage.getItem('sigra.admin.theme')),
    ).toBe(theme);
  }
}

// ---------------------------------------------------------------------------
// Reduced-motion CSS-effect assertion (D-10)
// ---------------------------------------------------------------------------

/**
 * Asserts that the `@media (prefers-reduced-motion: reduce)` guard in
 * sigra_admin.css:1467 has collapsed the loading bar animation to `none`.
 *
 * The guard sets `animation: none !important` on `.sg-admin-loading-bar::before`.
 * This function evaluates `window.getComputedStyle` on the element for the
 * `::before` pseudo-element and asserts `animationName` is `'none'`.
 *
 * This is a CSS-effect assertion (verifying the browser applied the media
 * query), NOT just a `matchMedia().matches` assertion.
 *
 * IMPORTANT: This function MUST be called AFTER `test.use({ reducedMotion: 'reduce' })`
 * is set at the describe-block level. Never call `page.emulateMedia` after
 * `page.goto` — Firefox drops it after navigation (playwright#31328).
 *
 * Source: 190-PATTERNS.md D-10 section; sigra_admin.css:1467-1484.
 */
export async function assertReducedMotionEffect(page: Page): Promise<void> {
  const animName = await page.locator('.sg-admin-loading-bar').evaluate((el) =>
    window.getComputedStyle(el, '::before').animationName,
  );
  expect(animName).toBe('none');
}
