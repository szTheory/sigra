---
phase: 198-contributor-dx-acceptance-gate
plan: "02"
subsystem: ci
tags: [ci, gate, design-gallery, hard-gate, todo-hygiene]
dependency_graph:
  requires: ["198-01"]
  provides: ["design-gallery hard-gated (D-06)", "GATE-02 no-regression guards", "D-07 todo hygiene"]
  affects: [".github/workflows/ci.yml", ".planning/todos/"]
tech_stack:
  added: []
  patterns: ["ci.yml YAML edit — remove soft-gate + restore aggregator loop entry"]
key_files:
  created:
    - .planning/todos/resolved/2026-06-20-complete-d10-design-gallery-re-gate-after-recapture.md
    - .planning/todos/resolved/2026-06-20-phase51-installer-milestone-audit-ci-contract-stale.md
    - .planning/todos/resolved/ (directory — new convention)
  modified:
    - .github/workflows/ci.yml (remove TEMP SOFT-GATE + restore aggregator entry)
decisions:
  - "D-06: Remove continue-on-error: true from design_gallery step; restore steps.design_gallery.outcome to aggregator loop — behind confirmed-green checkpoint (PR #60 / 9eed3474 on main)"
  - "D-07: Close Phase51 stale todo as already-resolved (no re-fix); close design-gallery deferral todo (all 4 D-10 steps complete)"
  - "Introduce .planning/todos/resolved/ directory as the todo-resolution convention (no resolved/ directory previously existed)"
metrics:
  duration: "~4 minutes"
  completed: "2026-06-21"
  tasks_completed: 3
  tasks_total: 4
  tasks_note: "Task 1 was a checkpoint pre-resolved by orchestrator before this execution"
  files_changed: 3
status: complete
---

# Phase 198 Plan 02: Hard Re-Gate Design-Gallery + GATE-02 No-Regression Guards Summary

**One-liner:** Hard re-gate of the design_gallery CI lane (remove TEMP SOFT-GATE continue-on-error, restore aggregator entry) behind confirmed-green ubuntu baselines; GATE-02 no-regression invariants proven byte-stable; D-07 todo hygiene complete.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| Task 1 | Confirm-green checkpoint (pre-resolved) | (checkpoint — no commit) | — |
| Task 2 | Hard re-gate design-gallery lane (D-06) | 32d43bb5 | .github/workflows/ci.yml |
| Task 3 | Verify required-name stability + contract locks (read-only) | (no files changed) | phase_51/phase_192 contract tests |
| Task 4 | Close stale todos (D-07 hygiene) | 8d3b1e3c | .planning/todos/resolved/ |

## What Was Built

### Task 2: Hard Re-Gate (D-06)

Two exact edits to `.github/workflows/ci.yml`:

**Edit 1:** Removed the `TEMP SOFT-GATE` comment block and `continue-on-error: true` from the `design_gallery` step (was at line ~1047). The step's HARD-GATING rationale comments (Phase 197 / D-10, font-metric root cause, remediation summary) are preserved.

**Edit 2:** Restored `"${{ steps.design_gallery.outcome }}"` into the `Aggregate Playwright step outcomes` for-loop and removed the `TEMP (bootstrap ordering ...)` comment that explained the omission.

**Invariants verified after edit:**
- `grep -cE '^[[:space:]]*continue-on-error: true' .github/workflows/ci.yml` = **1** (was 2; the intentional nightly OQ3 key at ~1595 stays; the unrelated OQ3 comment line at ~1591 is untouched)
- No real `continue-on-error: true` key exists within the `design_gallery` step range
- `steps.design_gallery.outcome` present in the aggregator loop (line 1102)
- Path-detector regex still appears **exactly twice** (phase_51 lock: 2)
- MG-5/6 `test.skip(` marker untouched in admin-design.spec.ts
- No job `name:` string changed

### Task 3: GATE-02 No-Regression Guards (read-only assertions)

**Required-check names (ruleset 14941512) — verbatim output:**
```
Library tests
Example unit smoke (ExUnit + ConnTest)
Install smoke (fresh phx.new + sigra.install)
Example HTTP smoke (boot + curl critical routes)
Example Playwright smoke (full lifecycle)
```

All 5 required-check names are byte-stable. This is the verbatim `gh api repos/szTheory/sigra/rulesets/14941512 --jq '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context'` output for Plan 03 to cite.

**Contract lock tests:**
```
mix test test/sigra/planning/phase_51_install_golden_ci_contract_test.exs \
         test/sigra/planning/phase_192_known_failure_contract_test.exs
→ 3 tests, 0 failures
```

**Snapshot-canary-guard:**
```
bash scripts/ci/snapshot-canary-guard.sh
→ snapshot-canary-guard: PASS (0 changed slug(s), all within allowlist)
```

### Task 4: Todo Hygiene (D-07)

Created `.planning/todos/resolved/` directory (new convention — no resolved/ directory previously existed).

**Moved to resolved:**
1. `2026-06-20-complete-d10-design-gallery-re-gate-after-recapture.md` — all 4 D-10 sequence steps complete; hard re-gate landed in commit 32d43bb5.
2. `2026-06-20-phase51-installer-milestone-audit-ci-contract-stale.md` — already-resolved; `installer_milestone_audit:` absent from ci.yml; `phase_51` contract test passes (asserts `install_golden_contract:` + `scripts/ci/installer-milestone-audit.sh`). No re-fix applied.

## Deviations from Plan

### Auto-fixed Issues

None — plan executed exactly as written.

### Task 3 Note

Task 3 is read-only assertions with no file changes. No separate commit was created for Task 3; its evidence is captured in this SUMMARY (the verbatim ruleset output above).

## Decisions Made

1. **D-06 hard re-gate landed:** Exactly two ci.yml edits as specified. The nightly OQ3 `continue-on-error: true` at line ~1595 (inside `admin_design_recapture`) was not touched. The OQ3 comment line at ~1591 (`# continue-on-error: true so a font-driven compare failure...`) was not touched.

2. **D-07 todo resolution convention:** Created `.planning/todos/resolved/` directory as the resolution landing zone. Both todos moved there with full resolution notes (resolving commit, date, evidence). No annotation-in-place approach was used since the directory pattern is cleaner.

3. **Phase51 stale todo: no re-fix.** The contract test already correctly asserts `install_golden_contract:` and `scripts/ci/installer-milestone-audit.sh`; the todo was stale documentation of a problem that had already been fixed in an earlier phase.

## GATE-02 Acceptance Evidence

| Invariant | Result |
|-----------|--------|
| Real `continue-on-error: true` keys in ci.yml | 1 (was 2) |
| design_gallery soft-gate removed | Yes (32d43bb5) |
| `steps.design_gallery.outcome` in aggregator | Yes |
| Path-detector regex count (phase_51 lock) | 2 (unchanged) |
| MG-5/6 test.skip marker (phase_192 lock) | Present (unchanged) |
| Required-check names byte-stable (ruleset 14941512) | 5/5 verified |
| Contract lock tests | 3 tests, 0 failures |
| snapshot-canary-guard.sh | PASS (0 changed slugs) |
| Both pending todos closed | Yes (moved to resolved/) |

## Self-Check: PASSED

- `.github/workflows/ci.yml` — modified and committed (32d43bb5)
- `.planning/todos/resolved/2026-06-20-complete-d10-design-gallery-re-gate-after-recapture.md` — created (8d3b1e3c)
- `.planning/todos/resolved/2026-06-20-phase51-installer-milestone-audit-ci-contract-stale.md` — created (8d3b1e3c)
- Commits verified in git log: 32d43bb5, 8d3b1e3c
