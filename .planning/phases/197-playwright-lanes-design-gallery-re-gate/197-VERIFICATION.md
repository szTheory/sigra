---
phase: 197-playwright-lanes-design-gallery-re-gate
verified: 2026-06-20T21:00:00Z
status: human_needed
score: 4/4
behavior_unverified: 0
overrides_applied: 0
human_verification:
  - test: "Trigger a non-PR CI run (push to main or workflow_dispatch) and confirm admin_design_recapture job runs, recaptures all 72 admin-design PNGs on ubuntu, passes snapshot-canary-guard, and opens a reviewable PR on a ci/recapture-admin-design-<run_id> branch"
    expected: "A PR appears targeting main with the recaptured ubuntu-native admin-design PNGs. The board-notice canary is re-established as 'added' (not 'modified'). Canary guard passes. Once that PR is merged, the example_playwright_smoke design-gallery step runs green on CI."
    why_human: "The admin_design_recapture job only runs on non-PR events (github.event_name != 'pull_request'). Its correctness — including the OQ1 canary re-baseline, OQ2 PR commit, and OQ3 cross-lane drift measurement — can only be observed in a live CI run. No local probe can substitute."
  - test: "After the recapture PR is merged, open a new PR against main and observe the example_playwright_smoke 'Run design gallery boards' step"
    expected: "The design gallery step runs green (hard-gates — no continue-on-error). If it goes red, the aggregator 'Aggregate Playwright step outcomes' also goes red and the PR is blocked. Success criterion #3 and #4 require a live CI run to prove the full end-to-end path."
    why_human: "This is the 'CI measures itself' verification mechanism explicitly called out by the phase context. The re-gate and the baselines cannot be verified as green without a real CI run against ubuntu with the committed woff2 and font-loaded baselines."
---

# Phase 197: Playwright Lanes + Design Gallery Re-gate — Verification Report

**Phase Goal:** The Playwright critical path is shorter and an early failure no longer masks later steps; browser readiness is deterministic; and the demoted `continue-on-error` admin-design gallery is a hard gate again because its font-reflow height delta is fixed.

