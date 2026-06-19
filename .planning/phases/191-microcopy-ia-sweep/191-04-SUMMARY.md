---
phase: 191-microcopy-ia-sweep
plan: "04"
subsystem: admin-checkpoints-baselines
tags: [playwright, snapshot-recapture, canary-guard, zero-human-uat]
depends_on: [191-02, 191-03]
requires: [COPY-01, COPY-02, COPY-03]
provides: [admin-checkpoint-baselines-updated, snapshot-allowlist-reset]
affects:
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-chromium.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-dark.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-mobile.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-chromium.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-dark.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-mobile.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-chromium.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-dark.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-mobile.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-scoped-admin-admin-checkpoints-chromium.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-scoped-admin-admin-checkpoints-dark.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-scoped-admin-admin-checkpoints-mobile.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-detail-admin-checkpoints-chromium.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-detail-admin-checkpoints-dark.png
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-detail-admin-checkpoints-mobile.png
  - test/example/priv/playwright/snapshot-allowlist
tech_stack:
  added: []
  patterns: [D-10-recapture-sequence, zero-human-uat, canary-guard]
key_files:
  created: []
  modified:
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-{chromium,dark,mobile}.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/global-user-index-admin-checkpoints-{chromium,dark,mobile}.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-overview-admin-checkpoints-{chromium,dark,mobile}.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/org-scoped-admin-admin-checkpoints-{chromium,dark,mobile}.png
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/user-detail-admin-checkpoints-{chromium,dark,mobile}.png
    - test/example/priv/playwright/snapshot-allowlist
decisions:
  - "admin-design MG-5/6 content-equivalence test failure is pre-existing data-state issue from Phase 188 (requires 25+ audit events for a user to render pagination); gate (a), (b), (c) all green; (a2) admin-design failure is not Phase 191 regression"
  - "SIGRA_EXAMPLE_URL=http://localhost:4011 must be set when running Playwright locally; default is http://localhost:4000 which collides with Rulestead Docker"
metrics:
  duration: "135 minutes"
  completed: "2026-06-18"
  tasks_completed: 1
  tasks_total: 1
  files_created: 0
  files_modified: 16
status: complete
---

# Phase 191 Plan 04: Playwright Baseline Recapture Summary

Zero-human recapture of 15 admin-checkpoint PNG baselines (5 slugs x 3 projects) whose visible copy changed in Wave 2. Phase 183-proven D-10 sequence: declare slugs in allowlist, pre-compile + boot on PORT=4011, run Playwright --update-snapshots=all, restore canary PNGs, run gate (a)+(b)+(c) GREEN, reset allowlist to empty.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Recapture 5 admin-checkpoint baselines + reset allowlist | 2dabcd2d | 15 PNG files + snapshot-allowlist |

## What Was Built

### Recaptured Baseline PNGs

**5 slug groups, 3 Playwright projects each = 15 PNGs updated:**

| Slug | Copy Changes Visible |
|------|---------------------|
| global-overview | "review risky accounts" → "review risky users"; "accounts need review" → "users need review"; "Review accounts" → "Review users"; "Review risky accounts" → "Review risky users"; "deletion-scheduled accounts" → "deletion-scheduled users"; "Accounts registered" → "Users registered" |
| user-detail | "revoke active logins" → "revoke active sessions"; "This account is not currently..." → "This user is not a member..."; "Recent Audit" → "Recent audit"; "Session revocation uses Sigra's..." → "Revoking a session signs the user out..."; "No active sessions." → "No active sessions"; "No MFA configured — recommend enabling..." → "No MFA configured — ask the user..." |
| org-overview | "Search org members, open account detail" → "Search organization members, open member detail"; "account needs"/"accounts need" → "member needs"/"members need"; "Review accounts" → "Review members"; "Investigate org events" → "Investigate organization events"; "invite teammates" → "invite members" |
| global-user-index | "Review the account before unlocking." → "Review the user before unlocking."; "Once accounts exist" → "Once users exist"; "Last activity: Not available" → "Last activity: None recorded" |
| org-scoped-admin | Same users_index_live.ex copy changes scoped to the org-scoped admin list view |

**Canary PNGs (impersonation-banner) — byte-identical (NOT recaptured):**
- impersonation-banner-admin-checkpoints-chromium.png: UNCHANGED
- impersonation-banner-admin-checkpoints-dark.png: UNCHANGED
- impersonation-banner-admin-checkpoints-mobile.png: UNCHANGED

**Canary verified via:** `git checkout -- test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/impersonation-banner-*.png`

### Recapture Sequence Executed (D-10 Phase 183-proven)

1. Declared 5 slugs in `test/example/priv/playwright/snapshot-allowlist`
2. Pre-compiled example: `cd test/example && PORT=4011 MIX_ENV=dev mix compile`
3. Booted: `PORT=4011 MIX_ENV=dev mix phx.server &`
4. Polled until server ready at http://localhost:4011/
5. Ran: `SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-checkpoints.spec.ts --update-snapshots=all --project=admin-checkpoints-chromium --project=admin-checkpoints-mobile --project=admin-checkpoints-dark` — 3 passed (59.3s)
6. Restored canary PNGs via `git checkout -- tests/...snapshots/impersonation-banner-*.png`
7. Restored non-affected slugs (user-audit, audit-explorer) via `git checkout --`
8. Ran recapture gate: `bash scripts/ci/snapshot-recapture-gate.sh global-overview user-detail org-overview global-user-index org-scoped-admin` — gate steps (a), (b), (c) passed; step (a2) admin-design failed (pre-existing, see Deviations)
9. Reset `snapshot-allowlist` to empty (comments only)
10. Killed background phx.server (`kill 51761`)
11. Ran `mix test` — 2399 tests, 2 failures (both pre-existing install-golden, see below)

