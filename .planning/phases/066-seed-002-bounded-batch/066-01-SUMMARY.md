---
phase: 066-seed-002-bounded-batch
plan: 01
subsystem: auth
tags: [mfa, audit, ecto-multi, postgres, telemetry]

requires: []
provides:
  - insert_failed mfa.enroll.failure via follow-up Multi + log_multi_safe
  - Postgrex-aware handling for credential/backup persistence failures
  - mfa_audit_atomicity_test coverage for durable failure row and rollback guard
affects: [phase-067, AUD-10]

tech-stack:
  added: []
  patterns:
    - "Enrollment audit: success in primary Multi; insert_failed in dedicated txn"

key-files:
  created: []
  modified:
    - lib/sigra/mfa.ex
    - test/sigra/mfa_audit_atomicity_test.exs

key-decisions:
  - "Re-raise enrollment failures on audit_events constraints via Ecto.ConstraintError for audit step only"
  - "Duck-type Postgrex-style exceptions without hard dependency on Postgrex in prod compile"

patterns-established:
  - "emit_enroll_insert_failed_audit/3 centralizes failure Multi + telemetry + log_safe_error parity"

requirements-completed: [AUD-09]

duration: —
completed: 2026-04-23
---

# Phase 66 plan 01 — AUD-09 confirm_enrollment insert_failed

**`mfa.enroll.failure` for `insert_failed` is now written through a follow-up `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3`, with telemetry aligned to other Multi audit paths and without breaking the existing `mfa.enroll.success` guard test.**

## Performance

- **Tasks:** 2 (production + tests)
- **Commits:** `07646a3` (feat), `2c5c0c7` (test)

## Accomplishments

- Replaced post-rollback `log_safe` with transactional `log_multi_safe` + `emit_telemetry_from_changes/2` on success.
- Handled PostgreSQL raising on `insert_all` CHECK violations while preserving `Ecto.ConstraintError` for blocked success-audit inserts.
- Added integration tests mirroring existing CHECK-guard patterns in `mfa_audit_atomicity_test.exs`.

## Self-Check: PASSED

- `MIX_ENV=test mix compile --warnings-as-errors`
- `SIGRA_TEST_PG_USERNAME=jon SIGRA_TEST_PG_PASSWORD= SIGRA_TEST_PG_DATABASE=postgres MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs`
