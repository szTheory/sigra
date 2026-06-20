---
phase: 195-test-suite-performance-partition-async-dep-off-slim
plan: "03"
subsystem: ci
status: complete
tags: [ci, github-actions, dep-off, threadline-guard, runners, runbook]
completed_date: "2026-06-20"
duration_minutes: 2

dependency_graph:
  requires:
    - 195-01-SUMMARY.md  # :threadline_guard tag + mix sigra.dep_off alias
    - 195-02-SUMMARY.md  # library_tests_dep_off topology + mix docs relocation
  provides:
    - "Slimmed library_tests_dep_off: mix test --only threadline_guard --no-deps-check (TEST-02/D-10)"
    - "D-11 fail-red-on-zero-match trust property: --only fails if tag is dropped/renamed"
    - "D-14 no-drift comment: CI lane comment links to MIX_ENV=test mix sigra.dep_off"
    - "D-09 compile proof: mix compile --warnings-as-errors --no-deps-check kept unchanged"
    - "CACHE-03 measurement-gate runbook: guides/recipes/local-development.md"
  affects:
    - ".github/workflows/ci.yml (library_tests_dep_off final step)"
    - "guides/recipes/local-development.md (CACHE-03 runbook section)"

tech_stack:
  added: []
  patterns:
    - "mix test --only <tag> as dep-off subset selector (fails RED on zero matches)"
    - "CI lane comment linking to local-repro alias as no-drift source of truth"
    - "Measurement-gate runbook: before/after table + decision rule for larger-runner adoption"

key_files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - guides/recipes/local-development.md

decisions:
  - "Kept discrete CI steps (unlock/clean/compile-proof) unchanged; only final test command changed to --only threadline_guard --no-deps-check — preferred option from D-14 (legibility preserved, alias is single source of truth for local repro)"
  - "D-21/D-22/D-23: No larger runners adopted; 2 free standard shards strictly dominate 1 paid larger runner for parallelizable work; wall-clock pole is Playwright (~22m, Phase 197 target)"

metrics:
  duration_minutes: 2
  completed: "2026-06-20"
  tasks: 2
  files_modified: 2
---

# Phase 195 Plan 03: Slim library_tests_dep_off + CACHE-03 Runbook Summary

**One-liner:** `library_tests_dep_off` final step changed to `mix test --only threadline_guard --no-deps-check` (65 tests vs full suite, fail-red on zero matches) with a no-drift comment, plus the CACHE-03 measurement-gate runbook documenting the reject-by-default larger-runner posture.

## What Was Built

### Task 1: Slim library_tests_dep_off to the guard subset (TEST-02 / D-09, D-10, D-11, D-14)

**Changed in `.github/workflows/ci.yml` — only the final test step of `library_tests_dep_off`:**

```yaml
# BEFORE:
- name: Run library tests (Threadline absent)
  env: { MIX_ENV: test, PGUSER: postgres, PGPASSWORD: postgres, PGHOST: localhost }
  run: mix test --exclude requires_threadline --no-deps-check

# AFTER (D-10/D-11/D-14):
# D-10/D-11/D-14: Run only the :threadline_guard tagged subset.
# `--only threadline_guard` fails RED on zero matches — a dropped/renamed tag turns CI red,
# never silently green (the D-11 trust property). This matches the final command in the
# `mix sigra.dep_off` alias exactly; local repro: MIX_ENV=test mix sigra.dep_off (D-14).
- name: Run guard subset (Threadline absent — :threadline_guard tagged modules only)
  env: { MIX_ENV: test, PGUSER: postgres, PGPASSWORD: postgres, PGHOST: localhost }
  run: mix test --only threadline_guard --no-deps-check
```

**Kept UNCHANGED** (as required):
- All preceding steps: checkout, setup-beam, dep-off cache, Hex+Rebar, phx_new 1.8.7, `mix deps.get`, `mix deps.compile`, `Remove :threadline from dep graph` (unlock/clean)
- `Compile without Threadline (--warnings-as-errors --no-deps-check)` proof step — D-09 load-bearing assertion preserved
- `Check docs build cleanly` (`mix docs --warnings-as-errors`) — D-07 relocation from Plan 02 preserved

**D-14 no-drift routing:** The discrete CI steps are kept as-is (preferred option per plan). The alias (`mix sigra.dep_off`) is the single source of truth for local repro, and CI's final command now matches the alias's final command verbatim. A comment in the lane makes this explicit.

**D-11 trust property:** `mix test --only <tag>` fails RED on zero matches — unlike `--exclude` which silently passes if the excluded tag doesn't exist. A renamed or dropped `:threadline_guard` tag will now turn CI red, not silently green.

