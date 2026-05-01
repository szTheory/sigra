---
gsd_state_version: 1.0
milestone: v1.21
milestone_name: — active
status: executing
last_updated: "2026-05-01T17:01:14.506Z"
last_activity: 2026-05-01
progress:
  total_phases: 6
  completed_phases: 3
  total_plans: 16
  completed_plans: 21
  percent: 100
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**North star (milestones):** Prefer work that moves **North Star (milestones)** in `.planning/PROJECT.md` — production trust, integration path, DX.

**Current focus:** Phase 92 — rbac-seams-b2b-02

## Current Position

Milestone: **v1.21 B2B-ready & production-honest**

Phase: 92 (rbac-seams-b2b-02) — READY TO EXECUTE

Plan: 2 of 4

Status: Ready to execute

Last activity: 2026-05-01

## Decisions

- Completed v1.20 milestone (2026-04-28).
- Opened v1.21 with B2B trust + production hardening + API polish theme. Webhooks deferred to v1.22.
- v1.21 phase boundaries fixed at 6 phases (91–96) per the user-approved plan: one phase per REQ-ID except Phase 96 which bundles HARD-03 + API-01 (both narrow surface area on the dual-mode auth plug + OAuth callback).
- Phase numbering continues from Phase 90; `--reset-phase-numbers` not used.
- Phase 93 (B2B-03) is complete on disk and verified. Phase 92, 94, 95, and 96 are pending execution (previous broken executions were discarded).
- Kept delivery_mode :auto synchronous unless Oban is actually running, while explicit async boundaries enforce :async_email through Sigra.OptionalDeps.
- Moved the email worker to an always-defined module so missing Oban fails at first queue-backed use instead of via compile-time disappearance.
- Limited permissive missing-bcrypt behavior to no_user timing equalization; bcrypt hash verification and TOTP QR rendering now raise tagged missing-dependency errors.
- Kept mix sigra.doctor contextual: only enabled enforced optional deps can halt with status 2.
- Moved Joken/Bcrypt/EQRCode warning suppression to local module seams and reserved mix.exs global suppression for advisory or worker references.
- Added a compile-time host-proof warning macro in Sigra.Application instead of relying on speculative undefined-module warnings.
- Kept lifecycle workers always defined while guarding only Oban-specific entrypoints behind the compile-safe seam.
- Used dedicated dep-off CI jobs with real mix run assertions instead of a mandatory Joken-off lane.
- Routed maintainer and adopter optional-dependency diagnosis through mix sigra.doctor and the optional-until-enabled rule.
- Replace detect_adapter with a strict validate_supported_adapter! that halts execution immediately on unsupported adapters
- Update build_binding to receive adapter context directly from run/1 rather than internal lookup
- Replaced multi-adapter check tests with tests that ensure Postgres-specific configurations like citext remain intact.

## Session Continuity

**Next:** Execute `94-01-PLAN.md` to begin the Postgres-only declaration hardening work. Phase 95 is complete on disk with `95-04-SUMMARY.md`, `95-VALIDATION.md`, and `95-VERIFICATION.md` recorded.

**Artifacts (active):** `.planning/PROJECT.md` (v1.21 Current Milestone block), `.planning/REQUIREMENTS.md` (REQ traceability), `.planning/ROADMAP.md` (Phases 91–96 detailed). Phase 93 execution artifacts under `.planning/phases/93-m2m-service-account-tokens-b2b-03/` — see `93-VERIFICATION.md` for the goal-backward verdict.

## Accumulated Context

### Pending Todos

- 2 pending todos in `.planning/todos/pending`
- 2026-04-30: Fix JOSE JWT warning surfaced by install smoke
- 2026-04-30: Stabilize generated-host Postgres connection usage in install smoke
