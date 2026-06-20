---
phase: 193-baseline-observability-one-line-wins
plan: "01"
subsystem: CI/CD observability
tags: [baseline, ci-performance, observability, planning-artifact]
dependency_graph:
  requires: []
  provides: [193-BASELINE.md, BASE-01, BASE-02]
  affects: [193-02-PLAN.md, 193-03-PLAN.md, phases/194, phases/195, phases/196, phases/197, phases/198]
tech_stack:
  added: []
  patterns: [SEED-005 §3 per-job baseline table, gh CLI run data extraction, mix test --slowest diagnostics]
key_files:
  created:
    - .planning/phases/193-baseline-observability-one-line-wins/193-BASELINE.md
  modified: []
decisions:
  - "p95 reported as honest point estimates (n=4-9) per SEED-005 Pitfall 2 — no fabricated percentile from sparse data"
  - "Slowest tests dominated by subprocess-spawning install tests (23-33s each); these are high-value and correct, not targets for deletion"
  - "Sigra.Admin.Components is the dominant compile-chain bottleneck — 5 LiveView modules wait 329-347ms for it"
  - "CI schedulers_online=2 on ubuntu-latest limits ExUnit max_cases to 4 concurrent test cases despite 186 async modules — this is the quantified partitioning motivation for phase 195"
metrics:
  duration_seconds: 1096
  completed_date: "2026-06-19"
  tasks_completed: 2
  files_created: 1
  files_modified: 0
status: complete
requirements: [BASE-01, BASE-02]
---

# Phase 193 Plan 01: CI Baseline + Elixir Diagnostics Summary

Committed the CI performance before-state baseline and Elixir-side diagnostics as a planning artifact (193-BASELINE.md). This is the falsifiable reference for phases 194-198 — every later "CI is faster" claim diffs against it.

## What Was Built

**`193-BASELINE.md`** — a 226-line committed planning artifact containing:

1. **BASE-01: Per-job baseline table** — all 23 CI jobs with SEED-005 §3 columns (duration, p95, cache usage, required-for-merge, quality signal, likely bottleneck, notes). Data sourced from `gh run view 27846034918` (primary sample) and n=9 recent successful runs for p95. All p95 figures carry explicit sample-size notes (`n=4, point estimate` etc.).

2. **Critical path prose** — shows that `example_playwright_smoke` (22.2m) starts exactly 2 seconds after `library_tests` (15.9m) finishes (verified: 2026-06-19T20:19:24Z → 20:19:26Z), making total wall-clock 38m rather than the ~22m it would be without the gratuitous edge. This is the CRIT-01 finding that plan 03 fixes.

3. **BASE-02: Elixir-side diagnostics** — three diagnostic captures recorded as the optimization target:
   - `mix test --slowest 20`: install subprocess tests (23-33s each) dominate the top 11 positions; the upgrade integration tests (3 tests, ~95s combined) are the single most expensive module
   - `System.schedulers_online()`: local=18, CI=2 (ubuntu-latest 2 vCPU); `max_cases = 4` on CI despite 186 async modules — quantified partitioning motivation for phase 195
   - `MIX_ENV=test mix compile --force --profile time`: `Sigra.Admin.Components` is the compile-chain bottleneck — 5 LiveView modules wait 329-347ms for it (compile parallelism blocked until it completes)

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Gather CI run data and write per-job baseline table (BASE-01) | fdd41023 | 193-BASELINE.md (created) |
| 2 | Capture Elixir-side diagnostics into the baseline (BASE-02) | fdd41023 | 193-BASELINE.md (appended) |

Both tasks committed atomically in a single commit (same file, same read-only data-gathering session).

## Key Findings

- **Wall-clock range:** n=6 recent (2026-06-19) runs: 37.7m–40.4m. The SEED-005 "~17-30m" estimate was from an older codebase (2026-06-13) where the admin Playwright smoke suite was smaller (578s vs 1333s now).
- **Long poles:** `example_playwright_smoke` (22.2m) > `library_tests` (15.9m) > `library_tests_dep_off` (13.9m). Everything else is <5m.
- **Cache state (run 27846034918):** All caches were warm hits (library deps, example deps, npm node_modules). This is the warm-cache baseline; cold-cache runs would be significantly longer.
- **The CRIT-01 serialization is proven:** dropping `library_tests` from `example_playwright_smoke`'s `needs:` will reduce wall-clock ~16m (38m → ~22m) for a one-line YAML change.
- **`library_tests_dep_off` is over-broad:** re-runs all 2401 tests just to prove 2 compile guards work. TEST-02 (phase 195) targets this.

## Deviations from Plan

None — plan executed exactly as written. Read-only data gathering only; no `ci.yml`, spec, or runtime-code changes.

## Known Stubs

None — this plan creates a pure planning artifact (committed markdown). No UI, no data flows, no wired components.

## Threat Flags

None — the artifact contains only public CI timing and test-name data. No secrets, tokens, or PG credentials were pasted into the artifact (reviewed before commit).

## Self-Check: PASSED

- `193-BASELINE.md` exists at expected path: VERIFIED
- `grep -qi "critical path"`: PASSED
- `grep -q "example_playwright_smoke"`: PASSED
- `grep -Eq "slowest|schedulers_online"`: PASSED
- `grep -q "compile"`: PASSED
- `git diff --name-only HEAD~1 HEAD` shows only `193-BASELINE.md`: VERIFIED — zero drift to ci.yml, specs, or runtime code
- Commit `fdd41023` exists: VERIFIED
