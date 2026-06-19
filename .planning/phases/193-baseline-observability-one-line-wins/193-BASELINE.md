# 193-BASELINE — CI Performance Before-State (BASE-01 / BASE-02)

**Phase:** 193 — baseline-observability-one-line-wins  
**Captured:** 2026-06-19  
**Primary sample:** run `27846034918` (pull_request, 2026-06-19, conclusion: success)  
**Sample set for p95:** n=9 successful runs from 2026-06-13 to 2026-06-19 (see p95 note below)  
**Purpose:** Falsifiable reference for phases 194-198. Every later optimization claim diffs against this document.

---

## Per-Job Baseline Table (BASE-01)

> **Sample-size note (SEED-005 Pitfall 2):** n=9 successful runs total (from 2026-06-13 through 2026-06-19). For the 3 long-pole jobs (example_playwright_smoke, library_tests, library_tests_dep_off), p95 is computed from n=9 and labeled accordingly. For jobs where timing was only observed in run 27846034918, no p95 is computed — "n=1, point est." is shown. Jobs that did not run in the older 2026-06-13 cohort (which had fewer jobs) are also labeled.

| Workflow | Trigger | Job Name (id) | Runner | Matrix | Services | Commands | Avg Duration | p95 Duration | Failure/Rerun Rate | Cache Usage | Required for Merge | Quality Signal | Likely Bottleneck | Notes |
|----------|---------|--------------|--------|--------|----------|----------|-------------|-------------|-------------------|-------------|-------------------|---------------|-------------------|-------|
| CI | push, pull_request, workflow_dispatch | **Example Playwright smoke** (`example_playwright_smoke`) | ubuntu-latest | — | postgres:14 | `mix deps.get`, `mix compile`, `mix ecto.setup`, `npm ci`, `mix phx.gen.secret`, `npx playwright test` (multiple spec files) | 1329s (22.2m) | **1336s** (22.3m; n=4 2026-06-19 runs, the 578s 2026-06-13 run was on an older codebase) | unknown (recent CI green streak; older runs had unrelated failures) | node npm: HIT; example deps: HIT | **YES** (ci-gate.needs) | Full lifecycle browser smoke (register, login, MFA, OAuth, admin, passkeys) — highest-value end-to-end gate | Boot time (seeding, compile, PG service startup) + full test suite execution | **CRIT-01 target.** Currently serialized behind library_tests via gratuitous `needs: library_tests` edge (see Critical Path). Starts 2s after library_tests finishes. |
| CI | push, pull_request, workflow_dispatch | **Library tests** (`library_tests`) | ubuntu-latest | — | postgres:14 | `mix deps.get`, `mix compile --warnings-as-errors`, `mix ecto.setup`, `mix test`, `mix docs --warnings-as-errors` | 960s (16.0m) | **977s** (16.3m; n=4) | low (recent streak green) | library deps: HIT | **YES** (ci-gate.needs) | Core library correctness; the primary regression gate for all 2401+ tests | `mix test` (full suite, no `--partitions`) dominates; `mix docs` adds ~1-2m | Long pole #2. 186 async + 27 non-async test modules; 274 `*_test.exs` files. SEED-005 thesis #5: 2-core runner under-serves 186-async suite. |
| CI | push, pull_request, workflow_dispatch | **Library tests dep-off** (`library_tests_dep_off`) | ubuntu-latest | — | postgres:14 | Same as library_tests + `THREADLINE_ABSENT=true mix test` | 830s (13.8m) | **840s** (14.0m; n=4) | low | library deps (dep-off key): HIT | **YES** (ci-gate.needs) | Proves `Code.ensure_loaded?` guards work without `:threadline`; catches compile-time coupling bugs | `mix test` (full suite re-run — only the `:threadline` dep is removed) | TEST-02 target (phase 195): re-runs the entire ~14m suite to prove guards work; should use a targeted subset. |
| CI | push, pull_request, workflow_dispatch | Install golden + idempotency contract (`install_golden_contract`) | ubuntu-latest | — | postgres:14 | subprocess harness: `phx.new` + `mix sigra.install` + idempotency checks | 28s (n=1 2026-06-19) | 281s (n=4 recent; wide spread 28-281s suggests cold vs warm cache variance) | low | library deps: cache (no `id:` yet; read from logs) | **YES** (ci-gate.needs) | Golden fixture byte-for-byte parity; idempotency of `mix sigra.install` | phx.new archive install time vs subprocess spawn; cache variance | Large duration spread (28s–281s) suggests sensitive to hex registry cache state. The 28s hit in run 27846034918 was a fast warm-cache run. |
| CI | push, pull_request, workflow_dispatch | Install smoke (`install_smoke`) | ubuntu-latest | — | postgres:14 | `phx.new`, `mix sigra.install`, boot + curl | 109s (n=1, point est.) | n=1, point est. | low | library deps: HIT; hex registry: HIT | **YES** (ci-gate.needs) | Proves a fresh install of phx.new + sigra.install produces a bootable app | phx.new archive + dep install | SEED-004 phx_new 1.8.7 pin must be preserved. |
| CI | push, pull_request, workflow_dispatch | Upgrade smoke (`upgrade_smoke`) | ubuntu-latest | — | postgres:14 | published source + `mix sigra.upgrade` | 97s (n=1, point est.) | n=1, point est. | low | library deps: HIT; hex registry: HIT | **YES** (ci-gate.needs) | Proves upgrade from published source to local candidate | dep install + upgrade migration | Non-trivial (97s) due to two full `mix deps.get` + compile passes. |
| CI | push, pull_request, workflow_dispatch | Example HTTP smoke (`example_http_smoke`) | ubuntu-latest | — | postgres:14 | boot example + curl critical routes | 49s (n=1, point est.) | n=1, point est. | low | example deps (dev): cache (no `id:` yet) | **YES** (ci-gate.needs) | Proves example app boots and critical HTTP endpoints return 200 | PG service startup + boot + requests | Fast gate; provides early boot-regression signal. |
| CI | push, pull_request, workflow_dispatch | **Generated admin Playwright smoke** (`generated_admin_playwright_smoke`) | ubuntu-latest | — | postgres:14 | phx.new + sigra.install + boot + npm + playwright | 174s (2.9m; n=2 recent avg) | 187s (n=4; wide) | low | node npm: HIT | **YES** (ci-gate.needs) | Proves generated admin UI renders correctly in a fresh scaffold | Scaffold time + playwright test | `timeout-minutes: 60` set; actual runtime ~3m. |
| CI | push, pull_request, workflow_dispatch | Snapshot drift guard (`snapshot_drift_guard`) | ubuntu-latest | — | — | `scripts/ci/snapshot-canary-guard.sh` | 6s (n=1, point est.) | n=1, point est. | low | none | **YES** (ci-gate.needs) | Detects admin Playwright snapshot drift vs committed baseline | trivial shell | Fast quality signal. |
| CI | push, pull_request, workflow_dispatch | Quality ledger monotonic guard (`quality_ledger_monotonic`) | ubuntu-latest | — | — | shell ledger-monotonic check | 7s (n=1, point est.) | n=1, point est. | low | none | **YES** (ci-gate.needs) | Enforces quality tier can only go up (monotonic) | trivial shell | Fast, cheap correctness guard. |
| CI | push, pull_request, workflow_dispatch | Passkeys opt-out smoke (`passkeys_opt_out_smoke`) | ubuntu-latest | — | postgres:14 | `mix sigra.install --no-passkeys` + smoke | 180s (n=1, point est.) | n=1, point est. | low | library deps: HIT; hex registry: likely HIT | no (signal-only) | Proves passkeys opt-out flag produces a working app | dep install + phx.new + smoke | Not in ci-gate.needs; signal-only lane. |
| CI | push, pull_request, workflow_dispatch | Passkeys manual fallback smoke (`passkeys_manual_fallback_smoke`) | ubuntu-latest | — | postgres:14 | `mix sigra.install --passkeys` manual fallback path | 115s (n=1, point est.) | n=1, point est. | low | library deps: HIT; hex registry: likely HIT | no (signal-only) | Proves passkeys manual-wiring path works | dep install + smoke | Signal-only lane. |
| CI | push, pull_request, workflow_dispatch | Install matrix (`install_matrix`) ×4 | ubuntu-latest | `--no-passkeys`, `--no-organizations`, `--no-organizations --no-passkeys`, default | postgres:14 | `mix sigra.install` flag combos | 105-109s each (n=1, point est.) | n=1, point est. | low | library deps: likely HIT | no (signal-only) | Proves all 4 flag-combination installs work | dep install + phx.new ×4 | 4 parallel jobs; not in ci-gate.needs; signal-only. |
| CI | push, pull_request, workflow_dispatch | Example unit smoke (`example_unit_smoke`) | ubuntu-latest | — | postgres:14 | `mix test` (ExUnit + ConnTest in example/) | 49s (n=1, point est.) | n=1, point est. | low | example deps: likely cached | no (signal-only) | Smoke test for example app ConnTest correctness | `mix test` in example/ | Fast; signal-only lane. |
| CI | push, pull_request, workflow_dispatch | Milestone VERIFICATION.md gate (`milestone_verification_gate`) | ubuntu-latest | — | — | shell: check VERIFICATION.md sentinel | 7s (n=1, point est.) | n=1, point est. | low | none | no (signal-only) | Enforces milestone verification doc exists and is signed off | trivial shell | Signal-only. |
| CI | push, pull_request, workflow_dispatch | Installer milestone audit (`installer_milestone_audit`) | ubuntu-latest | — | — | INT-01..03 checks | 10s (n=1, point est.) | n=1, point est. | low | none | no (signal-only) | Installer integrity checks (INT-01..03) | trivial shell | Signal-only. |
| CI | push, pull_request, workflow_dispatch | Getting started doc contract (`getting_started_uat_contract`) | ubuntu-latest | — | — | shell: check doc contracts (SEED-8 shift-left) | 7s (n=1, point est.) | n=1, point est. | low | none | no (signal-only) | Enforces getting-started guide fidelity | trivial shell | Signal-only. |
| CI | push, pull_request, workflow_dispatch | Phase 34 UAT contracts (`phase_34_uat_contract`) | ubuntu-latest | — | — | 28-VERIFICATION + smoke bash | 6s (n=1, point est.) | n=1, point est. | low | none | no (signal-only) | Phase 34 UAT contract enforcement | trivial shell | Signal-only. |
| CI | push, pull_request, workflow_dispatch | Release ref guard (`release_ref_guard`) | ubuntu-latest | — | — | check ref is `v*` on `workflow_dispatch` | 2s (n=1, point est.) | n=1, point est. | low | none | no (not in ci-gate.needs) | Prevents manual release-evidence runs on non-tag refs | trivial shell | All required lanes depend on this as their first `needs:` entry. 2s guard. |
| CI | push, pull_request, workflow_dispatch | ci-gate (`ci-gate`) | ubuntu-latest | — | — | checks all 10 required lane results via `needs.*.result` | 3s (n=1, point est.) | n=1, point est. | low | none | (the gate itself) | The sole merge gate — fails if any of 10 required lanes is non-success | trivial shell | `if: always()`. NOT branch protection — main is unprotected (verified: `gh api` returns 404). |

