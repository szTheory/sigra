# Phase 157: Overview Landings (Highest Effort) - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-04
**Phase:** 157-overview-landings-highest-effort
**Mode:** assumptions
**Areas analyzed:** LAND-04 async/skeleton mechanism; LAND-01 loud alarm; LAND-02/03 archetype reorder; Playwright checkpoints + nested-`<p>` fold

## Assumptions Presented

### LAND-04 — async/skeleton mechanism
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| `connected?(socket)`-gated deferred load (skeleton on disconnected mount, real query inline on connected mount); no `assign_async/3`, no Task/send | Likely | `users/query.ex:159-167` (6+ aggregates), `organizations/detail.ex:59-99` (joined `repo.all`), `confirmation_live.ex:103` (in-repo `connected?` precedent), `admin-design-contract.md:125,127` |
| `aria-busy="true"` on loading section; alarm live-region role opt-in via `:rest` (valid now that count is post-load-dynamic per 155-D-08); no always-on role | Likely | `admin-design-contract.md:125`, `components.ex:274-276`, WAI-ARIA APG |

### LAND-01 — loud alarm, existing classes only
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Promote `<.notice>` to first child above task grid; risk/ok tone + count + deep-link; prominence from position + existing `sg-notice[data-tone]`, NO new class; delete old status-pill alarm | Likely | `index_live.ex:60-65`, `organization_live.ex:86-94`, `app.css:960-978`, no-new-CSS-class lock (STATE.md) |

### LAND-02/03 — identical archetype, demoted strips
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Both reorder to header → alarm → task cards → demoted posture strip → capability (Global only); Global 3 cards / Org 2, archetype identical | Likely | `admin-design-contract.md:142-160`, `app.css:1172` (posture-strip "below the jobs" comment), LAND-03 ("differing task counts acceptable") |
| Org Members roster + Pending invitations fate under archetype parity | **Unclear → escalated** | `organization_live.ex:125-162`; Global has no roster; LAND-03 "identical archetype" vs Org's real tenant data |

### Playwright checkpoints + nested-`<p>` fold
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add `global-overview` + `org-overview` slugs to existing journey (6 PNGs); wait for LOADED data not skeleton frame; confirm org route not a stub | Likely | `admin-checkpoints.spec.ts:40-44,171-208,202` |
| Fold `2026-06-04-org-notice-nested-p.md`: keep notice slot content inline; redesign removes the block-`<p>` call site naturally | Confident | `organization_live.ex:73-78`, `components.ex:303-304` |

## Corrections Made

No corrections to the locked assumptions. One genuinely-Unclear, above-escalation-threshold item
was surfaced to the user as a single focused question.

### LAND-02/03 — Org scoped-data fate (escalated)
- **Question:** Under LAND-03's "identical archetype" requirement, what happens to the Org
  Overview's live Members roster + Pending invitations (which Global has no equivalent of)?
- **Options presented:** (1) Keep as demoted tail section *(recommended)*; (2) Demote to
  deep-link cards; (3) Drop from overview entirely.
- **User choice:** **Keep as demoted tail section** — shared front-door archetype is identical
  across both; Org appends members + pending invitations as a clearly-demoted scoped-detail tail.
- **Rationale:** Preserves real operator data (pending invitations have no other home); LAND-03
  parity is about front-door rhythm, not forbidding scope-specific content; least surprising.
- Recorded as D-05.

## External Research

None performed — codebase evidence was sufficient (the `connected?`-gate idiom, skeleton/notice
CSS + component contracts, checkpoint spec pattern, and both todos were all readable in-repo).
