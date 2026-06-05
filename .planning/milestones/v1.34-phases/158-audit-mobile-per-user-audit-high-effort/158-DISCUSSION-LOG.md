# Phase 158: Audit Mobile + Per-User Audit (High Effort) - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-04
**Phase:** 158-audit-mobile-per-user-audit-high-effort
**Mode:** assumptions
**Areas analyzed:** Unified audit-row component, Mobile dual-layout, Quick-filter chips, user-audit checkpoint, Baseline re-record scope

## Assumptions Presented

### Area 1 — Unified audit-row component
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| 11th shared component `audit_row/1` emitting the `sg-list-row` card form; desktop `<tr>` stays inline; single `audit_tone/1` retires `row_tone`/`audit_tone` divergence | Likely | `user_show_live.ex:265-272,437-440`; `audit_index_live.ex:136-162,206-208`; `audit_user_live.ex:165-192,246-248`; `components.ex:5,9-10`; `app.css:952-966` |

### Area 2 — Mobile dual-layout for AuditIndexLive
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Mirror UsersIndexLive: `sg-table-panel sg-show-desktop` + sibling `sg-stack sg-show-mobile` of audit_row cards; separate composition | Confident | `users_index_live.ex:179-238`; `app.css:247-255,556-559`; `audit_index_live.ex:125,132,159` |

### Area 3 — Quick-filter chips
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Value-setting chips on existing params (Failures→`outcome=failure`, Impersonation→`action_prefix=admin.impersonation`); NOT boolean checkboxes | Likely | `query_params.ex:9-15,56-60`; `audit_index_live.ex:88`; `admin-checkpoints.spec.ts:270`; `users_index_live.ex:322-338` |

### Area 4 — `user-audit` Playwright checkpoint
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New slug for `/admin/users/:id/audit` on `targetEmail` post-impersonation (zero new seed); wait on visible loaded row | Confident | `admin-checkpoints.spec.ts:234-273`; `router.ex:260,293`; `audit_user_live.ex:26-56` |

### Area 5 — Baseline re-record scope
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Re-record all 3 `audit-explorer` projects (chips above fold on all viewports under `fullPage:false`), + 3 new `user-audit` PNGs | Likely | `app.css:247-255`; `admin-checkpoints.spec.ts:141,270`; 156 D-03/D-04 re-record discipline |

## Corrections Made

No assumptions were rejected — user selected "Yes, proceed". Two coupled forks were resolved
by explicit choice rather than correction:

### Area 3 / Area 5 — chip viewport behavior
- **Fork:** chips on all viewports (re-record all 3 `audit-explorer` projects) **vs**
  `sg-show-mobile`-only chips (desktop byte-frozen, asymmetric filter idiom).
- **User choice:** **All viewports** → value-chips render on desktop+mobile (one filter
  idiom); accept the deliberate all-three-project `audit-explorer` re-record. Captured as
  D-05 + D-07.

## Folded Todos

User chose to fold BOTH offered phase-matched todos:
- `2026-06-04-admin-format-date-naivedatetime.md` → **D-09** (`format_date/1` handle
  `%NaiveDateTime{}`/`%Date{}` explicitly; raise on unexpected; audit surfaces are
  timestamp-heavy and read host-controlled data).
- `2026-06-03-sg-notice-tone-rule-duplication.md` → **D-10** (CSS already merged in 156 D-08;
  remaining fold target is the Elixir tone-derivation single-source via `audit_row` `audit_tone/1`,
  retiring `row_tone`×2).

Reviewed-not-folded (157-Overview surfaces, not audit): `admin-overview-cleanup-misc`,
`admin-overview-needs-review-count-link-mismatch`, `admin-overview-notice-role-status`,
`org-notice-nested-p` (already folded into 157 D-07).

## External Research

None performed — internal coherence phase; codebase fully supplied the patterns
(UsersIndexLive dual-layout + quick-filter idiom, `sg-show-desktop/mobile` utilities, audit
query param contract, established checkpoint journey/seed). The `gsd-assumptions-analyzer`
flagged no `Needs External Research` topics.

## Methodology Lenses Applied

Decisive Defaulting (METHODOLOGY.md): single strongest repo-consistent recommendation per
area; two alternatives only where genuinely forked. **No decision crossed the escalation
threshold** — all implementation-detail-level, no public/generated-host/security/operator-truth
change. The Area-1 tone unification *corrects* the recent-audit block's under-flagging of
impersonation toward the explorer's existing truth (coherence fix, not contract change). The
one fork surfaced to the user (Area 3 chip mechanism + Area 5 re-record coupling) shapes the
visible affordance but did not require escalation — it was confirmed for clarity.
</content>
