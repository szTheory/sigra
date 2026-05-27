---
phase: 131
plan: "04"
subsystem: audit-forwarders
tags:
  - threadline
  - oban-worker
  - telemetry
  - optional-dep
  - audit
dependency_graph:
  requires:
    - "131-03: Forwarders dispatcher (Sigra.Audit.Forwarders.dispatch/3, oban_running?/1)"
    - "131-02: Extended telemetry emit ([:sigra, :audit, :log] event with full metadata)"
    - "131-01: Sigra.Audit.Forwarder behaviour + Noop forwarder"
  provides:
    - "Sigra.Audit.Forwarders.Threadline — post-commit Threadline projection forwarder"
    - "Sigra.Workers.AuditForward — optional Oban worker for async audit forward"
  affects:
    - "Sigra.Audit.Forwarders — dispatch_async path now live (calls oban.insert/1)"
tech_stack:
  added:
    - "Threadline forwarder: optional-dep wrap, :telemetry.attach/4, call_threadline/2"
    - "AuditForward: Oban.Worker, queue :sigra_audit_forward, max_attempts 5, backoff/1"
  patterns:
    - "if Code.ensure_loaded?(Threadline) do ... end (D-18 dep-off safety)"
    - "if Code.ensure_loaded?(Oban.Worker) do ... end (D-18 dep-off safety)"
    - "try/rescue/catch :exit/:throw in handle_event/4 (D-20 auto-detach landmine)"
    - "Process.put(:sigra_audit_forward_config, ...) for test injection (D-27)"
    - "Thin job args: forwarder + audit_event_id + occurred_at only (D-13)"
    - "StubOban pattern for async dispatch tests (D-32)"
key_files:
  created:
    - lib/sigra/audit/forwarders/threadline.ex
    - lib/sigra/workers/audit_forward.ex
  modified:
    - test/sigra/audit/forwarders/threadline_test.exs
    - test/sigra/workers/audit_forward_test.exs
    - test/sigra/audit/forwarders/dispatch_test.exs
decisions:
  - "Threadline :sync path calls call_threadline/2 directly — avoids recursive dispatch (dispatch_sync calls handle_event/4 which would re-enter dispatch)"
  - "forwarder telemetry metadata key is atom :threadline NOT module name (D-30)"
  - "correlation_id = audit row UUID for Threadline idempotency (RESEARCH.md §4 path 1)"
  - "backoff/1 byte-for-byte from EmailDelivery formula (D-15)"
  - "cancel taxonomy: :audit_event_not_found, :unknown_forwarder, :schema_mismatch, {:error, _} (D-16)"
  - "StubOban must implement insert/1 returning {:ok, %Oban.Job{}} — bare atoms no longer work once AuditForward compiled"
metrics:
  duration: "~4h (context window resumed)"
  completed: "2026-05-27"
  tasks_completed: 3
  files_created: 2
  files_modified: 3
---

# Phase 131 Plan 04: Threadline Forwarder + AuditForward Worker Summary

One-liner: Optional Threadline telemetry forwarder with auto-detach landmine safety and Oban async worker with thin job args, exponential backoff, and cancel taxonomy.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | RED: failing tests for Threadline + AuditForward | f431ab2 | threadline_test.exs, audit_forward_test.exs |
| 2 | GREEN: implement Sigra.Audit.Forwarders.Threadline | d6ad90e | threadline.ex |
| 3 | GREEN: implement Sigra.Workers.AuditForward | 24726c3 | audit_forward.ex, dispatch_test.exs, audit_forward_test.exs |

## Verification

