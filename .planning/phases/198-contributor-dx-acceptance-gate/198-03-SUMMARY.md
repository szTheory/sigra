---
phase: 198-contributor-dx-acceptance-gate
plan: "03"
subsystem: ci
tags: [ci, gate, acceptance-evidence, gate-01, gate-02, d-05, d-06]
dependency_graph:
  requires: ["198-02"]
  provides: ["198-ACCEPTANCE.md (GATE-01 before/after evidence)", "MAINTAINING.md acceptance pointer", "GATE-02 required-name attestation"]
  affects:
    - ".planning/phases/198-contributor-dx-acceptance-gate/198-ACCEPTANCE.md"
    - "MAINTAINING.md"
tech_stack:
  added: []
  patterns: ["gh run view --json jobs timing capture", "before/after acceptance artifact mirroring 193-BASELINE shape"]
key_files:
  created:
    - .planning/phases/198-contributor-dx-acceptance-gate/198-ACCEPTANCE.md
  modified:
    - MAINTAINING.md
decisions:
  - "Real post-197 PR-path CI timings captured via gh (n=3 runs, 2026-06-20) — wall-clock reduced from ~38.6m to ~22.1m avg (-43%); GATE-01 met"
  - "5 required-check name strings confirmed byte-stable via live ruleset 14941512 — GATE-02 name-stability assertion"
  - "Flake-rate: 0 reruns in after-cohort sample; FLAKE-01 (demo-showcase rgb) confirmed resolved"
  - "Phase 198 moved nothing new to nightly — tradeoffs ledger unchanged from Phase 196 D-08 baseline"
  - "SEED-004 phx_new 1.8.7 confirmed pinned in 9 ci.yml locations; snapshot-canary-guard PASS"
  - "D-06 hard re-gate confirmed: continue-on-error count = 1 (only the intentional OQ3 nightly key remains)"
  - "198-ACCEPTANCE.md placed in .planning/phases/ with a MAINTAINING.md ADD-only pointer"
metrics:
  duration: "~6 minutes"
  completed: "2026-06-21"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 2
status: complete
---

# Phase 198 Plan 03: CI-PERF Acceptance Evidence Summary

**One-liner:** Committed before/after acceptance artifact (198-ACCEPTANCE.md) with real post-197 PR-path CI timings showing -16.5m wall-clock improvement (-43%, 38.6m → 22.1m avg, n=3 runs), 5 required-name strings byte-stable, 0 flakes, and an ADD-only MAINTAINING.md pointer.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| Task 1 + 2 | Capture real post-197 CI timings + author 198-ACCEPTANCE.md | 525bb0d7 | .planning/phases/198-contributor-dx-acceptance-gate/198-ACCEPTANCE.md |
| Task 3 | ADD-only MAINTAINING.md pointer to acceptance artifact | bdcbaa55 | MAINTAINING.md |

## What Was Built

### Tasks 1 + 2: 198-ACCEPTANCE.md

Captured per-job timings from 3 successful PR-path CI runs on 2026-06-20 using `gh run view --json jobs`. All numbers are falsifiable by run ID.

**After-cohort (n=3 PR runs, 2026-06-20, post-Phase 193-198 pipeline):**

| Run ID | Trigger | Wall-Clock |
|--------|---------|-----------|
| 27884350750 | pull_request | 1379s (23.0m) |
| 27883990824 | pull_request | 1369s (22.8m) |
| 27883386841 | pull_request | 1237s (20.6m) |

**Before vs After summary:**

| Metric | Before (n=6, 193-BASELINE) | After (n=3, 198-ACCEPTANCE) | Delta |
|--------|----------------------------|-----------------------------|-------|
| Avg wall-clock | ~38.6m | ~22.1m | **-16.5m (-43%)** |
| p95 | ~40.4m | ~23.0m | -17.4m |

**Per-long-pole:**

| Job | Before avg | After avg | Delta |
|-----|-----------|-----------|-------|
| example_playwright_smoke | 22.2m | 21.9m | -0.3m (now starts at t+6s instead of t+16m) |
| Library tests (shard max) | 16.0m (single runner) | 8.5m (shard max) | -7.5m (Phase 195 2-shard partition) |
| Library tests dep-off | 13.8m (full re-run) | 3.4m (--only threadline_guard) | -10.4m (Phase 195 targeted subset) |