**Run-level wall-clock data (n=9 successful runs):**

| Run ID | Trigger | Date | Wall-Clock |
|--------|---------|------|-----------|
| 27847562459 | push | 2026-06-19 | 2304s (38.4m) |
| 27846034918 | pull_request | 2026-06-19 | 2301s (38.4m) |
| 27837497615 | push | 2026-06-19 | 2260s (37.7m) |
| 27835747516 | pull_request | 2026-06-19 | 2311s (38.5m) |
| 27835546762 | push | 2026-06-19 | 2424s (40.4m) |
| 27833715452 | pull_request | 2026-06-19 | 2310s (38.5m) |
| 27476589835 | push | 2026-06-13 | 1531s (25.5m) |
| 27475945765 | pull_request | 2026-06-13 | 1562s (26.0m) |
| 27472179258 | push | 2026-06-13 | 1539s (25.7m) |

**Wall-clock p95 note:** The 2026-06-13 runs were on an older codebase — `example_playwright_smoke` ran only ~578s on that cohort (the spec suite was smaller). The 2026-06-19 cohort (n=6) is the representative baseline for the current codebase: average ~38.4m, p95 ~40m (n=6, point estimate — within the SEED-005 "~17-30m" lower estimate and extending toward 40m with the admin Playwright smoke now included in the suite).

