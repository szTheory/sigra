---
phase: 194-caching-correctness-micro-job-consolidation
verified: 2026-06-19T00:00:00Z
status: passed
score: 15/15
behavior_unverified: 0
overrides_applied: 0
re_verification: false
---

# Phase 194: Caching Correctness + Micro-Job Consolidation Verification Report

**Phase Goal:**
- CACHE-01: Audit and correct GitHub Actions caching — precise keys (OS/arch/OTP/Elixir/MIX_ENV/lockfile/buster), no `_build` reuse across incompatible combos, never skip `deps.get` after a partial restore, separate deps cache from any PLT cache, document how to bust.
- CACHE-02: Consolidate the trivial micro-guard jobs into one cheap "fast checks" job, preserving the stable required-check names, keeping `release_ref_guard` standalone, porting the installer-audit PR-path gate, and rewiring `ci-gate` in lockstep.

**Verified:** 2026-06-19
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

#### CACHE-01 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Every one of the 11 deps+`_build` cache keys binds OS, resolved OTP version, resolved Elixir version, MIX_ENV (test/dev literal), the lockfile hash, and a trailing `-v1` manual buster (D-04). | VERIFIED | `grep -cE 'otp\$\{\{ steps\.setup\.outputs\.otp-version \}\}-elixir\$\{\{ steps\.setup\.outputs\.elixir-version \}\}'` returns **22** (11 key lines + 11 restore-keys lines). `grep -cE '\-v1$'` returns **11**. All 11 precision-key lines confirmed at lines 150, 201, 278, 350, 411, 471, 522, 583, 701, 752, 832 in ci.yml. |
| 2 | The 4 existing cache namespaces (`-library-`, `-library-dep-off-`, `-example-`, `-example-dev-`) are preserved so lanes do not cross-contaminate (D-05). | VERIFIED | All 4 namespaces confirmed present in ci.yml. `-library-dep-off-` count: 2; `-library-` count: 16 (includes dep-off); `-example-` count: 11; `-example-dev-` count: 4. Each namespace uses the MIX_ENV literal matching its workload (-test- or -dev-). |
| 3 | `deps` and `_build` stay co-located in one cache entry; no shared deps+PLT key is introduced (D-06). | VERIFIED | All 11 `path:` blocks list only `deps`/`test/example/deps` and `_build`/`test/example/_build`. No PLT paths appear anywhere in cache path blocks. No PLT-related cache keys introduced. |
| 4 | `mix deps.get` remains an unconditional always-run step in every lane, never gated on cache-hit (D-07). | VERIFIED | All `mix deps.get` occurrences (lines 162, 213, 289, 354, 426, 486, 537, 592, 615, 643, 716, 758, 838) inspected. The single `if: steps.detect.outputs.run == 'true'` on line 161 gates the entire `install_golden_contract` lane on a path-scoped PR detect, NOT on cache-hit — this is explicitly permitted by D-07. No `if: steps.*cache.outputs.cache-hit` condition appears on any `mix deps.get` step. |
| 5 | Cache hit-rate is surfaced in `$GITHUB_STEP_SUMMARY` via `if: always()` steps reading `steps.<id>.outputs.cache-hit`, labelled honestly as an exact hit (D-09). | VERIFIED | Exactly 6 `outputs.cache-hit` references found (grep returns 6). All 6 use the label `"deps cache (exact hit)"` with the correct step ID. Lines: 233 (`deps_cache`), 321 (`dep_off_deps_cache`), 379 (`example_unit_deps_cache`), 441 (`install_smoke_deps_cache`), 797 (`http_smoke_deps_cache`), 1019 (`example_deps_cache`). |
| 6 | The orphan `example_deps_cache` id (playwright lane) has its `cache-hit` read into a summary line (no dead id). | VERIFIED | `id: example_deps_cache` at line 826; its `cache-hit` is consumed at line 1019 in an `if: always()` summary step: `"deps cache (exact hit): ${{ steps.example_deps_cache.outputs.cache-hit }}"`. |
| 7 | MAINTAINING.md documents the `-v1` buster value and the how-to-bust procedure under the Actions/cache-retention runbook heading (D-10). | VERIFIED | MAINTAINING.md heading `#### Actions deps+_build cache keys (CACHE-01)` exists under `### Artifact, log, and cache retention`. Contains: key shape template, `-v1` buster value, "How to bust" instructions (bump `-v1` to `-v2`), D-06 forward-looking PLT note, and note about hex-registry exclusion. |

