# Phase 143: Playwright Demo Spec & Screenshots — Research

**Researched:** 2026-05-30
**Domain:** Playwright TypeScript spec authoring, Phoenix LiveView authentication flows, TOTP challenge handling, committed screenshot baselines
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Playwright Project Partition (PW-01)**
- D-01: Add `DEMO_SHOWCASE_SPEC = /demo-showcase\.spec\.ts/` regex constant to `playwright.config.ts` — same shape as `ADMIN_CHECKPOINTS_SPEC` and `ADMIN_GENERATED_SPEC`.
- D-02: Add `demo-showcase-chromium` project entry using `testMatch: DEMO_SHOWCASE_SPEC` with `use: { ...devices['Desktop Chrome'] }`. Single desktop chromium project only — no mobile or dark variants.
- D-03: Add `DEMO_SHOWCASE_SPEC` to `testIgnore` on BOTH the `chromium` and `mobile` projects — same isolation as `ADMIN_CHECKPOINTS_SPEC` and `ADMIN_GENERATED_SPEC`.
- D-04: New spec file lives at `tests/demo-showcase.spec.ts`. Global config already enforces `workers: 1, fullyParallel: false`.

**Persona Auth Assertions (PW-01)**
- D-05: Assert each seeded persona's presence via `data-testid="demo-persona-row-{local}"` on `/demo/credentials`.
- D-06: For admin-page persona assertions, use structural email-based locators on `#admin-users-desktop-results` rows. Do NOT assert on display-name text strings.
- D-07: The spec logs in as the `admin@demo.sigra.dev` persona to access admin pages. Password: `DemoAdmin1!SecurePass`.

