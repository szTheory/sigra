---
phase: 217-adversarial-panel-auto-fix-safety-rails
plan: "06"
subsystem: autofix-engine
tags: [autofix, fix-apply, safety-rails, tdd, hermetic-test, sc-4, git-revert, token-swap, copy-swap]
dependency_graph:
  requires:
    - scripts/ci/fix-queue-build.mjs (Plan 02 — sole writer of open_findings; queue source)
    - guides/reference/fix-queue.json (Plan 02 — auto_eligible entries)
    - scripts/ci/quality-findings-monotonic.sh (Plan 02 dep — rail 1 guard)
    - scripts/ci/award-guard.mjs (Plan 04 dep — rail 2 guard)
    - scripts/ci/snapshot-canary-guard.sh (Plan 09 dep — rail 4 guard)
    - scripts/ci/settled-findings-lint.sh (Plan 01 dep — settled findings writer)
    - test/example/priv/playwright/lib/eval/probes.ts (onScale/nearest logic reference)
    - scripts/panel/judge.mjs (Plan 05 — LLM panel, upstream of autofix)
  provides:
    - scripts/panel/fix-apply.mjs
    - scripts/panel/fix-apply.test.mjs
    - scripts/panel/copy-rules.json
    - scripts/ci/admin-autofix-loop.sh
    - scripts/ci/admin-autofix-loop.test.sh
    - test/example/lib/example_web/live/admin/design_gallery_live.ex (board-autofix-seed fixture added)
  affects:
    - .github/workflows/ci.yml (fast_checks: fix-apply.test + admin-autofix-loop.test added)
    - .gitignore (eval/autofix-state.json excluded)
tech_stack:
  added: []
  patterns:
    - "TDD RED/GREEN for fix-apply.mjs (Task 1)"
    - "Token-swap: nearest token in +/-1.0px band (tighter than probe 0.5px detection); deterministic arithmetic; no model text"
    - "Copy-swap: fixed copy-rules.json ruleset; text-node-only edit; semantic judgment refused"
    - "apply surface: admin LiveView .heex/.ex + test/example only; CSS and component/judgment refused"
    - "git revert --no-edit HEAD (new commit) — NEVER reset/force-push/admin-merge"
    - "FOUR rails: monotonic count (rail 1), award-band floor (rail 2), gate/anchor flip (rail 3), PNG drift (rail 4)"
    - "Poison-set (eval/autofix-state.json, gitignored) + settled-findings.tsv for never-retry"
    - "mktemp-hermetic SC-4 test (quality-findings-monotonic.test.sh idiom)"
    - "realpathSync CLI detection fix for macOS /var→/private/var symlinks"
    - "Grep hygiene: loop basename assembled via shell variable (panel-ci-isolation convention)"
key_files:
  created:
    - scripts/panel/fix-apply.mjs
    - scripts/panel/fix-apply.test.mjs
    - scripts/panel/copy-rules.json
    - scripts/ci/admin-autofix-loop.sh
    - scripts/ci/admin-autofix-loop.test.sh
  modified:
    - test/example/lib/example_web/live/admin/design_gallery_live.ex (board-autofix-seed fixture)
    - .github/workflows/ci.yml (fix-apply.test + admin-autofix-loop.test in fast_checks)
    - .gitignore (eval/autofix-state.json)
decisions:
  - "Token-swap band tightened to +/-1.0px (vs probe +/-0.5px detection): confident mapping, ties downgrade to judgment"
  - "Copy-swap is text-node-only from copy-rules.json fixed ruleset; free-form/semantic edit routes to judgment"
  - "apply surface confined to admin LiveView .heex/.ex + test/example; CSS files and component/judgment refused (3-lockstep sigra_admin.css out of scope)"
  - "git revert --no-edit HEAD = new commit (not reset/force-push); hermetic test asserts Revert subject + clean reflog"
  - "Rail 4 (snapshot-canary-guard.sh --base pre-loop-sha) closes the gap where a .heex fix passes the loop but fails fast_checks on the PR"
  - "SC-4 proves rail 1 via mktemp count-delta seed; rail 4 proven by Task-2 grep + board-autofix-seed live companion"
  - "eval/autofix-state.json gitignored (operator/nightly tool state — never committed)"
  - "admin-autofix-loop.sh NEVER wired into CI; panel-ci-isolation.test.sh proves it"
  - "realpathSync used for CLI detection to handle macOS /var→/private/var symlink resolution"
metrics:
  duration: "15m 14s"
  completed: "2026-07-04T19:08:35Z"
  tasks_completed: 3
  files_created: 5
  files_modified: 3
status: complete
---

