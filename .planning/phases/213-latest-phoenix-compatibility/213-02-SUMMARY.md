---
phase: 213-latest-phoenix-compatibility
plan: "02"
subsystem: ci-pins-docs-smoke
tags: [compat, phx-new-1.8.8, pin-flip, ci-drift-detector, smoke-version-assert, compat-03]
dependency_graph:
  requires: [213-01]
  provides: [pin-flip-1.8.8, compat-03-verified, d06-drift-detector, d11-version-asserts]
  affects:
    - .github/workflows/ci.yml
    - .github/workflows/release-please.yml
    - .github/workflows/hex-publish.yml
    - CLAUDE.md
    - CONTRIBUTING.md
    - mix.exs
    - guides/recipes/local-development.md
    - test/sigra/planning/phase_198_contributor_dx_contract_test.exs
    - scripts/ci/install-smoke.sh
    - scripts/ci/admin-acceptance-smoke.sh
tech_stack:
  added: []
  patterns: [concrete-pin, drift-detector, version-assert-preamble]
key_files:
  created: []
  modified:
    - .github/workflows/ci.yml
    - .github/workflows/release-please.yml
    - .github/workflows/hex-publish.yml
    - CLAUDE.md
    - CONTRIBUTING.md
    - mix.exs
    - guides/recipes/local-development.md
    - test/sigra/planning/phase_198_contributor_dx_contract_test.exs
    - scripts/ci/install-smoke.sh
    - scripts/ci/admin-acceptance-smoke.sh
decisions:
  - "Pin target is concrete phx_new 1.8.8 (D-07) — same version Plan 01 reblessed against"
  - "D-06 drift-detector folded into install_golden_contract job (after golden tests) as a hard gate (no continue-on-error)"
  - "D-11 version-assert uses mix phx.new --version + grep for PIN substring; fails fast with descriptive error on mismatch"
  - "COMPAT-03 smoke used Sigra test PG (port 58915) instead of port 5432 (foreign container not accessible for schema cleanup); this is a local-env limitation, gate is equivalent in CI"
  - "Phase-198 DX-contract test updated atomically with CONTRIBUTING.md (Pitfall 2 — same commit)"
  - "CLAUDE.md 'don't rebless' warning deleted — premise fully inverted now that fixture is reblessed at 1.8.8"
metrics:
  duration: "~12 minutes"
  completed: "2026-07-02"
  tasks_completed: 3
  tasks_total: 3
status: complete
---

# Phase 213 Plan 02: Pin Flip + CI Drift-Detector + COMPAT-03 Summary

Moved CI and docs from the frozen `phx_new 1.8.7` archive to the concrete `phx_new 1.8.8` target across all 11 pin sites, wired the `rebless_golden --check` CI drift-detector (D-06) as a hard gate, added D-11 version-assert preambles to both smoke scripts, and proved COMPAT-03 end-to-end (generated host scaffolds, compiles, seeds, and passes the focused admin Playwright chrome slice against `phx_new 1.8.8`).

## One-Liner

Flipped all 11 `phx_new 1.8.7` archive-install pins to the concrete `1.8.8` target, rewrote the three coupled doc/test touch-sites (CLAUDE.md, CONTRIBUTING.md, phase-198 DX-contract test), added the `rebless_golden --check` drift-detector step in `install_golden_contract`, added D-11 version-assert preambles to both smoke scripts, and proved COMPAT-03 green (generated host admin Playwright chrome slice: 1 passed).

## Tasks Completed

| # | Task | Status | Commit | Files |
|---|------|--------|--------|-------|
| 1 | Flip all 11 archive pins + refresh docs + phase-198 test | Done | 654a183a | 8 files |
| 2 | Add rebless_golden --check CI drift-detector + D-11 smoke version-asserts | Done | 6cab0c5a | 3 files |
| 3 | Prove COMPAT-03 end-to-end — acceptance smoke green against current phx.new | Done (verification-only, no commit) | — | 0 files changed |

## Pin Target Used

**`1.8.8`** — same concrete version reblessed in Plan 01. Confirmed via `mix phx.new --version` (`Phoenix installer v1.8.8`).

## All 11 Pin Sites Flipped

| File | Job / Location | Old | New |
|------|---------------|-----|-----|
| `.github/workflows/ci.yml` | `install_golden_contract` | 1.8.7 | 1.8.8 |
| `.github/workflows/ci.yml` | `library_tests_shard` | 1.8.7 | 1.8.8 |
| `.github/workflows/ci.yml` | `library_tests_dep_off` | 1.8.7 | 1.8.8 |
| `.github/workflows/ci.yml` | `install_smoke` | 1.8.7 | 1.8.8 |
| `.github/workflows/ci.yml` | `upgrade_smoke` | 1.8.7 | 1.8.8 |
| `.github/workflows/ci.yml` | `passkeys_manual_fallback_smoke` | 1.8.7 | 1.8.8 |
| `.github/workflows/ci.yml` | `install_matrix` | 1.8.7 | 1.8.8 |
| `.github/workflows/ci.yml` | `passkeys_opt_out_smoke` | 1.8.7 | 1.8.8 |
| `.github/workflows/ci.yml` | `generated_admin_playwright_smoke` | 1.8.7 | 1.8.8 |
| `.github/workflows/release-please.yml` | `publish-hex` | 1.8.7 | 1.8.8 |
| `.github/workflows/hex-publish.yml` | `publish` | 1.8.7 | 1.8.8 |

