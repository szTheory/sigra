# Phase 154: Design Contract + sg-notice - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-06-03
**Phase:** 154-design-contract-sg-notice
**Mode:** assumptions
**Calibration:** minimal_decisive (USER-PROFILE: vendor_philosophy opinionated)
**Areas analyzed:** Artifact location & format · sg-notice CSS tree & tokens · Mapping scope (document vs. invent)

## Assumptions Presented

### Where the design-contract artifact lives and in what format
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Ship as `guides/reference/admin-design-contract.md`, registered in `mix.exs` ExDoc `extras:`; NOT under `.planning/` | Likely | `guides/reference/generator-options.md` precedent; `mix.exs:186-230` extras registry; Phase 160 SC#4 requires "referenced from the repo"; no pre-existing published design doc |

### Which app.css tree gets sg-notice, and which existing tokens it reuses
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Add in ONE place — `test/example/priv/static/assets/css/app.css` inside `@layer sg-components`; reuse `[data-tone]` token set; no mirrored copy | Confident | `git ls-files` → sole tracked app.css; installer emits no CSS; `admin-generated` lane probes routes/markup, never diffs CSS; existing `.sg-list-row[data-tone]` rules 945-967 |

### What "winning variant" decisions the mapping must encode vs. defer
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Document current reality + already-locked winners (COHR-02 open header, AUDX-02 users-index filter); defer executable contract to Phase 155, call-site migration to Phase 156; don't invent new winners | Confident | boxed (`user_show_live.ex:97,136,229`) vs open (`users_index_live.ex:72`) split; no `.sg-stat` CSS class; REQUIREMENTS pre-decides winners; "artifacts only, no behavior change" boundary SC#4 |

## Corrections Made

No corrections — user selected "Yes, proceed"; all three assumptions confirmed as locked decisions.

## External Research

None performed — analyzer flagged no research gaps. Docs + ~15-line CSS phase fully determinable from the codebase.