**Screenshot Capture (PW-02)**
- D-08: Use the `assertCheckpointScreenshot`-style `toHaveScreenshot` pattern from `admin-checkpoints.spec.ts` (lines 129–144): `fullPage: false`, viewport capture only, CI-aware `maxDiffPixels`/`maxDiffPixelRatio` tolerances.
- D-09: Committed screenshot baselines live under `tests/demo-showcase.spec.ts-snapshots/` with filenames `{slug}-demo-showcase-chromium.png`.
- D-10: Required screenshot surfaces (SC#3, amended): `demo-credentials`, `admin-user-list`, `admin-user-detail` (MFA row + passkey row only, no API-token row), `audit-explorer`.

**Seeds-Smoke (PW-03)**
- D-11: PW-03 is satisfied by the existing `test/example/test/example/demo/seeds_test.exs`. No new test code needed.
- D-12: Phase 143's PW-03 implementation is adding `# PW-03: seeds-smoke check` doc comments to the `seeds_test.exs` describe blocks.
- D-13: No CI config changes needed for PW-03.

### Claude's Discretion
- The specific password string for `admin@demo.sigra.dev` — read from `Example.Demo.Personas.all()` at plan time. **Confirmed:** `DemoAdmin1!SecurePass`.
- Whether to extract an `assertDemoScreenshot` helper or inline `toHaveScreenshot` calls. Follow checkpoint pattern if reuse warranted; inline is fine for 4 captures.
- The `maxDiffPixels` tolerance values — use the same CI-aware formula from `admin-checkpoints.spec.ts`.

### Deferred Ideas (OUT OF SCOPE)
- Mobile/dark variants of demo-showcase screenshots.
- Admin user detail screenshot for non-admin personas.
- `2026-05-28-phase-135-review-deferred-findings.md` — Threadline upstream.
- `2026-05-29-deprecation-since-vs-removal-version-axis.md` — lib/sigra deprecation.
- `2026-05-29-phase-138-doctor-info-findings.md` — Doctor Info findings.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PW-01 | A Playwright demo spec exercises the seeded personas' auth states using structural assertions (`data-testid` / auth-state, not brittle persona-name matching), in its own Playwright project partition, leaving the golden-path specs unaffected. | `playwright.config.ts` partition pattern confirmed; `demo-persona-row-{local}` testids confirmed in `credentials_live.ex`; `adminUsersEmailLocator` helper confirmed for admin-page assertions |
| PW-02 | Evaluator-facing screenshots are captured via the existing Playwright capture infrastructure, covering key surfaces (login, admin user list, audit log, MFA, organization switcher). | `toHaveScreenshot` baseline pattern confirmed from `admin-checkpoints.spec.ts:129-144`; `pathTemplate` config confirmed OS-suffix-free; CI tolerance values confirmed |
| PW-03 | A seeds-smoke check proves the seeds are idempotent and each persona's auth state is verifiable, guarding CI against seed/schema drift. | `test/example/test/example/demo/seeds_test.exs` confirmed covers all PW-03 acceptance criteria — idempotency (line 89), dave.locked_at (line 130), frank.scheduled_deletion_at (line 138), 6 personas, 6+ distinct audit actions |
</phase_requirements>

---

## Summary

Phase 143 adds a `demo-showcase-chromium` Playwright project partition and a single spec (`tests/demo-showcase.spec.ts`) that exercises the seeded demo personas and captures four committed PNG baselines. The spec is isolated from the golden-path lanes via `testIgnore` — identical to the existing `ADMIN_CHECKPOINTS_SPEC` and `ADMIN_GENERATED_SPEC` isolation pattern. PW-03 (seeds-smoke) is already covered by the existing `seeds_test.exs`; the plan only needs a comment cross-reference.

Two implementation gaps require explicit plan tasks beyond what the CONTEXT assumes:

1. **`SigraAdminPolicy` does not grant platform-admin to `admin@demo.sigra.dev`** — the current policy only grants it to emails starting with `platform-admin+`. The CONTEXT treats admin access as given, but direct inspection confirms the gap. The `SigraAdminPolicy` must be extended to also grant platform-admin to the seeded admin email. [VERIFIED: direct codebase inspection]

2. **CI does not run seeds before Playwright** — the `example_playwright_smoke` CI job runs `mix ecto.create && mix ecto.migrate` but does NOT run `mix run priv/repo/seeds.exs`. The demo-showcase spec asserts against seeded personas, so CI must run seeds (`MIX_ENV=dev mix run priv/repo/seeds.exs`) after migrate and before booting the server (or before the demo-showcase project step). [VERIFIED: direct codebase inspection]

Additionally, `admin@demo.sigra.dev` has TOTP enrolled (`mfa.ex` line 1924: login with MFA sets session type `:mfa_pending`), so the spec must complete the TOTP challenge after password login. The demo TOTP secret is deterministic and its base32 encoding is confirmed: `CSIL7ZDJ7RGXDGXRGIV3Q6CZIBOESTCW` — verified to produce valid codes via otplib in the Playwright node environment.

**Primary recommendation:** Add two tasks to Wave 0 — extend `SigraAdminPolicy` and add a seeds step to CI — then implement the spec in one task.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Playwright partition config | Test infrastructure (playwright.config.ts) | — | Project isolation lives in the config, not the spec |
| Persona auth assertions | Playwright spec (browser layer) | ExUnit (seeds_test.exs) | Browser assertions prove UI surface; ExUnit proves DB state |
| TOTP challenge completion | Playwright spec | MFAChallengeLive (backend) | Spec must drive the challenge UI; LV owns verification logic |
| Screenshot baseline capture | Playwright spec | CI artifact upload | Spec writes committed PNG; CI uploads report artifacts |
| Seeds-smoke (PW-03) | ExUnit (seeds_test.exs) | CI (mix test alias) | Already covered; just needs comment cross-reference |
| Admin policy (platform-admin) | `SigraAdminPolicy` (host app) | — | Policy is host-app-owned; must be extended explicitly |
| Demo DB seeding in CI | CI workflow (ci.yml) | mix alias (seeds.exs) | CI must run seeds as a pre-flight step before demo-showcase |

---

## Standard Stack

### Core (already in project — no new installs)

| Library | Version | Purpose | Notes |
|---------|---------|---------|-------|
| `@playwright/test` | `^1.48.0` | Test runner, `toHaveScreenshot`, project partitioning | Already in `package.json` devDependencies |
| `otplib` | `^12.0.1` | TOTP code generation for MFA challenge | Already in `package.json` devDependencies |

### No new packages

This phase installs no new packages. All required libraries are already present in `test/example/priv/playwright/package.json`.

---

## Package Legitimacy Audit

No packages to audit — phase installs no new dependencies.

---

## Architecture Patterns

### System Architecture Diagram

```
[Playwright Runner: demo-showcase-chromium]
          |
          v
[/demo/credentials] ──── screenshot: demo-credentials ──────────────────┐
          |                                                               |
          v                                                               |
[/users/log_in] ──── fill email + password ──────────────────────────── |
          |                                                               |
          v (session type: :mfa_pending because TOTP enrolled)           |
[/users/mfa] ──── fill #mfa_totp_code (otplib.generate(DEMO_B32)) ───── |
          |                                                               |
          v (auto-verify fires → redirect to "/")                        |
[/admin/users?q=@demo.sigra.dev] ──── screenshot: admin-user-list ───── |
          |                                                               |
          v (click "Open user" for admin persona)                        |
[/admin/users/{admin-id}] ──── screenshot: admin-user-detail ─────────  |
          |                                                               |
          v                                                               |
[/admin/audit] ──── screenshot: audit-explorer ───────────────────────── |
          |                                                               |
          v (committed baselines)                                         |
[tests/demo-showcase.spec.ts-snapshots/]                                 |
  demo-credentials-demo-showcase-chromium.png ◄────────────────────────┘
  admin-user-list-demo-showcase-chromium.png
  admin-user-detail-demo-showcase-chromium.png
  audit-explorer-demo-showcase-chromium.png
```

### Recommended Project Structure

```
test/example/
├── lib/example/sigra_admin_policy.ex   # MODIFIED: add demo admin grant
├── priv/playwright/
│   ├── playwright.config.ts            # MODIFIED: add demo-showcase project
│   └── tests/
│       ├── demo-showcase.spec.ts       # NEW: demo spec
│       └── demo-showcase.spec.ts-snapshots/   # NEW: committed PNG baselines
│           ├── demo-credentials-demo-showcase-chromium.png
│           ├── admin-user-list-demo-showcase-chromium.png
│           ├── admin-user-detail-demo-showcase-chromium.png
│           └── audit-explorer-demo-showcase-chromium.png
├── test/example/demo/
│   └── seeds_test.exs                  # MODIFIED: add PW-03 comment cross-ref
└── .github/workflows/ci.yml           # MODIFIED: add seeds step before demo-showcase
```

### Pattern 1: Playwright Project Partition (established, follow exactly)

**What:** A regex constant + `testMatch`/`testIgnore` pair that isolates a spec to exactly one project lane.

**When to use:** Any spec that must not run in the behavior-truth lanes.

```typescript
// Source: test/example/priv/playwright/playwright.config.ts (existing pattern)
const ADMIN_CHECKPOINTS_SPEC = /admin-checkpoints\.spec\.ts/;
// → add analogously:
const DEMO_SHOWCASE_SPEC = /demo-showcase\.spec\.ts/;

// In projects array:
{
  name: 'chromium',
  testIgnore: [ADMIN_CHECKPOINTS_SPEC, ADMIN_GENERATED_SPEC, DEMO_SHOWCASE_SPEC],
  use: { ...devices['Desktop Chrome'] },
},
{
  name: 'mobile',
  testIgnore: [
    ADMIN_BEHAVIOR_SPECS,
    ADMIN_CHECKPOINTS_SPEC,
    ADMIN_GENERATED_SPEC,
    WEBAUTHN_CDP_SPECS,
    DEMO_SHOWCASE_SPEC,    // add here too
  ],
  use: { ...devices['iPhone 13'] },
},
{
  name: 'demo-showcase-chromium',
  testMatch: DEMO_SHOWCASE_SPEC,
  use: { ...devices['Desktop Chrome'] },
},
```

### Pattern 2: Screenshot Baseline with CI Tolerance (established, copy exactly)

**What:** `toHaveScreenshot` with viewport-only capture and CI-aware pixel tolerance.

**When to use:** Committed PNG baselines that must not fail on Linux CI vs macOS local.

```typescript
// Source: test/example/priv/playwright/tests/admin-checkpoints.spec.ts:129-144
async function assertDemoScreenshot(page: Page, testInfo: TestInfo, slug: string) {
  const ci = process.env.CI === 'true';
  await expect(page).toHaveScreenshot(`${slug}.png`, {
    fullPage: false,
    maxDiffPixels: ci ? 200_000 : 30_000,
    maxDiffPixelRatio: ci ? 0.22 : 0.06,
  });
}
// Note: no axe assertions — those are for the admin-checkpoints lane (Phase 35),
// not required by PW-02. Keep demo-showcase lean.
```

### Pattern 3: Login + TOTP Challenge for Demo Admin Persona

**What:** Password login for a user with TOTP enrolled triggers an `:mfa_pending` session, requiring the TOTP challenge before any admin route is accessible.

**When to use:** Any spec logging in as `admin@demo.sigra.dev` (or `bob@demo.sigra.dev`).

```typescript
// Source: verified via direct inspection of mfa_challenge_live.ex + auth.ex:1924
import { authenticator } from 'otplib';

// Deterministic demo TOTP secret — base32 of SHA-256("sigra-demo-admin-totp-v1") first 20 bytes
// Computed and verified: authenticator.generate(DEMO_TOTP_B32) produces a valid 6-digit code.
const DEMO_TOTP_B32 = 'CSIL7ZDJ7RGXDGXRGIV3Q6CZIBOESTCW';

async function loginDemoAdmin(page: Page) {
  // 1. Password login
  await page.goto('/users/log_in');
  await page.fill('#login_form input[name="user[email]"]', 'admin@demo.sigra.dev');
  await page.fill('#login_form input[name="user[password]"]', 'DemoAdmin1!SecurePass');
  await page.click('#login_form button:has-text("Log in")');

  // 2. Handle TOTP challenge — auto-verifies on 6 digits (phx-change="validate_totp")
  await expect(page).toHaveURL(/\/users\/mfa/);
  await page.waitForSelector('[data-phx-session].phx-connected', { state: 'attached' });
  // Switch to TOTP tab — admin has 1 passkey so active_method defaults to 'passkey'
  await page.click('button[phx-click="show_totp"]');
  await page.waitForSelector('#mfa_totp_code', { state: 'visible' });
  const code = authenticator.generate(DEMO_TOTP_B32);
  await page.fill('#mfa_totp_code', code);

  // 3. Auto-verify redirects to "/" — navigate to admin pages from there
  await expect(page).not.toHaveURL(/\/users\/mfa/);
}
```

**Critical note:** After TOTP auto-verify, MFAChallengeLive redirects to `"/"` (hardcoded, not to `mfa_return_to`). The spec must navigate to `/admin/*` explicitly after calling `loginDemoAdmin`.

### Pattern 4: Email-Based Admin User List Locator (established, reuse)

```typescript
// Source: test/example/priv/playwright/helpers/adminUsersIndex.ts
import { adminUsersEmailLocator } from '../helpers/adminUsersIndex';
// Usage: assert each of the 6 demo personas visible by email
const demoEmails = [
  'admin@demo.sigra.dev', 'alice@demo.sigra.dev', 'bob@demo.sigra.dev',
  'carol@demo.sigra.dev', 'dave@demo.sigra.dev', 'frank@demo.sigra.dev',
];
// Navigate to /admin/users?q=demo.sigra.dev to scope results to demo domain
await page.goto('/admin/users?q=demo.sigra.dev');
await waitForLiveViewReady(page);
for (const email of demoEmails) {
  await expect(adminUsersEmailLocator(page, email)).toBeVisible();
}
```

### Pattern 5: SigraAdminPolicy Extension for Demo Admin

**What:** `SigraAdminPolicy.platform_admin?/1` currently only returns `true` for emails starting with `platform-admin+`. The demo admin persona (`admin@demo.sigra.dev`) needs platform-admin access.

**Resolution:** Add an explicit allowlist clause for the demo admin email. This is a host-app module, safe to customize.

```elixir
# Source: test/example/lib/example/sigra_admin_policy.ex (current)
@platform_admin_prefix "platform-admin+"
@demo_admin_email "admin@demo.sigra.dev"   # ADD

@impl true
def platform_admin?(%{user: %{email: email}}) when is_binary(email) do
  String.starts_with?(email, @platform_admin_prefix) or email == @demo_admin_email  # MODIFY
end
```

### Anti-Patterns to Avoid

- **Asserting on display-name text:** `"Admin (operator)"`, `"Alice"`, etc. are brittle. Use `data-testid="demo-persona-row-{local}"` or email-based locators.
- **Navigating to `/admin/users` immediately after login:** The TOTP challenge intercepts first. Always check for and complete the MFA challenge before accessing admin routes.
- **Generating a TOTP code from a raw binary secret:** `otplib` requires base32 encoding. The raw binary (`Personas.demo_totp_secret/0`) must be base32-encoded first. The computed value `CSIL7ZDJ7RGXDGXRGIV3Q6CZIBOESTCW` is verified correct.
- **Registering a new `platform-admin+` user for the demo spec:** The spec must use the seeded `admin@demo.sigra.dev` persona — it is the evaluator-visible demo admin with real TOTP/passkey data.
- **Running the demo-showcase project before seeding the database:** CI currently does `ecto.create && ecto.migrate` but not `run priv/repo/seeds.exs`. The CI step must be added.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| TOTP code generation | Custom SHA-1/HOTP implementation | `otplib` (already installed) | RFC 6238 has time-window edge cases; otplib handles step alignment |
| Screenshot diffing | Manual pixel comparison | `toHaveScreenshot` with `maxDiffPixels` | Playwright handles CI vs local font rasterization diff |
| Admin user row locator | Custom CSS/XPath selector | `adminUsersEmailLocator` helper | Handles dual desktop/mobile DOM layout, Tailwind visibility, strict mode |

**Key insight:** All required infrastructure already exists — the spec is 90% copy-adapt from `admin-checkpoints.spec.ts`.

---

## Common Pitfalls

### Pitfall 1: `admin@demo.sigra.dev` Cannot Access `/admin/*` Without Policy Change

**What goes wrong:** Spec logs in as `admin@demo.sigra.dev`, completes TOTP, navigates to `/admin/users`, and gets redirected or receives a 403 because `SigraAdminPolicy.platform_admin?/1` returns `false` for this email.

**Why it happens:** `SigraAdminPolicy` only matches the `platform-admin+` email prefix. The demo admin email does not match. This gap is NOT currently closed — CONTEXT.md's claim "grants platform-admin... OR the seeded admin persona" is an [ASSUMED] design intent, not an implemented fact. [VERIFIED: direct inspection of `lib/example/sigra_admin_policy.ex`]

**How to avoid:** Wave 0 must include a task to extend `SigraAdminPolicy.platform_admin?/1` to also return `true` for `email == "admin@demo.sigra.dev"`.

**Warning signs:** `page.goto('/admin/users')` redirects to `/users/log_in` or `AuthErrorHandler` renders 403.

### Pitfall 2: CI Demo-Showcase Fails on Unseeded Database

**What goes wrong:** `npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium` runs in CI against a freshly migrated but unseeded database. `/demo/credentials` renders an empty table. Admin user list shows 0 demo personas. All persona assertions fail.

**Why it happens:** CI's `Setup example dev DB` step only runs `mix ecto.create && mix ecto.migrate`, NOT `mix run priv/repo/seeds.exs`. [VERIFIED: direct inspection of `.github/workflows/ci.yml` lines 642–649]

**How to avoid:** Add a `Run demo seeds` step after DB setup (and before booting the server) in the `example_playwright_smoke` CI job: `MIX_ENV=dev mix run priv/repo/seeds.exs`. Seeds are idempotent — safe to run multiple times.

**Warning signs:** `demo-credentials-table` is empty; `adminUsersEmailLocator` finds no rows for `@demo.sigra.dev` emails.

### Pitfall 3: TOTP Code Stale at Auto-Verify Time

**What goes wrong:** `authenticator.generate(DEMO_TOTP_B32)` is called, stored in `code`, then a slow `waitForSelector` elapses past the 30-second TOTP step boundary. The stored code is now invalid. Auto-verify fires with a stale code and returns `:invalid_code`.

**Why it happens:** NimbleTOTP default drift window is 1 step (±30s). If the spec pauses for more than 30 seconds between code generation and input, the code may be outside the valid window.

**How to avoid:** Generate the TOTP code immediately before `page.fill('#mfa_totp_code', code)`. Do not store the code across slow operations. The `expect: { timeout: 15_000 }` global means this is unlikely in practice, but the code generation call must be adjacent to the fill.

**Warning signs:** MFA challenge page shows "Invalid code" flash; spec redirects back to `/users/mfa` instead of completing.

### Pitfall 4: Screenshot Baseline Filename Does Not Match Expected Pattern

**What goes wrong:** Committed PNGs have wrong filename — e.g., `demo-credentials.png` instead of `demo-credentials-demo-showcase-chromium.png` — causing Playwright to regenerate on every run instead of comparing.

**Why it happens:** `toHaveScreenshot('demo-credentials.png', ...)` produces `demo-credentials-demo-showcase-chromium.png` via `pathTemplate`. The project name is appended automatically. Committing only `demo-credentials.png` (without project suffix) leaves no baseline to compare against.

**How to avoid:** The `pathTemplate: '{testDir}/{testFilePath}-snapshots/{arg}{-projectName}{ext}'` config appends project name. Committed files MUST be `{slug}-demo-showcase-chromium.png`. Generate baselines first (`--update-snapshots`) then commit.

**Warning signs:** `toHaveScreenshot` error "Missing baseline — run with --update-snapshots".

### Pitfall 5: MFA Challenge Page Defaults to Passkey, Not TOTP

**What goes wrong:** `admin@demo.sigra.dev` has 1 passkey row (from seeds). `MFAChallengeLive` sets `active_method: if(passkey_count > 0, do: "passkey", else: "totp")`. The default active tab is passkey, not TOTP. The `#mfa_totp_code` input may not be visible without switching tabs.

**Why it happens:** `UserPasskey` row for admin was inserted by seeds. `Auth.passkey_count_for_user/1` returns 1, so `active_method` defaults to `"passkey"`.

**How to avoid:** Check if a tab-switch click is needed before filling `#mfa_totp_code`. Look for a tab/button labeled "Authenticator app" or similar to switch to TOTP view. Alternatively, examine the MFAChallengeLive template to confirm the TOTP tab selector.

**Warning signs:** `page.fill('#mfa_totp_code', code)` throws element-not-visible error.

---

## MFA Challenge UI — Selector Reference

From direct inspection of `test/example/lib/example_web/live/mfa_challenge_live.ex`:

| Element | Selector | Notes |
|---------|----------|-------|
| TOTP code input | `#mfa_totp_code` | `name="mfa[code]"`, auto-verifies on 6 digits |
| Backup code input | `#mfa_backup_code` | Same `name="mfa[code]"`, different form |
| TOTP form (phx-change) | `form[phx-change="validate_totp"]` | Fires auto-verify via `send(self(), {:auto_verify_totp, code})` |
| After successful verify | Redirect to `"/"` | NOT to `mfa_return_to`; navigate to admin pages manually |

---

## Admin User Detail — Assertion Reference

From direct inspection of `lib/sigra/admin/live/user_show_live.ex`:

| Element | Expected text for admin persona | Selector approach |
|---------|----------------------------------|-------------------|
| MFA status | `"MFA: Enabled"` | `page.getByText('MFA: Enabled')` |
| Passkey count | `"1 passkey"` | `page.getByText('1 passkey')` |
| Security section heading | `"Security"` | Visible heading confirming the section rendered |

The "API token row" is NOT present in the admin user detail page — the `api_tokens` table does not exist (Phase 141 D-10). Do not assert or mention it.

---

## Audit Explorer — Assertion Reference

The demo seeds insert these distinct action types tied to `admin@demo.sigra.dev`:

```
auth.login.success, auth.login.failure, mfa.enroll.success, session.create,
session.revoke_all, admin.impersonation.start, admin.impersonation.stop,
mfa.disable, mfa.regenerate_backup_codes
```

That is 9 distinct types (>= 6 required by PW-02 "showing event variety"). Navigate to `/admin/audit` without a filter — the default page shows all events ordered by `inserted_at desc`.

---

## Demo TOTP Secret — Derivation

| Property | Value |
|----------|-------|
| Source expression | `:crypto.hash(:sha256, "sigra-demo-admin-totp-v1") \|> binary_part(0, 20)` |
| Raw hex (first 20 bytes) | `1490bfe469fc4d719af1322bb87859405c494c56` |
| Base32 (RFC 4648, no padding) | `CSIL7ZDJ7RGXDGXRGIV3Q6CZIBOESTCW` |
| Verified via | `authenticator.generate('CSIL7ZDJ7RGXDGXRGIV3Q6CZIBOESTCW')` in otplib — produced valid 6-digit code |
| Used by personas | `admin@demo.sigra.dev`, `bob@demo.sigra.dev` |

Both admin and bob have this secret (confirmed in seeds.ex `seed_mfa_credentials/1`). The spec only logs in as admin, so only admin's TOTP challenge needs to be solved.

---

## CI Changes Required

The CI job `example_playwright_smoke` needs two additions:

**1. Seed the demo database (after migrate, before server boot):**

```yaml
- name: Run demo seeds
  working-directory: test/example
  env:
    MIX_ENV: dev
    PGUSER: postgres
    PGPASSWORD: postgres
    PGHOST: localhost
  run: mix run priv/repo/seeds.exs
```

Insert this step after the existing `Setup example dev DB` step (line ~649) and before `Boot example app in background` (line ~656).

**2. Add a demo-showcase Playwright run step** (after the non-admin smoke run or as a named step):

```yaml
- name: Run demo-showcase spec (demo-showcase-chromium)
  working-directory: test/example/priv/playwright
  env:
    CI: "true"
    SIGRA_EXAMPLE_URL: "http://localhost:4000"
  run: |
    npx playwright test \
      tests/demo-showcase.spec.ts \
      --project=demo-showcase-chromium
```

The `demo-showcase-chromium` project is excluded from `chromium` and `mobile` via `testIgnore`, so it will NOT run incidentally in other steps.

---

## Runtime State Inventory

Not applicable — this is a greenfield Playwright spec phase, not a rename/refactor/migration phase.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node.js | Playwright runner | ✓ | 22.14.0 | — |
| `@playwright/test` | Spec runner | ✓ | in package.json `^1.48.0` | — |
| `otplib` | TOTP code generation | ✓ | `^12.0.1` in package.json | — |
| Chromium browser | Screenshot capture | ✓ | Installed via `playwright install` | — |
| PostgreSQL on port 5432 | Demo seeds (dev DB) | ✓ (local) | postgres:16-alpine | docker run per CLAUDE.md |
| `demo@demo.sigra.dev` seeds | Spec assertions | ✓ (after `mix run priv/repo/seeds.exs`) | — | Must run seeds before spec |

**Missing dependencies with no fallback:** None — all tools present.

**Missing dependencies with fallback:** None.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Playwright 1.48+ (TypeScript) |
| Config file | `test/example/priv/playwright/playwright.config.ts` |
| Quick run command | `npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium` |
| Full suite command | `npx playwright test` |

ExUnit (for seeds_test.exs comment cross-reference):

| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir) |
| Config file | `test/example/test/test_helper.exs` |
| Quick run command | `mix test test/example/demo/seeds_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PW-01 | demo-showcase-chromium project exists, isolated from chromium/mobile | Playwright smoke | `npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium` | ❌ Wave 0 |
| PW-01 | Each persona's `data-testid="demo-persona-row-{local}"` visible on /demo/credentials | Playwright structural | same as above | ❌ Wave 0 |
| PW-01 | All 6 `@demo.sigra.dev` emails visible in `/admin/users?q=demo.sigra.dev` | Playwright structural | same as above | ❌ Wave 0 |
| PW-02 | 4 PNG baselines committed under `demo-showcase.spec.ts-snapshots/` | Playwright screenshot | `npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium` | ❌ Wave 0 |
| PW-03 | Seeds idempotent (run twice, identical counts) | ExUnit | `mix test test/example/demo/seeds_test.exs -t idempotency` | ✅ exists |
| PW-03 | `dave.locked_at` not nil | ExUnit | `mix test test/example/demo/seeds_test.exs` | ✅ exists |
| PW-03 | `frank.scheduled_deletion_at` not nil | ExUnit | `mix test test/example/demo/seeds_test.exs` | ✅ exists |

### Sampling Rate

- **Per task commit:** `npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium`
- **Per wave merge:** Full Playwright suite + `mix test test/example/demo/seeds_test.exs`
- **Phase gate:** Both suites green before `/gsd-verify-work`

### Wave 0 Gaps

- [ ] `tests/demo-showcase.spec.ts` — PW-01 and PW-02 (new file)
- [ ] `tests/demo-showcase.spec.ts-snapshots/` — committed PNG baselines (4 files, generated via `--update-snapshots`)
- [ ] `SigraAdminPolicy` extension — `admin@demo.sigra.dev` granted platform-admin
- [ ] CI seeds step — `mix run priv/repo/seeds.exs` in `example_playwright_smoke` job

*(seeds_test.exs PW-03 comment cross-ref is a one-line edit — not a gap, just a task)*

---

## Security Domain

This phase adds only test infrastructure (Playwright spec, CI step, policy comment). No new user-facing auth surfaces are introduced. Standard ASVS categories are not applicable here — the spec does not implement security controls, it tests them.

The only security-adjacent consideration: `DEMO_TOTP_B32 = 'CSIL7ZDJ7RGXDGXRGIV3Q6CZIBOESTCW'` is a public-by-design fixture value (matches `Personas.demo_totp_secret/0` which is clearly labeled demo-only). Committing this value in the spec is appropriate and consistent with how `Personas.demo_totp_secret/0` is already public in the repository.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | MFAChallengeLive defaults to `active_method: "passkey"` when admin has 1 passkey, requiring a tab-switch before filling `#mfa_totp_code` | Pitfall 5 / Pattern 3 | Spec fails with element-not-visible on `#mfa_totp_code` fill; plan must include tab-switch step |
| A2 | After TOTP auto-verify, `page.url()` no longer matches `/users/mfa` before 15s timeout elapses | Pattern 3 | If LV redirect is slower, `expect(page).not.toHaveURL(/\/users\/mfa/)` times out |
| A3 | `/admin/users?q=demo.sigra.dev` (domain substring search) returns all 6 demo personas on the first page | Architecture / Pattern 4 | If the `q` search does not support domain substring matching, need to assert each email individually via separate navigations |

