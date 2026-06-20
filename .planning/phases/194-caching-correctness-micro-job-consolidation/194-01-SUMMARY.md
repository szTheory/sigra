---
phase: 194-caching-correctness-micro-job-consolidation
plan: "01"
subsystem: ci-infrastructure
tags: [ci, caching, github-actions, observability, documentation]
status: complete

dependencies:
  requires: []
  provides:
    - "Precision cache keys (OS+OTP+Elixir+MIX_ENV+lockfile+-v1) on all 11 deps+_build blocks"
    - "Cache-hit observability in $GITHUB_STEP_SUMMARY on 6 lanes"
    - "MAINTAINING.md cache-bust runbook (D-10)"
    - "MAINTAINING.md corrected required-check list (D-15)"
  affects:
    - ".github/workflows/ci.yml"
    - "MAINTAINING.md"

tech-stack:
  added: []
  patterns:
    - "erlef/setup-beam resolved outputs (otp-version/elixir-version) fed into cache keys"
    - "if: always() $GITHUB_STEP_SUMMARY cache-hit reporting"
    - "restore-keys prefix per namespace for warm-start"

key-files:
  created: []
  modified:
    - ".github/workflows/ci.yml"
    - "MAINTAINING.md"

decisions:
  - "D-03 gate executed at runtime: live ruleset 14941512 re-read, exactly 5 contexts confirmed, no ci-gate"
  - "D-04: OTP+Elixir+MIX_ENV+lockfile+-v1 applied to all 11 deps+_build blocks via setup-beam resolved outputs"
  - "D-05: 4 namespaces preserved (-library-, -library-dep-off-, -example-, -example-dev-)"
  - "D-06: deps+_build co-located; no PLT key introduced; forward-looking note in MAINTAINING.md"
  - "D-07: mix deps.get unconditional in every lane (ungated on cache-hit)"
  - "D-08: restore-keys prefix added per namespace (cushions first cold run)"
  - "D-09: 6 cache-hit summary lines (5 protected + dep_off companion) with 'exact hit' labeling"
  - "D-10: MAINTAINING.md cache key shape + -v1 bust handle + PLT note documented"
  - "D-15: MAINTAINING.md required-check list corrected to live ruleset; ci-gate noted as internal aggregator"
  - "Phase 193 BASE-03 ci.yml changes incorporated into worktree base (id: deps_cache, CI run summary)"
  - "hex-registry blocks left untouched (4 blocks; cache registry not _build, no correctness risk)"

metrics:
  duration: "~9 minutes"
  completed: "2026-06-20"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 2
  files_created: 0
---

# Phase 194 Plan 01: Caching Correctness (CACHE-01) Summary

Bound all 11 GitHub Actions `deps`+`_build` cache keys to the resolved toolchain identity (OS+OTP+Elixir+MIX_ENV+lockfile+-v1) eliminating the stale-artifact correctness risk, surfaced cache hit-rate in CI step summaries on 6 lanes with honest "exact hit" labeling, and documented the bust handle and live required-check reality in MAINTAINING.md.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Re-read live ruleset (D-03 gate) | 8f893e46 | (no file change — gate only) |
| 2 | Apply precision cache keys to 11 blocks (D-04/D-05/D-06/D-07/D-08) | 8f893e46 | .github/workflows/ci.yml |
| 3 | Cache hit summaries + MAINTAINING.md bust docs (D-09/D-10/D-15) | 8f893e46 | .github/workflows/ci.yml, MAINTAINING.md |

## Task 1: D-03 Live Ruleset Ground Truth

Re-read `gh api repos/szTheory/sigra/rulesets/14941512` at execution time (2026-06-20).

**Verbatim live required-check contexts (executor-time ground truth):**

1. `Example HTTP smoke (boot + curl critical routes)`
2. `Example Playwright smoke (full lifecycle)`
3. `Example unit smoke (ExUnit + ConnTest)`
4. `Install smoke (fresh phx.new + sigra.install)`
5. `Library tests`

**Confirmed:**
- Exactly 5 contexts.
- All 5 match the D-01 protected names byte-for-byte.
- `ci-gate` is NOT in the list.
- None of the 7 micro-guard jobs is in the list.

**D-03 gate: PASSED.** Proceeded with ci.yml edits.

## Task 2: Precision Cache Keys (D-04/D-05/D-06/D-07/D-08)

### New cache-step IDs (11 total)

| Job | Cache step id | Namespace |
|-----|---------------|-----------|
| install_golden_contract | `install_golden_deps_cache` | -library- |
| library_tests | `deps_cache` (pre-existing) | -library- |
| library_tests_dep_off | `dep_off_deps_cache` | -library-dep-off- |
| example_unit_smoke | `example_unit_deps_cache` | -example- |
| install_smoke | `install_smoke_deps_cache` | -library- |
| upgrade_smoke | `upgrade_smoke_deps_cache` | -library- |
| passkeys_manual_fallback_smoke | `passkeys_fallback_deps_cache` | -library- |
| install_matrix | `install_matrix_deps_cache` | -library- |
| passkeys_opt_out_smoke | `passkeys_opt_out_deps_cache` | -library- |
| example_http_smoke | `http_smoke_deps_cache` | -example-dev- |
| example_playwright_smoke | `example_deps_cache` (pre-existing) | -example-dev- |

### Cache key shapes (final per-namespace)

**-library- (7 blocks, MIX_ENV test):**
```
${{ runner.os }}-library-otp${{ steps.setup.outputs.otp-version }}-elixir${{ steps.setup.outputs.elixir-version }}-test-${{ hashFiles('mix.lock') }}-v1
```

