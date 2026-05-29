---
gsd_state_version: 1.0
milestone: v1.30
milestone_name: TRUST-HARDENING — Phases
status: executing
last_updated: "2026-05-29T14:39:48.748Z"
last_activity: 2026-05-29 -- Phase 137 execution started
progress:
  total_phases: 10
  completed_phases: 7
  total_plans: 16
  completed_plans: 16
  percent: 70
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** Phase 137 — optional-dependency-source-of-truth

## Current Position

Phase: 137 (optional-dependency-source-of-truth) — EXECUTING
Plan: 1 of 3
Status: Executing Phase 137
Resume file: .planning/phases/138-mix-sigra-doctor-operator-diagnostic/138-CONTEXT.md
Last activity: 2026-05-29 -- Phase 137 execution started
Progress: [____________________] 0/4 phases

## Accumulating Context

- `v1.30 TRUST-HARDENING` roadmap created 2026-05-29: 4 phases (137–140), 11/11 requirements mapped. Phase 137 `Sigra.OptionalDeps` SOT + guard consolidation (OD-01/OD-02) → Phase 138 `mix sigra.doctor` diagnostic (DR-01/DR-02, depends on 137) → Phase 139 recipe-contract fixture + Lockspire/Rulestead sister-repo verification (RCT-01/RCV-01/RCV-02, independent track, document-the-assumption fallback) → Phase 140 deprecation-removal timelines + verification + docs close (DEPR-01/DEPR-02/PROOF-01/DOC-01). Low-code consolidation milestone; honors the Diminishing Returns Wall.
- `v1.29 SUITE-INTEGRATION` shipped + archived 2026-05-29: Threadline audit forwarder (only new library code), six companion-lib recipes, suite narrative, `test/example/` demo, proof bundle + v1.25 Mailglass corrigendum. Milestone audit passed (16/16). Next milestone starts at Phase 137.
- `v1.28 DATA-LIFECYCLE` shipped 2026-05-27: versioned auth/account export, schedule/cancel/execute deletion semantics, generated-host parity, release-readiness proof.
- Roadmap is the lowest-code milestone in recent memory: exactly one new library module (`Sigra.Audit.Forwarders.Threadline` + behaviour + Noop + optional worker); everything else is recipes, narrative, and `test/example/` extension.
- Mailglass disposition is locked: recipe-only in v1.29; the orphaned Phase 111/114 library-resident adapter does NOT re-land here. Phase 136 DOC-01 corrigendum corrects the v1.25 narrative.
- `Sigra.OptionalDeps` SOT and `mix sigra.doctor` are both explicitly deferred out of v1.29; existing scattered-`Code.ensure_loaded?` precedent stands.
- Research basis: `.planning/research/SUMMARY.md` (HIGH confidence; verified against repo HEAD on `v1.28-data-lifecycle` and hex.pm on 2026-05-27).

## Deferred Items

Items acknowledged and deferred at v1.29 milestone close on 2026-05-29 (non-blocking; classified standing-posture by the passing v1.29 milestone audit):

| Category | Item | Status |
|----------|------|--------|
| todo | 2026-05-28-phase-134-recipe-residual-findings.md | deferred — WR-02/WR-05 sister-repo contract checks (lockspire `resolve_account/2` shape, rulestead `RulesteadPolicy @behaviour`) unverifiable without sister-repos in tree; verify-when-available |
| todo | 2026-05-28-phase-135-review-deferred-findings.md | deferred — Threadline 0.6.0 vs `~> 0.5` pin brings 3 migrations not 2 (API-compatible, tests green); upstream Threadline generated-DDL concern |
| standing | credo `--strict` 506 advisory issues in library code | deferred — pre-existing, non-CI-enforced (mix.exs:120 dev/test-only); 2 custom enforced checks pass; not v1.29-accrued |
| standing | Nyquist formal sign-off (131/134/135 draft, 132/133/136 N/A) | deferred — runtime coverage comprehensive (PROOF-01); consistent with project's retroactive-validation pattern |

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

