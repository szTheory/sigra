---
phase: 22-passkeys-generator-wiring
plan: 04
subsystem: ci
tags: [installer, generator, passkeys, ci, smoke]
requires:
  - phase: 22-passkeys-generator-wiring
    provides: "Generated-app passkey opt-out omission coverage"
  - phase: 18-backfill-organizations-generator-wiring
    provides: "Install matrix and smoke harness patterns"
provides:
  - "Assets-enabled passkey opt-out smoke harness for both disabled combinations"
  - "Four-leg local/CI install matrix including both passkey opt-out combinations"
  - "Final verification notes for precommit and local act preflight blockers"
affects: [23, ci, generator-flags, passkeys]
tech-stack:
  added: []
  patterns:
    - "Fresh Phoenix app smoke harnesses that patch in local Sigra via path dep"
    - "Separate opt-out smoke coverage from passkey-enabled browser ceremony coverage"
key-files:
  created:
    - scripts/ci/passkeys-opt-out-smoke.sh
  modified:
    - priv/templates/sigra.install/core/mfa_challenge_live.ex
    - scripts/ci/install-matrix-local.sh
    - .github/workflows/ci.yml
key-decisions:
  - "The opt-out smoke harness exports a deterministic `CLOAK_KEY` because generated apps now boot a Vault process."
  - "The dedicated opt-out smoke job stays separate from Playwright/browser ceremony jobs to avoid multiplying expensive passkey-enabled coverage."
  - "Local `act` matrix reproduction remains preflight-blocked when a host process listens on `:5432`; that is an environment issue, not a code failure."
patterns-established:
  - "Asset-enabled omission smoke should validate compile, assets, migrate, and boot for both disabled passkey legs."
  - "Generated template regressions exposed by smoke should be fixed in the shared template before expanding CI coverage."
requirements-completed: [PK-02]
duration: 10 min
completed: 2026-04-16
---

# Phase 22 Plan 04: CI and Smoke Summary

**CI now covers the four organizations/passkeys flag combinations, and a dedicated assets-enabled opt-out smoke proves both disabled passkey legs through boot**

## Performance

- **Duration:** 10 min
- **Started:** 2026-04-16T13:20:10Z
- **Completed:** 2026-04-16T13:30:22Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added `scripts/ci/passkeys-opt-out-smoke.sh`, which scaffolds fresh Phoenix apps for both `--no-passkeys` and `--no-organizations --no-passkeys`, then verifies omitted assets/deps/config/routes plus compile, assets, migrate, and boot.
- Expanded `.github/workflows/ci.yml` and `scripts/ci/install-matrix-local.sh` to the four required install-matrix combinations.
- Fixed a generated-app compile regression in `mfa_challenge_live.ex` that the new smoke harness exposed.

## Task Commits

1. **Task 1: Add an assets-enabled `--no-passkeys` smoke harness** - `9c6c418` (feat)
2. **Task 2: Expand CI and local matrix reproduction to all four flag combinations** - `ac52563` (ci)

## Files Created/Modified

- `scripts/ci/passkeys-opt-out-smoke.sh` - runs both disabled passkey legs end to end with assets enabled, including a default `CLOAK_KEY` for generated Vault startup.
- `priv/templates/sigra.install/core/mfa_challenge_live.ex` - removes brittle generated comment output that the smoke harness caught during disabled-leg compilation.
- `scripts/ci/install-matrix-local.sh` - reproduces all four install-matrix legs locally with `act`.
- `.github/workflows/ci.yml` - adds `--no-passkeys` and `--no-organizations --no-passkeys` to the install matrix and runs the dedicated opt-out smoke job separately.

## Decisions Made

- Kept the new opt-out smoke independent from passkey-enabled Playwright/browser coverage.
- Treated the `CLOAK_KEY` requirement as part of the generated-app runtime contract and encoded a deterministic default in the smoke harness.
- Left the local `act` preflight failure as a reported environment blocker instead of stopping host services from the script.

## Deviations from Plan

- `test/support/install_fixture.ex` did not need changes; the standalone smoke harness was sufficient.
- The local matrix script could not complete in this environment because something on the host was already listening on TCP `:5432`, which the script intentionally blocks before `act` starts its own Postgres service.

## Issues Encountered

- The new smoke harness surfaced two real template/runtime issues before it went green: malformed generated comment output in `mfa_challenge_live.ex` and missing `CLOAK_KEY` at generated-app boot.
- `mix precommit` is still unavailable at the repo root: `** (Mix) The task "precommit" could not be found`.

## User Setup Required

None for the repository changes themselves. To run `scripts/ci/install-matrix-local.sh` locally, free TCP `:5432` first or let `act` use its own Postgres service without a host conflict.

## Next Phase Readiness

- Phase 23 can rely on both focused omission tests and an end-to-end opt-out smoke path in CI.
- The install matrix now exercises all four organizations/passkeys combinations continuously.

## Self-Check: PASSED

Verified:
- `.planning/phases/22-passkeys-generator-wiring/22-04-SUMMARY.md` exists
- `9c6c418` is present in git history
- `ac52563` is present in git history
- `bash scripts/ci/passkeys-opt-out-smoke.sh` passed
- `mix test test/sigra/install/generator_passkeys_opt_out_test.exs --max-failures 1` passed
- `bash scripts/ci/install-matrix-local.sh` was attempted and blocked by local TCP `:5432` preflight
- `mix precommit` was attempted and failed because no root task/alias exists

---
*Phase: 22-passkeys-generator-wiring*
*Completed: 2026-04-16*