**Note on A1 (highest risk):** Inspecting `mfa_challenge_live.ex:37` confirms `active_method: if(passkey_count > 0, do: "passkey", else: "totp")`. Since `admin@demo.sigra.dev` has 1 passkey row, the TOTP tab is NOT the default. The plan task implementing the login helper must click the TOTP tab before filling `#mfa_totp_code`. The planner should read the MFAChallengeLive template to identify the TOTP tab button selector before writing the spec task.

---

## Open Questions (RESOLVED)

1. **What is the TOTP tab button selector in MFAChallengeLive?**
   - What we know: `active_method` defaults to `"passkey"` when passkey count > 0. The template has separate TOTP and passkey sections.
   - What's unclear: The exact button/tab label text or `data-*` attribute to click to switch to the TOTP method view.
   - **RESOLVED: `button[phx-click="show_totp"]`** — confirmed via direct inspection of `mfa_challenge_live.ex`. Pattern 3 code sample updated to include this click before the `#mfa_totp_code` fill.

2. **Does `/admin/users?q=demo.sigra.dev` (domain substring) return all 6 personas?**
   - What we know: The search param is `q`, the admin users index uses it, and existing specs search with full emails.
   - What's unclear: Whether a partial domain match (`demo.sigra.dev`) surfaces all 6 results or requires exact email matching.
   - **RESOLVED: Fallback per-email assertions pattern added to plan.** The spec uses `adminUsersEmailLocator` in a loop over all 6 `DEMO_EMAILS` regardless of whether domain search works. If the `q=demo.sigra.dev` query does not narrow results sufficiently, the per-email `toBeVisible` assertions still pass as long as the persona rows exist in the results set. No plan change needed beyond what is already specified.

