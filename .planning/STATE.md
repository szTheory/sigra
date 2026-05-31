---
gsd_state_version: 1.0
milestone: v1.32
milestone_name: RELEASE-ADOPTION
status: executing
last_updated: "2026-05-31T21:12:18.286Z"
last_activity: 2026-05-31 -- Phase 148 planning complete
progress:
  total_phases: 5
  completed_phases: 3
  total_plans: 11
  completed_plans: 8
  percent: 60
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** Phase 148 — Evaluator Funnel And First-Run DX

## Current Position

Phase: 148 (Evaluator Funnel And First-Run DX) — READY TO PLAN
Plan: Not started
Status: Ready to execute
Last activity: 2026-05-31 -- Phase 148 planning complete

## Accumulating Context

- `v1.32 RELEASE-ADOPTION` roadmap created 2026-05-31: 5 phases (145–149), 20/20 requirements mapped. Phase 145 locks the public 1.0 contract and release truth; Phase 146 builds deterministic release gates and maintainer runbook; Phase 147 ships upgrade/migration lanes; Phase 148 tightens evaluator funnel and first-run DX; Phase 149 packages launch evidence and announcement materials.
- Phase 146 context gathered 2026-05-31 in assumptions mode: `.planning/phases/146-release-gate-and-maintainer-runbook/146-CONTEXT.md` locks release-ref gate truth, reuse of existing CI contracts as gate evidence, manual Hex publish recovery as the primary no-invention recovery path, a dedicated release-runbook/policy doc with `MAINTAINING.md` as pointer, first-14-day hotfix triage policy, and post-1.0 cleanup of the one-time Release Please `release-as: "1.0.0"` override.
- Phase 146 completed 2026-05-31: canonical CI can be manually dispatched only on `refs/tags/v*` for release evidence, Release Please and manual Hex publish both enforce version/ref/manifest/source-ref/package/visibility gates, `docs/release-runbook-v1-0.md` is the canonical runbook, and maintainer routers point to it. Verification scored 11/11 codebase must-haves with three live release UAT items tracked in `.planning/phases/146-release-gate-and-maintainer-runbook/146-HUMAN-UAT.md`.
- Phase 147 context gathered 2026-05-31 in assumptions mode: `.planning/phases/147-upgrade-and-migration-lanes/147-CONTEXT.md` locks the `upgrading-to-v1.0.md` operational guide shape, a dedicated `0.3.x` consumer-to-`1.0.0` candidate smoke lane, comparative boundary-first migration docs for `phx.gen.auth` and Pow/Guardian/Ueberauth, and discovery wiring through README, ExDoc, release/evidence docs, and `doc/llms.txt`.
- Phase 147 completed 2026-05-31: `scripts/ci/upgrade-smoke.sh` and `CI` / `upgrade_smoke` prove published-consumer upgrade posture, public upgrade and migration guides are wired through README/CHANGELOG/ExDoc/AI index/release evidence, code review is clean, and verification passed 9/9 must-haves. Review cleanup made the smoke lane source series configurable (`SIGRA_UPGRADE_SOURCE_SERIES`) so live Hex package truth can move beyond the historical v1.0 source series without stale docs.
- Phase 148 context gathered 2026-05-31 in assumptions mode: `.planning/phases/148-evaluator-funnel-and-first-run-dx/148-CONTEXT.md` locks the demo showcase as the canonical evaluator-first path, reuse of existing six-persona demo data and four committed screenshots, first-run `mix sigra.doctor` guidance, and a docs/assets/routing-only scope boundary that leaves DEMO-03 and Phase 149 launch packaging deferred.
- Phase 145 context gathered 2026-05-31 in assumptions mode: `.planning/phases/145-1-0-contract-and-release-truth/145-CONTEXT.md` locks direct Hex `1.0.0` from `main`, public version-axis messaging, canonical 1.0 contract surface, one-time Release Please `release-as: "1.0.0"` override, ownership boundaries, and security invariants/non-goals.
- Phase 145 Plan 01 completed 2026-05-31: `guides/introduction/contract.md` is the canonical public 1.0 contract, README/CHANGELOG route version-axis readers to it, SECURITY.md exposes invariants/non-goals, and `mix docs --warnings-as-errors` passes. Global `mix format --check-formatted` still reports unrelated pre-existing formatter drift outside Plan 01's write set.
- Phase 145 Plan 02 completed 2026-05-31: Release Please has the one-time `release-as: "1.0.0"` override, `.release-please-manifest.json` and `mix.exs` remain at last shipped/current `0.3.0`, maintainer docs explain the direct Hex 1.0 path and cleanup rule, and first-path install examples use `{:sigra, "~> 1.0"}` while companion pins remain unchanged. `mix docs --warnings-as-errors` and companion recipe contract tests pass; global formatter drift remains outside Plan 02's write set.
- Phase 145 post-review cleanup completed 2026-05-31: release contract docs, companion recipe links/examples, CHANGELOG compare/doc text, and Mailglass arity text were corrected; `.planning/phases/145-1-0-contract-and-release-truth/145-REVIEW.md` records a clean standard-depth review with 0 findings. Final verification also corrected a remaining introduction guide `Mailglass.deliver/2` reference to `Mailglass.deliver/1`.
- Phase 145 verification gap closure completed 2026-05-31: `guides/introduction/contract.md` now links to `SECURITY.md` from the security invariants section.
- Research consensus from `.planning/research/RELEASE-MECHANICS.md`, `ADOPTION-DX.md`, `ECOSYSTEM-BENCHMARKS.md`, `LOCAL-PROMPT-SYNTHESIS.md`, and `SUMMARY.md`: cut real Hex `1.0.0` directly from `main`, avoid a public RC train unless a concrete blocker appears, and keep v1.32 as release-truth/adoption work rather than new auth feature work.
- Selected scope: SemVer/public API contract, generated-host ownership contract, compatibility/support boundaries, release gate matrix, upgrade smoke, migration lanes, demo/evaluator funnel, announcement/evidence bundle, and first-14-day hotfix policy.
- Non-goals locked: no SCIM, hosted control plane, authorization engine, generic compliance platform, broad generated-host UI redesign, Mailglass adapter resurrection, public RC train by default, or new auth primitives.
- `v1.31 DEMO-SHOWCASE` roadmap created 2026-05-29: 4 phases (141–144), 14/14 requirements mapped. Phase 141 Seed Data Layer (SEED-01..06, hard dependency for all later phases, owns full security posture) → Phase 142 Dev Credentials Page & App Framing (DEMO-01/DEMO-02, depends on 141) → Phase 143 Playwright Demo Spec & Screenshots (PW-01/PW-02/PW-03, depends on 141) → Phase 144 README Evaluator Lane & Docs/Proof (DOC-01/DOC-02/DOC-03, depends on 141 + 143). Seeds-first / proof-last invariant honored per SUMMARY.md firm ordering rule.
- Granularity config is "fine" but this is a low-net-new-code milestone (data + one dev LiveView + Playwright + docs). 4 phases map cleanly to natural delivery boundaries without artificial padding.
- Key architectural decisions locked in SUMMARY.md: no Faker dep (determinism); deterministic demo-only TOTP secret is acceptable behind the `Mix.env()==:test` guard; 6 persona roster (admin/alice/bob/carol/dave/frank); email domains `@demo.sigra.dev` (seeded) vs `@example.test` (golden-path) are an enforced invariant; Argon2 dev cost override `t_cost: 2, m_cost: 12` in `dev.exs` (not `t_cost: 1, m_cost: 8`).
- `v1.30 TRUST-HARDENING` shipped + archived 2026-05-29 (Phases 137–140, 11/11 requirements). Phase 141 continues the sequential numbering.

