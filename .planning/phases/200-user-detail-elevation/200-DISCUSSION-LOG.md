# Phase 200: User Detail Elevation - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-25
**Phase:** 200-user-detail-elevation
**Mode:** assumptions
**Areas analyzed:** Identity header, JTBD regrouping & link-outs, APG destructive dialog, host-seam preservation, Tier-2 ratchet & recapture, CSS/template lockstep

## Methodology Lenses Applied

`.planning/METHODOLOGY.md` lenses applied to assumption generation:
- **Decisive Defaulting** — drove the "recompose existing `sg-*` primitives, reuse the existing
  `ConfirmDialog`" defaults rather than reopening component menus.
- **Escalation Threshold** — flagged the Sessions link-out (new admin route = generated-host router
  contract change) as the one decision worth escalating to the user; all other forks defaulted.

## Assumptions Presented

### Identity Header
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Recompose stacked pills + 4-fact `<dl>` + alert into one calm identity bar, reusing existing `summary_alert/1` + `sg-*` primitives, no new component | Likely | `user_show_live.ex:102-139,475-513`; `admin-design.spec.ts:304` |

### JTBD Regrouping & Link-Outs
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Recent-audit + Organizations link-out via existing routes; **Sessions kept inline** (no admin sessions route exists; new route is escalation-worthy) | Likely → **CORRECTED** | `user_show_live.ex:264,379-401`; `router.ex:285,317-318` (no admin sessions route) |

### APG Destructive Dialog
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Reuse existing generic `ConfirmDialog` APG hook; no new dialog, no JS change | Confident | `admin_hooks.js:373-480`; `admin-modal-interaction.spec.ts`; `user_show_live.ex:315-333` |

### Host-Seam Preservation
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Preserve `extra_detail_sections/1` callback, data path, dual atom/string key reads, post-lib placement; update design contract | Confident | `hooks.ex:16-25`; `default_hooks.ex:24`; `detail.ex:35`; `user_show_live.ex:310-313`; `admin-design-contract.md:251-279` |

### Tier-2 Ratchet & Recapture
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Flip `user-show-live` cell to bare `2` + cite per-proxy evidence; recapture only `user-detail` + affected `mg-9/10/11` through gate; canaries byte-stable | Likely | `admin-quality-ledger.md:33-54,88`; `admin-fractal-scorecard.md:123-167`; `admin-checkpoints.spec.ts:218-231,268`; `snapshot-recapture-gate.sh` |

### CSS / Template Lockstep
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Lib-owned page; any new `sg-*` CSS into all 3 byte-identical copies or golden-diff fails | Confident | `diff -q` identical ×2; CLAUDE.md installer-drift hazard; 184→185 regression class |

## Corrections Made

### JTBD Regrouping & Link-Outs — Sessions
- **Original assumption:** Keep Sessions inline as a bounded table (no admin per-user sessions route
  exists; adding one is an escalation-worthy generated-host router contract change, so default to inline).
- **User correction:** **Add a new admin Sessions route** — build a lib-owned
  `Sigra.Admin.Live.UserSessionsLive` + `/admin/users/:id/sessions`, making Sessions a true link-out.
- **Reason:** User deliberately accepted the generated-host router/LiveView contract cost to get the
  strongest "clearly separated" destructive flow (DETAIL-03) and a calmer detail page.
- **Knock-on effects captured in CONTEXT.md D-04/D-06/D-10/D-12:** new route propagated to installer
  template + example + golden fixtures in lockstep; per-session revoke + revoke-all destructive flow
  moves to the new page (reusing the existing `ConfirmDialog`); new checkpoint slug + (optionally) new
  quality-ledger cell for the sessions surface.

## External Research

None performed — codebase + known standards (APG Dialog pattern, WCAG 2.2 target-size, reduced-motion)
were sufficient; analyzer flagged no research gaps.
</content>
