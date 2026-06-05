# Phase 160: Regression Hardening + Baseline Ratification - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-04
**Phase:** 160-regression-hardening-baseline-ratification
**Mode:** assumptions
**Areas analyzed:** Baseline ratification, Parity lane (GATE-02), Component governance contract, Deferred-bug folding, Milestone proof bundle

## Assumptions Presented

### Baseline ratification (clean DB)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New slugs use ad-hoc per-run fixtures = the "clean DB"; ratify by compare-mode, not seed re-capture | Likely → locked | admin-checkpoints.spec.ts:49–72,164–172; baselines committed e609b48a/25ee1bf0; 159 D-07 resolved toward min-churn |
| snapshot-allowlist must be reset to empty (still carries 158 user-audit/audit-explorer) | Confident | snapshot-allowlist steady-state comment; snapshot-canary-guard.sh:20 |

### Parity lane (GATE-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Closed by final green run of existing admin-generated lane; no new machinery | Confident | admin-acceptance-smoke.sh:1–40; playwright.config.ts:143–150 |

### Component governance contract
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Contract already exists + ExDoc-wired; criterion 4 is verify-and-ratify | Confident | guides/reference/admin-design-contract.md; mix.exs:199,242–244; REQUIREMENTS.md COMP-03 Complete |

### Deferred-bug folding
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 2 already fixed (nested-p, naivedatetime); brand-strong + count/link threaten criteria; role-status + cleanup are code-quality | Likely | components.ex:303; organization_live.ex:194; app.css:160–184; index_live.ex:157/organization_live.ex:215 |

### Milestone proof bundle
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Assembled from existing artifact producers + new v1.34-MILESTONE-AUDIT.md; flip gates + STATE | Likely | snapshot-recapture-gate.sh:30–50; per-phase VERIFICATION.md set; prior v1.x-MILESTONE-AUDIT.md precedent |

## Corrections Made

### Deferred-bug folding scope
- **Original assumption (analyzer lean):** Fold brand-strong dark fix + count/link; ~decisive default leaned toward gating brand-strong on empirical axe result.
- **Orchestrator refinement before asking:** Established axe is *already* green on committed dark baselines → fixing brand-strong is NOT criterion-blocking and would force dark re-records, so the honest default was to DEFER brand-strong. Surfaced the fork to the user.
- **User decision:** **"+ Fix dark contrast too"** — fold the brand-strong global dark fix as a DELIBERATE, allowlisted intended-delta dark re-record, making the dark-AA claim genuinely true. Also fold the count/link link-fix. Defer code-quality + role-status (→ contract).
- **Reason:** Prefer a genuinely-true dark-AA claim over a green-by-under-detection one; the allowlist exists for exactly this kind of sanctioned deliberate delta.

## External Research

None performed — analyzer flagged no gaps. This is a CI/process/closure phase fully determinable from the codebase; the only empirical unknown (does axe fire on the brand-soft+brand-strong dark combos) is resolved by running admin-checkpoints-dark, not external research.