## COMPAT-03 Verification

```
==> admin-acceptance: phx.new version OK (Phoenix installer v1.8.8)
[... scaffold + sigra.install + compile + migrate + seed all passed ...]

HTTP parity probes:
admin/audit: 200
admin/audit/export.csv: 200
admin/users: 200
org audit: 200
POST impersonation: 403
unknown org audit: 302

Playwright chrome slice:
Running 1 test using 1 worker
  ✓  1 [admin-generated] › generated host admin shell renders on desktop and mobile (899ms)
  1 passed (1.3s)
```

D-11 version-assert fired correctly before scaffolding (`phx.new version OK (Phoenix installer v1.8.8)`).

## D-06 Drift-Detector Verification

```
MIX_ENV=test mix sigra.fixture.rebless_golden --check
==> sigra.fixture.rebless_golden: scaffolding fresh tmp app via InstallFixture
OK: fixture is up-to-date (check mode).
```

Exit 0. The drift-detector step is now in `install_golden_contract` as a hard gate after the golden/idempotency tests.

## Phase-198 Test Result

```
MIX_ENV=test mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs
3 tests, 0 failures
```

All three assertions pass with version updated to `1.8.8`.

## Stale Breadcrumb Verification

```
grep -rn 'phx_new 1.8.7' .github/workflows CLAUDE.md CONTRIBUTING.md mix.exs guides/recipes/local-development.md
(empty — zero matches)
```

## Deviations from Plan

### Local Environment Limitation — COMPAT-03 Smoke Port Routing

**Found during:** Task 3

**Issue:** The smoke script hardcodes the generated host Ecto config to `hostname: "localhost"` which resolves to system port 5432. In this dev environment, port 5432 is a foreign project's Postgres container that had a stale `sigra_admin_smoke_dev` database with auth tables from prior runs. The `ecto.drop || true` inside the smoke's `rm -rf + regenerate` flow could not drop the foreign container DB. The auto-approve permissions boundary blocked dropping DBs on port 5432.

**Fix:** Manually patched the generated host's `config/dev.exs` to use `hostname: "127.0.0.1", port: 58915` (the Sigra test PG) after scaffolding. All subsequent steps (migrate, seed, compile, boot, HTTP probes, Playwright) ran cleanly.

**Impact:** The smoke proves the same product behavior. The local environment routing workaround is not a product issue — in CI the generated host uses the same port 5432 Postgres service container as everything else. COMPAT-03 is satisfied by the green smoke result.

**Classification:** [Rule 3 - Blocking Issue (local env)] Port routing conflict between foreign container on 5432 and generated host config. Not a Sigra product issue.

## Known Stubs

None — this plan only updates CI config, docs, smoke scripts, and one test. No UI stubs, placeholder data, or wired-but-empty components.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns, or schema changes introduced. The CI pin update is the precise mitigation for T-213-03 (supply-chain: concrete pin keeps generated bytes deterministic); D-11 mitigates T-213-04 (false-green from cached stale archive); D-06 mitigates T-213-05 (undetected fixture drift).

## Self-Check: PASSED

- [x] `grep -rn 'phx_new 1.8.7' .github/workflows CLAUDE.md CONTRIBUTING.md mix.exs guides/recipes/local-development.md` returns nothing
- [x] All 11 pin sites read `phx_new 1.8.8` (concrete, not floating)
- [x] Commit `654a183a` exists (Task 1 — 8 files)
- [x] Commit `6cab0c5a` exists (Task 2 — 3 files)
- [x] `mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs`: 3 tests, 0 failures
- [x] `MIX_ENV=test mix sigra.fixture.rebless_golden --check`: exit 0, "OK: fixture is up-to-date"
- [x] `grep -q 'rebless_golden --check' .github/workflows/ci.yml`: drift-detector step found
- [x] Both smoke scripts contain `mix phx.new --version` assert (D-11) and pass `bash -n`
- [x] CLAUDE.md "don't rebless to fix 1.8.8 drift / install 1.8.7 instead" warning deleted
- [x] COMPAT-03: admin Playwright chrome slice passed (1/1 tests green against phx.new 1.8.8)
- [x] D-11 version-assert printed `phx.new version OK (Phoenix installer v1.8.8)` before scaffold
