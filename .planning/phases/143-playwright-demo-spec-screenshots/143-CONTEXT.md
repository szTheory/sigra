# Phase 143: Playwright Demo Spec & Screenshots - Context

**Gathered:** 2026-05-30 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Add a `demo-showcase` Playwright project partition and spec that exercises the seeded
personas' distinct auth states using structural assertions, and capture evaluator-quality
screenshots of the populated example app committed in the expected snapshot directory.

**In scope (test/example/ only):**
- `priv/playwright/playwright.config.ts` — add `demo-showcase-chromium` project partition
- `priv/playwright/tests/demo-showcase.spec.ts` — new spec file
- `priv/playwright/tests/demo-showcase.spec.ts-snapshots/` — committed screenshot PNGs
- `test/example/demo/seeds_test.exs` — cross-reference PW-03 comment only (tests already pass)

**Out of scope:** Any changes to `lib/sigra/`, README/guide (Phase 144), new admin UI surfaces
(API-token admin surface explicitly deferred in Phase 141 D-10 and not required here).
</domain>

<decisions>
## Implementation Decisions

### Playwright Project Partition (PW-01)
- **D-01:** Add a `DEMO_SHOWCASE_SPEC = /demo-showcase\.spec\.ts/` regex constant to
  `playwright.config.ts` — same shape as the existing `ADMIN_CHECKPOINTS_SPEC` and
  `ADMIN_GENERATED_SPEC` constants.
- **D-02:** Add `demo-showcase-chromium` project entry using `testMatch: DEMO_SHOWCASE_SPEC`
  with `use: { ...devices['Desktop Chrome'] }`. Single desktop chromium project only — no
  mobile or dark variants required by PW-02 success criteria.
- **D-03:** Add `DEMO_SHOWCASE_SPEC` to `testIgnore` on BOTH the `chromium` and `mobile`
  projects — same isolation as `ADMIN_CHECKPOINTS_SPEC` and `ADMIN_GENERATED_SPEC`. This
  prevents the demo spec from running in the behavior-truth lanes.
- **D-04:** New spec file lives at `tests/demo-showcase.spec.ts`. Global config already
  enforces `workers: 1, fullyParallel: false` — no per-project worker override needed.

### Persona Auth Assertions (PW-01)
- **D-05:** Assert each seeded persona's presence via `data-testid="demo-persona-row-{local}"`
  on `/demo/credentials` (e.g. `[data-testid="demo-persona-row-admin"]`,
  `[data-testid="demo-persona-row-dave"]`). The `{local}` value is the email prefix
  (admin, alice, bob, carol, dave, frank) — confirmed from Phase 142 D-03 and
  `credentials_live.ex` render.
- **D-06:** For admin-page persona assertions, use structural email-based locators on
  `#admin-users-desktop-results` rows (pattern established in existing admin-audit.spec.ts
  and admin-user-operations.spec.ts helpers). Do NOT assert on display-name text strings —
  a persona rename must not break the spec.
- **D-07:** The spec logs in as the `admin@demo.sigra.dev` persona to access admin pages.
  The admin persona has confirmed email, TOTP enrolled, and multi-org membership — use the
  deterministic password from `Example.Demo.Personas.all()` (e.g. `DemoAdmin1!`).

### Screenshot Capture (PW-02)
- **D-08:** Use the `assertCheckpointScreenshot`-style `toHaveScreenshot` pattern from
  `admin-checkpoints.spec.ts` (lines 129–144): `fullPage: false`, viewport capture only,
  CI-aware `maxDiffPixels`/`maxDiffPixelRatio` tolerances to handle font rasterization
  difference between macOS and Linux CI runners.
- **D-09:** Committed screenshot baselines live under
  `tests/demo-showcase.spec.ts-snapshots/` with filenames `{slug}-demo-showcase-chromium.png`
  — matching the `pathTemplate: '{testDir}/{testFilePath}-snapshots/{arg}{-projectName}{ext}'`
  already configured in `playwright.config.ts`. The `artifacts/` directory is git-ignored;
  do not place committed baselines there.
- **D-10:** Required screenshot surfaces (SC#3, amended to drop API-token row per Phase 141
  D-10 — no `api_tokens` table exists, no admin API-token UI surface):
  1. `demo-credentials` — `/demo/credentials` showing the populated persona table (the
     "login page (populated)" evaluator entry point)
  2. `admin-user-list` — `/admin/users` with all 6 `@demo.sigra.dev` personas visible
  3. `admin-user-detail` — `/admin/users/{admin-id}` showing MFA credential row + passkey
     display row (API token row is dropped)
  4. `audit-explorer` — `/admin/audit` showing ≥6 distinct event types

### Seeds-Smoke (PW-03)
- **D-11:** PW-03 is satisfied by the existing
  `test/example/test/example/demo/seeds_test.exs` — already covers:
  - Idempotency: runs `Seeds.run()` twice, asserts identical counts (line 89)
  - `dave.locked_at` not nil (line 130)
  - `frank.scheduled_deletion_at` not nil (line 138)
  - 6 personas present, org membership shape, TOTP/passkey/OAuth identity rows
- **D-12:** Phase 143's PW-03 implementation is: add a `# PW-03: seeds-smoke check` doc
  comment to the `seeds_test.exs` describe blocks that cover PW-03, confirming these
  ExUnit tests serve as the seeds-smoke check for this requirement. No new test code is
  needed — the tests already pass (Phase 141 verified).
