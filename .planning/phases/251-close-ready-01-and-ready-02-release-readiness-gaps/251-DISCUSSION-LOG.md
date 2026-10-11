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
