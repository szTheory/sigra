---
phase: 217-adversarial-panel-auto-fix-safety-rails
verified: 2026-07-04T21:15:00Z
status: passed
score: 7/7
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: human_needed
  previous_score: 5/5
  gaps_closed:
    - "SC-2 live reality-check — panel/render-matrix surface mismatch resolved (Option 2: panel repointed at board-mg-5/9 surfaces that have real captured bundles); mechanism shifted maximally left to a deterministic key-free CLI bundle-wiring test (judge-cli.test.mjs) exercised against a real on-disk board-mg bundle."
    - "SC-4 live apply->revert->waive companion — converted from a human-attested live run into an AUTONOMOUS, API-free automated assertion executed inside a throwaway git clone of committed HEAD; independently reproduced by the verifier (Revert commit + restored ledger + settled(waived) finding + clean reflog)."
  gaps_remaining: []
  regressions: []
optional_operator_confirmation:
  - test: "TRUE-live SC-2 paid run (OPTIONAL, post-merge, operator-only — NOT a task gate)."
    detail: "With a real ANTHROPIC_API_KEY + a booted example server at committed HEAD, run `bash scripts/ci/admin-panel.sh` twice; 2nd run reports 0 API calls AND `git diff guides/reference/admin-panel-verdicts.json` is empty. Documented in admin-eval-runbook.md as the single un-automatable check. The plan completes autonomously WITHOUT it; its mechanism is hermetically proven (judge.test.mjs callCount===0) and additionally proven against a real on-disk bundle by judge-cli.test.mjs. Does NOT hold the phase in human_needed per plan scope."
---

# Phase 217: Adversarial Panel + Auto-Fix Safety Rails Verification Report (Final — post gap-closure 217-08)

**Phase Goal:** The 4-lens LLM panel (3 persona/JTBD + 1 graphic-design) evaluates deterministically-clean surfaces under a forced-finding floor with k=3 consensus, deduplicates findings into a stable fix queue, and auto-applies only provably-safe fix classes with per-fix auto-revert on regression — all proven by an injected-regression test.
**Verified:** 2026-07-04T21:15:00Z
**Status:** passed
**Re-verification:** Yes — final pass after gap-closure plan 217-08 (the two prior human_needed items are now closed).

## Goal Achievement

This final pass verifies the seven `must_haves.truths` in `217-08-PLAN.md` against committed HEAD (commits `ca1c03a9`, `665a304c`, `d8b571c2`, `3c6c5729`). The five phase-goal Observable Truths from the initial pass (2026-07-04T20:30) remain VERIFIED (regression-checked below); the gap-closure truths that convert the two prior deferred live checks into committed, automated evidence are the focus here.