**Verified:** 2026-06-20T21:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Playwright lane surfaces independent step failures in a single run; early failure no longer masks later steps | VERIFIED | All 5 `npx playwright test` steps carry `id:` + `if: ${{ !cancelled() }}` (confirmed: 5 occurrences at lines 974, 994, 1032, 1058, 1078 in ci.yml). `grep -cE 'if: \$\{\{ !cancelled\(\) \}\}'` returns 5. An `if: always()` aggregator step at line 1088 iterates all 5 step outcomes and exits 1 if any equals `failure`, preserving the hard gate. |
| 2 | Criterion 1b (critical-path time reduction) — honestly modest/near-zero | VERIFIED | Plan 02 explicitly documents that webkit cannot be dropped (three mobile projects use iPhone 13), the 5 launches are serial-by-design (workers:1), and the real win is reliability not wall-clock. As instructed in the phase context, this is NOT treated as a failure — the mechanism (aggregator) is the deliverable. |
| 3 | No `Process.sleep`-based / `waitForTimeout` readiness remains in browser lanes | VERIFIED | `grep -rn 'waitForTimeout' test/example/priv/playwright/tests/` returns nothing. Both `extractInvitationLink` helpers in `organizations.spec.ts` (lines 115-163) and `ga-uat-shift-left.spec.ts` (lines 74-118) use `expect.poll()` with `intervals: [250, 500, 1000]` and `timeout: 30_000`. No fixed sleep introduced. |
| 4 | `admin-design.spec.ts` awaits `document.fonts.ready` and asserts the face loaded; brand webfont self-hosted | VERIFIED | `waitForLiveViewReady` in `admin-design.spec.ts` lines 23-25: awaits `document.fonts.ready` then asserts `document.fonts.check('16px "Space Grotesk"')`. `space-grotesk-var.woff2` exists at `test/example/priv/static/assets/fonts/` (49 KB, verified `wOF2` magic bytes). `app.css` lines 2516-2526 declare `@font-face` pointing to `/assets/fonts/space-grotesk-var.woff2` and override `:root { --font-sans: 'Space Grotesk', ... }`. |
| 5 | `continue-on-error: true` removed from the design-gallery step; gallery hard-gates again | VERIFIED | The "Run design gallery boards" step at ci.yml lines 1031-1056 carries `id: design_gallery` + `if: ${{ !cancelled() }}` and has NO `continue-on-error` key. The step comment (lines 1038-1050) contains the corrected D-07 explanation. The remaining `continue-on-error: true` at line 1592 is in the separate `admin_design_recapture` job's OQ3 cross-lane compare step — not the PR-gating lane. |
| 6 | MG-5/6 `test.fail()` replaced with `test.skip()` with recorded reason | VERIFIED | `grep -n 'test\.fail()' admin-design.spec.ts` returns nothing. Line 328 shows `test.skip('data-dependent pagination across /admin/audit + first-listed-user audit page; no seeded user reaches the >=25-event @default_limit threshold — tracked in .planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md')`. The referenced todo file exists. |
| 7 | `admin_design_recapture` sibling CI job exists, non-PR-gated, job-level `contents: write` | VERIFIED | ci.yml lines 1381-1665: job `admin_design_recapture` with `if: github.event_name != 'pull_request'`, `needs: release_ref_guard`, and job-level `permissions: { contents: write, pull-requests: write }`. Workflow-level `permissions: contents: read` at line 27 is unchanged. Recapture step runs `--update-snapshots` across all 3 admin-design projects. OQ1 (board-notice canary as `added`), OQ2 (ci/recapture-* branch + gh pr create), OQ3 (cross-lane compare-mode) all implemented. |
| 8 | SEED-006 records root-cause correction | VERIFIED | `SEED-006-admin-design-gallery-ci-baseline-recapture.md` lines 76-139 contain an explicit "Root-cause correction (Phase 197, D-07)" section stating the original "brand webfont does not load in CI" premise was factually wrong, identifies the OS system-ui metric delta as the real cause, documents the Phase 197 remediation, and marks the seed as "ADDRESSED / FOLDED". |

