---
phase: 73-bounded-audit-atomicity-batch
plan: 02
subsystem: testing
tags: [postgres, mfa, audit, AUD-11]

requires: []
provides:
  - CHECK constraint fault-injection proving verify/4 and regenerate_backup_codes/4 Multi rollback with blocked audit inserts
affects: [test]

tech-stack:
  added: []
  patterns:
    - "Prefer assert_raise Ecto.ConstraintError when audit insert hits Postgres CHECK (log_multi_safe uses Repo.insert)"

key-files:
  created: []
  modified:
    - test/sigra/mfa_audit_atomicity_test.exs

key-decisions:
  - "Tests assert Ecto.ConstraintError (audit insert) rather than RuntimeError; rollback invariants match plan intent"

patterns-established: []

requirements-completed: [AUD-11]

duration: 25min
completed: 2026-04-24
---

# Phase 73 plan 02 — Summary

Added five **Postgres `CHECK`** fault-injection tests on **`audit_events`** proving **`Sigra.MFA.verify/4`** (success, wrong TOTP, lockout-at-threshold-1) and **`regenerate_backup_codes/4`** (success + wrong TOTP) roll back credential/backup state when the paired audit row is rejected.

## Task commits

1. **Tasks 1–4 (single commit)** — `b5500a7`

## Deviations

- **PLAN** specified **`RuntimeError`** with regex for **`verify/4`** / **`regenerate_backup_codes/4`**; **`log_multi_safe`** audit steps use **`Ecto.Repo.insert`**, so **`Ecto.ConstraintError`** is what Postgres CHECK surfaces first. Assertions use **`assert_raise Ecto.ConstraintError`**; rollback and absence of durable audit rows match **AUD-11** intent.

## Self-Check: PASSED

- `SIGRA_TEST_PG_USERNAME=jon SIGRA_TEST_PG_PASSWORD= MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs` — 14 tests, 0 failures.
- `MIX_ENV=test mix compile --warnings-as-errors` — exit 0.
