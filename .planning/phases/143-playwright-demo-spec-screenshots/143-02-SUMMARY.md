---
phase: 143-playwright-demo-spec-screenshots
plan: "02"
subsystem: playwright-demo-spec
tags: [playwright, demo, screenshots, ci, mfa-label-fix]
dependency_graph:
  requires:
    - "143-01 (SigraAdminPolicy demo admin grant, CI seeds step)"
  provides:
    - demo-showcase-chromium Playwright project partition in playwright.config.ts
    - tests/demo-showcase.spec.ts: full demo showcase spec with 6-persona assertions and 4 screenshot surfaces
    - 4 committed PNG baselines under tests/demo-showcase.spec.ts-snapshots/
    - CI Run demo-showcase spec step in example_playwright_smoke job
    - mfa_label/1 fix in user_show_live.ex: %{enabled: true} pattern added
  affects:
    - test/example/priv/playwright/playwright.config.ts
    - test/example/priv/playwright/tests/demo-showcase.spec.ts
    - test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/
    - .github/workflows/ci.yml
    - lib/sigra/admin/live/user_show_live.ex
tech_stack:
  added: []
  patterns:
    - Playwright project partition via testMatch/testIgnore pair (DEMO_SHOWCASE_SPEC)
    - CI-aware toHaveScreenshot tolerances (maxDiffPixels 200k/30k, maxDiffPixelRatio 0.22/0.06)
    - Email-based structural locators via adminUsersEmailLocator helper (no display-name text)
    - data-testid assertions for demo-persona-row-{local} on /demo/credentials
key_files:
  created:
    - test/example/priv/playwright/tests/demo-showcase.spec.ts
    - test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/demo-credentials-demo-showcase-chromium.png
    - test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/admin-user-list-demo-showcase-chromium.png
    - test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/admin-user-detail-demo-showcase-chromium.png
    - test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/audit-explorer-demo-showcase-chromium.png
  modified:
    - test/example/priv/playwright/playwright.config.ts
    - .github/workflows/ci.yml
    - lib/sigra/admin/live/user_show_live.ex
decisions:
  - Example app uses MFA as step-up auth (not login challenge) per golden-path.spec.ts:141 — loginDemoAdmin uses simple password login without TOTP challenge; DEMO_TOTP_B32 and authenticator import retained for future activation if mfa.check_fn is added to sigra_config()
  - mfa_label/1 bug fixed by adding %{enabled: true} pattern to match Sigra.MFA.status/3 return shape (was checking %{enabled?: true} which never matched)
  - PNG baselines captured on macOS dev server with CI-aware tolerances matching the admin-checkpoints lane pattern
metrics:
  duration: ~45 minutes
  completed: "2026-05-30T14:00:00Z"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 5
  files_created: 5
---

# Phase 143 Plan 02: Demo-Showcase Playwright Spec & Screenshots Summary

**One-liner:** Demo-showcase-chromium Playwright partition with 6-persona structural assertions, simplified password login (no TOTP challenge — example app uses MFA as step-up auth), and 4 committed PNG baselines covering credentials/admin-list/admin-detail/audit surfaces.

## What Was Built

Three tasks delivering the core deliverable of Phase 143:

1. **Playwright config partition (Task 1)** — Added `DEMO_SHOWCASE_SPEC = /demo-showcase\.spec\.ts/` constant and `demo-showcase-chromium` project entry to `playwright.config.ts`. Extended `testIgnore` on both `chromium` (inline array) and `mobile` (multi-line array) to include `DEMO_SHOWCASE_SPEC`. The partition uses `testMatch: DEMO_SHOWCASE_SPEC` with `Desktop Chrome` device — no video override (demo lane uses global screenshot-on-failure setting).

