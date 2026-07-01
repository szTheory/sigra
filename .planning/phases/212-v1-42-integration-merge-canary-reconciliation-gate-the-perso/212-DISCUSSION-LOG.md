# Phase 212: v1.42 integration merge — Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-01
**Phase:** 212-v1-42-integration-merge-canary-reconciliation-gate-the-perso
**Mode:** assumptions
**Areas analyzed:** GATE-01 canary reconciliation, FLOW-01 persona-flow CI wiring, GATE-02 generated-host runtime smoke, SC-4 merge mechanics + honest-status sweep

## Assumptions Presented

### GATE-01a — impersonation-banner mobile canary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Requires explicit HUMAN decision among 3 options; recommend re-baseline + re-designate w/ documented rationale preserving the 204-03 WCAG fix | Unclear (escalated) | Only mobile drifted (`git diff --name-status origin/main`); chromium/dark byte-stable. Drift = `c96749fa` 204-03 WCAG fix. Guard forbids any canary change (`snapshot-canary-guard.sh:104`). Sanctioned re-baseline machinery exists (`snapshot-recapture-gate.sh`; PR-body precedent `ci.yml:1852`). |

### GATE-01b — allowlist the 4 legit checkpoint drifts
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add 1 line/slug (audit-explorer, user-audit, global-user-index, org-scoped-admin) to `snapshot-allowlist` in same PR diff; reset empty post-merge | Confident | Exactly 4 slugs drifted; cumulative v1.41 backlog (`af735d75`/`e7c5b0c7`/`4c3ce3cf`). Allowlist load/pass `snapshot-canary-guard.sh:42-48,106-111`, steady-state empty. |

### FLOW-01 — CI wiring approach
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Append the 3 admin-flow specs to the existing `example_playwright_smoke` chromium step (`ci.yml:991-997`); not a new job, not a waiver | Confident | Job already boots app + runs `seeds.exs` (personas alice/dave/frank/morgan). Specs match `ADMIN_BEHAVIOR_SPECS` (`playwright.config.ts:24-25`), excluded from mobile. Aggregator (`ci.yml:1102-1107`) fail-closes. |

### GATE-02 — un-skip generated-host runtime smoke
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Relax the PR-skip (`ci.yml:1209`) so it runs on the integration PR; exact scope needs a cost/benefit call | Likely (escalated) | Hard `needs` of `ci-gate`; skipped-as-not-failed means runtime parity never green on PR. Cold `phx.new`+compile+Playwright, `timeout-minutes: 60`, ~30-60m (CI-PERF pole). |

### SC-4 — merge mechanics + honest-status sweep
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Gates green → push main (385 ahead) → un-draft PR #63 → green → merge → THEN flip shipped; sweep stale phase-205 todo + Phase 208 VERIFICATION pointer | Confident | `gh pr view 63` → isDraft:true, state:OPEN, mergeable:MERGEABLE. Audit §81/§158 flags premature "shipped". 84 board PNGs now exist (phase-205 todo stale). |

## Corrections Made

Two Unclear/Likely items were escalated to the user as decision points (not corrections to
Confident assumptions):

### GATE-01a — canary-discipline decision
- **Options presented:** (a) re-baseline + re-designate w/ rationale [recommended];
  (b) revert mobile canary to origin bytes; (c) one-time integration exception.
- **User chose:** **(a) Re-baseline + re-designate with rationale** — preserves the 204-03
  WCAG fix via sanctioned recapture machinery; canary stays armed on new mobile bytes.

### GATE-02 — un-skip scope
- **Options presented:** (a) scope to ship/integration branch [recommended]; (b) un-skip
  all PRs; (c) accept post-merge push-to-main run.
- **User chose:** **(a) Scope to the ship/integration branch** — proves parity on PR #63
  without adding 30-60m to every future PR.

All other assumptions (GATE-01b, FLOW-01, SC-4) confirmed as-presented.

## External Research

None performed — all four areas fully evidenced from codebase, CI workflow, guard scripts,
spec files, git state, and PR metadata. No external research gaps flagged.
</content>
