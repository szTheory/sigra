# Phase 222: Release-Lane Hardening (No Silent Rot) - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-07-10
**Phase:** 222-release-lane-hardening-no-silent-rot
**Mode:** assumptions
**Areas analyzed:** HARD-01 rot-visibility + stopgap-pin disposition, HARD-02 auto-publish proof + fail-loudly, recovery runbook location

## Methodology Applied

`.planning/METHODOLOGY.md` lenses active: **Decisive Defaulting**, **Escalation Threshold**,
**Research Depth Calibration**, **Discuss-Phase Default (recommendation-first)**. Calibration tier:
**minimal_decisive** (PROJECT.md opinionated/decisive posture). Applied: formed one cohesive
recommendation set from repo + Actions-history evidence; escalated exactly one decision (HARD-02
live-proof-vs-backstop) because it touches the public/semver Hex contract + operator-truth claim.

## Assumptions Presented

### HARD-01 — rot-visibility + stopgap-pin disposition
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Keep upgrade_smoke nightly (not PR-visible); add loud red-main signal (GitHub Issue open/update) on non-success | Likely | ci.yml:636 (PR-invisible by design), MAINTAINING.md:146 (D-07 perf residual), release-please.yml:22 (`issues: write`), ci.yml:2181/:1238 (loud precedents) |
| Replace D-13 stopgap env pin with durable retired-filter in upgrade-smoke.sh (drop `(retired)` before `sort -V \| tail -1`) | Likely | upgrade-smoke.sh:45 (sed strips marker+tail so retired stays), :52 (sort picks stray), 221-CONTEXT D-13 (Option 4b deferred here) |

### HARD-02 — auto-publish proof + concrete fails-loudly
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Don't cut throwaway version; prove path via hex-publish.yml dry_run + green ci-gate + build fail-loudly notify on publish-hex/gate-ci-green | Unclear→resolved | `gh run list`: v1.2.0/v1.3.0 shipped manual (16:49/17:03/18:00 2026-07-10); auto-publish stalled silently 31m14s #74 / 31m7s #66 (gate-ci-green timeout); release-please.yml:119-169/:279-285 |

### Recovery runbook location
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Runbook in MAINTAINING.md new subsection; cross-ref docs/release-runbook-v1-0.md; no new top-level doc | Confident | MAINTAINING.md:264 (entry-point index), :178-198 (forced-failure probe runbook precedent), :266-276 (recovery area), :31/:33 (anti-duplication) |

## External Verification Performed

- **Actions run history (`gh run list`)** — decisive operator-truth resolution of the one Unclear
  item: **v1.2.0/v1.3.0 published via MANUAL `hex-publish.yml`** (three `workflow_dispatch` successes
  2026-07-10), and **release-please auto-publish DEMONSTRABLY stalled silently** (31m14s #74, 31m7s
  #66 = `gate-ci-green` ~30-min timeout on the then-red gate, then failure, no alert). Resolved
  HARD-02 confidence: auto-publish is unproven end-to-end + proven-silent-on-failure → the
  "fail loudly" OR-branch is the concrete buildable deliverable.

## Corrections / Decisions Made

### HARD-02 verification stance (escalated to Jon)
- **Question:** loud-failure backstop + dry-run **vs** also cut a live throwaway v1.3.1 proof.
- **User decision:** **Loud-failure backstop + dry-run (recommended)** — no new Hex version cut.
  Satisfies HARD-02's explicit OR-branch; the next real release exercises auto-publish live with the
  new loud signal as backstop.

### Assumption confirmation gate
- **User decision:** **Yes, proceed** — all three areas locked as-is (HARD-02 per the stance above).
  No corrections to HARD-01 (loud-signal + retire pin) or the runbook location.
