---
phase: 248-exact-source-release-gate
plan: 03
subsystem: release-automation
tags: [github-actions, environments, credentials, hex-publish, workflow-contracts]
requires:
  - phase: 248-exact-source-release-gate
    provides: Exact-source release checks and a guarded exact-head merge workflow
provides:
  - Least-privilege release workflow permissions and non-cancelling per-run concurrency
  - Main-only environment policies and a fail-closed live policy preflight
  - Step-scoped Release Please and Hex credentials with boolean-only presence checks
affects: [248-04, 248-05, release-automation, hex-publish]
actuals:
  tokens: 4719
  tasks: 3
  commits: 3
tech-stack:
  added: []
  patterns: ["Environment-scoped credentials with exact-main deployment policy preflight"]
key-files:
  created:
    - scripts/ci/release-environment-preflight.sh
    - scripts/ci/release-environment-preflight.test.sh
    - .planning/phases/248-exact-source-release-gate/248-USER-SETUP.md
  modified:
    - .github/workflows/release-please.yml
    - .github/workflows/release-pr-automerge.yml
    - .github/workflows/hex-publish.yml
    - test/sigra/planning/phase_248_release_gate_contract_test.exs
key-decisions:
  - "Keep repository-level secret copies until each environment copy is confirmed by name; GitHub does not expose saved values for transfer."
  - "Require can_admins_bypass=false in the live environment preflight as defense in depth."
patterns-established:
  - "Check required secret presence through booleans and never pass credential values to the policy helper."
requirements-completed: [AUTO-01]
coverage:
  - id: D1
    description: "Release workflows use scoped permissions, unique non-cancelling run groups, and separate dry-run and publish credentials."
    requirement: AUTO-01
    verification:
      - kind: unit
        ref: test/sigra/planning/phase_248_release_gate_contract_test.exs
        status: pass
      - kind: other
        ref: "actionlint -shellcheck=0 on release-please.yml, release-pr-automerge.yml, hex-publish.yml, and ci.yml"
        status: pass
    human_judgment: false
  - id: D2
    description: "Both privileged GitHub environments permit exactly main and deny administrator bypass."
    requirement: AUTO-01
    verification:
      - kind: unit
        ref: scripts/ci/release-environment-preflight.test.sh
        status: pass
      - kind: integration
        ref: "bash scripts/ci/release-environment-preflight.sh --repository szTheory/sigra"
        status: pass
    human_judgment: false
  - id: D3
    description: "Release token and Hex publish key are installed in their environment scopes and repository-level copies are removed after confirmation."
    requirement: AUTO-01
    verification: []
    human_judgment: true
    rationale: "Target environment secret names are not present yet, and copying secret values requires the user's secure source of truth. The checklist records the remaining transfer and verification steps."
duration: 157 min
completed: 2026-10-08
status: complete
plan_head_before: bc0a6029a
plan_head_after: ba79b324eb6dec9b2c5e8228e917b5fcef26df34
---

# Phase 248 Plan 03: Workflow Permissions and Environment Credentials Summary

**Release evaluation and recovery now use least-privilege permissions, non-cancelling run identities, exact-main environment policies, and step-scoped credentials.**

## Performance

- **Duration:** 157 min
- **Started:** 2026-10-08T19:57:20Z
- **Completed:** 2026-10-08T22:34:38Z
- **Tasks:** 3
- **Files modified:** 6 implementation and test files

## Accomplishments

- Scoped release workflow permissions and attached credential-consuming jobs to their matching GitHub environments. Release evaluations and manual recovery use unique run/attempt concurrency groups that do not cancel one another.
- Added a fail-closed policy helper and hermetic fixtures. It requires exactly one `main` branch rule for both environments, `can_admins_bypass=false`, and boolean-only credential presence checks.
- Kept Hex dry-run and publish authority on their respective steps in both automated and manual release workflows. Added contract coverage for all privileged callers.
- Created [248-USER-SETUP.md](./248-USER-SETUP.md) for the two secret transfers that require access to the user's secure source of truth.