---

## Critical Path (BASE-01)

### Jobs that gate merge (ci-gate.needs — 10 required lanes)

```
install_golden_contract, library_tests, library_tests_dep_off,
install_smoke, upgrade_smoke, example_http_smoke, example_playwright_smoke,
generated_admin_playwright_smoke, snapshot_drift_guard, quality_ledger_monotonic
```

### Parallel execution structure (run 27846034918)

All 10 required lanes (plus non-required lanes) start after `release_ref_guard` (2s).  
**EXCEPTION: `example_playwright_smoke` starts after `library_tests` finishes** (CRIT-01).

Timeline for run 27846034918:
- **t=0** — CI triggered
- **t+6s** — `release_ref_guard` completes → all other required lanes start (nearly simultaneously)
- **t+31s** — `library_tests` starts (2026-06-19T20:03:31Z)
- **t+34m** — `library_tests` completes (2026-06-19T20:19:24Z, duration: 953s/15.9m)
- **t+34m+2s** — `example_playwright_smoke` starts (2026-06-19T20:19:26Z — 2 seconds after library_tests ends)
- **t+38m21s** — `example_playwright_smoke` completes (2026-06-19T20:41:39Z, duration: 1333s/22.2m) → run ends

### Which job determines wall-clock

`example_playwright_smoke` (22.2m) determines wall-clock **because** it is serialized behind `library_tests` (15.9m).  
Total serialized time: 15.9m + 22.2m = 38.1m = actual wall-clock.

