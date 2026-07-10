---
phase: 216-harness-foundation-award-gradient
verified: 2026-07-04T04:10:00Z
status: passed
score: 5/5
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/5
  gaps_closed:
    - "Gap 1 (probe-scope vs DOM-scope mismatch): all 9 probe element-scan candidate loops are now board-root scoped; evidence-anchor-check exits 0 on 132 real bundles / 3808 findings."
    - "Gap 2 (SC-5 never proven with trusted provenance): full harness re-run at committed HEAD ae78b94f with a provenance-verified orchestrator-owned server on :4011 exited 0 with all 5 guards green; captured log committed at 216-09-harness-evidence.log."
  gaps_remaining: []
  regressions: []
gaps: []
deferred: []
follow_ups:
  - id: DETERMINISM-16-FLAKE
    severity: non-blocking
    summary: "16 first-navigation page.goto('/users/register' | '/admin/_design') 'load' timeouts (15s) that all recovered on the warm retry (~3s). Timing/first-paint issue, not a code or board-state defect. admin_eval_render is a separate non-merge-blocking CI job (JUDGE-CI-01). Suggested hardening: waitUntil 'domcontentloaded' + explicit LiveView-ready wait instead of 'load'."
  - id: D12-PROBE-IDS-DUP
    severity: non-blocking
    summary: "probes.ts still duplicates the PROBE_IDS array instead of importing scripts/ci/lib/eval-probe-ids.mjs (D-12 drift risk). IDs identical at this commit."
---

# Phase 216: Harness Foundation + Award Gradient — Verification Report (RE-VERIFICATION)

**Phase Goal:** A single near-command renders every admin surface into tamper-proof evidence bundles, deterministic visual probes run and flag defects automatically, and the quality ledger gains a finer-grained award sub-score — all proven end-to-end on two pilot surfaces.
**Verified:** 2026-07-04T04:10:00Z
**Status:** passed
**Re-verification:** Yes — after closure of the two BLOCKER gaps from the 2026-07-03 initial verification (216-08 board-scope + W1 anchor alignment; 216-09 live SC-5 proof).

---

## Re-Verification Summary

Both BLOCKER gaps from the prior verification are **genuinely closed** (verified against the codebase and the committed evidence log, not taken from SUMMARY claims):

- **Gap 1 — probe-scope vs DOM-scope mismatch: CLOSED (structural).** `test/example/priv/playwright/lib/eval/probes.ts` now contains exactly ONE `document.querySelectorAll` (line 297) — the ember reserved-context containment test that builds `reservedSet` of allowed ancestor contexts, which is the explicitly-permitted global query. Every element-scan **candidate** loop (lines 105, 165, 224, 313, 402, 588, 720) is now `boardRoot.querySelectorAll(...)` / `board.querySelectorAll(...)`. All 9 probes receive `boardRoot`/`boardSelector` in `runAllProbes` (lines 788–796). D-22 finding enrichment (`enrichFindingsForBundle`, admin-eval.spec.ts L85–102) adds `finding_id = sha256(surface \0 probe_class \0 anchor)`, `class`, and `surface` to every finding. `evidence-anchor-check.mjs` reads real `finding_id`/`class`/`surface` with a `surface::class::anchor` fallback (L210) so it never prints `undefined`, and `GEOMETRY_ONLY_CLASSES` (L131) holds the real emitter strings (`misalignment`, `below-fold-primary`, `focus-ring`).

- **Gap 2 — SC-5 never proven with trusted provenance: CLOSED (empirical).** The full harness was re-run at committed HEAD `ae78b94f` (clean tree) with a provenance-verified orchestrator-owned `mix phx.server` on :4011, and exited 0 with all 5 guards green. The 690-line captured log is committed at `.planning/phases/216-harness-foundation-award-gradient/216-09-harness-evidence.log`.