## Research Flags

Surface these during v1.32 planning:

| Flag | What to Confirm | Impact if Wrong |
|------|-----------------|-----------------|
| Release Please 1.0 jump | Whether Release Please needs config or manual PR handling to jump from `0.3.0` to `1.0.0` cleanly | Wrong automation assumptions can produce `0.4.0` or malformed changelog/tag state |
| Hex publish dry-run | Exact package files, docs size, source links, and warnings from `mix hex.publish --dry-run` | Publish can fail late or ship stale/missing docs |
| Consumer upgrade smoke | Whether the latest published `0.3.x` posture can be simulated locally without requiring real Hex `1.0.0` | Upgrade gate may need path/source override design before release |
| Top-level docs IA | Exact README/ExDoc/Hex package entry points that need canonical first-path alignment | Adoption funnel can remain fragmented despite new docs |

## Deferred Items

Items deferred at v1.30 milestone close and resolved before v1.31 archive:

| Category | Item | Status |
|----------|------|--------|
| todo | 2026-05-28-phase-135-review-deferred-findings.md | resolved 2026-05-31 — Threadline demo caveats documented and moved to completed |
| todo | 2026-05-29-deprecation-since-vs-removal-version-axis.md | resolved 2026-05-31 — dual-axis decision documented; future re-key requires a new milestone item |
| todo | 2026-05-29-phase-138-doctor-info-findings.md | resolved 2026-05-31 — Doctor docs/comment/test cleanup landed and moved to completed |