Without the serialization (CRIT-01 fix): `example_playwright_smoke` would start at ~t+6s (same as all other `needs: release_ref_guard` lanes) and complete at ~t+22.2m. New wall-clock would be gated by `example_playwright_smoke`'s own duration (~22m), not the sum.

**Expected post-CRIT-01 wall-clock: ~22m** (down from ~38m — approximately -16m for a one-line change).

### What work is duplicated across jobs

- **Full dep install + compile** is run in every job with `needs: release_ref_guard` (each starts its own env); cache hits mean deps/build dirs are restored quickly, but the compile step still runs per-job.
- **`mix ecto.setup`** runs in every job that uses Postgres (each job has its own PG service container, so no shared DB contention).
- **`mix test` (full suite)**: `library_tests` and `library_tests_dep_off` both run the complete 274-file suite. `library_tests_dep_off` only changes one dep; the full re-run is the bottleneck (TEST-02 in phase 195 targets this).

### Steps that dominate each long-pole job

**`example_playwright_smoke` (~22m):**
1. App compile + `mix ecto.setup` + seeding (~2-3m)
2. `npm ci` (node_modules, even with cache hit the install still takes time)
3. Playwright test execution (multiple spec files in sequence — fail-fast inside one shared app boot)

**`library_tests` (~16m):**
1. `mix test` (full suite, 2401 tests, 274 files) — dominates
2. `mix docs --warnings-as-errors` — ~1-2m additional at the end

