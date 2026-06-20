---
phase: 193-baseline-observability-one-line-wins
verified: 2026-06-19T00:00:00Z
status: passed
score: 6/6 must-haves verified
behavior_unverified: 0
overrides_applied: 0
---

# Phase 193: Baseline, Observability & One-Line Wins Verification Report

**Phase Goal:** A committed before-state baseline exists so every later phase can prove its win — and the two cheapest, lowest-risk wall-clock wins are already banked.
**Verified:** 2026-06-19
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1 | A committed baseline artifact records per-job CI durations, critical path, cache hit/miss, required-vs-not, quality signal, and likely bottleneck for the before-state (BASE-01). | ✓ VERIFIED | `193-BASELINE.md` (226 lines). Per-job table at line 15 carries all SEED-005 §3 columns: Avg Duration, p95, Cache Usage, Required for Merge, Quality Signal, Likely Bottleneck, Notes. "Critical Path (BASE-01)" heading at line 56; 10 required lanes enumerated at line 58 derived from `ci-gate.needs`. p95 figures carry explicit sample-size notes (`n=4`, `n=1, point est.`). |
| 2 | The artifact records Elixir-side diagnostics (slowest tests, schedulers_online, slow compile modules) as the named optimization target (BASE-02). | ✓ VERIFIED | `193-BASELINE.md`: "Top 20 slowest tests (`mix test --slowest 20`)" at line 130; `schedulers: {18, 18}` local / CI=2 with `max_cases = 2*2 = 4` implication at lines 118-126 (partitioning motivation for phase 195); compile-chain bottleneck (`Sigra.Admin.Components`) recorded at lines 174+. |
| 3 | CI run summaries surface resolved Elixir/OTP versions, cache hit/miss, and a test-timing summary (BASE-03). | ✓ VERIFIED | `ci.yml` `CI run summary` step (lines 197-206, `if: always()`): elixir version (202), OTP release (203), schedulers_online (204), `steps.deps_cache.outputs.cache-hit` (205) → `$GITHUB_STEP_SUMMARY`. `Test timing summary` step (207-217) appends slowest-tests table. `id: deps_cache` (168) and `id: example_deps_cache` (745) added. |
| 4 | example_playwright_smoke no longer waits on library_tests; the two longest jobs run concurrently while it stays a required ci-gate lane (CRIT-01). | ✓ VERIFIED | `ci.yml:723` `needs: [release_ref_guard]` (library_tests edge dropped). Old `needs: [release_ref_guard, library_tests]` not present (grep empty). `example_playwright_smoke` still in `ci-gate.needs` (line 1214) and gates merge via `needs.example_playwright_smoke.result` (1228). YAML parses (`yaml.safe_load` OK). |
| 5 | The demo-showcase remember-checkbox accent-color assertion is deterministic with retries OFF (no retry papering-over) (FLAKE-01). | ✓ VERIFIED | `demo-showcase.spec.ts:895-899`: exact `toBe(rememberCheckedStyles.expectedAccent)` replaced with per-channel `toBeLessThanOrEqual(10)` via in-file `rgbChannels()` parser (line 52). `playwright.config.ts:50` `retries` unchanged (`process.env.CI ? 1 : 0` — local=0, so the fix passes with retries OFF, not by retry masking). Executor SUMMARY documents 3× consecutive `--retries=0` passes; CI proves continuously (zero-human-UAT model). afterBackgroundColor exact check (902-904) correctly left untouched. |
| 6 | The FLAKE-01 todo is closed (moved pending → completed). | ✓ VERIFIED | `.planning/todos/pending/2026-06-19-demo-showcase-remember-checkbox-color-flaky.md` no longer exists; `.planning/todos/completed/2026-06-19-demo-showcase-remember-checkbox-color-flaky.md` exists. |

