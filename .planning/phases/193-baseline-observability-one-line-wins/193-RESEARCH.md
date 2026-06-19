# Phase 193: Baseline, Observability & One-Line Wins - Research

**Researched:** 2026-06-19
**Domain:** GitHub Actions CI topology / Elixir-Mix diagnostics / Playwright flake hygiene
**Confidence:** HIGH (every claim grounded in the live `ci.yml`, real `gh run` data, and the in-repo spec/todo)

## Summary

Phase 193 is the **measure-before-optimize** opening slice of the SEED-005 CI-PERF audit. It must produce a committed before-state baseline (BASE-01), capture Elixir-side diagnostics as the optimization target (BASE-02), add `$GITHUB_STEP_SUMMARY` observability so future regressions stay visible (BASE-03), and bank two cheap, low-risk wins: dropping the gratuitous `example_playwright_smoke needs: library_tests` serialization edge (CRIT-01) and de-flaking the demo-showcase remember-checkbox color assertion (FLAKE-01). It must NOT do the big optimizations (partitioning, dep-off slimming, PR/nightly split, runner sizing) — those are phases 194-198.

The single highest-leverage finding is fully verified from live run data: run `27846034918` (the run REQUIREMENTS.md cites) had a **38m21s** wall-clock, and `example_playwright_smoke` (22.2m) started **2 seconds after** `library_tests` (15.9m) ended — pure serialization. `example_playwright_smoke` boots its own Phoenix app + its own Postgres service and consumes **zero** artifacts/outputs from `library_tests`; the only references to `needs.library_tests` in the whole file are inside the `ci-gate` aggregator. Dropping the `library_tests` edge (keeping `release_ref_guard`) lets the two long poles run concurrently and should cut wall-clock from ~38m toward ~22m for a one-line YAML change. [VERIFIED: gh run 27846034918 job timings]

A second verified ground-truth: `main` is **not** a protected branch (GitHub branch-protection API returns `Branch not protected`, HTTP 404). The merge gate is enforced entirely by the in-workflow `ci-gate` job that `needs:` 10 named lanes and fails if any is non-success. So "required-check stability" (CRIT-03, a later phase) means the `ci-gate` job name + its `needs:` list, not a branch-protection config. For Phase 193 this means CRIT-01's edge-drop is safe: `example_playwright_smoke` stays in `ci-gate.needs`, so it's still a required lane; only its *start time* changes.

**Primary recommendation:** Write the baseline as a committed planning markdown (`.planning/phases/193-baseline-observability-one-line-wins/193-BASELINE.md` or similar) populated from `gh run view <id> --json jobs`; add `$GITHUB_STEP_SUMMARY` blocks + `id:` on cache steps for hit/miss; change `needs: [release_ref_guard, library_tests]` → `needs: [release_ref_guard]` on `example_playwright_smoke` only; and fix FLAKE-01 by replacing the exact `toBe` color equality at demo-showcase.spec.ts:885 with a ±2 per-channel tolerance using the file's existing `rgbChannels` parser (preferred) — no blanket retries.

## User Constraints

No CONTEXT.md exists for this phase (user went straight to plan-phase). The binding constraints come from REQUIREMENTS.md, SEED-005 scope guardrails, and CLAUDE.md.

### Locked Decisions (from REQUIREMENTS.md + SEED-005 guardrails)
- **Measure before optimize.** Phase 193 captures the baseline; it does NOT do partitioning, dep-off slimming, PR/nightly split, runner upsizing, micro-job consolidation (those are 194-198).
- **Never trade trust for speed.** Any faster-but-less-trustworthy change is a labeled tradeoff moved to nightly — not applicable to the 193 wins, which are pure parallelization + a determinism fix.
- **No flake masking via blanket retries.** FLAKE-01 must be de-flaked or deleted, NOT papered over with `retries`. `retries: 1` already exists in CI and D-15 forbids using it to mask real failures.
- **Required-check names stable.** Do not rename `ci-gate` or any lane in its `needs:` list; do not introduce path/skip pending-check traps. (CRIT-03 is phase 196, but 193 must not violate it.)
- **Respect SEED-004 phx_new 1.8.7 pin.** Do not touch the `mix archive.install --force hex phx_new 1.8.7` steps.
- **Preserve snapshot/baseline determinism.** Do not change the snapshot-canary / drift-guard contracts.

### Claude's Discretion
- Exact filename/location of the committed baseline artifact (recommend `.planning/phases/193-.../193-BASELINE.md`).
- Exact columns beyond the SEED-005-mandated set (workflow, trigger, job, runner, matrix, services, command, avg duration, p95, failure/rerun rate, cache usage, required-for-merge, quality signal, likely bottleneck, notes).
- Whether BASE-02 diagnostics are captured locally into the artifact, emitted in a CI step, or both (recommend: capture locally into the artifact now + add a CI `--slowest` summary step for ongoing visibility).
- FLAKE-01: de-flake (tolerance) vs delete the sub-assertion. Recommend de-flake with ±2 tolerance — the assertion still has value (proves the checked accent renders) and the file already has the parser.

