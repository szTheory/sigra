# 198-ACCEPTANCE — v1.40 CI-PERF Milestone Acceptance Evidence (GATE-01 / GATE-02)

**Phase:** 198 — contributor-dx-acceptance-gate  
**Captured:** 2026-06-21  
**Captured by:** `gh run view --json jobs` (authenticated gh as szTheory) — read-only, no code changes  
**After-cohort:** 3 successful pull_request runs on 2026-06-20, all post-PR#58/59/60 (v1.40 CI-PERF pipeline, CRIT-01 fix applied)  
**Sample size n=3** (PR-path runs after the full Phase 193-198 pipeline landed on main)  
**Before-state reference:** [193-BASELINE.md](../193-baseline-observability-one-line-wins/193-BASELINE.md) — n=6 runs, 2026-06-19 cohort  
**Purpose:** Falsifiable before/after evidence for GATE-01 (PR-path is meaningfully faster) and GATE-02 (quality signal equal or greater).

---

## 1. Before/After Wall-Clock + p95 Table (GATE-01)

> Captures D-05 honest-numbers discipline. Table shape mirrors 193-BASELINE. After-numbers are REAL run IDs with per-job `gh run view --json jobs` measurements, not estimates.

### Run-Level Wall-Clock

| Cohort | Run ID | Trigger | Date | Wall-Clock |
|--------|--------|---------|------|-----------|
| **Before (193-BASELINE)** | 27847562459 | push | 2026-06-19 | 2304s (38.4m) |
| **Before (193-BASELINE)** | 27846034918 | pull_request | 2026-06-19 | 2301s (38.4m) |
| **Before (193-BASELINE)** | 27837497615 | push | 2026-06-19 | 2260s (37.7m) |
| **Before (193-BASELINE)** | 27835747516 | pull_request | 2026-06-19 | 2311s (38.5m) |
| **Before (193-BASELINE)** | 27835546762 | push | 2026-06-19 | 2424s (40.4m) |
| **Before (193-BASELINE)** | 27833715452 | pull_request | 2026-06-19 | 2310s (38.5m) |
| **After (198-ACCEPTANCE)** | 27884350750 | pull_request | 2026-06-20 | 1379s (23.0m) |
| **After (198-ACCEPTANCE)** | 27883990824 | pull_request | 2026-06-20 | 1369s (22.8m) |
| **After (198-ACCEPTANCE)** | 27883386841 | pull_request | 2026-06-20 | 1237s (20.6m) |

| Metric | Before (n=6, 2026-06-19) | After (n=3, 2026-06-20) | Delta |
|--------|--------------------------|--------------------------|-------|
| Average wall-clock | ~2318s (~38.6m) | ~1328s (~22.1m) | **-990s (-16.5m)** |
| p95 (best estimate from sample) | ~2424s (~40.4m) | ~1379s (~23.0m) | **-1045s (-17.4m)** |
| Fastest run | 2260s (37.7m) | 1237s (20.6m) | -1023s (-17.1m) |

**GATE-01 verdict:** Wall-clock reduced from ~38.6m avg to ~22.1m avg — a **-16.5m (43%) improvement**. The GATE-01 target ("meaningfully faster than the ~38m baseline") is met. The improvement is entirely explained by CRIT-01 (Phase 193): removing the gratuitous `needs: library_tests` edge on `example_playwright_smoke` so the 22-minute Playwright pole runs in parallel from t+6s rather than serialized after the 16m library_tests job.

## Target shortfall (honest disclosure)

The v1.40 result is ~22.1m avg — meeting the hard GATE-01 bar (meaningfully faster than the ~38m 193-BASELINE, -43%) but NOT the aspirational ROADMAP SC-2 "<~12m fast PR path" stretch target. The root cause: once CRIT-01 de-serialized the pipeline, `example_playwright_smoke` (~22m) became the binding run-level floor — the longest single job, so run-level wall-clock cannot drop below it regardless of further parallelization. Reaching <12m requires splitting/parallelizing the Playwright job itself (e.g., sharding the admin and example Playwright suites), which was out of v1.40 CI-PERF scope and is deferred to future work.

**Note on sample size:** n=3 for the after-cohort is a small sample. The p95 is therefore the max of the 3 runs (1379s / 23.0m) — a conservative upper bound. The consistent clustering (1237s, 1369s, 1379s) across 3 runs gives high confidence in the ~22-23m wall-clock range. A larger sample would tighten the p95 estimate but is unlikely to change the conclusion given the consistency observed.

