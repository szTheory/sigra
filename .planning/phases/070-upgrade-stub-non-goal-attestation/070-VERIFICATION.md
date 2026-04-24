---
status: passed
phase: "070"
completed: 2026-04-23
---

# Phase 70 verification

**Goal (ROADMAP):** Planning **v1.10** vs Hex SemVer is legible; Lockspire / SEED-002 deferrals explicit (**ACF-05**, **ACF-06**).

## Must-haves (from plans)

### 070-01 — ACF-05

- [x] `guides/introduction/upgrading-to-v1.10.md` exists with required H1, first-paragraph tokens (`mix.exs`, `CHANGELOG.md`, `.planning/`), v1.9 subsection with `../../.planning/milestones/v1.9-ROADMAP.md`, checklist heading, See also links to v1.8/v1.7 HTML, link to `../../.planning/v1.10-ADOPTER-SCOPE.md`.
- [x] `mix.exs` lists `guides/introduction/upgrading-to-v1.10.md` in `extras:` immediately after `upgrading-to-v1.8.md`.
- [x] `MIX_ENV=dev mix docs --warnings-as-errors` succeeds.

### 070-02 — ACF-06

- [x] `.planning/REQUIREMENTS.md` Out of scope table contains `[ADR 001](decisions/001-defer-sigra-lockspire-glue-package.md)` and `[SEED-002](seeds/SEED-002-phase-9-log-safe-atomicity-followup.md)`.
- [x] `.planning/PROJECT.md` contains verbatim `decisions/001-defer-sigra-lockspire-glue-package.md` and `seeds/SEED-002-phase-9-log-safe-atomicity-followup.md`.
- [x] `MIX_ENV=dev mix compile --warnings-as-errors` succeeds.

## Automated checks run

- `MIX_ENV=dev mix docs --warnings-as-errors`
- `MIX_ENV=dev mix compile --warnings-as-errors`
- Plan acceptance `grep` commands from `070-01-PLAN.md` and `070-02-PLAN.md`

Full `MIX_ENV=test mix test` was not re-run in the execution environment (no local `postgres` DB role); this phase touched documentation and `mix.exs` docs config only — run the suite with Postgres per **`CLAUDE.md`** before merge if desired.

## Human verification

None required.

## Gaps

None.