2. **Demo-showcase spec + PNG baselines (Task 2)** — Wrote `tests/demo-showcase.spec.ts` with a single `test.describe` block exercising:
   - `/demo/credentials` — all 6 persona rows via `data-testid="demo-persona-row-{local}"` (D-05)
   - Password login as `admin@demo.sigra.dev` (simplified, see Deviations)
   - `/admin/users?q=demo.sigra.dev` — all 6 demo emails via `adminUsersEmailLocator` (D-06)
   - `/admin/users/{admin-id}` — `MFA: Enabled` and `1 passkey` text assertions
   - `/admin/audit` — non-empty audit rows via `table tbody tr` count
   - 4 `assertDemoScreenshot` calls capturing committed PNG baselines (D-10)
   
   Also fixed a pre-existing bug in `lib/sigra/admin/live/user_show_live.ex`: `mfa_label/1` was matching `%{enabled?: true}` but `Sigra.MFA.status/3` returns `%{enabled: true}` (no trailing `?`). Added the correct pattern clause so admin user detail now shows "MFA: Enabled" for enrolled users.
   
   Generated 4 committed PNG baselines via `--update-snapshots` against a running dev server:
   - `demo-credentials-demo-showcase-chromium.png` (78 KB)
   - `admin-user-list-demo-showcase-chromium.png` (120 KB)
   - `admin-user-detail-demo-showcase-chromium.png` (102 KB)
   - `audit-explorer-demo-showcase-chromium.png` (85 KB)

3. **CI step (Task 3)** — Inserted `Run demo-showcase spec (demo-showcase-chromium)` step in `example_playwright_smoke` job, positioned immediately after `Run non-admin example browser smoke`. Uses `CI: "true"`, `SIGRA_EXAMPLE_URL`, and `--project=demo-showcase-chromium`.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1    | 3239dd1 | feat(143-02): add demo-showcase-chromium project partition to playwright.config.ts |
| 2    | 5325aaf | feat(143-02): add demo-showcase spec with 4 committed PNG baselines |
| 3    | b65978f | feat(143-02): add Run demo-showcase spec step to CI example_playwright_smoke job |

## Verification Results

| Check | Result |
|-------|--------|
| `grep -c "DEMO_SHOWCASE_SPEC" playwright.config.ts` returns 4 | PASS |
| DEMO_SHOWCASE_SPEC in chromium testIgnore | PASS |
| DEMO_SHOWCASE_SPEC in mobile testIgnore (multi-line array, line 98) | PASS |
| `grep -c "show_totp" demo-showcase.spec.ts` returns 1 (in doc comment) | PASS |
| 4 PNG files in demo-showcase.spec.ts-snapshots/ | PASS |
| `grep -c "Run demo-showcase spec" ci.yml` returns 1 | PASS |
| `npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium --reporter=line` exits 0 | PASS |
| Partition isolation: `--list --project=chromium` does not include demo-showcase | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed mfa_label/1 pattern mismatch in user_show_live.ex**

- **Found during:** Task 2 — admin user detail showed "MFA: Not configured" for admin@demo.sigra.dev despite having TOTP enrolled
- **Root cause:** `mfa_label/1` matched `%{enabled?: true}` (trailing ?) but `Sigra.MFA.status/3` returns `%{enabled: true}` (no trailing ?). All other patterns also failed to match, so the catch-all returned "Not configured"
- **Fix:** Added `defp mfa_label(%{enabled: true}), do: "MFA: Enabled"` clause before the legacy `enabled?:` clause
- **Files modified:** `lib/sigra/admin/live/user_show_live.ex`
- **Commit:** 5325aaf

### Research-Driven Deviation (not a bug fix)

**2. TOTP login challenge not triggered in example app**

