---
phase: 131
plan: "06"
subsystem: ci-dep-off-lane
tags:
  - ci
  - github-actions
  - threadline
  - dep-off
  - optional-dep
  - tl-04
dependency_graph:
  requires:
    - "131-03: mix.exs optional: true + no_warn_undefined for Threadline atoms"
    - "131-04: Code.ensure_loaded?(Threadline) wrap in Sigra.Audit.Forwarders.Threadline"
    - "131-05: maybe_warn_missing_forwarder_deps/0 + attach_forwarders/0 boot wiring"
  provides:
    - "Phase 136: PROOF-01 dep-off lane has been green for the duration of v1.29"
  affects:
    - .github/workflows/ci.yml
    - test/sigra/audit/forwarders/threadline_test.exs
tech_stack:
  added: []
  patterns:
    - "library_tests_dep_off: dep-off CI lane pattern (mix deps.unlock + deps.clean + --no-deps-check)"
    - "@moduletag :requires_threadline: ExUnit tag to exclude Threadline-hard-dep tests in dep-off lane"
key_files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - test/sigra/audit/forwarders/threadline_test.exs
decisions:
  - "Added --no-deps-check to compile and test steps (Rule 1 auto-fix): mix deps.unlock removes the lock entry which causes mix to refuse compile/test without --no-deps-check; the flag is correct because we intentionally removed the dep"
  - "Approach A (deps.unlock + deps.clean) retained over sed/perl mix.exs edit: surgical, reversible, mirrors how local devs test dep absence"
  - "No docs build step in dep-off lane: mix docs requires full dep graph; existing library_tests job covers it"
metrics:
  duration: "~7 minutes"
  completed: "2026-05-27"
  tasks_completed: 2
  tasks_total: 2
  files_created: 0
  files_modified: 2
---

# Phase 131 Plan 06: Dep-off CI Lane (library_tests_dep_off) Summary

New `library_tests_dep_off` GitHub Actions job proves TL-04 SC-2 on every PR: when Threadline is absent from the dep graph, compile is clean (no UndefinedFunctionError), and all non-Threadline tests pass via `--exclude requires_threadline`.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add library_tests_dep_off job to .github/workflows/ci.yml | 1ea6ddd | .github/workflows/ci.yml |
| 2 | Add @moduletag :requires_threadline to threadline_test.exs | cf6d0be | test/sigra/audit/forwarders/threadline_test.exs |

## Implementation Details

### `.github/workflows/ci.yml` — New Job Block (lines 170-220)

The new `library_tests_dep_off` job is inserted between `library_tests` and `example_unit_smoke`. It mirrors the `library_tests` structure exactly with these deltas:

1. **Display name:** `Library tests (dep-off — Threadline absent)`
2. **Cache key:** `${{ runner.os }}-library-dep-off-${{ hashFiles('mix.lock') }}` — separate prefix prevents cache pollution with the main lane
3. **Dep-removal step** (new, runs after `mix deps.get`):
   ```
   mix deps.unlock threadline
   mix deps.clean threadline --build
   ```
4. **Compile step** (new): `mix compile --warnings-as-errors --no-deps-check`
5. **Test step**: `mix test --exclude requires_threadline --no-deps-check`
6. **No docs build step** — covered by `library_tests` which has the full dep graph

**SHA pins preserved (identical to library_tests):**
- `actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd`
- `erlef/setup-beam@fc68ffb90438ef2936bbb3251622353b3dcb2f93`
- `actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830`

### `test/sigra/audit/forwarders/threadline_test.exs` — One-line addition

Added `@moduletag :requires_threadline` immediately after `use ExUnit.Case, async: false`. This is the only test file carrying this tag — verified by `grep -lr '@moduletag :requires_threadline' test/sigra/`.

### Local Smoke Test Output

**Dep-off compile (after unlock + clean):**
```
MIX_ENV=test mix compile --warnings-as-errors --no-deps-check
# Exit 0 — no UndefinedFunctionError on Threadline atoms
```