#### CACHE-02 Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 8 | The 6 leaf guards (`milestone_verification_gate`, `installer_milestone_audit`, `getting_started_uat_contract`, `phase_34_uat_contract`, `snapshot_drift_guard`, `quality_ledger_monotonic`) are folded into ONE `fast_checks` job (D-11). | VERIFIED | `grep -cE '^  fast_checks:'` = 1. `grep -cE '^  (milestone_verification_gate\|installer_milestone_audit\|getting_started_uat_contract\|phase_34_uat_contract\|snapshot_drift_guard\|quality_ledger_monotonic):'` = 0. All 6 job keys are absent from ci.yml at the top level. |
| 9 | `release_ref_guard` remains a separate standalone no-checkout job (D-12). | VERIFIED | `grep -cE '^  release_ref_guard:'` = 1. The `release_ref_guard` job at line 24 has no `uses: actions/checkout` step — it is a pure shell script no-checkout job as required. |
| 10 | `fast_checks` uses a single `checkout` with `fetch-depth: 0` plus the per-PR `git fetch origin <base_ref> --depth=1` base-ref pattern, run once; each of the 6 guards is a distinct named `run:` step (D-13). | VERIFIED | `fast_checks` job (lines 48-100) has exactly one `actions/checkout` at line 52 with `fetch-depth: 0`. One `Resolve base ref` step (`id: base`) at line 55. Six distinct named `run:` steps: Milestone verification gate, Detect installer-related changes (PRs only), Installer milestone audit (INT-01..03), Getting started doc contract, Phase 34 UAT contracts, Snapshot drift guard (canary allowlist), Snapshot drift guard — design lane, Quality ledger monotonic guard. |
| 11 | The `installer_milestone_audit` PR-path detect gate is ported faithfully so the installer audit still only runs on installer-touching PRs (LANDMINE). | VERIFIED | `grep -qE "if: steps\.detect\.outputs\.run == 'true'"` returns present. `id: detect` step at line 69 uses exact path pattern `'^priv/templates/sigra\.install/\|^lib/sigra/install/\|^lib/sigra/mfa(\.ex/)\|^lib/sigra/oauth(\.ex/)\|^lib/sigra/account(\.ex/)\|^lib/sigra/passkeys(\.ex/)'`. Installer audit step at line 83 gated with `if: steps.detect.outputs.run == 'true'`. |
| 12 | `ci-gate.needs` is rewired in lockstep: `snapshot_drift_guard` + `quality_ledger_monotonic` dropped, `fast_checks` added, and the `${{ needs.*.result }}` env block + aggregation loop updated (D-14). | VERIFIED | `grep -qE '^      - fast_checks$'` confirmed present. `FAST_CHECKS: ${{ needs.fast_checks.result }}` at line 1243. `FAST_CHECKS` in the loop at line 1256. `grep -c 'needs.snapshot_drift_guard.result'` = 0. `grep -c 'needs.quality_ledger_monotonic.result'` = 0. |
| 13 | Both snapshot sub-steps (default + design-lane `--canary board-notice`) are present inside `fast_checks`. | VERIFIED | Line 91: `bash scripts/ci/snapshot-canary-guard.sh --base "${{ steps.base.outputs.ref }}"`. Lines 93-99: design lane sub-step with `SNAP_DIR=...`, `--allowlist`, `--canary board-notice` arguments. Both `steps.base.outputs.ref` references confirmed at lines 91, 96, 100. |
| 14 | MAINTAINING.md's required-check documentation is corrected to the 5 live ruleset names and notes `ci-gate` is an internal aggregator, not the enforced required check (D-15). | VERIFIED | `grep -c 'Install golden + idempotency contract' MAINTAINING.md` = 0 (stale string fully absent). All 5 live names confirmed present: `Library tests`, `Example unit smoke (ExUnit + ConnTest)`, `Install smoke (fresh phx.new + sigra.install)`, `Example HTTP smoke (boot + curl critical routes)`, `Example Playwright smoke (full lifecycle)`. `grep -qiE 'ci-gate.*(aggregat\|not.*required\|internal)'` confirms present (line 112: "`ci-gate` is NOT an enforced required check. It is an internal aggregator job..."). `grep -q '14941512' MAINTAINING.md` confirmed. |
| 15 | The 5 protected required-check `name:` strings are not renamed or removed. | VERIFIED | All 5 confirmed at: `Library tests` (line 173), `Example unit smoke (ExUnit + ConnTest)` (line 325), `Install smoke (fresh phx.new + sigra.install)` (line 385), `Example HTTP smoke (boot + curl critical routes)` (line 726), `Example Playwright smoke (full lifecycle)` (line 801). `phx_new 1.8.7` steps unchanged (confirmed at lines 159, 211, 285, 424, 484, 535, 590, 714, 1130). |

