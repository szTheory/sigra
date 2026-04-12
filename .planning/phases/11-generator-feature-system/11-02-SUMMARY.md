---
phase: 11
plan: 02
subsystem: generator-primitives
tags: [generator, behaviour, primitives, feature-system]
wave: 1
depends_on: [11-01]
requires: [wave-0-golden-diff-harness]
provides:
  - Sigra.Install.Feature behaviour (5 callbacks)
  - "%Sigra.Install.Injection{} struct"
  - Sigra.Install.Injector.apply/2 adapter
  - Sigra.Install.Report accumulator
  - Sigra.Install.MigrationTimestamps.allocate/2
affects:
  - lib/sigra/install/injector.ex (additive only)
tech_stack:
  added: []
  patterns:
    - behaviour-based feature manifest
    - struct with @enforce_keys for installer descriptors
    - record-as-you-go accumulator for multi-column summary
    - slot-based deterministic timestamp allocation
key_files:
  created:
    - lib/sigra/install/feature.ex
    - lib/sigra/install/injection.ex
    - lib/sigra/install/report.ex
    - lib/sigra/install/migration_timestamps.ex
    - test/sigra/install/feature_test.exs
    - test/sigra/install/injection_test.exs
    - test/sigra/install/report_test.exs
    - test/sigra/install/migration_timestamps_test.exs
  modified:
    - lib/sigra/install/injector.ex (added apply/2 adapter + private helpers; legacy inject_* functions untouched)
decisions:
  - "Kept draft field names (target/marker/anchor/content) from CONTEXT.md D-02 verbatim — CD-03 allowed renaming, but reusing draft names avoids a second rename in Wave 3/4."
  - "Report struct was created in Task 1 commit (not Task 2 as planned) because Feature.post_instructions/2 typespec references Sigra.Install.Report.t() — module must exist at compile time. Report record_* public API and tests still landed in Task 2 as planned."
  - "render_summary/1 pads columns to max(header_width, longest_entry) and guards max_rows == 0 so empty reports still render valid headers and long paths don't break alignment (plan-checker info-level fix applied)."
  - "Injector.apply/2 is a thin additive wrapper — the legacy inject_router_plugs/2 / inject_config/2 functions remain unchanged and continue to serve the monolith until Wave 4."
metrics:
  duration_minutes: ~15
  tasks_completed: 2
  files_created: 8
  files_modified: 1
  tests_added: 18
  completed_date: 2026-04-11
---

# Phase 11 Plan 02: Generator Primitives Summary

Behaviour, struct, accumulator, and slot allocator primitives for the `mix sigra.install` feature system — pure additions, zero touches to the monolith, golden-diff regression barrier intact.

## What Shipped

### Public API Surface (1-line per function)

**`Sigra.Install.Feature`** (behaviour, 5 callbacks):
- `enabled?(opts :: keyword()) :: boolean()` — gate on generator opts
- `files(binding :: keyword()) :: [{:eex, source, target}]` — non-migration templates
- `injections(binding :: keyword()) :: [Sigra.Install.Injection.t()]` — structured injections
- `migrations(binding :: keyword()) :: [{slot, template, basename}]` — migration slots in order
- `post_instructions(binding, report :: Report.t()) :: [iodata()]` — post-install lines

**`%Sigra.Install.Injection{}`** (struct, `@enforce_keys [:target, :marker, :anchor, :content]`):
- `target :: Path.t()` — project-relative file to mutate
- `marker :: String.t()` — idempotency marker comment
- `anchor :: :before_last_end | :after_use_block | :at_top | atom()` — insertion point
- `content :: String.t()` — rendered code block

**`Sigra.Install.Injector`** (additive, existing module):
- `apply(%Injection{}, opts \\ []) :: {:ok, :injected | :already_present} | {:error, term()}` — marker-checked idempotent injection, routes by anchor