- `mix test test/sigra/audit/ test/sigra/workers/` — 122 tests, 0 failures
- All Task 3 acceptance criteria greps pass (D-13, D-14, D-15, D-16, D-17, D-18, D-27)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Circular dispatch in Threadline handle_event/4 for :sync path**
- **Found during:** Task 2 implementation review
- **Issue:** Plan said "delegate to Sigra.Audit.Forwarders.dispatch/3 for all paths." The shared dispatcher's `dispatch_sync` calls `forwarder_module.handle_event/4` — so calling the dispatcher from `handle_event/4` for the `:sync` path would cause infinite recursion.
- **Fix:** `:sync` path calls `call_threadline/2` directly (Threadline.record_action inline). Only the `:async` path uses the shared dispatcher — `dispatch_async` enqueues an Oban job and does NOT call `handle_event/4` recursively.
- **Files modified:** lib/sigra/audit/forwarders/threadline.ex
- **Commit:** d6ad90e

**2. [Rule 1 - Bug] dispatch_test.exs Tests 2 and 4 broke after AuditForward compiled**
- **Found during:** Task 3 — once `lib/sigra/workers/audit_forward.ex` was compiled, `dispatch_async` now calls `oban.insert(changeset)` via the configured `:oban` module. Tests 2 and 4 were using bare process-name atoms (`:nonexistent_oban_module_for_testing`, an agent atom) as the `:oban` override — these have no `insert/1` function.
- **Fix:** Added `defmodule StubOban` with `insert/1` that captures the call via `send/2` and returns `{:ok, %Oban.Job{}}`. Test 2 updated to `oban: StubOban`. Test 4 registers an Agent process under the `StubOban` atom name (so `Process.whereis(StubOban) != nil` for the `oban_running?` check) while also using `StubOban.insert/1` for the actual insert.
- **Files modified:** test/sigra/audit/forwarders/dispatch_test.exs
- **Commit:** 24726c3

## Key Design Notes

### Auto-Detach Landmine (D-20)

`Sigra.Audit.Forwarders.Threadline.handle_event/4` wraps its entire body in `try/rescue/catch :exit/:throw`. Every code path — happy path, rescued exception, caught exit, caught throw — returns `:ok` to `:telemetry`. A handler that raises is auto-detached by `:telemetry` for the rest of BEAM uptime (permanent silence). All three tests for this (Test 2: rescue RuntimeError, Test 3: catch :exit, Test 4: catch :throw) confirm the handler survives and telemetry still lists the handler ID post-failure.

### Circular Dispatch Design

The `:async` path in `handle_event/4` calls `Sigra.Audit.Forwarders.dispatch(__MODULE__, metadata, opts)`. This only enqueues an Oban job (`dispatch_async`) — it does NOT call `handle_event/4`. The `:sync` path calls `call_threadline/2` directly. This asymmetry prevents the recursion that would occur if the `:sync` path went through the shared dispatcher (whose `dispatch_sync` calls back into the forwarder).

### Threadline API Mapping

- `Threadline.record_action(name_atom, opts)` — requires atom name (guard `when is_atom(name)`)
- Action string → atom conversion: `String.to_atom(s)` for binary actions
- `Threadline.Semantics.ActorRef.new(type_atom, binary_id)` — returns `{:ok, ref}`
- `correlation_id: metadata[:id]` — audit UUID as Threadline idempotency key

### AuditForward Worker Config Injection

Tests inject config via `Process.put(:sigra_audit_forward_config, %{repo: StubRepo, audit_schema: StubAuditSchema})`. The worker checks this key first in `resolve_config/0`, falling back to the Application env cascade (D-27) only when the process dict key is absent.

## Known Stubs

None — all data paths are wired. Threadline calls use MockThreadline in tests and real Threadline in production. Worker reloads audit row from DB at perform time.

## Threat Flags

None — no new network endpoints or trust boundaries introduced. Threadline calls go through the existing `Threadline.record_action/2` integration point already in the threat model. Oban job args carry only thin references (no PII payload in the job queue — T-3-INFRA-01 compliant).

## Self-Check: PASSED

- `lib/sigra/audit/forwarders/threadline.ex` — FOUND
- `lib/sigra/workers/audit_forward.ex` — FOUND
- commit f431ab2 — FOUND (RED tests)
- commit d6ad90e — FOUND (Threadline GREEN)
- commit 24726c3 — FOUND (AuditForward GREEN)
- 122 tests passing, 0 failures
