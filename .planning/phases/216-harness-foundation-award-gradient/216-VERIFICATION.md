---
phase: 216-harness-foundation-award-gradient
verified: 2026-07-03T22:00:00Z
status: gaps_found
score: 3/5
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "The stale-render guard hard-fails when a bundle's app_git_sha does not match working HEAD or admin source is newer than the bundle; an evidence-integrity check rejects findings whose DOM anchor is absent from the captured DOM, making cite-and-flip impossible by construction."
    status: partial
    reason: "Stale-render guard is fully implemented and self-test passes (12/12 cases). Evidence-anchor-check.mjs self-test passes (10/10 cases). HOWEVER: the guard exits 1 (FAIL) on every real bundle run because the probes scan document.querySelectorAll('[class*=\"sg-\"]') across the FULL page, while dom.html captures only the board container's outerHTML. In the MG-5 bundle: 526/869 findings (60.5%) have anchors absent from dom.html. The guard is structurally correct — it correctly detects absent anchors — but the probe-scope vs DOM-scope mismatch means the admin_eval_render CI job will always fail after producing bundles. The harness phase (b2) cannot complete successfully, so the 'proven end-to-end' claim (SC-5) is blocked."
    artifacts:
      - path: "scripts/ci/evidence-anchor-check.mjs"
        issue: "Guard logic is correct but guard fails on all real bundles due to probe-scope mismatch (probes: full page; dom.html: board element only)"
      - path: "test/example/priv/playwright/lib/eval/probes.ts"
        issue: "All probes use document.querySelectorAll('[class*=\"sg-\"]') scanning the entire page; anchors reference page-level elements not present in the board-scope dom.html"
      - path: "test/example/priv/playwright/tests/admin-eval.spec.ts"
        issue: "outerHTML captured as board.evaluate(el => el.outerHTML) — board element only, not full page; inconsistent with probe scan scope"
    missing:
      - "Either restrict probes to board-scope (e.g., boardEl.querySelectorAll vs document.querySelectorAll) OR capture full page outerHTML in dom.html; the two scopes must match for evidence-anchor-check to function correctly"
  - truth: "Two pilot surfaces complete the full render-probe-ratchet loop end-to-end with zero guard regressions."
    status: failed
    reason: "The 'zero guard regressions' claim cannot be verified. The SUMMARY explicitly states the live browser render was NOT re-run locally ('A pre-existing unknown Phoenix server occupied port 4011 — untrustworthy provenance'). While bundles are present on disk (eeb6bf14 SHA directory), the evidence-anchor-check exits 1 on these bundles (526/869 anchor failures in MG-5 board alone). The harness would fail at phase (b2) on any real run. The guard self-tests pass (which is what the SUMMARY measured), but the full end-to-end harness run with real bundles does not produce green results."
    artifacts:
      - path: "scripts/ci/admin-eval-harness.sh"
        issue: "Harness is syntactically correct and chains all 5 guards; but phase (b2) — evidence-anchor-check — fails with real bundles"
      - path: "guides/reference/admin-award-ledger.json"
        issue: "award-guard exits 0 via initial-commit mode (skips comparison before checking band==min(axes)); ledger values were manually validated and are correct (users-index-live=A2, user-show-live=A1, band==min(axes) confirmed)"
    missing:
      - "Fix probe-scope vs DOM-scope mismatch (see gap 1) so evidence-anchor-check exits 0 with real bundles"
      - "Re-run admin-eval-harness.sh against a known-good example server and confirm all 5 guards pass"
deferred: []
---

# Phase 216: Harness Foundation + Award Gradient — Verification Report

