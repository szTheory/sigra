---
phase: 198-contributor-dx-acceptance-gate
plan: "01"
subsystem: contributor-dx
tags: [mix-alias, contributing, contract-test, dx]
dependency_graph:
  requires: []
  provides: [mix-ci-alias, contributing-dx-01-section, phase-198-contract-lock]
  affects: [mix.exs, CONTRIBUTING.md, test/sigra/planning/]
tech_stack:
  added: []
  patterns: [contract-lock-test, mix-alias-chain]
key_files:
  created:
    - test/sigra/planning/phase_198_contributor_dx_contract_test.exs
  modified:
    - mix.exs
    - CONTRIBUTING.md
decisions:
  - DX-01 mix ci chains exactly four legs (compile --warnings-as-errors, test, ci.install_golden, sigra.dep_off) — no stricter legs per D-03
  - CONTRIBUTING documents CI-only excluded lanes (ubuntu Playwright snapshots and heavy scaffold smokes) so contributors do not misread CI-only failures as local regressions
  - Contract-lock test uses plain File.read! with no Postgres or app boot to stay in the fast planning test lane
metrics:
  duration_minutes: 3
  completed_date: "2026-06-21"
  tasks_completed: 3
  files_modified: 3
status: complete
---

# Phase 198 Plan 01: Contributor DX — mix ci alias + contract lock Summary

**One-liner:** `mix ci` alias added as a four-leg DX-01 PR-gate mirror (compile + test + install-golden + dep-off), documented in CONTRIBUTING.md with prereqs and CI-only caveats, pinned by a contract-lock test.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add mix ci alias to mix.exs aliases/0 | 6badb0e0 | mix.exs |
| 2 | Document mix ci + prereqs + CI-only caveats in CONTRIBUTING.md | 5aa17be7 | CONTRIBUTING.md |
| 3 | Add contract-lock test Phase198ContributorDxContractTest | a41a1d8b | test/sigra/planning/phase_198_contributor_dx_contract_test.exs |

## What Was Built

**Task 1 — mix ci alias (mix.exs):** Added a `ci:` key to the `aliases/0` keyword list, chaining exactly the four PR-gate legs in CI order: `"compile --warnings-as-errors"`, `"test"`, `"ci.install_golden"`, `"sigra.dep_off"`. A comment above the entry names it as the DX-01 local mirror and notes the Postgres and phx_new 1.8.7 prerequisites. No format/credo/dialyzer legs were added (D-03 not-stricter-than-CI invariant).

**Task 2 — CONTRIBUTING.md DX-01 section:** Added `## Reproducing the PR gate locally (mix ci)` section after `## Developing`. Documents: the four-leg command and what each mirrors; Postgres prereq with `scripts/db/up.sh` + `source tmp/db.env` path; phx_new 1.8.7 archive requirement (SEED-004); CI-only excluded lanes (ubuntu-baselined Playwright visual snapshots and heavy scaffold smokes with exact optional commands `scripts/ci/install-smoke.sh` and `scripts/ci/http-smoke.sh`); optional local hygiene commands (format/credo/dialyzer) explicitly framed as not in the PR gate; and known non-regression v1.40 mix test failures.

**Task 3 — contract-lock test:** Created `Sigra.Planning.Phase198ContributorDxContractTest` modeled on `phase_51_install_golden_ci_contract_test.exs` style (same `root/0` + `read!/1` helpers, `use ExUnit.Case, async: true`). Three tests: (1) `ci:` key present in aliases region with all four required leg strings; (2) `ci:` entry does not contain credo, dialyzer, or `format --check-formatted` (D-03 negative assert); (3) CONTRIBUTING.md mentions `mix ci` and `1.8.7`. No Postgres, no app boot — runs in the fast `mix test test/sigra/planning/` lane.

## Verification Results

- `mix compile --warnings-as-errors` — PASS
- `mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs` — 3 tests, 0 failures
- `mix test test/sigra/planning/` (full contract-lock lane) — 39 tests, 0 failures, 12 skipped
- CONTRIBUTING grep checks (mix ci, 1.8.7, install-smoke.sh/http-smoke.sh) — all PASS

## Deviations from Plan

None — plan executed exactly as written.

## Threat Coverage

| Threat ID | Status | Note |
|-----------|--------|------|
| T-198-01 (false-green) | Mitigated | Alias chains only real PR-gate commands; contract test (Task 3 test 198-01) locks the four legs |
| T-198-02 (false-red / scope creep) | Mitigated | D-03 excludes format/credo/dialyzer; Task 3 test 198-02 negative-asserts their absence |
| T-198-03 (silent doc drift) | Mitigated | Task 3 test 198-03 fails if CONTRIBUTING drops the mix ci or 1.8.7 mention |

## Known Stubs

None.

## Self-Check: PASSED

- `/Users/jon/projects/sigra/mix.exs` — FOUND, ci: alias present with 4 legs
- `/Users/jon/projects/sigra/CONTRIBUTING.md` — FOUND, mix ci section with all required content
- `/Users/jon/projects/sigra/test/sigra/planning/phase_198_contributor_dx_contract_test.exs` — FOUND, 3 tests passing
- Commits: 6badb0e0, 5aa17be7, a41a1d8b — all present in git log
