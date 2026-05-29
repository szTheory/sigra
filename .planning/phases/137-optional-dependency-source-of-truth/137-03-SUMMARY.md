---
phase: 137-optional-dependency-source-of-truth
plan: "03"
subsystem: optional-deps
tags: [refactor, optional-deps, oban, req, compound-guard, SOT]
dependency_graph:
  requires: ["137-01"]
  provides: ["OD-02-compound-subset"]
  affects:
    - lib/sigra/delivery.ex
    - lib/sigra/audit/forwarders.ex
    - lib/sigra/enterprise_connections/validation.ex
    - lib/sigra/account/deletion.ex
tech_stack:
  added: []
  patterns:
    - compound-guard split (D-06): delegate load half to Sigra.OptionalDeps, keep liveness/arity half literal
key_files:
  modified:
    - lib/sigra/delivery.ex
    - lib/sigra/audit/forwarders.ex
    - lib/sigra/enterprise_connections/validation.ex
    - lib/sigra/account/deletion.ex
decisions:
  - "Forwarders.ex {:ok, oban_override} branch left byte-unchanged (Pitfall 2 fence)"
  - "deletion.ex:308 Code.ensure_loaded?(Sigra.Workers.AccountDeletion) left literal (Bucket C, Pitfall 3)"
  - "forwarders.ex mirror comment updated from 'byte-for-byte' to delegated form to stay honest"
metrics:
  duration: ~5 minutes
  completed: "2026-05-29"
  tasks_completed: 2
  files_changed: 4
---

# Phase 137 Plan 03: Compound Guard Load-Half Delegation Summary

Delegated the LOAD HALF of compound runtime optional-dep guards to `Sigra.OptionalDeps` (OD-02, D-06) in four files, keeping liveness/arity halves literal at each call site.

## What Was Built

Mechanical refactor delegating `Code.ensure_loaded?(NamedMod)` tokens to `Sigra.OptionalDeps.<dep>_available?()` in four files, with deliberate surgical precision:

- `delivery.ex oban_running?/0`: `Code.ensure_loaded?(Oban) and Process.whereis(Oban) != nil` → `Sigra.OptionalDeps.oban_available?() and Process.whereis(Oban) != nil`. Liveness half and 3-line explanatory comment preserved.
- `audit/forwarders.ex oban_running?/1 :error branch`: same delegation. The `{:ok, oban_override}` test-override branch (line 94, no `Code.ensure_loaded?`) left byte-unchanged. Mirror comment updated to reference delegated form.
- `enterprise_connections/validation.ex default_http_get/1`: `Code.ensure_loaded?(Req) and function_exported?(Req, :get, 1)` → `Sigra.OptionalDeps.req_available?() and function_exported?(Req, :get, 1)`. Arity half preserved.
- `account/deletion.ex maybe_enqueue_deletion_job/4 line 307`: `with true <- Code.ensure_loaded?(Oban),` → `with true <- Sigra.OptionalDeps.oban_available?(),`. Line 308 `Code.ensure_loaded?(Sigra.Workers.AccountDeletion)` left literal (Bucket C internal worker).

## Tasks Completed

| Task | Commit | Files |
|------|--------|-------|
| Task 1: Delegate Oban load-half in delivery.ex and forwarders.ex | 7467d75 | lib/sigra/delivery.ex, lib/sigra/audit/forwarders.ex |
| Task 2: Delegate Req load-half (validation.ex) and Oban with-leg (deletion.ex:307) | 523b631 | lib/sigra/enterprise_connections/validation.ex, lib/sigra/account/deletion.ex |

## Verification Results

- `git grep "Code.ensure_loaded?(Oban)"` in delivery.ex, forwarders.ex, deletion.ex: NOTHING (all delegated)
- `git grep "Code.ensure_loaded?(Req)"` in validation.ex: NOTHING (delegated)
- `git grep "Code.ensure_loaded?(Sigra.Workers.AccountDeletion)"` in deletion.ex: line 308 still literal (correctly fenced)
- `mix compile --warnings-as-errors`: exits 0
- `mix test test/sigra/application_forwarders_test.exs`: 9 tests, 0 failures
- `mix test test/sigra/account/deletion_test.exs test/sigra/enterprise_connections/validation_test.exs`: 22 tests, 0 failures

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Threat Flags

None. Pure delegation refactor. No new network endpoints, auth paths, or schema changes.

## Self-Check: PASSED

- lib/sigra/delivery.ex: FOUND (modified, contains delegated form)
- lib/sigra/audit/forwarders.ex: FOUND (modified, :error branch delegated, override branch unchanged)
- lib/sigra/enterprise_connections/validation.ex: FOUND (modified, arity half preserved)
- lib/sigra/account/deletion.ex: FOUND (modified, line 307 delegated, line 308 literal)
- Task 1 commit 7467d75: verified
- Task 2 commit 523b631: verified