**Score:** 15/15 truths verified (0 present, behavior-unverified)

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `.github/workflows/ci.yml` | 11 precision-keyed deps+_build cache blocks with `id:`, cache-hit summary lines, `fast_checks` job | VERIFIED | All 11 IDs present: `install_golden_deps_cache`, `deps_cache`, `dep_off_deps_cache`, `example_unit_deps_cache`, `install_smoke_deps_cache`, `upgrade_smoke_deps_cache`, `passkeys_fallback_deps_cache`, `install_matrix_deps_cache`, `passkeys_opt_out_deps_cache`, `http_smoke_deps_cache`, `example_deps_cache`. `fast_checks` job present with 6 guard steps. |
| `MAINTAINING.md` | Cache key + how-to-bust subsection (D-10) + corrected required-check list (D-15) | VERIFIED | `#### Actions deps+_build cache keys (CACHE-01)` subsection present. 5 live required-check names listed. Stale string eliminated. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `erlef/setup-beam` step (`id: setup`) | each deps cache `key:` | `steps.setup.outputs.otp-version` / `steps.setup.outputs.elixir-version` | VERIFIED | 22 occurrences of both outputs in cache key expressions (11 `key:` lines + 11 `restore-keys:` lines). Pattern `steps\.setup\.outputs\.(otp\|elixir)-version` confirmed across all 11 lanes. |
| `actions/cache` step (cache id) | `$GITHUB_STEP_SUMMARY` | `if: always()` step echoing `steps.<id>.outputs.cache-hit` | VERIFIED | 6 cache-hit summary steps confirmed with `if: always()` and exact-hit labeling at lines 226-234, 316-322, 374-380, 436-442, 792-798, 1014-1020. |
| `fast_checks` job | `ci-gate.needs` | `fast_checks` listed in `ci-gate.needs` and `FAST_CHECKS` in the result-aggregation loop | VERIFIED | `fast_checks` in `ci-gate.needs` array. `FAST_CHECKS: ${{ needs.fast_checks.result }}` in env block. `FAST_CHECKS` in loop. |
| `fast_checks` "Resolve base ref" step (`id: base`) | snapshot + ledger guard `run:` steps | `${{ steps.base.outputs.ref }}` consumed by `--base` flag | VERIFIED | 3 occurrences of `steps.base.outputs.ref` at lines 91, 96, 100 — all within `fast_checks` job's guard steps. |

---

### Data-Flow Trace (Level 4)

Not applicable — this phase modifies only CI workflow YAML and documentation. No dynamic data rendering or application state involved.

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Workflow parses and lints correctly | `/opt/homebrew/bin/actionlint .github/workflows/ci.yml` | exit 0, no output | PASS |
| 11 precision cache keys with OTP+Elixir outputs | `grep -cE 'otp\$\{\{ steps\.setup\.outputs\.otp-version \}\}-elixir\$\{\{ steps\.setup\.outputs\.elixir-version \}\}'` | 22 | PASS (11 key + 11 restore-keys) |
| 11 `-v1` buster segments | `grep -cE '\-v1$' ci.yml` | 11 | PASS |
| 8 hex-registry lines unchanged | `grep -c 'hex-registry-' ci.yml` | 8 | PASS |
| 6 cache-hit summary references | `grep -c 'outputs.cache-hit' ci.yml` | 6 | PASS |
| `fast_checks` present (count == 1) | `grep -cE '^  fast_checks:'` | 1 | PASS |
| 6 folded job keys absent (count == 0) | `grep -cE '^  (milestone_verification_gate\|installer_milestone_audit\|...):'` | 0 | PASS |
| `release_ref_guard` present standalone | `grep -cE '^  release_ref_guard:'` | 1 | PASS |
| Installer detect gate ported | `grep -qE "if: steps\.detect\.outputs\.run == 'true'"` | present | PASS |
| `fast_checks` in `ci-gate.needs` | `grep -qE '^      - fast_checks$'` | present | PASS |
| Old guard results removed from ci-gate | `grep -c 'needs.snapshot_drift_guard.result'` | 0 | PASS |
| Old guard results removed from ci-gate | `grep -c 'needs.quality_ledger_monotonic.result'` | 0 | PASS |
| Stale MAINTAINING.md string absent | `grep -c 'Install golden + idempotency contract' MAINTAINING.md` | 0 | PASS |

