# Phase 68 — Pattern map

Analogs and excerpts for documentation edits (executor reads full files before editing).

## Hub recipe

| Target | Role | Closest analog | Notes |
|--------|------|----------------|-------|
| `guides/recipes/deployment.md` | Canonical prod how-to | Self — extend in place | Env table, Oban block, Fly/Gigalixir already present; insert checklist **after** intro paragraph per **068-CONTEXT D-02** |
| `guides/introduction/getting-started.md` | Tutorial landing | `055-02-PLAN` reading-map callout pattern | **End** of doc only per **D-12** |
| `README.md` | Topic map | `055-01-PLAN` production evidence section | Short “Before production” strip; **no** second env matrix |

## Mail / Oban prose pattern

Existing anchor in `deployment.md` (~L103–126):

- Section `## Oban for background jobs` + closing line **Strongly prefer Oban in production.** — extend with TL;DR bullets above or inside this section per CONTEXT **D-09**.

## Install task truth

- `lib/mix/tasks/sigra.install.ex` — `@moduledoc` **Usage** and **Options** — single source for Installation doc table.

## PATTERN MAPPING COMPLETE
