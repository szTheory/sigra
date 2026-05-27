---
phase: 127-versioned-auth-data-export
plan: 01
subsystem: testing
tags: [exunit, data-export, auth-export, tdd, security]

requires:
  - phase: none
    provides: phase entry point
provides:
  - Executable contract tests for versioned auth export lifecycle status
  - Structured omission inventory assertions for missing optional schemas
  - Configured-schema safe serialization and sensitive-field exclusion tests
affects: [127-versioned-auth-data-export, data-export, account-lifecycle]

tech-stack:
  added: []
  patterns:
    - In-test Ecto schemas plus deterministic fake repo for configured optional-schema proof
    - RED proof commits before production implementation

key-files:
  created:
    - .planning/phases/127-versioned-auth-data-export/127-01-SUMMARY.md
  modified:
    - test/sigra/data_export_test.exs

key-decisions:
  - "Kept Plan 01 test-only: production export behavior remains unchanged for Plan 02."
  - "Used self-contained test schemas and FakeRepo so configured-schema export assertions compile without database setup."

patterns-established:
  - "Auth export contract tests assert safe exported keys and explicit forbidden secret-bearing keys."
  - "Missing optional schemas are tested as present empty sections plus exact structured omission maps."

requirements-completed: [EXP-01, EXP-02]

duration: 4min
completed: 2026-05-27
---

# Phase 127 Plan 01: Versioned Auth Data Export Proof Surface Summary

**Executable RED tests now pin lifecycle status, omission truth, configured-schema serialization, and credential-secret exclusion for the auth data export contract.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-05-27T06:45:50Z
- **Completed:** 2026-05-27T06:49:23Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added lifecycle-status assertions for scheduled, deleted, and not-scheduled account states.
- Replaced string-only omission coverage with exact structured omission maps for all seven optional schema options.
- Added configured-schema tests with in-test Ecto schemas, FakeRepo, safe-field assertions, and explicit refutations for secret-bearing auth fields.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add contract tests for lifecycle status and omission inventory** - `60277a3` (test)
2. **Task 2: Add configured-schema safe serialization tests** - `55fce1d` (test)

**Plan metadata:** pending final docs commit

## Files Created/Modified

- `test/sigra/data_export_test.exs` - Adds RED contract tests for lifecycle status, structured omissions, configured optional schema serialization, and sensitive-field exclusion.
- `.planning/phases/127-versioned-auth-data-export/127-01-SUMMARY.md` - Records plan execution, verification, and expected pre-implementation failures.

## Decisions Made

- Kept this plan as test-only proof work; no production code was modified.
- Used deterministic in-test Ecto schemas and FakeRepo instead of database fixtures so Plan 02 can implement against a stable proof surface quickly.

## Verification

- `mix test test/sigra/data_export_test.exs --max-failures 1` - expected failure; test file compiles, then fails on missing production contract (`:lifecycle_status`/structured omissions depending on seed).
- `mix test test/sigra/data_export_test.exs:343 --max-failures 1` - expected failure; configured-schema proof compiles, then fails because current production returns raw structs with `:hashed_token` and `:user_id`.
- `mix format --check-formatted test/sigra/data_export_test.exs` - passed.
- `rg -n "lifecycle_status|section: :sessions|schema_option: :backup_code_schema|refute Map.has_key\\?.*:hashed_token|refute Map.has_key\\?.*:encrypted_access_token|refute Map.has_key\\?.*:hashed_code|def aggregate\\(" test/sigra/data_export_test.exs` - passed.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `mix format --check-formatted test/sigra/data_export_test.exs` initially failed after Task 2. The test file was formatted and the Task 2 commit was amended to keep the task commit clean.

## Known Stubs

None. Stub-pattern scan found intentional empty-section assertions for missing optional schemas; these are the expected contract under EXP-02, not placeholder UI/data stubs.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 02 can now implement `Sigra.DataExport.export_auth_data/3` against failing tests for:

- `account.lifecycle_status` derived from `Sigra.Account.Deletion.status/1`
- structured omission maps for all optional schema options
- curated safe serializers for sessions, identities, audit rows, MFA credentials, passkeys, backup-code summary, and memberships
- exclusion of `:hashed_token`, `:encrypted_access_token`, `:encrypted_refresh_token`, `:encrypted_secret`, `:credential_id`, `:public_key`, and `:hashed_code`

## Self-Check: PASSED

- Found `test/sigra/data_export_test.exs`.
- Found `.planning/phases/127-versioned-auth-data-export/127-01-SUMMARY.md`.
- Found task commit `60277a3`.
- Found task commit `55fce1d`.

---
*Phase: 127-versioned-auth-data-export*
*Completed: 2026-05-27*
