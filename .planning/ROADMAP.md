# Roadmap: Sigra

**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Status:** v1.40 CI-PERF in planning (phases 193+). Prior milestone v1.39 DS-COHERENCE shipped 2026-06-19 (phases 184-192). Hex: `v1.1.0`.

## Milestones

- 🔜 **v1.40 CI-PERF** — Phases 193-198 (in planning)
- ✅ **v1.39 DS-COHERENCE** — Phases 184-192 (shipped 2026-06-19)
- ✅ **v1.38 BRAND-V2** — Phases 178-183 (shipped 2026-06-13)
- ✅ **v1.37 AUTH-BRANDING-WHITELABEL** — Phases 173-177 (shipped 2026-06-07)
- ✅ **v1.36 ADMIN-BRAND-THEME-POLISH** — Phases 168-172 (shipped 2026-06-06)
- ✅ **v1.35 BRAND-SYSTEM-PRESSURE-TEST** — Phases 161-167 (shipped 2026-06-05)
- ✅ **v1.34 ADMIN-UI-COHERENCE** — Phases 154-160 (shipped 2026-06-05)
- ✅ **v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS** — Phases 150-153 (shipped 2026-06-02)

## Phases

### 🔜 v1.40 CI-PERF (Phases 193-198) — IN PLANNING

**Milestone Goal:** Cut PR CI wall-clock from ~22m toward well under ~12m on a fast PR path by attacking the three long poles (`example_playwright_smoke` 22.2m, `library_tests` 15.9m, `library_tests_dep_off` 13.9m) — **without** weakening coverage, determinism, or trust. A maintenance/trust (CI/DX) lane, not a feature milestone. Source of truth: `SEED-005` (grounded baseline + verbatim audit playbook) + `SEED-006` (design-gallery CI fragility).

**Design principles:** Measure-before-optimize (Phase 193 captures the baseline; every later phase re-measures against it). Sequence smallest-safest-first (the gratuitous `needs` edge and the rgb flake are near-one-line wins, banked in Phase 193). Each phase ships as its own independently reversible PR mirroring the SEED's stepwise PR ordering. Zero-human-UAT: verification is the CI pipeline measuring itself (before/after timings, cache hit-rate, flake/rerun rate). Every phase keeps the `ci-gate` required check + stable child-check names (no branch-protection churn). Respect SEED-004 (phx_new 1.8.7 pin) and snapshot/baseline determinism.

**Requirement coverage:** All 18 v1.40 requirements (BASE-01..03, CRIT-01..03, TEST-01..03, PW-01..03, CACHE-01..03, DX-01, FLAKE-01, GATE-01..02) mapped to exactly one phase across 193-198.

- [x] **Phase 193: Baseline, Observability & One-Line Wins** — capture the before-state baseline + Elixir diagnostics, add CI job-summary observability, then bank the two cheapest wins (drop the gratuitous `needs` edge; fix the rgb flake). Covers BASE-01, BASE-02, BASE-03, CRIT-01, FLAKE-01. (completed 2026-06-20)
- [ ] **Phase 194: Caching Correctness & Micro-Job Consolidation** — precise cache keys, no stale `_build` reuse across incompatible combos, separated deps/PLT caches, documented busting; fold the trivial guard jobs into one cheap "fast checks" job. Covers CACHE-01, CACHE-02.
- [x] **Phase 195: Test-Suite Performance (partition / async / dep-off slim)** — partition `library_tests` across DB-isolated shards, audit/convert `async: true`, slim the dep-off full rerun to a targeted subset, apply larger runners selectively only if measurement justifies. Covers TEST-01, TEST-02, TEST-03, CACHE-03. (completed 2026-06-20)
- [ ] **Phase 196: PR-Fast vs Nightly-Broad Trigger Model** — move exhaustive/low-probability coverage (install matrix ×4, upgrade smoke, broad galleries) off the every-PR path to a `schedule:`/main lane, keep a fast representative PR gate, never strand a correctness-critical test on nightly — all under a single stable `ci-gate` required check with stable child-check names. Covers CRIT-02, CRIT-03.
- [ ] **Phase 197: Playwright Lanes & Design-Gallery Re-Gate** — reduce the Playwright critical path (boot-sharing/sharding so an early-step failure no longer masks later steps), make readiness deterministic (no `Process.sleep`), and re-gate the `continue-on-error` admin-design gallery by fixing the systemic font-reflow height delta (deterministic CI webfont + in-CI baseline recapture) — folding in SEED-006. Covers PW-01, PW-02, PW-03.
- [ ] **Phase 198: Contributor DX & Acceptance Gate** — ship a documented local CI equivalent (`mix ci`) in CONTRIBUTING, then prove the milestone-level acceptance: measured before/after PR wall-clock + p95 meaningfully faster with equal-or-greater quality signal, no flake introduced, no correctness-critical coverage dropped, required-check names stable. Covers DX-01, GATE-01, GATE-02.