**`library_tests_dep_off` (~14m):**
1. `mix test` (full suite re-run with `:threadline` absent) — dominates; only proves guards work

---

## Elixir Diagnostics (Optimization Target — BASE-02)

**Captured locally:** 2026-06-19, Postgres up via `scripts/db/up.sh` + `source tmp/db.env`

### Scheduler configuration

```
# Local (Mac, 18-core M-series):
schedulers: {18, 18}   # {schedulers_online, schedulers}
# elixir -e 'IO.inspect({System.schedulers_online(), System.schedulers()}, label: :schedulers)'

# CI (ubuntu-latest = 2 vCPU):
schedulers: {2, 2}     # GitHub-hosted standard Linux runner: 2 vCPU / 7 GB RAM
```

**ExUnit implication (the partitioning motivation):**  
`max_cases` default = `2 * System.schedulers_online()` = `2 * 2` = **4 concurrent test cases** on CI.  
With 186 `async: true` test modules and only 4 concurrent slots, throughput is severely limited.  
This is the quantified motivation for `mix test --partitions N` (TEST-01, phase 195): more partitions = more parallelism across separate runner instances, each with their own 2-core limit.

### Top 20 slowest tests (`mix test --slowest 20`)

Run locally 2026-06-19 (local Mac 18-core; times will differ from CI 2-core due to parallelism; ordering is representative):

| Rank | Test | Module | Duration (local) | Notes |
|------|------|--------|-----------------|-------|
| 1 | `upgrade after --no-organizations install … mix sigra.upgrade --yes on a --no-organizations install emits zero ALTERs` | `Sigra.UpgradeIntegrationTest` | 33028ms | Spawns subprocess: phx.new + sigra.install + boot + upgrade + curl |
| 2 | `mix sigra.upgrade --backfill-personal-orgs (ORG-UPGRADE-01) every user gets a personal org; re-run is a no-op` | `Sigra.UpgradeIntegrationTest` | 31947ms | Subprocess install + upgrade + seeding + queries |
| 3 | `upgrade after default install (org-enabled path — ORG-UPGRADE-02) login after backfill-off upgrade redirects` | `Sigra.UpgradeIntegrationTest` | 31772ms | Subprocess install + upgrade + HTTP smoke |
| 4 | `mix sigra.install opt out passkeys disabled with organizations disabled omits passkey routes` | `Sigra.Install.GeneratorPasskeysOptOutTest` | 27115ms | Spawns subprocess: full phx.new + sigra.install (--no-passkeys --no-organizations) |
| 5 | `mix sigra.install --passkeys app.js wiring rerunning install keeps a single passkey marker block` | `Sigra.Install.Features.PasskeysJsTest` | 25476ms | Subprocess install with passkeys |
| 6 | `mix sigra.install opt out passkeys disabled omits passkey routes` | `Sigra.Install.GeneratorPasskeysOptOutTest` | 25333ms | Subprocess install (--no-passkeys) |
| 7 | `mix sigra.install --passkeys emits the real vault and encrypted binary templates` | `Sigra.Install.VaultPromotionTest` | 25046ms | Subprocess install with passkeys + vault |
| 8 | `mix sigra.install --passkeys app.js wiring injects a marker-wrapped merged hooks block` | `Sigra.Install.Features.PasskeysJsTest` | 24523ms | Subprocess install |
| 9 | `golden diff generated tree matches committed fixture byte-for-byte` | `Sigra.Install.GoldenDiffTest` | 23895ms | Subprocess phx.new + full sigra.install |
| 10 | `mix sigra.install --passkeys app.js wiring leaves non-standard app.js untouched` | `Sigra.Install.Features.PasskeysJsTest` | 23853ms | Subprocess install |
| 11 | `golden diff captured stdout matches committed STDOUT.txt after normalization` | `Sigra.Install.GoldenDiffTest` | 23508ms | Subprocess phx.new + sigra.install |
| 12 | `second invocation produces zero new file writes and zero new injections` | `Sigra.Install.IdempotencyTest` | 1474ms | Subprocess idempotency check |
| 13 | `generate_invite_envelope/2 + verify_invite_envelope/3 returns :expired when max_age exceeded` | `Sigra.TokenTest` | 1100ms | Time-based expiry: intentional `Process.sleep(1_100)` |
| 14 | `reserved :impersonating_from field (D-11) compile-and-introspect` | `Sigra.Install.ScopeTemplateInvariantsTest` | 509ms | Subprocess: compiles generated Scope module |
| 15 | `authenticate/3 with bcrypt hash upgrades to argon2id` | `Sigra.AuthTest` | 359ms | bcrypt hash computation (intentionally slow) |
| 16 | `authenticate/3 emits hash_upgraded telemetry event on hash upgrade` | `Sigra.AuthTest` | 352ms | bcrypt hash computation |
| 17 | `verify_with_upgrade/2 with bcrypt returns {:error, :invalid} for wrong password` | `Sigra.CryptoTest` | 350ms | bcrypt hash computation |
| 18 | `verify_with_upgrade/2 with bcrypt returns {:ok, :valid, new_hash} for correct password` | `Sigra.CryptoTest` | 349ms | bcrypt hash computation |
| 19 | `D-11 System↔explicit-toggle dark-block parity auth ember-family values` | `Sigra.Install.Features.AdminTest` | 212ms | CSS parsing + comparison |
| 20 | `rollback on second audit emits zero telemetry events` | `Sigra.AuditMultiStepTest` | 208ms | DB transaction test |