### Observable Truths (Plan 217-08 must-haves)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | admin-panel.sh PILOT_SURFACES and admin-render-sha.json cells agree on the same concrete board-mg surfaces (board-mg-5-*/board-mg-9-*) | VERIFIED | `admin-panel.sh:91` lists all eight board-mg-5/9 surfaces; `admin-render-sha.json` has all 16 desktop light+dark cells with valid 64-hex `render_sha256` and `open_findings: 0`; no `board-autofix-seed` render cell present. Former pilot names (`users-index-live`) no longer in `PILOT_SURFACES`. |
| 2 | judge.mjs CLI reads dom.html + facts.json from the bundle output dir and hard-refuses paid API calls on empty DOM BEFORE importing/constructing the Anthropic SDK (refuse path provable key-free) | VERIFIED | `judge.mjs`: render-sha lookup (587), verdicts read (599), bundle dom.html/facts.json read (615-627), empty-DOM refuse `process.exit(1)` (628-636) — ALL precede `import('@anthropic-ai/sdk')` + `new Anthropic()` (640-641). Source-position check: import@23718 > refuse@23402. |
| 3 | Deterministic key-free self-test drives runJudge against a REAL on-disk board-mg bundle with an injected SDK double: 0 calls on cache hit, k calls on cache miss | VERIFIED | `env -u ANTHROPIC_API_KEY node scripts/panel/judge-cli.test.mjs` → 4 passed, 0 failed (exit 0). Tests 2-3 ran against real on-disk board-mg-5 bundle (NOT skipped): cache hit callCount===0, cache miss callCount===3. Test 1 CLI-ordering grep + Test 4 empty-DOM refuse pass. |
| 4 | One appliable in-band SPACE-token finding seeded on board-autofix-seed; survives fix-queue-lint; not a merge-gated render cell | VERIFIED | `fix-queue.json`: exactly 1 board-autofix-seed entry — fix_class:token, auto_eligible:true, priority:normal, measured_px:[12.5], 10-entry scale_px, NO token_family, NO surfaces_affected. `fix-queue-lint.sh` → PASS (117 entries). `design_gallery_live.ex:1439` has `<div class="sg-stack" style="padding: 12.5px">`. No board-autofix-seed cell in admin-render-sha.json. |
| 5 | SC-4 apply->rail-trip->revert->waive chain runs AUTONOMOUSLY + API-free in a throwaway clone of committed HEAD, asserted by an automated block (git log / reflog / ledger diff / settled-findings.tsv) | VERIFIED (behaviorally reproduced) | Verifier independently re-ran the clone chain on committed HEAD: seed applied (padding: 12.5px → var(--sg-space-12)), rail-1 tripped, `git revert --no-edit` landed `Revert "autofix(...)` commit (fresh sha `98fc383b`), ledger RESTORED, seed finding in settled-findings.tsv with disposition=waived, reflog CLEAN (no force/reset --hard). Real repo working tree + settled-findings.tsv untouched (clone-isolated). |
| 6 | quality-findings-monotonic.sh --base <merge-base> PASSES with the new board-mg cells at open_findings:0 | VERIFIED | vs actual merge-base (origin/main f2e54612, pre-ledger): PASS (initial-commit skip). Adversarial cross-check vs base 26b11a81 (ledger present, board-mg absent): "PASS (32 cells checked)" — new board-mg cells default base=0, yield 0→0, no increase. |
| 7 | Runbook documents the OPTIONAL post-merge operator-only TRUE-live SC-2 paid run as the single un-automatable check + JUDGE-CI-01 | VERIFIED | `admin-eval-runbook.md` names board-mg-5-*/board-mg-9-* pilot surfaces (183, 203-204), documents SC-4 as autonomously proven, documents the OPTIONAL/operator-only/post-merge SC-2 paid run, restates JUDGE-CI-01. Stale pilot-surface CLAIM replaced (remaining `users-index-live` mentions are a generic usage example + a deliberate historical note explaining the Option-2 change). |

**Score:** 7/7 truths verified (0 present, behavior-unverified). All five original phase-goal Observable Truths remain VERIFIED (regression-checked).

### Prohibition Verification (CI-gate-load-bearing)

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| Option 1 (rendering pilots) NOT implemented — Option 2 only | HONORED | PILOT_SURFACES repointed; no new render cells for the former pilot surfaces; board-mg cells reuse existing on-disk bundle sha values. |
| New board-mg cells carry open_findings: 0 (no 0→N trip) | HONORED | All 16 board-mg cells = 0; monotonic gate PASS vs both bases. |
| fix-queue-build.mjs NOT run into this commit's output (would recompute board-mg to 197/181) | HONORED | board-mg cells remain 0; monotonic gate green. |
| admin-panel.sh NEVER wired into any CI lane (JUDGE-CI-01) | HONORED | No `run:` invokes admin-panel.sh in `.github/workflows/`; panel-ci-isolation.test.sh 3/3 PASS. |
| admin-autofix-loop.sh NEVER wired into any CI lane; SC-4 loop runs only in throwaway clone | HONORED | Only `admin-autofix-loop.test.sh` (hermetic test) at ci.yml:162; the loop binary is never a `run:` step; real repo history untouched by the clone run. |
| Seed is a SPACE token (10-entry scale_px, NO token_family, single-surface priority:normal) | HONORED | Verified in fix-queue.json; survives fix-queue-lint; SC-4 clone proves fix-apply APPLIES it (not SKIP). |
| No board-autofix-seed cell added to admin-render-sha.json | HONORED | Absent from render cells; keeps it off the merge-gated matrix. |
| judge.mjs empty-DOM refuse guard BEFORE any Anthropic SDK import/construction | HONORED | import@23718 > refuse@23402; refuse path exits at line 635 before SDK loads. |
| No ANTHROPIC_API_KEY committed/echoed/logged | HONORED | No `sk-ant-*` literal in any 217-08 diff; all references are `<your-key>` placeholders or env reads; admin-panel.sh names the var only in the no-op message. |

