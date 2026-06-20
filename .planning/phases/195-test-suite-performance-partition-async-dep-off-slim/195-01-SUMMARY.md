---
phase: 195-test-suite-performance-partition-async-dep-off-slim
plan: "01"
subsystem: test-infrastructure
status: complete
tags: [ci, testing, elixir, async, threadline-guard]
completed_date: "2026-06-20"
duration_minutes: 3

dependency_graph:
  requires: []
  provides:
    - ":threadline_guard ExUnit moduletag on 7 guard modules (D-10/D-11/D-13)"
    - "mix sigra.dep_off alias in mix.exs (D-14)"
    - "async: true on auth_plain_map_regression_test and passkeys/rate_limit_test (D-15)"
    - "Async-safety checklist in guides/recipes/testing.md (D-17)"
    - "Dep-off local repro note in guides/recipes/local-development.md (D-14 doc)"
  affects:
    - "Plan 03 (dep-off CI lane rewrite calls the alias)"

tech_stack:
  added: []
  patterns:
    - "@moduletag :threadline_guard — ExUnit tag-based subset selection (mix test --only)"
    - "mix alias as local-repro bundle for CI lane (sigra.dep_off)"
    - "async: false because <reason> comment convention"

key_files:
  created: []
  modified:
    - test/sigra/optional_deps_test.exs
    - test/sigra/application_forwarders_test.exs
    - test/sigra/audit/forwarders/noop_test.exs
    - test/sigra/workers/audit_forward_test.exs
    - test/sigra/doctor_test.exs
    - test/sigra/mix/tasks/doctor_task_test.exs
    - test/sigra/config_forwarders_test.exs
    - mix.exs
    - test/sigra/auth_plain_map_regression_test.exs
    - test/sigra/passkeys/rate_limit_test.exs
    - guides/recipes/testing.md
    - guides/recipes/local-development.md

decisions:
  - "7 guard modules tagged with :threadline_guard; threadline_test.exs keeps :requires_threadline only (D-12); phase_148 excluded (A1 — passes dep_off_opts as injected keyword, not a genuine guard path)"
  - "sigra.dep_off alias runs 4 steps in order: unlock→clean→compile--warnings-as-errors--no-deps-check→test --only threadline_guard --no-deps-check"
  - "Only 2 process-local-verified modules flipped to async: true (D-15); must-stay-serial set (D-16) untouched including application_forwarders_test.exs"
  - "Async-safety checklist covers all D-17 criteria: Application/System env, persistent_term, named ETS, telemetry handlers, set_mox_global, filesystem/cwd, durable DDL, sandbox isolation"
---

# Phase 195 Plan 01: Threadline Guard Tags, dep_off Alias, Async Flips, and Checklist Summary

Threadline guard tag set on 7 modules, `mix sigra.dep_off` alias, 2 safe async flips, and the D-17 async-safety checklist — all TEST-02/TEST-03 foundations for the dep-off CI lane rewrite in Plan 03.

## What Was Built

### Task 1: Tag 7 threadline-absent guard modules with :threadline_guard (TEST-02 / D-10, D-11, D-13)

Added `@moduletag :threadline_guard` directly under the `use ExUnit.Case` line in exactly 7 modules:

| Module | D-13 coverage | async |
|--------|---------------|-------|
| `test/sigra/optional_deps_test.exs` | (b) threadline_available?/0 == false canary | true |
| `test/sigra/application_forwarders_test.exs` | (c) boot degrade path, one Logger.warning | false (D-16) |
| `test/sigra/audit/forwarders/noop_test.exs` | (d) Noop fallback dispatch | true |
| `test/sigra/workers/audit_forward_test.exs` | (d) worker dispatch path | true |
| `test/sigra/doctor_test.exs` | (e) doctor reports threadline: false | true |
| `test/sigra/mix/tasks/doctor_task_test.exs` | (e) doctor task in-process | false (default) |
| `test/sigra/config_forwarders_test.exs` | (supporting) forwarder config cascade | true |

`threadline_test.exs` keeps `:requires_threadline` only (D-12 preserved). `phase_148_*` excluded (A1).