**Total time in top 20:** ~300s out of ~330s (91% of total wall-clock in top 20).

**Key insight from top 20:**  
- **Ranks 1-11** are **subprocess-spawning install tests** that each spawn a full `phx.new` + `mix sigra.install` process (23-33 seconds each). These dominate. They are genuinely integration-expensive but high-value; they are the correct implementation. Optimization target: can some of these be parallelized via `async: true` + isolated temp dirs? Most install tests already use temp dirs, but `async: true` on subprocess-spawning tests risks platform temp-dir contention.
- **Ranks 13-14** are intentional (time-based expiry sleep + subprocess compile) — not flaky.
- **Ranks 15-18** are intentional (bcrypt is slow by design for security) — not optimizable.
- **Rank 1 module (`Sigra.UpgradeIntegrationTest`):** 3 tests, ~95s combined, non-async. Primary target for subprocess isolation improvement.

### Total suite stats (local run)

- **33 doctests, 3 properties, 2401 tests** (+ some known failures / skipped)
- **Total time (local):** 309-330 seconds (5.5m)  
- **CI time:** ~953s (15.9m) — the delta is largely: (a) 2 vCPU vs 18-core means fewer concurrent async cases; (b) cold-ish compile; (c) `mix docs` appended
- **Async breakdown (from SEED-005):** 186 `async: true` modules, 27 non-async; with `max_cases = 4` on CI, 186 async modules are heavily serialized

### Slow compile modules (`MIX_ENV=test mix compile --force --profile time`)

Top slowest modules (sorted by compile time, force-recompile pass, local Mac):