**Score:** 4/4 truths verified (all 8 observable truths above satisfy the 4 success criteria)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `test/example/priv/playwright/tests/organizations.spec.ts` | expect.poll mailbox readiness, no waitForTimeout | VERIFIED | Lines 115-163: `expect.poll()` with closure `let link`, intervals, timeout. `waitForTimeout` absent. |
| `test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts` | expect.poll mailbox readiness, no waitForTimeout | VERIFIED | Lines 74-118: identical transformation applied. `waitForTimeout` absent. |
| `test/example/priv/static/assets/fonts/space-grotesk-var.woff2` | self-hosted brand font, wOF2 magic | VERIFIED | 49364 bytes, `wOF2` magic confirmed via xxd. Converted from in-repo OFL SpaceGrotesk TTF. |
| `test/example/priv/static/assets/css/app.css` | @font-face + --font-sans override | VERIFIED | Lines 2511-2526: `@font-face` for `'Space Grotesk'` + `:root { --font-sans: 'Space Grotesk', ... }`. Confirmed by grep. |
| `test/example/priv/playwright/tests/admin-design.spec.ts` | fonts.ready + fonts.check + no test.fail() | VERIFIED | Lines 23-25: `fonts.ready` + `fonts.check` hard guard. Line 328: `test.skip`. No `test.fail()`. |
| `.github/workflows/ci.yml` | Guarded + aggregated seams, no design-gallery continue-on-error, admin_design_recapture job | VERIFIED | 5 guarded steps with ids. Aggregator at line 1088. Design gallery step has no `continue-on-error`. `admin_design_recapture` job at line 1381. YAML valid (python3 yaml.safe_load confirmed). |
| `.planning/seeds/SEED-006-admin-design-gallery-ci-baseline-recapture.md` | Root-cause correction recorded | VERIFIED | Lines 76-139 contain the explicit correction section with D-07 root cause, remediation, and "ADDRESSED / FOLDED" status. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| ci.yml aggregator step | all 5 guarded step ids | `steps.<id>.outcome` iteration | VERIFIED | Lines 1097-1101: all 5 outcomes iterated: `admin_behavior`, `admin_checkpoints`, `design_gallery`, `non_admin_smoke`, `demo_showcase` |
| ci.yml design_gallery step | aggregator | `steps.design_gallery.outcome` read by aggregator | VERIFIED | `design_gallery` id at line 1032; aggregator reads it at line 1099. No `continue-on-error` on the step — failure now reaches the aggregator. |
| app.css @font-face | `space-grotesk-var.woff2` | `src: url('/assets/fonts/space-grotesk-var.woff2') format('woff2-variations')` | VERIFIED | Line 2518 of app.css exactly matches. File exists at expected path. |
| admin-design.spec.ts | browser font loading | `await document.fonts.ready` + `fonts.check('16px "Space Grotesk"')` | VERIFIED | Lines 23-25 of `waitForLiveViewReady`. Patterns `fonts.ready` and `fonts.check` confirmed by grep. |
| ci.yml Stage admin checkpoint PNGs | admin_checkpoints step outcome | `if: ${{ steps.admin_checkpoints.outcome == 'success' }}` | VERIFIED | Line 1019: guard changed from `success()` to seam-specific outcome. Pitfall 4 resolved. |
| admin_design_recapture job | snapshot-canary-guard.sh | `bash scripts/ci/snapshot-canary-guard.sh --canary board-notice --allow <slugs>` | VERIFIED | Lines 1555-1559: canary guard invoked with `--canary board-notice` and per-slug `--allow` args. |

### Data-Flow Trace (Level 4)

Not applicable — this phase modifies CI workflow YAML and test infrastructure, not components rendering dynamic data from a database.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| No `waitForTimeout` in browser test files | `grep -rn 'waitForTimeout' test/example/priv/playwright/tests/` | (no output) | PASS |
| woff2 has correct magic bytes | `head -c4 space-grotesk-var.woff2 \| xxd` | `wOF2` confirmed | PASS |
| ci.yml is valid YAML | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))"` | Exits 0 | PASS |
| `!cancelled()` guard count >= 5 | `grep -cE 'if: \$\{\{ !cancelled\(\) \}\}' ci.yml` | 5 | PASS |
| `test.fail()` absent from admin-design.spec.ts | `grep -c 'test\.fail()' admin-design.spec.ts` | 0 | PASS |
| `continue-on-error` absent from design_gallery step in example_playwright_smoke | Context search: only remaining `continue-on-error: true` is at line 1592 in `admin_design_recapture` job (OQ3 cross-lane compare — intentional per plan) | Not in design_gallery step | PASS |
| `admin_design_recapture` job not PR-gated | `grep -A3 'admin_design_recapture:' ci.yml \| grep 'pull_request'` | `if: github.event_name != 'pull_request'` | PASS |
| Global workflow permissions not widened | Lines 26-27: `permissions: { contents: read }` | Unchanged | PASS |
| MG-5/6 todo file exists at path referenced in skip | `ls .planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md` | EXISTS | PASS |

### Probe Execution

No conventional `scripts/*/tests/probe-*.sh` files declared or applicable. YAML validity and grep-based spot-checks substituted per Step 7b.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| PW-01 | 197-02 | Reduce critical path; early failure no longer masks later steps | SATISFIED | 5 guarded steps + aggregator. Criterion 1b honestly modest (webkit non-droppable, serial design). |
| PW-02 | 197-01 | Deterministic readiness; no `Process.sleep`-based waits | SATISFIED | Both `waitForTimeout` mailbox loops replaced with `expect.poll()`. Zero `waitForTimeout` in test tree. |
| PW-03 | 197-03, 197-04, 197-05 | Re-gate admin-design gallery; brand webfont loads in CI; baselines recaptured | SATISFIED (mechanism) | woff2 committed + @font-face wired + fonts.ready guard + `admin_design_recapture` job + `continue-on-error` removed. Runtime-green proof requires a live CI run (CI-deferred per phase context). |

