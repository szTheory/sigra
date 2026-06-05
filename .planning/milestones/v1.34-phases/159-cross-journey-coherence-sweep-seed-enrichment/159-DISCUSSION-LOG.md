# Phase 159: Cross-Journey Coherence Sweep + Seed Enrichment - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-04
**Phase:** 159-cross-journey-coherence-sweep-seed-enrichment
**Mode:** assumptions
**Areas analyzed:** Expired invitation seed, Passkey-only persona + in-roster deletion,
Richer audit variety, Determinism & idempotency, Motion audit (GATE-03), Coherence sweep
verification (criterion 4)

## Assumptions Presented

### Expired invitation seed (FIXT-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add a SECOND Acme invitation (past `expires_at`), keep existing pending future-dated | Confident | `detail.ex:118-119` (expired? vs utc_now), `organization_live.ex:157,162`, `seeds.ex:247-256` |

### Passkey-only persona + in-roster deletion (FIXT-02, FIXT-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New passkey-only persona (totp:false); existing passkey is on TOTP admin | Confident | `users_index_live.ex:347-350`, `seeds.ex:295-312` |
| Make an Acme MEMBER deletion-scheduled (Frank is in no org) | Confident | `personas.ex:110-123`, `organization_live.ex:135-138`, `users_index_live.ex:355` |

### Richer audit variety (FIXT-04)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Append reserved-prefix action rows; no presenter change needed | Confident | `audit.ex:41`, `seeds.ex:577,601`, `presenter.ex:43-48` |

### Determinism & idempotency (FIXT-05)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Count-threshold is list-length-derived → bump lists + re-pin seeds_test assertions; anchor occurred_at to @seed_reference_ts; tie via effective_user_id; MIX_ENV guard in seeds.exs | Confident | `seeds.ex:548,558,573-575`, `seeds_test.exs:88-103,100,241,270` |

### Motion audit (GATE-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Audit + assert, not build; budget already implemented; fix only violations | Likely | `app.css:115-116,131-133,1290-1298,1314,1335,1368-1369,1458-1467` |

### Coherence sweep verification (criterion 4)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 6 screens identified; extend admin-checkpoints journey, not net-new spec | Likely | `admin-checkpoints.spec.ts:8-41,132-148,282-283,317` |

## Corrections Made

No corrections — all assumptions confirmed ("Yes, proceed").

## Todo Disposition
- FOLD: `org-notice-nested-p` (criterion 4 notice/flash unification on org overview),
  `admin-format-date-naivedatetime` (light — invitation dates render on a checkpoint screen)
- DEFER: `sg-notice-tone-rule-duplication` (already folded into 156),
  `admin-overview-cleanup-misc` (refactor, out of scope),
  `admin-overview-notice-role-status` (a11y adjudication, orthogonal)
- DEFER + FLAG: `admin-overview-needs-review-count-link-mismatch` (new FIXT-02 seed exercises
  this bug; verify overview not visibly broken, track follow-on rather than guess-fix)

## External Research

None performed — entirely internal seed/CSS/Playwright work; all evidence in-repo.