| Rank | Module (file) | Compile Time | Wait Time | Total | Notes |
|------|--------------|-------------|----------|-------|-------|
| 1 | `lib/sigra/admin/users/query.ex` | 481ms | 0ms | 481ms | Complex Ecto query module |
| 2 | `lib/sigra/admin/live/audit_user_live.ex` | 415ms | 329ms | 744ms | Waits for `Sigra.Admin.Components` |
| 3 | `lib/sigra/admin/live/user_show_live.ex` | 400ms | 336ms | 736ms | Waits for `Sigra.Admin.Components` |
| 4 | `lib/sigra/admin/live/users_index_live.ex` | 376ms | 340ms | 716ms | Waits for `Sigra.Admin.Components` |
| 5 | `lib/sigra/auth.ex` | 370ms | 53ms | 423ms | Waits for `Sigra.Config` struct |
| 6 | `lib/sigra/admin/components.ex` | 369ms | 0ms | 369ms | The `Sigra.Admin.Components` bottleneck — all admin LiveViews wait for it |
| 7 | `lib/sigra/error.ex` | 357ms | 0ms | 357ms | Error type definitions |
| 8 | `lib/sigra/admin/live/branding_live.ex` | 307ms | 347ms | 654ms | Waits for `Sigra.Admin.Components` |
| 9 | `lib/sigra/mfa.ex` | 298ms | 0ms | 298ms | MFA logic |
| 10 | `lib/sigra/organizations.ex` | 288ms | 0ms | 288ms | Organizations context |
| 11 | `lib/sigra/organizations/invitations.ex` | 254ms | 0ms | 254ms | Invitations context |
| 12 | `lib/sigra/integrations/chimeway.ex` | 225ms | 0ms | 225ms | OAuth integration |
| 13 | `lib/sigra/admin/live/audit_index_live.ex` | 258ms | 330ms | 588ms | Waits for `Sigra.Admin.Components` |
| 14 | `lib/sigra/passkeys.ex` | 157ms | 0ms | 157ms | WebAuthn/passkeys logic |
| 15 | `lib/sigra/api_token.ex` | 152ms | 0ms | 152ms | API token management |

**Key compile bottleneck:** `Sigra.Admin.Components` is a **compile-connected bottleneck** — 5 LiveView modules wait 329-347ms for it before they can start compiling. Its own compile time is 369ms. The effective serialized compile of `admin/components.ex → admin/live/*.ex` chain is the dominant compile-time bottleneck on a cold rebuild.

### Compile-connected chains (`mix xref graph --label compile-connected`)

```
lib/sigra/config.ex
├── lib/sigra/hashers/argon2.ex (compile)
└── lib/sigra/session_stores/ecto.ex (compile)
```

Only `Sigra.Config` has direct compile-connected dependents (2 modules). The Admin.Components → LiveView serialization above is a **structural** dependency (not a compile-connected edge per xref), but it still forces sequential compilation because components must be fully compiled before the macros in LiveViews can expand.

---

## Summary: Named Optimization Targets

| Optimization | Phase | Current Cost | Expected Improvement |
|-------------|-------|-------------|---------------------|
| **CRIT-01: Drop `example_playwright_smoke needs: library_tests`** | 193-03 | +15.9m serialization delay (2s gap proves it) | ~-16m wall-clock (38m → ~22m); one-line YAML change |
| **TEST-01: Partition `library_tests`** | 195 | 15.9m single-runner | Target: < 8m with 2-shard; limited by 2-core runners per shard |
| **TEST-02: Slim `library_tests_dep_off`** | 195 | 13.9m full re-run | Target: < 3m targeted subset |
| **BASE-03: Add `$GITHUB_STEP_SUMMARY` observability** | 193-02 | No visibility into versions/cache/timing on run summaries | Ongoing visibility; no runtime perf change |
| **FLAKE-01: Fix demo-showcase color flake** | 193-02 | 1-2 retries consumed; intermittent CI reds | Deterministic; `retries: 1` no longer masking real failures |

---

## Commit-safe verification

The data in this document was gathered read-only:
- All CI timing from `gh run view --json jobs` (authenticated `gh` 2.94.0 as szTheory)
- Local Elixir diagnostics from `mix test --slowest 20` and `MIX_ENV=test mix compile --force --profile time` with test Postgres up via `scripts/db/up.sh`
- No `ci.yml`, spec, runtime code, or migration files were modified to produce this artifact
- No secrets, passwords, or PG credentials appear in this document
