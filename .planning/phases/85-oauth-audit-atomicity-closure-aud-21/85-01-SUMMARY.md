---
phase: 85
plan: 01
subsystem: impersonation-session-audit
tags: [audit, atomicity, impersonation, postgres, test]
dependency_graph:
  requires: []
  provides: [impersonation-co-fate, fallback-compatibility]
  affects: [phase-9-verification, phase-45-inventory]
tech_stack:
  added: [Ecto.Multi, Postgres CHECK fault injection, ExUnit async:false]
  patterns: [capability-dispatched optional callbacks, stable error atom]
key_files:
  created: [test/sigra/impersonation_audit_atomicity_test.exs]
  modified: [lib/sigra/session_store.ex, lib/sigra/session_stores/ecto.ex, lib/sigra/impersonation.ex]
decisions: ["Use optional SessionStore multi callbacks only on adapters that support them", "Return :impersonation_aborted on transactional audit failure"]
metrics:
  duration: session
  completed: 2026-04-25
---

# Phase 85 Plan 01: Impersonation Atomicity Summary

## What shipped

- Added an async:false Postgres integration test for impersonation start/stop co-fate.
- Added optional `create_session_multi/3` and `delete_session_multi/3` callbacks to `Sigra.SessionStore`.
- Implemented the default Ecto session-store multi path and impersonation capability dispatch.

## Verification

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/impersonation_audit_atomicity_test.exs`
- `rg -n "async: false|impersonation_aborted|CHECK|legacy|create_session|delete_session" test/sigra/impersonation_audit_atomicity_test.exs`
- `rg -n "create_session_multi|delete_session_multi|optional_callbacks|impersonation_aborted" lib/sigra/session_store.ex lib/sigra/session_stores/ecto.ex lib/sigra/impersonation.ex`

## Deviations from plan

- The fallback test uses a tiny local store module instead of `Mox` so it can truly lack the optional multi callbacks.
- Audit CHECK failures surfaced as `Ecto.ConstraintError`, so the transactional path rescues that exception and normalizes it to `{:error, :impersonation_aborted}`.
- The test schema stores `hashed_token` as `:binary` / `bytea` to match the session hash shape.

## Commits

- `4869c5b` — test scaffold and fallback coverage
- `af8af36` — transactional impersonation co-fate implementation

## Self-Check: PASSED

- Summary file exists.
- Commit hashes `4869c5b` and `af8af36` are present in `git log`.