- **D-13:** The `mix test` alias in `test/example/mix.exs` runs `ecto.migrate --quiet`
  before the suite, so `seeds_test.exs` already runs in CI. No CI config changes needed
  for PW-03.

### Claude's Discretion
- The specific password string for `admin@demo.sigra.dev` — read from
  `Example.Demo.Personas.all()` at plan time.
- Whether to extract an `assertDemoScreenshot` helper (mirror of `assertCheckpointScreenshot`)
  or inline the `toHaveScreenshot` calls. Follow the checkpoint pattern if reuse seems
  warranted; inline is fine for 4 captures.
- The `maxDiffPixels` tolerance values — use the same CI-aware formula from
  `admin-checkpoints.spec.ts` (CI: 200_000 / 0.22; default chromium: 30_000 / 0.06).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `test/example/priv/playwright/playwright.config.ts` — existing project partition structure; add `demo-showcase` following the same pattern
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — reference implementation for `toHaveScreenshot` screenshot capture pattern (lines 129–144 for `assertCheckpointScreenshot`)
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/` — committed PNG baseline naming convention (`{slug}-{project}.png`)
- `test/example/priv/playwright/tests/golden-path.spec.ts` — reference for auth flow login sequence
- `test/example/test/example/demo/seeds_test.exs` — existing ExUnit seeds-smoke coverage (PW-03 satisfied here)
- `test/example/lib/example/demo/personas.ex` — persona data including emails, passwords, `feature_map/0`
- `test/example/lib/example_web/live/demo/credentials_live.ex` — `demo-persona-row-{local}` testid rendering
- `.planning/phases/141-seed-data-layer/141-CONTEXT.md` — D-10 (API-token surface deferred), D-01/D-02 (persona/idempotency decisions)
- `.planning/phases/142-dev-credentials-page-app-framing/142-CONTEXT.md` — D-03/D-05/D-06 (testid contract)
- `.planning/REQUIREMENTS.md` — PW-01/PW-02/PW-03 acceptance criteria
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `assertCheckpointScreenshot` helper pattern in `admin-checkpoints.spec.ts` — copy/adapt for
  demo spec with identical CI-tolerance logic
- `captureAdminCheckpoint` helper (for HTML-report attachments) available but not needed for
  committed baselines
- `adminUsersEmailLocator` / `#admin-users-desktop-results` locator pattern used in existing
  admin specs for email-based structural assertions
- `ADMIN_CHECKPOINTS_SPEC`, `ADMIN_GENERATED_SPEC` regex constants in `playwright.config.ts`
  — direct template for `DEMO_SHOWCASE_SPEC`

### Established Patterns
- All Playwright projects use global `workers: 1, fullyParallel: false` (DB-sharing constraint)
- Screenshot baselines use `pathTemplate: '{testDir}/{testFilePath}-snapshots/{arg}{-projectName}{ext}'`
  (no OS suffix) — Playwright appends project name, not platform
- Screenshot tolerances: CI `maxDiffPixels: 200_000 / maxDiffPixelRatio: 0.22`; desktop
  chromium `30_000 / 0.06` — needed because CI Linux font rasterization differs from
  macOS baseline captures
- New specs are excluded from `chromium`/`mobile` via `testIgnore` — not by file naming or
  directory structure
- `seeds_test.exs` uses `DataCase, async: false` — correct for shared-sandbox DB assertions

### Integration Points
- `/demo/credentials` — Phase 142 LiveView; requires `MIX_ENV=dev` (dev-only route);
  testids `demo-credentials-table`, `demo-persona-row-{local}`, `demo-dev-only-badge`
- `/admin/users` — Sigra library admin panel; accessible after logging in as
  `admin@demo.sigra.dev` (platform-admin role via `Example.SigraAdminPolicy`)
- `Example.SigraAdminPolicy` grants platform-admin to emails with `platform-admin+` prefix
  OR the seeded admin persona — confirm login credentials from `personas.ex` at plan time
- `seeds_test.exs` — existing PW-03 coverage; only needs comment cross-reference
</code_context>

<specifics>
## Specific Ideas

- Screenshot slug naming should mirror `admin-checkpoints` convention (kebab-case, no project
  suffix in the test call — Playwright appends it): `demo-credentials`, `admin-user-list`,
  `admin-user-detail`, `audit-explorer`
- The `demo-showcase-chromium` project name determines the committed PNG filenames:
  `demo-credentials-demo-showcase-chromium.png`, etc.
- Phase 141 D-10 amendment: SC#3's "API token row" in the ROADMAP is outdated. Capture
  `admin-user-detail` as MFA row + passkey row only. Do not mention API token row in
  PLAN.md success verification.
</specifics>

<deferred>
## Deferred Ideas

- Mobile/dark variants of demo-showcase screenshots — Phase 143 only needs the chromium
  desktop baseline per PW-02; mobile/dark variants can be added later if needed
- Admin user detail screenshot for non-admin personas (alice, bob, carol, dave, frank) —
  the admin persona detail with MFA+passkey is sufficient for evaluator proof

### Reviewed Todos (not folded)
- `2026-05-28-phase-135-review-deferred-findings.md` — Threadline upstream + test/example
  polish from Phase 135 review; not related to Playwright spec work. Deferred.
- `2026-05-29-deprecation-since-vs-removal-version-axis.md` — lib/sigra deprecation
  annotation cleanup; out of Phase 143 scope. Deferred.
- `2026-05-29-phase-138-doctor-info-findings.md` — lib/sigra Doctor minor findings;
  out of Phase 143 scope. Deferred.
</deferred>
