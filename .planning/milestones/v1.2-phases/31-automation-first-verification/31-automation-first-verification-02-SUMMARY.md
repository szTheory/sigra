---
phase: 31-automation-first-verification
plan: 2
subsystem: testing
tags: [playwright, admin, artifacts, screenshots, dark-mode, mobile, impersonation, audit, checkpoints, browser-contract]

requires:
  - phase: 27-admin-access-foundation
    provides: example-app admin routes, scope chrome, policy seams
  - phase: 28-user-operations-surface
    provides: /admin/users search/detail + session revoke UI
  - phase: 29-secure-impersonation
    provides: sudo gate, impersonation start/stop, persistent banner
  - phase: 30-audit-exploration-and-export
    provides: /admin/audit explorer, scoped CSV export links
  - phase: 31-automation-first-verification (plan 1)
    provides: partitioned Playwright projects (admin-checkpoints-chromium / -mobile / -dark) and shared captureAdminCheckpoint helper
provides:
  - Canonical Phase 31 admin browser contract locked into three behavior-truth specs (admin-user-operations, impersonation, admin-audit) with describe blocks and header comments that name the D-04 slice each owns and the ExUnit homes for the permutation matrices they deliberately do NOT cover
  - New test/example/priv/playwright/tests/admin-checkpoints.spec.ts capturing the five D-28 reviewer pages (global user index, user detail, organization-scoped admin, active impersonation banner on a non-admin page, audit explorer) across admin-checkpoints-chromium, admin-checkpoints-mobile, and admin-checkpoints-dark with deterministic per-project screenshot naming
  - GREEN-step captureAndVerify(page, testInfo, name) wrapper that asserts every curated checkpoint lands on disk as a non-empty PNG, turning D-19/D-20's reviewer-artifact promise into an explicit test-time contract
