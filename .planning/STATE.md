---
gsd_state_version: 1.0
milestone: v1.21
milestone_name: — shipped (between milestones)
status: "v1.21 archived 2026-05-06 — ready for /gsd-new-milestone"
last_updated: "2026-05-06T00:00:00.000Z"
last_activity: 2026-05-06
progress:
  total_phases: 6
  completed_phases: 6
  total_plans: 26
  completed_plans: 33
  percent: 100
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**North star (milestones):** Prefer work that moves **North Star (milestones)** in `.planning/PROJECT.md` — production trust, integration path, DX.

**Current focus:** Between milestones — `/gsd-new-milestone` to start the next cycle (webhooks `WH-01..03` is the leading deferred-from-v1.21 candidate for v1.22)

## Current Position

Milestone: **v1.21 — SHIPPED 2026-05-06**, archived to `.planning/milestones/v1.21-*`

Phases: 91, 92, 93, 94, 95, 96 all VERIFIED. See [milestones/v1.21-MILESTONE-AUDIT.md](milestones/v1.21-MILESTONE-AUDIT.md).

Status: Audit passed (substantive 7/7); REQUIREMENTS.md / ROADMAP.md / phase verifications reconciled 2026-05-06.

Last activity: 2026-05-06 — v1.21 milestone audit + bookkeeping reconciliation (HARD-01/HARD-03/API-01 promoted to Complete; Phase 94 stale env caveat closed; SUMMARY/VERIFICATION frontmatter cleanup across 91/94/96).

Open tech debt at milestone close (non-blocking):
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

- Completed v1.20 milestone (2026-04-28).
- Opened v1.21 with B2B trust + production hardening + API polish theme. Webhooks deferred to v1.22.
- v1.21 phase boundaries fixed at 6 phases (91–96) per the user-approved plan: one phase per REQ-ID except Phase 96 which bundles HARD-03 + API-01 (both narrow surface area on the dual-mode auth plug + OAuth callback).
- Phase numbering continues from Phase 90; `--reset-phase-numbers` not used.
- Phase 91 (B2B-01) is complete and verified — full library suite green (2214 tests).
- Phase 92 (B2B-02) is complete and verified — 5/5 must-haves.
- Phase 93 (B2B-03) is complete and re-verified 2026-05-02 (22/22 after gap-closure commit `bf5a8a8`).
- Phase 94 (HARD-01) is complete and verified; the original "environmental Oban-test caveat" was confirmed closed in the 2026-05-06 milestone audit.
- Phase 95 (HARD-02) is complete and verified.
- Phase 96 (HARD-03 + API-01) is complete and verified — 122 passing tests across OAuth refresh, rate-limit headers, generator wiring, and example-app wire-test.
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

**Next:** `/gsd-complete-milestone v1.21` to archive v1.21 and start the v1.22 milestone cycle. Audit verdict: tech_debt → reconciled → ready for close. Optional pre-close: `/gsd-validate-phase` for 91/92/93/94/96 to fill Nyquist gaps.

**Artifacts (active):** `.planning/v1.21-MILESTONE-AUDIT.md` (the close-out audit), `.planning/PROJECT.md` (v1.21 Current Milestone block), `.planning/REQUIREMENTS.md` (REQ traceability — all 7 Complete), `.planning/ROADMAP.md` (Phases 91–96 all [x]), `.planning/phases/9{1,2,3,4,5,6}-*/` VERIFICATION.md (all six phases verified).

## Accumulated Context

### Pending Todos

- 2 pending todos in `.planning/todos/pending`
- 2026-04-30: Fix JOSE JWT warning surfaced by install smoke
- 2026-04-30: Stabilize generated-host Postgres connection usage in install smoke

**Planned Phase:** none — v1.21 milestone close pending. Run `/gsd-complete-milestone v1.21`.