## Phase Details

### Phase 193: Baseline, Observability & One-Line Wins

**Goal**: A committed before-state baseline exists so every later phase can prove its win — and the two cheapest, lowest-risk wall-clock wins are already banked.
**Depends on**: Nothing (first phase of milestone)
**Requirements**: BASE-01, BASE-02, BASE-03, CRIT-01, FLAKE-01
**Key tasks**:

  - Build the before-state baseline table from `.github/workflows/ci.yml` + recent runs (per-job duration, p95, critical path, cache hit/miss, required-vs-not, quality signal, likely bottleneck); commit as a planning artifact (BASE-01).
  - Collect Elixir-side diagnostics as the optimization target: `mix test --slowest`, `System.schedulers_online()` on the runner, top slow compile modules (BASE-02).
  - Add CI job-summary observability surfacing resolved Elixir/OTP versions, cache hit/miss, and a test-timing summary so future regressions stay visible (BASE-03).
  - Drop the gratuitous `example_playwright_smoke needs: [library_tests]` edge (keep `release_ref_guard`) so the two longest jobs stop running sequentially (CRIT-01).
  - Fix the known-flaky demo-showcase remember-checkbox accent-color (off-by-one rgb) assertion — de-flake or delete, no blanket retries (FLAKE-01).

**Success Criteria** (what must be TRUE):

  1. A committed baseline artifact records per-job durations, the critical path, cache hit/miss, and required-vs-not for every CI job — the reference every later phase measures against.
  2. CI run summaries now show resolved versions, cache hit/miss, and a test-timing/slowest-tests summary.
  3. `example_playwright_smoke` no longer waits on `library_tests`; the two long poles run concurrently and measured wall-clock drops toward the `library_tests` time.
  4. The demo-showcase remember-checkbox color assertion is deterministic (or removed) with no retry papering-over, and the tracked todo is closed.

**Verification mechanism (zero-human-UAT)**: CI measures itself — the post-change run's wall-clock/critical-path is compared against the committed baseline; the de-flaked spec runs green across repeated CI runs without retries.
**Plans**: 3 plans

- [x] 193-01-PLAN.md — Capture before-state CI baseline + Elixir diagnostics (BASE-01, BASE-02)
- [x] 193-02-PLAN.md — De-flake demo-showcase color assertion + close todo (FLAKE-01)
- [x] 193-03-PLAN.md — Add CI step-summary observability + drop gratuitous needs edge (BASE-03, CRIT-01)

### Phase 194: Caching Correctness & Micro-Job Consolidation

**Goal**: Caching is correct and observable (no stale-artifact correctness risk), and per-job runner-startup overhead from trivial guard jobs is eliminated — without losing any required-check name.
**Depends on**: Phase 193 (baseline + observability in place to measure cache hit-rate and per-job overhead before/after)
**Requirements**: CACHE-01, CACHE-02
**Key tasks**:

  - Audit and correct caching: precise keys (OS/arch/OTP/Elixir/MIX_ENV/lockfile/buster), no `_build` reuse across incompatible combos, never skip `deps.get` after a partial restore, separate deps cache from any PLT cache, document how to bust (CACHE-01).
  - Consolidate the trivial micro-guard jobs (`release_ref_guard`, `milestone_verification_gate`, `installer_milestone_audit`, `getting_started_uat_contract`, `phase_34_uat_contract`, `snapshot_drift_guard`, `quality_ledger_monotonic`) into one cheap "fast checks" job, preserving stable required-check names (CACHE-02).

**Success Criteria** (what must be TRUE):

  1. Cache keys are precise and documented; a cache restore never reuses `_build` across incompatible OTP/Elixir/MIX_ENV combos, and `deps.get` always runs after a partial restore.
  2. Cache hit-rate is visible in CI summaries and measurably stable/improved vs the Phase 193 baseline.
  3. The trivial guard jobs run in a single consolidated "fast checks" job, cutting aggregate runner-startup overhead, with every previously-required child-check name still reported.
  4. `ci-gate` remains the single required check and still aggregates the same lane results.