Verified: `mix test --only threadline_guard` runs 65 tests, 0 failures (2372 excluded). Nonzero count confirmed — D-11 fail-red-on-zero property intact.

### Task 2: Add mix sigra.dep_off alias and flip 2 verified-safe async modules (TEST-02/D-14, TEST-03/D-15)

**mix.exs alias added:**
```elixir
"sigra.dep_off": [
  "deps.unlock threadline",
  "deps.clean threadline --build",
  "compile --warnings-as-errors --no-deps-check",
  "test --only threadline_guard --no-deps-check"
],
```

**Async flips:**
- `test/sigra/auth_plain_map_regression_test.exs`: `async: false` → `async: true` (StubRepo is process-local)
- `test/sigra/passkeys/rate_limit_test.exs`: `async: false` → `async: true` (RecordingLimiter is process-local)

Both files passed `MIX_ENV=test mix test ... --max-failures 1`: 7 tests, 0 failures.
`application_forwarders_test.exs` confirmed still `async: false` (Application env mutator, D-16).

### Task 3: Async-safety checklist and dep-off repro note (TEST-03/D-17, TEST-02/D-14 doc)

**guides/recipes/testing.md**: Added "Is this test allowed to be async: true?" section with:
- Full global-state checklist (Application/System env, persistent_term, named ETS, telemetry handlers, set_mox_global, filesystem/cwd/archives, durable DDL via checkout_repo!/unboxed_run)
- Process-local and Mox private-mode as safe paths
- The `# async: false because <reason>` comment convention with example
- Note that partitioning does not change the async-safety rule

**guides/recipes/local-development.md**: Added "Reproducing the CI dep-off lane locally" subsection under "Postgres for mix test" documenting `MIX_ENV=test mix sigra.dep_off` with all 4 steps explained and a note to restore the dep with `mix deps.get` afterward.

## Verification Results

```
mix test --only threadline_guard
→ 65 tests, 0 failures (2372 excluded)  ✓ nonzero count

grep -rl 'threadline_guard' test/ | sort
→ exactly 7 modules (application_forwarders, noop, config_forwarders, doctor,
  doctor_task, optional_deps, audit_forward)  ✓

grep -c requires_threadline test/sigra/audit/forwarders/threadline_test.exs → 1  ✓ D-12 preserved
grep -c threadline_guard test/sigra/audit/forwarders/threadline_test.exs → 0  ✓ D-12
grep -c threadline_guard test/sigra/planning/phase_148_* → 0  ✓ A1 exclusion

grep -q sigra.dep_off mix.exs → alias present, 4 steps in correct order  ✓
grep -Eq 'async: true' test/sigra/auth_plain_map_regression_test.exs → ✓
grep -Eq 'async: true' test/sigra/passkeys/rate_limit_test.exs → ✓
grep -Eq 'async: false' test/sigra/application_forwarders_test.exs → ✓ D-16 untouched

grep -qi 'async-safe' guides/recipes/testing.md → ✓ D-17 checklist present
grep -q 'set_mox_global' guides/recipes/testing.md → ✓
grep -q 'sigra.dep_off' guides/recipes/local-development.md → ✓ dep-off repro documented
```

## Deviations from Plan

None — plan executed exactly as written.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Known Stubs

None.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 1eae478a | chore(195-01): tag 7 threadline-absent guard modules with :threadline_guard |
| 2 | d1220f52 | chore(195-01): add mix sigra.dep_off alias and flip 2 verified-safe async modules |
| 3 | b222b301 | docs(195-01): add async-safety checklist and dep-off local repro note |

## Self-Check: PASSED

- [x] 7 guard modules carry :threadline_guard tag
- [x] mix sigra.dep_off alias in mix.exs with 4 steps in correct order
- [x] Both async flips green (7 tests, 0 failures)
- [x] application_forwarders_test.exs still async: false
- [x] testing.md has async-safety checklist with all D-17 items
- [x] local-development.md has dep-off repro command
- [x] mix test --only threadline_guard: 65 tests, 0 failures (nonzero — D-11 property holds)
- [x] All 3 commits exist and verified