**Note on after-cohort pipeline state:** The after-cohort is post-PR#58/59/60 (v1.40 CI-PERF) and post-Plan-02 re-gate (D-06: `design_gallery` hard re-gated locally but NOT yet pushed to a new PR triggering these CI runs — the re-gate commit exists locally on `main` branch but was committed after run 27884942846). The after-runs therefore reflect the Phase 193-197 pipeline optimizations (CRIT-01 parallelization, Phase 195 shard partitioning, Phase 196 nightly split). The Plan 02 hard re-gate (D-06) changes gating behavior, NOT job durations, so these runs are a valid and complete "after" timing sample for GATE-01.

---

### Per-Long-Pole Job Table (After)

> Capture date: 2026-06-21. Method: `gh run view <id> --json jobs --jq '.jobs[] | {name, conclusion, startedAt, completedAt}'` for each run.

| Job | Before avg (193-BASELINE, n=4) | Before p95 | After avg (n=3) | After p95 | Delta avg | Notes |
|-----|-------------------------------|------------|-----------------|-----------|-----------|-------|
| **Example Playwright smoke** | 1329s (22.2m) | 1336s (22.3m) | 1317s (21.9m) | 1367s (22.8m) | -12s (-0.3m) | Was the serialization bottleneck; now runs from t+6s (no longer waits for library_tests) |
| **Library tests (shard max)** | 960s (16.0m) [single runner] | 977s (16.3m) | 512s (8.5m) [shard max] | 518s (8.6m) | -448s (-7.5m) | 2-shard partition (Phase 195); longest shard determines library_tests aggregator time |
| **Library tests dep-off** | 830s (13.8m) | 840s (14.0m) | 204s (3.4m) | 206s (3.4m) | -626s (-10.4m) | `--only threadline_guard` targeted subset (Phase 195); was full 14m re-run |

**Per-run raw data:**

| Run ID | example_playwright_smoke | Library tests shard 1 | Library tests shard 2 | Library tests dep-off |
|--------|-------------------------|----------------------|----------------------|----------------------|
| 27884350750 | 1367s (22.8m) | 474s (7.9m) | 515s (8.6m) | 204s (3.4m) |
| 27883990824 | 1357s (22.6m) | 473s (7.9m) | 503s (8.4m) | 206s (3.4m) |
| 27883386841 | 1226s (20.4m) | 464s (7.7m) | 518s (8.6m) | 202s (3.4m) |

**Wall-clock determination:** The after-pipeline is dominated exclusively by `example_playwright_smoke` (~22m), which now starts at t+6s (immediately after `release_ref_guard`). Library tests shards (8.5m) complete well before `example_playwright_smoke` — no serialization, no waiting. The CRIT-01 one-line YAML change (`needs: library_tests` removed from `example_playwright_smoke`) delivered the full -16m delta as predicted in 193-BASELINE.

---

## 2. Quality-Signal Parity Proof (GATE-02)

### 2a. Required-Check Names — Verbatim Live Ruleset Output

> Method: `gh api repos/szTheory/sigra/rulesets/14941512 --jq '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context'` — captured 2026-06-21.

```
Library tests
Example unit smoke (ExUnit + ConnTest)
Install smoke (fresh phx.new + sigra.install)
Example HTTP smoke (boot + curl critical routes)
Example Playwright smoke (full lifecycle)
```

All 5 required-check name strings are byte-stable. These are the same strings documented in 198-02-SUMMARY.md (Task 3 GATE-02 assertion) and in MAINTAINING.md §"Branch protection — enforced required checks (live ruleset)". The post-198 pipeline has not renamed any job `name:` field.

**No `ci-gate` in the enforced set:** `ci-gate` is the internal aggregator job — it is NOT in ruleset 14941512. The 5 lane `name:` strings above are the merge-blocking required checks. This was clarified in Phase 196 (D-15) and the stale reference swept from MAINTAINING.md.

### 2b. ci-gate `needs:` List Parity

The `ci-gate` job's `needs:` list controls what the internal aggregator waits for. The list is unchanged from the Phase 196 baseline:

```
install_golden_contract, library_tests, library_tests_dep_off,
install_smoke, upgrade_smoke, example_http_smoke, example_playwright_smoke,
generated_admin_playwright_smoke, fast_checks
```

`ci-gate` tolerates `skipped` result (since nightly-only jobs like `upgrade_smoke` and `generated_admin_playwright_smoke` are skipped on PRs). No correctness-critical job has been removed from or added to the `needs:` list in Phase 198. (D-06 hard re-gated `design_gallery` within the `example_playwright_smoke` job body — it does not appear in `ci-gate.needs` as a separate job.)

### 2c. Design-Gallery Hard Re-Gate (D-06) — STRENGTHENED Signal

The `design_gallery` step within the `example_playwright_smoke` job was re-hardened in Phase 198 Plan 02 (commit `32d43bb5`, D-06):