**Quality-signal parity proof (GATE-02):**

Verbatim ruleset 14941512 output (captured 2026-06-21):
```
Library tests
Example unit smoke (ExUnit + ConnTest)
Install smoke (fresh phx.new + sigra.install)
Example HTTP smoke (boot + curl critical routes)
Example Playwright smoke (full lifecycle)
```
All 5 byte-stable. D-06 hard re-gate confirmed (design_gallery now hard-gates; continue-on-error count = 1 intentional OQ3 key only). Flake-rate = 0 reruns observed. SEED-004 phx_new 1.8.7 pinned in 9 locations. snapshot-canary-guard PASS.

### Task 3: MAINTAINING.md ADD-only pointer

Appended a single paragraph after the "Accepted residuals (D-07)" subsection, before "Squash-merge [skip ci] footgun". The pointer references `.planning/phases/198-contributor-dx-acceptance-gate/198-ACCEPTANCE.md` as the committed before/after acceptance evidence. No existing content deleted or rewritten. All 5 required-check name strings remain intact.

## Automated Verify Checks

**Task 2:**
- `grep -qF '193-BASELINE' 198-ACCEPTANCE.md` → PASS
- `grep -qiE 'p95|wall-clock' 198-ACCEPTANCE.md` → PASS
- `grep -qF 'Library tests' 198-ACCEPTANCE.md` → PASS
- `grep -qF '1.8.7' 198-ACCEPTANCE.md` → PASS

**Task 3:**
- `grep -qF '198-ACCEPTANCE.md' MAINTAINING.md` → PASS
- `grep -qF 'Library tests' MAINTAINING.md` → PASS
- `grep -qF 'Example Playwright smoke (full lifecycle)' MAINTAINING.md` → PASS

## Deviations from Plan

None — plan executed exactly as written.

**Post-verification addition (2026-06-21):** Added a "Target shortfall (honest disclosure)" subsection to `198-ACCEPTANCE.md` stating that the ~22.1m result meets the hard GATE-01 bar but not the aspirational ROADMAP SC-2 "<~12m fast PR path" stretch target, with root cause (`example_playwright_smoke` is the binding ~22m floor) and deferral note — per D-05 honest-numbers discipline.

**Note on Task 1+2 commit consolidation:** Tasks 1 and 2 both authored the same file (`198-ACCEPTANCE.md`) — Task 1 gathered the data and Task 2 completed the quality-signal and tradeoffs sections. These were committed together in a single atomic commit (525bb0d7) since the file was in-progress through both tasks. This is a reasonable consolidation for a single-file artifact.

## Decisions Made

1. **n=3 after-cohort is sufficient for the purpose.** Three successful PR-path runs showing consistent clustering (1237s, 1369s, 1379s) establish the wall-clock range with high confidence. The honest shortfall (small n for statistical rigor) is stated explicitly in 198-ACCEPTANCE.md.

2. **Tasks 1+2 combined into one commit.** Both tasks authored the same artifact. The combined commit message documents all sections produced.

3. **ADD-only insertion point chosen at end of "Accepted residuals" subsection** (before "Squash-merge [skip ci] footgun"). This is the natural location that follows the CI-cadence prose without interrupting the existing D-07 disclosure.

4. **flake rate stated as 0 with honest caveat.** No reruns in the sample. The structural defense (hard gates, contract lock tests, canary guard) is cited as the durable protection rather than overstating the n=3 statistical confidence.

## Self-Check: PASSED

- `.planning/phases/198-contributor-dx-acceptance-gate/198-ACCEPTANCE.md` — created (525bb0d7) ✓
- `MAINTAINING.md` — modified with ADD-only pointer (bdcbaa55) ✓
- Commits verified in git log: 525bb0d7, bdcbaa55 ✓
- Task 2 automated greps: all 4 PASS ✓
- Task 3 automated greps: all 3 PASS ✓
