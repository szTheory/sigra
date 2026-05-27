---
phase: 131
plan: 02
subsystem: audit
tags: [telemetry, audit, idempotency, threadline-enabler, additive-extension, tdd]
requires:
  - "lib/sigra/audit.ex emit_telemetry/1 (existing private fn at line 304)"
  - "lib/sigra/audit/changeset.ex :occurred_at validate_required (existing)"
  - "priv/templates/sigra.install/core/audit_event.ex @primary_key :binary_id autogenerate (existing)"
provides:
  - "[:sigra, :audit, :log] metadata key :id (binary UUID string)"
  - "[:sigra, :audit, :log] metadata key :occurred_at (%DateTime{})"
  - "Canonical idempotency-key pair {id, occurred_at} ready for Plan 04 Threadline forwarder"
affects:
  - "lib/sigra/audit.ex (emit_telemetry/1 metadata map + moduledoc bullet)"
  - "test/sigra/audit_telemetry_test.exs (new — D-31 contract test)"
tech-stack:
  added: []
  patterns:
    - "Additive metadata extension on existing :telemetry.execute/3 emission"
    - "TDD RED-then-GREEN gate (test file in commit 82ccdfa, impl in 168b3a4)"
    - ":telemetry.attach/4 with anonymous-fn + on_exit detach (test harness)"
key-files:
  created:
    - test/sigra/audit_telemetry_test.exs
  modified:
    - lib/sigra/audit.ex
decisions:
  - "Production code reads event.id / event.occurred_at raw (no defensive nil guard) — schema + changeset guarantee both fields per D-31"
  - "Test StubRepo emulates Ecto.Repo autogenerate hook (Ecto.UUID.generate/0) because Ecto.Changeset.apply_changes/1 alone does NOT trigger @primary_key autogenerate"
  - "Moduledoc extension condensed into single bullet (line 13) — plan said 'find existing section listing metadata keys'; no such section existed, so the existing one-line summary was extended in place instead of inventing a new section"
metrics:
  duration_seconds: 870
  completed: 2026-05-27
  tasks_completed: 2
  files_touched: 2
---

# Phase 131 Plan 02: emit_telemetry/1 metadata superset (TL-05 enabler) Summary

Strict-additive extension of `Sigra.Audit.emit_telemetry/1` so the
`[:sigra, :audit, :log]` event carries `:id` (audit row UUID, binary string)
and `:occurred_at` (DateTime) alongside the pre-existing `:action`, `:actor_id`,
`:outcome`. Plan 04 Threadline forwarder reads both directly off metadata to
ship the canonical idempotency-key pair via `:correlation_id` (Pitfall 4
unblocked — no extra DB query inside the telemetry handler).

## What was done

- **Task 1 (RED, commit `82ccdfa`):** Wrote `test/sigra/audit_telemetry_test.exs`
  with two contract tests against `[:sigra, :audit, :log]` metadata:
  - Test 1: strict-superset assertion — all 5 keys `(:action, :actor_id, :outcome, :id, :occurred_at)` present; `is_binary(metadata.id)`; `match?(%DateTime{}, metadata.occurred_at)`.
  - Test 2: backwards-compat — pre-existing keys retain identical values (additive only — proves the change cannot mutate any existing subscriber's expected payload).
  - Pre-impl run was RED with "metadata missing required key :id (D-31). Got: [:action, :actor_id, :outcome]" — exactly the expected failure mode.

- **Task 2 (GREEN, commit `168b3a4`):** Extended `lib/sigra/audit.ex` `emit_telemetry/1` (line 304-323 after edit) metadata map from 3 keys to 5; updated moduledoc bullet at line 13 to document the extended shape and tag the v0.4.0 / Pitfall 4 rationale.

## emit_telemetry/1 before/after

### Before (lib/sigra/audit.ex:304-310)

```elixir
defp emit_telemetry(event) do
  :telemetry.execute(
    @telemetry_event,
    %{count: 1},
    %{action: event.action, actor_id: event.actor_id, outcome: event.outcome}
  )
end
```

### After (lib/sigra/audit.ex:304-323)

```elixir
defp emit_telemetry(event) do
  # Metadata superset per D-31 (Phase 131 Plan 02):
  # - :action, :actor_id, :outcome — original (Plan 09 / D-24); preserved verbatim
  # - :id, :occurred_at — added in v0.4.0 for cross-system idempotency (Pitfall 4)
  #   so Threadline forwarder (Plan 04) can ship the canonical dedupe key via
  #   :correlation_id without an extra DB round-trip inside the handler.
  # Both new fields are schema-guaranteed: event.id from
  # @primary_key {:id, :binary_id, autogenerate: true}; event.occurred_at from
  # validate_required([:action, :outcome, :occurred_at]) (Audit.Changeset).
  :telemetry.execute(
    @telemetry_event,
    %{count: 1},
    %{
      action: event.action,
      actor_id: event.actor_id,
      outcome: event.outcome,
      id: event.id,
      occurred_at: event.occurred_at
    }
  )
end
```

## Test run output

### `test/sigra/audit_telemetry_test.exs` (the new contract — Task 1 + 2 gate)

```
Running ExUnit with seed: 613774, max_cases: 36
..
Finished in 0.05 seconds (0.00s async, 0.05s sync)
2 tests, 0 failures
```

### `test/sigra/audit/` (existing suite — backwards-compat regression check)

```
Running ExUnit with seed: ...
.........................................
Finished in 0.5 seconds (0.06s async, 0.4s sync)
42 tests, 0 failures
```

### `test/sigra/audit_observability_test.exs + audit_test.exs` (sibling subscribers)

```
Running ExUnit with seed: 284597, max_cases: 36
...........
Finished in 0.05 seconds (0.05s async, 0.00s sync)
11 tests, 0 failures
```

### Full `mix test` (proves the additive change touches zero subscriber)

```
33 doctests, 3 properties, 2213 tests, 0 failures
```

## Source acceptance criteria — all green

| Assertion                                                          | Required | Actual |
| ------------------------------------------------------------------ | -------- | ------ |
| `grep -c 'id: event\.id' lib/sigra/audit.ex`                       | ≥ 1      | 1      |
| `grep -c 'occurred_at: event\.occurred_at' lib/sigra/audit.ex`     | ≥ 1      | 1      |
| `grep -c 'action: event\.action' lib/sigra/audit.ex` (preserved)   | ≥ 1      | 1      |
| `grep -c 'actor_id: event\.actor_id' lib/sigra/audit.ex` (preserved)| ≥ 1     | 1      |
| `grep -c 'outcome: event\.outcome' lib/sigra/audit.ex` (preserved) | ≥ 1      | 1      |
| `test/sigra/audit_telemetry_test.exs` exists                       | exists   | YES    |
| `grep -c ':telemetry\.attach' test/sigra/audit_telemetry_test.exs` | ≥ 1      | 1      |
| `grep -cE 'metadata\.id\|metadata\[:id\]'`                         | ≥ 1      | 2      |
| `grep -cE 'metadata\.occurred_at\|metadata\[:occurred_at\]'`       | ≥ 1      | 2      |
| `mix compile --warnings-as-errors` exits 0                         | yes      | yes    |

## Existing tests modified? No.

Zero existing tests required modification. The additive metadata extension is
a strict superset, and every Sigra subscriber (notably
`Sigra.Telemetry.attach_default_logger` at `lib/sigra/telemetry.ex:341-348`)
pattern-matches on a subset — RESEARCH.md §2.1's backwards-compat audit is
proven by the full-suite green (2213 tests, 0 failures).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] test/sigra/audit_telemetry_test.exs StubRepo missing :id autogenerate emulation**

