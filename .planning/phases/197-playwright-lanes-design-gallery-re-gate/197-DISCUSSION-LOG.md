# Phase 197: Playwright Lanes & Design-Gallery Re-Gate - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-20
**Phase:** 197-playwright-lanes-design-gallery-re-gate
**Mode:** assumptions
**Areas analyzed:** PW-01 lane topology, PW-02 readiness, PW-03 font determinism + recapture, PW-03 gallery placement/re-gate, MG-5/6 disposition

## Assumptions Presented

### PW-01 — Lane topology
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `if: ${{ !cancelled() }}` per test step + final aggregating gate; NO matrix sharding (prelude dominates, `workers:1/fullyParallel:false` shared DB state) | Likely | ci.yml:872–1090 (no `if:` on test steps), playwright.config.ts:48–49 |

### PW-02 — Readiness
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Bash curl-poll + warm-up loops are explicit readiness (keep); no `Process.sleep` in lane code; replace two `waitForTimeout(1_000)` with `expect.poll()` | Likely | ci.yml:954–969; organizations.spec.ts:152; ga-uat-shift-left.spec.ts:106 |

### PW-03 — Font determinism + recapture
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| SEED-006 premise WRONG — no webfont served; reflow is macOS-vs-ubuntu system-font metric delta on `/admin/_design` (same app, same CSS) | Confident (root cause); Likely (remediation) | grep: zero `@font-face`/`*.woff*`/Google Fonts in served CSS; default.css system stacks; router.ex:186–193 |
| In-CI recapture = dedicated `workflow_dispatch`/nightly job (recapture-gate.sh doesn't update/commit) | Likely | snapshot-recapture-gate.sh (compare-only); snapshot-canary-guard.sh empty allowlist; Phase-196 trigger precedent |

### PW-03 — Gallery placement / re-gate
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep gallery inline; delete `continue-on-error` once deterministic (PR hard-gate again) | Confident | ROADMAP success criterion #4; ci.yml:1043 |

### MG-5/6 disposition
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Resolve via ≥25-audit-event seeding (preferred) or `test.skip()` with recorded reason | Likely | pending todo 2026-06-17; admin-design.spec.ts `test.fail()` block |

## Corrections Made

### PW-03 — Font remediation direction
- **Original assumption:** Analyzer rated the remediation Likely with three viable paths
  (bundle self-hosted font + recapture; recapture-in-CI only; pinned CI fallback font), pending
  user confirmation because the root-cause reframing (no webfont exists) changes intended scope.
- **User decision:** "Bundle self-hosted font + recapture in-CI" — add Space Grotesk via
  `@font-face` to served CSS + `document.fonts.ready` wait, recapture admin-design baselines in
  CI, remove `continue-on-error`. Render becomes OS-independent (local AND CI match); makes
  criterion #3 literally true; closes the outlined-logo-only brand-truth gap.
- **Reason:** Durability + honoring the stated "brand webfont loads in CI" intent over the
  cheaper recapture-only (which leaves render OS-dependent and local baselines divergent).

All other assumptions confirmed as presented.

## Folded Todos
- `2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md` — folded into D-11
  (required by success criterion #4).

## Reviewed (not folded)
- `2026-06-18-token-reference-completeness-ci-guard.md` — different concern.
- `2026-06-20-phase51-installer-milestone-audit-ci-contract-stale.md` — `fast_checks` drift, not browser-lane.
- `2026-06-17-page04-branding-explicit-scoring.md` — admin-UI quality ledger, not CI-lane.

## External Research
None performed — codebase evidence sufficient. Two narrow items flagged for the phase
researcher to confirm against primary sources (not re-derive): ubuntu-latest `system-ui`/
fontconfig default resolution (validates the self-host-font choice), and `expect.poll` vs
manual mailbox-loop ergonomics.
