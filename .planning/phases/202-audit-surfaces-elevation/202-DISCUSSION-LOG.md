# Phase 202: Audit Surfaces Elevation - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-26
**Phase:** 202-audit-surfaces-elevation
**Mode:** assumptions
**Areas analyzed:** Filter consolidation + advanced-disclosure + Export; Column-density reduction + inline code disclosure; Byte-coherence between the two pages; Pagination proof; Tier-2 ratchet + recapture + docs; Lockstep invariants

## Assumptions Presented

### Filter consolidation + advanced-disclosure + Export relocation (AUDIT-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Converge both pages on the 201 single `sg-filter-panel` pattern; `audit_user_live.ex` is the violator (3 forms) needing most surgery; Export already in action row on both | Confident | `audit_index_live.ex:58-137,128-132`; `audit_user_live.ex:81-108,110-164,155-157`; `admin-checkpoints.spec.ts:368` |
| Quick toggles stay GET-form checkboxes; advanced-disclosure via native `<details>`/hidden, no JS | Likely | `handle_params` only state path (`:25`/`:29`); `admin-checkpoints.spec.ts:356-367`; 201 D-02 / 200 D-03 |

### Column-density reduction (event-code → drill-down) + mobile-first stacking (AUDIT-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| "Codes deferred to drill-down" = remove inline `row.id`/`row.action` from primary cells; NO drill-down route exists today — must decide build-vs-inline-affordance | Unclear | `audit_index_live.ex:168,177`; `audit_user_live.ex:197,206`; `components.ex:710-711`; no `/admin/audit/:event_id` route found; only `csv_export.ex:8,59` emits `event_id` |
| Removing the code column requires updating Playwright equivalence selectors in lockstep | Confident | `admin-design.spec.ts:166-178` reads `code.sg-code` (2) + `td:nth-child(3) span` (3); drives MG-6 + live + per-user checks |

### Byte-coherence between the two audit pages (AUDIT-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Mobile card already shared (`<.audit_row>`), but desktop table / pagination / empty state / ~8 helpers hand-duplicated; "byte-coherent" = extract shared function components | Likely | identical desktop body `:154-193` vs `:183-222`; identical `<nav>` `:216-236` vs `:246-266`; "identical to…" comments `:243`/`:271`; divergences: chip-key sets, return_to, breadcrumbs |

### Pagination proof against ≥25-event fixture (AUDIT-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Honest cursor pagination already implemented; prove multi-page against ≥25-event persona by booting dev DB with seeds; fixture exists (FIXT-01) | Confident | `multi_page?/1` `:309-313`/`:475-479`; page_size=25 `:134`/`:161`; `seeds.ex:12-13`; `admin-design.spec.ts:370` "only ~3 audit events" |

### Tier-2 ratchet + recapture + docs (AUDIT-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Ratchet two bare ledger cells `1`→`2`; applicable proxies = content-equivalence + glossary-clean + 3 manual; overlay-axe/APG = N/A (no modal) | Confident | `admin-quality-ledger.md:90,91,87`; `glossary_test.exs:28-29`; `admin-fractal-scorecard.md:135-167`; no dialog in either LiveView |
| No stale Audit archetype to rewrite — ADD a new Audit Explorer archetype block; recapture `audit-explorer`/`user-audit` slugs + `mg-6` | Likely | `admin-design-contract.md` archetypes only Overview `:172`/List `:211`/Detail `:284`; `:77` audit ref; checkpoint slugs on disk |

### Lockstep invariants
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| New/changed `sg-*` CSS must be byte-identical across the 3 copies; audit reuses existing classes so disclosure-only reflow may need zero new CSS | Confident | triple-copy golden-diff; 201 D-11 / 200 D-11 |
| Audit surfaces have NO host-extension seams (extra_filters are internal); CSV `event_id` is the de-facto host-visible contract | Likely | `explorer.ex:115-181`; no `Audit.Hooks` behaviour; `csv_export.ex:8` |

## Corrections Made

One assumption was genuinely Unclear and above the escalation threshold (it changes the
generated-host router contract). Surfaced as a focused decision rather than auto-resolved.

### Column-density reduction — drill-down mechanism
- **Original assumption:** "Codes deferred to drill-down" is undefined in the codebase; unclear
  whether it means an inline affordance or building a new `AuditEventLive` route.
- **User decision:** **Inline disclosure, no new route** — move raw event id + action code out of
  the primary desktop columns into an in-row progressive-disclosure affordance, reusing the mobile
  card's existing `show_detail`/`show_codes` pattern. No new LiveView / no `/admin/audit/:event_id`
  generated-host router seam. CSV `event_id` preserved.
- **Reason:** Proportionate to a density-reduction phase; avoids adding a generated-host router-contract
  seam adopters inherit; keeps codes accessible for forensic/regulatory use.

All other assumptions confirmed as-is (Confident/Likely, following the established Phase 200/201 playbook).

## External Research

None performed — internal UI refactor following an established in-repo playbook; all evidence in-repo.
