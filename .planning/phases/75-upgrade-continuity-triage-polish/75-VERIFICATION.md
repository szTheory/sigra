---
status: passed
phase: 75
verified: 2026-04-23
---

# Phase 75 — Verification

**Triage accountability (TRN-03):** see **`.planning/v1.11-TRIAGE.md`** → **`## v1.12 reconciliation (Phase 75)`** (primary record).

## Must-haves (from plans)

| Criterion | Evidence |
|-----------|----------|
| **TRN-01** | **`upgrading-to-v1.12.md`** + **`mix.exs`** **`extras`** registration; **`mix docs --warnings-as-errors`** green |
| **TRN-02** | **Faster path** + **MAINTAINING** block + **`CHANGELOG`** unreleased bullet; **README** unchanged |
| **TRN-03** | Triage subsection present (**this file is not the sole record**) |

## Verification outcome

- Ran the **Automated** script block below on **2026-04-23** — all greps and `mix docs --warnings-as-errors` succeeded.
- `MIX_ENV=test mix compile --warnings-as-errors` succeeded during plan execution.
- Full root `mix test` was not re-run to completion in this sandbox (host Postgres `postgres` role / pool errors); executable regressions are unchanged by markdown-only edits — rely on CI **`library_tests`** for BEAM coverage.

## Automated

```bash
# Post-phase gate: run only after **75-01** and **75-02** are complete.
test -f guides/introduction/upgrading-to-v1.12.md
grep -nF 'upgrading-to-v1.12.md' mix.exs
grep -nF '[Upgrading notes — v1.12](upgrading-to-v1.12.html)' guides/introduction/getting-started.md
grep -nF '## v1.12 trust bundle (audit + UAT evidence)' MAINTAINING.md
grep -nF '**v1.12** trust bundle' CHANGELOG.md
grep -nF '## v1.12 reconciliation (Phase 75)' .planning/v1.11-TRIAGE.md
mix docs --warnings-as-errors
```

## Human verification

Optional: open **`doc/getting-started.html`** locally and click **v1.12** upgrade link.
