---
phase: 31-automation-first-verification
plan: 1
subsystem: testing
tags: [playwright, admin, artifacts, ci, screenshots, dark-mode, mobile, generated-host]

requires:
  - phase: 27-admin-access-foundation
    provides: example and generated-host admin routes, policy seams, and denial responses
  - phase: 28-user-operations-surface
    provides: admin-user-operations browser contract
  - phase: 29-secure-impersonation
    provides: impersonation browser contract
  - phase: 30-audit-exploration-and-export
    provides: admin-audit browser contract and scoped CSV export flow
provides:
  - Partitioned Playwright project layout separating admin behavior truth, checkpoint artifact capture, and generated-host parity
  - Reserved admin checkpoint lanes (chromium, mobile, dark-chromium) scoped to tests/admin-checkpoints.spec.ts so a later plan can drop the checkpoint spec into a pre-scoped project with curated screenshot + retained-video-on-failure policy
  - Shared admin artifact helper (captureAdminCheckpoint, adminArtifactName) emitting deterministic, reviewer-visible screenshot attachments for the Playwright HTML report
  - Generated-host parity spec locked to shell render, scope labels, admin navigation, allowed-org access, denied-global, and not-found-out-of-scope semantics only
affects:
  - 31-02 (example-app admin behavior plus checkpoint spec)
  - 31-03 (direct-path ExUnit + thin runtime smoke)
  - 31-04 (CI artifact publication)

tech-stack:
  added: []
  patterns:
    - Playwright project partitioning via testMatch/testIgnore to enforce coverage boundaries
    - Selective failure-oriented retained video scoped to checkpoint and generated-host lanes
    - Curated reviewer-facing screenshots via testInfo.attach with deterministic project-aware naming

key-files:
  created:
    - test/example/priv/playwright/helpers/adminArtifacts.ts
  modified:
    - test/example/priv/playwright/playwright.config.ts
    - test/example/priv/playwright/tests/admin-generated.spec.ts

key-decisions:
  - "Keep non-admin mobile coverage (golden-path, organizations, passkey-*) on the mobile project; only the admin behavior specs are narrowed to chromium so mobile admin coverage moves entirely into the dedicated checkpoint lane"
  - "Use testIgnore on chromium/mobile plus testMatch on the dedicated checkpoint/generated-host projects so each admin spec runs once in exactly one partitioned project"
  - "Scope video: retain-on-failure to the three admin-checkpoints-* projects and the admin-generated project only, per D-24"
  - "Curated screenshot attachment is used only on passing generated-host shell/organization checkpoints; denial paths rely on the project-level on-failure screenshot + retained video for diagnostics, per D-21"
  - "Reserve the admin-checkpoints.spec.ts partitioning surface in config even before the checkpoint spec exists, so Plan 2 can author that spec without re-touching the config"

patterns-established:
  - "Partitioned Playwright projects: one behavior-truth lane, N checkpoint lanes, and one generated-host lane, each scoped through testMatch or testIgnore regexes and commented with their D-number rationale"
  - "Shared screenshot helper returns an absolute path and attaches the image to testInfo so HTML reports become asynchronously reviewable without custom reporter plumbing"
  - "Deterministic artifact naming (<prefix>-<name>-<project>) keeps admin screenshots unique across projects and run-over-run comparisons"

requirements-completed:
  - VFY-01
  - VFY-02
  - VFY-04

duration: 7min
completed: 2026-04-17
---

# Phase 31 Plan 1: Admin Playwright Harness Partitioning Summary

**Partitioned the admin Playwright harness into one behavior-truth chromium lane, three reserved checkpoint lanes (chromium/mobile/dark-chromium) for curated artifacts, and one narrow generated-host parity lane, plus a shared screenshot helper that makes green runs asynchronously reviewable from the Playwright HTML report.**

## Performance

- **Duration:** ~7 min
- **Started:** 2026-04-17T02:46:39Z
- **Completed:** 2026-04-17T02:54:09Z
- **Tasks:** 2
- **Files modified:** 3 (1 new helper, 1 new narrow spec, 1 config update)

