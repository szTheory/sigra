# Requirements: Sigra — v1.40 CI-PERF

**Defined:** 2026-06-19
**Core Value:** Authentication that works out of the box with great DX — extended here to the *maintainer/contributor* inner loop: CI must be fast, deterministic, trustworthy, and cheap to run, without trading away signal.
**Source of truth:** `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` (grounded baseline + verbatim audit playbook) and `SEED-006` (design-gallery CI fragility). Fresh evidence: PR #56 run `27846034918` — 20/23 jobs ≤3.1m; wall-clock gated by `example_playwright_smoke` 22.2m, `library_tests` 15.9m, `library_tests_dep_off` 13.9m.

## v1.40 Requirements

Each maps to roadmap phases (193+). "Done" = measured improvement with **equal-or-greater** quality signal on the required gate.

### Baseline & observability (measure before optimize)

- [ ] **BASE-01**: Capture a before-state baseline table from `.github/workflows/ci.yml` + recent runs — per-job duration, p95, critical path, cache hit/miss, required-vs-not, quality signal, likely bottleneck. Committed as a planning artifact.
- [ ] **BASE-02**: Collect Elixir-side diagnostics to target the suite — `mix test --slowest`, `System.schedulers_online()` on the runner, top slow compile modules — and record them as the optimization target.
- [ ] **BASE-03**: CI job summaries surface resolved versions, cache hit/miss, and a test-timing summary so future regressions are visible (observability, not just speed).

### Critical-path & trigger model

- [ ] **CRIT-01**: Remove gratuitous job serialization — `example_playwright_smoke needs: [library_tests]` makes the two longest jobs run sequentially though the Playwright lane consumes nothing from `library_tests`. Drop the edge (keep `release_ref_guard`). *Likely the single biggest, lowest-risk win.*
- [ ] **CRIT-02**: Establish a PR-fast vs nightly/main-broad split — move exhaustive/low-probability coverage (install matrix ×4, upgrade smoke, broad galleries) off the every-PR path to `schedule:`/main, keeping a fast representative PR gate. **Never** strand a correctness-critical test on nightly only.
- [ ] **CRIT-03**: Preserve a single stable required check (`ci-gate` aggregator) and stable child-check names across the redesign — no branch-protection churn, no path/skip pending-check traps.

### Test-suite performance

- [ ] **TEST-01**: Partition `library_tests` (`mix test --partitions N`) across parallel shards, each with an isolated Postgres database; merge coverage if applicable; partition count chosen from evidence (don't oversubscribe a 2-core runner).
- [ ] **TEST-02**: Slim `library_tests_dep_off` — run a targeted subset that actually exercises the Threadline-absent compile/guard paths instead of re-running the full ~14m suite.
- [ ] **TEST-03**: Audit `async: true` coverage — convert safe modules, split oversized serial modules, without marking any global-state-mutating test async. Sandbox/pool config stays correct under partitioning.

### Playwright lanes

- [ ] **PW-01**: Reduce the `example_playwright_smoke` critical path — share app boot, and/or shard the serial `npx playwright test` steps so an early-step failure no longer masks later steps (this session cost multiple ~25m round-trips to surface independent failures).
- [ ] **PW-02**: Deterministic readiness everywhere in the browser lanes — no `Process.sleep`-based waits; explicit readiness checks.
- [ ] **PW-03** *(folds in SEED-006)*: Re-gate the `continue-on-error` admin-design gallery — make CI visual capture deterministic (brand webfont loads in the CI dev-mode boot) and/or recapture baselines in-CI, then restore it to a hard gate. Resolve the systemic ~20–53px height delta (font fallback reflow), not by widening pixel tolerance.

### Caching, runners, job topology

- [ ] **CACHE-01**: Audit and correct caching — precise keys (OS/arch/OTP/Elixir/MIX_ENV/lockfile/buster), no `_build` reuse across incompatible combos, never skip `deps.get` after a partial restore; separate deps cache from any PLT cache; document how to bust.
- [ ] **CACHE-02**: Consolidate trivial micro-guard jobs (release-ref, milestone-verification, snapshot-drift, quality-ledger, getting-started/phase-34 contracts) into one cheap "fast checks" job to cut per-job runner-startup overhead — preserving stable required-check names.
- [ ] **CACHE-03**: Apply larger runners *selectively* to the long poles only if the cost/speed tradeoff is justified by measurement — not by default.

### Contributor DX

- [ ] **DX-01**: Provide a single documented local CI equivalent (`mix ci` alias or `make`/`just` target) that mirrors the PR gate; document it in CONTRIBUTING so a contributor can reproduce a red check locally without guessing.

### Hygiene

- [ ] **FLAKE-01**: Fix the known-flaky demo-showcase remember-checkbox accent-color assertion (off-by-one rgb) — de-flake or delete; do **not** paper over with blanket retries. (Todo: `.planning/todos/pending/2026-06-19-demo-showcase-remember-checkbox-color-flaky.md`.)

### Acceptance gate (milestone-level)

- [ ] **GATE-01**: Measured before/after — PR wall-clock + p95 meaningfully faster (target: well under the current ~22m, ideally <~12m on the fast PR path) with **equal-or-greater** quality signal on the required gate. Any change that is faster-but-less-trustworthy is labeled a tradeoff and moved to an optional/nightly tier.
- [ ] **GATE-02**: No flake introduced; no correctness-critical coverage dropped from the merge gate; required-check names stable; `mix ci` documented. Respect SEED-004 (phx_new 1.8.7 pin) and preserve snapshot/baseline determinism.

## Out of Scope

| Item | Reason |
|------|--------|
| Multi-OS / Windows / macOS / ARM CI matrix | Library targets Linux CI; no evidence of OS-specific bugs. Not worth the matrix cost. |
| Broad Elixir/OTP version matrix on every PR | Single supported pair on PR; any compat matrix belongs on nightly/main, not the PR gate. |
| Adding Dialyzer/Sobelow as new mandatory PR gates | Out of scope unless a realistic remediation plan exists; CI-PERF is about speed/trust of existing gates, not new gates. |
| Rewriting the whole pipeline | Prefer stepwise, reversible PRs; keep the sound `ci-gate` aggregator model. |
| "Fix" flake via blanket retries | Retry is quarantine, not a root fix (guardrail). |

## Traceability

Phases assigned during roadmap creation (continue numbering from 193).

| Requirement | Phase | Status |
|-------------|-------|--------|
| BASE-01, BASE-02, BASE-03 | 193 | Pending |
| CRIT-01 | 193 | Pending |
| FLAKE-01 | 193 | Pending |
| CACHE-01, CACHE-02 | 194 | Pending |
| TEST-01, TEST-02, TEST-03 | 195 | Pending |
| CACHE-03 | 195 | Pending |
| CRIT-02, CRIT-03 | 196 | Pending |
| PW-01, PW-02, PW-03 | 197 | Pending |
| DX-01 | 198 | Pending |
| GATE-01, GATE-02 | 198 | Pending |

**Coverage:**
- v1.40 requirements: 18 total
- Mapped to phases: 18 (phases 193–198)
- Unmapped: 0 ✓

---
*Requirements defined: 2026-06-19*
*Last updated: 2026-06-19 — milestone v1.40 CI-PERF start*
