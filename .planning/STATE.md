---
gsd_state_version: 1.0
milestone: v1.29
milestone_name: SUITE-INTEGRATION
status: verifying
last_updated: "2026-05-28T14:07:28.234Z"
last_activity: 2026-05-28
progress:
  total_phases: 6
  completed_phases: 4
  total_plans: 9
  completed_plans: 9
  percent: 67
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** Phase 134 — recipe-only-companion-libraries

## Current Position

Phase: 134 (recipe-only-companion-libraries) — EXECUTING
Plan: 1 of 1
Status: Phase complete — ready for verification
Last activity: 2026-05-28
Resume file: None

## Accumulating Context

- `v1.28 DATA-LIFECYCLE` shipped 2026-05-27: versioned auth/account export, schedule/cancel/execute deletion semantics, generated-host parity, release-readiness proof.
- v1.29 SUITE-INTEGRATION is now active. Phases continue from 131 (no reset).
- Roadmap is the lowest-code milestone in recent memory: exactly one new library module (`Sigra.Audit.Forwarders.Threadline` + behaviour + Noop + optional worker); everything else is recipes, narrative, and `test/example/` extension.
- Mailglass disposition is locked: recipe-only in v1.29; the orphaned Phase 111/114 library-resident adapter does NOT re-land here. Phase 136 DOC-01 corrigendum corrects the v1.25 narrative.
- `Sigra.OptionalDeps` SOT and `mix sigra.doctor` are both explicitly deferred out of v1.29; existing scattered-`Code.ensure_loaded?` precedent stands.
- Research basis: `.planning/research/SUMMARY.md` (HIGH confidence; verified against repo HEAD on `v1.28-data-lifecycle` and hex.pm on 2026-05-27).

## Deferred Items

Items acknowledged and deferred at v1.26 milestone close on 2026-05-25 (still pending after v1.28; promoted into v1.29 active scope):

| Category | Item | Status |
|----------|------|--------|
| todo | 2026-05-08-write-accrue-integration-recipe.md | promoted → Phase 134 (RC-03) |
| todo | 2026-05-08-write-lockspire-integration-recipe.md | promoted → Phase 134 (RC-04) |
| todo | 2026-05-08-write-relyra-integration-recipe.md | promoted → Phase 134 (RC-05) |
| todo | 2026-05-08-write-rulestead-integration-recipe.md | promoted → Phase 134 (RC-06) |
| todo | 2026-05-08-write-threadline-integration-recipe.md | promoted → Phase 132 (RC-01) |
| seed | SEED-011-ecosystem-integrations | active — backing v1.29 SUITE-INTEGRATION |

Items explicitly deferred OUT of v1.29 (to a separate quick task or v1.30+):

| Category | Item | Status |
|----------|------|--------|
| refactor | `Sigra.OptionalDeps` SOT consolidation | deferred (no v1.29 trigger; existing scattered guards sound) |
| task | `mix sigra.doctor` adopter-facing diagnostic | deferred (referenced in v1.21 HARD-02 narrative but never shipped) |
| recovery | Re-land orphaned Phase 111/114 Mailglass adapter | deferred (separate quick task; current call: drop orphaned work) |
| differentiator | Threadline correlation-ID propagation | deferred (v1.30 candidate) |
| differentiator | Recipe-contract test fixtures | deferred unless Phase 134 has budget |

### Decisions

- Shipped `v1.28 DATA-LIFECYCLE` on 2026-05-27 with four phases: versioned export, deletion lifecycle truth, generated-host/docs parity, and verification/release readiness.
- Opened `v1.29 SUITE-INTEGRATION` on 2026-05-27. Phases 131-136. 16 REQ-IDs across Threadline forwarder library code (TL-01..TL-05, FB-01), recipes (RC-01..RC-06), suite narrative (NX-01), reference example (EX-01), and verification + corrigendum (PROOF-01, DOC-01).
- Adopted ARCHITECTURE.md's `Sigra.Audit.Forwarders.Threadline` naming over STACK.md's `Sigra.Audit.Adapters.Threadline` — "Forwarders" correctly signals "Sigra DB row remains source-of-truth; Threadline is a projection."
- Adopted `guides/recipes/companion-libs/<name>.md` subdir convention (new ExDoc "Companion Libraries" group) over flat `guides/recipes/`.
- Adopted "extend `test/example/`" over "new top-level `examples/` directory" — Phase 114 already paid the cost of closing nested-example-app drift; existing CI lanes cover it.
- Adopted scattered-`Code.ensure_loaded?` precedent for Threadline optional-dep handling; deferred the `Sigra.OptionalDeps` SOT module to a separate refactor.
- Locked Mailglass posture for v1.29 as **recipe-only**: do NOT re-land the orphaned Phase 111/114 adapter; Phase 136 DOC-01 corrigendum corrects the v1.25 EMAIL-RAILS narrative claim.
- Treated `--with-threadline` (and any `--with-*`) install flag as out of scope — no precedent in `lib/mix/tasks/sigra.install.ex`.
- Kept all six companion-lib recipes under a uniform template: `validated_against:` + `last_validated:` frontmatter, `mix.exs` snippet, "Failure modes" section, "Non-goals" section, "Sigra works fully standalone" banner.

## Operator Next Steps

- Plan Phase 131 with `/gsd-plan-phase 131`: forwarder behaviour + Threadline impl + Noop fallback + optional Oban worker + boundary doctrine.
- Phases 132 → 136 execute in order after 131; Phase 134 may parallelize with Phase 133 if planning budget allows.

### Blockers

- None.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260527-bsd | Reconcile Phase 130 PROOF-01: capture fresh `mix docs --warnings-as-errors` evidence and flip v1.28 milestone to passed | 2026-05-27 | 111e024 | [260527-bsd-reconcile-phase-130-proof-01](./quick/260527-bsd-reconcile-phase-130-proof-01/) |

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 130 P01 | 605s | 3 tasks; PROOF-01 release-blocked on mix docs --warnings-as-errors; unblocked by quick task 260527-bsd via commit 110a560. |
