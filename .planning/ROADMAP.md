# Roadmap: Sigra

**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Status:** Active milestone — **v1.43 STABILIZE** (Phases 213-215). Start planning with `/gsd-plan-phase 213`.

## Milestones

- 🔄 **v1.43 STABILIZE** — Phases 213-215 (in progress)
- ✅ **v1.42 ADMIN-DS-ELEVATION** — Phases 205-212 (shipped 2026-07-02) · full detail in milestones/v1.42-ROADMAP.md
- ✅ **v1.41 ADMIN-UX-ELEVATION** — Phases 199-204 (shipped 2026-06-27)
- ✅ **v1.40 CI-PERF** — Phases 193-198 (shipped 2026-06-21)
- ✅ **v1.39 DS-COHERENCE** — Phases 184-192 (shipped 2026-06-19)
- ✅ **v1.38 BRAND-V2** — Phases 178-183 (shipped 2026-06-13)
- ✅ **v1.37 AUTH-BRANDING-WHITELABEL** — Phases 173-177 (shipped 2026-06-07)
- ✅ **v1.36 ADMIN-BRAND-THEME-POLISH** — Phases 168-172 (shipped 2026-06-06)
- ✅ **v1.35 BRAND-SYSTEM-PRESSURE-TEST** — Phases 161-167 (shipped 2026-06-05)
- ✅ **v1.34 ADMIN-UI-COHERENCE** — Phases 154-160 (shipped 2026-06-05)
- ✅ **v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS** — Phases 150-153 (shipped 2026-06-02)

## Phases

### v1.43 STABILIZE

- [ ] **Phase 213: Latest-Phoenix Compatibility** — Fix generated-host compile failure against phx.new ≥1.8.8, reconcile golden fixture, drop the 1.8.7 CI pin
- [ ] **Phase 214: Debt & Robustness Clear** — Oban enqueue guard, deferred code-review items (phase-209, phase-200), Hex version-ranking wart, demo CSS corruption, and local test noise sources
- [ ] **Phase 215: Terminal Ratification** — Full library + example suites green, every required CI check passes, milestone closed with no blocking debt

<details>
<summary>✅ v1.42 ADMIN-DS-ELEVATION (Phases 205-212) — SHIPPED 2026-07-02 · full detail in milestones/v1.42-ROADMAP.md</summary>

- [x] **Phase 205: Foundation** — Adversarial persona/JTBD rubric, real-configuration `board-cfg-*` gallery, IA diagnostic, stress fixtures (4/4) — completed 2026-06-28
- [x] **Phase 206: L1 Component Elevation Wave A** — 8 highest-reuse L1 components to Tier-2 (4/4) — completed 2026-06-28
- [x] **Phase 207: L1 Component Elevation Wave B + L0 Token Layer** — remaining 5 L1 components + token layer to Tier-2 (4/4) — completed 2026-06-28
- [x] **Phase 208: L2 Meta-Component Group Elevation** — all 11 MG groups (MG-1…MG-11) to Tier-2 (208-03/GROUP-02 folded into 210-02) (3/3) — completed 2026-07-01
- [x] **Phase 208.1: v1.42 CI-Gate Remediation (INSERTED)** — fix ~15 never-CI-validated admin Playwright failures blocking the backlog ship (4/4) — completed 2026-07-01
- [x] **Phase 209: Judgment-Level Page Pass** — adversarial persona panel over all 8 pages; remediations under the monotonic guard (6/6) — completed 2026-07-01
- [x] **Phase 210: Remaining Cell Elevation** — user-sessions page + 3 persona flows to Tier-2 (2/2) — completed 2026-07-01
- [x] **Phase 211: Terminal Ratification** — every ledger cell reads 2, baselines recaptured, generated-host parity proven (5/5) — completed 2026-07-01
- [x] **Phase 212: v1.42 Integration Merge (INSERTED)** — canary reconciliation + gate persona flows + un-skip generated-host smoke; PR #63 merged to origin/main (4/4) — completed 2026-07-02

</details>

<details>
<summary>✅ v1.41 ADMIN-UX-ELEVATION (Phases 199-204) — SHIPPED 2026-06-27 · full detail in milestones/v1.41-ROADMAP.md</summary>

- [x] **Phase 199: Foundation** — Tier-2 scorecard & stress fixtures — completed 2026-06-25
- [x] **Phase 200: User Detail Elevation** — completed 2026-06-26
- [x] **Phase 201: Users Index Elevation** — completed 2026-06-26
- [x] **Phase 202: Audit Surfaces Elevation** — completed 2026-06-26
- [x] **Phase 203: Consistency Propagation** — completed 2026-06-26
- [x] **Phase 204: Terminal Ratification** — completed 2026-06-27

</details>

Earlier milestones (v1.33–v1.40) are archived under `milestones/`.

## Phase Details

### Phase 213: Latest-Phoenix Compatibility