**Verification mechanism (zero-human-UAT)**: CI measures itself — cache hit/miss and per-job counts/overhead from CI summaries compared against the Phase 193 baseline; `ci-gate` child-check names diffed for stability.

> **Reconciliation note (D-15):** Success Criterion #4 above ("`ci-gate` remains the single required check") reflects an outdated premise. The live ruleset 14941512 enforces **5 lane `name:` strings** as the required checks (`Library tests`, `Example unit smoke (ExUnit + ConnTest)`, `Install smoke (fresh phx.new + sigra.install)`, `Example HTTP smoke (boot + curl critical routes)`, `Example Playwright smoke (full lifecycle)`); `ci-gate` is an internal aggregator, NOT an enforced required check. Honest closure verifies the 5 names stay byte-identical AND `ci-gate` keeps aggregating an equal-or-greater result set.

**Plans**: 2 plans

- [x] 194-01-PLAN.md — CACHE-01: precision cache keys (OS+OTP+Elixir+MIX_ENV+lockfile+`-v1` buster) on all 11 deps+`_build` blocks, cache-hit observability, bust doc
- [x] 194-02-PLAN.md — CACHE-02: fold 6 leaf guards into one `fast_checks` job, rewire `ci-gate`, reconcile required-check docs

### Phase 195: Test-Suite Performance (partition / async / dep-off slim)

