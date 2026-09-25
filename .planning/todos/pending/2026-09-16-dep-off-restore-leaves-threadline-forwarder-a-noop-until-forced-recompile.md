---
created: 2026-09-16T00:00:00.000Z
status: pending
title: sigra-dep-off.sh's restore step leaves Sigra.Audit.Forwarders.Threadline compiled as a no-op until the next forced recompile
area: testing
severity: major
source: phase 237 plan 06 Task 3 (MIX_ENV=test mix ci gate run, reproduced 5 times)
files:
  - scripts/ci/sigra-dep-off.sh
  - lib/sigra/audit/forwarders/threadline.ex
---

## Problem

`lib/sigra/audit/forwarders/threadline.ex` (D-18/TL-04, "Dep-Off Safety") guards its entire
`defmodule` with `if Code.ensure_compiled(Threadline) == {:module, Threadline} do … end` — a
COMPILE-TIME conditional. When the `:threadline` dependency is absent, the file compiles to a
no-op and `Sigra.Audit.Forwarders.Threadline` simply does not exist.

`scripts/ci/sigra-dep-off.sh` deliberately exercises this: it unlocks and cleans the
`threadline` dependency, recompiles, runs the `@moduletag :threadline_guard` tests against the
degraded state, then calls a `restore()` function to put the dependency state back:

```bash
restore() {
  …
  MIX_ENV=test mix deps.get --check-locked
  …
  MIX_ENV=test mix compile threadline
  …
}
```

**`mix compile threadline` only recompiles the `threadline` app itself.** It does NOT
recompile `sigra`'s own files, including `lib/sigra/audit/forwarders/threadline.ex`. Since
that file's source bytes never changed across the whole dep-off cycle, Mix's incremental
compiler has no signal to know it needs recompiling — the compile-time truth of
`Code.ensure_compiled(Threadline)` changed, but Mix's dependency tracker only watches source
file changes, not runtime/compile-time conditional outcomes.

**Consequence:** after ANY `sigra.dep_off` run (i.e., after any `mix ci` run, since it's the
alias's last step), `Sigra.Audit.Forwarders.Threadline` stays compiled as a no-op in
`_build/test/` — even though `threadline` itself is fully restored and
`Code.ensure_compiled(Threadline)` now correctly returns `{:module, Threadline}` when checked
directly. The NEXT `mix ci` invocation's `test --exclude scaffold` step then fails 6 tests in
`Sigra.Audit.Forwarders.ThreadlineTest` with `** (UndefinedFunctionError) function
Sigra.Audit.Forwarders.Threadline.attach/1 is undefined` — a false-negative local gate result
with no connection to any code change.

## Reproduced 5 times, deterministically

Across this plan's Task 3 gate-verification runs:

| Run | `_build/test` state | Result |
|---|---|---|
| 1 | fresh session state | 0 failures |
| 2 (immediately after run 1) | post-dep-off from run 1 | **6 threadline failures** |
| 3 (after `MIX_ENV=test mix compile --force`) | force-recompiled | 3 unrelated load-timeout failures (0 threadline) |
| 4 (immediately after run 3) | post-dep-off from run 3 | **6 threadline failures again** |
| 5 (after `rm -rf _build/test` + fresh compile) | fresh | 1 load-timeout failure (0 threadline) |
| 6 (immediately after run 5) | post-dep-off from run 5 | **7 failures, 6 of them threadline again** |
| 7 (after another fresh `rm -rf _build/test` + recompile) | fresh | **0 failures, exit 0** — the authoritative clean result this ledger records |

The pattern is 100% consistent: threadline failures appear if and only if a prior `mix ci`
(specifically its `sigra.dep_off` step) ran against the same `_build/test` directory without
an intervening forced recompile of `sigra` itself.

## Why this doesn't show up in CI

Every GitHub Actions job starts with a fresh `_build`/`deps` (or a cache keyed to `mix.lock`,
which the dep-off cycle's temporary unlock/restore does not durably change). CI has therefore
never observed this failure mode — it only manifests on a local machine where `_build`
persists across multiple `mix ci` invocations, which is exactly how CLAUDE.md instructs
contributors to use it ("run `MIX_ENV=test mix ci` before pushing" — implying repeated local
runs against the same checkout).

## Solution

`restore()` in `scripts/ci/sigra-dep-off.sh` should recompile `sigra` itself (not just
`threadline`), e.g. `MIX_ENV=test mix compile --force` (or at minimum
`MIX_ENV=test mix compile sigra`, if that scopes correctly) after `mix compile threadline`,
so the conditional-compile files in `lib/` that depend on `threadline`'s availability are
re-evaluated with the dependency restored. This should be proven with a fixture: run `mix ci`
twice in a row against the same `_build` and assert the second run is also green.

This is out of scope for phase 237 — its task list does not touch
`scripts/ci/sigra-dep-off.sh` or the dep-off mechanism, and the v1.48 standing constraint is
explicit: found-while-cleaning becomes a todo, never an in-phase fix. Recommend routing to
whoever next touches the CI/local-gate machinery (candidates: Phase 241's TEST-01/TEST-02
retirement, which already re-examines this alias's topology, or a dedicated local-DX fix).
