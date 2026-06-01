# Phase 152: strategic-bet-evaluation-gate - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-01
**Phase:** 152-strategic-bet-evaluation-gate
**Mode:** assumptions
**Areas analyzed:** Strategic Evaluation Threshold (Diminishing Returns Wall), SCIM Implementation Strategy, Lockspire Integration Posture, Threadline Tracing Correlation

## Assumptions Presented

### Strategic Evaluation Threshold (Diminishing Returns Wall)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Greenfield enterprise features (like SCIM or new auth primitives) will remain blocked unless an explicit enterprise adopter contract requires them. | Confident | `.planning/decisions/002-strategic-bets-v1.33.md`, `.planning/phases/152-strategic-bet-evaluation-gate/152-CONTEXT.md` |

### SCIM Implementation Strategy
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| When SCIM is eventually unblocked by an enterprise contract, it will use the `ex_scim` dependency rather than a custom minimal implementation. | Confident | `.planning/decisions/002-strategic-bets-v1.33.md`, `152-CONTEXT.md` |

### Lockspire Integration Posture
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Lockspire integration will remain a host-owned responsibility (manual stub generation) rather than a published glue package (`sigra_lockspire`). | Confident | `guides/recipes/companion-libs/lockspire.md`, `.planning/decisions/001-defer-sigra-lockspire-glue-package.md`, `002-strategic-bets-v1.33.md` |

### Threadline Tracing Correlation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Threadline trace-correlation ID propagation is deferred until Threadline provides a stable upstream injection seam. | Confident | `lib/sigra/audit/forwarders/threadline.ex`, `.planning/decisions/002-strategic-bets-v1.33.md` |

## Corrections Made

No corrections — all assumptions confirmed.

## External Research

- `ex_scim` (v0.2.0) Hex package: `ex_scim` is a highly modular, adapter-based SCIM 2.0 implementation for Elixir. It fully supports RFC 7643, 7644, and 6902, using `ex_scim` for core logic, `ex_scim_ecto` for storage, and `ex_scim_phoenix` for routing. Resolves assumption viability to High confidence. (Source: HexDocs: ex_scim)
- Threadline's upstream injection seams: Threadline (since v0.5.0) has introduced and stabilized the required upstream injection seams for correlation IDs, such as `x-correlation-id` and `context_overrides_fn`. Resolves assumption D-03 to High confidence (unblocked). (Source: Threadline docs)