- **Before (soft-gate, TEMP):** `continue-on-error: true` — a visual regression in the design gallery would not fail the job.
- **After (hard-gate):** `continue-on-error` removed; `steps.design_gallery.outcome` restored to the aggregator loop. A gallery failure now fails `example_playwright_smoke`, which is a required lane.

This is a **strengthened** quality signal, not a weakened one. The only real `continue-on-error: true` key remaining in `ci.yml` (line 1595) is the intentional OQ3 cross-lane measurement step inside `admin_design_recapture` — a nightly-only, non-gating metric collection step.

**Confirmed:** `grep -cE '^[[:space:]]*continue-on-error: true' .github/workflows/ci.yml` = **1** (the intentional OQ3 nightly key; the design-gallery soft-gate is gone).

### 2d. No Correctness-Critical Test Stranded Nightly-Only (D-08 Proxy Table Reference)

The Phase 196 D-08 proxy table (documented in `196-04-SUMMARY.md`) audited all jobs moved to nightly-only, confirming each has an adequate PR-path behavioral proxy:

| Nightly-only job | PR-path proxy |
|------------------|---------------|
| `upgrade_smoke` | Release-boundary coverage: runs on `push: main` before any Hex publish; accepted residual (D-07 disclosure) |
| `generated_admin_playwright_smoke` | Proxied by `example_playwright_smoke` admin specs on every PR; template-parity backstopped by `scripts/ci/admin-acceptance-smoke.sh` (DIST-06 RUN_PARITY) |
| `install_matrix` (4 flag combos) | `install_smoke` (default) covers the primary path on PRs; 4 flag-combo matrix runs nightly |
| `passkeys_opt_out_smoke`, `passkeys_manual_fallback_smoke` | Core library tests exercise passkeys logic; CI-only smoke confirms the installed variant |
| `admin_design_recapture` | Baseline capture is a push/schedule action; the result (committed PNGs) gates `design_gallery` on every PR |

**Phase 198 moved nothing new to nightly.** See §4 (Tradeoffs Ledger) below.

---

## 3. Flake-Rate (Before vs After)

### Before (193-BASELINE era, 2026-06-13 to 2026-06-19)

The 193-BASELINE noted `FLAKE-01`: the `demo-showcase` rgb assertion was intermittently flaky, consuming `retries: 1` in the Playwright config. That assertion's tolerance was widened in Phase 193-02 (widened to ±10 for the remember-checkbox color assertion), resolving the known flake.

### After (post-197, 2026-06-20 sample)

Runs sampled (2026-06-20):

| Run ID | Trigger | Conclusion | SHA | Notes |
|--------|---------|------------|-----|-------|
| 27884350750 | pull_request | success | a5cd8ce2 | Clean first-attempt success |
| 27883990824 | pull_request | success | 6a654489 | Clean first-attempt success |
| 27883386841 | pull_request | success | 83186ced | Clean first-attempt success |
| 27884942846 | push | success | ee911ea4 | Clean push success |
| 27885649109 | pull_request | failure | fdb24147 | `snapshot-canary-guard` intentional gate failure (canary snapshot was modified — correct gate behavior, not a flake) |
| 27882644882 | pull_request | failure | f1808aa9 | Library tests shard 2 + dep-off + Playwright: real test failures on a different SHA/PR (not a rerun) |
| 27882635436 | pull_request | failure | f6fb46e7 | Same pattern as above — real failures on distinct SHA |

**Flake-rate (failed-then-passed reruns / total):** 0 reruns observed in this sample. Each failure has a unique SHA — these are real test failures on different code states, not flakes masking underlying issues. No run in this sample was a rerun of a failed run on the same SHA.

**FLAKE-01 status:** Resolved. The `retries: 1` configuration no longer appears to be masking real failures in the after-cohort. No runs show the pattern of "failed once, passed on retry with the same code."

**Honest caveat:** n=3 successful PR runs is a small sample for statistical confidence in the flake rate. The 0% rerun rate in this sample is a necessary-but-not-sufficient proof of zero flakes. The quality gate (hard `design_gallery` gate, `snapshot-canary-guard`, contract lock tests) provides structural defense against masking real failures.

---

## 4. Tradeoffs Ledger

> Asserts Phase 198 moved nothing new to nightly. References MAINTAINING.md §"CI cadence — PR-fast vs nightly/main-broad (Phase 196)".