Items acknowledged and deferred OUT of v1.31 scope (see REQUIREMENTS.md Future Requirements):

| Category | Item | Status |
|----------|------|--------|
| feature | DEMO-03: in-app per-persona explainer banner | deferred — only affordance touching new LiveView beyond credentials page; DEMO-01 covers core need |

### Decisions

- **v1.31 roadmap (2026-05-29):** 4 phases derived from the natural delivery boundary implied by SUMMARY.md's firm ordering rule (seeds → evaluator affordances → Playwright → README/proof). Granularity config is "fine" but the milestone is intentionally low-net-new-code; 4 tight phases are the correct calibration over artificial padding.
- **Phase numbering:** continues from v1.30's Phase 140; v1.31 phases run 141–144.
- **Seeds-first invariant:** Phase 141 gates ALL later phases — it owns the security posture (Argon2id cost, `Mix.env()==:test` guard, `@demo.sigra.dev` domain segregation, idempotency). No other phase may touch seeded data before Phase 141 completes.
- **Playwright partition:** `demo-showcase` project partition is isolated from `chromium`/`mobile`/golden-path runs; never coupled to `mix test`. This preserves CI determinism.
- **No new Sigra library code:** this milestone adds to `test/example/` only (seeds, one LiveView, Playwright spec, README). Zero changes to `lib/sigra/`.
- **DEMO-03 deferred:** in-app persona banner overlay is the only affordance requiring new LiveView code beyond the credentials page; the DEMO-01 credentials cheat-sheet covers the core evaluator need. Deferred to post-milestone polish per REQUIREMENTS.md.

## Operator Next Steps

- Plan Phase 148 with `/gsd-plan-phase 148`.

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
| Phase 139 P01 | 8min | 1 tasks | 1 files |
| Phase 139 P02 | 15min | 2 tasks | 3 files |
| Phase 140 P01 | 5min | 2 tasks | 2 files |
| Phase 140 P02 | 5min | 3 tasks | 3 files |
| Phase 140 P03 | 953 | 2 tasks | 3 files |
| Phase 147 P01 | 20min | 2 tasks | 2 files |

## Accumulated Context

### Roadmap Evolution

- v1.32 RELEASE-ADOPTION created after research-backed milestone selection. Five phases (145–149) map 20 requirements with zero unmapped requirements.
- Phase 144.1 inserted after Phase 144: Address tech debt: VALIDATION.md finalization + Dave credential clarity + spec comment (URGENT)
- Phase 144.2 inserted after Phase 144.1: Close minor integration debt: testInfo param + ga-evidence link (URGENT)
