---
phase: 212-v1-42-integration-merge-canary-reconciliation-gate-the-perso
plan: "03"
subsystem: ci
tags: [ci, gate, playwright, generated-host, GATE-02]
requires: [212-02]
provides: [GATE-02-wiring]
affects: [.github/workflows/ci.yml]
tech_stack:
  added: []
  patterns: [branch-scoped CI job condition]
key_files:
  modified:
    - .github/workflows/ci.yml
decisions:
  - "Branch-scoped if: github.event_name != 'pull_request' || github.head_ref == 'ship/v1.42-ci-gate-remediation' rather than un-skipping on all PRs, to avoid ~30-60m cold phx.new+Playwright cost on every future PR (D-08)"
  - "Comment added above if: marks the disjunct as GATE-02/D-08 temporary and trivially removable post-merge — no dead config"
metrics:
  duration: "78s"
  completed: "2026-07-02"
  tasks_completed: 1
  tasks_total: 1
  files_changed: 1
status: complete
---

# Phase 212 Plan 03: Branch-scope generated_admin_playwright_smoke Summary

Branch-scoped `if:` on generated_admin_playwright_smoke adds `|| github.head_ref == 'ship/v1.42-ci-gate-remediation'` so the job runs (not skips) on PR #63, closing GATE-02's false-green ci-gate gap.

## What Was Built

Modified `generated_admin_playwright_smoke`'s `if:` condition in `.github/workflows/ci.yml` from:

```yaml
if: github.event_name != 'pull_request'
```

to:

```yaml
# GATE-02 / D-08: temporary integration-scoped relaxation — runs on PR #63's head branch
# (ship/v1.42-ci-gate-remediation) to prove generated-host parity in CI; remove after merge.
if: github.event_name != 'pull_request' || github.head_ref == 'ship/v1.42-ci-gate-remediation'
```

This means:
- On pushes to any branch (non-PR events): job runs as before
- On PR #63 (`head_ref == 'ship/v1.42-ci-gate-remediation'`): job now RUNS instead of skipping
- On all other PRs: job skips as before (no 30-60m cold phx.new cost added to routine PRs)

The ci-gate job's `GENERATED_ADMIN_PLAYWRIGHT_SMOKE` env var (ci.yml:1357) now receives a real `success`/`failure` result on PR #63 instead of `skipped` (which ci-gate was treating as not-failed → false-green).

## Verification Results

All three automated checks passed:

1. `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"` — YAML: VALID
2. `grep -q "head_ref == 'ship/v1.42-ci-gate-remediation'" .github/workflows/ci.yml` — head_ref disjunct: FOUND
3. `grep -c "if: github.event_name != 'pull_request'" .github/workflows/ci.yml` = 8 (≥5) — PASS

The 8 remaining plain `github.event_name != 'pull_request'` guards (lines ~520, 573, 624, 754, 1395, 1696, 1877, and the new disjunct itself which contains the exact string) are all unmodified jobs. The other `if: github.event_name != 'pull_request'` guards at lines 520/573/624/754/1395/1696/1877 are untouched.

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Branch-scope generated_admin_playwright_smoke PR-skip (D-08) | efaf350c | .github/workflows/ci.yml |

## Deviations from Plan

None — plan executed exactly as written. The integration branch name `ship/v1.42-ci-gate-remediation` was confirmed live via `gh pr view 63` before the edit.

## Decisions Made

1. **Disjunction not substitution:** Kept `github.event_name != 'pull_request'` as the first operand (push/nightly path preserved) and added `|| github.head_ref == 'ship/v1.42-ci-gate-remediation'` as the second (PR #63 path).
2. **Comment as intent signal:** Two-line comment directly above `if:` names GATE-02 and D-08, declares it temporary/integration-scoped, and says "remove after merge" — so a future reader immediately knows it is intentional and bounded, not dead config.
3. **Scope unchanged:** No other job's `if:`, the smoke run step, the golden test, or installer templates were touched.

## Known Stubs

None.

## Threat Flags

None — CI-config edit only; no new runtime attack surface introduced.

## Self-Check: PASSED

- `.github/workflows/ci.yml` modified: confirmed (git diff HEAD~1 shows 3-line change)
- Commit `efaf350c` exists: confirmed (`git log --oneline -1` = `efaf350c feat(212-03): ...`)
- YAML valid: python3 yaml.safe_load passed
- head_ref disjunct present: grep confirmed
- Plain pull_request-skip guard count ≥ 5: 8 guards confirmed
