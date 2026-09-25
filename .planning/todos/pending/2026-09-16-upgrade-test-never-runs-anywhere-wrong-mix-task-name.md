---
created: 2026-09-16T00:00:00.000Z
status: pending
title: Sigra.UpgradeIntegrationTest never runs anywhere — test_helper.exs calls the non-existent mix task "archive.list"
area: testing
severity: critical
source: phase 237 plan 06 Task 3 (MIX_ENV=test mix ci gate run)
files:
  - test/test_helper.exs
  - test/upgrade_test.exs
---

## Problem

`test/test_helper.exs` gates the `:upgrade` ExUnit tag exclusion on whether the pinned
`phx_new` archive is installed (D-19/D-20, Phase 214), via:

```elixir
phx_new_ok? =
  case System.cmd("mix", ["archive.list"], stderr_to_stdout: true) do
    {output, 0} -> String.contains?(output, "phx_new-1.8.8")
    _ -> false
  end

unless phx_new_ok? do
  ExUnit.configure(exclude: [:upgrade])
end
```

**`mix archive.list` is not a real Mix task.** The correct task name is `mix archive`
(`mix help | grep archive` → `mix archive  # Lists installed archives`). Confirmed directly:

```bash
$ elixir -e 'IO.inspect(System.cmd("mix", ["archive.list"], stderr_to_stdout: true))'
{"** (Mix) The task \"archive.list\" could not be found. Did you mean \"archive.install\"?\n", 1}
```

The command **always** returns a non-zero exit code, in every environment, regardless of
whether `phx_new-1.8.8` is actually installed. `phx_new_ok?` therefore evaluates to `false`
unconditionally, and `ExUnit.configure(exclude: [:upgrade])` runs on **every** invocation of
the test suite — locally and in CI alike. `test/upgrade_test.exs`
(`Sigra.UpgradeIntegrationTest`, tagged `@moduletag :upgrade`) has **never executed a single
test case**, since this code was introduced.

## Confirmed against CI, not just local

`.github/workflows/ci.yml`'s `library_tests_shard` job installs the pinned archive
(`mix archive.install --force hex phx_new 1.8.8`) and then runs `MIX_ENV=test mix ci` as one
shell command (`ci.yml:548`) — the identical invocation shape used locally. Since the bug is
in the `System.cmd` call itself (wrong task name, not an environment difference), CI hits the
exact same always-false branch. This is not a local-only gap.

## How this was found

Discovered while running Task 3 of phase 237 plan 06 (`MIX_ENV=test mix ci` at final HEAD, as
the sanctioned local gate). `mix ci` exited 0 as expected; this is not a test failure — it is
a silent exclusion that has made an entire test file structurally unreachable. Verified with a
same-block positive control: `mix archive` (correct task name) succeeds and lists
`phx_new-1.8.8` once installed; `mix archive.list` fails identically whether or not the
archive is present.

## Why this matters

`test/upgrade_test.exs` is the semantic-equivalence upgrade regression test (Phase 18 D-06) —
it exercises both `mix sigra.upgrade` paths (backfill-off and backfill-on) end to end via a
real `mix phx.new` scaffold. `STATE.md`'s decision log records these tests as historically
running with known accepted failures ("2403 tests, 2 Sigra.UpgradeIntegrationTest env-DB
failures in D-05 accepted set"), which is inconsistent with the current always-excluded state
— this task-name typo silently regressed coverage at some point after that decision was
recorded, and no gate caught it, because the excluding branch reports nothing (ExUnit simply
has fewer tests to run; there is no error).

## Solution

Fix the task name: `System.cmd("mix", ["archive"], ...)` (or `System.cmd("mix", ["archive",
"list"]` is not a thing either — `mix archive` with no subcommand is correct) instead of
`"archive.list"`. Once corrected, `phx_new_ok?` will correctly evaluate `true` when the pinned
archive is installed, restoring the originally-intended conditional exclusion, and
`test/upgrade_test.exs` will run again — which may surface the previously-accepted env-DB
failures or new ones; whoever fixes this should expect and triage that follow-on.

This is out of scope for phase 237, whose task list does not touch `test/test_helper.exs` or
`test/upgrade_test.exs`, and the v1.48 standing constraint is explicit: found-while-cleaning
becomes a todo, never an in-phase fix. Recommend routing to whichever phase or task next
touches the test-suite gate machinery — this is closely related to, but distinct from, the
already-tracked TEST-01/TEST-02 debt
(`.planning/todos/pending/2026-09-15-test-01-02-timing-machinery-orphaned.md`, resolved by
Phase 241): that todo is about the orphaned timing-formatter/sharding machinery, this one is
about an entire test file never executing due to a literal wrong-task-name bug. Phase 241 (or
whoever re-examines the `mix ci` single-owner topology) should read both together.