## Accomplishments

- Stopped admin behavior specs (admin-user-operations, impersonation, admin-audit) from silently duplicating under the mobile project; each admin behavior test now runs exactly once in the chromium lane.
- Reserved four new projects for future admin work: `admin-checkpoints-chromium`, `admin-checkpoints-mobile`, `admin-checkpoints-dark` (scoped to `tests/admin-checkpoints.spec.ts`), and `admin-generated` (scoped to `tests/admin-generated.spec.ts`).
- Added global `screenshot: 'only-on-failure'`, preserved `trace: 'on-first-retry'`, and scoped `video: 'retain-on-failure'` to just the failure-oriented checkpoint/generated-host lanes.
- Shipped a shared `captureAdminCheckpoint` / `adminArtifactName` helper with deterministic `<prefix>-<name>-<project>` naming that attaches screenshots into the HTML report.
- Kept `admin-generated.spec.ts` strictly on the six shipped parity seams (shell render, scope labels, admin navigation, allowed-org access, denied-global, not-found-out-of-scope) and added curated desktop/mobile shell + organization screenshots through the new helper.

## Task Commits

Each task was committed atomically:

1. **Task 1: Partition Playwright projects around admin behavior truth and checkpoint capture** - `28367e1` (feat)
2. **Task 2: Add shared admin artifact helpers and keep generated-host smoke parity-focused** - `12045ba` (feat)

## Files Created/Modified

- `test/example/priv/playwright/helpers/adminArtifacts.ts` (new) — exports `captureAdminCheckpoint` and `adminArtifactName`; uses `testInfo.outputPath` + `testInfo.attach` so the HTML report surfaces named reviewer screenshots without custom plumbing.
- `test/example/priv/playwright/playwright.config.ts` — replaced the flat `mobile`+`chromium` projects with six partitioned projects; added global `screenshot: 'only-on-failure'`, selective `video: 'retain-on-failure'` on checkpoint/generated-host lanes, and ignore/match regexes that keep admin behavior specs on chromium only.
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — locked to the six shipped parity seams, added four curated checkpoints (`shell-global-desktop`, `allowed-org-desktop`, `shell-global-mobile`, `allowed-org-mobile`) via the new helper, and documented that denial paths rely on the project-level failure-oriented artifact policy.

## Decisions Made

- **Preserved mobile coverage for non-admin specs.** Plan Task 1 says "keep retries/workers aligned" and "do not widen"; narrowing mobile to admin-only would have regressed existing `golden-path`, `organizations`, and `passkey-*` mobile coverage. Kept those on `mobile` via `testIgnore` while excluding the three admin behavior specs.
- **Reserved rather than mixed checkpoint projects.** Rather than overloading the existing `chromium`/`mobile` projects with checkpoint rules, added three explicit `admin-checkpoints-*` projects scoped to `tests/admin-checkpoints.spec.ts`. Plan 2 can author that spec without re-touching the config.
- **Named projects with an explicit lane suffix.** Used `admin-checkpoints-chromium`, `-mobile`, `-dark` instead of reusing existing `chromium` / `mobile` names. This makes the project-name column of `playwright test --list` unambiguous and simplifies upcoming CI artifact job names per D-28 through D-29.
- **Screenshot attachment scoped to passing-run reviewer value only.** Per D-20, D-21, and D-25, `captureAdminCheckpoint` is invoked on shell/organization success checkpoints, not on denial paths. Denial regressions fall back to the project-level `screenshot: 'only-on-failure'` + `video: 'retain-on-failure'` on the `admin-generated` lane.

## Deviations from Plan