| Speed-for-trust move | Phase introduced | Documented in MAINTAINING.md? | D-08 proxy recorded? | Phase 198 impact |
|----------------------|-----------------|-------------------------------|----------------------|-----------------|
| `upgrade_smoke` to nightly | Phase 196 | Yes | Yes (release-boundary coverage) | No change |
| `generated_admin_playwright_smoke` to nightly | Phase 196 | Yes | Yes (DIST-06 RUN_PARITY backstop) | No change |
| `install_matrix` ×4 to nightly | Phase 196 | Yes | Yes | No change |
| `passkeys_*_smoke` to nightly | Phase 196 | Yes | Yes | No change |
| `admin_design_recapture` to nightly | Phase 196 | Yes | Yes | No change |

**Phase 198 tradeoff: None.** Phase 198 authored acceptance evidence (Plan 03) and documentation (Plans 01-02). It did not move any job between PR-fast and nightly. The design-gallery re-gate (D-06, Plan 02) strengthened the PR-fast gate, not weakened it.

The full accepted-residual disclosure (the two D-07 honest-truth items) is documented in MAINTAINING.md §"Accepted residuals (D-07 honest-truth disclosure)" and is unchanged.

---

## 5. SEED-004 + Determinism Attestation

### phx_new 1.8.7 Pin (SEED-004)

The `phx_new 1.8.7` archive is pinned in **9 locations** in `.github/workflows/ci.yml` (confirmed by `grep -n "phx_new 1.8.7" .github/workflows/ci.yml` — lines 169, 231, 344, 495, 556, 608, 664, 789, 1237). The pin is grep-auditable and has not changed since SEED-004 (commit `f5755a40`). No after-cohort run used a newer archive.

**Implication:** The golden-diff fixture committed at `test/sigra/install/fixtures/` matches the 1.8.7-generated output. Installing a newer archive (e.g. 1.8.8, which adds `config :phoenix_live_view, root_tag_attribute:` to `config.exs`) produces a spurious byte-diff locally. Contributors must install `mix archive.install --force hex phx_new 1.8.7` (documented in CLAUDE.md and CONTRIBUTING.md).

### Snapshot-Canary-Guard Attestation

`bash scripts/ci/snapshot-canary-guard.sh` run locally 2026-06-21:

```
snapshot-canary-guard: PASS (0 changed slug(s), all within allowlist)
```

The canary (`board-notice` snapshot) is byte-stable. The allowlist is at steady-state empty. No spurious snapshot drift is pending.

**Note on the 2026-06-20 run 27885649109 failure:** That failure was caused by a `snapshot-canary-guard` failure in `fast_checks` — the canary was modified in the PR branch (correct gate behavior: canary-modification is intentionally forbidden). This is the canary working as designed, not a flake. After the PR was amended/fixed, subsequent runs succeeded.

### Contract Lock Tests

The Phase 51 and Phase 192 contract lock tests remain green:

```
mix test test/sigra/planning/phase_51_install_golden_ci_contract_test.exs \
         test/sigra/planning/phase_192_known_failure_contract_test.exs
→ 3 tests, 0 failures (verified in 198-02 GATE-02 check)
```

These tests assert:
- `phase_51`: The path-detector regex appears **exactly twice** in `ci.yml` (structural lock on installer path-scoping logic).
- `phase_192`: The `test.skip(` marker in `admin-design.spec.ts` for MG-5/6 is present (locks the known-failure quarantine).

Both invariants are intact after the Phase 198 Plan 02 ci.yml edits (D-06).

---

## Capture Methodology

All timing data in this document was gathered read-only:

- Run list: `gh run list --workflow CI --json databaseId,event,conclusion,headSha,createdAt,updatedAt --limit 40`
- Per-job durations: `gh run view <id> --json jobs --jq '.jobs[] | {name, conclusion, startedAt, completedAt}'`
- Duration computation: `(completedAt - startedAt)` in seconds for each job; run-level wall-clock = `(run.updatedAt - run.createdAt)` from the run list
- Required-name check: `gh api repos/szTheory/sigra/rulesets/14941512 --jq '.rules[] | select(.type=="required_status_checks") | .parameters.required_status_checks[].context'`
- Capture date: 2026-06-21
- Authenticated as: szTheory (gh 2.x)

No `ci.yml`, spec, runtime code, or migration files were modified to produce this artifact.

---

## Decision References

| Decision ID | What it governs | Verdict |
|-------------|-----------------|---------|
| D-05 | Honest "after" capture — real runs, not estimates | Applied: all numbers from `gh run view --json jobs` with falsifiable run IDs |
| D-06 | design-gallery hard re-gate | Applied in Plan 02 (commit 32d43bb5); strengthens GATE-02 quality-signal claim |
| GATE-01 | PR-path meaningfully faster with equal-or-greater quality signal | Met: -16.5m avg (-43%), quality signal equal + strengthened (D-06) |
| GATE-02 | Required names stable, no flake, phx_new 1.8.7, determinism | Met: 5/5 names byte-stable, 0 flakes observed, pin confirmed, canary green |