**Phase Goal:** A single near-command renders every admin surface into tamper-proof evidence bundles, deterministic visual probes run and flag defects automatically, and the quality ledger gains a finer-grained award sub-score — all proven end-to-end on two pilot surfaces.
**Verified:** 2026-07-03T22:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A single command emits render bundles (screenshot + DOM + axe + facts + app_git_sha + render_sha256) for every admin surface across the light/dark/mobile × populated/zero/loading/error matrix. | ✓ VERIFIED | `scripts/ci/admin-eval-harness.sh` exists (80 lines, non-stub), chains `tests/admin-eval.spec.ts` across 3 projects (admin-eval / -mobile / -dark). The spec covers 11 gallery boards × 4 states. `bundle.ts` writes dom.html + screenshot.png + axe.json + facts.json + bundle.json with app_git_sha + render_sha256. 132 bundles produced in the pilot run (eeb6bf14 directory present). |
| 2 | The stale-render guard hard-fails on stale app_git_sha / admin-source-newer / absent bundles; evidence-integrity check rejects findings whose DOM anchor is absent from the captured DOM. | ✗ FAILED | Stale-render guard: VERIFIED (self-test 12/12 pass; sha-match PASS, sha-mismatch FAIL, empty-dir FAIL, source-newer FAIL). Evidence-anchor-check: self-test passes (10/10) but guard exits 1 on all real bundles — probes scan full page (`document.querySelectorAll`), dom.html captures only board element outerHTML. In MG-5 board: 526/869 findings (60.5%) have anchors absent from dom.html. Guard is architecturally correct; probe-scope vs DOM-scope mismatch makes it always fail with real bundles. Cite-and-flip cannot be "impossible by construction" when the check itself is broken. |
| 3 | Deterministic visual probes run over rendered DOM/computed-style and produce machine-readable findings for the 9 specified probe classes. | ✓ VERIFIED | `probes.ts` (735 lines) implements all 9 probes using live `getComputedStyle().getPropertyValue()` calls (no `toHaveCSS`, confirmed by grep). Focus-ring (#7) diffs box-shadow. Target-size (#6) uses explicit axe enable. Card-in-card (#8) lifted verbatim from admin-design.spec.ts. All probe IDs match `eval-probe-ids.mjs` (confirmed — identical values, comment notes "must match"). Gate/warn split enforced: probes #1/#4/#5/#6/#7/#8 are gate; #2/#3/#9 are warn. NOTE: probes.ts duplicates PROBE_IDS array rather than importing from eval-probe-ids.mjs (D-12 drift risk, WARNING-level). Seeded defect tests present for #1/#5/#6/#7/#8; probes #2/#3/#4/#9 have no seeded defect assertions (PLAN required all 9; #4 ember is gate-severity but has no seeded test — WARNING). |
| 4 | The award sub-score ledger extension is committed and the harness runs verify-then-climb over existing Tier-2 claims, flagging cells that fail re-verification. | ✓ VERIFIED | `admin-award-ledger.json` schema_version:1, 4-axis A0..A3 per cell. `award-guard.mjs` (213 lines) enforces all 4 D-20 conditions — self-test 14/14 pass covering climb-without-render FAIL, band!=min FAIL, unresolved-evidence FAIL, decrease FAIL, no-change PASS, legit-climb PASS. `node scripts/ci/award-guard.mjs --base HEAD` exits 0 (initial-commit mode — skip comparison — per monotonic-guard idiom; ledger manually validated: users-index-live=A2/band=min/rendered=true, user-show-live=A1/band=min/rendered=true, both below A2 cap). D-24 modal ownership re-verified: overlay confirmed on UserSessionsLive, not user-show-live; stale claim correctly caught. KNOWN LIMITATION: guard exits 0 before checking band==min(axes) in initial-commit mode — full enforcement fires on all subsequent PRs; shipped ledger manually verified valid. |
| 5 | The findings-count-monotonic guard exits non-zero when any cell's open-finding count increases versus merge-base, and two pilot surfaces complete the full render-probe-ratchet loop end-to-end with zero guard regressions. | ✗ FAILED | `quality-findings-monotonic.sh` VERIFIED: self-test 7/7 pass (3→4 FAIL, no-change PASS, 4→3 PASS, 0→1 FAIL). `bash scripts/ci/quality-findings-monotonic.sh --base HEAD` exits 0 (initial-commit mode). BUT: "zero guard regressions" end-to-end is NOT verified because evidence-anchor-check exits 1 on real bundles (see truth #2). The SUMMARY admits live render was not re-run locally with trusted server provenance. The harness would fail at phase (b2) on any real run. Guard self-tests pass; full harness loop does not. |

**Score:** 3/5 truths verified (0 behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/ci/admin-eval-harness.sh` | Thin orchestrator | ✓ VERIFIED | 80 lines, chains all 5 guards, bash -n passes |
| `test/example/priv/playwright/lib/eval/canonicalize.ts` | renderSha256 | ✓ VERIFIED | 191 lines, parse5 tree-walk, self-test 17/17 pass |
| `test/example/priv/playwright/lib/eval/bundle.ts` | writeBundle | ✓ VERIFIED | 202 lines, writes dom.html + screenshot + axe + facts + bundle.json |
| `test/example/priv/playwright/lib/eval/probes.ts` | 9 probes | ✓ VERIFIED | 735 lines, all 9 probe classes implemented, live getPropertyValue reads |
| `test/example/priv/playwright/tests/admin-eval.spec.ts` | Render matrix + bundle spec | ✓ VERIFIED | 546 lines, 11 boards × 4 states, gate/warn split enforced |
| `test/example/priv/playwright/playwright.config.ts` | 3 new projects added (not forked) | ✓ VERIFIED | admin-eval + admin-eval-mobile + admin-eval-dark added; 10 existing projects preserved |
| `scripts/ci/quality-findings-monotonic.sh` + `.test.sh` | Findings down-ratchet guard | ✓ VERIFIED | 91 lines; self-test 7/7 pass |
| `scripts/ci/settled-findings-lint.sh` + `.test.sh` | TSV sorted/dedup enforcer | ✓ VERIFIED | 174 lines; self-test 9/9 pass; `--add` regen helper present |
| `scripts/ci/evidence-anchor-check.mjs` + `.test.mjs` | Anchor-presence guard | ✗ BROKEN | Self-test 10/10 pass; but exits 1 on all real bundles (probe-scope vs DOM-scope mismatch) |
| `scripts/ci/stale-render-guard.sh` + `.test.sh` | Stale-render trust guard | ✓ VERIFIED | 111 lines; self-test 12/12 pass |
| `scripts/ci/award-guard.mjs` + `.test.mjs` | Verify-then-climb guard | ✓ VERIFIED | 213 lines; self-test 14/14 pass; all 4 D-20 conditions enforced |
| `scripts/ci/lib/eval-probe-ids.mjs` | Single source of 9 probe IDs | ✓ VERIFIED | 9 IDs exported; resolveEvidenceRef works correctly |
| `guides/reference/admin-award-ledger.json` | Award sub-score ledger | ✓ VERIFIED | Two pilot cells, band==min(axes) confirmed, rendered:true, verified_at_sha present |
| `guides/reference/admin-render-sha.json` | Render SHA + open-finding counts | ✓ VERIFIED | 16 real render_sha256 values (non-null); MG-5/MG-9 SHAs match committed values |
| `guides/reference/settled-findings.tsv` | Suppression set | ✓ VERIFIED | 7-column header, 0 data rows; lint passes |
| `guides/reference/admin-eval-schema.md` | Schema contract doc | ✓ VERIFIED | finding_id=sha256 formula documented; Phase 217 seam flagged UNRESOLVED |
| `guides/reference/admin-eval-runbook.md` | Iteration runbook | ✓ VERIFIED | Documents single-command iteration, guard descriptions, band-climb rules, sign-off location |
| `.github/workflows/ci.yml` | Merge-base fix + guard wiring + separate render job | ✓ VERIFIED | id:base uses git merge-base (no --depth=1); 5 guards wired in fast_checks with self-tests; admin_eval_render job added (not in ci-gate.needs); YAML valid; ci-gate.needs unchanged (9 jobs) |
| `.gitignore` | Eval bundle paths ignored | ✓ VERIFIED | All 3 subproject paths confirmed present (eval/, playwright-report/, test-results/) |
| `test/example/priv/playwright/package.json` | parse5 + cheerio devDeps | ✓ VERIFIED | parse5 ^8.0.1, cheerio ^1.2.0 both installed and resolve correctly |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `admin-eval-harness.sh` | `admin-eval.spec.ts` | `npx playwright test ... --project=admin-eval` | ✓ WIRED | Harness drives spec across 3 projects |
| `admin-eval.spec.ts` | `canonicalize.renderSha256` | `import { renderSha256 } from '../lib/eval/canonicalize.ts'` | ✓ WIRED | Direct import confirmed |
| `admin-eval.spec.ts` | `bundle.writeBundle` | `writeBundleLocal` (CJS-shim deviation from bundle.ts) | ✓ WIRED | Inline `writeBundleLocal` function uses same logic as bundle.ts; documented Rule 3 deviation |
| `probes.ts probe IDs` | `eval-probe-ids.mjs` | Comment "must match"; NOT imported | ⚠️ PARTIAL | probes.ts duplicates the PROBE_IDS array instead of importing from eval-probe-ids.mjs; D-12 drift risk; IDs are identical at commit time |
| `admin-render-sha.json` | `quality-findings-monotonic.sh` | `LEDGER="guides/reference/admin-render-sha.json"` | ✓ WIRED | Guard reads JSON via node -e; confirmed |
| `admin-award-ledger.json` | `award-guard.mjs` | `readFileSync(LEDGER_ABS, 'utf8')` | ✓ WIRED | Direct file read; band==min(axes) recomputed |
| `stale-render-guard.sh` | `fast_checks` | Self-test wired; guard wired to admin_eval_render | ✓ WIRED | Self-test in fast_checks; guard in render job (architectural deviation from plan; documented) |
| `evidence-anchor-check.mjs` | `fast_checks` + `admin_eval_render` | Soft-skip (no bundles) in fast_checks; real run in render job | ⚠️ BROKEN | Soft-skip works correctly; real run exits 1 due to probe-scope vs DOM-scope mismatch |
| `ci.yml id:base` | All `--base` consumers | `git merge-base "origin/${{ github.base_ref }}" HEAD` | ✓ WIRED | Confirmed grep; push-branch else-branch unchanged |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| `admin-award-ledger.json` cells | band, axes, verified_at_sha | Pilot harness run → Task 2 manual update | Yes — real SHA eeb6bf14, real probe evidence_refs | ✓ FLOWING |
| `admin-render-sha.json` cells | render_sha256, open_findings | Pilot harness run (MG-5, MG-9 boards) | Yes — 16 non-null SHA values; distinct per surface | ✓ FLOWING |
| `admin-eval.spec.ts` outerHTML | board.evaluate(el => el.outerHTML) | Live page board element | Board element only (not full page) | ⚠️ PARTIAL — probe findings reference elements outside this scope |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| canonicalize.test.ts — 17 determinism cases | `npx tsx lib/eval/canonicalize.test.ts` | 17/17 PASS | ✓ PASS |
| quality-findings-monotonic guard self-test | `bash scripts/ci/quality-findings-monotonic.test.sh` | 7/7 PASS | ✓ PASS |
| settled-findings-lint guard self-test | `bash scripts/ci/settled-findings-lint.test.sh` | 9/9 PASS | ✓ PASS |
| award-guard self-test (all 5 D-20 cases) | `node scripts/ci/award-guard.test.mjs` | 14/14 PASS | ✓ PASS |
| evidence-anchor-check self-test | `node scripts/ci/evidence-anchor-check.test.mjs` | 10/10 PASS | ✓ PASS |
| stale-render-guard self-test | `bash scripts/ci/stale-render-guard.test.sh` | 12/12 PASS | ✓ PASS |
| award-guard against HEAD ledger | `node scripts/ci/award-guard.mjs --base HEAD` | exits 0 (initial-commit INFO) | ✓ PASS |
| quality-findings-monotonic against HEAD | `bash scripts/ci/quality-findings-monotonic.sh --base HEAD` | exits 0 (initial-commit mode) | ✓ PASS |
| settled-findings-lint against committed TSV | `bash scripts/ci/settled-findings-lint.sh` | exits 0 (0 data rows) | ✓ PASS |
| **evidence-anchor-check with real bundles** | `node scripts/ci/evidence-anchor-check.mjs` | **exits 1** (1332+ anchor failures) | ✗ FAIL |

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|---------------|-------------|--------|----------|
| HARNESS-01 | 216-01, 216-03, 216-06, 216-07 | Single command renders every admin surface into evidence bundles (screenshot + DOM + axe + facts + app_git_sha + render_sha256) | ✓ SATISFIED | `admin-eval-harness.sh` + `admin-eval.spec.ts` + `bundle.ts` + 3 playwright projects; 11 boards × 4 states × 3 themes/viewports |
| HARNESS-02 | 216-04, 216-06 | Stale-render guard hard-fails; evidence-integrity check rejects anchor-absent findings | ✗ PARTIAL | Stale-render guard: SATISFIED. Evidence-anchor-check: mechanism exists and self-tests pass, but exits 1 on real bundles (probe-scope vs DOM-scope mismatch) — the "impossible by construction" guarantee does not hold |
| HARNESS-03 | 216-05, 216-06 | 9 deterministic visual probes over DOM/computed-style | ✓ SATISFIED | All 9 probes implemented with live getPropertyValue reads; seeded defect tests for 5/9 gate probes (warning: #4 ember missing seeded test, #2/#3/#9 warn-only probes missing seeded tests) |
| RATCHET-01 | 216-02, 216-05, 216-07 | Award sub-score ledger; verify-then-climb re-verification of Tier-2 claims | ✓ SATISFIED | admin-award-ledger.json committed; award-guard.mjs enforces all 4 D-20 conditions; pilots verified-then-climbed (users-index-live=A2, user-show-live=A1); D-24 stale claim correctly caught |
| RATCHET-02 | 216-01, 216-04, 216-07 | Findings-count-monotonic guard + settled-findings suppression set | ✓ SATISFIED | quality-findings-monotonic.sh guards open-finding counts (self-test 7/7); settled-findings-lint.sh enforces sorted/dedup TSV (self-test 9/9); ci.yml wired |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `test/example/priv/playwright/lib/eval/probes.ts` | 30-42 | PROBE_IDS array duplicated rather than imported from `scripts/ci/lib/eval-probe-ids.mjs` | ⚠️ Warning | D-12 drift risk: the two tables can diverge on edits; IDs are identical at this commit |
| (no TBD/FIXME/XXX debt markers found in phase-modified files) | — | — | — | — |

### Gaps Summary

**Gap 1 (BLOCKER): evidence-anchor-check exits 1 on real bundles**

The evidence-anchor-check guard (`scripts/ci/evidence-anchor-check.mjs`) is architecturally correct: it correctly detects when a finding's anchor is absent from the captured DOM. The self-test proves this (10/10 pass). However, it fails in normal operation because the implementation has a scope mismatch:

- **Probes** (`probes.ts`) scan `document.querySelectorAll('[class*="sg-"]')` — the **entire page**, including navigation, breadcrumbs, sidebar, and all admin chrome.
- **DOM capture** (`admin-eval.spec.ts` line 315) captures only the **board element's outerHTML** (`board.evaluate(el => el.outerHTML)`) — approximately 5KB per board.
- Findings reference page-level elements (`.sg-nav-link`, `.sg-breadcrumb__item`, `.sg-scope-pill`, etc.) that are not in the board DOM.
- Empirical measurement: in the committed MG-5 board bundle, 526/869 findings (60.5%) have anchors absent from dom.html.

The `admin_eval_render` CI job (not in ci-gate.needs) will always fail at the evidence-anchor-check step after producing bundles. This makes the "zero guard regressions end-to-end" and "cite-and-flip impossible by construction" claims incorrect.

**Fix required:** Align probe scope with DOM capture scope. Options:
1. Scope all probes to the board element (pass the board element's root to querySelectorAll, not `document`)
2. Capture full page outerHTML in dom.html instead of just the board element
3. Record probe-scope in bundle metadata so evidence-anchor-check knows which DOM to validate against

**Gap 2 (BLOCKER): End-to-end harness run not verified green**

SC-5 requires "two pilot surfaces complete the full render-probe-ratchet loop end-to-end with zero guard regressions." The SUMMARY explicitly acknowledges the live browser render was not re-run locally with trusted server provenance. With Gap 1 present, the harness (`admin-eval-harness.sh`) cannot produce a green exit (phase b2 fails on evidence-anchor-check). The "proven end-to-end" claim requires both Gap 1 to be resolved and a verified green harness run.

**Non-blocking observations:**

- **award-guard initial-commit mode:** exits 0 before checking per-cell invariants (band==min, rendered:true) when base ledger is absent. This is the documented monotonic-guard idiom and an accepted design choice. The shipped ledger was manually validated as correct. Full enforcement fires on all subsequent PRs. Not a defect.

- **probes.ts PROBE_IDS duplication (D-12 warning):** IDs are identical to eval-probe-ids.mjs at this commit but are duplicated rather than imported. This is a future drift risk, not a current functional defect.

- **Missing seeded defect tests for probes #2, #3, #4, #9:** Plan 06 required seeded defect tests for all 9 probes. #4 (ember, gate-severity) has no seeded test — the probe is implemented and 0 findings on clean surfaces is correct, but we cannot prove the probe fires on ember misuse without a seeded test. #2/#3/#9 are warn-only. This is a WARNING-level gap (the probes exist and run; the Nyquist proof is incomplete).

---

## Human Verification Required

None — all outstanding items are code-verifiable gaps, not behavioral/visual items requiring human testing.

---

_Verified: 2026-07-03T22:00:00Z_
_Verifier: Claude (gsd-verifier)_
