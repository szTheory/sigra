---
phase: 131
plan: "03"
subsystem: audit
tags: [audit, forwarders, dispatch, config, oban, threadline, tdd]
dependency_graph:
  requires: [131-01, 131-02]
  provides: [131-04, 131-05, 131-06]
  affects: [lib/sigra/audit/forwarders.ex, lib/sigra/config.ex, mix.exs]
tech_stack:
  added: [threadline 0.5.0]
  patterns: [NimbleOptions custom validator, Oban optional dispatch, oban_running? cross-module public fn]
key_files:
  created:
    - lib/sigra/audit/forwarders.ex
    - test/sigra/audit/forwarders/dispatch_test.exs
    - test/sigra/config_forwarders_test.exs
  modified:
    - lib/sigra/config.ex
    - mix.exs
    - mix.lock
decisions:
  - "D-07: per-forwarder :dispatch knob (NOT top-level :delivery_mode) — mirrors email per-entry delivery_mode precedent"
  - "D-08: arbitrary impl-specific keys pass through top-level schema unvalidated (RESEARCH §3 option 1 — custom validator)"
  - "D-12: oban_running?/1 mirrors delivery.ex:113-115 byte-for-byte but uses Keyword.fetch to distinguish :oban test override from production path"
  - "D-32: :oban override key allows tests to simulate Oban supervised/not without a live Oban process"
  - "D-33: handle_event/4 is NOT a behaviour callback — it's a convention called by dispatch_sync"
  - "postgrex :only :test restriction removed — threadline optional dep requires postgrex at runtime"
metrics:
  duration: "~2h (split across two context windows)"
  completed: "2026-05-27"
  tasks_completed: 3
  tasks_total: 3
  files_created: 3
  files_modified: 3
---

# Phase 131 Plan 03: Forwarders Dispatcher + Config Schema Summary

Froze the `audit: [forwarders: [...]]` config shape, shipped `Sigra.Audit.Forwarders.dispatch/3` with `:auto`/`:async`/`:sync` routing, and extended `mix.exs` with optional Threadline dep and `no_warn_undefined` coverage.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 0 | Threadline legitimacy gate | (verified in prior wave context) | — |
| 1 (RED) | Dispatch + config forwarders tests | acb2d1a | test/sigra/audit/forwarders/dispatch_test.exs, test/sigra/config_forwarders_test.exs |
| 2 (GREEN) | Forwarders dispatcher + Config schema | aac361a | lib/sigra/audit/forwarders.ex, lib/sigra/config.ex |
| 3 | mix.exs Threadline + no_warn_undefined | bbaef09 | mix.exs, mix.lock, test/sigra/audit/forwarders/dispatch_test.exs |

## Implementation Notes

### Sigra.Audit.Forwarders (dispatch/3 router)

- `dispatch/3` routes to `:sync` or `:async` via `dispatch_mode/1` which reads `opts[:dispatch]` (NOT `:delivery_mode` — D-07)
- `oban_running?/1` is PUBLIC (`def`, not `defp`) — Plan 05 calls this cross-module for boot-time validation (BLOCKER 2)
- Production path mirrors `delivery.ex:113-115` byte-for-byte: `Code.ensure_loaded?(Oban) and Process.whereis(Oban) != nil`
- Test override path (D-32): when `opts[:oban]` key is present, skips `Code.ensure_loaded?` (override is a named process, not a module)
- `dispatch_async/3` uses `apply(@worker_module, :new, [job_args])` with `@worker_module Sigra.Workers.AuditForward` to avoid compile-time undefined-module warning

### Config forwarders schema (NimbleOptions custom validator)

- `{:list, {:keyword_list, keys}}` was tested and REJECTED — it rejects arbitrary impl-specific keys (`:endpoint`, `:api_key`)
- Adopted `{:custom, Sigra.Config, :validate_forwarders, []}` which validates canonical keys (`:module`, `:dispatch`, `:id`) but passes arbitrary keys through (D-08 / RESEARCH §3 option 1)
- `validate_forwarders/1` is `def` with `@doc false` — NimbleOptions requires it to be public for cross-module custom validator calls

### mix.exs changes

- Added `Threadline`, `Threadline.ActorRef`, `Threadline.AuditChange`, `Threadline.AuditTransaction` to `no_warn_undefined` optional-deps section
- Added `Sigra.Workers.AuditForward` to `no_warn_undefined` internal-modules section
- Added `{:threadline, "~> 0.5", optional: true}` — threadline 0.5.0 fetched from Hex
- Removed `:only :test` restriction from postgrex (threadline requires postgrex at runtime, not just :test)

## Test Coverage

- 11 new tests (6 in dispatch_test.exs, 5 in config_forwarders_test.exs)
- 54 tests in `test/sigra/audit/` pass across multiple random seeds (0, 100, 200, 300, 400, 500, 813366)
- 2208 tests in full `test/sigra/` pass with seed 0

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] NimbleOptions `{:list, {:keyword_list, keys}}` rejects unknown keys**
- **Found during:** Task 2 (GREEN implementation)
- **Issue:** The RESEARCH.md §3 option 2 NimbleOptions schema type `{:list, {:keyword_list, keys}}` rejects arbitrary impl-specific keys like `:endpoint` and `:api_key`, breaking Test 5 (D-08 pass-through requirement)
- **Fix:** Switched to `{:custom, Sigra.Config, :validate_forwarders, []}` — a custom validator function that validates canonical keys but passes through arbitrary keys. This is RESEARCH.md §3 option 1.
- **Files modified:** lib/sigra/config.ex
- **Commit:** aac361a

**2. [Rule 1 - Bug] postgrex `:only :test` conflict with threadline optional dep**
- **Found during:** Task 3 (`mix deps.get` failure)
- **Issue:** `{:postgrex, "~> 0.17", only: :test}` conflicted with `threadline/mix.exs` which requires postgrex without an `:only` restriction (threadline uses postgrex at runtime, not just test)
- **Fix:** Removed `:only :test` restriction from postgrex. Updated comment to explain that threadline (optional) also requires it at runtime.
- **Files modified:** mix.exs
- **Commit:** bbaef09

**3. [Rule 1 - Bug] function_exported?/3 returns false for not-yet-loaded modules (seed-dependent test flakiness)**
- **Found during:** Task 3 verification
- **Issue:** Test 5 in dispatch_test.exs (`function_exported?(Forwarders, :oban_running?, 1)`) returned false when the test ran before other tests had triggered module loading (Erlang documented behavior: `function_exported?` returns false for modules not yet in the running system)
- **Fix:** Added `Code.ensure_loaded!(Forwarders)` before the `function_exported?` assertion
- **Files modified:** test/sigra/audit/forwarders/dispatch_test.exs
- **Commit:** bbaef09

## Known Stubs

None. All tests exercise real implementation code. The `dispatch_async` path gracefully no-ops when `Sigra.Workers.AuditForward` is not compiled (Plan 05 makes it live) — this is intentional and documented behavior, not a stub.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes at trust boundaries introduced. `Sigra.Audit.Forwarders` is a library-internal dispatcher with no public HTTP surface.

## Self-Check: PASSED

- `lib/sigra/audit/forwarders.ex` — FOUND
- `test/sigra/audit/forwarders/dispatch_test.exs` — FOUND
- `test/sigra/config_forwarders_test.exs` — FOUND
- Commit acb2d1a — FOUND (test RED)
- Commit aac361a — FOUND (implementation GREEN)
- Commit bbaef09 — FOUND (mix.exs Task 3)