**Expected speedup:** From ~13.8m (full suite rerun) to <3m (65-test guard subset). The compile proof (D-09) adds ~1m; the targeted test run adds ~1m. Total lane expected <3m vs 13.8m baseline (TEST-02 target met by design).

### Task 2: CACHE-03 measurement-gate runbook + D-21 assertion (CACHE-03 / D-21, D-22, D-23)

**Added to `guides/recipes/local-development.md`:** New "Larger-runner measurement gate (CACHE-03)" section containing:

- **D-21 billing fact:** Standard runners are free/unlimited on public repos; larger runners are billed per-minute even on public repos (~$0.016/min for 4-core as of June 2026) and do not consume included minutes. 2 free standard shards (4 effective cores, $0/min) strictly dominate 1 paid 4-core runner for parallelizable work.

- **D-22 decision rule** (adopt only if ALL of):
  - Job is on the critical path (its duration extends run-level wall-clock)
  - Job is genuinely un-shardable
  - Δwall-clock ≥30% on that job (measured, not estimated)
  - Run-level wall-clock actually drops (not masked by another pole)
  - Recurring $/min is accepted

- **Measurement procedure:** baseline from 193-BASELINE.md → A/B on larger label ×3 runs → measure wall-clock + billed-minutes + cache-hit → apply decision rule

- **Before/after table template (D-23):** Empty template with columns: job, runner label, wall-clock, billed-minutes, cache-hit, verdict

- **Current status:** All 16 `runs-on:` entries in ci.yml are `ubuntu-latest` (confirmed: 16/16 = ubuntu-latest). Larger runners evaluated and rejected per D-22 — wall-clock pole is `example_playwright_smoke` (~22m, Phase 197 target), not any job a larger runner would materially shorten.

**D-21 assertion verified:** `grep -cE '^\s*runs-on:' ci.yml` = 16 = `grep -cE '^\s*runs-on:\s*ubuntu-latest' ci.yml` = 16. No larger-runner label adopted.

## Verification Results

All acceptance criteria met:

```
grep -q 'only threadline_guard' .github/workflows/ci.yml         → PASS
grep -q 'exclude requires_threadline' .github/workflows/ci.yml   → PASS (not found — correctly absent)
grep -q 'warnings-as-errors --no-deps-check' .github/workflows/ci.yml → PASS (D-09 proof kept)
grep -q 'mix sigra.dep_off' .github/workflows/ci.yml             → PASS (D-14 comment present)
python3 -c "import yaml; yaml.safe_load(...)"                    → YAML_OK

grep -qi 'measurement' guides/recipes/local-development.md       → PASS
grep -qi 'billed' guides/recipes/local-development.md            → PASS
grep -qi 'decision rule' guides/recipes/local-development.md     → PASS
grep -qi 'before/after' guides/recipes/local-development.md      → PASS

runs-on: count: 16
ubuntu-latest count: 16
→ ALL_RUNS_ON_UBUNTU_LATEST (D-21 satisfied)

grep -q 'mix docs --warnings-as-errors' ci.yml                   → PASS (D-07 preserved)
```

## Deviations from Plan

None — plan executed exactly as written.

The preferred routing option from the plan (keep discrete CI steps, change only the final test command) was chosen. The alias remains the single source of truth for local repro; CI and local repro cannot drift because CI's final command matches the alias's final command verbatim.

## Threat Coverage

| Threat ID | Mitigation | Status |
|-----------|------------|--------|
| T-195-06 | `mix test --only threadline_guard` fails RED on zero matches; compile proof (D-09) kept | Mitigated |
| T-195-07 | CI final command matches alias final command verbatim; D-14 comment in lane | Mitigated |
| T-195-SC | No package installs; no new external dependency | Accepted (no gate needed) |

## Known Stubs

None.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 3d916910 | chore(195-03): slim library_tests_dep_off to :threadline_guard subset (TEST-02/D-10,D-11,D-14) |
| 2 | 3ab7ad4e | docs(195-03): add CACHE-03 larger-runner measurement-gate runbook (D-21,D-22,D-23) |

## Self-Check: PASSED

- [x] `--only threadline_guard` in dep-off final step (D-10)
- [x] `--exclude requires_threadline` removed from ci.yml (D-10)
- [x] `mix compile --warnings-as-errors --no-deps-check` proof step preserved (D-09)
- [x] `mix sigra.dep_off` referenced in lane comment (D-14)
- [x] `mix docs --warnings-as-errors` still present in library_tests_dep_off (D-07)
- [x] YAML parses as valid
- [x] All 16 `runs-on:` entries are `ubuntu-latest` (D-21)
- [x] CACHE-03 runbook in guides/recipes/local-development.md (D-23)
- [x] Decision rule (D-22) documented in runbook
- [x] Before/after table template (D-23) present in runbook
- [x] Both commits exist and verified
