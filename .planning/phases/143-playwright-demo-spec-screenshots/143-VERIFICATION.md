---
phase: 143-playwright-demo-spec-screenshots
verified: 2026-05-30T16:30:00Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
---

# Phase 143: Playwright Demo Spec & Screenshots Verification Report

**Phase Goal:** Automated Playwright coverage exercises the seeded personas' distinct auth states using structural assertions in a dedicated project partition that does not affect the golden-path specs, and evaluator-quality screenshots of the populated app are captured and committed.
**Verified:** 2026-05-30T16:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A `demo-showcase` Playwright project partition exists in `playwright.config.ts`, runs independently of the `chromium` and `mobile` partitions, and can be invoked without affecting the golden-path spec results | VERIFIED | `DEMO_SHOWCASE_SPEC = /demo-showcase\.spec\.ts/` declared at line 34; `demo-showcase-chromium` project with `testMatch: DEMO_SHOWCASE_SPEC` at lines 155–158; `DEMO_SHOWCASE_SPEC` in `testIgnore` on both `chromium` (line 84, inline array) and `mobile` (line 98, multi-line array); 4 total occurrences confirmed by grep |
| 2 | The demo spec asserts each seeded persona's auth state using `data-testid` or structural DOM checks — not persona display-name text — so a persona rename does not break the spec | VERIFIED | `/demo/credentials`: iterates `DEMO_LOCALS` and asserts `[data-testid="demo-persona-row-${local}"]` visibility for all 6 locals; `/admin/users?q=demo.sigra.dev`: iterates `DEMO_EMAILS` and asserts via `adminUsersEmailLocator(page, email)` (email-based structural locator from `helpers/adminUsersIndex.ts`); no display-name text selectors found |
| 3 | Screenshots are captured covering at minimum: credentials page (populated), admin user list (all 6 personas visible), admin user detail (MFA row, passkey row), and the audit log explorer (showing event variety); screenshots are committed in the expected output directory | VERIFIED | 4 PNG baselines committed: `demo-credentials-demo-showcase-chromium.png` (78 521 bytes), `admin-user-list-demo-showcase-chromium.png` (120 406 bytes), `admin-user-detail-demo-showcase-chromium.png` (102 157 bytes), `audit-explorer-demo-showcase-chromium.png` (84 582 bytes) — all under `tests/demo-showcase.spec.ts-snapshots/`; spec makes 4 `assertDemoScreenshot` calls at lines 115, 132, 148, 160. Note: ROADMAP SC3 text says "login page (populated)" and "API token row" — both amended per CONTEXT D-10 (no admin API-token surface exists; `/demo/credentials` is the evaluator-facing credentials entry point) |
| 4 | A seeds-smoke check (ExUnit or Playwright) runs in CI, asserts that seeds are idempotent (run twice, no errors), and verifies each persona's key auth-state column (`locked_at` is not null for dave, `scheduled_deletion_at` is not null for frank) | VERIFIED | `test/example/test/example/demo/seeds_test.exs` has no `@moduletag` so it runs in the "Example unit smoke" CI job via `mix test --include example_app` (untagged tests are not excluded); `describe "idempotency (SEED-01)"` block at line 90 annotated `# PW-03: seeds-smoke check` (line 89); `describe "six personas + states (SEED-02, SEED-03)"` block at line 108 annotated `# PW-03: seeds-smoke check` (line 107); `refute is_nil(dave.locked_at)` at line 132; `refute is_nil(frank.scheduled_deletion_at)` at line 140 |