---

### Probe Execution

Step 7c: No probes declared. This is a CI-self-validation phase — the authoritative mechanical gate is `actionlint` + `grep` assertions (all passed above). The live-CI wave gate (push + `gh run watch`) is a deferred manual follow-up explicitly noted in both PLANs as intentionally not run during execution (commits landed on local main, unpushed). Per the phase context, absence of a live CI run is NOT treated as a gap.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| CACHE-01 | 194-01-PLAN.md | Precise cache keys (OS/OTP/Elixir/MIX_ENV/lockfile/buster), no `_build` reuse, unconditional `deps.get`, separate PLT, document bust handle | SATISFIED | All 11 deps+_build cache keys verified with OTP+Elixir outputs, `-v1` buster, 4 namespaces, no PLT merging, `mix deps.get` ungated on cache-hit, MAINTAINING.md bust docs present |
| CACHE-02 | 194-02-PLAN.md | Consolidate 6 micro-guard jobs into `fast_checks`, keep `release_ref_guard` standalone, port installer-audit gate, rewire `ci-gate`, correct MAINTAINING.md required-check docs | SATISFIED | `fast_checks` job with 6 guard steps, `release_ref_guard` standalone, `if: steps.detect.outputs.run == 'true'` gate ported, `ci-gate.needs` rewired with `FAST_CHECKS`, MAINTAINING.md corrected |

Note: REQUIREMENTS.md shows CACHE-01 as unchecked (`[ ]`) and CACHE-02 as checked (`[x]`). This is a tracking artifact — the content verification above confirms CACHE-01 was fully executed and its deliverables exist in the codebase. The checkbox state in REQUIREMENTS.md is a documentation tracking issue, not a content gap.

---

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `.github/workflows/ci.yml` | `continue-on-error: true` on `Run design gallery boards` step (line 971, not introduced by this phase) | Info | Pre-existing. The design gallery spec is `SEED-006 NON-BLOCKING` (documented inline). Not introduced by phase 194 and not a phase 194 gap. |

No debt markers (`TBD`, `FIXME`, `XXX`) introduced by this phase.
No stubs.
No orphaned artifacts.

---

### Human Verification Required

None. All truths are mechanically verifiable via `actionlint` + grep over the workflow YAML and MAINTAINING.md. The live-CI wave gate is deferred by design and does not affect the mechanical verification result.

---

### Gaps Summary

No gaps. All 15 must-have truths are VERIFIED against the actual codebase:

- All 11 deps+`_build` cache keys bind OS + resolved OTP + resolved Elixir + MIX_ENV literal + lockfile hash + `-v1` buster via `erlef/setup-beam` resolved outputs.
- 4 namespaces preserved, no cross-contamination.
- `deps` and `_build` co-located in every cache path block; no PLT paths introduced.
- `mix deps.get` unconditional in all lanes (the one `if: detect` on the `install_golden_contract` lane gates on PR path-scope, not cache-hit — compliant with D-07).
- Cache hit-rate surfaced in `$GITHUB_STEP_SUMMARY` with honest exact-hit labels on 6 lanes.
- Orphan `example_deps_cache` id wired into playwright lane summary.
- MAINTAINING.md documents the `-v1` bust handle, key shape, D-06 PLT separation note, and hex-registry exclusion rationale.
- `fast_checks` job consolidates 6 guards (single checkout + single base-ref resolve + 6 distinct named steps).
- `release_ref_guard` kept standalone.
- Installer-audit detect gate ported faithfully with exact path pattern and `if: steps.detect.outputs.run == 'true'`.
- Both snapshot drift guard sub-steps (default canary allowlist + design lane) present in `fast_checks`.
- `ci-gate.needs` rewired: `snapshot_drift_guard` + `quality_ledger_monotonic` dropped, `fast_checks` added; env block and loop updated in lockstep.
- 5 protected required-check `name:` strings unchanged byte-for-byte.
- `phx_new 1.8.7` pins untouched.
- MAINTAINING.md stale string (`Install golden + idempotency contract`) absent (0 occurrences); 5 live required-check names present; `ci-gate` internal aggregator note present; ruleset 14941512 reference present.
- `actionlint` exits 0 with no warnings.

---

_Verified: 2026-06-19_
_Verifier: Claude (gsd-verifier)_