# Phase 217 Plan 06: Auto-Fix Safety Rails (fix-apply + loop + SC-4) Summary

Deterministic auto-fix engine built: `fix-apply.mjs` applies only copy/token swaps to admin .heex/inline-style + example (LLM strictly out of apply path); `admin-autofix-loop.sh` commits one fix per commit, re-renders, and auto-reverts via `git revert --no-edit HEAD` if any of FOUR rails trips; SC-4 hermetic test proves both rails fire.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| T1 | fix-apply.mjs + copy-rules.json (TDD GREEN — 39/39 PASS) | 054edefd | scripts/panel/fix-apply.mjs, scripts/panel/fix-apply.test.mjs, scripts/panel/copy-rules.json |
| T2 | admin-autofix-loop.sh — 4 rails + revert + poison-set | 0054a630 | scripts/ci/admin-autofix-loop.sh, .gitignore |
| T3 | board-autofix-seed fixture + admin-autofix-loop.test.sh (SC-4) | 73696a7e | test/example/.../design_gallery_live.ex, scripts/ci/admin-autofix-loop.test.sh, scripts/panel/fix-apply.mjs (CLI fix), .github/workflows/ci.yml |

## Verification Results

All plan verification criteria pass:

- `node scripts/panel/fix-apply.test.mjs` — 39/39 PASS
  - Test 1: token swap within +/-1.0px band applied; var() reference emitted
  - Test 2: tie (equidistant tokens) → NOT applied (downgraded to judgment)
  - Test 3: nearest >1.0px away → NOT applied (downgraded to judgment)
  - Test 4: auto_eligible=false → refused
  - Test 5: copy-swap sentence-case normalization applied as text-node-only
  - Test 6: unmatched content unchanged (judgment boundary respected)
  - Test 7: CSS file not in apply surface (refused)
  - Test 8: fix_class=component and fix_class=judgment refused; token/copy allowed
  - Test 9: !important preserved after token swap
  - Test 10: findNearestToken unit tests (8 cases — exact, within-band, edge, outside, tie, empty, single-far, single-near)
- `bash -n scripts/ci/admin-autofix-loop.sh` — syntax clean
- `grep -q 'git revert --no-edit' ...` — PASS
- `grep -q 'snapshot-canary-guard.sh' ...` — PASS (rail 4 wired)
- `! grep -q 'git reset --hard|--force|push --force' ...` — PASS (no unsafe git)
- `bash scripts/ci/admin-autofix-loop.test.sh` — 9/9 PASS
  - Test A-i-a: Revert commit exists (git log shows `Revert "autofix(...)` subject)
  - Test A-i-b: reflog clean (no force-push / reset --hard)
  - Test A-i-c: open_findings restored to 3 after revert
  - Test A-ii-a: quality-findings-monotonic.sh exits non-zero on 3→4 increase
  - Test A-ii-b: stderr contains 'open findings increased' (causal link)
  - Test B: settled-findings-lint.sh passes after loop run (1 row, sorted, 7-column)
  - Test C: loop reports 0 eligible findings on re-run (poison-set effective)
  - Test C-settled: finding in settled-findings.tsv
  - Test C-disposition: disposition=waived confirmed
- `bash scripts/ci/panel-ci-isolation.test.sh` — 3/3 PASS (loop not wired into CI)
- `eval/autofix-state.json` — gitignored (confirmed via `git check-ignore`)

## Must-Haves Status

| Truth | Status |
|-------|--------|
| fix-apply.mjs auto-applies ONLY copy-swap and token-swap classes, to admin LiveView .heex/.ex + example only | PASS — surface patterns enforced; CSS refused |
| Token-swap reuses probe onScale/nearest logic; +/-1.0px band; !important preserved; ties/>1.0px downgrade to judgment | PASS — 39 tests |
| Copy-swap is text-node-only edit from fixed copy-rules.json; semantic judgment refused | PASS — 39 tests |
| Loop commits one fix per commit and auto-reverts via git revert --no-edit HEAD | PASS — SC-4 proves it |
| Rail 4 = snapshot-canary-guard.sh --base pre-loop-sha (baseline-PNG drift) | PASS — wired; grep verified |
| Reverted finding written to settled-findings.tsv (waived, autofix-217) + gitignored poison-set | PASS — SC-4 proves it |
| Hermetic SC-4 test proves BOTH rails fire AND quality-findings-monotonic.sh exits non-zero on pre-revert commit | PASS — 9/9 |
| admin-autofix-loop.sh never wired into any CI lane | PASS — panel-ci-isolation.test.sh proves it |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] CLI detection fails on macOS /var→/private/var symlink**
- **Found during:** Task 3 debugging — fix-apply.mjs ran with exit 0 but produced no output and made no file changes when invoked from a tmp repo on macOS
- **Issue:** `process.argv[1] === fileURLToPath(import.meta.url)` compares unresolved paths; macOS resolves `mktemp` dirs under `/var/folders/...` but `import.meta.url` has the realpath `/private/var/folders/...` — the check evaluates false and the CLI block is silently skipped
- **Fix:** Added `isMainModule()` helper using `realpathSync` for both sides of the comparison; falls back to string equality on error
- **Files modified:** `scripts/panel/fix-apply.mjs`
- **Commit:** 73696a7e