## Task Commits

1. **Task 1: Scope event-causing tokens and concurrency** — `09338c38d` (`fix`)
2. **Task 2: Add exact-main policy preflight** — `3ba83c8b9` (`test`)
3. **Task 3: Isolate credentials across release entry points** — `ba79b324e` (`test`)

**Plan metadata:** pending.

## Files Created/Modified

- `.github/workflows/release-please.yml` — Main-only Release Please guard, scoped token access, environment preflight, and separated Hex credentials.
- `.github/workflows/release-pr-automerge.yml` — Environment-scoped merge token with exact-main policy preflight.
- `.github/workflows/hex-publish.yml` — Trusted-main manual recovery and separate dry-run/publish keys.
- `scripts/ci/release-environment-preflight.sh` — Live policy and required-secret-presence gate.
- `scripts/ci/release-environment-preflight.test.sh` — Nine hermetic exact-main, admin-bypass, and missing-policy cases.
- `test/sigra/planning/phase_248_release_gate_contract_test.exs` — Six workflow contracts, including boolean-only credential checks on all privileged callers.

## Decisions Made

- Required `can_admins_bypass=false` in addition to the exact-main branch policy so later environment toggles cannot weaken the trust boundary.
- Kept repository secret copies until the environment copies are confirmed by name. Secret values cannot be read from GitHub and were not copied, logged, or deleted.

## Deviations from Plan

**1. [Rule 2 - Missing critical protection] Reject administrator bypass**
- **Found during:** Task 2
- **Issue:** An exact-main rule alone would not detect an enabled administrator bypass.
- **Fix:** The helper now requires `can_admins_bypass=false`, with an explicit negative fixture.
- **Files modified:** `scripts/ci/release-environment-preflight.sh`, `scripts/ci/release-environment-preflight.test.sh`
- **Verification:** Fixture suite passes 9/9 and live environment preflight passes.
- **Committed in:** `3ba83c8b9`

**Total deviations:** 1 auto-fixed (Rule 2).
**Impact on plan:** Defense-in-depth strengthens the planned main-only secret boundary.

## Validation Evidence

- `bash scripts/ci/release-environment-preflight.test.sh` — 9 passed, 0 failed.
- `mix test test/sigra/planning/phase_248_release_gate_contract_test.exs` — 6 tests, 0 failures.
- `bash scripts/ci/release-environment-preflight.sh --repository szTheory/sigra` — both environments report `main`; live preflight passes.
- `actionlint -shellcheck=0` across the three release workflows and `ci.yml` — passed; plain `actionlint` on the three changed release workflows — passed.
- Plain `actionlint` including inherited `ci.yml` reports six existing ShellCheck warnings in that file. Its unrelated changes were preserved and not staged.
- Scoped `git diff --check` passed. Only the inherited `ci.yml` remains modified among Plan03 workflow paths.

## User Setup Required

**External services require manual configuration.** See [248-USER-SETUP.md](./248-USER-SETUP.md) for adding `RELEASE_PLEASE_TOKEN` to `release-automation` and `HEX_API_KEY` to `hex-publish`, verifying the environment secret names, and removing repository copies only after confirmation. The current environment-name check showed neither target copy present; the dry-run key is already present.

## Next Phase Readiness

Plan03 implementation and automated policy verification are complete. The external credential checklist remains incomplete, so release transitions that require those secrets will fail closed. Plan04 is the next runnable plan in Phase248; no Plan04 work is included here.

---
*Phase: 248-exact-source-release-gate*
*Completed: 2026-10-08*

## Self-Check: PASSED

- Summary and user-setup files exist.
- All three task commits are ancestors of the current HEAD.
- Task commit count and plan head metadata match `git rev-list bc0a6029a..HEAD`.
