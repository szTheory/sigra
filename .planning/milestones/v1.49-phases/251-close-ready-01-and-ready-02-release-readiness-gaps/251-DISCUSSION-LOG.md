# Phase 251: Close READY-01 and READY-02 Release Readiness Gaps - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in `251-CONTEXT.md` — this log preserves the analysis.

**Date:** 2026-10-11
**Phase:** 251-close-ready-01-and-ready-02-release-readiness-gaps
**Mode:** assumptions
**Areas analyzed:** READY-01 candidate evidence and approval, READY-02 current inventory and preservation, verification boundary and milestone routing

## Assumptions Presented

### READY-01 candidate evidence and approval
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| A single exact candidate/base/main tuple must join its matching CI, readiness, dry-run, and approval records; evidence from different tuples cannot be combined. | Confident | `247-RELEASE-READINESS.json`, `247-10-REBIND-PROPOSAL.json`, `250-247-RECONCILIATION.json`, `250-247-TUPLE-DECISION-PACKET.json` |
| Only a contemporaneous approval tied to the exact source and readiness record can satisfy READY-01; a later or broad approval cannot repair a missing historic approval. | Confident after user confirmation | User selected “Keep the original readiness bar” and confirmed that missing contemporaneous approval must leave READY-01 unsatisfied. |

### READY-02 current inventory and preservation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| READY-02 needs a fresh open-PR and inherited-work inventory, a disposition for each item, and recoverable preservation identities for inherited work. | Confident | `247-VERIFICATION.md`, `247-VALIDATION.md`, `250-247-RECONCILIATION.json`, `249-PRESERVATION.json` |

### Verification and phase boundary
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Phase 251 refreshes evidence and owner verification only; it does not dispatch workflows or merge, publish, or release. If evidence is unavailable, it records the gap instead of lowering the acceptance bar. | Confident after user confirmation | User approved the recommended Phase 251 scope; `.planning/REQUIREMENTS.md`; `.planning/METHODOLOGY.md`; `.planning/ROADMAP.md` Phase 251 placement. |
| CI/CD reliability and performance work remains separate from v1.49. | Confident | User's earlier instruction deferred this work until after the milestone. |

## User Decisions

- READY-01 keeps its original readiness bar: only contemporaneous approval tied to the exact candidate/source/CI/readiness/dry-run record can pass. If that record cannot be recovered, record the gap and leave READY-01 unsatisfied.
- Phase 251 refreshes existing evidence; READY-02 passes only with a fresh inventory and recoverable preservation records; unmet checks remain gaps. No workflow dispatch, merge, publish, or release action is included.

## Corrections Made

No corrections to the recommended scope. The user's answers confirmed the assumptions above.

## External Research

None needed; existing phase evidence and project policy define the acceptance bar.

## Todo Review

- The two high-relevance release-lane CI/CD todos were not folded into Phase 251 because the user deferred CI/CD optimization until after v1.49.
- The remaining heuristic matches were unrelated or historical and were not folded into scope.


---

## Discussion Update — 2026-10-12

**Mode:** assumptions, text fallback.
**Capture head:** `5d4b2638d1ff42a3228953cede17f8aed1bd4046` (clean).
**Prior context and log:** exact bytes verified from that committed ref; identities are in `251-DISCUSSION-RESOLUTION.json`.
**Areas analyzed:** original READY-01 evidence bar, evidence feasibility, owner and milestone truth, discussion resolution.

### Assumptions Presented

| Assumption | Confidence | Evidence |
|---|---|---|
| Preserve the exact-source and contemporaneous approval bar; later evidence cannot establish the original historical facts. | Confident | `251-CONTEXT.md` D-01/D-02; `verify-247-readiness.mjs`; Phase 247 context. |
| No additional automatic gap plan without a new independently trusted original source; bounded recovery is exhausted. | Confident | `.planning/METHODOLOGY.md`; `251-06-SUMMARY.md`; `251-GAP-REPLANNING-INCONCLUSIVE.json`. |
| Preserve READY-02 satisfied, READY-01 unsatisfied, Phase 247 ownership, and v1.49 incomplete at 8/9. | Confident | Phase 247 owner report; `251-VERIFICATION.md`; `.planning/REQUIREMENTS.md`; strict milestone audit. |
| Record implementation complete and verification incomplete, with no automatic retry; prospective repairs need separate scope. | Likely before confirmation; confirmed by user | `.planning/ROADMAP.md`; `.planning/STATE.md`; committed replanning diagnostic. |

### User Decisions

- The user first selected `1` (“Update it”) for the existing context.
- After the four assumptions and recommended direction were presented, the user selected `1` (“Yes, save this direction”).
- The confirmed direction preserves the original approval/source requirements and current verdicts, stops repeat gap planning, allows future bounded reassessment only for newly identified independent original evidence, and treats prospective documentation/release work as separately scoped.
- No new archive or immutable record ID was provided. No prospective corrective work, release action, acceptance waiver, or milestone archival was authorized.

### Corrections Made

No corrections — the user confirmed the recommended direction. New decisions D-07 through D-10 capture the exhausted-recovery guard; prior D-01 through D-06 remain byte-identical.

### Methodology Applied

Automation-first verification, exact source identity, historical evidence feasibility, write-ahead preservation, and truthful closeout. Assumptions were analyzed by the typed `gsd-assumptions-analyzer` role, model `gpt-6-sol`, resolved effort `xhigh`; local read-only analysis only. The original completed implementation/regression evidence remains historical; this discussion does not rerun or assert a new application test result.

### External Research

None. Ecosystem research cannot reconstruct the original approval interval or change the published tag.

### Todo Review

The 69 heuristic matches produced no new directly in-scope item. Prior release-note, label, and documentation-index work remains owned by its existing phases; CI/CD optimization remains deferred by D-06. No todo was folded into Phase 251.
