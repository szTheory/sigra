---
gsd_state_version: 1.0
milestone: v1.21
milestone_name: — active
status: executing
last_updated: "2026-04-30T21:08:20.428Z"
last_activity: 2026-04-30
progress:
  total_phases: 6
  completed_phases: 4
  total_plans: 25
  completed_plans: 23
  percent: 92
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**North star (milestones):** Prefer work that moves **North Star (milestones)** in `.planning/PROJECT.md` — production trust, integration path, DX.

**Current focus:** Phase 95 — optional-dep-boot-validation-mix-sigra-doctor-hard-02

## Current Position

Milestone: **v1.21 B2B-ready & production-honest**

Phase: 95 (optional-dep-boot-validation-mix-sigra-doctor-hard-02) — EXECUTING

Plan: 2 of 4

Status: Ready to execute

Last activity: 2026-04-30

## Decisions

- Completed v1.20 milestone (2026-04-28).
- Opened v1.21 with B2B trust + production hardening + API polish theme. Webhooks deferred to v1.22.
- v1.21 phase boundaries fixed at 6 phases (91–96) per the user-approved plan: one phase per REQ-ID except Phase 96 which bundles HARD-03 + API-01 (both narrow surface area on the dual-mode auth plug + OAuth callback).
- Phase numbering continues from Phase 90; `--reset-phase-numbers` not used.
- Phase 93 (B2B-03) is complete on disk and verified locally, but not yet committed from this workspace snapshot.
- Kept delivery_mode :auto synchronous unless Oban is actually running, while explicit async boundaries enforce :async_email through Sigra.OptionalDeps.
- Moved the email worker to an always-defined module so missing Oban fails at first queue-backed use instead of via compile-time disappearance.
- Limited permissive missing-bcrypt behavior to no_user timing equalization; bcrypt hash verification and TOTP QR rendering now raise tagged missing-dependency errors.

## Session Continuity

**Next:** Start Phase 94 discussion/planning (`$gsd-discuss-phase 94`). Phase 94 (Postgres-only declaration) is the next roadmap item; Phases 95 and 96 remain independently plannable after that. Before any ship/merge step, the current dirty Phase 93 batch still needs commit hygiene.

**Artifacts (active):** `.planning/PROJECT.md` (v1.21 Current Milestone block), `.planning/REQUIREMENTS.md` (REQ traceability), `.planning/ROADMAP.md` (Phases 91–96 detailed). Phase 93 execution artifacts under `.planning/phases/93-m2m-service-account-tokens-b2b-03/` — see `93-VERIFICATION.md` for the goal-backward verdict.

## Accumulated Context

### Pending Todos

- 2 pending todos in `.planning/todos/pending`
- 2026-04-30: Fix JOSE JWT warning surfaced by install smoke
- 2026-04-30: Stabilize generated-host Postgres connection usage in install smoke