**`Sigra.Install.Report`** (accumulator struct):
- `new() :: t()` — empty 4-column accumulator
- `record_generated(t(), Path.t()) :: t()` — append to generated column
- `record_modified(t(), Path.t()) :: t()` — append to modified column
- `record_skipped(t(), Path.t(), reason :: String.t()) :: t()` — append to skipped column with reason
- `record_manual_action(t(), instruction :: String.t()) :: t()` — append to manual-action column
- `render_summary(t()) :: iodata()` — stable 4-column table, header-padded, sorted

**`Sigra.Install.MigrationTimestamps`**:
- `allocate(features :: [module()], base_time :: DateTime.t()) :: %{module() => %{atom() => String.t()}}` — deterministic slot-keyed 14-digit timestamp map, strictly monotonic across features

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created Report.ex in Task 1 instead of Task 2**
- **Found during:** Task 1 compilation check
- **Issue:** `Sigra.Install.Feature.post_instructions/2` callback typespec references `Sigra.Install.Report.t()`. The `feature_test.exs` also instantiates `%Sigra.Install.Report{}` directly. Without the Report module defined at Task 1 compile time, `--warnings-as-errors` would fail.
- **Fix:** Created `lib/sigra/install/report.ex` as part of Task 1 with the full struct + record_* API. Kept the Report unit test file (`test/sigra/install/report_test.exs`) in Task 2 as planned.
- **Files modified:** `lib/sigra/install/report.ex` (Task 1 commit)
- **Commit:** `1d73a9d`

Otherwise, plan executed exactly as written.

### Auth Gates

None.

## Field Naming (CD-03)

Kept draft names `target/marker/anchor/content` verbatim — no rename. Rationale: avoiding a second rename in Wave 3/4 when `Features.Core.injections/1` and the walker start consuming the struct.

## tmp/ Gitignore

Already covered. `.gitignore` line 26 is `/tmp/` (project-root tmp directory). Test at `tmp/injection_test` uses that directory — matches the existing ignore rule. No gitignore edits needed.

## Verification Results

| Check | Result |
|-------|--------|
| `mix test test/sigra/install/feature_test.exs` | 2 tests, 0 failures |
| `mix test test/sigra/install/injection_test.exs` | 4 tests, 0 failures |
| `mix test test/sigra/install/report_test.exs` | 7 tests, 0 failures |
| `mix test test/sigra/install/migration_timestamps_test.exs` | 5 tests, 0 failures |
| `mix test test/sigra/install/golden_diff_test.exs` | 2 tests, 0 failures (regression barrier intact) |
| `mix test test/sigra/install/` (full install suite) | 280 tests, 0 failures |
| `mix compile --warnings-as-errors` | clean |
| `mix format --check-formatted` (plan files only) | clean |
| `git diff e0c313a -- lib/mix/tasks/sigra.install.ex` | empty (monolith untouched) |
| `grep -c "^  @callback" lib/sigra/install/feature.ex` | 5 |

## Commits

- `1d73a9d` — feat(11-02): add Feature behaviour + Injection struct + Injector.apply/2
- `6198406` — feat(11-02): add Report tests + MigrationTimestamps slot allocator

## Known Stubs

None. All modules have full implementations with runtime verification behind unit tests. Features.Core consumption arrives in Wave 3 per plan.

## Self-Check: PASSED

All artifact files verified present on disk:
- lib/sigra/install/feature.ex — FOUND
- lib/sigra/install/injection.ex — FOUND
- lib/sigra/install/report.ex — FOUND
- lib/sigra/install/migration_timestamps.ex — FOUND
- lib/sigra/install/injector.ex — FOUND (with apply/2 additive wrapper)
- test/sigra/install/feature_test.exs — FOUND
- test/sigra/install/injection_test.exs — FOUND
- test/sigra/install/report_test.exs — FOUND
- test/sigra/install/migration_timestamps_test.exs — FOUND

Commits verified in git log:
- 1d73a9d — FOUND
- 6198406 — FOUND