### Deferred Ideas (OUT OF SCOPE for 193)
- Partitioning `library_tests` (TEST-01 → 195), slimming `library_tests_dep_off` (TEST-02 → 195), async audit (TEST-03 → 195).
- Cache key correction + micro-job consolidation (CACHE-01/02 → 194).
- Larger runners (CACHE-03 → 195).
- PR-fast vs nightly split + required-check redesign (CRIT-02/03 → 196).
- Playwright sharding / readiness / SEED-006 gallery re-gate (PW-01/02/03 → 197).
- `mix ci` local equivalent + acceptance gate (DX-01/GATE-01/02 → 198).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BASE-01 | Committed before-state baseline table (per-job duration, p95, critical path, cache hit/miss, required-vs-not, quality signal, likely bottleneck) | `gh run view <id> --json jobs --jq ...` yields exact per-job start/complete/duration (verified below). Required-vs-not derivable from `ci-gate.needs` (10 lanes). Critical path proven by serialization timing. p95 needs ≥5-10 recent runs via `gh run list`. |
| BASE-02 | Elixir-side diagnostics: `mix test --slowest`, `System.schedulers_online()`, slow compile modules | Exact invocations documented below; runner is `ubuntu-latest` = 2 vCPU → `schedulers_online` = 2 (the SEED-005 thesis #5 motivation). `mix test --slowest N`, `mix compile --profile time` documented. |
| BASE-03 | CI job summaries surface resolved versions, cache hit/miss, test-timing | No `$GITHUB_STEP_SUMMARY` exists anywhere today (greenfield); no `id:` on any `actions/cache` step today, so cache-hit not yet captured. Idiomatic pattern documented below — add `id:` + summary echo steps without renaming jobs. |
| CRIT-01 | Drop `example_playwright_smoke needs: [library_tests]` (keep `release_ref_guard`) | `ci.yml:697` is the exact edge. Verified gratuitous (no artifact/output consumption). Verified safe (lane stays in `ci-gate.needs`). |
| FLAKE-01 | Fix flaky demo-showcase remember-checkbox accent-color (off-by-one rgb) — de-flake or delete, no blanket retries | Exact assertion: `demo-showcase.spec.ts:885-887` in test block `"home page orients evaluators before login"` (line 403). File already has `rgbChannels()` parser (line 52) for a tolerance fix. Todo: `.planning/todos/pending/2026-06-19-demo-showcase-remember-checkbox-color-flaky.md`. |

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Baseline measurement (BASE-01/02) | Planning artifact (committed markdown) | Local shell + `gh` CLI | Read-only data gathering; lives in `.planning/`, not runtime code. |
| CI run observability (BASE-03) | GitHub Actions workflow (`ci.yml` steps) | — | `$GITHUB_STEP_SUMMARY` is a runner-provided file; pure workflow-YAML concern. |
| Job-graph topology (CRIT-01) | GitHub Actions workflow (`needs:` edges) | — | DAG scheduling lives in `ci.yml`; the fix is one `needs:` line. |
| Browser-test determinism (FLAKE-01) | Playwright spec (`test/example/priv/playwright/`) | — | Test-layer assertion; no library/runtime code changes. |

**Sanity check:** None of Phase 193's work touches `lib/` (security-critical library code) or `priv/templates/` (the generator). It is entirely planning-doc + workflow-YAML + one Playwright spec. That correctly scopes it as a CI/DX maintenance phase with zero library-behavior risk.

## CI Job Graph (BASE-01 / CRIT-01)

**Source:** `.github/workflows/ci.yml` (1231 lines, single workflow `CI`). Triggers: `workflow_dispatch`, `push: [main]`, `pull_request: [main]`. Top-level `permissions: contents: read`. All jobs `runs-on: ubuntu-latest`. [VERIFIED: ci.yml:1-23]

### Full job enumeration (23 jobs)

| Job (id) | `name:` | `needs:` | In `ci-gate`? (required) | Postgres svc | Cache step(s) | Duration (run 27846034918) |
|----------|---------|----------|--------------------------|--------------|---------------|----------------------------|
| `release_ref_guard` | Release ref guard | — | no | no | none | 2s |
| `milestone_verification_gate` | Milestone VERIFICATION.md gate | — | no | no | none | 7s |
| `installer_milestone_audit` | Installer milestone audit (INT-01..03) | — | no | no | none | 10s |
| `install_golden_contract` | Install golden + idempotency contract | `release_ref_guard` | **yes** | yes | library deps | 28s |
| `library_tests` | **Library tests** | `release_ref_guard` | **yes** | yes | library deps | **953s (15.9m)** ← long pole |
| `library_tests_dep_off` | Library tests (dep-off — Threadline absent) | `release_ref_guard` | **yes** | yes | library deps (dep-off key) | **835s (13.9m)** ← long pole |
| `example_unit_smoke` | Example unit smoke (ExUnit + ConnTest) | — | no | yes | example deps | 51s |
| `install_smoke` | Install smoke (fresh phx.new + sigra.install) | `release_ref_guard` | **yes** | yes | library deps + hex registry | 109s |
| `upgrade_smoke` | Upgrade smoke (published source → local) | `release_ref_guard` | **yes** | yes | library deps + hex registry | 97s |
| `passkeys_manual_fallback_smoke` | Passkeys manual fallback smoke | — | no | yes | library deps + hex registry | 114s |
| `install_matrix` (×4) | Install matrix (flag combinations) | — | no | yes | library deps | ~105-109s each |
| `passkeys_opt_out_smoke` | Passkeys opt-out smoke | — | no | yes | library deps + hex registry | 185s |
| `example_http_smoke` | Example HTTP smoke (boot + curl) | `release_ref_guard` | **yes** | yes | example deps (dev key) | 49s |
| `example_playwright_smoke` | **Example Playwright smoke (full lifecycle)** | **`[release_ref_guard, library_tests]`** | **yes** | yes | node npm + example deps (dev) | **1333s (22.2m)** ← longest |
| `generated_admin_playwright_smoke` | Generated admin Playwright smoke | `release_ref_guard` | **yes** | yes | node npm | 187s (timeout-minutes: 60) |
| `getting_started_uat_contract` | Getting started doc contract | — | no | no | none | 7s |
| `phase_34_uat_contract` | Phase 34 UAT contracts | — | no | no | none | 6s |
| `snapshot_drift_guard` | Snapshot drift guard (canary allowlist) | — | **yes** | no | none | 6s |
| `quality_ledger_monotonic` | Quality ledger monotonic guard | — | **yes** | no | none | 7s |
| `ci-gate` | ci-gate | (10 lanes below) | (the gate itself) | no | none | 3s |

[VERIFIED: ci.yml job blocks + gh run 27846034918 timings]

### The required gate (`ci-gate`)

`ci-gate` (ci.yml:1177-1231) `needs:` exactly these 10 lanes and `if: always()`, then fails unless every one is `success`: [VERIFIED: ci.yml:1180-1190]

```
install_golden_contract, library_tests, library_tests_dep_off, install_smoke,
upgrade_smoke, example_http_smoke, example_playwright_smoke,
generated_admin_playwright_smoke, snapshot_drift_guard, quality_ledger_monotonic
```

Jobs NOT in `ci-gate.needs` (non-required, run for signal but don't block the gate): `milestone_verification_gate`, `installer_milestone_audit`, `example_unit_smoke`, `passkeys_manual_fallback_smoke`, `install_matrix` (×4), `passkeys_opt_out_smoke`, `getting_started_uat_contract`, `phase_34_uat_contract`. [VERIFIED: ci.yml diff of all job ids vs ci-gate.needs]

**`main` is NOT a protected branch** — `gh api repos/szTheory/sigra/branches/main/protection/required_status_checks` returns `Branch not protected` (HTTP 404). The merge gate is the in-workflow `ci-gate` job alone. CRIT-03's "required-check name stability" therefore = stability of the `ci-gate` job `name:` and its `needs:` list, NOT a branch-protection setting. [VERIFIED: gh api branch protection]

### CRIT-01: the serialization, proven

`example_playwright_smoke` is the ONLY required long-pole job whose `needs:` includes `library_tests`:

```yaml
# ci.yml:694-697
example_playwright_smoke:
  name: Example Playwright smoke (full lifecycle)
  runs-on: ubuntu-latest
  needs: [release_ref_guard, library_tests]   # ← CRIT-01 target
```

Timing proof from run `27846034918` (the run REQUIREMENTS.md cites): [VERIFIED: gh run 27846034918]

- Total wall-clock (created → updated): **20:03:25 → 20:41:46 = 38m21s**
- `library_tests` ran **20:03:31 → 20:19:24** (15m53s)
- `example_playwright_smoke` ran **20:19:26 → 20:41:39** (22m13s) — it started **2 seconds after** `library_tests` finished.
- Without the edge, `example_playwright_smoke` would start right after `release_ref_guard` (~20:03:33, like every other `needs: release_ref_guard` lane) and finish ~16m earlier — wall-clock would drop toward the next-longest pole (`library_tests` 15.9m or `library_tests_dep_off` 13.9m, both of which already run concurrently). Expected new wall-clock ≈ **~22m** (gated by `example_playwright_smoke`'s own 22.2m, now started near t=0).

**Is dropping the edge safe?** Yes, fully verified:
1. **No data dependency.** `example_playwright_smoke` boots its OWN Phoenix app and its OWN Postgres service container (ci.yml:698-768); it `npm ci` + compiles example + seeds + runs playwright. It downloads NO artifact from `library_tests` and reads NO `library_tests.outputs.*`. The ONLY `needs.library_tests` references in the entire file are at ci.yml:1196 (the `ci-gate` aggregator reading `.result`). [VERIFIED: grep needs.library_tests / download-artifact / outputs]
2. **What each `needs` entry gates:** `release_ref_guard` gates the "manual release-evidence runs must use a `v*` tag ref" guard (ci.yml:24-42); it's a 2s correctness guard that every required lane depends on. **Keep it.** `library_tests` gates nothing real for this lane — it's the gratuitous serialization edge. **Drop it.**
3. **Lane stays required.** `example_playwright_smoke` remains in `ci-gate.needs` (ci.yml:1187), so dropping its `library_tests` edge does not remove it from the gate. The required-check surface is unchanged.

**The fix (one line):** `needs: [release_ref_guard, library_tests]` → `needs: [release_ref_guard]` on `example_playwright_smoke` only. [CITED: ci.yml:697]

**Long-pole jobs by name** (the critical path): `example_playwright_smoke` (22.2m), `library_tests` (15.9m), `library_tests_dep_off` (13.9m). Everything else is <3.2m. [VERIFIED: gh run 27846034918]

## Baseline Artifact (BASE-01)

### Where it lives
Recommend a committed markdown at `.planning/phases/193-baseline-observability-one-line-wins/193-BASELINE.md` (a tracked planning artifact, per BASE-01 "Committed as a planning artifact"). The phase dir already exists. This is the reference every later phase (194-198) diffs against. [ASSUMED: exact filename is Claude's discretion]

### Required columns (SEED-005 §3 verbatim audit playbook, ci.yml:296-313 of the seed)
The playbook mandates this table shape — produce it per job:

`workflow name | trigger | job name | runner | matrix dimensions | services/containers | command(s) | average duration | p95 duration | failure/rerun rate | cache usage | required-for-merge | quality signal | likely bottleneck | notes`

Plus the seed's "compute the critical path" prose: which jobs gate merge, which run in parallel, which determines wall-clock, which steps dominate each job, what work is duplicated across jobs. [CITED: SEED-005 lines 296-328]

### How to obtain the data (all verified available)

`gh` CLI v2.94.0 is installed and authenticated as `szTheory` with repo access. [VERIFIED: gh auth status]

**Per-job duration (exact):**
```bash
gh run view <RUN_ID> --json jobs \
  --jq '.jobs[] | "\(.name)\t\(((.completedAt|fromdateiso8601)-(.startedAt|fromdateiso8601)))s"' \
  | sort -t$'\t' -k2 -rn
```
This was used to produce the duration column above. [VERIFIED: executed against 27846034918]

**Run-level wall-clock:**
```bash
gh run view <RUN_ID> --json createdAt,updatedAt
```

**Recent runs for p95 (need a sample of ≥5-10 same-trigger runs):**
```bash
gh run list --workflow CI --limit 20 \
  --json databaseId,event,conclusion,createdAt,updatedAt
```
Filter to `event == "pull_request"` (or `push`) for like-for-like, compute per-job p95 across the sample. NOTE: many recent runs are `chore:` pushes; pick a coherent set. SEED-005 cites runs `27783442056` / `27785703122`; REQUIREMENTS cites `27846034918`. With only a handful of green full runs, p95 may be reported as "n<5, point estimate only" — that is acceptable and honest for a baseline. [CITED: SEED-005 line 115; REQUIREMENTS line 5]

**Cache hit/miss for the baseline:** `actions/cache` logs print `Cache restored from key:` / `Cache not found`. There is **no machine-readable cache-hit in run JSON today** because no cache step has an `id:` (see BASE-03). For the baseline snapshot, read cache hit/miss from the step logs:
```bash
gh run view --job <JOB_ID> --log | grep -iE "cache (restored|not found|hit|miss)"
```
Going forward, BASE-03's `id:` + `$GITHUB_STEP_SUMMARY` makes this self-reporting.

**Required-vs-not:** derive from `ci-gate.needs` (the 10 lanes listed above). [VERIFIED: ci.yml:1180-1190]

## Elixir Diagnostics (BASE-02)

These target the `library_tests` (~16m, `mix test` whole suite) and `library_tests_dep_off` (~14m) long poles. The suite is **274 `*_test.exs` files** (SEED-005 says 274 test files, 186 `async: true` / 27 non-async). [VERIFIED: find test -name '*_test.exs' | wc -l = 274; CITED: SEED-005 line 24]

### Exact invocations

**Slowest tests** (the primary BASE-02 deliverable):
```bash
mix test --slowest 20
```
`--slowest N` prints timing of the N slowest tests AND the N slowest `describe`/test modules. Run with the live test Postgres (`scripts/db/up.sh` + `source tmp/db.env`, per CLAUDE.md). [CITED: hexdocs.pm/ex_unit `mix test` task — `--slowest`]

**Scheduler/core count on the runner** (motivates SEED-005 thesis #5 — 2-core under-serves 186 async modules):
```bash
elixir -e 'IO.inspect({System.schedulers_online(), System.schedulers()}, label: :schedulers)'
# In CI add as a step so it lands in the run log / step summary.
```
`ubuntu-latest` GitHub-hosted runners are **2 vCPU / 7 GB** (standard public-repo Linux runner), so `System.schedulers_online()` will be **2**. ExUnit's default `max_cases` is `2 * schedulers_online` = 4 concurrent test cases. This is the quantified motivation for partitioning (TEST-01, phase 195) — capture it now as the baseline number. [VERIFIED: ci.yml runs-on ubuntu-latest; CITED: GitHub Actions standard runner spec — 2-core/7GB Linux; CITED: hexdocs.pm/ex_unit ExUnit `max_cases` default]

**Slowest compile modules** (the other half of long-pole time is compilation):
```bash
MIX_ENV=test mix compile --force --profile time   # per-module compile timing
mix xref graph --label compile-connected           # compile-connected dependency chains
```
`mix compile --profile time` emits `Compiled <module> in Nms`-style timing; `xref graph --label compile-connected` surfaces the macro-heavy chains that force recompilation. [CITED: hexdocs.pm/mix `compile` `--profile time`; hexdocs.pm/mix `xref`]

### Where these run
Recommend **both**: (1) capture the numbers locally now and paste them into `193-BASELINE.md` as the recorded optimization target (BASE-02 says "record them as the optimization target"); (2) BASE-03 adds an ongoing `--slowest` summary step in CI so the target stays visible run-over-run. Local capture requires the test Postgres up (CLAUDE.md "Local development prerequisites": `scripts/db/up.sh` → `source tmp/db.env` → `mix test`). [CITED: CLAUDE.md Local development prerequisites]

## Job-Summary Observability (BASE-03)

**Current state:** `$GITHUB_STEP_SUMMARY` is used **nowhere** in the repo (grep across `.github/` and `scripts/` returns zero hits). No `actions/cache` step has an `id:`, so `cache-hit` is not captured anywhere today. BASE-03 is greenfield-in-CI. [VERIFIED: grep GITHUB_STEP_SUMMARY / id:.*cache → empty]

### The mechanism
GitHub Actions exposes a writable file path in `$GITHUB_STEP_SUMMARY`; markdown appended to it renders on the run's summary page. Idiomatic, low-risk, no new actions:
```bash
- name: CI run summary
  if: always()
  run: |
    {
      echo "## Library tests"
      echo "- Elixir: $(elixir --version | tail -1)"
      echo "- OTP: $(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().')"
      echo "- schedulers_online: $(elixir -e 'IO.write(System.schedulers_online())')"
      echo "- deps cache hit: ${{ steps.deps_cache.outputs.cache-hit }}"
    } >> "$GITHUB_STEP_SUMMARY"
```

### Cache hit/miss — add `id:` to existing cache steps
`actions/cache` exposes a `cache-hit` output ONLY when the step has an `id:`. Today none do. Add `id: deps_cache` (or similar) to the `Cache library deps` / `Cache example deps` steps, then reference `steps.deps_cache.outputs.cache-hit` in the summary. This is additive — it does NOT change the cache key, path, or the job name. [CITED: github.com/actions/cache README — `cache-hit` output requires step `id`]

### Resolved versions
`erlef/setup-beam` already resolves Elixir/OTP from `.tool-versions` (`erlang 28.5`, `elixir 1.19.5-otp-28`). Echo the resolved values (`elixir --version`, `erl -eval ... otp_release`) into the summary. setup-beam also sets outputs (`elixir-version`, `otp-version`) you can reference directly. [VERIFIED: .tool-versions; CITED: erlef/setup-beam outputs]

### Test-timing summary
Append `mix test --slowest 10` output (or parse it) into `$GITHUB_STEP_SUMMARY` in the `library_tests` job so slowest tests are visible on every run without opening logs.

### Low-risk constraints for BASE-03
- **Do NOT rename any job** — `ci-gate.needs` references job ids; the `name:` strings are the gate surface. Add steps, never rename. [VERIFIED: ci.yml ci-gate.needs]
- Use `if: always()` on summary steps so a test failure still emits the summary (the whole point is post-failure visibility).
- Adding `id:` to a cache step is inert w.r.t. caching behavior.
- Keep summary steps' `run:` shell `set -euo pipefail`-safe so a summary-write failure doesn't mask a real failure (or guard with `|| true` on the echo, never on the test itself).

## FLAKE-01: Demo-Showcase Remember-Checkbox Color

### Exact location
- **File:** `test/example/priv/playwright/tests/demo-showcase.spec.ts`
- **Test block:** `test("home page orients evaluators before login", ...)` — line **403**.
- **Flaky assertion:** lines **885-887**:
  ```js
  expect(rememberCheckedStyles.backgroundColor).toBe(
    rememberCheckedStyles.expectedAccent,
  );
  ```
  An **exact** rgb-string equality between the checked "Keep me signed in" checkbox's rendered `background-color` and the expected brand accent (resolved from `--vt-color-primary` at line 865-867). [VERIFIED: demo-showcase.spec.ts:403,843-887]
- **Runs in CI** via the `demo-showcase-chromium` project (playwright.config.ts:162), invoked in the `example_playwright_smoke` job's final playwright step (ci.yml:887-895). [VERIFIED: ci.yml:887; playwright.config.ts:162]
- **Todo:** `.planning/todos/pending/2026-06-19-demo-showcase-remember-checkbox-color-flaky.md` (status: pending) — must be closed/moved to `completed/` as part of FLAKE-01's success criterion. [VERIFIED: todo file read]

### The failure signature
CI intermittently fails by 1-2 units per channel and **passes on retry** (`retries: 1` in CI masks it):
```
Expected: "rgb(72, 214, 202)"   (#48D6CA)
Received: "rgb(71, 212, 200)"   (#47D4C8)
```
This is the classic sub-pixel / color-rounding / not-yet-settled `:checked` paint signature (color-mix / opacity / transition mid-frame), not a wrong brand color. [VERIFIED: todo body lines 24-27]

### Recommended fix: ±2 per-channel tolerance (de-flake, don't delete)
The assertion has value (proves the checked accent actually renders), and the file **already contains the exact tool needed**: `function rgbChannels(value: string): [number, number, number]` at line 52 parses any CSS color (incl. oklab) into numeric channels — it's already used by `relativeLuminance`/`contrastRatio` in the same file. Replace the exact `toBe` with a parsed per-channel comparison allowing ±2:

```js
// Replace lines 885-887:
const [br, bg, bb] = rgbChannels(rememberCheckedStyles.backgroundColor);
const [er, eg, eb] = rgbChannels(rememberCheckedStyles.expectedAccent);
expect(Math.abs(br - er)).toBeLessThanOrEqual(2);
expect(Math.abs(bg - eg)).toBeLessThanOrEqual(2);
expect(Math.abs(bb - eb)).toBeLessThanOrEqual(2);
```

Optionally combine with a settle-wait before the read (the test already uses `expect.poll(...).toBe("1")` on `::after` opacity at line 836-842 to wait for the checked paint — extend that pattern or disable CSS transitions for the assertion if rounding persists). The `afterBackgroundColor`/`expectedOnAccent` exact check at line 890-892 is the same family and may warrant the same tolerance treatment if it also flakes — but only change what's evidenced as flaky (the todo only cites the line-885 `backgroundColor` assertion). [VERIFIED: rgbChannels at demo-showcase.spec.ts:52; poll pattern at 836-842]

**Delete-instead option** (acceptable per the todo if de-flaking proves not worth it): drop just the line-885 color sub-assertion, keep the orientation coverage. The todo notes the micro-assertion is "arguably over-specified design trivia already covered by the design-system layers (sg-* tokens, admin-checkpoints, the gallery)." Recommend de-flake first since the tolerance fix is ~5 lines using existing helpers. [VERIFIED: todo fix-direction lines 43-54]

**Forbidden:** Do NOT add or rely on `retries` to make this pass. `retries: 1` already exists (playwright.config.ts:50) and D-15 / SEED-005 guardrail forbid masking real failures with it. The success criterion is "deterministic across repeated CI runs with NO reliance on `retries: 1`." [VERIFIED: playwright.config.ts:50; todo acceptance]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-job CI durations / p95 | A custom Actions-API scraper | `gh run view --json jobs --jq` + `gh run list` | Already installed, authenticated, returns exact `startedAt`/`completedAt`. |
| Color parsing for tolerance | A new rgb parser | The file's existing `rgbChannels()` (line 52) | Already handles rgb + oklab; already imported in-file. |
| Cache hit/miss reporting | A bespoke log-grep step | `actions/cache` `cache-hit` output (add `id:`) | First-party output; zero new dependencies. |
| Run summary rendering | An uploaded HTML artifact | `$GITHUB_STEP_SUMMARY` markdown | Native, renders inline on the run page, no artifact retention cost. |

**Key insight:** Every Phase 193 task has a first-party / in-repo tool already available. No new packages, no new actions. This is a measurement + one-line-fix phase by design.

## Common Pitfalls

### Pitfall 1: Renaming a job while adding observability
**What goes wrong:** Renaming `library_tests` → `library_tests (elixir 1.19/otp 28)` breaks `ci-gate.needs` (which references job *ids*, not names) or, if branch protection is ever added, breaks required-check names.
**How to avoid:** BASE-03 adds *steps* to existing jobs; never touch `name:` or job ids. CRIT-03 (renaming for clarity) is explicitly phase 196, out of 193's scope.
**Warning signs:** Any diff line touching a `name:` or a top-level job key in `ci.yml`.

### Pitfall 2: Treating p95 as if many runs exist
**What goes wrong:** The repo has only a handful of green full CI runs; computing "p95" over n=2 is meaningless.
**How to avoid:** Report point estimates honestly, label sample size (`n=3, point estimate`), use the longest recent run as the conservative baseline. SEED-005's own baseline is "~17-30m" range, not a tight p95.
**Warning signs:** A p95 column with no sample-size note.

### Pitfall 3: Dropping the wrong `needs` edge on example_playwright_smoke
**What goes wrong:** Removing `release_ref_guard` instead of `library_tests` disables the release-ref correctness guard for the Playwright lane.
**How to avoid:** Change `needs: [release_ref_guard, library_tests]` → `needs: [release_ref_guard]`. Keep `release_ref_guard`. Only `library_tests` is gratuitous.
**Warning signs:** A diff where `release_ref_guard` disappears from the `needs` array.

### Pitfall 4: "Fixing" the flake with a wider exact-match or a retry
**What goes wrong:** Bumping `retries` or comparing normalized-hex-with-no-tolerance still drifts by a rounding unit.
**How to avoid:** Parse to numeric channels, allow ±2 per channel (the documented delta is 1-2). No retry changes.
**Warning signs:** A diff touching `retries:` in playwright.config.ts, or a still-exact `toBe` on a color string.

### Pitfall 5: Doing phase 194-198 work here
**What goes wrong:** Scope creep into partitioning, cache-key rewrites, micro-job consolidation, or the SEED-006 gallery re-gate — all of which carry real risk and belong to later phases.
**How to avoid:** 193 ships exactly: 1 committed baseline artifact, observability steps, 1 `needs:` line change, 1 spec assertion fix + todo close. Nothing else.
**Warning signs:** Editing cache `key:` strings, adding `--partitions`, touching `library_tests_dep_off` test selection, or `continue-on-error` on the gallery.

## Code Examples

### CRIT-01: the one-line edge drop
```yaml
# .github/workflows/ci.yml — example_playwright_smoke (currently line 697)
# BEFORE:
  needs: [release_ref_guard, library_tests]
# AFTER:
  needs: [release_ref_guard]
```
[CITED: ci.yml:697]

### BASE-01: capture per-job durations
```bash
# Source: gh CLI v2.94.0 (verified installed/authed)
RUN_ID=27846034918
gh run view "$RUN_ID" --json jobs \
  --jq '.jobs[] | "\(.name)\t\((.completedAt|fromdateiso8601)-(.startedAt|fromdateiso8601))s"' \
  | sort -t$'\t' -k2 -rn
gh run view "$RUN_ID" --json createdAt,updatedAt   # wall-clock
```

### BASE-03: cache-hit + version summary
```yaml
- name: Cache library deps
  id: deps_cache                       # ← ADD: enables cache-hit output
  uses: actions/cache@27d5ce7f107fe9357f9df03efb73ab90386fccae  # v5.0.5 (unchanged pin)
  with:
    path: |
      deps
      _build
    key: ${{ runner.os }}-library-${{ hashFiles('mix.lock') }}
# ... later ...
- name: CI summary
  if: always()
  run: |
    {
      echo "## ${{ github.job }}"
      echo "- elixir: $(elixir --version | tail -1)"
      echo "- deps cache hit: ${{ steps.deps_cache.outputs.cache-hit }}"
    } >> "$GITHUB_STEP_SUMMARY"
```
[CITED: actions/cache README cache-hit output; ci.yml:167-173 current cache step]

### FLAKE-01: tolerance fix using the file's existing parser
```js
// demo-showcase.spec.ts — replace exact toBe at lines 885-887
const [br, bg, bb] = rgbChannels(rememberCheckedStyles.backgroundColor);
const [er, eg, eb] = rgbChannels(rememberCheckedStyles.expectedAccent);
expect(Math.abs(br - er)).toBeLessThanOrEqual(2);
expect(Math.abs(bg - eg)).toBeLessThanOrEqual(2);
expect(Math.abs(bb - eb)).toBeLessThanOrEqual(2);
```
[VERIFIED: rgbChannels demo-showcase.spec.ts:52]

## Runtime State Inventory

> Phase 193 is workflow-YAML + planning-doc + one Playwright spec. It is NOT a rename/refactor/migration of runtime code, but FLAKE-01's "close the todo" requires a file move, and the baseline is a new tracked artifact. Inventory below for completeness.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no DB/datastore keys touched. | none |
| Live service config | None — no external service config. The only "config" is `ci.yml` itself (in git). | edit `ci.yml` (CRIT-01, BASE-03) |
| OS-registered state | None. | none |
| Secrets/env vars | None changed. `CLOAK_KEY` and PG creds in CI are unchanged; no new secrets. | none |
| Build artifacts | None. The committed baseline `.md` is a NEW tracked artifact (additive). The FLAKE-01 todo at `.planning/todos/pending/2026-06-19-...md` must move to `.planning/todos/completed/` when FLAKE-01 lands (state hygiene, not a build artifact). | move todo file pending→completed |

**Verified by:** grep for `download-artifact`/`outputs`/cache keys; the only stateful side-effect is the committed baseline doc (new file) and the todo move.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Read CI timings from the Actions web UI by hand | `gh run view --json jobs --jq` for scriptable per-job timing | `gh` ≥ 2.x | Baseline data is reproducible/committable, not screenshotted. |
| Exact rgb-string `toBe` for rendered colors | Parse-to-channels + per-channel tolerance | Long-standing Playwright practice for `:checked`/transition paints | Eliminates sub-pixel/rounding flake without retries. |
| Cache hit visibility via reading raw logs | `actions/cache` `cache-hit` step output + `$GITHUB_STEP_SUMMARY` | actions/cache v2+ | Self-reporting run summaries; no log spelunking. |

**Deprecated/outdated:** Nothing in 193's scope is deprecated. The `erlef/setup-beam` pin (v1.24.0, SHA-pinned) and `phx_new 1.8.7` pin (SEED-004) are intentional and MUST be preserved.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Baseline artifact filename `193-BASELINE.md` under the phase dir | Baseline Artifact | Low — exact name is Claude's discretion; any committed `.planning/` markdown satisfies BASE-01. |
| A2 | Recommend BASE-02 captured both locally (into artifact) AND as a CI summary step | Elixir Diagnostics | Low — REQUIREMENTS says "record as optimization target"; local capture alone satisfies BASE-02, CI step is the BASE-03 overlap. |
| A3 | FLAKE-01 best fixed by de-flake (±2 tolerance) over delete | FLAKE-01 | Low — todo explicitly lists both as acceptable; tolerance is the lower-effort, higher-value option. |
| A4 | Expected post-CRIT-01 wall-clock ≈ ~22m (gated by example_playwright_smoke's own 22.2m started near t=0) | Summary / CRIT-01 | Low — arithmetic from verified timings; actual depends on runner queue variance. The *direction* (≈ -16m) is certain. |

All other claims are `[VERIFIED]` against live `ci.yml`, real `gh run` data, or in-repo files.

## Open Questions

1. **How many comparable green full-CI runs exist for a meaningful p95?**
   - What we know: `gh run list` shows many recent `chore:` push runs; REQUIREMENTS cites `27846034918`, SEED-005 cites `27783442056`/`27785703122`.
   - What's unclear: whether ≥5 green, same-trigger, full runs exist for a real p95 vs a point estimate.
   - Recommendation: gather what exists, label sample size, use the longest as the conservative baseline. Don't block BASE-01 on a perfect p95.

2. **Does the line-890 `afterBackgroundColor`/`expectedOnAccent` exact check also flake?**
   - What we know: it's the same exact-`toBe`-color family as the line-885 assertion the todo cites.
   - What's unclear: the todo only evidences the line-885 `backgroundColor` flake.
   - Recommendation: fix only the evidenced assertion (885-887); apply the same tolerance to 890-892 only if it independently flakes (don't over-edit).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI (authenticated) | BASE-01 run-data gathering | ✓ | 2.94.0, logged in as szTheory | GitHub Actions UI (manual) |
| Elixir/OTP | BASE-02 local diagnostics | ✓ (pinned) | elixir 1.19.5-otp-28 / erlang 28.5 | run diagnostics in a CI step instead |
| Test Postgres | `mix test --slowest` locally | ✓ via `scripts/db/up.sh` | postgres:15 | capture `--slowest` from a CI `library_tests` step |
| Node/Playwright | FLAKE-01 local repro | ✓ (in `test/example/priv/playwright`) | node 20 (CI), local varies | rely on CI demo-showcase-chromium run |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None blocking — all primary tools present.

## Validation Architecture

> `.planning/config.json` was not found in the read scope; treating `nyquist_validation` as enabled (default). Phase 193's verification is "CI measures itself" (zero-human-UAT).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (library, 274 `*_test.exs`) + Playwright (`test/example/priv/playwright`) |
| Config file | `mix.exs` (ExUnit) / `test/example/priv/playwright/playwright.config.ts` |
| Quick run command | `npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium` (FLAKE-01) |
| Full suite command | `mix test` (lib) ; the CI `example_playwright_smoke` lane (CRIT-01/FLAKE-01 in-CI) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BASE-01 | Committed baseline exists with required columns | artifact check | `test -f .planning/phases/193-*/193-BASELINE.md && grep -q "critical path" ...` | ❌ Wave 0 (artifact is the deliverable) |
| BASE-02 | Diagnostics recorded | artifact check | grep for `--slowest` / `schedulers_online` in baseline doc | ❌ Wave 0 |
| BASE-03 | Run summary shows versions + cache + timing | CI self-report | inspect a CI run's summary page after merge; `grep GITHUB_STEP_SUMMARY ci.yml` | ❌ Wave 0 (new CI steps) |
| CRIT-01 | Playwright lane no longer waits on library_tests | CI timing | next CI run: `example_playwright_smoke` start ≈ release_ref_guard end; wall-clock ↓ | ✅ measured via `gh run view` |
| FLAKE-01 | Color assertion deterministic, no retry reliance | Playwright | `npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium --retries=0` (run repeatedly) | ✅ demo-showcase.spec.ts:403 |

### Sampling Rate
- **Per task commit:** for FLAKE-01, `npx playwright test tests/demo-showcase.spec.ts --project=demo-showcase-chromium --retries=0` (must pass with retries OFF).
- **Per phase gate:** one full CI run post-merge; confirm (a) wall-clock dropped ~16m, (b) run summary shows versions/cache/timing, (c) demo-showcase green with no retry, (d) baseline artifact committed.

### Wave 0 Gaps
- [ ] `.planning/phases/193-.../193-BASELINE.md` — the BASE-01/02 deliverable (does not exist yet).
- [ ] `$GITHUB_STEP_SUMMARY` steps + cache-step `id:`s in `ci.yml` (BASE-03 — none exist).
- [ ] Move `.planning/todos/pending/2026-06-19-demo-showcase-remember-checkbox-color-flaky.md` → `completed/` on FLAKE-01 done.

## Security Domain

> `security_enforcement` config not found in read scope; default = enabled. Phase 193 changes are workflow-YAML + a planning doc + a test assertion — no auth/crypto/input-handling surface. The relevant security posture is the workflow's own supply-chain hygiene, which Phase 193 must PRESERVE (not weaken).

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | n/a — no auth code touched |
| V5 Input Validation | no | n/a — no user input surface |
| V6 Cryptography | no | n/a |
| V14 Config / CI supply-chain | **yes** | Preserve `permissions: contents: read`; keep all third-party actions SHA-pinned (e.g. `actions/cache@27d5ce7...`, `erlef/setup-beam@fc68ffb...`); do not add unpinned actions for the summary work (use shell `run:`, not a new action). |

### Known Threat Patterns for GitHub Actions
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unpinned 3rd-party action | Tampering / Elevation | BASE-03 uses plain `run:` shell + `$GITHUB_STEP_SUMMARY` — no new action dependency. |
| Over-broad `GITHUB_TOKEN` | Elevation | Top-level `permissions: contents: read` stays; summary writes need no extra scope. |
| Shell injection from PR metadata into summary | Tampering | Echo only resolved versions / step outputs / static strings — never interpolate untrusted `github.event.*` into a summary `run:`. |

## Sources

### Primary (HIGH confidence)
- `.github/workflows/ci.yml` (1231 lines) — full job graph, `needs:` edges, cache steps, `ci-gate` aggregator, `example_playwright_smoke` edge at line 697.
- `gh run view 27846034918 --json jobs` — live per-job timings (the run REQUIREMENTS.md cites); proves the CRIT-01 serialization (2s gap).
- `gh api repos/szTheory/sigra/branches/main/protection` — `main` is NOT protected; gate is the in-workflow `ci-gate`.
- `test/example/priv/playwright/tests/demo-showcase.spec.ts` — FLAKE-01 assertion (885-887), test block (403), `rgbChannels` parser (52).
- `.planning/todos/pending/2026-06-19-demo-showcase-remember-checkbox-color-flaky.md` — failure signature + fix directions + acceptance.
- `.planning/seeds/SEED-005-...md` — grounded baseline, verbatim audit-playbook column set (§3), critical-path thesis.
- `.planning/REQUIREMENTS.md` — BASE-01/02/03, CRIT-01, FLAKE-01 exact text + traceability (193).
- `CLAUDE.md` — local-dev Postgres prereqs, SEED-004 phx_new 1.8.7 pin, determinism notes.

### Secondary (MEDIUM confidence)
- hexdocs.pm `mix test` (`--slowest`), `mix compile --profile time`, `mix xref` — diagnostic invocations [CITED, not re-fetched this session — standard Mix tasks].
- GitHub Actions docs: `$GITHUB_STEP_SUMMARY`, `actions/cache` `cache-hit` output requires step `id` [CITED].
- GitHub-hosted `ubuntu-latest` = 2 vCPU / 7 GB (standard public-repo Linux runner) → `System.schedulers_online()` = 2 [CITED].

### Tertiary (LOW confidence)
- p95 availability — depends on how many comparable green runs exist (Open Question 1).

## Metadata

**Confidence breakdown:**
- CI job graph / CRIT-01: **HIGH** — read from live `ci.yml` + real `gh run` timing; serialization and edge-gratuitousness both empirically proven.
- Baseline mechanics (BASE-01): **HIGH** — `gh` commands executed successfully this session.
- Elixir diagnostics (BASE-02): **HIGH** for invocations & 2-core fact; **MEDIUM** on exact slowest-test numbers (not run this session — they belong in the artifact).
- Observability (BASE-03): **HIGH** — confirmed zero existing usage; mechanism is first-party and well-documented.
- FLAKE-01: **HIGH** — exact file/line/test-block + existing parser confirmed; fix is ~5 lines.

**Research date:** 2026-06-19
**Valid until:** 2026-07-19 (stable; the only volatility is which CI runs exist for p95 — re-pull `gh run list` at plan time).