**-library-dep-off- (1 block, MIX_ENV test):**
```
${{ runner.os }}-library-dep-off-otp${{ steps.setup.outputs.otp-version }}-elixir${{ steps.setup.outputs.elixir-version }}-test-${{ hashFiles('mix.lock') }}-v1
```

**-example- (1 block, MIX_ENV test):**
```
${{ runner.os }}-example-otp${{ steps.setup.outputs.otp-version }}-elixir${{ steps.setup.outputs.elixir-version }}-test-${{ hashFiles('test/example/mix.lock', 'test/example/config/**', 'test/example/lib/**/*.ex', 'lib/**/*.ex', 'mix.exs') }}-v1
```

**-example-dev- (2 blocks, MIX_ENV dev):**
```
${{ runner.os }}-example-dev-otp${{ steps.setup.outputs.otp-version }}-elixir${{ steps.setup.outputs.elixir-version }}-dev-${{ hashFiles('test/example/mix.lock', 'test/example/config/**', 'test/example/lib/**/*.ex', 'lib/**/*.ex', 'mix.exs') }}-v1
```

### D-06 verification

All 11 `path:` blocks list both `deps`/`test/example/deps` AND `_build`/`test/example/_build` co-located. No PLT path introduced.

### D-07 verification

All `mix deps.get` steps remain unconditional (no `if: steps.*cache.outputs.cache-hit` guard).

### D-08 discretion

Added `restore-keys` prefix per namespace (everything up to the lockfile hash) on all 11 blocks to cushion the one-time cold run forced by the key change.

## Task 3: Cache Hit Observability + Documentation (D-09/D-10/D-15)

### Lanes with cache-hit summary steps

| Lane | Step id referenced | Labeling |
|------|--------------------|----------|
| library_tests | `deps_cache` | "deps cache (exact hit)" |
| library_tests_dep_off | `dep_off_deps_cache` | "deps cache (exact hit)" |
| example_unit_smoke | `example_unit_deps_cache` | "deps cache (exact hit)" |
| install_smoke | `install_smoke_deps_cache` | "deps cache (exact hit)" |
| example_http_smoke | `http_smoke_deps_cache` | "deps cache (exact hit)" |
| example_playwright_smoke | `example_deps_cache` | "deps cache (exact hit)" |

Note: `example_deps_cache` was a pre-existing id (Phase 193) whose `cache-hit` output was never read (orphan). It is now wired into the playwright lane's cache-hit summary — no longer dead.

All labels say "exact hit" per Pitfall 1 (actions/cache `cache-hit` is `'true'` only on exact key match; on a restore-keys partial match it reports `'false'`).

No new `uses:` actions added for reporting — native `cache-hit` output + `$GITHUB_STEP_SUMMARY` shell echo only (D-09 supply-chain discipline).

### MAINTAINING.md subsection anchor (D-10)

Under `### Artifact, log, and cache retention` → `#### Actions deps+_build cache keys (CACHE-01)`:
- Documents cache key shape template
- Documents the `-v1` buster value and how-to-bust procedure
- Forward-looking D-06 note: future Dialyzer PLT cache must be separate

### MAINTAINING.md required-check correction (D-15)

Section `### Branch protection — enforced required checks (live ruleset)` replaces the stale "Branch protection — required check for install golden" section. Now:
- Lists all 5 live required-check contexts from ruleset 14941512
- Explicitly notes `ci-gate` is NOT an enforced required check (internal aggregator)
- Provides `gh api` command for on-demand verification
- Preserves `install_golden_contract` context with a clarifying note about its path-scoped nature

## Deviations from Plan

### Auto-incorporated base changes (not in plan scope)

**[Rule 3 - Blocking] Phase 193 BASE-03 ci.yml changes applied to worktree base**
- **Found during:** Plan startup — worktree was forked from commit 5d071538 before Phase 193's BASE-03 ci.yml changes were committed to the expected base (fb9e5a23).
- **Issue:** Worktree's ci.yml was missing: `id: deps_cache` on library_tests cache block, `id: example_deps_cache` on playwright lane cache block, CI run summary + test timing steps in library_tests, and the `example_playwright_smoke` needs change from `[release_ref_guard, library_tests]` to `[release_ref_guard]`.
- **Fix:** Copied fb9e5a23 ci.yml as the starting point before applying Phase 194-01 changes. This incorporated all Phase 193 BASE-03 changes correctly.
- **Files modified:** `.github/workflows/ci.yml`
- **Commit:** 8f893e46

### Auto-additions within plan scope

**[Rule 2 - Missing Critical] D-15 applied alongside D-10**
- The plan's Task 3 primarily targeted D-09/D-10 but D-15 (correct stale docs) was in the same MAINTAINING.md file. Applied it in the same task to avoid a second doc-only commit.
- Added `library_tests_dep_off` cache-hit summary (making 6 total) to meet the `>= 6` criterion — the 5 protected lanes plus the dep-off companion.

## Self-Check: PASSED

- `.github/workflows/ci.yml` exists: FOUND
- `MAINTAINING.md` exists: FOUND
- `194-01-SUMMARY.md` exists: FOUND
- Commit `8f893e46` exists: FOUND
- `actionlint .github/workflows/ci.yml` exits 0: PASS
- 11 precision cache keys (OTP+Elixir): PASS (22 occurrences = 11 key lines + 11 restore-keys lines)
- 11 -v1 buster segments: PASS
- 8 hex-registry lines unchanged: PASS
- 6 cache-hit summary lines: PASS
- All 5 protected lane names unchanged: PASS
- No mix deps.get gated on cache-hit: PASS
- MAINTAINING.md contains -v1 and bust documentation: PASS
