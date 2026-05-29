---
phase: "138"
plan: "01"
subsystem: "diagnostic"
tags: ["doctor", "optional-deps", "injection-seam", "tdd"]
dependency_graph:
  requires:
    - "lib/sigra/optional_deps.ex"
    - "lib/sigra/audit/forwarders.ex"
  provides:
    - "Sigra.Doctor.diagnose/1"
    - "Sigra.Doctor.run/1"
  affects:
    - "lib/mix/tasks/sigra.doctor.ex (Plan 02 — thin Mix task shell)"
tech_stack:
  added: []
  patterns:
    - "Injection seam (D-04): predicates/host_sigra/oban_running keyword overrides"
    - "Nine-feature matrix with four DR-01 states per row"
    - "D-09 hard-fail boundary: configured-but-broken only, never dep-absent-unconfigured"
    - "TDD: RED commit (e356245) then GREEN commit (4c69dcf)"
key_files:
  created:
    - "lib/sigra/doctor.ex"
    - "test/sigra/doctor_test.exs"
  modified: []
decisions:
  - "oauth_token_storage_enabled? is distinct from oauth_providers_configured? — having OAuth providers does NOT trigger encryption hard-fail; only explicit :store_tokens or passkeys enabled does"
  - "Code.ensure_loaded? called directly for dynamic forwarder module atoms (D-06 narrow exception, per spec)"
  - "encryption_configured? checks passkeys_enabled? OR oauth_token_storage_enabled? (not providers)"
metrics:
  duration: "~20 minutes"
  completed: "2026-05-29"
  tasks_completed: 1
  files_created: 2
  files_modified: 0
---

# Phase 138 Plan 01: Sigra.Doctor Pure Diagnostic Module Summary

**One-liner:** Pure injectable Sigra.Doctor module with nine-feature DR-01 matrix, D-09 hard-fail wiring checks, and injection seam for unit testing without ambient dep toggling.

## What Was Built

`Sigra.Doctor` — a pure library module (no IO, no Mix.Task dependency, no side effects) that:

1. Builds a nine-feature optional-dependency matrix (all D-05 features: totp_mfa, password_migration, oauth, rate_limiting, jwt, async_email, audit_forwarding, encryption, enterprise_connections)
2. Assigns one of four DR-01 states to each row: `:missing`, `:available`, `:loaded_active`, `:configured_but_missing`
3. Validates boot-time wiring via four D-09 hard-fail conditions (async forwarder without Oban, async email without Oban, encryption stub with encryption-requiring feature enabled, forwarder module not loaded)
4. Returns structured result `%{rows: [...], wiring: [...], verdict: :ok | :fail}`

The injection seam (`predicates:`, `host_sigra:`, `oban_running:` keyword overrides) makes all 13 behavior tests work without toggling the ambient dep tree or spawning subprocesses.

## Commits

| Hash | Type | Description |
|------|------|-------------|
| e356245 | test | Add failing tests for Sigra.Doctor (RED phase) |
| 4c69dcf | feat | Implement Sigra.Doctor with injection seam and nine-feature matrix (GREEN phase) |

## Acceptance Criteria Verification

- [x] `lib/sigra/doctor.ex` exists and compiles without warnings (`mix compile --warnings-as-errors`)
- [x] `Sigra.Doctor` exports `diagnose/1` and `run/1`
- [x] At most 1 `Code.ensure_loaded?` call (line 489 — dynamic forwarder module check per D-06 exception)
- [x] No `verify_vault!` or `attach_forwarders` function calls (only mentioned in @moduledoc as what NOT to do)
- [x] No `IO.puts`, `IO.inspect`, `System.halt` calls
- [x] All 15 unit tests pass (`mix test test/sigra/doctor_test.exs`)
- [x] No `CaptureIO`, `Mix.Task.run`, or `System.cmd` in test file
- [x] Test 9 (dep-off CI-gate-green): all-false predicates + empty host_sigra → verdict `:ok`
- [x] Tests 5+6+7+8: each D-09 hard-fail condition → verdict `:fail`
- [x] `:rows` has exactly 9 entries covering all D-05 features

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Encryption hard-fail triggered by OAuth providers in Tests 3 and 4**
- **Found during:** GREEN phase — tests 3 and 4 returned `:fail` instead of `:ok`
- **Issue:** `encryption_configured?` was checking `oauth_token_storage_configured?` via "non-empty providers list" — but having OAuth providers does NOT require encryption. OAuth token storage is a separate, explicit opt-in.
- **Fix:** Renamed `oauth_token_storage_configured?` to `oauth_token_storage_enabled?` and changed it to check `oauth: [store_tokens: true]` (explicit flag), not providers list. Passkeys + explicit store_tokens are the only triggers.
- **Files modified:** `lib/sigra/doctor.ex`
- **Commit:** 4c69dcf (folded into GREEN commit)

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes. `Sigra.Doctor` reads config and availability predicates — it is a read-only diagnostic. The hint strings contain no secret values, only dep names and config key names (per T-138-01 mitigate disposition — satisfied).

## TDD Gate Compliance

- RED gate: commit e356245 (`test(138-01): add failing tests...`) — 15 tests failing with UndefinedFunctionError
- GREEN gate: commit 4c69dcf (`feat(138-01): implement Sigra.Doctor...`) — 15 tests passing

Both gate commits exist in correct order.

## Self-Check: PASSED

Files exist:
- `lib/sigra/doctor.ex` — FOUND
- `test/sigra/doctor_test.exs` — FOUND

Commits exist:
- e356245 — FOUND (test/RED phase)
- 4c69dcf — FOUND (feat/GREEN phase)