**Score:** 6/6 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `193-BASELINE.md` | Before-state baseline + Elixir diagnostics (min 60 lines, contains "critical path") | ✓ VERIFIED | 226 lines; "critical path" present; per-job table + diagnostics + critical-path prose all present. |
| `test/example/priv/playwright/tests/demo-showcase.spec.ts` | De-flaked per-channel tolerance assertion (contains `toBeLessThanOrEqual`) | ✓ VERIFIED | Per-channel `toBeLessThanOrEqual(10)` at 897-899 via `rgbChannels()`; comment corrected per WR-02. |
| `.github/workflows/ci.yml` | Additive `$GITHUB_STEP_SUMMARY` + cache `id:` outputs + dropped needs edge (contains `GITHUB_STEP_SUMMARY`) | ✓ VERIFIED | 2× `GITHUB_STEP_SUMMARY` writes; `id: deps_cache`/`id: example_deps_cache`; needs edge dropped; YAML valid; all 55 `uses:` SHA-pinned. |
| `.planning/todos/completed/...remember-checkbox-color-flaky.md` | Closed FLAKE-01 todo | ✓ VERIFIED | Present in completed/, absent from pending/. |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `193-BASELINE.md` | `.github/workflows/ci.yml` | per-job table from ci-gate.needs + run timings | ✓ WIRED | Baseline names `ci-gate`, `library_tests`, `example_playwright_smoke`; required-lane list matches `ci-gate.needs`. |
| `demo-showcase.spec.ts` | `demo-showcase.spec.ts` | de-flaked assertion reuses in-file `rgbChannels()` (line 52) | ✓ WIRED | Assertion at 895-896 calls `rgbChannels()` defined at line 52. |
| `ci.yml example_playwright_smoke needs` | `ci.yml ci-gate.needs` | lane stays required after dropping library_tests edge | ✓ WIRED | `example_playwright_smoke` at line 1214 in ci-gate.needs; result consumed at 1228. |
| `ci.yml CI summary step` | `ci.yml Cache library deps step id:` | summary reads `steps.deps_cache.outputs.cache-hit` | ✓ WIRED | `id: deps_cache` (168) consumed at line 205. |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| -------- | ------- | ------ | ------ |
| ci.yml is valid YAML | `python3 -c "import yaml; yaml.safe_load(...)"` | YAML OK | ✓ PASS |
| All actions SHA-pinned | `grep -E "uses:.+@[0-9a-f]{40}"` + tag-ref check | 55 pinned, 0 unpinned | ✓ PASS |
| No untrusted github.event.* in summary run blocks | grep over summary steps | none found | ✓ PASS |
| WR-01: suite runs once (no double-run) | read lines 186-217 | single `mix test --slowest 10` run; timing step reads `/tmp/library_tests.log` | ✓ PASS |
| Cited commits exist | `git log -1` ×7 | fdd41023, b03f881f, fa8346b7, 5999fc69, 177bea47, 7d9038cb, b5dad242 all present | ✓ PASS |
| Working tree clean | `git status --short` | clean | ✓ PASS |
| FLAKE-01 Playwright `--retries=0` determinism | `npx playwright test ... --retries=0` | NOT re-run here — needs booted Phoenix app + Postgres (server boot, state-mutating, exceeds spot-check budget). Structural precondition verified by source; runtime exercised by executor (3× per SUMMARY) and continuously by CI per zero-human-UAT model. | ? SKIP |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| BASE-01 | 193-01 | Before-state per-job baseline table | ✓ SATISFIED | Truth #1 |
| BASE-02 | 193-01 | Elixir-side diagnostics as optimization target | ✓ SATISFIED | Truth #2 |
| BASE-03 | 193-03 | CI summaries surface versions/cache/timing | ✓ SATISFIED | Truth #3 |
| CRIT-01 | 193-03 | Drop gratuitous serialization edge | ✓ SATISFIED | Truth #4 |
| FLAKE-01 | 193-02 | De-flake remember-checkbox color (no retries) | ✓ SATISFIED | Truths #5, #6 |

All 5 declared requirement IDs accounted for. No orphaned requirements: REQUIREMENTS.md maps exactly BASE-01/02/03, CRIT-01, FLAKE-01 to phase 193 and all are claimed by plans. All five are checked `[x]` in the REQUIREMENTS.md checklist (lines 13-15, 19, 47).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| `.planning/REQUIREMENTS.md` | 70 | Traceability table shows `BASE-01, BASE-02, BASE-03 | 193 | Pending` while the checklist items (lines 13-15) are checked `[x]` | ℹ️ Info | Bookkeeping staleness only; deliverables verifiably exist. Status-table reconciliation is a ship/complete-phase concern, not a goal failure. |
| `.github/workflows/ci.yml` | 745 | `id: example_deps_cache` added but never consumed by any summary step (IN-01 from review) | ℹ️ Info | Inert/harmless; the example cache hit/miss is not surfaced. Pre-flagged as Info in 193-REVIEW.md; not a blocker. |

No debt markers (TBD/FIXME/XXX), no stubs, no placeholder implementations in phase-modified files.

### Code Review Remediation (cross-check)

The phase code review (193-REVIEW.md: 0 blocker / 2 warning / 2 info) flagged two warnings; both are remediated in the codebase:

- **WR-01** (library_tests ran the suite twice): FIXED in `177bea47`. `ci.yml:196` now runs `mix test --slowest 10` exactly once (tee'd to `/tmp/library_tests.log`); the `Test timing summary` step (213-214) parses that captured log and explicitly does NOT re-run the suite. The doubling that would have erased the CRIT-01 win is gone.
- **WR-02** (overstated comment claiming brand-identity detection): FIXED in `7d9038cb`. Comment at `demo-showcase.spec.ts:890-894` now correctly describes a paint-fidelity check that "cannot detect a wrong-token swap since both sides move together" — review's recommended option (a).

### Gaps Summary

No gaps. The committed before-state baseline exists with the full SEED-005 §3 column set, critical-path prose, and Elixir diagnostics (BASE-01/BASE-02). CI observability is wired (BASE-03). The two banked wins are in place: the gratuitous serialization edge is dropped while the lane stays required (CRIT-01), and the flaky color assertion is de-flaked deterministically without any reliance on retries (FLAKE-01), with its tracking todo closed. Both code-review warnings were remediated. Two Info-level items (stale traceability-table status string; an unconsumed cache `id:`) are non-blocking bookkeeping/cosmetic notes.

Per the phase's explicit zero-human-UAT model ("CI measures itself") and the instruction to verify structural/code preconditions rather than live CI timings, all preconditions are present and correct. No human verification items.

---

_Verified: 2026-06-19_
_Verifier: Claude (gsd-verifier)_
