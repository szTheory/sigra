---
phase: "214"
plan: "01"
subsystem: optional-deps-oban-guard
tags: [oban, robustness, debt, guard, refactor]
status: complete
completed_date: "2026-07-03"
duration: "149s"
tasks_completed: 2
files_modified: 5
requirements: [DEBT-01]
dependency_graph:
  requires: []
  provides: [oban-running-sot]
  affects: [lib/sigra/optional_deps.ex, lib/sigra/account/deletion.ex, lib/sigra/delivery.ex, lib/sigra/audit/forwarders.ex, test/sigra/account/deletion_test.exs]
tech_stack:
  added: []
  patterns: [process-supervision-guard, optional-deps-sot]
key_files:
  created: []
  modified:
    - lib/sigra/optional_deps.ex
    - lib/sigra/account/deletion.ex
    - lib/sigra/delivery.ex
    - lib/sigra/audit/forwarders.ex
    - test/sigra/account/deletion_test.exs
decisions:
  - "Process.register(dummy, Oban) pattern (from delivery_test.exs) used to simulate Oban supervision in the enqueue test"
  - "Existing enqueues-worker test updated to register dummy Oban process — required because oban_running?() now correctly rejects unsupervised hosts"
  - "CaptureLog used to assert no crash-warning emitted when guard fires (proves guard fires before insert attempt)"
---

# Phase 214 Plan 01: Oban Supervision Guard SOT Summary

**One-liner:** Centralized `oban_running?/0` in `Sigra.OptionalDeps` as the single source of truth for the compiled-AND-supervised Oban check; fixed the buggy `oban_available?()` call in `deletion.ex` and de-duped private copies from `delivery.ex` and `forwarders.ex`.

## Objective

Close DEBT-01 (D-01 through D-04): a compiled-but-unsupervised host calling `schedule_deletion/3`
previously attempted a `repo.insert` on the `oban_jobs` table that does not exist, producing a
`42P01` crash caught by the rescue block and logged as a warning. The fix closes that wasted-insert
loop by checking supervision state before the insert attempt.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Add oban_running?/0 SOT and fix 3 call sites | e1040b7a | optional_deps.ex, deletion.ex, delivery.ex, forwarders.ex |
| 2 | Regression test: compiled-but-unsupervised guard | 10f7aec6 | deletion_test.exs |

## What Was Built

### Task 1 — `Sigra.OptionalDeps.oban_running?/0`

New public function added after `oban_available?/0` in `lib/sigra/optional_deps.ex`:

```elixir
@doc since: "1.1.0"
@spec oban_running?() :: boolean()
def oban_running?, do: oban_available?() and Process.whereis(Oban) != nil
```

Three call-site updates:

1. **`deletion.ex` line 308:** `oban_available?()` → `oban_running?()` (D-01 bug fix)
2. **`delivery.ex` line 105:** `oban_running?()` → `Sigra.OptionalDeps.oban_running?()`; private `defp oban_running?/0` deleted (D-02 de-dupe)
3. **`forwarders.ex` `:error` branch:** delegates to `Sigra.OptionalDeps.oban_running?()` instead of re-implementing (D-02 de-dupe); opts-override test-injection path unchanged

### Task 2 — Regression Test

New test case added to `deletion_test.exs`:

- **"does not attempt to enqueue when Oban is compiled but not supervised"** — asserts `oban_available?()` is `true` and `Process.whereis(Oban)` is `nil` (natural in ExUnit), calls `schedule_deletion`, asserts `{:ok, updated_user, scheduled_at}` returned, asserts no Oban-crash warning logged (proving guard fires before insert).

Also fixed the existing **"enqueues account deletion worker"** test which broke because it previously relied on the weaker `oban_available?()` check. Fixed by registering a dummy process as `Oban` via `Process.register(dummy, Oban)` (same pattern as `delivery_test.exs`).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed existing enqueues-worker test broken by oban_running?() change**
- **Found during:** Task 2 — running `mix test deletion_test.exs`
- **Issue:** The existing "enqueues account deletion worker when generated-host job context is present" test failed because `oban_running?()` now requires Oban to be supervised, but the test ran in the unsupervised ExUnit environment where `Process.whereis(Oban) == nil`. The Mox `expect(:insert, ...)` was never called.
- **Fix:** Added `Process.register(dummy, Oban)` at the start of the test (with `on_exit` cleanup) to simulate Oban supervision — identical pattern to `delivery_test.exs` line 150.
- **Files modified:** `test/sigra/account/deletion_test.exs`
- **Commit:** 10f7aec6

## Verification Results

- `mix compile --warnings-as-errors`: passes clean
- `mix test test/sigra/account/deletion_test.exs --seed 0`: 21 tests, 0 failures
- `grep -n "oban_available?" lib/sigra/account/deletion.ex`: 0 matches in `maybe_enqueue_deletion_job/4`
- `grep -n "defp oban_running?" lib/sigra/delivery.ex`: 0 matches (private copy deleted)
- `grep -n "oban_running?" lib/sigra/optional_deps.ex`: shows the new public function at lines 92-93

## Todo Closed

- `.planning/todos/pending/2026-06-24-oban-enqueue-unguarded-when-compiled-but-unsupervised.md` → moved to `.planning/todos/resolved/`

## Known Stubs

None.

## Threat Flags

None — this is a hardening change only; no new trust boundaries or attack surface introduced.

## Self-Check: PASSED

- [x] `lib/sigra/optional_deps.ex` modified — exists and contains `oban_running?/0`
- [x] `lib/sigra/account/deletion.ex` modified — `oban_running?()` at line 308
- [x] `lib/sigra/delivery.ex` modified — no private `oban_running?/0`
- [x] `lib/sigra/audit/forwarders.ex` modified — `:error` branch delegates to SOT
- [x] `test/sigra/account/deletion_test.exs` modified — new regression test + existing test fixed
- [x] Commit e1040b7a exists (Task 1)
- [x] Commit 10f7aec6 exists (Task 2)
- [x] All 21 deletion tests pass
