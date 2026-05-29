---
created: 2026-05-29T00:00:00.000Z
title: Phase 138 Sigra.Doctor minor (Info) code-review findings
area: lib/sigra
resolves_phase: 140
files:
  - lib/sigra/doctor.ex
  - test/sigra/mix/tasks/doctor_task_test.exs
---

## Problem

Phase 138 code review (138-REVIEW.md) raised 1 Critical + 6 Warning + 3 Info findings.
The Critical and all 6 Warnings were fixed in commit `6c936a9` (predicate alignment to
canonical `Sigra.Config`/`Sigra.Application` semantics + raw-input defense + injection
seam for the forwarder-not-loaded branch). The 3 Info findings were deliberately deferred
(decision: fix-verified-now, defer-minor) — they are maintainability/doc/test-hygiene
items with no correctness impact.

## Deferred findings (from 138-REVIEW.md)

- **IN-01** — `run/1` docstring (lib/sigra/doctor.ex ~125-134) claims `:quiet` "omits hints
  from the returned rows," but `run/1` delegates to `diagnose/1` which never reads `:quiet`;
  hint suppression happens only in the Mix task's `print_row/2`. Fix: remove the `:quiet`
  paragraph from `run/1`'s doc (or move row-stripping into the library if returned-row
  stripping is genuinely intended).

- **IN-02** — `bcrypt_configured?/1` (lib/sigra/doctor.ex ~412-414) is hardcoded `false`, so
  `:password_migration` can only be `:missing` or `:available`, never `:loaded_active`. The
  `hint_active`/`hint_broken` strings for that feature (~232-235) are therefore dead. This is
  intentional per the inline comment, but a reader can't tell the unreachable states are
  deliberate. Fix: drop the unreachable hints for this feature, or add a note in
  `feature_definitions` that `:password_migration` is intentionally a two-state feature.

- **IN-03** — Mix task test 8 (test/sigra/mix/tasks/doctor_task_test.exs:160) does
  `File.read!("lib/mix/tasks/sigra.doctor.ex")` with a CWD-relative path and greps the source
  for "no System.halt" — brittle (matches comments/docstrings; couples test to CWD). Fix:
  assert the behavior (exit is catchable, process not halted — Test 6 already does this) and
  drop the grep test, or anchor to `__ENV__.file`-relative resolution.

## Why deferred

These are low-priority maintainability items. Phase 140 (Deprecation Hygiene + Verification
& Docs Close) is the natural home — it already touches docstrings/migration notes and runs
the full proof bundle, so the doc and dead-hint cleanups fold in cleanly. None block the
v1.30 trust-hardening goal.
