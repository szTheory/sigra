---
phase: 95-optional-dep-boot-validation-mix-sigra-doctor-hard-02
plan: 4
subsystem: infra
tags: [oban, bcrypt, eqrcode, ci, docs, optional-deps]
requires:
  - phase: 95-02
    provides: runtime optional-dependency enforcement for async email, bcrypt migration, and TOTP QR rendering
  - phase: 95-03
    provides: mix sigra.doctor and warning-clean optional-dependency diagnostics
provides:
  - always-defined lifecycle workers with tagged Oban-missing queue entrypoints
  - targeted Oban-off, bcrypt-off, and EQRCode-off CI jobs
  - maintainer and adopter docs aligned to mix sigra.doctor and optional-until-enabled behavior
  - Phase 95 validation and verification closeout artifacts
affects: [phase-95, hard-02, ci, docs]
tech-stack:
  added: []
  patterns: [always-defined optional worker modules, dep-off CI lanes with real missing-dep assertions, doctor-first maintainer diagnosis]
key-files:
  created:
    - test/sigra/workers/optional_deps_test.exs
    - .planning/phases/95-optional-dep-boot-validation-mix-sigra-doctor-hard-02/95-VALIDATION.md
    - .planning/phases/95-optional-dep-boot-validation-mix-sigra-doctor-hard-02/95-VERIFICATION.md
  modified:
    - lib/sigra/workers/account_deletion.ex
    - lib/sigra/workers/audit_cleanup.ex
    - lib/sigra/workers/token_cleanup.ex
    - lib/sigra/workers/cleanup_expired_invitations.ex
    - .github/workflows/ci.yml
    - README.md
    - MAINTAINING.md
    - guides/introduction/troubleshooting-install.md
    - guides/recipes/deployment.md
key-decisions:
  - "Kept lifecycle worker modules always defined while guarding only Oban-specific entrypoints behind the compile-safe seam."
  - "Used dedicated dep-off CI jobs with real mix run assertions instead of broad suite runs or a mandatory Joken-off lane."
  - "Routed both maintainer and adopter diagnosis through mix sigra.doctor and the optional-until-enabled rule."
patterns-established:
  - "Optional worker pattern: module always exists, queue entrypoint calls Sigra.OptionalDeps.ensure_available!/2."
  - "CI dep-off proof pattern: patch mix.exs in-job, fetch reduced deps, then execute one real missing-dep assertion plus targeted phase coverage."
requirements-completed: [HARD-02]
duration: 10 min
completed: 2026-04-30
---

# Phase 95 Plan 4 Summary

**Lifecycle Oban workers now stay visible, CI proves Oban/bcrypt/EQRCode-off behavior, and Phase 95 closes with doctor-first maintainer/adopter guidance**

## Performance

- **Duration:** 10 min
- **Started:** 2026-04-30T21:24:00Z
- **Completed:** 2026-04-30T21:34:15Z
- **Tasks:** 3
- **Files modified:** 12

## Accomplishments

- Replaced the remaining compile-time worker disappearance wrappers with always-defined lifecycle worker modules that raise the tagged async dependency error at queue entry.
- Added dedicated Oban-off, bcrypt-off, and EQRCode-off CI jobs that patch `mix.exs`, fetch the reduced dependency graph, and execute real missing-dependency assertions.
- Aligned README, maintainer guidance, deployment/troubleshooting docs, and Phase 95 validation/verification artifacts around `mix sigra.doctor` and the optional-until-enabled contract.

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove conditional Oban worker disappearance from the remaining lifecycle modules** - `660a364` (test), `b0f4398` (feat)
2. **Task 2: Add the targeted dep-off CI matrix and keep Joken out of the required lanes** - `dfb5b52` (feat)
3. **Task 3: Align docs plus validation and verification artifacts to the shipped optional-dep contract** - `c048594` (docs)

_Note: Task 1 followed TDD with a failing regression commit before the implementation commit._

## Files Created/Modified

- `test/sigra/workers/optional_deps_test.exs` - Regression coverage proving lifecycle workers remain defined and fail with the tagged async dependency error.
- `lib/sigra/workers/account_deletion.ex`, `lib/sigra/workers/audit_cleanup.ex`, `lib/sigra/workers/token_cleanup.ex`, `lib/sigra/workers/cleanup_expired_invitations.ex` - Always-defined worker modules with registry-backed queue entrypoints.
- `.github/workflows/ci.yml` - Oban-off, bcrypt-off, and EQRCode-off merge-gate jobs with targeted proof commands.
- `README.md`, `MAINTAINING.md`, `guides/introduction/troubleshooting-install.md`, `guides/recipes/deployment.md` - User and maintainer guidance for `mix sigra.doctor` and optional dependencies.
- `.planning/phases/95-optional-dep-boot-validation-mix-sigra-doctor-hard-02/95-VALIDATION.md`, `.planning/phases/95-optional-dep-boot-validation-mix-sigra-doctor-hard-02/95-VERIFICATION.md` - Phase closeout contract and recorded evidence.

## Decisions Made

- Kept the compile-safe `if Code.ensure_loaded?(Oban.Worker)` seam only around Oban-specific entrypoints so modules no longer disappear when Oban is absent.
- Used `mix run -e` assertions inside CI dep-off jobs to prove real missing-dependency behavior without adding extra helper scripts or broad suite runs.
- Left Joken out of the required dep-off matrix because doctor/warning/test coverage from `95-03` already proves that contract and the plan explicitly constrained the matrix to Oban, bcrypt, and EQRCode.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The first CI workflow patch used an unquoted inline `run:` command with colons, which broke YAML parsing. The lane steps were converted to block scalars and the workflow was re-validated with `python3` YAML parsing before commit.
- Task 2 had no separate local RED harness because the owned surface was only `.github/workflows/ci.yml`; verification was kept concrete through grep checks and YAML parsing instead of inventing a fake test artifact.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 95 is ready to close once `.planning` state metadata is updated and the summary commit lands.
- Phase 94 remains independent and untouched by this plan’s code changes.

## Self-Check: PASSED

- Verified summary, validation, verification, and worker regression files exist on disk.
- Verified task commits `660a364`, `b0f4398`, `dfb5b52`, and `c048594` exist in git history.
