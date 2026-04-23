---
phase: 68
plan: "02"
completed: "2026-04-23"
---

## Outcome

Added thin discoverability links to **`guides/recipes/deployment.md#production-checklist-read-first`** (and mail TL;DR where specified) from **README**, **getting-started**, **first-hour**, **installation**, and **MAINTAINING**. Documented **`mix sigra.install`** flags in **installation** via a reference table aligned with **`mix help sigra.install`**.

## Key files

- `README.md` — `## Before production` strip with two checklist/mail links (no env-var table)
- `guides/introduction/getting-started.md` — end-of-doc production handoff
- `guides/introduction/first-hour.md` — reading-map entry for production checklist
- `guides/introduction/installation.md` — install flags table + deployment anchors + `test/example/` pointer
- `MAINTAINING.md` — adopters breadcrumb (no checklist table pasted)

## Verification

- `MIX_ENV=dev mix compile --warnings-as-errors` — PASS
- `MIX_ENV=dev mix docs --warnings-as-errors` — PASS
- `rg -l 'production-checklist-read-first'` across the five target files — count **5**

## Self-Check: PASSED