**Dep-off test (audit/ directory):**
```
Running ExUnit with seed: 771971, max_cases: 36
Excluding tags: [:requires_threadline]

Finished in 0.4 seconds (0.1s async, 0.3s sync)
54 tests, 0 failures (6 excluded)
# Exit 0 — threadline_test.exs (6 tests) correctly excluded
```

**Normal lane (with Threadline dep, no --exclude):**
```
6 tests, 0 failures
# Exit 0 — @moduletag does NOT skip tests in the standard lane
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added --no-deps-check to compile and test steps**

- **Found during:** Task 1 local smoke validation
- **Issue:** The plan's approach (`mix deps.unlock threadline && mix deps.clean threadline --build` then `mix compile`) fails with `** (Mix) Can't continue due to errors on dependencies` because `mix deps.unlock` removes the lock entry, causing mix's built-in dep-check to reject compile/test. The plan did not account for this behavior.
- **Fix:** Added `--no-deps-check` flag to both the `mix compile --warnings-as-errors` step and the `mix test --exclude requires_threadline` step. This is the correct flag for intentional dep-graph mutations — it bypasses the lock consistency check while still running all other compile-time checks (including `--warnings-as-errors`).
- **Files modified:** `.github/workflows/ci.yml` (same commit 1ea6ddd — discovered and fixed inline during Task 1)
- **Impact:** No behavioral regression. The flag is correct and idiomatic for CI lanes that intentionally remove optional deps.

## Known Stubs

None. Both files contain production-ready CI configuration and test metadata.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes. The new CI job:
- Reuses SHA-pinned actions identical to `library_tests` (T-131-23 mitigated)
- Uses only local Postgres credentials (T-131-25 accepted — same as existing lanes)
- Avoids sed/perl mix.exs edits (T-131-26 N/A — deps.unlock approach used instead)

## Phase 136 Note

The `library_tests_dep_off` lane is the regression catch for TL-04 SC-2. Phase 136 PROOF-01 can assert this lane has been green for the duration of v1.29 by checking CI run history. The lane proves:
1. Plan 03's `no_warn_undefined` entries for Threadline atoms are complete (compile gate)
2. Plan 04's `Code.ensure_loaded?(Threadline)` wrap works (compile gate catches UndefinedFunctionError)
3. Plan 05's `maybe_warn_missing_forwarder_deps/0` + `attach_forwarders/0` don't crash when Threadline is absent (test gate)
4. The `@moduletag :requires_threadline` skip mechanism works (6 tests excluded, 54 pass)

## Self-Check: PASSED

- `.github/workflows/ci.yml` modified — FOUND, contains library_tests_dep_off job
- `test/sigra/audit/forwarders/threadline_test.exs` modified — FOUND, contains @moduletag :requires_threadline
- Commit 1ea6ddd (CI job) — FOUND
- Commit cf6d0be (@moduletag) — FOUND
- `grep -c 'library_tests_dep_off:' .github/workflows/ci.yml` == 1 — VERIFIED
- `grep -c 'mix deps.unlock threadline' .github/workflows/ci.yml` == 1 — VERIFIED
- `grep -c '--exclude requires_threadline' .github/workflows/ci.yml` == 1 — VERIFIED
- `grep -c 'library-dep-off' .github/workflows/ci.yml` == 1 — VERIFIED
- SHA de0fac2e count >= 2 (15 total) — VERIFIED
- SHA fc68ffb9 count >= 2 (11 total) — VERIFIED
- `@moduletag :requires_threadline` count in threadline_test.exs == 1 — VERIFIED
- Only threadline_test.exs carries the tag — VERIFIED
- YAML valid (python3 yaml.safe_load) — VERIFIED
- Dep-off compile smoke: exit 0 — VERIFIED
- Dep-off test smoke: 54 tests, 0 failures, 6 excluded — VERIFIED
- Normal lane test smoke: 6 tests, 0 failures — VERIFIED