---

## Sources

### Primary (HIGH confidence — direct codebase inspection)

- `test/example/priv/playwright/playwright.config.ts` — project partition pattern, `testIgnore`/`testMatch`, `pathTemplate`, tolerance constants
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts:129-144` — `assertCheckpointScreenshot` pattern (copy-adapt as `assertDemoScreenshot`)
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/` — confirmed PNG naming convention `{slug}-{project}.png`
- `test/example/lib/example/sigra_admin_policy.ex` — confirmed `platform-admin+` prefix only; no `admin@demo.sigra.dev` grant exists
- `test/example/lib/example_web/live/mfa_challenge_live.ex` — confirmed `#mfa_totp_code` selector, auto-verify on 6 digits, redirect to `"/"` after success, `active_method` defaults to passkey
- `test/example/lib/example/demo/personas.ex` — confirmed `admin@demo.sigra.dev` password `DemoAdmin1!SecurePass`, 6 personas, `demo_totp_secret/0` derivation
- `test/example/lib/example/demo/seeds.ex` — confirmed 9 distinct audit action types, TOTP used by admin + bob
- `test/example/test/example/demo/seeds_test.exs` — confirmed PW-03 coverage (idempotency line 89, dave line 130, frank line 138)
- `test/example/lib/example_web/live/demo/credentials_live.ex` — confirmed `demo-persona-row-{local}` testids, no auth required
- `test/example/lib/example_web/router.ex` — confirmed `/demo/credentials` is browser-only (no auth), `/admin/*` uses `:require_authenticated` + `:admin_global`
- `lib/sigra/auth.ex:1924` — confirmed TOTP-enrolled user login sets session type `:mfa_pending`
- `.github/workflows/ci.yml:642-649` — confirmed no seeds step in `example_playwright_smoke` CI job
- `test/example/lib/example/sigra_admin_policy.ex` — confirmed current policy does not grant admin to `admin@demo.sigra.dev`
- Node.js computation + `otplib` in playwright `node_modules` — confirmed `CSIL7ZDJ7RGXDGXRGIV3Q6CZIBOESTCW` is the correct base32 of the demo TOTP secret and produces valid TOTP codes

### Secondary (MEDIUM confidence)

- `lib/sigra/admin/live/user_show_live.ex:155-156` — Security section renders `"MFA: Enabled"` and `"1 passkey"` for admin persona
- `lib/sigra/admin/live/users_index_live.ex:94-95` — search param name is `q`

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries already installed, versions confirmed
- Architecture: HIGH — all patterns verified via direct code inspection
- Pitfalls: HIGH (P1, P2) / MEDIUM (P3, P4, P5) — first two verified, rest confirmed by code inspection with some timing uncertainty
- CI changes: HIGH — gap verified directly in ci.yml

**Research date:** 2026-05-30
**Valid until:** 2026-06-30 (stable patterns; only invalidated if `mfa_challenge_live.ex` or `SigraAdminPolicy` changes)
