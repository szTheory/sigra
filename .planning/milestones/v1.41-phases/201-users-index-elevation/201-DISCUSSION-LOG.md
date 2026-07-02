# Phase 201: Users Index Elevation - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-26
**Phase:** 201-users-index-elevation
**Mode:** assumptions
**Areas analyzed:** Filter Consolidation (INDEX-01), Metric Strip Demotion + Pill Reduction (INDEX-02), DRY Desktop-Table ⇄ Mobile-Card (INDEX-03), Tier-2 Ratchet + Recapture Blast Radius (INDEX-04)

## Assumptions Presented

### Filter Consolidation (INDEX-01)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Merge three filter regions into one panel; only the applied-chip block (`:236-243`) is detached after `</form>`, move it inside/contiguous; data (`applied_chips`/`any_filter_active?`/`remove_chip_path`) already present | Confident | `users_index_live.ex:156-243`, `:524-574`, `:14-15` |
| Quick-filter chips stay GET-form checkboxes (not `phx-click`); only `toggle_filters` stays a LiveView event; keep filter state URL-driven | Confident | `:156`, `:399-412`, `:66-68`, `:606-622` |

### Metric Strip Demotion + Pill Reduction (INDEX-02)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Slim + move metric strip below filter/search panel (not delete, not `<details>`); cut to Total + Locked + Deletion-scheduled; query untouched | Likely | `:91-149` renders first; `:136`/`:146` risk/warn tones; `summary_stats/3 :171-208`; Phase 200 "slim don't delete" precedent |
| Reduce `status_pills/1` to decision-bearing signals — keep Unconfirmed/Locked/Deletion-scheduled, drop Confirmed, collapse security pill to No MFA | Likely | `:415-430`; equivalence spec reads only first 2 pills (`admin-design.spec.ts:157`); `needs_review` filter `query.ex:353-357` |

### DRY Desktop-Table ⇄ Mobile-Card (INDEX-03)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| DRY via shared function component (not CSS-only reflow); desktop `<td>` + mobile `sg-kv` shells only | Likely | desktop `:261-295` vs mobile `:305-345` hand-duplicated (pills `:271-275` vs `:313-317`); audit-feed precedent |
| Frozen desktop column order (User/Status/Orgs/Activity/Action) — spec reads `td:nth-child(3)/(4)` positionally | Confident | `admin-design.spec.ts:151-164`, `:158-159` |
| `extra_badges`/`extra_columns` host seam frozen; must survive both copies; example `[]` won't catch one-sided drop | Confident | `query.ex:534-549`; render `:274`/`:287`/`:316`/`:335-337`; `test/example/lib/example/sigra_admin_users.ex:20,23` |
| Honest pagination already implemented; this phase proves it at list-scale (45 users → 2 pages) | Confident | `multi_page?/1 :513-517`, `:359-390`; `seeds.ex:11-13,43-47`; `query.ex:65` |

### Tier-2 Ratchet + Recapture Blast Radius (INDEX-04)
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Flip column-4 `1`→`2` (bare integer) at ledger `:87`; Evidence cites applicable proxies (equivalence, glossary, manual motion/density/target-size); APG/overlay-axe EXEMPT (no modal) | Confident | `admin-quality-ledger.md:14-27,87,88`; `admin-fractal-scorecard.md:123-167`; `glossary_test.exs:24` |
| Lockstep/recapture radius: CSS triple-copy + `global-user-index` checkpoint + equivalence selectors + ledger cell + List Archetype block; `sg-chevron` unstyled | Confident | three CSS copies share md5; `admin-checkpoints.spec.ts:215-216`; `admin-design-contract.md:211-243` stale |
| Phase-199 stress fixtures exist (36 loadtest + 9 personas = 45 → 2 pages); seeds `MIX_ENV=dev`-only | Confident | `seeds.ex:11-13,43-47,96-119`; `query.ex:65` |

## Corrections Made

No corrections — all assumptions confirmed via "Yes, proceed" on the single confirmation gate.

## Auto-Resolved

Not applicable (interactive run; no `--auto`, no Unclear items requiring auto-resolution).

## External Research

None performed. The analyzer flagged no external-research needs — every instrument (Tier-2 scorecard, quality ledger + monotonic guard, content-equivalence spec, checkpoint canary, CSS golden-diff triple-copy, glossary guard, design-contract archetypes, FIXT-02 stress seeds) already exists in-repo and was confirmed by direct file inspection.