**Provenance note (verified, honest).** Current `git rev-parse HEAD` is `f667a6fc`, a **docs-only** commit (`git diff --name-only ae78b94f HEAD` = only 216-09-SUMMARY.md + 216-09-harness-evidence.log). No code, script, or ledger file changed after the authoritative run. `git merge-base --is-ancestor ae78b94f HEAD` = true. The evidence log's guard block is pinned to `ae78b94f` via `stale-render-guard: PASS (132 bundle(s) verified at HEAD ae78b94f...)`, so the committed-HEAD evidence remains current for the code under test.

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | A single command emits render bundles (screenshot + DOM + axe + facts + app_git_sha + render_sha256) for every admin surface across the light/dark/mobile × populated/zero/loading/error matrix. | ✓ VERIFIED | `admin-eval-harness.sh` drives `admin-eval.spec.ts` across 3 projects. Evidence log: phase (a) 153/153 Playwright tests passed (11 boards × 4 states × 3 themes/viewports); 132 bundles produced at `ae78b94f`. |
| 2 | The stale-render guard hard-fails on stale app_git_sha / admin-source-newer / absent bundles; evidence-integrity check rejects findings whose DOM anchor is absent from the captured DOM (cite-and-flip impossible by construction). | ✓ VERIFIED | **Gap 1 closed.** stale-render-guard self-test 12/12; evidence-anchor-check self-test 15/15 (grew from 10 after 216-08 real-emitter-shape alignment). On real HEAD bundles: `stale-render-guard: PASS (132 verified at ae78b94f)` and `evidence-anchor-check: PASS (132 bundle(s), 3808 finding(s) checked)`. W1 tripwire clean — no `undefined` finding-id in output. |
| 3 | Deterministic visual probes run over rendered DOM/computed-style and produce machine-readable findings for the 9 specified probe classes. | ✓ VERIFIED | 9 probe functions (probes.ts L74–L788), all board-scoped, all wired in `runAllProbes`. 9 distinct `probe_class` strings emitted. 216-09 fixed two real `probeEmberReservedFor` bugs (self-suppressing `.sg-ember`; missing-token early-return) — seeded ember-misuse test fired in-scope at runtime, proving the probe now flags misuse. |
| 4 | The award sub-score ledger extension is committed and the harness runs verify-then-climb over existing Tier-2 claims, flagging cells that fail re-verification. | ✓ VERIFIED | `admin-award-ledger.json` (band==min(axes), rendered:true, verified_at_sha). award-guard self-test 14/14; on real run `award-guard: PASS (2 cells checked vs HEAD)`. Ledger unchanged since 216-07 (`c214b574`) — stable under board-scoping. |
| 5 | The findings-count-monotonic guard exits non-zero when any cell's open-finding count increases; two pilot surfaces complete the full render-probe-ratchet loop end-to-end with zero guard regressions. | ✓ VERIFIED | **Gap 2 closed.** quality-findings-monotonic self-test 7/7; on real run `PASS (16 cells checked vs HEAD)`. Full harness end-to-end: `admin-eval-harness: PASS — all phases green` / `HARNESS EXIT: 0` at committed HEAD `ae78b94f` with trusted server provenance. |

**Score:** 5/5 truths verified (0 behavior-unverified)

### Required Artifacts (regression check — all previously VERIFIED artifacts re-confirmed present)

| Artifact | Status | Details |
|----------|--------|---------|
| `scripts/ci/evidence-anchor-check.mjs` (+`.test.mjs`) | ✓ VERIFIED | **Was BROKEN, now fixed.** Reads real finding_id/class/surface with surface::class::anchor fallback; GEOMETRY_ONLY_CLASSES holds real emitter strings; self-test 15/15; exits 0 on 132 real bundles / 3808 findings. |
| `test/example/priv/playwright/lib/eval/probes.ts` | ✓ VERIFIED | Board-root scoped; single allowed `document.querySelectorAll` (ember reserved-context test). 9 probes wired. |
| `test/example/priv/playwright/tests/admin-eval.spec.ts` | ✓ VERIFIED | D-22 `enrichFindingsForBundle` adds finding_id/class/surface; runAllProbes passes board root. |
| `scripts/ci/stale-render-guard.sh` (+`.test.sh`) | ✓ VERIFIED | self-test 12/12; PASS on real bundles pinned to HEAD ae78b94f. |
| `scripts/ci/award-guard.mjs` (+`.test.mjs`) | ✓ VERIFIED | self-test 14/14; PASS (2 cells). |
| `scripts/ci/quality-findings-monotonic.sh` (+`.test.sh`) | ✓ VERIFIED | self-test 7/7; PASS (16 cells). |
| `scripts/ci/settled-findings-lint.sh` (+`.test.sh`) | ✓ VERIFIED | self-test 9/9; PASS (no data rows). |
| `scripts/ci/admin-eval-harness.sh` | ✓ VERIFIED | chains all 5 guards; real run exits 0. |
| `guides/reference/admin-award-ledger.json` | ✓ VERIFIED | unchanged since 216-07; SHAs stable under board-scoping. |
| `guides/reference/admin-render-sha.json` | ✓ VERIFIED | unchanged since 216-07; SHAs stable under board-scoping. |

