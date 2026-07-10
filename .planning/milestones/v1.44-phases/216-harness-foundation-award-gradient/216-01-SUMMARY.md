---
phase: 216-harness-foundation-award-gradient
plan: "01"
subsystem: ci-harness
tags: [ci, gitignore, deps, merge-base, playwright]
dependency_graph:
  requires: []
  provides:
    - parse5 + cheerio installed in playwright subproject
    - .gitignore coverage for ephemeral eval bundles
    - ci.yml id:base step emits merge-base SHA (shared by all down-ratchet guards)
  affects:
    - .github/workflows/ci.yml (fast_checks lane, all --base consumers)
    - test/example/priv/playwright/package.json + package-lock.json
    - .gitignore
tech_stack:
  added:
    - parse5 ^8.0.1 (playwright subproject devDep — HTML parser for canonicalize.ts)
    - cheerio ^1.2.0 (playwright subproject devDep — HTML traversal for evidence-anchor-check.mjs)
  patterns:
    - ci.yml id:base merge-base pattern (D-10) — all --base consumers now compare against true fork point
key_files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - .gitignore
    - test/example/priv/playwright/package.json
    - test/example/priv/playwright/package-lock.json
decisions:
  - parse5 pinned to ^8.0.1 (current 8.x) — human approved NOT downgrading to 7.x
  - cheerio pinned to ^1.2.0 — human approved at current 1.2.0
  - ci.yml id:base PR branch drops --depth=1 and computes merge-base; else (push) branch HEAD~1 unchanged
  - pre-existing --depth=1 at install_golden_contract detect step L147 left untouched — different job, different context, out of scope per plan task 4
metrics:
  duration: 144s
  completed: "2026-07-03"
  tasks_completed: 3
  tasks_total: 4
  files_modified: 4
status: complete
---

# Phase 216 Plan 01: Harness Foundation (Dependencies + Gitignore + Base-Ref Fix) Summary

Installed parse5 8.0.1 + cheerio 1.2.0 as human-verified devDependencies in the playwright subproject; added three gitignore entries to prevent ephemeral eval bundles from being committed; and fixed the shared `ci.yml` `id: base` step to emit the merge-base SHA instead of the base-branch tip — correctly re-pointing all existing `--base` consumers (snapshot-canary x2, quality-ledger-monotonic) and the new Phase 216 guards at once.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Human verify parse5 + cheerio legitimacy (checkpoint) | (prior agent — no commit) | — |
| 2 | Install parse5 ^8.0.1 + cheerio ^1.2.0 | a8af6464 | package.json, package-lock.json |
| 3 | Add .gitignore entries for eval bundles | 5c587ac9 | .gitignore |
| 4 | Fix ci.yml id:base to emit merge-base (D-10) | b2a8565a | .github/workflows/ci.yml |

## Verification Results

- `npm ls parse5 cheerio @axe-core/playwright @playwright/test --depth=0`: all 4 packages resolved, 0 missing, 0 extraneous, 0 vulnerabilities
- `.gitignore` grep -qxF: all 3 exact subproject paths confirmed present
- `ci.yml`: `git merge-base` present, YAML parses clean via python3 yaml.safe_load
- `quality-ledger-monotonic.test.sh`: 6/6 tests pass (existing guard unaffected by base-ref change)

## Deviations from Plan

### Minor: Pre-existing --depth=1 in install_golden_contract

The plan's verification command `! grep -qE 'git fetch origin.*--depth=1' .github/workflows/ci.yml` would fail because a pre-existing `--depth=1` at line 147 (in the `install_golden_contract` job's `Detect installer-related changes` step) is unrelated to the `id: base` step. This grep was too broad. The `id: base` step was corrected exactly as planned — the other `--depth=1` is in a different job, fetching the base branch for a three-dot diff, and is out of scope per the task definition ("Change ONLY the `id: base` step"). No fix applied to the unrelated step; deviation documented here.

### Task 2: parse5 pinned to ^8.0.1 (not 7.x)

The plan body said "parse5 ^7.x, cheerio ^1.x per RESEARCH" but the human's resume signal explicitly said "install parse5 pinned to ^8.0.1 (current latest)" and "Do NOT downgrade parse5 to 7.x." The checkpoint resolution overrides the plan body. parse5 8.x is the npm current-latest and is what the prior agent verified from the live registry (v8.0.1). Installed at ^8.0.1 as directed.

## Known Stubs

None — no stubs introduced in this plan. All files are configuration/dependency artifacts with no UI rendering.

## Threat Surface Scan

No new network endpoints, auth paths, or trust-boundary schema changes introduced. The two new npm packages (parse5, cheerio) are devDependencies of the playwright subproject only — they do not enter the Elixir library or generated host app. All three threats from the plan's threat model are mitigated:

- T-216-01-SC: human legitimacy gate satisfied (npm view + human approval)
- T-216-01-BASE: merge-base emit verified (grep + YAML parse)
- T-216-01-IGN: gitignore paths confirmed (grep -qxF)

## Self-Check: PASSED

- [x] test/example/priv/playwright/package.json — modified with parse5 + cheerio entries
- [x] test/example/priv/playwright/package-lock.json — updated lockfile committed
- [x] .gitignore — 3 new entries confirmed by grep
- [x] .github/workflows/ci.yml — merge-base present, YAML valid
- [x] commit a8af6464 exists: feat(216-01) parse5 + cheerio
- [x] commit 5c587ac9 exists: chore(216-01) gitignore
- [x] commit b2a8565a exists: fix(216-01) ci.yml merge-base