- **Found during:** Task 2 first GREEN run.
- **Issue:** The plan said "event.id from `@primary_key {:id, :binary_id, autogenerate: true}` — do NOT introduce defensive `event.id || raise`; schema guarantees presence." That guarantee holds in production (real `Ecto.Repo.insert/1` runs the autogenerate hook), but the StubRepo I had written in Task 1 used `Ecto.Changeset.apply_changes/1` alone, which does NOT trigger autogenerate. Result: `metadata.id == nil` and the test failed with "metadata.id must be a UUID string, got: nil" — not because the production code was wrong, but because the StubRepo was an incomplete Ecto.Repo emulation.
- **Fix:** Extended StubRepo with a `defp ensure_autogenerated_id/1` that calls `Ecto.UUID.generate/0` when the struct's `:id` is nil. This makes the StubRepo observe the production invariant the test was designed to assert. Production code remained untouched (no defensive guard added, per plan).
- **Files modified:** test/sigra/audit_telemetry_test.exs (StubRepo only).
- **Commit:** 168b3a4 (folded into Task 2 GREEN commit — paired change with the production edit).

### Architectural / decision deviations: none.

Plan was followed exactly:
- Single private-fn edit at `lib/sigra/audit.ex:304-323`.
- Metadata map went from 3 keys to exactly 5 (per D-31 — no extras).
- `%{count: 1}` measurements unchanged.
- `@telemetry_event` unchanged.
- Moduledoc bullet at line 13 extended in place rather than introducing a new top-level section (the plan said "find existing section listing metadata keys"; the only mention was the single bullet on line 13, which was the right place to extend).

## Threat Model Compliance

- **T-131-04 (Info disclosure via telemetry):** Metadata is exactly the 5 fields specified in the plan — no email, no IP, no metadata blob. Grep-asserted in acceptance criteria.
- **T-131-05 (Backwards-compat tampering):** Three pre-existing keys preserved verbatim. Grep-asserted; full-suite green confirms zero subscriber regression.
- **T-131-06 (DoS via field presence):** Schema guarantees `event.id` (autogenerated UUID) and `event.occurred_at` (validate_required). No nil-guard needed in production.
- **T-131-SC:** No new package-manager installs. `mix deps.get` only restored existing locked deps for the worktree.

## Self-Check: PASSED

- [x] test/sigra/audit_telemetry_test.exs exists
- [x] lib/sigra/audit.ex modification present (5-key metadata map)
- [x] Commit 82ccdfa exists (RED)
- [x] Commit 168b3a4 exists (GREEN)
- [x] No deletions in either commit
- [x] All acceptance grep-asserts pass
- [x] mix compile --warnings-as-errors exits 0
- [x] mix test test/sigra/audit_telemetry_test.exs exits 0 (2 tests passing)
- [x] mix test test/sigra/audit/ exits 0 (42 existing tests still green)
- [x] Full mix test exits 0 (2213 tests, 0 failures)

## Commits

| Task | Hash    | Type | Message                                                                   |
| ---- | ------- | ---- | ------------------------------------------------------------------------- |
| 1    | 82ccdfa | test | add failing [:sigra, :audit, :log] metadata contract test                 |
| 2    | 168b3a4 | feat | extend emit_telemetry/1 metadata with :id + :occurred_at (D-31)           |
