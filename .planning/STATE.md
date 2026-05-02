---
gsd_state_version: 1.0
milestone: v1.21
milestone_name: — active
status: "Phase 93 shipped — PR #37 (v1.21 batch)"
last_updated: "2026-05-02T18:24:30.095Z"
last_activity: 2026-05-02
progress:
  total_phases: 6
  completed_phases: 5
  total_plans: 26
  completed_plans: 33
  percent: 100
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**North star (milestones):** Prefer work that moves **North Star (milestones)** in `.planning/PROJECT.md` — production trust, integration path, DX.

**Current focus:** Phase 93 — m2m-service-account-tokens-b2b-03 verification

## Current Position

Milestone: **v1.21 B2B-ready & production-honest**

Phase: 93 (m2m-service-account-tokens-b2b-03) — PLANS COMPLETE, AWAITING VERIFICATION

Plan: 10/10 complete (gap-closure plans 06-10 just executed)

Status: Phase 93 shipped — PR #37 (v1.21 batch)

Last activity: 2026-05-02

## Decisions

- Completed v1.20 milestone (2026-04-28).
- Opened v1.21 with B2B trust + production hardening + API polish theme. Webhooks deferred to v1.22.
- v1.21 phase boundaries fixed at 6 phases (91–96) per the user-approved plan: one phase per REQ-ID except Phase 96 which bundles HARD-03 + API-01 (both narrow surface area on the dual-mode auth plug + OAuth callback).
- Phase numbering continues from Phase 90; `--reset-phase-numbers` not used.
- Phase 92 (B2B-02) is complete and verified.
- Phase 93 (B2B-03) is substantially implemented in the working tree, but the original plan's full closeout contract is not yet met; see `.planning/phases/93-m2m-service-account-tokens-b2b-03/93-VERIFICATION.md`.
- Phase 94 has local artifacts in the worktree but is not the active source of truth until Phase 93 closeout gaps are resolved or explicitly waived.
- Phase 95 is complete and verified.
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
- Removed all adapter branches from adjacent generator templates to enforce Postgres-only schemas across the board.

## Session Continuity

**Next:** Finish the remaining automated proof and generated-host contract gaps for Phase 93, then decide whether to advance to the parked Phase 94 work or explicitly down-scope the Phase 93 plan.

**Artifacts (active):** `.planning/PROJECT.md` (v1.21 Current Milestone block), `.planning/REQUIREMENTS.md` (REQ traceability), `.planning/ROADMAP.md` (Phases 91–96 detailed), `.planning/phases/93-m2m-service-account-tokens-b2b-03/93-01-SUMMARY.md` through `93-05-SUMMARY.md`, and `.planning/phases/93-m2m-service-account-tokens-b2b-03/93-VERIFICATION.md`.

## Accumulated Context

### Pending Todos

- 2 pending todos in `.planning/todos/pending`
- 2026-04-30: Fix JOSE JWT warning surfaced by install smoke
- 2026-04-30: Stabilize generated-host Postgres connection usage in install smoke

**Planned Phase:** 93 (M2M / service-account tokens (B2B-03)) — 10 plans — 2026-05-02T01:45:41.231Z
