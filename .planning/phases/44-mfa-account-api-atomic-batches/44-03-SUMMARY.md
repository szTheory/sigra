---
phase: 44-mfa-account-api-atomic-batches
plan: "03"
subsystem: mfa
tags: [audit, AUD-06, Ecto.Multi, postgres]

requires:
  - phase: 44-02
    provides: "audit_multi_step + emit_telemetry_from_changes/2"
provides:
  - "MFA success and paired failure paths use log_multi_safe + repo.transaction"
  - "metadata_resolver on Audit.build_attrs for dynamic MFA metadata"
  - "Postgres atomicity tests for enroll, verify TOTP, verify_backup"
affects: []

key-files:
  created:
    - "test/sigra/mfa_audit_atomicity_test.exs"
  modified:
    - "lib/sigra/mfa.ex"
    - "lib/sigra/audit.ex"

requirements-completed: [AUD-06]

duration: 90min
completed: 2026-04-20
---

# Phase 44 plan 03 — Summary

Converted **`Sigra.MFA`** inventoried success paths to **`Ecto.Multi` + `Sigra.Audit.log_multi_safe`**, including dual-audit **`verify_backup/4`**, **`confirm_enrollment/5`**, TOTP **`verify/4`** success, failure/lockout bundles (with **`Multi.merge`** for conditional lockout audit), **`regenerate_backup_codes/4`** failure path, and **`cleanup_mfa/6`** for **`disable/4`** / **`disable!/4`**. Added **`metadata_resolver`** in **`Sigra.Audit`** so audit metadata can depend on prior Multi step results.

## Self-Check: PASSED

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs test/sigra/mfa_test.exs test/sigra/audit_multi_step_test.exs`

## Issues encountered

- `confirm_enrollment` audit failure surfaces as **`Ecto.ConstraintError`** from the repo (not `{:error, changeset}`) when DB check constraints fire — atomicity test uses **`assert_raise`**.

## Task commits

Tracked as a single implementation series in git (audit + MFA + tests).