All three requirement IDs (PW-01, PW-02, PW-03) declared across plans are traced to REQUIREMENTS.md lines 31-33 where they are listed as `[x]` (marked complete) under the Phase 197 row.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| ci.yml | 1592 | `continue-on-error: true` | Info | This occurrence is in the `admin_design_recapture` job's OQ3 cross-lane compare step — correctly intentional. The plan explicitly prescribes `continue-on-error: true` here so a font-driven compare failure does not block the recapture PR commit (the deliverable). Not a blocker. |

No unreferenced `TBD`, `FIXME`, or `XXX` markers found in any file modified by this phase.

### Human Verification Required

#### 1. admin_design_recapture Non-PR CI Run

**Test:** Trigger a non-PR CI event (push to main, workflow_dispatch, or merge a branch) and observe the `admin_design_recapture` job in GitHub Actions.

**Expected:** The job runs, boots the example app on ubuntu, recaptures all 72 admin-design PNGs with `--update-snapshots`, executes `snapshot-canary-guard.sh` with `--canary board-notice` and per-slug `--allow` args, deletes existing board-notice PNGs first so the guard sees them as `added` (OQ1), commits to a `ci/recapture-admin-design-<run_id>` branch, and opens a reviewable PR via `gh pr create` (OQ2).

**Why human:** The job has `if: github.event_name != 'pull_request'` — it cannot be triggered by or observed in a PR. Only a live non-PR CI run can confirm the OQ1/OQ2/OQ3 logic executes correctly. The committed woff2 must load in the ubuntu runner and the `fonts.check` hard guard must pass before any baseline is captured — this requires a real browser invocation on CI infrastructure.

#### 2. Design Gallery Hard Gate (Post Recapture)

**Test:** After the recapture PR is merged, open a new PR against main and observe the `example_playwright_smoke` job's "Run design gallery boards" step.

**Expected:** The step runs green (CI-native ubuntu baselines now match CI render). The aggregator step at "Aggregate Playwright step outcomes" reads `steps.design_gallery.outcome == 'success'` and passes. The PR is not blocked by the gallery step. If a visual regression is introduced in a future PR, the gallery step goes red, the aggregator exits 1, and the PR is blocked — confirming the hard gate is active.

**Why human:** The "CI measures itself" verification mechanism stated in the phase context. The baselines were captured on macOS; the recapture job must run in CI to establish ubuntu-native baselines. The re-gate can only be proven green by a CI run against those baselines. Grep checks confirm the mechanism is correctly in place; the runtime outcome requires a live run.

### Gaps Summary

No gaps found. All mechanisms verified in the committed codebase:

- PW-01: 5 guarded seams + aggregator — VERIFIED
- PW-02: zero `waitForTimeout` + `expect.poll()` in both spec files — VERIFIED
- PW-03 foundation: woff2 committed, @font-face wired, `fonts.ready` + `fonts.check` hard guard, `test.fail()` removed — VERIFIED
- PW-03 recapture: `admin_design_recapture` job present, non-PR-gated, OQ1/OQ2/OQ3 addressed — VERIFIED
- PW-03 re-gate: `continue-on-error` absent from design_gallery step, aggregator reads its outcome — VERIFIED
- SEED-006: root-cause correction written, seed marked addressed/folded — VERIFIED

The two human verification items are CI-deferred checks, not gaps. The phase context explicitly calls out that "where a criterion's final proof requires a live CI run... verify that the MECHANISM is correctly in place... and classify the runtime-green confirmation as a CI-deferred check rather than a local gap."

---

_Verified: 2026-06-20T21:00:00Z_
_Verifier: Claude (gsd-verifier)_