### Behavioral Spot-Checks (re-run at current HEAD)

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| evidence-anchor-check self-test | `node scripts/ci/evidence-anchor-check.test.mjs` | 15/15 PASS | ✓ PASS |
| stale-render-guard self-test | `bash scripts/ci/stale-render-guard.test.sh` | 12/12 PASS | ✓ PASS |
| award-guard self-test | `node scripts/ci/award-guard.test.mjs` | 14/14 PASS | ✓ PASS |
| quality-findings-monotonic self-test | `bash scripts/ci/quality-findings-monotonic.test.sh` | 7/7 PASS | ✓ PASS |
| settled-findings-lint self-test | `bash scripts/ci/settled-findings-lint.test.sh` | 9/9 PASS | ✓ PASS |
| **Full harness end-to-end** (committed evidence) | `scripts/ci/admin-eval-harness.sh` @ ae78b94f | HARNESS EXIT: 0, all 5 guards green, 132 bundles / 3808 findings | ✓ PASS |

### Requirements Coverage

| Requirement | Status | Evidence |
|-------------|--------|----------|
| HARNESS-01 (deterministic capture / render_sha256) | ✓ SATISFIED | harness + spec + bundle writer; 132 bundles emitted with render_sha256 + app_git_sha across the full matrix. |
| HARNESS-02 (evidence-anchor integrity / cite-and-flip impossible) | ✓ SATISFIED | **was PARTIAL.** Probe scope aligned to DOM capture scope; evidence-anchor-check PASS on 132 real bundles / 3808 findings; "impossible by construction" now holds. |
| HARNESS-03 (nine probes) | ✓ SATISFIED | 9 board-scoped probes wired; ember probe runtime-proven after two real bug fixes. |
| RATCHET-01 (forward-only render-sha ledger) | ✓ SATISFIED | quality-findings-monotonic PASS (16 cells); render-sha ledger stable. |
| RATCHET-02 (award verify-then-climb) | ✓ SATISFIED | award-guard PASS (2 cells); band==min(axes), rendered:true. |

### Anti-Patterns / Non-Blocking Observations

| Item | Severity | Impact |
|------|----------|--------|
| 16 first-navigation `page.goto` 'load' timeouts, all recovered on warm retry (~3s) | ℹ️ Non-blocking follow-up | Timing/first-paint issue, not a code or board-state defect. Retries absorbed it; harness exited 0. `admin_eval_render` is a separate non-merge-blocking CI job (JUDGE-CI-01). Hardening suggestion: `waitUntil: 'domcontentloaded'` + explicit LiveView-ready wait. |
| `probes.ts` duplicates PROBE_IDS instead of importing `eval-probe-ids.mjs` (D-12) | ⚠️ Warning (non-blocking) | Drift risk; IDs identical at this commit. |

---

## Human Verification Required

None — both blockers are closed with committed, reproducible codebase and log evidence. The determinism flake is a tracked non-blocking follow-up.

---

## Gaps Summary

No gaps. Both prior BLOCKER gaps are closed and verified against the codebase and the committed authoritative harness log. Phase goal achieved end-to-end on the two pilot surfaces.

---

_Verified: 2026-07-04T04:10:00Z (re-verification)_
_Verifier: Claude (gsd-verifier)_