## Verification Results

| Check | Result |
|-------|--------|
| gate step (a): admin-checkpoints compare 3 projects | PASS (3/3) |
| gate step (b): canary guard --require-all 5 slugs | PASS (5 changed, 0 canary delta) |
| gate step (c): ExUnit component byte-goldens | PASS (35/0) |
| gate step (a2): admin-design 3 projects | FAIL — pre-existing MG-5/6 data-state issue (see Deviations) |
| 15 PNGs changed, 0 canary PNGs changed | CONFIRMED (git diff --stat) |
| snapshot-allowlist empty (comments only) | CONFIRMED |
| mix test glossary_test.exs | PASS (1/0) |
| mix test components_test.exs | PASS (35/0) |
| mix test full suite | 2399 tests, 2 failures (pre-existing install-golden failures — see below) |

## Deviations from Plan

### Pre-existing Failures — Not Phase 191 Regressions

**1. [Pre-existing] admin-design MG-5/6 content-equivalence test failure (data-state dependent)**
- **Found during:** snapshot-recapture-gate.sh step (a2)
- **Test:** `admin-design.spec.ts:314 — MG-5 and MG-6 desktop and mobile representations are content-equivalent`
- **Error:** `expect(page.getByRole('link', { name: 'Previous page' })).toBeAttached()` — element not found
- **Root cause:** The test unconditionally asserts pagination controls exist for the first user in `/admin/users`. Pagination is only rendered when a user has 25+ audit events (cursor-based "honest pagination guard" hides nav entirely when results fit one page). With a fresh dev server, all newly-created test users have fewer than 25 events. The demo fixture user (admin@demo.vaultr.test, 784 events) sorts last (newest-first DESC) because newer test users appear first.
- **Phase 188 context:** This test WAS passing in Phase 188 because it was the first run after demo fixture users were inserted in June 2026, so they appeared first. Subsequent test runs created newer users that now appear before them.
- **Not a Phase 191 regression:** Phase 191 did NOT modify `admin-design.spec.ts`. The gate would fail identically on any fresh server without sufficient accumulated audit data.
- **Gate steps that are Phase 191-relevant:** (a) admin-checkpoints compare, (b) canary guard, (c) ExUnit — all GREEN.

**2. [Pre-existing] 2 install-golden mix test failures**
- `test/sigra/install/vault_promotion_test.exs:9` — undefined attribute "type" for CoreComponents.button/1 under --warnings-as-errors
- `test/sigra/install/golden_diff_test.exs:53` — generated-tree byte diff
- Verified present on clean origin/main, identical to Phase 02 SUMMARY documentation.

### Auto-fixed Issues

**1. [Rule 3 - Blocking] SIGRA_EXAMPLE_URL not set in Playwright run**
- **Found during:** Step 3 (initial Playwright run) — all 3 tests failed with LiveView timeout waiting for `[data-phx-session].phx-connected`
- **Issue:** Playwright default `baseURL` is `http://localhost:4000` (from `playwright.config.ts` line 71). Without `SIGRA_EXAMPLE_URL`, Playwright connected to the Rulestead Docker on port 4000 instead of the example dev server on port 4011. The 4000 server doesn't have LiveView sessions for Sigra registration, causing timeout on `waitForLiveViewReady`.
- **Fix:** Prefixed all `npx playwright test` calls with `SIGRA_EXAMPLE_URL=http://localhost:4011`
- **Commit:** 2dabcd2d (included in recapture run)

## Known Stubs

None. All 15 PNGs reflect the actual rendered admin UI with live data seeded by the Playwright fixtures. No placeholder copy remains.

## Threat Flags

None. This plan only updates PNG baselines (binary artifacts, no auth-boundary changes). The snapshot-allowlist was reset to empty (steady-state), preserving the merge-blocking canary guard invariant.

## Self-Check: PASSED

- global-overview-admin-checkpoints-chromium.png: FOUND (modified)
- global-overview-admin-checkpoints-dark.png: FOUND (modified)
- global-overview-admin-checkpoints-mobile.png: FOUND (modified)
- global-user-index-admin-checkpoints-chromium.png: FOUND (modified)
- global-user-index-admin-checkpoints-dark.png: FOUND (modified)
- global-user-index-admin-checkpoints-mobile.png: FOUND (modified)
- org-overview-admin-checkpoints-chromium.png: FOUND (modified)
- org-overview-admin-checkpoints-dark.png: FOUND (modified)
- org-overview-admin-checkpoints-mobile.png: FOUND (modified)
- org-scoped-admin-admin-checkpoints-chromium.png: FOUND (modified)
- org-scoped-admin-admin-checkpoints-dark.png: FOUND (modified)
- org-scoped-admin-admin-checkpoints-mobile.png: FOUND (modified)
- user-detail-admin-checkpoints-chromium.png: FOUND (modified)
- user-detail-admin-checkpoints-dark.png: FOUND (modified)
- user-detail-admin-checkpoints-mobile.png: FOUND (modified)
- snapshot-allowlist is empty (0 non-comment lines): CONFIRMED
- impersonation-banner canary PNGs: UNCHANGED (git diff empty for canary files)
- Commit 2dabcd2d: FOUND
- mix test glossary_test.exs: 1 test, 0 failures: CONFIRMED
- mix test components_test.exs: 35 tests, 0 failures: CONFIRMED
- mix test full suite: 2399 tests, 2 failures (both pre-existing install-golden): CONFIRMED
- gate step (a) admin-checkpoints compare: PASS (3/3): CONFIRMED
- gate step (b) canary guard --require-all 5 slugs: PASS: CONFIRMED
- gate step (c) ExUnit: PASS (35/0): CONFIRMED
