# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: admin-checkpoints.spec.ts >> Phase 31 admin checkpoint inventory (D-28) >> captures curated admin review pages across desktop/mobile/dark
- Location: tests/admin-checkpoints.spec.ts:172:7

# Error details

```
TimeoutError: page.waitForSelector: Timeout 15000ms exceeded.
Call log:
  - waiting for locator('[data-phx-session].phx-connected')
    - waiting for" http://localhost:4002/users/register" navigation to finish...

```

# Page snapshot

```yaml
- generic [ref=e3]:
  - banner [ref=e4]:
    - generic [ref=e5]:
      - heading "Register" [level=1] [ref=e6]
      - paragraph [ref=e7]:
        - text: Already registered?
        - link "Log in" [ref=e8]:
          - /url: /users/log_in
        - text: to your account now.
  - generic [ref=e9]:
    - generic [ref=e11]:
      - generic [ref=e12]: Email
      - textbox "Email" [ref=e13]
    - generic [ref=e15]:
      - generic [ref=e16]: Password
      - textbox "Password" [ref=e17]
    - generic [ref=e18]:
      - checkbox "Add a passkey after creating your account After confirming your email, you will continue to passkey setup." [ref=e19] [cursor=pointer]
      - generic [ref=e20]:
        - text: Add a passkey after creating your account
        - generic [ref=e21]: After confirming your email, you will continue to passkey setup.
    - button "Create an account" [ref=e22] [cursor=pointer]:
      - text: Create an account
      - generic [ref=e23]: →
```

# Test source

