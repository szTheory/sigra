---
phase: 235-terminal-ratification-measured-not-read
plan: 07
subsystem: ci-evidence
tags: [github-actions, provenance, pagination, attestation, fast-01, gate-05]
requires:
  - phase: 235-06
    provides: canonical terminal receipts and ownership semantics
provides:
  - Main-only, separately attested receipt capture workflow
  - Fail-closed bounded GitHub Actions pagination collector
  - External-evidence API coverage contract
affects: [FAST-01, GATE-05]
tech-stack:
  added: [GitHub artifact attestations]
  patterns: [terminal empty page proof, manifest validation, offline provenance verification]
key-files:
  created:
    - .github/workflows/terminal-ratification-evidence.yml
    - scripts/ci/capture-terminal-ratification-evidence.sh
    - scripts/ci/capture-terminal-ratification-evidence.test.sh
    - .planning/phases/235-terminal-ratification-measured-not-read/235-COVERAGE.md
  modified:
    - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
key-decisions:
  - Protected evidence is collected only by a main-ref manual workflow and bound by GitHub artifact attestation.
  - Pagination proves exhaustion with a retained terminal empty page; the 19-run/772-second FAST-01 miss is unchanged.
metrics:
  tasks_completed: 2
  files_modified: 5
completed: 2026-08-02
status: complete
---

# Phase 235 Plan 07: Protected Terminal Receipt Summary

A main-only workflow can now produce an attested, complete receipt for the fixed Phase 235 CI interval without joining the CI required-check graph.

## Accomplishments

- Added a fixed-bound `gh api` collector that retains every requested workflow/job page, including the terminal empty page, and rejects count, identity, pagination, and chronology corruption before canonical output.
- Added the separately dispatched, least-privilege workflow with immutable checkout, provenance-attestation, and upload action pins.
- Added hermetic fake-GitHub coverage and an ExUnit workflow contract; documented every Plan 07–08 evidence API seam and its hard-stop policy.

## Protected Main Handoff

- Workflow blob: `dcb7a8d051e14f58a8e49ec7385dad291aa315b3`
- Introducing commit: `36ebf430`
- Plan 08 remains blocked until a maintainer merges that exact blob to `origin/main` and independently confirms the protected workflow executor matches it.

## Task Commits

1. `53ac25cf` — RED protected-workflow contract.
2. `36ebf430` — attested receipt collector and main-only workflow.
3. `48487b64`, `9deb3a07`, `78191931`, `874f8518` — collector fixture/manifest/portable-jq corrections found during tracer verification.
4. `fafe3b19` — external evidence API coverage declaration.

## Verification

- `bash scripts/ci/capture-terminal-ratification-evidence.test.sh` — passed; hermetic fake `gh` proves the production collector requests terminal empty pages and rejects inverted runs.
- `MIX_ENV=test mix test test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` — 16 tests, 0 failures.
- Ledger assertion: 19 eligible PR runs, p50 `772`, status `miss`; `.github/workflows/ci.yml` remains byte-unchanged.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 1 - Bug] Corrected fixture page matching and manifest validation**
   - **Found during:** Task 1 tracer verification.
   - **Issue:** Prefix page matching and per-line jq validation could accept or reject the wrong fixture shape; one jq predicate was unavailable in the repository version.
   - **Fix:** Parsed exact page values, slurped the manifest before validation, corrected envelope identity comparisons, and used portable event predicates.
   - **Files modified:** `scripts/ci/capture-terminal-ratification-evidence.sh`, `scripts/ci/capture-terminal-ratification-evidence.test.sh`
   - **Verification:** Hermetic collector fixture and focused ExUnit contract passed.
   - **Commits:** `48487b64`, `9deb3a07`, `78191931`, `874f8518`

**Total deviations:** 1 auto-fixed (Rule 1). **Impact:** strengthens the fail-closed collector; no CI topology or measurement behavior changed.

## Known Stubs

None.

## Self-Check: PASSED

- All five planned artifacts exist and all recorded task commits are reachable.
- No new product endpoint, auth path, schema, or `ci.yml` DAG surface was introduced.
