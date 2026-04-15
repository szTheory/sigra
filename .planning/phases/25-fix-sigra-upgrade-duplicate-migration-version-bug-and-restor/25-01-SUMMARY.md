---
phase: 25-fix-sigra-upgrade-duplicate-migration-version-bug-and-restor
plan: 01
subsystem: sigra-upgrade
tags: [bugfix, migrations, tdd, phase-25]
requires:
  - lib/sigra/upgrade.ex (existing emit_migrations/1 pipeline)
provides:
  - Sigra.Upgrade.next_migration_timestamp/2 (scan-and-bump timestamp generator)
affects:
  - lib/sigra/upgrade.ex
  - test/sigra/upgrade_test.exs
tech_stack:
  added: []
  patterns:
    - "Scan-and-bump migration timestamp generator (precedent: Sigra.Install.MigrationTimestamps)"
    - "Per-run counter threading via Enum.with_index on migration list"
key_files:
  created: []
  modified:
    - lib/sigra/upgrade.ex
    - test/sigra/upgrade_test.exs
decisions:
  - "Chose Shape A (Enum.with_index on migration list) over Shape B (explicit accumulator) — fits the existing emit_migrations/1 pipeline naturally"
  - "extract_migration_version/1 remains defp; only next_migration_timestamp/2 is @doc false + def for test access"
metrics:
  duration: ~6min
  completed: 2026-04-15
  tasks: 2
  commits: 2
---

# Phase 25 Plan 01: Fix sigra.upgrade Duplicate Migration Version Bug Summary

**One-liner:** Replaced naive `Calendar.strftime(DateTime.utc_now(), ...)` migration timestamp generator in `Sigra.Upgrade` with a scan-and-bump helper that threads a per-run counter, eliminating the install+upgrade same-second collision that would otherwise fail Phase 25-02's integration un-skip with `Ecto.MigrationError: migration version NNNN is duplicated`.

## What Shipped

### `Sigra.Upgrade.next_migration_timestamp/2`

Signature (final, as chosen):

```elixir
@doc false
@spec next_migration_timestamp(Path.t(), non_neg_integer()) :: String.t()
def next_migration_timestamp(migrations_dir, counter)
    when is_binary(migrations_dir) and is_integer(counter) and counter >= 0
```

Semantics:

1. Computes `now_stamp = %Y%m%d%H%M%S` (14-digit integer) from `DateTime.utc_now/0`.
2. If `migrations_dir` exists, `File.ls!/1` → `extract_migration_version/1` (private helper matching `^(\d{14})_`) → max of existing 14-digit prefixes (0 if empty/no matches).
3. Returns `max(now_stamp, highest_existing + 1) + counter`, zero-padded to 14 chars.
4. Gracefully handles missing directory (`File.exists?/1` guard → `highest_existing = 0`).

### Call-site replacement (Shape A — Enum.with_index)

`emit_migrations/1` now threads a counter through `write_migration/3`:

```elixir
defp emit_migrations(migrations) do
  migrations
  |> Enum.with_index()
  |> Enum.each(fn {{template, output_name}, counter} ->
    write_migration(template, output_name, counter)
  end)
end

defp write_migration(template, output_name, counter) do
  # ...
  migrations_dir = Path.join(["priv", "repo", "migrations"])
  timestamp = next_migration_timestamp(migrations_dir, counter)
  # ...
end
```

This makes the ALTER pair (and optional `--backfill-personal-orgs` data-migration shim) strictly monotonic regardless of wall-clock resolution: counters 0, 1, 2 guarantee three distinct, ordered 14-digit prefixes even in the same second.

### Regression test

`test/sigra/upgrade_test.exs` now has a `describe "next_migration_timestamp/2"` block containing `"produces monotonically increasing prefixes when called twice in the same second"`:

- Seeds tmp dir with `20260415102050_fake.exs` (known-high timestamp)
- Calls helper twice with counters 0 and 1
- Asserts: both are 14-char digit strings, both exceed seeded `20260415102050`, and t2 > t1 (strictly increasing)
- `on_exit` teardown removes tmp dir

Comment includes the literal `"monotonically increasing"` string required by plan acceptance.

## Final Test Output

### Targeted (Task 2 GREEN gate)

```
Running ExUnit with seed: 994637, max_cases: 16
...............
Finished in 0.1 seconds (0.00s async, 0.1s sync)
15 tests, 0 failures
```

### Full unit suite excluding `@moduletag :upgrade`

```
Finished in 84.3 seconds (3.4s async, 80.8s sync)
33 doctests, 3 properties, 1811 tests, 0 failures (3 excluded)
```

No regressions in any other subsystem.

## Deviations from Plan

None — plan executed exactly as written. Shape A was selected for the call-site replacement (as the plan authorized), implemented via `Enum.with_index` on the existing `emit_migrations/1` pipeline.

## Edge Cases Discovered

1. **Missing migrations directory:** `File.exists?/1` guard handles the case where `priv/repo/migrations/` doesn't exist (fresh install scenario). Returns `now_stamp + counter` with `highest_existing = 0`.
2. **Empty migrations directory:** `File.ls!/1` returns `[]`, the `case` clause lands on `[] -> 0`, so the fallback behaves identically to missing-dir.
3. **Non-migration files in directory:** `extract_migration_version/1` uses `^(\d{14})_` so files like `.formatter.exs` or READMEs are filtered via `Enum.reject(&is_nil/1)`.
4. **Counter thread-through across multi-migration emits:** With `--backfill-personal-orgs`, the 3-element migration list produces 3 strictly monotonic timestamps (0, 1, 2 offsets past the scan-and-bump base). Verified by plan design; test covers the 2-call subset.

## Commits

- `5ac717c` test(25-01): add failing regression test for next_migration_timestamp/2 monotonicity (RED)
- `313e6b3` fix(25-01): scan-and-bump migration timestamps to prevent install/upgrade collisions (GREEN)

## Acceptance Verification

- [x] `lib/sigra/upgrade.ex` contains `next_migration_timestamp(` (3 hits: spec + def + call site)
- [x] `lib/sigra/upgrade.ex` contains ZERO `Calendar.strftime(DateTime.utc_now` hits (verified via Grep)
- [x] `test/sigra/upgrade_test.exs` contains `"monotonically increasing"`
- [x] `test/sigra/upgrade_test.exs` contains `next_migration_timestamp`
- [x] `mix test test/sigra/upgrade_test.exs` → 15 tests, 0 failures
- [x] `mix test --exclude upgrade` → 1811 tests, 0 failures
- [x] Two commits landed with prefixes `test(25-01):` and `fix(25-01):`

## Self-Check: PASSED

- FOUND: lib/sigra/upgrade.ex (modified, helper present)
- FOUND: test/sigra/upgrade_test.exs (modified, regression test present)
- FOUND: commit 5ac717c (RED)
- FOUND: commit 313e6b3 (GREEN)
- FOUND: zero `Calendar.strftime(DateTime.utc_now` hits in lib/sigra/upgrade.ex