**2. [Rule 1 - Bug] Test assertion checked wrong token name (xs vs sm for index 1)**
- **Found during:** Task 1 TDD GREEN — test 1b asserted `var(--sg-radius-xs)` but scale_px=[2,4,6,8] maps index 1 (value=4) to `--sg-radius-sm` (xs=index 0)
- **Fix:** Updated test assertion to `var(--sg-radius-sm)` with explanatory comment
- **Files modified:** `scripts/panel/fix-apply.test.mjs`
- **Commit:** 054edefd (correction inline)

**3. [Rule 1 - Bug] Test C double-add attempt after Test A already settled the finding**
- **Found during:** Task 3 test run — `settled-findings-lint.sh --add` failed with "finding_id already exists" because the loop in Test A had already added the finding
- **Fix:** Added idempotent guard in Test C: check if finding already in settled-findings.tsv before attempting to add
- **Files modified:** `scripts/ci/admin-autofix-loop.test.sh`
- **Commit:** 73696a7e (correction inline)

**4. [Rule 2 - Auto-add] SC-4 scope clarification: rail 4 tested by grep, not hermetic fixture**
- **Found during:** Task 3 design — rail 4 (snapshot-canary-guard.sh baseline-PNG drift) cannot be cheaply hermetic-tested (would require committed PNGs + real render diff + snapshot-allowlist fixture)
- **Decision:** SC-4 proves rail 1 (count-monotonic) via the mktemp count-delta seed. Rail 4 is proven by: (a) Task-2 `<verify>` grep asserting `snapshot-canary-guard.sh` is wired into the loop, (b) board-autofix-seed live companion that exercises the real admin render path. This matches the plan's scope note exactly.

## Known Stubs

None. All components are fully implemented:
- `fix-apply.mjs`: complete deterministic token-swap + copy-swap engine with CLI + exported pure functions
- `copy-rules.json`: 5 deterministic normalization rules (sentence-case, title-case, terminal-period, em-dash, ellipsis)
- `admin-autofix-loop.sh`: complete loop with all FOUR rails, poison-set, settled-findings.tsv write, resumable + idempotent
- `admin-autofix-loop.test.sh`: hermetic SC-4 proof (9/9 PASS)
- `board-autofix-seed`: live fixture in design_gallery_live.ex

## Threat Surface Scan

All STRIDE mitigations from the plan implemented:

| Threat | Mitigation Status |
|--------|-------------------|
| T-217-06-UNSAFE: unbounded edit | MITIGATED — only copy+token auto-apply; CSS/component/judgment refused; --max-fixes bounds runs; no model text reaches source |
| T-217-06-PNGDRIFT: .heex fix perturbs committed baseline PNG | MITIGATED — rail 4: snapshot-canary-guard.sh --base pre-loop-sha wired into loop; on drift → git revert + waive + poison |
| T-217-06-HISTORY: forged history / bypass ruleset | MITIGATED — git revert --no-edit = new commit; SC-4 asserts Revert subject + clean reflog; no reset/force-push (negative grep verified) |
| T-217-06-LOOP: endless retry on poison finding | MITIGATED — reverted findings enter poison-set + settled-findings.tsv; loop skips them (SC-4 Test C proves it) |
| T-217-06-JUDGE: loop wired into CI gate | MITIGATED — loop stays OFF merge path; panel-ci-isolation.test.sh proves no run: step invokes it |

## Self-Check: PASSED

| Check | Result |
|-------|--------|
| scripts/panel/fix-apply.mjs | FOUND |
| scripts/panel/fix-apply.test.mjs | FOUND |
| scripts/panel/copy-rules.json | FOUND |
| scripts/ci/admin-autofix-loop.sh | FOUND |
| scripts/ci/admin-autofix-loop.test.sh | FOUND |
| board-autofix-seed in design_gallery_live.ex | FOUND |
| commit 054edefd (T1: fix-apply + copy-rules) | FOUND |
| commit 0054a630 (T2: admin-autofix-loop.sh) | FOUND |
| commit 73696a7e (T3: board-autofix-seed + test) | FOUND |