None - plan executed as written. Pre-existing environmental state in the worktree (missing untracked installer templates and planning files inherited from prior phases' uncommitted work) was worked around without modifying the scope of Plan 31-01 — see **Issues Encountered** below.

## Issues Encountered

- **Worktree base commit pre-dates uncommitted installer templates.** The worktree was hard-reset to `d6448cc` (per the orchestrator's `worktree_branch_check` block). That commit lacks `priv/templates/sigra.install/core/{vault,encrypted_binary}.ex` and `scripts/ci/admin-acceptance-smoke.sh` — all three exist only as untracked files in the main worktree's working tree (accumulated from prior phases). To exercise the Task 2 verify command, those files were copied into the worktree filesystem as read-only scaffolding; **they were not staged or committed** as part of this plan because they belong to prior phases. The committed plan-31 artifacts contain only the three files listed under "Files Created/Modified".
- **Task 2 verify (admin-acceptance-smoke.sh) cannot fully run against this worktree's base commit.** The fresh-generated Phoenix app's `mix compile --warnings-as-errors` step fails because the base commit's `lib/sigra_web/router.ex` template injection references `SigraAdminSmokeWeb.Admin.ImpersonationController` and `SigraAdminSmokeWeb.Admin.AuditExportController`, both introduced in uncommitted phase 29/30 installer work. The failure is entirely in scaffolded-host code generated from the base-commit's installer, not in any file this plan created or modified. Task 2 deliverables were verified independently via `npx playwright test --list` (helper exports resolve, spec parses, tests route into the `admin-generated` project) and a short TypeScript import smoke that confirms `adminArtifactName` and `captureAdminCheckpoint` are exported with the expected signatures.

## Threat Flags

None. All three `mitigate` dispositions in the plan's `<threat_model>` are addressed in-commit:

| Threat | Mitigation |
| --- | --- |
| T-31-01 (tampered project matrix) | Explicit `testMatch`/`testIgnore` regexes per project; dedicated `admin-checkpoints-dark` lane so dark-mode coverage does not grow from an in-test theme toggle. |
| T-31-02 (generated-host suite drift) | `admin-generated.spec.ts` is locked to the six shipped parity seams; broader negative-case coverage explicitly deferred to ExUnit and the example-app behavior suite (D-06, D-15, D-18). |
| T-31-03 (indiscriminate artifact leakage) | `captureAdminCheckpoint` only attaches named passing-run screenshots; traces and retained video are selective and failure-oriented per D-20, D-21, D-24. |

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **Ready for Plan 31-02 (example-app admin behavior plus checkpoint spec).** The checkpoint project partitioning and screenshot helper are in place; `tests/admin-checkpoints.spec.ts` can be authored directly and will automatically route into `admin-checkpoints-chromium`, `admin-checkpoints-mobile`, and `admin-checkpoints-dark` without config changes.
- **Ready for Plan 31-04 (CI artifact publication).** Artifact file locations (`test/example/priv/playwright/playwright-report/` + per-test attachments under the project-specific output dirs) are already deterministic. CI upload steps can key off project-scoped output names.
- **Concern to carry forward.** The worktree-base environmental gap (missing installer templates, missing `admin-acceptance-smoke.sh`) is not a Plan 31-01 concern but the orchestrator should ensure later plans run against a more current base, or these pre-existing untracked files should be committed in a separate housekeeping step so the `admin-acceptance-smoke.sh` verify command can run unmodified.

## Self-Check: PASSED

Verified post-write:

- `test/example/priv/playwright/helpers/adminArtifacts.ts` — FOUND
- `test/example/priv/playwright/playwright.config.ts` — FOUND (modified; 90 insertions, 3 deletions vs. base)
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — FOUND (modified; committed as a new file in this worktree's history because the base commit lacks it)
- Task 1 commit `28367e1` — FOUND in `git log`
- Task 2 commit `12045ba` — FOUND in `git log`
- `npx playwright test --list tests/admin-user-operations.spec.ts tests/impersonation.spec.ts tests/admin-audit.spec.ts tests/admin-generated.spec.ts` — PASSED (5 behavior tests on `chromium`, 2 parity tests on `admin-generated`, 0 duplicated across projects)

---

*Phase: 31-automation-first-verification*
*Completed: 2026-04-17*