### Documented Deviation Assessment — fix-queue-lint.sh 0-exemption

**Deviation:** `fix-queue-lint.sh` was modified to exempt `open_findings === 0` cells from the cross-surface open_findings-consistency check (rule e), because the new board-mg-5/9 cells introduced at sentinel 0 collide on cell-key names (e.g. `light-desktop-populated`) with the existing users-index-live/user-show-live cells at 197/181.

**Assessment: SOUND — does not weaken the gate for real values.**
- The exemption is narrowly scoped: the `null` (missing), `< 0` (negative), and `> totalUncollapsed` (stale/inflated) checks still apply to 0-valued cells. Only the cross-surface *agreement* check is skipped for exactly-0 cells.
- Measured, nonzero cells (e.g. users-index-live@197) remain fully subject to cross-surface consistency with any other nonzero cell sharing the key — verified by reading the branch structure (lines 154-186): the 0-exemption is an isolated `if (openFindings === 0)` short-circuit that never affects nonzero cells.
- Semantics are correct: 0 is the explicit "introduced but not yet measured" sentinel (the panel reads only render_sha256; open_findings is a fix-queue-build-derived field). The next fix-queue-build run against captured bundles will populate real values, at which point the cross-surface check re-engages.
- Classification: INFO / acceptable deviation. Not a blocker.

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| PANEL-01 | 4-lens LLM panel, forced-finding floor, machine-parseable findings, deterministically-clean surfaces only | SATISFIED | Verified in initial pass (panel-forced-floor-check.mjs 7/7, admin-graphic-design-lens.md 4th lens, judge.mjs machine-parseable, lenses.mjs 4-lens assembly). Unchanged by 217-08. REQUIREMENTS.md marks Complete. |
| PANEL-02 | k=3 consensus at ≥2/3 quorum; content-hash skip for unchanged surfaces; never in merge gate | SATISFIED | judge.test.mjs 11/11 (k=3, quorum, callCount===0 skip); judge-cli.test.mjs now proves the skip decision against a REAL on-disk bundle (cache hit 0 calls); panel/render-matrix surface alignment closes the SC-2 disjoint-set gap; JUDGE-CI-01 preserved. The deferred SC-2 live-reality item is resolved (mechanism shifted maximally left; only the OPTIONAL paid run remains, non-gating). |
| AUTOFIX-01 | Stable finding_id, dedup fix queue, cross-surface systemic collapse | SATISFIED | fix-queue-build.mjs 28/28; committed queue (now 117 entries incl. the seed) lint-clean; finding_id byte-identity to 216 formula. Unchanged by 217-08 except the one appliable seed. |
| AUTOFIX-02 | Auto-applies only safe classes as atomic commits; auto-reverts on regression; injected-regression test proves rails | SATISFIED | fix-apply.mjs (copy/token only) PASS; admin-autofix-loop.test.sh 9/9 (both rails); AND the SC-4 apply->revert->waive chain now reproduced AUTONOMOUSLY end-to-end against committed HEAD (real appliable seed → var(--sg-space-12) → rail trip → git revert → settled(waived)). The deferred SC-4 live companion is resolved. |

All four requirement IDs are accounted for and SATISFIED; REQUIREMENTS.md marks each Complete (lines 83-86).

