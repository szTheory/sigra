# Phase 142: dev-credentials-page-app-framing - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions captured in CONTEXT.md — this log preserves the analysis.

**Date:** 2026-05-30
**Phase:** 142-dev-credentials-page-app-framing
**Mode:** assumptions
**Areas analyzed:** Personas consumption contract, LiveView structure & testid application, Branding/app-framing edit surface, Seeds stdout & env-guard verification

## Methodology Applied

`.planning/METHODOLOGY.md` lenses applied: Decisive Defaulting, Escalation Threshold,
Discuss-Phase Default. All findings sit below the escalation threshold (no security model,
public/semver, or generated-host contract impact — this is `test/example/` only). Therefore
recommendation-first, single confirmation gate, no broad option menus. The two "Likely" items
(nav-link treatment, seeds stdout placement) are within "default UX/layout within an already
chosen flow" / "internal modularization" and were left at agent discretion with guardrails.

## Assumptions Presented

### (a) Personas Consumption Contract
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Feature text is a hardcoded map (no persona-map field), joined by email local part | Confident | `personas.ex:37-118` — `all/0` keys lack `:feature`/`:description`/`:role` |
| `demo-persona-row-{local}` derives local via `email` split on `@` | Confident | `personas.ex` emails are `{local}@demo.sigra.dev`; `display_name` is "Admin (operator)" |

### (b) LiveView Structure & testid Application
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Must wrap render in `<Layouts.app flash={@flash}>` (no default layout; flash required) | Confident | `example_web.ex` `:live_view` no `layout:`; `organization_settings_live.ex:57-61`; `layouts.ex:32` |
| Hand-roll `<table>` (daisyUI classes) — `<.table>` has no testid passthrough | Confident | `core_components.ex:354-390` — fixed table markup, rows only get `id` via `row_id` |

### (c) Branding / App Framing
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| "Vaultr" touches `root.html.heex:7` + `layouts.ex:48-52`; `app-name` testid on brand | Confident | `root.html.heex:7` title; `layouts.ex:48-52` version span |
| `layouts.ex` is shared `Layouts.app`; scope edits to brand span + nav `<ul>` only | Confident | `layouts.ex:54-76` org-switcher/impersonation rows below brand |
| Nav-link "Sign In →" should branch on `@current_scope`, not static | Likely | `Layouts.app` renders for both authed + unauthed contexts |

### (d) Seeds Stdout & Env-Guard Verification
| Assumption | Confidence | Evidence |
|------------|-----------|----------|
| Print stdout block from `Seeds.run/0`, not `seeds.exs` | Likely | `seeds.ex:33,63` aliases+iterates Personas; `seeds.exs` is thin guard wrapper |
| Env-guard test is net-new; assert route-absent/404 under `MIX_ENV=test` | Confident | grep found no existing dev-route env test; `router.ex:172-177` gate; compile_env compiles route out under test |

## Corrections Made

No corrections — user selected "Yes, proceed". All assumptions confirmed as decisions
(D-01 through D-12 in CONTEXT.md), with the two Likely items locked to their recommended
defaults plus discretion guardrails (nav-links branch on `@current_scope` with minimal-rebrand
fallback; stdout from `Seeds.run/0`).

## External Research

None — self-contained `test/example/` Phoenix change; all contracts confirmed from the codebase.
