---
phase: 77-mfa-adhoc-audit-multi
plan: 01
subsystem: mfa-audit
tags: [postgres, mfa, audit, AUD-13, SEED-002]

requires: []
provides:
  - Transactional MFA ad-hoc audit via commit_ad_hoc_mfa_audit/5 (Multi + log_multi_safe)
  - mfa_audit_atomicity_test.exs coverage for backup_codes_regenerate and trust_browser paths
affects: [library, test, planning]

tech-stack:
  added: []
  patterns:
    - "Ad-hoc MFA audit helpers share commit_ad_hoc_mfa_audit/5 with log_safe-class telemetry on audit failure"

key-files:
  created: []
  modified:
    - lib/sigra/mfa.ex
    - test/sigra/mfa_audit_atomicity_test.exs
    - .planning/phases/09-audit-logging/09-VERIFICATION.md
    - .planning/phases/09-audit-logging/09-03-SUMMARY.md
    - .planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md
    - CHANGELOG.md

key-decisions:
  - "Close AUD-04-033/034 with Multi + log_multi_safe; leave AUD-04-022 on log_safe per EX-44-02"

patterns-established: []

requirements-completed: [AUD-13-01, AUD-13-02, AUD-13-03, AUD-13-04]

duration: n/a
completed: 2026-04-24
---

# Phase 77 plan 01 — Summary

Closed **AUD-04-033** / **AUD-04-034** by routing **`audit_backup_codes_regenerate/3`** and **`audit_trust_browser/2`** through **`commit_ad_hoc_mfa_audit/5`** (**`Repo.transaction/1`** on **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`**), preserving **`log_safe/3`-class** swallowing and **`[:sigra, :audit, :log_safe_error]`** telemetry on invalid audit changesets. Extended **`mfa_audit_atomicity_test.exs`** with success, audit-disabled no-op, and CHECK-guard rollback cases. Refreshed **09-VERIFICATION**, **09-03-SUMMARY**, **44-AUD-04-INVENTORY**, and **CHANGELOG** **[Unreleased]** for **T1** alignment on **033**/**034**.

**One-liner:** MFA ad-hoc audit helpers for backup-code regen and trust-browser now commit atomically with machine-tested rollback parity.