**Score:** 4/4 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `test/example/lib/example/sigra_admin_policy.ex` | `@demo_admin_email` attribute + OR clause in `platform_admin?/1` | VERIFIED | `@demo_admin_email "admin@demo.sigra.dev"` at line 19; `String.starts_with?(email, @platform_admin_prefix) or email == @demo_admin_email` at line 23; committed in 4dfd9b8 |
| `.github/workflows/ci.yml` | `Run demo seeds` step after `mix ecto.create && mix ecto.migrate` and before `Install Playwright deps` | VERIFIED | Step at line 650; `working-directory: test/example`; `MIX_ENV: dev`; `run: mix run priv/repo/seeds.exs`; ecto at line 649, playwright install at line 658 — ordering confirmed; committed in 98818f2 |
| `test/example/test/example/demo/seeds_test.exs` | Two `# PW-03: seeds-smoke check` comments above idempotency and persona-state describe blocks | VERIFIED | Line 89 (above `describe "idempotency (SEED-01)"`); line 107 (above `describe "six personas + states (SEED-02, SEED-03)"`); `grep -c "PW-03"` returns 2; committed in c257280 |
| `test/example/priv/playwright/playwright.config.ts` | `DEMO_SHOWCASE_SPEC` constant + `demo-showcase-chromium` project + `testIgnore` on chromium and mobile | VERIFIED | Constant at line 34; project at lines 154–158; chromium testIgnore at line 84; mobile testIgnore at line 98; 4 total occurrences; committed in 3239dd1 |
| `test/example/priv/playwright/tests/demo-showcase.spec.ts` | Full spec with 6-persona assertions, 4 screenshot captures, structural locators | VERIFIED | 163 lines; 6 `data-testid` assertions via `DEMO_LOCALS` loop; 6 email assertions via `DEMO_EMAILS` + `adminUsersEmailLocator`; `assertDemoScreenshot` called 4 times; `waitForLiveViewReady`, `loginDemoAdmin` helpers; committed in 5325aaf |
| `tests/demo-showcase.spec.ts-snapshots/demo-credentials-demo-showcase-chromium.png` | Non-empty committed PNG baseline | VERIFIED | 78 521 bytes; committed in 5325aaf |
| `tests/demo-showcase.spec.ts-snapshots/admin-user-list-demo-showcase-chromium.png` | Non-empty committed PNG baseline | VERIFIED | 120 406 bytes; committed in 5325aaf |
| `tests/demo-showcase.spec.ts-snapshots/admin-user-detail-demo-showcase-chromium.png` | Non-empty committed PNG baseline | VERIFIED | 102 157 bytes; committed in 5325aaf |
| `tests/demo-showcase.spec.ts-snapshots/audit-explorer-demo-showcase-chromium.png` | Non-empty committed PNG baseline | VERIFIED | 84 582 bytes; committed in 5325aaf |
| `.github/workflows/ci.yml` (demo-showcase step) | `Run demo-showcase spec (demo-showcase-chromium)` step after non-admin browser smoke | VERIFIED | Step at line 764; non-admin smoke at line 746; ordering confirmed (764 > 746); `CI: "true"`, `SIGRA_EXAMPLE_URL: "http://localhost:4000"`, `--project=demo-showcase-chromium`; committed in b65978f |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `playwright.config.ts` | `tests/demo-showcase.spec.ts` | `testMatch: DEMO_SHOWCASE_SPEC` in `demo-showcase-chromium` project | WIRED | Line 156: `testMatch: DEMO_SHOWCASE_SPEC` resolves to `/demo-showcase\.spec\.ts/` which matches the spec filename |
| `playwright.config.ts` | `chromium` and `mobile` projects | `testIgnore: [..., DEMO_SHOWCASE_SPEC]` | WIRED | Chromium: line 84 inline array; mobile: lines 93–99 multi-line array (DEMO_SHOWCASE_SPEC at line 98) |
| `tests/demo-showcase.spec.ts` | `tests/demo-showcase.spec.ts-snapshots/` | `toHaveScreenshot` with `{slug}-demo-showcase-chromium.png` naming | WIRED | Global `pathTemplate: '{testDir}/{testFilePath}-snapshots/{arg}{-projectName}{ext}'` in playwright.config.ts produces `{slug}-demo-showcase-chromium.png`; all 4 baselines present with exact names |
| `tests/demo-showcase.spec.ts` | `helpers/adminUsersIndex.ts` | `import { adminUsersEmailLocator } from '../helpers/adminUsersIndex'` | WIRED | Line 8; `adminUsersEmailLocator` exported at line 10 of the helper; used at line 129 in the spec |
| `SigraAdminPolicy.platform_admin?/1` | `Sigra.Admin.Policy` behaviour | `@impl true def platform_admin?/1` | WIRED | `@behaviour Sigra.Admin.Policy` at line 10; `@impl true` at line 21; OR clause at line 23 |
| `.github/workflows/ci.yml` seeds step | `priv/repo/seeds.exs` | `mix run priv/repo/seeds.exs` with `MIX_ENV: dev` | WIRED | Line 657: `run: mix run priv/repo/seeds.exs`; line 653: `MIX_ENV: dev` |
| `.github/workflows/ci.yml` demo-showcase step | `demo-showcase-chromium` project | `npx playwright test ... --project=demo-showcase-chromium` | WIRED | Lines 770–772 |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PW-01 | 143-01-PLAN.md, 143-02-PLAN.md | Playwright demo spec exercises seeded personas' auth states using structural assertions (`data-testid` / auth-state, not brittle persona-name matching), in its own Playwright project partition, leaving the golden-path specs unaffected | SATISFIED | `demo-showcase-chromium` partition isolated via testIgnore; 6-persona `data-testid` assertions on `/demo/credentials`; email-based structural locators for admin user list; no display-name text selectors |
| PW-02 | 143-02-PLAN.md | Evaluator-facing screenshots captured via Playwright, covering key surfaces committed under the snapshot directory | SATISFIED | 4 PNG baselines in `tests/demo-showcase.spec.ts-snapshots/` with correct `{slug}-demo-showcase-chromium.png` naming; sizes 78–120 KB confirming non-empty real captures |
| PW-03 | 143-01-PLAN.md | Seeds-smoke check proves seeds are idempotent and each persona's auth state is verifiable, guarding CI against seed/schema drift | SATISFIED | `seeds_test.exs` has idempotency describe block (SEED-01) and persona auth-state describe block (SEED-02, SEED-03) both annotated `# PW-03: seeds-smoke check`; `dave.locked_at` and `frank.scheduled_deletion_at` assertions present; test runs in CI via Example unit smoke job |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | — | — | — | — |

No TBD, FIXME, or XXX markers in any Phase 143 modified files. No stubs, placeholder returns, or disconnected props detected.

### Notable Deviation: TOTP Challenge (Plan Must-Have vs. Roadmap SC)

Plan 143-02 listed as a must-have: "The spec completes the TOTP challenge using otplib before accessing admin routes." The spec does NOT perform a TOTP challenge at runtime. This was a documented research-driven deviation: the example app's `sigra_config()` does not include `mfa.check_fn`, so `Sigra.Auth.authenticate/2` creates `:standard` sessions regardless of TOTP enrollment state. Adding `check_fn` would break `golden-path.spec.ts` which explicitly expects no MFA challenge on login. The TOTP constants (`DEMO_TOTP_B32`, `authenticator` import) are retained for future activation and documented in comments at lines 2–7 and 62–75 of the spec.

This deviation does NOT affect ROADMAP success criteria: SC1–SC4 make no mention of TOTP challenge. The admin user detail screenshot correctly shows "MFA: Enabled" (enabled by the `mfa_label/1` pattern fix in `lib/sigra/admin/live/user_show_live.ex` line 360), demonstrating MFA enrollment to evaluators without requiring a login-time MFA challenge.

### Human Verification Required

None. All four ROADMAP success criteria are verifiable programmatically and confirmed by codebase inspection. The Playwright spec has been reported as passing (`npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium --reporter=line` exits 0 per SUMMARY 02 verification table). The PNG baselines exist with non-trivial file sizes confirming real captures.

---

_Verified: 2026-05-30T16:30:00Z_
_Verifier: Claude (gsd-verifier)_
