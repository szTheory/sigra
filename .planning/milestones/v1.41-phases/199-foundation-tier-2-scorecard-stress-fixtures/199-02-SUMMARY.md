---
phase: 199-foundation-tier-2-scorecard-stress-fixtures
plan: "02"
subsystem: ci-quality-guards
tags: [ci, quality-ledger, monotonic-guard, self-test, bash]
dependency_graph:
  requires: []
  provides: [LEDGER-02]
  affects: [scripts/ci/quality-ledger-monotonic.test.sh, .github/workflows/ci.yml]
tech_stack:
  added: []
  patterns: [hermetic-bash-self-test, throwaway-git-repo-fixture]
key_files:
  created:
    - scripts/ci/quality-ledger-monotonic.test.sh
  modified:
    - .github/workflows/ci.yml
decisions:
  - "D-04 confirmed: guard logic unchanged — numeric head_tier < base_tier already protects 2→1 for free"
  - "D-05 delivered: hermetic bash self-test proves the guard rejects a real 2→1 ledger delta"
  - "D-07 confirmed: existing guard step wiring (--base steps.base.outputs.ref) is byte-unchanged"
  - "Self-test uses a throwaway mktemp -d git repo with the guard binary at the same relative scripts/ci/ location so ROOT resolves correctly"
  - "Ledger fixture mirrors the real 4-column shape (Item/Level/Tier/Evidence) with a bare integer in column-4 matching the guard's awk -F'|' parse"
  - "Self-test placed in the same CI job as the existing guard step (inherits merge-blocking status without adding a new job or needs dependency)"
metrics:
  duration: "~5 minutes"
  completed: "2026-06-25"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
status: complete
requirements: [LEDGER-02]
---

# Phase 199 Plan 02: Monotonic Guard Self-Test (LEDGER-02) Summary

Positively proved the Tier-2 ratchet: a synthetic 2→1 ledger decrease provably fails the real guard binary. Added a hermetic bash self-test wired merge-blocking in CI alongside the existing guard step. Guard logic and CI wiring are unchanged (D-04, D-07).

## What Was Built

**`scripts/ci/quality-ledger-monotonic.test.sh`** — a hermetic bash self-test that:

1. Creates a throwaway git repo under `mktemp -d`
2. Installs the real `quality-ledger-monotonic.sh` at `scripts/ci/` inside the temp repo (so the guard's `ROOT` derivation resolves correctly: `cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd`)
3. Writes a minimal valid 4-column ledger (`| item | level | tier | evidence |`) with one Tier-2 cell and one Tier-1 cell matching the guard's parse rules (`grep -E '^\| [a-z]'` + `awk -F'|' '{tier=$4; if (tier ~ /^[012]$/)}'`)
4. Commits the baseline, then mutates the working tree to change the Tier-2 cell to Tier-1 (without committing)
5. **Test A:** Runs `quality-ledger-monotonic.sh --base <commit-sha>` and asserts exit is non-zero AND stderr contains `tier decreased`
6. **Test B:** Restores the file and asserts the same guard exits 0 (guard is not trivially always-failing)
7. Cleans up via `trap cleanup EXIT` — the real repo's `git status` is unchanged after the run

**`.github/workflows/ci.yml`** — added "Quality ledger monotonic guard self-test" step immediately after the existing "Quality ledger monotonic guard" step, in the same job (inheriting merge-blocking status). No new job, no `needs:` change, no gate aggregator change.

## Tasks Completed

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Write hermetic 2→1 guard self-test (D-05) | 9fa849f5 | scripts/ci/quality-ledger-monotonic.test.sh |
| 2 | Wire self-test as merge-blocking CI step (D-07) | 305d2000 | .github/workflows/ci.yml |

## Verification Results

- `bash scripts/ci/quality-ledger-monotonic.test.sh` exits 0: PASS (3/3 assertions)
- `bash scripts/ci/quality-ledger-monotonic.sh --base origin/main` exits 0: PASS (35 cells checked)
- `git status` of real repo clean after self-test run: PASS (only pre-existing REQUIREMENTS.md modification)
- `ci.yml` parses as valid YAML: PASS
- Both guard and self-test steps present in ci.yml: PASS

## Deviations from Plan

None — plan executed exactly as written. The synthetic ledger fixture format was clarified during implementation (4-column `| item | level | tier | evidence |` matching the real ledger's shape), which was required to match the guard's `awk -F'|' '{tier=$4}'` parse path correctly.

## Threat Flags

None. This plan introduces no new auth/crypto/input-handling code paths. The self-test is a CI tool only.

## Known Stubs

None.

## Self-Check: PASSED

- `scripts/ci/quality-ledger-monotonic.test.sh` exists: FOUND
- `bash scripts/ci/quality-ledger-monotonic.test.sh` exits 0: PASS
- Commit `9fa849f5` exists: FOUND
- Commit `305d2000` exists: FOUND
