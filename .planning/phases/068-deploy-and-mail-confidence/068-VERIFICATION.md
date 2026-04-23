---
status: passed
phase: 68-deploy-and-mail-confidence
verified: "2026-04-23"
---

## Summary

Phase **68** delivered documentation only: a canonical **Production checklist (read first)** and **Mail delivery: inline vs Oban (TL;DR)** in `guides/recipes/deployment.md`, plus thin inbound links from **README**, intro guides, and **MAINTAINING**, and a **`mix sigra.install`** flag table in **installation**.

## Must-haves (from plans)

| Criterion | Evidence |
|-----------|----------|
| ACF-01 checklist hub + discovery | `guides/recipes/deployment.md` §Production checklist; fragment `#production-checklist-read-first` linked from five surfaces (`rg -l` count **5**). |
| ACF-04 mail + install semantics | Mail TL;DR + Oban link + `test/example` pointer in deployment; install flags table + deployment anchors in `guides/introduction/installation.md`. |
| No duplicated env-var matrix in README / MAINTAINING | Confirmed: no `\| Variable \|` in README; no `\| Check \|` checklist table in MAINTAINING. |

## Automated checks

| Check | Result |
|-------|--------|
| `MIX_ENV=dev mix docs --warnings-as-errors` | PASS |
| `MIX_ENV=dev mix compile --warnings-as-errors` | PASS |
| Full `mix test` (Postgres `postgres`/`postgres` @ localhost) | **Not re-run to completion in this session** — sandbox lacked role `postgres` (connection errors mid-suite). Re-run in CI or with Docker Postgres per **`CLAUDE.md`**. |

## Human verification

_None required_ (docs-only phase).