- **Found during:** Task 2 execution — `admin@demo.sigra.dev` logged in without MFA challenge (redirected to `/` with "Welcome back!" flash instead of `/users/mfa`)
- **Root cause:** The example app's `sigra_config()` does NOT include `mfa: [check_fn: ...]`. Without `check_fn`, `Sigra.Auth.authenticate/2` creates `:standard` sessions regardless of TOTP enrollment. This is intentional per `golden-path.spec.ts:141`: "the example app uses MFA as step-up auth (sudo mode), not as a login challenge."
- **Plan's must-have:** "The spec completes the TOTP challenge using otplib before accessing admin routes" — this was based on incorrect research (RESEARCH.md line 70 assumed `check_fn` was configured).
- **Actual behavior:** Adding `check_fn` would break `golden-path.spec.ts` which explicitly expects no MFA challenge on login.
- **Resolution:** `loginDemoAdmin` uses simple password login. `DEMO_TOTP_B32` constant and `authenticator` import are retained for documentation and future activation. The spec's functional assertions and screenshots are unaffected.
- **Impact on requirements:** PW-01 (structural persona assertions in isolated partition) — FULLY MET. PW-02 (4 committed PNG baselines) — FULLY MET. The TOTP challenge was a must-have in the plan spec but the plan was based on incorrect research; the admin user detail correctly shows "MFA: Enabled" after the mfa_label fix, demonstrating MFA enrollment.

**3. [Rule 1 - Blocking] Server location for Playwright run**

- **Found during:** Task 2 — the running dev server on port 4000 was a different Phoenix app (RulesteadDemo). The Sigra example app was not running.
- **Fix:** Started the Sigra example app on port 4001 from the worktree (after symlinking deps from the main repo since the worktree has no independent deps directory).
- **Impact:** No code changes; operational deviation during baseline generation. CI always boots the example app explicitly before running Playwright.

## Known Stubs

None. All spec assertions are wired to live application endpoints. All PNG baselines are captured from the running example app with seeded demo data.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes. The `mfa_label/1` fix is a display-layer correction. The DEMO_TOTP_B32 constant is public-by-design (T-143-04, accepted in threat model).

## Self-Check: PASSED

Files confirmed to exist:
- `/Users/jon/projects/sigra/.claude/worktrees/agent-ac4dad9dd399b077d/test/example/priv/playwright/playwright.config.ts` — modified (DEMO_SHOWCASE_SPEC, demo-showcase-chromium project), committed 3239dd1
- `/Users/jon/projects/sigra/.claude/worktrees/agent-ac4dad9dd399b077d/test/example/priv/playwright/tests/demo-showcase.spec.ts` — created, committed 5325aaf
- `/Users/jon/projects/sigra/.claude/worktrees/agent-ac4dad9dd399b077d/test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/demo-credentials-demo-showcase-chromium.png` — created, 78 KB, committed 5325aaf
- `/Users/jon/projects/sigra/.claude/worktrees/agent-ac4dad9dd399b077d/test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/admin-user-list-demo-showcase-chromium.png` — created, 120 KB, committed 5325aaf
- `/Users/jon/projects/sigra/.claude/worktrees/agent-ac4dad9dd399b077d/test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/admin-user-detail-demo-showcase-chromium.png` — created, 102 KB, committed 5325aaf
- `/Users/jon/projects/sigra/.claude/worktrees/agent-ac4dad9dd399b077d/test/example/priv/playwright/tests/demo-showcase.spec.ts-snapshots/audit-explorer-demo-showcase-chromium.png` — created, 85 KB, committed 5325aaf
- `/Users/jon/projects/sigra/.claude/worktrees/agent-ac4dad9dd399b077d/.github/workflows/ci.yml` — modified (Run demo-showcase spec step), committed b65978f
- `/Users/jon/projects/sigra/.claude/worktrees/agent-ac4dad9dd399b077d/lib/sigra/admin/live/user_show_live.ex` — modified (mfa_label fix), committed 5325aaf

Commits confirmed:
- `3239dd1` — feat(143-02): add demo-showcase-chromium project partition to playwright.config.ts
- `5325aaf` — feat(143-02): add demo-showcase spec with 4 committed PNG baselines
- `b65978f` — feat(143-02): add Run demo-showcase spec step to CI example_playwright_smoke job
