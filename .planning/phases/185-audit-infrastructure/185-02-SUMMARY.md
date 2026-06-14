---
phase: 185-audit-infrastructure
plan: "02"
subsystem: ci-infrastructure
tags:
  - ci
  - quality-ledger
  - monotonic-guard
  - bash
  - github-actions
dependency_graph:
  requires:
    - guides/reference/admin-quality-ledger.md (produced by plan 185-01)
  provides:
    - scripts/ci/quality-ledger-monotonic.sh
    - quality_ledger_monotonic CI job in ci-gate
  affects:
    - .github/workflows/ci.yml (ci-gate merge gate extended)
tech_stack:
  added: []
  patterns:
    - Bash guard script mirroring snapshot-canary-guard.sh conventions
    - gawk gensub() for tier extraction from Markdown table column 4
    - GitHub Actions job cloned from snapshot_drift_guard shape
    - ci-gate aggregator extended (needs + env + loop)
key_files:
  created:
    - scripts/ci/quality-ledger-monotonic.sh
  modified:
    - .github/workflows/ci.yml
decisions:
  - Used gawk gensub() for tier extraction (available on ubuntu-latest; no POSIX fallback needed)
  - Mirrored snapshot-canary-guard.sh conventions exactly (shebang, set -euo pipefail, ROOT derivation, flag parsing, fail() helper, exit codes)
  - Initial-commit edge case exits 0 with INFO message when git show returns empty (no base ledger yet)
  - New items in HEAD ledger not in base are allowed (not checked); removed items are not checked
  - QUALITY_LEDGER_MONOTONIC env var uses uppercase; job key uses lowercase — mirrors SNAPSHOT_DRIFT_GUARD/snapshot_drift_guard convention
  - Same actions/checkout SHA (df4cb1c069e1874edd31b4311f1884172cec0e10) used in quality_ledger_monotonic as in snapshot_drift_guard
metrics:
  duration: "2m"
  completed: "2026-06-14T14:56:33Z"
  tasks_completed: 2
  files_changed: 2
---

# Phase 185 Plan 02: Quality Ledger Monotonic Guard Summary

## One-liner

Merge-blocking bash guard that prevents tier regression in admin-quality-ledger.md, wired into the ci-gate aggregator as a new required CI job.

## What Was Built

### Task 1: scripts/ci/quality-ledger-monotonic.sh

A new bash guard script (`scripts/ci/quality-ledger-monotonic.sh`) that enforces the "only move forward, never regress" discipline for the DS-COHERENCE milestone's quality tier ledger.

Key behaviors:
- `extract_tiers()`: reads stdin, extracts `item:tier` pairs from `guides/reference/admin-quality-ledger.md` using `grep -E '^\| [a-z]'` + `gawk gensub()` on column 4 — only digits `0`, `1`, or `2` are accepted as tier values
- Compares BASE tiers (from `git show $BASE:$LEDGER`) against HEAD tiers (working tree)
- Exits 0 on initial commit (no base ledger in git history — `git show 2>/dev/null` returns empty)
- Exits 1 on any per-cell tier decrease (`$head_tier -lt $base_tier`)
- Exits 2 on unknown CLI args
- Exits 0 on no-op (all tiers equal or increased) with PASS echo showing cell count
- New items in HEAD not in base: allowed (not a regression)
- Removed items: not checked (historical tiers only enforced on surviving items)

Script structure mirrors `scripts/ci/snapshot-canary-guard.sh` conventions exactly:
- `#!/usr/bin/env bash` + `set -euo pipefail`
- `ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"`
- `--base` flag parsing with `exit 2` on unknown args
- `fail()` helper
- Exit code contract: 0=PASS, 1=violation, 2=usage error

### Task 2: .github/workflows/ci.yml

Extended the CI pipeline with a new merge-blocking job and updated the ci-gate aggregator:

1. **New `quality_ledger_monotonic` job** (inserted before `ci-gate`):
   - Clones `snapshot_drift_guard` shape exactly (same checkout SHA, same base-ref resolution step)
   - Runs `bash scripts/ci/quality-ledger-monotonic.sh --base "${{ steps.base.outputs.ref }}"`

2. **ci-gate aggregator extended** (three changes):
   - `needs:` list: `quality_ledger_monotonic` added
   - `env:` block: `QUALITY_LEDGER_MONOTONIC: ${{ needs.quality_ledger_monotonic.result }}` added
   - `for lane in` loop: `QUALITY_LEDGER_MONOTONIC` added

## Verification Results

| Check | Result |
|-------|--------|
| `bash -n scripts/ci/quality-ledger-monotonic.sh` | PASS (syntax clean) |
| Executable bit `-rwxr-xr-x` | PASS |
| `--base NONEXISTENT_SHA` exits 0 + prints INFO | PASS |
| `--base HEAD` exits 0 (no ledger in HEAD yet) | PASS |
| `grep -i quality_ledger_monotonic ci.yml \| wc -l >= 4` | PASS (4 references) |
| `python3 yaml.safe_load(ci.yml)` exits 0 | PASS (valid YAML) |
| Same checkout SHA as snapshot_drift_guard | PASS (df4cb1c069e1874edd31b4311f1884172cec0e10) |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. The guard script is complete and functional. The `guides/reference/admin-quality-ledger.md` ledger file (the data source this guard reads) is created by plan 185-01. Until that file is committed and has a git history entry, this guard exits via the initial-commit path (INFO + exit 0), which is the correct intended behavior.

## Threat Flags

No new threat surface introduced. The guard is read-only (git show + file read). No new network endpoints, auth paths, file writes, or schema changes.

## Self-Check

### Created files exist:
- `/Users/jon/projects/sigra/.claude/worktrees/agent-a1cd25ac65134253d/scripts/ci/quality-ledger-monotonic.sh` — FOUND

### Commits exist:
- `098905b3` — feat(185-02): add quality-ledger-monotonic.sh merge-blocking guard
- `f534d1e9` — feat(185-02): wire quality_ledger_monotonic job into CI as merge-blocking gate

## Self-Check: PASSED
