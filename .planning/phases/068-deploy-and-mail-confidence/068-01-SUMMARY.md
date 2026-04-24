---
phase: 68
plan: "01"
completed: "2026-04-23"
---

## Outcome

Extended `guides/recipes/deployment.md` with an above-the-fold **Production checklist (read first)** (table + symptom triage + outbound links) and **Mail delivery: inline vs Oban (TL;DR)** (decision bullets, at-least-once / idempotency note with `test/example` pointer, `mix sigra.install` flags, Oban hexdocs link) ahead of the existing Oban workers section.

## Key files

- `guides/recipes/deployment.md` — checklist hub + mail TL;DR
- `README.md` — removed markdown file link to `.planning/PROJECT.md` (monospace only) so `mix docs --warnings-as-errors` passes ExDoc’s missing-path check

## Verification

- `MIX_ENV=dev mix docs --warnings-as-errors` — PASS
- Plan acceptance greps (heading order, table columns, forbidden warranty regex, mail section order) — PASS

## Self-Check: PASSED
