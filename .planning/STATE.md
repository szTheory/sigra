---
gsd_state_version: 1.0
milestone: v1.22
milestone_name: Webhooks / outbound event pipeline
status: "v1.22 initialized 2026-05-06 — roadmap ready, phase 97 not started"
last_updated: "2026-05-06T00:00:00.000Z"
last_activity: 2026-05-06
progress:
  total_phases: 3
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**North star (milestones):** Prefer work that moves **North Star (milestones)** in `.planning/PROJECT.md` — production trust, integration path, DX.

**Current focus:** v1.22 webhooks milestone — phase 97 will define the event contract, subscription registry, and signed delivery seam.

## Current Position

Milestone: **v1.22 — Webhooks / outbound event pipeline**

Phase: **97 — Webhook subscription registry + signed dispatcher contract**
Plan: —
Status: Roadmap created; ready for discuss/plan

Last activity: 2026-05-06 — initialized v1.22 with research, requirements, and roadmap for phases 97–99.

Carried-forward context (non-blocking):
- 2 install-smoke pending todos from 2026-04-30 (JOSE warning, Postgres too_many_connections)
- DEF-92-02-01 pre-existing audit Multi step-name collision (predates Phase 92)
- Nyquist coverage thin: 91/92/93 draft VALIDATION.md; 94/96 missing VALIDATION.md (Phase 95 only one with `nyquist_compliant: true`)

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260502-lzl | fix PR #37 CI red — 6 mechanical drift fixes (4 commits + 2 documented no-ops; 2357/2358 local pass) | 2026-05-02 | 80ecae7 | [260502-lzl-fix-pr-37-ci-red-6-mechanical-drift-fixe](./quick/260502-lzl-fix-pr-37-ci-red-6-mechanical-drift-fixe/) |
| 260502-oc7 | fix PR #37 CI groups B + D — Oban-off worker contract + OAuth Assent leak + admin policy arity (4 commits incl. fixture rebless; 2357/2358 local pass) | 2026-05-02 | 022b35b | [260502-oc7-fix-pr-37-ci-groups-b-d-oban-off-worker-](./quick/260502-oc7-fix-pr-37-ci-groups-b-d-oban-off-worker-/) |
| (manual) | PR #37 CI Group C partial — CLOAK_KEY env added to example_unit_smoke + example_http_smoke + example_playwright_smoke (3 of 6 jobs in Group C; the other 3 already had CLOAK_KEY and need separate diagnosis). Manual fix because gsd-sdk binary is broken (asdf shim → missing dist/cli.js). | 2026-05-02 | 5f32cfc | (no quick dir — manual) |

## Decisions

- Completed v1.21 milestone (2026-05-06) with all seven requirements substantively satisfied and reconciled.
- Opened v1.22 as a full end-to-end webhook milestone, not an infrastructure-only half-step.
- Phase numbering continues from Phase 96; `--reset-phase-numbers` not used.
- v1.22 is intentionally outbound-only: Sigra emits auth and identity events to downstream systems; inbound provider webhooks remain out of scope.
- The milestone includes generated admin UX in scope (Phase 99), not just library plumbing.
- Existing install-smoke todos remain tracked as context, not promoted into `WH-01..03`.

## Session Continuity

**Next:** `/gsd-discuss-phase 97` to sharpen the event catalog, payload contract, and signing / dispatch boundary before planning.

**Artifacts (active):** `.planning/PROJECT.md` (v1.22 milestone framing), `.planning/REQUIREMENTS.md` (`WH-01..03`), `.planning/ROADMAP.md` (Phases 97–99), `.planning/research/` (webhook design notes).

## Accumulated Context

### Pending Todos

- 2 pending todos in `.planning/todos/pending`
- 2026-04-30: Fix JOSE JWT warning surfaced by install smoke
- 2026-04-30: Stabilize generated-host Postgres connection usage in install smoke

**Planned Phase:** 97 — Webhook subscription registry + signed dispatcher contract.
