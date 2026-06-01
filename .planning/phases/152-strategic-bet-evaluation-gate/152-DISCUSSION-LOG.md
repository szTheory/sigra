# Phase 152: Strategic Bet Evaluation Gate - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-01T00:00:00Z
**Phase:** 152-strategic-bet-evaluation-gate
**Mode:** assumptions
**Areas analyzed:** Overriding the Diminishing Returns Wall, SCIM / Directory Sync Implementation, `sigra_lockspire` Glue Deferral, Threadline Correlation

## Assumptions Presented

### Overriding the Diminishing Returns Wall
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| The formal threshold for overriding the Diminishing Returns Wall requires an enterprise adopter contract explicitly blocked by the lack of the feature (e.g., JIT provisioning proving insufficient). | Confident | `.planning/MILESTONE-ARC.md`, `guides/introduction/suite-integration.md` |

### SCIM / Directory Sync Implementation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| The strategic evaluation will scope adopting the `ex_scim` dependency against building a custom minimal implementation, rather than building a generic integration immediately. | Likely | `.planning/research/SUMMARY.md` |

### `sigra_lockspire` Glue Deferral
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| The `sigra_lockspire` glue package remains formally deferred and blocked until both libraries are fully stable and a real companion-app trigger fires. | Confident | `.planning/decisions/001-defer-sigra-lockspire-glue-package.md`, `.planning/PROJECT.md` |

### Threadline Correlation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Threadline correlation (trace-correlation ID propagation) cannot proceed until a stable upstream injection seam exists in Threadline. | Confident | `.planning/milestones/v1.30-REQUIREMENTS.md`, `.planning/PROJECT.md` |

## Corrections Made

No corrections — all assumptions confirmed.

## External Research

- ex_scim: `ex_scim` is an available but early-stage library (currently around v0.2.0) published on Hex.pm under the MIT license. It provides foundational utilities for building SCIM 2.0 compliant APIs in Elixir. (Source: https://hex.pm/packages/ex_scim)
- Custom SCIM: Building a minimal custom sync is moderately complex. A minimal viable implementation for user lifecycle requires `GET`, `POST`, and `PATCH` on the `/Users` endpoint. Key complexities include Deactivation over Deletion, Strict Error Shapes, Conflict Resolution, Idempotency, and Filtering. (Source: Microsoft Entra ID SCIM documentation)
