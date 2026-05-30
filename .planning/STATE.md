---
gsd_state_version: 1.0
milestone: v1.31
milestone_name: DEMO-SHOWCASE
status: executing
last_updated: "2026-05-30T20:00:00.000Z"
last_activity: 2026-05-30 -- Phase 144.2 executed (commit 46cbc18)
progress:
  total_phases: 10
  completed_phases: 10
  total_plans: 24
  completed_plans: 24
  percent: 100
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Current focus:** Milestone complete

## Current Position

Phase: 144.2
Plan: 01
Status: Complete
Last activity: 2026-05-30 -- Phase 144.2 executed (commit 46cbc18)

```
Phase progress: [====================] 100% (10/10 phases)
```

## Accumulating Context

- `v1.31 DEMO-SHOWCASE` roadmap created 2026-05-29: 4 phases (141–144), 14/14 requirements mapped. Phase 141 Seed Data Layer (SEED-01..06, hard dependency for all later phases, owns full security posture) → Phase 142 Dev Credentials Page & App Framing (DEMO-01/DEMO-02, depends on 141) → Phase 143 Playwright Demo Spec & Screenshots (PW-01/PW-02/PW-03, depends on 141) → Phase 144 README Evaluator Lane & Docs/Proof (DOC-01/DOC-02/DOC-03, depends on 141 + 143). Seeds-first / proof-last invariant honored per SUMMARY.md firm ordering rule.
- Granularity config is "fine" but this is a low-net-new-code milestone (data + one dev LiveView + Playwright + docs). 4 phases map cleanly to natural delivery boundaries without artificial padding.
- Key architectural decisions locked in SUMMARY.md: no Faker dep (determinism); deterministic demo-only TOTP secret is acceptable behind the `Mix.env()==:test` guard; 6 persona roster (admin/alice/bob/carol/dave/frank); email domains `@demo.sigra.dev` (seeded) vs `@example.test` (golden-path) are an enforced invariant; Argon2 dev cost override `t_cost: 2, m_cost: 12` in `dev.exs` (not `t_cost: 1, m_cost: 8`).
- `v1.30 TRUST-HARDENING` shipped + archived 2026-05-29 (Phases 137–140, 11/11 requirements). Phase 141 continues the sequential numbering.

## Research Flags (Surface at Phase 141 Plan Time)

These require quick codebase confirmation before writing seed insert code — not pre-planning research, just spot-checks:

| Flag | What to Confirm | Impact if Wrong |
|------|-----------------|-----------------|
| `user_identities` schema fields | Exact column names for Carol's OAuth identity insert | Wrong column names cause compile/runtime failure on seed run |
| `EnterpriseConnection` schema shape | Required fields + column names for Acme Corp SSO row | Same — insert fails if fields are wrong |
| `Sigra.Testing.setup_totp/2` in dev | Whether the function is available outside `MIX_ENV=test` | If test-only, use direct `Repo.insert!` on `UserMfaCredential` instead |
| `UserPasskey.create_changeset/2` + Wax | Whether inserting a passkey display row triggers Wax ceremony validation | If yes, skip the passkey display row and note as deferred; avoid fabricated COSE key issues |

## Deferred Items

Items acknowledged and deferred at v1.30 milestone close on 2026-05-29 (non-blocking; carried forward):

| Category | Item | Status |
|----------|------|--------|
| todo | 2026-05-28-phase-135-review-deferred-findings.md | deferred — cross-milestone (v1.29/Phase 135), out of v1.30 scope; Threadline 0.6.0 vs `~> 0.5` pin + upstream generated-DDL concern |
| todo | 2026-05-29-deprecation-since-vs-removal-version-axis.md | deferred BY DESIGN — WR-01 resolved at v1.30 close to "accept + document"; tracking home for future `@doc since:` → Hex-axis re-keying |
| todo | 2026-05-29-phase-138-doctor-info-findings.md | deferred — Phase 138 Info findings IN-01/IN-02/IN-03; low-priority maintainability/doc/test-hygiene |

Items acknowledged and deferred OUT of v1.31 scope (see REQUIREMENTS.md Future Requirements):

| Category | Item | Status |
|----------|------|--------|
| feature | DEMO-03: in-app per-persona explainer banner | deferred — only affordance touching new LiveView beyond credentials page; DEMO-01 covers core need |
| feature | Playwright seeds-smoke with full persona CDP virtual-authenticator exercise | may land in Phase 143 if budget permits; otherwise post-milestone polish |
| feature | Carol OAuth row direct `user_identities` insert | deferred pending schema confirmation; Phase 141 research flag |

### Decisions

- **v1.31 roadmap (2026-05-29):** 4 phases derived from the natural delivery boundary implied by SUMMARY.md's firm ordering rule (seeds → evaluator affordances → Playwright → README/proof). Granularity config is "fine" but the milestone is intentionally low-net-new-code; 4 tight phases are the correct calibration over artificial padding.
- **Phase numbering:** continues from v1.30's Phase 140; v1.31 phases run 141–144.
- **Seeds-first invariant:** Phase 141 gates ALL later phases — it owns the security posture (Argon2id cost, `Mix.env()==:test` guard, `@demo.sigra.dev` domain segregation, idempotency). No other phase may touch seeded data before Phase 141 completes.
- **Playwright partition:** `demo-showcase` project partition is isolated from `chromium`/`mobile`/golden-path runs; never coupled to `mix test`. This preserves CI determinism.
- **No new Sigra library code:** this milestone adds to `test/example/` only (seeds, one LiveView, Playwright spec, README). Zero changes to `lib/sigra/`.
- **DEMO-03 deferred:** in-app persona banner overlay is the only affordance requiring new LiveView code beyond the credentials page; the DEMO-01 credentials cheat-sheet covers the core evaluator need. Deferred to post-milestone polish per REQUIREMENTS.md.

## Operator Next Steps

- Run `/gsd-plan-phase 141` to begin the Seed Data Layer phase

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

## Accumulated Context

### Roadmap Evolution

- Phase 144.1 inserted after Phase 144: Address tech debt: VALIDATION.md finalization + Dave credential clarity + spec comment (URGENT)
- Phase 144.2 inserted after Phase 144.1: Close minor integration debt: testInfo param + ga-evidence link (URGENT)