**Goal**: The two heaviest Elixir test poles (`library_tests`, `library_tests_dep_off`) are meaningfully faster through evidence-chosen partitioning, broader safe concurrency, and a targeted dep-off subset — with identical quality signal.
**Depends on**: Phase 193 (slowest-tests + schedulers diagnostics), Phase 194 (correct per-combo caching so partition shards cache safely)
**Requirements**: TEST-01, TEST-02, TEST-03, CACHE-03
**Key tasks**:

  - Partition `library_tests` via `mix test --partitions N` across parallel shards, each with an isolated Postgres database; merge coverage if applicable; choose N from BASE-02 evidence (don't oversubscribe the 2-core runner) (TEST-01).
  - Slim `library_tests_dep_off`: run a targeted subset that exercises the Threadline-absent compile/guard paths instead of re-running the full ~14m suite (TEST-02).
  - Audit `async: true` coverage: convert safe modules, split oversized serial modules, never mark a global-state-mutating test async; keep sandbox/pool config correct under partitioning (TEST-03).
  - Apply larger runners selectively to long poles only if measurement justifies the cost/speed tradeoff — not by default (CACHE-03).

**Success Criteria** (what must be TRUE):

  1. `library_tests` runs as evidence-chosen parallel partitions with isolated per-shard Postgres databases; the same set of tests pass and any coverage merge is correct.
  2. `library_tests_dep_off` proves the Threadline-absent compile/guard paths via a targeted subset and is materially faster than the prior full-suite rerun.
  3. Newly-async modules are async-safe (no global-state mutation marked async) and the sandbox/pool config is correct under partitioning — no flake introduced.
  4. Any larger-runner usage is justified by a recorded before/after measurement, or not used.

**Verification mechanism (zero-human-UAT)**: CI measures itself — partitioned/slimmed job durations and pass counts compared against the Phase 193 baseline; repeated runs confirm no new flake under concurrency.
**Plans**: 3 plans
**Wave 1**

- [x] 195-01-PLAN.md — Tag `:threadline_guard` guard subset + `mix sigra.dep_off` alias + 2 safe async flips + async-safety checklist (TEST-02, TEST-03)
- [x] 195-02-PLAN.md — Partition `library_tests` into matrix shards + name-preserving aggregator + relocate `mix docs` (TEST-01)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 195-03-PLAN.md — Slim `library_tests_dep_off` to the tagged subset + CACHE-03 measurement-gate runbook (TEST-02, CACHE-03)

### Phase 196: PR-Fast vs Nightly-Broad Trigger Model

**Goal**: Every-PR cost is reduced to a fast representative gate while exhaustive/low-probability coverage still runs (on `schedule:`/main), with a single stable required check and no correctness-critical test stranded on nightly only.
**Depends on**: Phase 193 (baseline classifies which lanes are exhaustive/low-probability), Phase 195 (fast test poles make the PR gate genuinely fast)
**Requirements**: CRIT-02, CRIT-03
**Key tasks**:

  - Establish a PR-fast vs nightly/main-broad split: move the install matrix (×4), upgrade smoke, and broad galleries off the every-PR path to a `schedule:`/main lane; keep a fast representative PR gate. Never strand a correctness-critical test on nightly only (CRIT-02).
  - Preserve a single stable required check (`ci-gate` aggregator) and stable child-check names across the redesign — no branch-protection churn, no path/skip pending-check traps (CRIT-03).

**Success Criteria** (what must be TRUE):

  1. The every-PR path runs a fast representative gate; exhaustive coverage (install matrix ×4, upgrade smoke, broad galleries) runs on a `schedule:`/main lane instead.
  2. No correctness-critical test lives only on nightly — each is covered by either the PR gate or a representative PR-path proxy, with the rationale recorded.
  3. `ci-gate` remains the single required check with stable child-check names; no required check can be left pending by path/skip filtering.
  4. Measured PR-path wall-clock drops vs the Phase 193 baseline with equal-or-greater PR-gate quality signal.

**Verification mechanism (zero-human-UAT)**: CI measures itself — PR-path vs nightly-path job inventories and wall-clock compared against baseline; `ci-gate` required/child-check names diffed for stability; a forced-failure probe confirms the nightly lane still fails on a real regression.
**Plans**: 4 plans
**Wave 1**

- [x] 196-01-PLAN.md — ci.yml trigger model: schedule cron + 5 moved-job PR gates + skip-tolerant ci-gate (D-01..D-12)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 196-02-PLAN.md — re-anchor phase_51 contract test to the fast_checks step + re-verify phase_58 slicer (D-15, D-16)
- [x] 196-03-PLAN.md — force_fail_probe workflow_dispatch input + needs-free nightly probe job (D-14)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 196-04-PLAN.md — MAINTAINING.md nightly cadence/residuals/probe runbook + local-dev note + VERIFICATION D-13 correction (D-07, D-13, D-14)

### Phase 197: Playwright Lanes & Design-Gallery Re-Gate

**Goal**: The Playwright critical path is shorter and an early failure no longer masks later steps; browser readiness is deterministic; and the demoted `continue-on-error` admin-design gallery is a hard gate again because its font-reflow height delta is fixed.
**Depends on**: Phase 193 (CRIT-01 already decoupled the lane), Phase 196 (trigger model decides PR vs nightly placement for heavier galleries)
**Requirements**: PW-01, PW-02, PW-03
**Key tasks**:

  - Reduce the `example_playwright_smoke` critical path: share app boot and/or shard the serial `npx playwright test` steps so an early-step failure no longer masks independent later-step failures (this session cost multiple ~25m round-trips) (PW-01).
  - Make readiness deterministic everywhere in the browser lanes — no `Process.sleep`-based waits; explicit readiness checks (PW-02).
  - Re-gate the `continue-on-error` admin-design gallery (SEED-006): make CI visual capture deterministic (brand webfont loads in the CI dev-mode boot) and/or recapture baselines in-CI, resolving the systemic ~20–53px height delta (font fallback reflow) — not by widening pixel tolerance — then restore the hard gate (PW-03).

**Success Criteria** (what must be TRUE):

  1. The Playwright lane surfaces independent step failures in a single run (sharded/aggregated) instead of masking later steps behind an early failure, and its critical-path time is reduced vs the Phase 193 baseline.
  2. No `Process.sleep`-based readiness remains in the browser lanes; readiness is explicit and deterministic.
  3. `admin-design.spec.ts` runs green in CI across chromium/mobile/dark with baselines captured in (or matched to) the CI environment; the brand webfont loads in the CI dev boot (no fallback-reflow dimension mismatch).
  4. `continue-on-error: true` is removed from the design-gallery step — the lane hard-gates again — and the MG-5/6 data dependency is resolved or explicitly skipped with a recorded reason.

**Verification mechanism (zero-human-UAT)**: CI measures itself — the re-gated gallery runs green in-CI across all three projects (proving deterministic capture), and Playwright-lane critical-path time is compared against the Phase 193 baseline.
**UI hint**: yes
**Plans**: TBD

### Phase 198: Contributor DX & Acceptance Gate

**Goal**: A contributor can reproduce the PR gate locally with one documented command, and the milestone's measured before/after target is met with equal-or-greater quality signal — closing the milestone honestly.
**Depends on**: Phases 193-197 (the acceptance gate measures the cumulative result; `mix ci` must mirror the final PR gate shape)
**Requirements**: DX-01, GATE-01, GATE-02
**Key tasks**:

  - Provide a single documented local CI equivalent (`mix ci` alias or `make`/`just` target) that mirrors the PR gate; document it in CONTRIBUTING so a contributor can reproduce a red check locally without guessing (DX-01).
  - Produce the measured before/after acceptance: PR wall-clock + p95 meaningfully faster (target well under ~22m, ideally <~12m on the fast PR path) with equal-or-greater quality signal on the required gate; any faster-but-less-trustworthy change is labeled a tradeoff and moved to an optional/nightly tier (GATE-01).
  - Confirm no flake introduced, no correctness-critical coverage dropped from the merge gate, required-check names stable, `mix ci` documented; respect SEED-004 (phx_new 1.8.7 pin) and preserve snapshot/baseline determinism (GATE-02).

**Success Criteria** (what must be TRUE):

  1. `mix ci` (or equivalent) exists, mirrors the PR gate, and is documented in CONTRIBUTING; a contributor can reproduce a red PR check locally.
  2. A committed before/after comparison shows PR-path wall-clock + p95 meaningfully faster than the Phase 193 baseline (target <~12m fast path) with equal-or-greater required-gate quality signal.
  3. No new flake and no correctness-critical coverage was dropped from the merge gate; any speed-for-trust tradeoff is explicitly labeled and tiered to nightly.
  4. Required-check names are stable end-to-end, SEED-004's phx_new 1.8.7 pin is respected, and snapshot/baseline determinism is preserved.

**Verification mechanism (zero-human-UAT)**: CI measures itself — the final before/after wall-clock/p95/flake-rate table is the acceptance evidence; `mix ci` is run locally and in CI to prove parity with the PR gate.
**Plans**: TBD

<details>
<summary>✅ v1.39 DS-COHERENCE (Phases 184-192) — SHIPPED 2026-06-19</summary>

**Milestone Goal:** Turn the strengthened v1.38 brand into a systematically audited, award-grade admin/operator design system — evaluated *fractally* (components → groups → pages → flows) and shipped to real adopters by closing the admin-CSS distribution gap, governed by a re-runnable quality ledger so re-runs only move quality forward.

- [x] **Phase 184: Distribution & Parity** (3/3 plans) — canonical `sg-*` CSS extracted into shipped `sigra_admin.css`, linked in generated admin layout, byte-parity test + styled generated-host proof. (completed 2026-06-14)
- [x] **Phase 185: Audit Infrastructure** (3/3 plans) — example-only `/admin/_design` gallery, `admin-design-{chromium,mobile,dark}` snapshot+axe lane, quality ledger + monotonic guard, fractal scorecard rubric. (completed 2026-06-14)
- [x] **Phase 186: Token Foundation (L0)** (4/4 plans) — `:root` token layer audited + ratified across Light/Dark/System, all color pairs AA, motion budget validated, three-surface ember parity preserved. (completed 2026-06-14)
- [x] **Phase 187: Individual Components (L1)** (6/6 plans) — all 13 components pass the per-component scorecard at ≥ Ratified with complete states, responsive, per-component axe. (completed 2026-06-15)
- [x] **Phase 188: Meta-Components / Groups (L2)** (6/6 plans) — MG-1..MG-11 group catalog passes the meta scorecard with content-equivalent desktop↔mobile swaps and byte-coherent reuse. (completed 2026-06-15)
- [x] **Phase 189: Page Compositions (L3)** (3/3 plans) — 3 archetypes + Branding customizer + Audit explorer pass the page scorecard; 8 checkpoints × 3 projects ratified. (completed 2026-06-17)
- [x] **Phase 190: Flows & Fixture Data (L4)** (5/5 plans) — 3 persona JTBD journeys pass happy/error/boundary with scope/return continuity, keyboard, reduced-motion, theme persistence from deterministic fixtures. (completed 2026-06-17)
- [x] **Phase 191: Microcopy & IA Sweep** (4/4 plans) — committed one-term-per-concept glossary enforced by ExUnit drift guard; system-wide voice + plain-language pass. (completed 2026-06-18)
- [x] **Phase 192: Ratification & Baseline Lock** (4/4 plans) — terminal idempotency gate: all baselines recaptured, both allowlists empty, generated-host parity proven, ~35 ledger cells locked Tier 1, monotonic guard green vs origin/main. (completed 2026-06-18)

Archive:

- [v1.39 Roadmap](milestones/v1.39-ROADMAP.md)
- [v1.39 Requirements](milestones/v1.39-REQUIREMENTS.md)

</details>

<details>
<summary>✅ v1.38 BRAND-V2 (Phases 178-183) — SHIPPED 2026-06-13</summary>

**Milestone Goal:** Pressure-test the v1.35 brand system against a fresh 14-section critical audit and elevate the Sigra identity with a redesigned, fully integrated logo system — ratified by the maintainer — propagated coherently everywhere the existing logo already lives.

- [x] **Phase 178: Brand v2 Pressure-Test Audit** — 14-section KEEP/TIGHTEN/REWORK/ADD/REMOVE audit, szTheory suite brand architecture, logo v2 design brief. (completed 2026-06-12)
- [x] **Phase 179: Outlining Toolchain + Logo Concept Exploration** — Committed opentype.js glyph-outlining script; 7 candidates with 4 integrated typemarks; Playwright render-critique loop; round-3 gallery. (completed 2026-06-12)
- [x] **Phase 180: Human Logo Ratification Gate** — Maintainer ratified D4 Linked Rail (round-4 refinement of A1 Rail-i, Space Grotesk 700); one round-4 loop used; decision recorded in round-3 README. (completed 2026-06-12)
- [x] **Phase 181: Ratified Logo System Buildout** — 8 D4 Linked Rail SVGs built + render-verified (16px favicon kill test passed); clearspace/min-size/6 misuse examples documented; 6 v1 assets archived. (completed 2026-06-12)
- [x] **Phase 182: Brand Book v2 + Tokens** — index.html v2 (expanded logo-system + szTheory suite sections); tokens 1.0.1 + change policy; stale specimens fixed; axe zero violations. (completed 2026-06-13)
- [x] **Phase 183: Propagation, Parity + Verification** — D4 logo propagated to installer+example (byte-identical, filenames unchanged); token parity verified unchanged; 21 Playwright baselines recaptured, canary intact, allowlist reset; hygiene green. (completed 2026-06-13)

Archive:

- [v1.38 Roadmap](milestones/v1.38-ROADMAP.md)
- [v1.38 Requirements](milestones/v1.38-REQUIREMENTS.md)
- [v1.38 Phase Artifacts](milestones/v1.38-phases/)

</details>

<details>
<summary>✅ v1.37 AUTH-BRANDING-WHITELABEL (Phases 173-177) — SHIPPED 2026-06-07</summary>

**Milestone Goal:** Make Sigra's generated authentication forms and emails production-ready by default, while giving adopters a low-friction white-label path, an admin/operator customizer, a code/config path, and a full-control escape hatch.

- [x] Phase 173: Auth Branding Contract + Token Model (1/1 plan) — completed 2026-06-07
- [x] Phase 174: Generated Auth Shell + Light/Dark/System CSS (1/1 plan) — completed 2026-06-07
- [x] Phase 175: Admin Customizer + Email Branding (1/1 plan) — completed 2026-06-07
- [x] Phase 176: Generated Host, Example, Docs, and Golden Parity (1/1 plan) — completed 2026-06-07
- [x] Phase 177: Verification, Generated-Host Smoke, and Audit Closure (1/1 plan) — completed 2026-06-07

Archive:

- [v1.37 Roadmap](milestones/v1.37-ROADMAP.md)
- [v1.37 Requirements](milestones/v1.37-REQUIREMENTS.md)
- [v1.37 Milestone Audit](milestones/v1.37-MILESTONE-AUDIT.md)
- [v1.37 Phase Artifacts](milestones/v1.37-phases/)

</details>

<details>
<summary>✅ v1.36 ADMIN-BRAND-THEME-POLISH (Phases 168-172) — SHIPPED 2026-06-06</summary>

**Milestone Goal:** Align the admin UI with the ratified Rail Accent brand system, add explicit Light/Dark/System theme support, and tighten the design-system guidance/tests without reopening the broad v1.34 admin redesign.

- [x] Phase 168: Admin Brand + Theme Audit (1/1 plan) — completed 2026-06-06
- [x] Phase 169: Durable UI Principles + Design Contract Update (1/1 plan) — completed 2026-06-06
- [x] Phase 170: Rail Accent Shell + Theme Control (1/1 plan) — completed 2026-06-06
- [x] Phase 171: Design-System Touchpoint Polish (1/1 plan) — completed 2026-06-06
- [x] Phase 172: Tests, Evidence, and Baseline Ratification (1/1 plan) — completed 2026-06-06

Archive:

- [v1.36 Roadmap](milestones/v1.36-ROADMAP.md)
- [v1.36 Requirements](milestones/v1.36-REQUIREMENTS.md)
- [v1.36 Milestone Audit](milestones/v1.36-MILESTONE-AUDIT.md)

</details>

<details>
<summary>✅ v1.35 BRAND-SYSTEM-PRESSURE-TEST (Phases 161-167) — SHIPPED 2026-06-05</summary>

**Milestone Goal:** Pressure-test Sigra's brand posture and commit a self-contained brandbook that is useful for docs, READMEs, landing pages, UI/UX buildout, marketing copy, design tokens, SVG logos, and future collateral without causing repo churn or binary sprawl.

- [x] Phase 161: Brand Evidence Extraction + Pressure-Test Audit (1/1 plan) — completed 2026-06-05
- [x] Phase 162: Brand DNA + Voice System (1/1 plan) — completed 2026-06-05
- [x] Phase 163: Tokens + UI/UX Buildout Spec (1/1 plan) — completed 2026-06-05
- [x] Phase 164: Logo + SVG Asset System (1/1 plan) — completed 2026-06-05
- [x] Phase 165: Static HTML Brand Book (1/1 plan) — completed 2026-06-05
- [x] Phase 166: Verification + Repo Hygiene (1/1 plan) — completed 2026-06-05
- [x] Phase 167: Logo Options + Brand Direction Review (2/2 plans) — completed 2026-06-05

Archive:

- [v1.35 Roadmap](milestones/v1.35-ROADMAP.md)
- [v1.35 Requirements](milestones/v1.35-REQUIREMENTS.md)
- [v1.35 Milestone Audit](milestones/v1.35-MILESTONE-AUDIT.md)
- [v1.35 Phase Artifacts](milestones/v1.35-phases/)

</details>

<details>
<summary>✅ v1.34 ADMIN-UI-COHERENCE (Phases 154-160) — SHIPPED 2026-06-05</summary>

- [x] Phase 154: Design Contract + sg-notice (2/2 plans) — completed 2026-06-03
- [x] Phase 155: Shared Component Foundation (KEYSTONE) (3/3 plans) — completed 2026-06-04
- [x] Phase 156: Adopt Shared Components on Baselined Screens (6/6 plans) — completed 2026-06-04
- [x] Phase 157: Overview Landings (Highest Effort) (4/4 plans) — completed 2026-06-04
- [x] Phase 158: Audit Mobile + Per-User Audit (High Effort) (5/5 plans) — completed 2026-06-04
- [x] Phase 159: Cross-Journey Coherence Sweep + Seed Enrichment (5/5 plans) — completed 2026-06-05
- [x] Phase 160: Regression Hardening + Baseline Ratification (4/4 plans) — completed 2026-06-05

Archive:

- [v1.34 Roadmap](milestones/v1.34-ROADMAP.md)
- [v1.34 Requirements](milestones/v1.34-REQUIREMENTS.md)
- [v1.34 Milestone Audit](milestones/v1.34-MILESTONE-AUDIT.md)
- [v1.34 Phase Artifacts](milestones/v1.34-phases/)

</details>

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
| --- | --- | --- | --- | --- |
| 193. Baseline, Observability & One-Line Wins | v1.40 | 3/3 | Complete    | 2026-06-19 |
| 194. Caching Correctness & Micro-Job Consolidation | v1.40 | 2/2 | Complete    | 2026-06-20 |
| 195. Test-Suite Performance (partition / async / dep-off slim) | v1.40 | 3/3 | Complete    | 2026-06-20 |
| 196. PR-Fast vs Nightly-Broad Trigger Model | v1.40 | 4/4 | Complete    | 2026-06-20 |
| 197. Playwright Lanes & Design-Gallery Re-Gate | v1.40 | 0/? | Not started | - |
| 198. Contributor DX & Acceptance Gate | v1.40 | 0/? | Not started | - |
| 150. Issue Triage & Bugfix Cadence | v1.33 | 1/1 | Complete | 2026-06-01 |
| 151. Ecosystem Sync & Hex Dependency Management | v1.33 | 1/1 | Complete | 2026-06-01 |
| 152. Strategic Bet Evaluation Gate | v1.33 | 1/1 | Complete | 2026-06-01 |
| 153. Infrastructure Stability & CI Hardening | v1.33 | 1/1 | Complete | 2026-06-02 |
| 154. Design Contract + sg-notice | v1.34 | 2/2 | Complete | 2026-06-03 |
| 155. Shared Component Foundation (KEYSTONE) | v1.34 | 3/3 | Complete | 2026-06-04 |
| 156. Adopt Shared Components on Baselined Screens | v1.34 | 6/6 | Complete | 2026-06-04 |
| 157. Overview Landings (Highest Effort) | v1.34 | 4/4 | Complete | 2026-06-04 |
| 158. Audit Mobile + Per-User Audit (High Effort) | v1.34 | 5/5 | Complete | 2026-06-04 |
| 159. Cross-Journey Coherence Sweep + Seed Enrichment | v1.34 | 5/5 | Complete | 2026-06-05 |
| 160. Regression Hardening + Baseline Ratification | v1.34 | 4/4 | Complete | 2026-06-05 |
| 161. Brand Evidence Extraction + Pressure-Test Audit | v1.35 | 1/1 | Complete | 2026-06-05 |
| 162. Brand DNA + Voice System | v1.35 | 1/1 | Complete | 2026-06-05 |
| 163. Tokens + UI/UX Buildout Spec | v1.35 | 1/1 | Complete | 2026-06-05 |
| 164. Logo + SVG Asset System | v1.35 | 1/1 | Complete | 2026-06-05 |
| 165. Static HTML Brand Book | v1.35 | 1/1 | Complete | 2026-06-05 |
| 166. Verification + Repo Hygiene | v1.35 | 1/1 | Complete | 2026-06-05 |
| 167. Logo Options + Brand Direction Review | v1.35 | 2/2 | Complete | 2026-06-05 |
| 168. Admin Brand + Theme Audit | v1.36 | 1/1 | Complete | 2026-06-06 |
| 169. Durable UI Principles + Design Contract Update | v1.36 | 1/1 | Complete | 2026-06-06 |
| 170. Rail Accent Shell + Theme Control | v1.36 | 1/1 | Complete | 2026-06-06 |
| 171. Design-System Touchpoint Polish | v1.36 | 1/1 | Complete | 2026-06-06 |
| 172. Tests, Evidence, and Baseline Ratification | v1.36 | 1/1 | Complete | 2026-06-06 |
| 173. Auth Branding Contract + Token Model | v1.37 | 1/1 | Complete | 2026-06-07 |
| 174. Generated Auth Shell + Light/Dark/System CSS | v1.37 | 1/1 | Complete | 2026-06-07 |
| 175. Admin Customizer + Email Branding | v1.37 | 1/1 | Complete | 2026-06-07 |
| 176. Generated Host, Example, Docs, and Golden Parity | v1.37 | 1/1 | Complete | 2026-06-07 |
| 177. Verification, Generated-Host Smoke, and Audit Closure | v1.37 | 1/1 | Complete | 2026-06-07 |
| 178. Brand v2 Pressure-Test Audit | v1.38 | 2/2 | Complete   | 2026-06-12 |
| 179. Outlining Toolchain + Logo Concept Exploration | v1.38 | 2/2 | Complete   | 2026-06-12 |
| 180. Human Logo Ratification Gate | v1.38 | 1/1 | Complete   | 2026-06-12 |
| 181. Ratified Logo System Buildout | v1.38 | 2/2 | Complete   | 2026-06-13 |
| 182. Brand Book v2 + Tokens | v1.38 | 2/2 | Complete   | 2026-06-13 |
| 183. Propagation, Parity + Verification | v1.38 | 2/2 | Complete   | 2026-06-13 |
| 184. Distribution & Parity | v1.39 | 3/3 | Complete | 2026-06-14 |
| 185. Audit Infrastructure | v1.39 | 3/3 | Complete | 2026-06-14 |
| 186. Token Foundation (L0) | v1.39 | 4/4 | Complete | 2026-06-14 |
| 187. Individual Components (L1) | v1.39 | 6/6 | Complete | 2026-06-15 |
| 188. Meta-Components / Groups (L2) | v1.39 | 6/6 | Complete | 2026-06-15 |
| 189. Page Compositions (L3) | v1.39 | 3/3 | Complete | 2026-06-17 |
| 190. Flows & Fixture Data (L4) | v1.39 | 5/5 | Complete | 2026-06-17 |
| 191. Microcopy & IA Sweep | v1.39 | 4/4 | Complete | 2026-06-18 |
| 192. Ratification & Baseline Lock | v1.39 | 4/4 | Complete | 2026-06-18 |
</content>
</invoke>