- **Milestone-boundary assessment (2026-05-29, mid-v1.30):** repo-grounded done-band is **90–95% (near-done / diminishing returns soon)** for stated scope — every major auth flow is real + tested. **Adoption evidence is NOT a blocker**: the E2E / install-verification / happy-path automation backbone already exists and is strong. The one genuine gap is narrow — an empty `test/example/priv/repo/seeds.exs` and no evaluator-facing demo *showcase*. Recommended next build after v1.30 = **"Demo Showcase"** (seed-rich, persona-driven, one-command spin-up; extend `test/example/`, not a new repo), then **1.0 Hex cut + adoption push** (the honest bottleneck is absence of real adopters, not features). Full investigation: `.planning/threads/adoption-evidence-and-demo-showcase.md`; learnings + 2 graduation candidates in `137-LEARNINGS.md`.
- **STATE-vs-git drift note (2026-05-29):** the `## Current Position` progress block below ("Plan 1 of 3", "0/4 phases") is stale — git log shows Phase 137 plans 137-02 and 137-03 already merged (`eb64903`, `a945a9b`, `523b631`), so Phase 137 is largely executed. STATE.md is the lowest-precedence session-handoff doc; trust git/ROADMAP. (Block left intact per assessment scope — corrective note only.) Working branch name `v1.28-data-lifecycle` is also stale vs active milestone v1.30.
- Created the `v1.30 TRUST-HARDENING` roadmap on 2026-05-29: Phases 137–140, continuing from v1.29's Phase 136. Derived 4 phases (favoring tight consolidation over `fine`-granularity sprawl) from the 11 requirements. Sequencing honors OD-before-doctor (Phase 137 feeds Phase 138), keeps recipe-contract/sister-repo work an independent track (Phase 139), and bundles deprecation hygiene + PROOF-01 + DOC-01 into the final close (Phase 140) per prior-milestone precedent (v1.28 Phase 130, v1.29 Phase 136).
- Phase 139 carries the document-the-assumption fallback for RCV-01/RCV-02 so unavailable sister repos cannot hard-block the milestone.
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

- Start the next milestone with /gsd:new-milestone

### Blockers

- None.

### Quick Tasks Completed

| # | Description | Date | Commit | Directory |
|---|-------------|------|--------|-----------|
| 260527-bsd | Reconcile Phase 130 PROOF-01: capture fresh `mix docs --warnings-as-errors` evidence and flip v1.28 milestone to passed | 2026-05-27 | 111e024 | [260527-bsd-reconcile-phase-130-proof-01](./quick/260527-bsd-reconcile-phase-130-proof-01/) |
| 260528-nwa | Fix RC-01 (threadline.md forwarders block: `endpoint:`/`api_key:` → `repo:`, DB-based failure framing) + CR-01 (accrue.md & audit-logging.md: non-existent `log/1`/`log/3` → real `log/2`) — v1.29 milestone-audit gaps | 2026-05-28 | 350ba24 | [260528-nwa-fix-rc-01-in-guides-recipes-companion-li](./quick/260528-nwa-fix-rc-01-in-guides-recipes-companion-li/) |
| 260528-sbn | Fix v1.29 doc debt from milestone audit: mailglass.md corrigendum pointer (stale "planned for Phase 136" → landed in CHANGELOG.md) + recipe `{:sigra, "~> 1.29"}` → `~> 0.2` (7 occurrences, IN-01) + AGENTS.md migration count verify (already "Three", no-op) | 2026-05-29 | 81b8a65 | [260528-sbn-fix-v1-29-doc-debt-mailglass-corrigendum](./quick/260528-sbn-fix-v1-29-doc-debt-mailglass-corrigendum/) |
| 260529-pgx | Drop the unnecessary `PGUSER=… PGPASSWORD=… PGHOST=… MIX_ENV=test` prefix from the CLAUDE.md test-invocation note — plain `mix test` works (test repo + install-golden fixture default to postgres/postgres/localhost; override via `SIGRA_TEST_PG_*`, not libpq `PG*`) | 2026-05-29 | fa104ee | — |

## Performance Metrics

| Phase | Plan | Duration | Notes |
|-------|------|----------|-------|
| Phase 130 P01 | 605s | 3 tasks; PROOF-01 release-blocked on mix docs --warnings-as-errors; unblocked by quick task 260527-bsd via commit 110a560. |