affects:
  - 31-04 (CI artifact publication — it can now rely on exactly 15 curated PNGs per run, with deterministic paths under Playwright's project-specific output directories)

tech-stack:
  added: []
  patterns:
    - "Describe-block contract tagging (Phase N admin X browser contract (D-04 slice)) so every admin spec's scope is self-documenting at test-list output time"
    - "captureAndVerify wrapper around captureAdminCheckpoint: filesystem-level assertion on every curated screenshot so silently-missing reviewer artifacts fail loudly"
    - "Single seeded checkpoint test per project: one fixture setup, five canonical pages captured in one authenticated journey — LiveView longpoll runtime stays bounded"

key-files:
  created:
    - test/example/priv/playwright/tests/admin-checkpoints.spec.ts
  modified:
    - test/example/priv/playwright/tests/admin-user-operations.spec.ts
    - test/example/priv/playwright/tests/impersonation.spec.ts
    - test/example/priv/playwright/tests/admin-audit.spec.ts

key-decisions:
  - "Adapted the plan's verify command (--project=chromium --project=mobile --project=dark-chromium) to the wave-1 lane names (--project=chromium --project=admin-checkpoints-chromium --project=admin-checkpoints-mobile --project=admin-checkpoints-dark) because the plan pre-dates Plan 31-01's final partitioning decision and the named projects it references (mobile, dark-chromium) either exclude the checkpoint spec or do not exist"
  - "Used platform-admin+ email prefix for the checkpoint admin because Example.SigraAdminPolicy grants platform-admin only to that prefix; without it /admin/* would redirect or 403 and the checkpoint pages would never render"
  - "Captured org-scoped-admin on /admin/organizations/:slug/users rather than /admin/organizations/:slug so reviewers see a dense data-rich list layout rather than the landing stub, matching D-28's 'dense data layout' intent"
  - "Stopped impersonation before the audit checkpoint so the explorer renders from a banner-free admin session — reviewers see the audit chrome reviewers actually use, with impersonation attribution in the visible rows rather than in a stuck banner"
  - "Kept the checkpoint spec to one test per project (three runs total) instead of one test per page (fifteen runs) so fixture setup runs once per project; LiveView longpoll makes per-test setup cost dominant"

patterns-established:
  - "Every admin browser spec self-identifies its D-04 slice in its describe block and header comment, naming the ExUnit homes for the matrices it intentionally does not cover — so 'why is this assertion here' is answerable from test-list output alone"
  - "Screenshot helper call sites are wrapped with a filesystem-existence assertion; the reviewer-artifact contract is verified, not implied"
  - "Single-journey checkpoint specs: seed once, walk the canonical pages in order, capture on arrival; a single spec body serves all three partitioned projects via Playwright's project matrix"

requirements-completed:
  - VFY-01
  - VFY-02
  - VFY-04

duration: 28min
completed: 2026-04-17
---

# Phase 31 Plan 2: Example-App Admin Browser Contract + Checkpoint Inventory Summary

**Locked the canonical Phase 31 admin browser contract into the three behavior-truth specs and added admin-checkpoints.spec.ts producing 15 curated reviewer screenshots (5 D-28 pages × 3 partitioned projects) with a filesystem-level assertion that every screenshot landed on disk.**

## Performance

- **Duration:** ~28 min
- **Started:** 2026-04-17T02:58:00Z (approx — worktree base reset timestamp)
- **Completed:** 2026-04-17T03:26:00Z
- **Tasks:** 2
- **Files modified:** 4 (1 new spec, 3 tightened behavior specs)

## Accomplishments

- Tightened admin-user-operations.spec.ts, impersonation.spec.ts, and admin-audit.spec.ts describe blocks + header comments so each spec now explicitly calls out the D-04 slice it owns (1/2, 3, 4) and the ExUnit modules that own the negative-case / permutation matrices it intentionally does NOT absorb.
- Authored tests/admin-checkpoints.spec.ts covering the five D-28 reviewer pages in a single seeded journey per project, routed automatically into admin-checkpoints-chromium, admin-checkpoints-mobile, and admin-checkpoints-dark via wave 1's testMatch partitioning.
- Added a captureAndVerify wrapper that asserts each curated screenshot exists on disk as a non-empty PNG, so a regression in the helper, project partitioning, or testInfo.outputPath plumbing would fail the spec loudly instead of silently shipping missing reviewer artifacts.
- Verified that a clean passing run of the full partitioned admin matrix produces exactly 15 curated screenshots (5 pages × 3 projects) and zero retained trace/video/failed-screenshot output, matching D-20, D-24, and D-25's green-run artifact policy.
- Kept the behavior suite on chromium-only and the dark + mobile coverage scoped to the checkpoint spec, so the full admin matrix stays at 8 tests (5 behavior on chromium + 3 checkpoint runs) rather than ballooning across every viewport/theme combination.

## Task Commits

Each task was committed atomically:

1. **Task 1: Lock the Phase 31 example-app browser contract and checkpoint inventory in specs** — `13d96e5` (test — TDD RED gate: describe/comment tightening + new admin-checkpoints.spec.ts)
2. **Task 2: Turn the example-app admin journeys and checkpoints green without widening the browser boundary** — `a746e7c` (feat — TDD GREEN gate: captureAndVerify wrapper asserting each curated screenshot lands on disk)

## Files Created/Modified

- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` (new) — single-test-per-project spec covering the five D-28 pages via one seeded journey; uses captureAndVerify to assert each curated screenshot exists on disk.
- `test/example/priv/playwright/tests/admin-user-operations.spec.ts` — added a Phase 31 contract header comment and renamed the describe block to "Phase 31 admin user operations browser contract (D-04 1/2)"; no behavior changes.
- `test/example/priv/playwright/tests/impersonation.spec.ts` — added a Phase 31 contract header comment and renamed the describe block to "Phase 31 admin impersonation browser contract (D-04 3)"; no behavior changes.
- `test/example/priv/playwright/tests/admin-audit.spec.ts` — added a Phase 31 contract header comment and renamed the describe block to "Phase 31 admin audit browser contract (D-04 4)"; no behavior changes.

## Decisions Made

- **Picked `/admin/organizations/:slug/users` for checkpoint 3.** The pure landing path `/admin/organizations/:slug` is valid per the router but renders the org landing stub. D-28 names "dense data layout" and "action visibility" as the reasons this checkpoint matters, so the users list path gives reviewers more signal per screenshot. Either is valid per D-28; documenting the choice here for future plans.
- **Stopped impersonation before the audit checkpoint.** The impersonation banner is already captured in its own checkpoint (page 4). Leaving it active on the audit page would double-capture the banner while obscuring the actual audit explorer chrome reviewers care about. D-28 lists "filter/export usability" as the audit-checkpoint purpose, not "banner persistence on audit" — the impersonation-banner checkpoint already proves persistence.
- **Single test per project, not per page.** One test seeds fixtures once and walks the five pages in an authenticated sequence. Five per-page tests would repeat register / createOrganization / re-login 4-5 times per project, tripling LiveView longpoll runtime without adding coverage.
- **Added filesystem-existence assertion as the GREEN step (Task 2).** The underlying admin UI already ships from Phases 27-30, so a pure "make it pass" step against the wave-1 helper would have been a no-op. Turning D-19/D-20's artifact promise into a test-time invariant is real implementation work inside the plan's scope (D-19 explicitly requires artifacts "on every run, not only on failure"), and it guards against silent regressions in the screenshot pipeline.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 — Blocking] Adapted the plan's --project flags to the wave-1 lane names**
- **Found during:** Task 1 verify
- **Issue:** The plan's verify command uses `--project=chromium --project=mobile --project=dark-chromium`. The `mobile` project is configured by wave 1 to excludes the admin behavior + checkpoint specs (testIgnore regex), and `dark-chromium` does not exist as a project name. Running the plan's verify verbatim would produce zero checkpoint runs and no dark-mode artifact.
- **Fix:** Adapted the verify call to `--project=chromium --project=admin-checkpoints-chromium --project=admin-checkpoints-mobile --project=admin-checkpoints-dark`, which routes the three behavior specs into chromium and the checkpoint spec into all three admin-checkpoints-* lanes per the wave 1 partitioning design.
- **Files modified:** none in source (verify-command-only adaptation; the plan's verify text was authored before the wave-1 SUMMARY's final lane names were fixed).
- **Verification:** `npx playwright test --list` confirms 5 behavior tests on `chromium` + 3 checkpoint runs across the three `admin-checkpoints-*` projects, with zero cross-project duplication.
- **Committed in:** n/a (verify-only adaptation, no source change).

**2. [Rule 3 — Blocking] Used the `platform-admin+` email prefix in admin-checkpoints.spec.ts**
- **Found during:** Task 1 initial spec run (first `waitForLiveViewReady` after `/admin/users` navigation timed out)
- **Issue:** `Example.SigraAdminPolicy.platform_admin?/1` grants platform-admin ONLY to users whose email starts with `platform-admin+`. My first draft used `checkpoint-admin-${suffix}@example.test`, which did not match and caused the admin routes to redirect/403 instead of rendering. Without this prefix the entire checkpoint journey fails on the first checkpoint.
- **Fix:** Changed admin email to `platform-admin+checkpoint-${suffix}@example.test` and added an inline comment pointing at the policy module so future authors do not trip the same gate.
- **Files modified:** test/example/priv/playwright/tests/admin-checkpoints.spec.ts
- **Verification:** Re-running the checkpoint spec on admin-checkpoints-chromium passed all five checkpoint assertions and produced all five expected screenshots.
- **Committed in:** `13d96e5` (Task 1 commit — the fix was part of the initial spec authoring).

---

**Total deviations:** 2 auto-fixed (both Rule 3 — blocking). Both were caught and resolved during Task 1 before any behavior regression shipped.
**Impact on plan:** No scope change. Deviation 1 is pure verify-command adaptation (plan pre-dates wave 1's lane names). Deviation 2 was a one-line fixture fix caught on the first run.

## Issues Encountered

- **Worktree base pre-dates the plan-file commit.** The worktree was hard-reset to `a104901` per the orchestrator's worktree_branch_check. At that commit, the new plan-file 31-02-PLAN.md, 31-CONTEXT.md, and 31-PATTERNS.md exist only as untracked files in the main worktree's working tree. To execute the plan, those three files were copied into the worktree filesystem as read-only planning input; they were NOT staged or committed by this plan (they belong to the orchestrator's phase scaffolding, not Plan 31-02's deliverables). This matches the pattern Plan 31-01 documented under the same heading.
- **Playwright npm deps not installed in the worktree.** The worktree's `test/example/priv/playwright/node_modules/` is empty at base `a104901`. Ran `npm ci` (lockfile-locked install) to get `@playwright/test` 1.59.1 before the verify step. No lockfile changes.

## Threat Flags

None. All three `mitigate` dispositions in the plan's `<threat_model>` are addressed in-commit:

| Threat | Mitigation |
| --- | --- |
| T-31-04 (example-app Playwright specs absorbing negative-case matrices) | Every admin spec's header comment explicitly names the ExUnit modules that own the permutation matrices (impersonation_test.exs, forbid_during_impersonation_test.exs, admin/authorizer_test.exs, admin/audit/query_test.exs, audit_export_controller_test.exs, impersonation_blocked_ops_test.exs). The checkpoint spec's header comment also names D-06 and forbids denial/forbidden/malformed assertions. |
| T-31-05 (checkpoint suite runtime ballooning) | Checkpoint spec is one test per project (three total runs), not one test per page (fifteen). Full admin matrix stays at 8 tests. |
| T-31-06 (passing-run screenshot leakage) | captureAndVerify asserts each *named* checkpoint exists; raw trace/video/failed-screenshot retention stays at zero on passing runs (verified: `find test-results -name trace.zip -o -name video.webm -o -name 'test-failed*'` returned 0). |

## User Setup Required

None — no external service configuration required. The checkpoint spec uses the example app's existing fixture-seeded paths (register + createOrganization) and the `platform-admin+` policy prefix already shipped by Phase 27.

## Next Phase Readiness

- **Ready for Plan 31-04 (CI artifact publication).** Artifact file locations are deterministic: each curated PNG lives at `test-results/<test-dir>/<project>/<adminArtifactName>.png`, with the project name baked into the filename. CI upload steps can rely on `test/example/priv/playwright/test-results/**/admin-*.png` as the curated-screenshot selector and `test/example/priv/playwright/playwright-report/` as the HTML report path, matching D-19/D-20/D-21's pass/fail split.
- **Concern to carry forward.** The plan's own verify command uses project names that wave 1 renamed (see Deviations §1). If Plan 31-04's CI job templates copy the plan's verify text verbatim, they will produce zero checkpoint runs and no artifacts. Plan 31-04 should base its CI commands on `--project=admin-checkpoints-chromium|mobile|dark` per the wave 1 SUMMARY's partitioning contract.

## TDD Gate Compliance

This plan is `type=execute` but Task 1 is `tdd="true"`. Gate sequence in the resulting git log:

1. `13d96e5 test(31-02): lock Phase 31 admin browser contract and checkpoint inventory` — RED gate.
2. `a746e7c feat(31-02): verify curated admin checkpoint artifacts land on disk` — GREEN gate.

Both required gates present. Noted for transparency: the Phase 27-30 admin UI under test was already shipped when Task 1 authored its specs, so the RED commit's new spec would pass against the live app on its own. The GREEN commit adds a real implementation step (the `captureAndVerify` filesystem assertion) that turns D-19/D-20's reviewer-artifact promise into a test-time invariant, giving the plan a substantive GREEN transition instead of an empty commit.

## Self-Check: PASSED

Verified post-write:

- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — FOUND
- `test/example/priv/playwright/tests/admin-user-operations.spec.ts` — FOUND (modified)
- `test/example/priv/playwright/tests/impersonation.spec.ts` — FOUND (modified)
- `test/example/priv/playwright/tests/admin-audit.spec.ts` — FOUND (modified)
- Task 1 commit `13d96e5` — FOUND in `git log`
- Task 2 commit `a746e7c` — FOUND in `git log`
- Partitioning: `npx playwright test --list ...` → 5 behavior tests on `chromium`, 3 checkpoint runs across `admin-checkpoints-chromium|mobile|dark`; zero cross-project duplication.
- Full matrix: `npx playwright test ... --project=chromium --project=admin-checkpoints-{chromium,mobile,dark}` → 8 passed, 0 failed.
- Artifact policy: 15 curated `admin-*-<project>.png` files produced; 0 trace.zip / video.webm / test-failed*.png retained on the clean passing run.

---

*Phase: 31-automation-first-verification*
*Completed: 2026-04-17*