**Goal**: Adopters using the latest `phx.new` (≥1.8.8) can install Sigra and compile their generated host without errors or warnings under `--warnings-as-errors`; CI tracks current Phoenix rather than a pinned archive.
**Depends on**: Nothing (first phase of this milestone)
**Requirements**: COMPAT-01, COMPAT-02, COMPAT-03
**Success Criteria** (what must be TRUE):

  1. A fresh `mix phx.new` (≥1.8.8) + `mix sigra.install` compiles clean under `--warnings-as-errors` — no `undefined attribute "type"` warning and no other 1.8.8 output-drift compile breakage.
  2. The install golden fixture and `golden_diff_test` pass without the `phx_new 1.8.7` archive — the `config/config.exs root_tag_attribute` byte-diff is correctly absorbed into the committed fixture.
  3. The `phx_new 1.8.7` pin is absent from all CI workflow files and from the CLAUDE.md dev-prereq note; the generated-host acceptance smoke runs against current `phx.new` and exits green.

**Plans**: 2/2 plans complete

- [x] 213-01-PLAN.md — Rebless the install golden fixture under phx.new ≥1.8.8; prove COMPAT-01/02 (golden_diff + install-smoke) [wave 1]
- [x] 213-02-PLAN.md — Flip all 11 archive pins to concrete 1.8.8 + rewrite docs/phase-198 test + add `--check` drift-detector + D-11 smoke version-asserts + acceptance smoke (COMPAT-03) [wave 2, depends on 213-01]

### Phase 214: Debt & Robustness Clear

**Goal**: Every tracked real-bug, robustness gap, and deferred code-review item from previous phases is resolved (or explicitly re-triaged with rationale), and local `mix test` output is a trustworthy release signal with no spurious failures.
**Depends on**: Phase 213
**Requirements**: DEBT-01, DEBT-02, DEBT-03, DEBT-04, DEBT-05, HEALTH-03
**Success Criteria** (what must be TRUE):

  1. Oban enqueue paths degrade safely when Oban is compiled but unsupervised or its table is absent — no `42P01` crash — with a regression test that proves the guard.
  2. The deferred phase-209 code-review items are closed: `panel-schema-check.sh` is either wired into CI or explicitly retired with rationale committed; remaining info nits are resolved.
  3. The deferred phase-200 code-review items are resolved or re-triaged with recorded rationale.
  4. The stray Hex `1.20.0` version-ranking wart is corrected so Sigra's version ordering is accurate.
  5. The demo `app.css` orphaned-comment corruption is removed and guarded against regression, so no CSS rule is silently dropped.
  6. A clean local `mix test` run has zero spurious non-product failures: the `Chimeway.Repo` missing-database startup noise and `Sigra.UpgradeIntegrationTest` env-DB failures are fixed or correctly gated.

**Plans**: 2/5 plans executed

Plans:

- [x] 214-01-PLAN.md — Add Sigra.OptionalDeps.oban_running?/0 SOT; fix deletion.ex bare guard; de-dupe delivery.ex and forwarders.ex; regression test [wave 1]
- [x] 214-02-PLAN.md — delete_session/3 user_id ownership guard (IDOR hardening); deny-path test; promote session render helpers to Sigra.Admin.Components; drop @return_to assign [wave 1]
- [ ] 214-03-PLAN.md — Clean orphaned :root value fragments from app.css; add CI corruption guard script; browser-parse verification [wave 1]
- [ ] 214-04-PLAN.md — Chimeway.Repo config-DB fix in config/test.exs; conditional upgrade test preflight skip in test_helper.exs [wave 1]
- [ ] 214-05-PLAN.md — Retire panel-schema-check.sh with rationale; delete git tag v1.20.0; correct contract.md:9 to 1.1.0; hex retire runbook [wave 1]

### Phase 215: Terminal Ratification

**Goal**: The full library and example suites are demonstrably green end-to-end, every required CI check passes on the milestone branch, and the milestone closes with all in-scope deferred-items reconciled and no new blocking debt.
**Depends on**: Phase 214
**Requirements**: HEALTH-01, HEALTH-02, HEALTH-04, RATIFY-01
**Success Criteria** (what must be TRUE):

  1. The full library test suite runs green against live Postgres, with the command and result recorded as the trustworthy release signal for this milestone.
  2. The example app test suite runs green against live Postgres with no failures.
  3. Every required CI check passes green end-to-end on the milestone branch (all lanes: library tests, dep-off, example Playwright smoke, design gallery, install/golden, fast checks, ci-gate).
  4. Every deferred-items-ledger entry pulled into this milestone is marked resolved; no new blocking debt is introduced; the milestone is closed cleanly.

**Plans**: TBD

## Progress (v1.43 STABILIZE)

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 213. Latest-Phoenix Compatibility | 2/2 | Complete    | 2026-07-02 |
| 214. Debt & Robustness Clear | 2/5 | In Progress|  |
| 215. Terminal Ratification | 0/? | Not started | - |

_Prior-milestone phase rows (v1.33–v1.42) live in each milestone's archived ROADMAP under `milestones/`._