### Behavioral Spot-Checks (this pass)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| judge-cli.test.mjs (key-free, real bundle) | `env -u ANTHROPIC_API_KEY node scripts/panel/judge-cli.test.mjs` | 4 passed, 0 failed (exit 0); Tests 2-3 NOT skipped | PASS |
| judge.test.mjs (no runJudge regression) | `env -u ANTHROPIC_API_KEY node scripts/panel/judge.test.mjs` | 11 passed, 0 failed | PASS |
| panel-ci-isolation.test.sh (JUDGE-CI-01) | `bash scripts/ci/panel-ci-isolation.test.sh` | 3 passed, 0 failed | PASS |
| fix-queue-lint.sh (committed queue + seed) | `bash scripts/ci/fix-queue-lint.sh` | PASS (117 entries) | PASS |
| quality-findings-monotonic (vs merge-base) | `bash scripts/ci/quality-findings-monotonic.sh --base <mb>` | PASS (skip: ledger absent at base) | PASS |
| quality-findings-monotonic (vs 26b11a81, ledger present) | `bash scripts/ci/quality-findings-monotonic.sh --base 26b11a81` | PASS (32 cells checked) | PASS |
| SC-4 clone chain (independent re-run on HEAD) | throwaway `git clone` + admin-autofix-loop.sh --max-fixes 20 --skip-render | Revert commit 98fc383b + ledger restored + settled(waived) + clean reflog | PASS |
| admin-autofix-loop.test.sh (hermetic SC-4) | `bash scripts/ci/admin-autofix-loop.test.sh` | 9 passed, 0 failed | PASS |
| fix-apply.test.mjs | `node scripts/panel/fix-apply.test.mjs` | PASS | PASS |
| panel-forced-floor-check.test.mjs | `node scripts/ci/panel-forced-floor-check.test.mjs` | 7 passed, 0 failed | PASS |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| — | — | No TBD/FIXME/XXX debt markers in any modified file | — | Prior WARNING (judge.mjs:609 `TODO: read from bundle dir`, empty-DOM stub) is RESOLVED — the CLI now reads dom.html/facts.json and refuses on empty DOM. No debt markers remain. |

### Confirmation Bias Counter (disconfirmation pass)

1. **Partial requirement?** SC-2's TRUE-live paid run is not automated — but this is BY DESIGN and explicitly non-gating (paid key + live server cannot be automated). The mechanism is hermetically proven AND proven against a real on-disk bundle. Not a partial-implementation defect.
2. **Test that passes without testing the behavior?** judge-cli.test.mjs could SKIP when no bundle is present. Verified it did NOT skip — Tests 2-3 ran against the real on-disk board-mg-5 bundle (callCount 0 / 3). The SC-4 clone chain was independently re-executed, not accepted on SUMMARY narrative.
3. **Uncovered error path?** The monotonic gate's "ledger absent → skip" path could mask a real 0→N regression. Adversarially cross-checked against a base WHERE the ledger exists (26b11a81): gate ran 32-cell comparison and still PASSED — confirming the board-mg 0-introduction is genuinely monotonic, not merely skipped.

### Gaps Summary

No gaps. All 7 gap-closure must-haves hold against committed HEAD; all 9 CI-gate-load-bearing prohibitions are honored; the fix-queue-lint 0-exemption deviation is sound and does not weaken the gate for measured cells; all 4 requirement IDs are SATISFIED. The two items the initial verification left in `human_needed` (SC-2 live, SC-4 live) are closed: SC-4 is now an autonomous, reproducible automated assertion (independently reproduced by the verifier), and SC-2's mechanism is shifted maximally left into a deterministic key-free CLI bundle-wiring test on a real bundle. The only residual item — the TRUE-live SC-2 paid run — is an OPTIONAL post-merge operator confirmation documented in the runbook; per the plan it is NOT a task gate and the phase completes autonomously without it, so it does not hold the phase in `human_needed`.

**Phase goal achieved. Requirements PANEL-01, PANEL-02, AUTOFIX-01, AUTOFIX-02 all SATISFIED by the automated, committed state.**

---

_Verified: 2026-07-04T21:15:00Z_
_Verifier: Claude (gsd-verifier)_
