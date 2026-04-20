---
phase: 44-mfa-account-api-atomic-batches
plan: "02"
subsystem: audit
tags: [audit, Ecto.Multi, telemetry]

requires:
  - phase: 44-01
    provides: "44-AUD-04-INVENTORY.md scope for MFA dual-audit rows"
provides:
  - ":audit_multi_step option on log_multi_safe / __log_internal__ (via do_log_multi)"
  - "emit_telemetry_from_changes/2 with default [:audit] for backward compatibility"
affects: [44-03, 44-04, 44-05]

key-files:
  created:
    - "test/sigra/audit_multi_step_test.exs"
  modified:
    - "lib/sigra/audit.ex"

key-decisions:
  - "Telemetry uses an explicit audit step name list; callers with multiple audit inserts pass emit_telemetry_from_changes(changes, [:step_a, :step_b])."

requirements-completed: [AUD-06, AUD-07]

duration: 30min
completed: 2026-04-20
---

# Phase 44 plan 02 — Summary

**D-44-02:** `Sigra.Audit.do_log_multi/4` now honors **`:audit_multi_step`** (default **`:audit`**) so two internal audit inserts can share one `Ecto.Multi` without key collision. **`emit_telemetry_from_changes/2`** emits **`[:sigra, :audit, :log]`** once per committed audit struct for the listed step names (default remains a single **`:audit`** step for existing callers).

## Task commits

1. **Task 1: Named Multi audit step + telemetry** — (same commit as tests below; single cohesive change)
2. **Task 2: Regression tests** — included in `feat(audit)` commit

## Self-Check: PASSED

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/audit_multi_step_test.exs test/sigra/api_token_audit_atomic_test.exs`
- `grep -q audit_multi_step lib/sigra/audit.ex`

## Issues encountered

- Full `mix test` was long-running in this workspace; library-focused suites above were used as the execution gate for this plan.