```ts
  1   | import { statSync } from 'node:fs';
  2   | import AxeBuilder from '@axe-core/playwright';
  3   | import { test, expect, type Page, type TestInfo } from '@playwright/test';
  4   | import { captureAdminCheckpoint } from '../helpers/adminArtifacts';
  5   | import { adminUsersEmailLocator } from '../helpers/adminUsersIndex';
  6   | import { TEST_PASSWORD } from '../helpers/fixtures';
  7   | 
  8   | // Phase 31 Plan 2: curated admin checkpoint spec.
  9   | //
  10  | // Per D-04, D-19, D-20, D-25, D-26, D-27, D-28, D-29, and D-30 this spec
  11  | // captures the eight required reviewer pages as explicit screenshots so the
  12  | // Playwright HTML report becomes asynchronously reviewable on green runs
  13  | // without widening the behavior suite across every viewport/theme:
  14  | //
  15  | //   1. Global overview                                 (/admin)
  16  | //   2. Org overview                                    (/admin/organizations/:slug)
  17  | //   3. Global user index                               (/admin/users)
  18  | //   4. User detail                                     (/admin/users/:id)
  19  | //   5. Organization-scoped admin page                  (/admin/organizations/:slug/users)
  20  | //   6. Active impersonation banner on a non-admin
  21  | //      page (the impersonated user's org members view) (/organizations/:slug/members)
  22  | //   7. Per-user audit                                  (/admin/users/:id/audit)
  23  | //   8. Audit explorer                                  (/admin/audit?...)
  24  | //
  25  | // This spec runs in exactly three partitioned projects configured by
  26  | // `playwright.config.ts` (D-27, D-29):
  27  | //
  28  | //   * admin-checkpoints-chromium — desktop reviewer artifacts
  29  | //   * admin-checkpoints-mobile   — mobile reviewer artifacts (iPhone 13 device)
  30  | //   * admin-checkpoints-dark     — dark-mode reviewer artifacts
  31  | //
  32  | // Per D-25 and D-30 we attach explicit screenshots through
  33  | // `captureAdminCheckpoint(...)` — we do NOT adopt a full visual-baseline
  34  | // regime and we do NOT retain whole-run raw Playwright output
  35  | // indiscriminately. Per D-06 this spec does NOT assert denial /
  36  | // forbidden / malformed-param / authorization-permutation paths; those
  37  | // remain in ExUnit and targeted HTTP smoke.
  38  | //
  39  | // LiveView + longpoll means each navigation is relatively slow; we keep the
  40  | // spec to a single test per project so fixtures are seeded once and the five
  41  | // pages are captured in one authenticated journey.
  42  | 
  43  | async function waitForLiveViewReady(page: Page) {
> 44  |   await page.waitForSelector('[data-phx-session].phx-connected', {
      |              ^ TimeoutError: page.waitForSelector: Timeout 15000ms exceeded.
  45  |     state: 'attached',
  46  |   });
  47  | }
  48  | 
  49  | async function registerUser(page: Page, email: string, password: string) {
  50  |   await page.goto('/users/register');
  51  |   await waitForLiveViewReady(page);
  52  |   await page.fill('input[name="user[email]"]', email);
  53  |   await page.fill('input[name="user[password]"]', password);
  54  |   await page.locator('form:has(input[name="user[password]"])').first().evaluate((form) => {
  55  |     (form as HTMLFormElement).requestSubmit();
  56  |   });
  57  |   await expect(page).not.toHaveURL(/\/users\/register/);
  58  | }
  59  | 
  60  | async function clearBrowserSession(page: Page) {
  61  |   await page.context().clearCookies();
  62  | }
  63  | 
  64  | async function createOrganization(page: Page, name: string, slug: string) {
  65  |   await page.goto('/organizations');
  66  |   await waitForLiveViewReady(page);
  67  |   await page.fill('input[name="organization[name]"]', name);
  68  |   await expect(page.locator('#slug-preview')).toHaveText(slug);
  69  |   await page.click('button:has-text("Create organization")');
  70  |   await expect(page).toHaveURL(new RegExp(`/organizations/${slug}/members$`));
  71  |   await waitForLiveViewReady(page);
  72  | }
  73  | 
  74  | async function openUserDetail(page: Page, targetEmail: string) {
  75  |   await page.goto(`/admin/users?q=${encodeURIComponent(targetEmail)}`);
  76  |   await waitForLiveViewReady(page);
  77  |   await expect(adminUsersEmailLocator(page, targetEmail)).toBeVisible();
  78  |   await page.getByRole('link', { name: 'Open user' }).first().click();
  79  |   await waitForLiveViewReady(page);
  80  |   await expect(page).toHaveURL(/\/admin\/users\/[^?]+/);
  81  | }
  82  | 
  83  | async function confirmSudo(page: Page, password: string) {
  84  |   await expect(page).toHaveURL(/\/users\/sudo\?/);
  85  |   await page.fill('input[name="sudo[password]"]', password);
  86  |   await page.getByRole('button', { name: 'Confirm password' }).click();
  87  | }
  88  | 
  89  | /**
  90  |  * Capture a curated admin checkpoint AND assert the artifact was actually
  91  |  * written to disk and is non-empty. The assertion turns D-19/D-20 from an
  92  |  * implicit promise ("we call the helper") into an explicit contract
  93  |  * ("the reviewer artifact exists for every shipped checkpoint page"),
  94  |  * catching regressions in the helper, project partitioning, or Playwright
  95  |  * output plumbing before they ship as silently-missing attachments.
  96  |  */
  97  | async function captureAndVerify(
  98  |   page: Page,
  99  |   testInfo: TestInfo,
  100 |   name: string,
  101 | ): Promise<void> {
  102 |   // Use viewport-only capture (fullPage: false) to avoid the 32767px hard limit
  103 |   // imposed by Playwright/Chrome on full-page screenshots. The global-user-index
  104 |   // checkpoint navigates to the unfiltered /admin/users list (100+ users), which
  105 |   // can exceed this limit on mobile. Viewport-only is sufficient for human review
  106 |   // artifacts — assertCheckpointScreenshot handles the baseline comparison
  107 |   // separately and also uses fullPage: false.
  108 |   const filePath = await captureAdminCheckpoint(page, testInfo, { name, fullPage: false });
  109 |   const stats = statSync(filePath);
  110 |   expect(
  111 |     stats.isFile(),
  112 |     `Expected curated checkpoint ${name} to land at ${filePath}`,
  113 |   ).toBe(true);
  114 |   expect(
  115 |     stats.size,
  116 |     `Expected curated checkpoint ${name} to be a non-empty PNG`,
  117 |   ).toBeGreaterThan(0);
  118 | }
  119 | 
  120 | /** Phase 35: axe a11y gate paired with each curated checkpoint capture. */
  121 | async function assertNoAxeViolations(page: Page, label: string) {
  122 |   // Scope to the full WCAG 2.1/2.2 AA tag set (EN 301 549 legal floor) so the
  123 |   // gate is literally defensible against modern accessibility standards (D-07).
  124 |   // The axe `best_practice` tag-group is intentionally excluded (D-09): rules
  125 |   // like `region` (full-page landmark wrapping) would fail on the admin shell's
  126 |   // `<header>` layout, which is intentional Phoenix/LiveView structure rather
  127 |   // than a shipped WCAG regression signal for this lane.
  128 |   //
  129 |   // D-08: `target-size` (wcag22aa/2.5.8) is suppressed because the admin
  130 |   // filter form uses intentionally dense sg-select and sg-bottom-nav controls
  131 |   // whose compact sizing is accepted by the admin-design-contract.md.
  132 |   // All other WCAG 2.2 AA rules remain active — this is a single-rule carve-out,
  133 |   // not a wholesale 2.2 tag drop.
  134 |   const { violations } = await new AxeBuilder({ page })
  135 |     .withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa'])
  136 |     .disableRules(['target-size'])
  137 |     .analyze();
  138 |   const detail =
  139 |     violations.length === 0 ? '' : JSON.stringify(violations).slice(0, 2000);
  140 |   expect(violations, `${label}: axe violations\n${detail}`).toHaveLength(0);
  141 | }
  142 | 
  143 | /**
  144 |  * Phase 35: committed `toHaveScreenshot` baselines (5 checkpoints × 3 projects).
```