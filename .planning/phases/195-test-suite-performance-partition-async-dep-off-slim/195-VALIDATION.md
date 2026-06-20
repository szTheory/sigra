---
phase: 195
slug: test-suite-performance-partition-async-dep-off-slim
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-20
---

# Phase 195 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source signal: **CI measures itself** — partitioned/slimmed job durations + pass
> counts diffed against `193-BASELINE.md`; zero-new-flake via repeated runs.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir 1.19.5-otp-28 stdlib) |
| **Config file** | `mix.exs` (`aliases`, optional `:threadline` dep), `test/test_helper.exs` (sandbox `:manual` mode), `.github/workflows/ci.yml` (job topology) |
| **Quick run command** | `MIX_ENV=test mix sigra.dep_off` (dep-off subset) · `MIX_TEST_PARTITION=1 mix test --partitions 2` (one shard) |
| **Full suite command** | `mix test` (full library suite); CI is the integration check |
| **Estimated runtime** | dep-off subset target <3m (vs ~13.8m baseline); each shard ≈ baseline/2 |

---

## Sampling Rate

- **After every task commit:** `MIX_ENV=test mix sigra.dep_off` (dep-off path) and/or `MIX_TEST_PARTITION=1 mix test --partitions 2` (one shard) locally
- **After every plan wave:** `mix test` (full library suite) green
- **Before `/gsd-verify-work`:** a real CI run on a PR branch showing (1) a single **bare** `Library tests` check green, (2) both shard durations recorded in `$GITHUB_STEP_SUMMARY`, (3) dep-off lane <3m with the `--only` red-property demonstrated once, (4) `ci-gate` green
- **Max feedback latency:** local dep-off subset < ~180s; per-shard local < baseline/2

---

## Per-Task Verification Map

> Final task IDs are assigned by the planner. This maps each requirement to its observable
> signal (vs `193-BASELINE.md`) — the Dimension-8 contract the executor must satisfy.

| Requirement | Wave | Observable Signal (automated) | Test Type | Where it lives | Status |
|-------------|------|-------------------------------|-----------|----------------|--------|
| TEST-01 | partition | Both shard durations + aggregated pass count vs `library_tests` 15.9m baseline; shard walltime ≈ baseline/2; same total test count reported across legs | CI measurement | `library_tests_shard` matrix + `$GITHUB_STEP_SUMMARY` | ⬜ pending |
| TEST-01 (correctness) | partition | `gh api .../rulesets/14941512` shows `Library tests`; PR shows a single bare `Library tests` check (not `(1)`/`(2)`); `ci-gate` green with `needs.library_tests.result == success` | CI structural | `library_tests` aggregator job; `ci-gate` | ⬜ pending |
| TEST-02 | dep-off | dep-off lane walltime ≈ 13.8m → target <3m; compile step still runs (`--warnings-as-errors --no-deps-check`); renaming/removing `:threadline_guard` makes the lane RED (zero-match) | CI measurement + red-property | `library_tests_dep_off` lane; `mix sigra.dep_off` alias | ⬜ pending |
| TEST-02 (coverage) | dep-off | `mix test --only threadline_guard` runs ≥7 modules covering D-13(a–e): compile / `threadline_available?==false` / boot-degrade one-warning / no `apply/3` crash / `mix sigra.doctor` reports `threadline: false`; nonzero test count | unit | tagged guard modules | ⬜ pending |
| TEST-03 | async | The 2 named flips (+ any others passing the D-17 checklist) are `async: true` and green; zero new flake via `mix test --repeat-until-failure N` locally + repeated CI runs; serial set (D-16) still `async: false` | unit + repeated-run | flipped modules | ⬜ pending |
| TEST-03 (deliverable) | async | Async-safety checklist exists in CONTRIBUTING / testing guide; `# async: false because <reason>` convention standardized | doc contract | docs | ⬜ pending |
| CACHE-03 | runners | Every job stays `runs-on: ubuntu-latest` (grep); measurement-gate runbook exists with the before/after table template | structural + runbook | `ci.yml`; runbook doc | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `@moduletag :threadline_guard` added to the ~7 guard modules — covers D-13(a–e). No new test *files*; the guard tests already exist — this is a tagging task. **Inspect `phase_148_*` (A1/A3) before tagging.**
- [ ] `mix sigra.dep_off` alias in `mix.exs` — enables local==CI repro (`deps.unlock threadline` → `deps.clean threadline --build` → `compile --warnings-as-errors --no-deps-check` → `test --only threadline_guard --no-deps-check`)
- [ ] Async-safety checklist doc (CONTRIBUTING or testing guide) — the TEST-03 deliverable
- [ ] Measurement-gate runbook (CACHE-03 / D-23) — short doc with the before/after table

*ExUnit is present and the suite is comprehensive — no framework install needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live branch-protection ruleset still names `Library tests` after aggregator rename | TEST-01 (correctness) | Ruleset is GitHub-side state, not in-repo; must be re-read at execution time (D-02 mandate) | `gh api repos/szTheory/sigra/rulesets/14941512` — confirm `Library tests` is byte-identical before merging the aggregator |

*All other phase behaviors have automated verification via CI self-measurement.*

---

## Validation Sign-Off

- [ ] All tasks have an automated verify (CI measurement / `mix test` signal) or a Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (tagging, alias, checklist doc, runbook)
- [ ] No watch-mode flags
- [ ] Feedback latency < ~180s (local dep-off subset)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
