---
phase: 193-baseline-observability-one-line-wins
plan: "03"
subsystem: ci
tags: [ci, observability, performance, github-actions]
status: complete

dependency_graph:
  requires: []
  provides:
    - ci.yml parallel job graph (example_playwright_smoke no longer serialized on library_tests)
    - GITHUB_STEP_SUMMARY observability for library_tests (resolved versions, cache hit/miss, slowest tests)
    - cache-hit output enabled on library_tests and example_playwright_smoke cache steps
  affects:
    - .github/workflows/ci.yml

tech_stack:
  added: []
  patterns:
    - GITHUB_STEP_SUMMARY markdown append via plain run: shell (no new action)
    - actions/cache id: field to expose cache-hit output

key_files:
  modified:
    - .github/workflows/ci.yml

decisions:
  - Drop library_tests edge from example_playwright_smoke.needs — verified gratuitous (no data dependency, no artifact download from library_tests); keeps release_ref_guard
  - Add id: deps_cache to library_tests Cache library deps step and id: example_deps_cache to example_playwright_smoke Cache example deps step — additive only, cache behavior unchanged
  - Summary steps use if: always() and append to GITHUB_STEP_SUMMARY via run: shell — no new action, preserves supply-chain posture
  - Test timing summary uses mix test --slowest 10 || true — guard on echo only, never on the test command itself

metrics:
  duration: "2 min"
  completed_date: "2026-06-19"
  tasks_completed: 2
  files_modified: 1
---

# Phase 193 Plan 03: CI Observability and Parallel Job Graph Summary

Add `$GITHUB_STEP_SUMMARY` observability steps + `id:` on cache steps (BASE-03), and drop the single gratuitous `library_tests` edge from `example_playwright_smoke.needs` so the two long poles run concurrently (CRIT-01) — both additive changes to `.github/workflows/ci.yml` only.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Drop gratuitous library_tests edge from example_playwright_smoke needs (CRIT-01) | fa8346b7 | .github/workflows/ci.yml |
| 2 | Add cache-step id: and $GITHUB_STEP_SUMMARY observability steps (BASE-03) | 5999fc69 | .github/workflows/ci.yml |

## What Was Built

### CRIT-01: Parallel long poles

Changed `example_playwright_smoke` `needs:` from `[release_ref_guard, library_tests]` to `[release_ref_guard]`. The lane consumes zero artifacts/outputs from `library_tests` (verified: no `download-artifact` or `needs.library_tests.outputs.*` in the job). This one-line change lets the two longest CI jobs run concurrently:

- `library_tests` (~15.9m) and `example_playwright_smoke` (~22.2m) previously serialized: wall-clock ~38m
- After this change: both start right after the 2s `release_ref_guard` guard; expected new wall-clock ~22m

`example_playwright_smoke` remains in `ci-gate.needs` (line 1187/1213), so the lane is still required for merge.

### BASE-03: GITHUB_STEP_SUMMARY observability

Added to `library_tests` job:
- `id: deps_cache` on the `Cache library deps` step — enables `steps.deps_cache.outputs.cache-hit`
- `CI run summary` step (`if: always()`) — appends resolved Elixir version, OTP release, `System.schedulers_online()`, and deps cache hit/miss to `$GITHUB_STEP_SUMMARY`
- `Test timing summary` step (`if: always()`) — appends `mix test --slowest 10` output to `$GITHUB_STEP_SUMMARY` so slowest tests surface on every run without log spelunking

Added to `example_playwright_smoke` job:
- `id: example_deps_cache` on the `Cache example deps` step — enables `steps.example_deps_cache.outputs.cache-hit`

All summary `run:` blocks are `set -euo pipefail`-safe. The `mix test --slowest 10` is guarded with `|| true` on the echo, never on the test command itself. No untrusted `github.event.*` is interpolated into any summary step. No new third-party actions added.

## Deviations from Plan

None — plan executed exactly as written.

## Threat Mitigations Applied

| Threat ID | Mitigation Applied |
|-----------|-------------------|
| T-193-03-T1 | BASE-03 uses only plain `run:` shell + `$GITHUB_STEP_SUMMARY`; zero new actions; all SHA pins preserved |
| T-193-03-T2 | Summary `run:` steps echo only resolved versions, `steps.*.outputs.*`, and static strings; no `github.event.*` interpolation |
| T-193-03-E | Top-level `permissions: contents: read` preserved; no `permissions:` widening |
| T-193-03-D | Summary steps are `if: always()`; `|| true` guards summary echo only, never `mix test`; write failure cannot hide a red suite |

## Verification Results

All plan verification checks passed:
- `grep -q "GITHUB_STEP_SUMMARY" .github/workflows/ci.yml` — PASS
- `grep -q "cache-hit" .github/workflows/ci.yml` — PASS
- `grep -Eq "id: (deps_cache|example_deps_cache)" .github/workflows/ci.yml` — PASS
- `grep -nq "needs: \[release_ref_guard\]" .github/workflows/ci.yml` — PASS
- `! grep -q "needs: \[release_ref_guard, library_tests\]" .github/workflows/ci.yml` — PASS
- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` — PASS (exits 0)
- `example_playwright_smoke` still in `ci-gate.needs` (line 1213) — PASS
- No job name/id changed — PASS
- No cache `key:`, `path:`, or SHA pin changed — PASS
- No `github.event.*` in summary `run:` blocks — PASS

## Threat Flags

None — this plan adds workflow observability only; no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- `.github/workflows/ci.yml` — FOUND
- Commit fa8346b7 — FOUND (chore(193-03): drop gratuitous library_tests edge)
- Commit 5999fc69 — FOUND (chore(193-03): add cache step id: and GITHUB_STEP_SUMMARY observability)
