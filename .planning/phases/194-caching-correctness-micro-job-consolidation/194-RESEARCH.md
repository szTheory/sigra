# Phase 194: Caching Correctness & Micro-Job Consolidation - Research

**Researched:** 2026-06-19
**Domain:** GitHub Actions CI/CD (cache-key correctness, step-summary observability, job-topology consolidation) — single workflow `.github/workflows/ci.yml` + `scripts/ci/*` + `MAINTAINING.md`
**Confidence:** HIGH (live ci.yml, live ruleset, and actions/cache + setup-beam docs all verified this session)

## Summary

This is a pure CI/CD infrastructure phase. CONTEXT.md already locked all 15 decisions with exact cache namespaces, the live-ruleset guardrail, and the `fast_checks` fold shape. Research therefore focused on **verifying CONTEXT's line references against the live file** and **de-risking the open implementation mechanics**: actions/cache `cache-hit` semantics under `restore-keys`, setup-beam's resolved version outputs, and the precise count/location of every cache block and guard job.

All CONTEXT claims verified true against the live ci.yml (1257 lines) and live ruleset 14941512. Three planning-relevant findings that CONTEXT under-specified surfaced: (1) there are **11 deps+`_build` cache blocks**, not "~10", plus **4 additional `-hex-registry-` cache blocks** that D-04 does not enumerate — the planner must decide explicitly whether the hex-registry caches are in or out of the precision fix (recommendation: leave them as-is, they are keyed on `mix.lock` and already carry `restore-keys`, and they cache the registry not `_build`, so no stale-artifact correctness risk); (2) `actions/cache` `cache-hit` is `'true'` **only on exact key match** — on a `restore-keys` partial match it is the string `'false'`, so the D-09 summary must label "exact hit" vs "partial/miss" honestly; (3) the `example_deps_cache` id (ci.yml:745, playwright lane) is set but its `cache-hit` is **never read** — D-09 should wire it into a summary or the id is dead.

**Primary recommendation:** Apply the D-04 key shape uniformly to the **11 deps+`_build` blocks only**, using setup-beam's resolved `steps.setup.outputs.elixir-version` / `outputs.otp-version` (give the existing `erlef/setup-beam` step an `id: setup`), keep the 4 hex-registry caches untouched, add an `id:` to each of the 11 cache steps, and extend the existing `$GITHUB_STEP_SUMMARY` block to report each `cache-hit`. Fold the 6 leaf guards into one `fast_checks` job (single checkout, 6 distinct named `run:` steps), keep `release_ref_guard` standalone, rewire `ci-gate.needs` in lockstep. Re-read the live ruleset at execution time per D-03.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Cache key correctness | CI / Build infra (`actions/cache`) | — | Stale-`_build` correctness is a runner-cache concern, owned entirely by ci.yml cache blocks |
| Resolved toolchain identity | CI / Build infra (`erlef/setup-beam`) | — | setup-beam resolves the concrete OTP/Elixir version; its outputs feed the cache key |
| Cache-hit observability | CI / Reporting (`$GITHUB_STEP_SUMMARY`) | — | Pure CI surface; no app code, reuses Phase-193 seam |
| Required-check enforcement | GitHub repo config (ruleset 14941512) | CI job `name:` strings | Enforcement lives in the ruleset; ci.yml only supplies matching `name:` contexts |
| Job-startup overhead | CI / Job topology (`fast_checks` fold) | `ci-gate` aggregator | Runner-startup cost is a workflow-topology concern |

## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Live enforced required checks are 5 lane `name:` strings in ruleset 14941512 (`enforcement: active`): `Library tests`, `Example unit smoke (ExUnit + ConnTest)`, `Install smoke (fresh phx.new + sigra.install)`, `Example HTTP smoke (boot + curl critical routes)`, `Example Playwright smoke (full lifecycle)`. `ci-gate` is NOT required; legacy branch protection absent (404). None of the 7 micro-guards is independently required.
- **D-02:** Never rename or remove those 5 protected lane names. Consolidation + cache changes leave them byte-identical.
- **D-03 (MANDATORY):** At execution time, re-read the live ruleset (`gh api repos/szTheory/sigra/rulesets/14941512`) as ground truth. If a 6th/renamed context appeared, stop and reconcile before touching any job name.
- **D-04:** Add OTP + Elixir identity + a manual buster to every `deps`+`_build` cache key, uniformly across all blocks. Shape: `${{ runner.os }}-<namespace>-otp${OTP}-elixir${ELIXIR}-${MIX_ENV}-${{ hashFiles('.tool-versions','mix.lock') }}-v1`. Prefer setup-beam resolved outputs where available; else hash `.tool-versions`. Trailing `-v1` is the documented bust handle.
- **D-05:** Preserve cache namespaces `-library-`, `-library-dep-off-`, `-example-`, `-example-dev-`. Precision fix applies to all identically.
- **D-06:** Keep `deps` and `_build` co-located in one cache entry. No PLT/dialyzer exists today — "separate deps from PLT cache" satisfied forward-lookingly (do NOT introduce a shared deps+PLT key). Document so a future Dialyzer gets its own PLT cache.
- **D-07:** `mix deps.get` already runs as an unconditional separate step in every lane — preserve exactly (never gate on `cache-hit`).
- **D-08:** `restore-keys` may be added for hit-rate (D-07 guarantees reconciliation). If added, verify partial restores don't leave a half-restored `_build` un-recompiled.
- **D-09:** Surface cache hit-rate by extending the Phase-193 `$GITHUB_STEP_SUMMARY` pattern (`ci.yml:197-217`-style `if: always()` shell step). Add `id:` to every cache step, read `steps.<id>.outputs.cache-hit`. No new third-party action.
- **D-10:** Document buster value + how-to-bust in MAINTAINING.md, under the cache-retention / Actions runbook headings.
- **D-11:** Fold 6 leaf guards into ONE `fast_checks` job: `milestone_verification_gate`, `installer_milestone_audit`, `getting_started_uat_contract`, `phase_34_uat_contract`, `snapshot_drift_guard`, `quality_ledger_monotonic`.
- **D-12:** KEEP `release_ref_guard` as a separate standalone job (deviating from the literal CACHE-02 list). It is a no-checkout ~2s `needs:` DAG gate for ~9 heavy lanes; folding it in would add checkout latency in front of every heavy lane. (User-confirmed deviation.)
- **D-13:** `fast_checks` uses a single `checkout` with `fetch-depth: 0` plus the per-PR `git fetch origin <base_ref> --depth=1` pattern (snapshot + ledger guards diff the base ref). Each of the 6 guards runs as a distinct named `run:` step. None of the 6 needs Postgres/Elixir/Node.
- **D-14:** Rewire `ci-gate.needs` in lockstep: drop `snapshot_drift_guard` + `quality_ledger_monotonic`, add `fast_checks`, update the result-aggregation loop. A red guard step → red `fast_checks` → red `ci-gate`.
- **D-15:** Correct stale CI docs. Update MAINTAINING.md's required-check list to match the live ruleset (5 names in D-01) and note `ci-gate` is an internal aggregator, not the enforced required check. ROADMAP success criteria #4 ("ci-gate remains the single required check") reflects an outdated premise; record corrected reality in CONTEXT/VERIFICATION.

### Claude's Discretion
- Exact key string format/order (so long as OS+arch+OTP+Elixir+MIX_ENV+lockfile+buster all represented and namespaces preserved per D-04/D-05).
- Whether to add `restore-keys` (D-08) — decide on measured hit-rate benefit vs simplicity.
- Step ordering within `fast_checks` and exact summary block formatting.

### Deferred Ideas (OUT OF SCOPE)
- Splitting `deps` into its own cache separate from `_build` — perf, not correctness; revisit Phase 195.
- Introducing a Dialyzer/PLT lane (would need its own PLT cache per D-06) — not this milestone.
- Larger runners for long poles — Phase 195 (CACHE-03).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CACHE-01 | Audit + correct caching — precise keys (OS/arch/OTP/Elixir/MIX_ENV/lockfile/buster), no `_build` reuse across incompatible combos, never skip `deps.get` after partial restore; separate deps from any PLT cache; document how to bust. | Verified cache-key shape (D-04), setup-beam outputs (`otp-version`/`elixir-version`), `cache-hit` semantics under `restore-keys`, the 11 deps+`_build` blocks + 4 hex-registry blocks inventory, and that `mix deps.get` is already unconditional in every lane (D-07 satisfied). |
| CACHE-02 | Consolidate trivial micro-guard jobs into one cheap "fast checks" job to cut per-job startup overhead — preserving stable required-check names. | Verified all 7 guard jobs, confirmed none of the 6 folded guards needs a toolchain, verified the base-ref fetch pattern, the `ci-gate` `needs:` + `${{ needs.*.result }}` loop, and that the 5 protected names are untouched by the fold (live ruleset confirms `ci-gate` and the 7 guards are not required checks). |

## Live File Verification (CONTEXT line refs confirmed)

Every CONTEXT line reference was confirmed against the live `.github/workflows/ci.yml` (1257 lines total). Drift notes inline.

| CONTEXT claim | Live ci.yml | Status |
|---------------|-------------|--------|
| Step-summary seam `ci.yml:197-217` | L197 `CI run summary` (`if: always()`) → L206 `}>>"$GITHUB_STEP_SUMMARY"`; L207-217 `Test timing summary` | ✅ EXACT |
| `deps_cache` id wired (L168), reads `cache-hit` (L205) | L168 `id: deps_cache`; L205 `steps.deps_cache.outputs.cache-hit` | ✅ EXACT |
| `example_deps_cache` id (2nd lane) | L745 `id: example_deps_cache` (playwright lane) — **but `outputs.cache-hit` is NEVER read** | ⚠️ DRIFT: id set, output unused. CONTEXT said cache-hit "already wired on 2 lanes" — only `deps_cache` actually reads it. |
| `ci-gate` aggregator "~L1204" | L1204 `ci-gate:`; `needs:` L1207-1217 (10 needs); `${{ needs.*.result }}` env L1222-1231; aggregation loop L1235-1252 | ✅ EXACT |
| Snapshot guard base-ref fetch `ci.yml:1156-1171` | L1156 checkout `fetch-depth:0`; L1159-1169 `Resolve base ref` (`git fetch origin "$base_ref" --depth=1`) | ✅ EXACT |
| Ledger guard base-ref fetch `ci.yml:1187-1202` | L1187 checkout `fetch-depth:0`; L1190-1200 `Resolve base ref`; L1201 run | ✅ EXACT |
| `release_ref_guard` no-checkout fast gate (D-12) | L24-43: single `run:` step, NO `actions/checkout`, exits 0 on non-`workflow_dispatch` | ✅ EXACT (~2s) |
| 7 guard jobs | `release_ref_guard`(24), `milestone_verification_gate`(44), `installer_milestone_audit`(52), `getting_started_uat_contract`(1129), `phase_34_uat_contract`(1139), `snapshot_drift_guard`(1152), `quality_ledger_monotonic`(1183) | ✅ All present |

## Live Ruleset Verification (D-01 / D-03 ground truth)

`gh api repos/szTheory/sigra/rulesets/14941512` returned (this session, 2026-06-19):

- `name: main`, `enforcement: active`
- `required_status_checks` contexts (byte-identical to D-01):
  1. `Library tests`
  2. `Example unit smoke (ExUnit + ConnTest)`
  3. `Install smoke (fresh phx.new + sigra.install)`
  4. `Example HTTP smoke (boot + curl critical routes)`
  5. `Example Playwright smoke (full lifecycle)`
- `ci-gate` is NOT in the list. The 7 guard jobs are NOT in the list.

`[VERIFIED: gh api ruleset 14941512]` — No 6th/renamed context. **D-03 must still be re-run at execution time** (the ruleset can change between research and execution). None of the 5 protected names is among the jobs being touched by the fold, so the consolidation is name-safe.

## Cache Block Inventory (the actual D-04 surface)

CONTEXT said "~10 cache blocks". Live count is **15 `actions/cache` blocks**: **11 deps+`_build`** (the D-04 targets) + **4 `-hex-registry-`** (NOT in D-04's namespace list — planner decision needed).

### deps+`_build` blocks — apply D-04 here (11 total)

| Line | Namespace | Path | Job |
|------|-----------|------|-----|
| 120 | `-library-` | deps, _build | install_golden_contract |
| 174 | `-library-` | deps, _build | library_tests (has `id: deps_cache`) |
| 248 | `-library-dep-off-` | deps, _build | library_tests_dep_off |
| 310 | `-example-` | test/example/{deps,_build} | example_unit_smoke |
| 361 | `-library-` | deps, _build | install_smoke |
| 411 | `-library-` | deps, _build | upgrade_smoke |
| 459 | `-library-` | deps, _build | passkeys_manual_fallback_smoke |
| 517 | `-library-` | deps, _build | install_matrix |
| 632 | `-library-` | deps, _build | passkeys_opt_out_smoke |
| 680 | `-example-dev-` | test/example/{deps,_build} | example_http_smoke |
| 751 | `-example-dev-` | test/example/{deps,_build} | example_playwright_smoke (has `id: example_deps_cache`) |

Namespace tally matches D-05: `-library-`=7, `-library-dep-off-`=1, `-example-`=1, `-example-dev-`=2.

### `-hex-registry-` blocks — NOT in D-04's namespace list (4 total)

| Line | Key | restore-keys | Job |
|------|-----|--------------|-----|
| 366 | `${{ runner.os }}-hex-registry-${{ hashFiles('mix.lock') }}` | `${{ runner.os }}-hex-registry-` | install_smoke |
| 416 | same shape | yes | upgrade_smoke |
| 464 | same shape | yes | passkeys_manual_fallback_smoke |
| 637 | same shape | yes | passkeys_opt_out_smoke |

**Planner decision (LANDMINE):** D-04 says "every `deps`+`_build` cache key" and enumerates only the 4 deps namespaces. The hex-registry caches cache the Hex *package registry* (`~/.hex` / `~/.mix`), **not** compiled `_build` artifacts, so they carry **no stale-`_build` correctness risk** — a stale registry just triggers a re-fetch. **Recommendation: leave the 4 hex-registry blocks untouched** (they already have `restore-keys` and are keyed on `mix.lock`). The planner should state this explicitly so a reviewer doesn't read "uniformly across all ~10 cache blocks" as "also rewrite hex-registry". `[VERIFIED: ci.yml grep]`

## Architecture Patterns

### Pattern 1: Precise cache key via setup-beam resolved outputs (D-04)

Give the existing `erlef/setup-beam` step an `id`, then reference its outputs in every deps cache key. This is cleaner than `hashFiles('.tool-versions')` because it binds to the *resolved* concrete version, not the pin string.

```yaml
# Source: github.com/erlef/setup-beam (outputs: otp-version, elixir-version)
- uses: erlef/setup-beam@fc68ffb90438ef2936bbb3251622353b3dcb2f93  # v1.24.0
  id: setup                       # NEW: expose resolved versions
  with:
    version-file: .tool-versions
    version-type: strict
- name: Cache library deps
  id: deps_cache                  # already present on L168; add id: to the other 10
  uses: actions/cache@27d5ce7f107fe9357f9df03efb73ab90386fccae  # v5.0.5
  with:
    path: |
      deps
      _build
    # MIX_ENV is test for this lane; encode it literally per-lane (test/dev) to match D-04.
    key: ${{ runner.os }}-library-otp${{ steps.setup.outputs.otp-version }}-elixir${{ steps.setup.outputs.elixir-version }}-test-${{ hashFiles('mix.lock') }}-v1
```

Notes:
- setup-beam outputs are like `otp-version: OTP-26.0`, `elixir-version: v1.14-otp-26` `[CITED: github.com/erlef/setup-beam]` — they contain characters (`-`) safe in a cache key. The current pins are `erlang 28.5` / `elixir 1.19.5-otp-28`.
- `runner.os` already encodes OS; GitHub-hosted `ubuntu-latest` is x64, so OS string covers arch for this single-runner pipeline. If you want arch explicit, `runner.arch` is available. CONTEXT's "OS+arch" is satisfied by `runner.os` on a single-arch pipeline; add `runner.arch` only if you want belt-and-suspenders.
- `MIX_ENV`: most lanes run `test`; the `-example-dev-` lanes run `dev`. Encode the env literally per namespace (`-test-` vs `-dev-`) rather than `${{ env.MIX_ENV }}` since not all cache steps have MIX_ENV in scope at that point. The namespace already distinguishes dev (`-example-dev-`) from test (`-example-`), so the literal env segment is partly redundant but satisfies D-04's checklist explicitly.
- Trailing `-v1` is the manual buster (D-04/D-10).

**Recommended key strings (per namespace):**
- `${{ runner.os }}-library-otp${{ steps.setup.outputs.otp-version }}-elixir${{ steps.setup.outputs.elixir-version }}-test-${{ hashFiles('mix.lock') }}-v1`
- `${{ runner.os }}-library-dep-off-otp${{ steps.setup.outputs.otp-version }}-elixir${{ steps.setup.outputs.elixir-version }}-test-${{ hashFiles('mix.lock') }}-v1`
- `${{ runner.os }}-example-otp${{ steps.setup.outputs.otp-version }}-elixir${{ steps.setup.outputs.elixir-version }}-test-${{ hashFiles('test/example/mix.lock', 'test/example/config/**', 'test/example/lib/**/*.ex', 'lib/**/*.ex', 'mix.exs') }}-v1`
- `${{ runner.os }}-example-dev-otp${{ steps.setup.outputs.otp-version }}-elixir${{ steps.setup.outputs.elixir-version }}-dev-${{ hashFiles('test/example/mix.lock', 'test/example/config/**', 'test/example/lib/**/*.ex', 'lib/**/*.ex', 'mix.exs') }}-v1`

Preserve each namespace's existing `hashFiles(...)` file-set exactly (the example lanes hash a richer set than `mix.lock` alone — keep it).

### Pattern 2: Cache-hit observability in step summary (D-09)

Extend the existing L197-206 block. With `restore-keys` present, `cache-hit` is `'true'` only on exact match — label honestly.

```yaml
# Source: existing ci.yml:197-206 pattern + actions/cache cache-hit semantics
- name: CI run summary
  if: always()
  run: |
    {
      echo "## library_tests"
      echo "- elixir: $(elixir --version | tail -1)"
      echo "- otp: $(erl -noshell -eval 'io:format("~s",[erlang:system_info(otp_release)]),halt().')"
      echo "- deps cache (exact hit): ${{ steps.deps_cache.outputs.cache-hit }}"  # 'true' | 'false' | ''
    } >> "$GITHUB_STEP_SUMMARY"
```

`steps.<id>.outputs.cache-hit` values `[VERIFIED: actions/cache docs]`:
- `'true'` — exact `key` match (cache fully reused, no save at job end)
- `'false'` — `key` missed but a `restore-keys` prefix matched (partial restore; cache IS saved at job end on success)
- `''` (empty) — total miss, no restore-keys match (cache saved at job end on success)

D-09 wiring task: add `id:` to all 11 deps cache steps; add/extend an `if: always()` summary step in each lane (or at least each protected lane) that echoes its `cache-hit`. **Also wire the orphan `example_deps_cache` (L745)** into the playwright lane summary, or its id is dead.

### Pattern 3: fast_checks fold (D-11/D-13)

Single job, single checkout, 6 distinct named `run:` steps so per-guard failure remains legible in the Actions UI. The base-ref fetch must run ONCE (snapshot + ledger guards both diff the base ref).

```yaml
fast_checks:
  name: Fast checks (milestone/installer/contracts/snapshot/ledger guards)
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@df4cb1c069e1874edd31b4311f1884172cec0e10  # v6.0.3
      with:
        fetch-depth: 0
    - name: Resolve base ref            # the L1159-1169 / L1190-1200 pattern, run ONCE
      id: base
      shell: bash
      run: |
        set -euo pipefail
        if [ "${{ github.event_name }}" = "pull_request" ]; then
          git fetch origin "${{ github.base_ref }}" --depth=1
          echo "ref=origin/${{ github.base_ref }}" >> "$GITHUB_OUTPUT"
        else
          echo "ref=HEAD~1" >> "$GITHUB_OUTPUT"
        fi
    - name: Milestone verification gate
      run: bash scripts/ci/milestone-verification-gate.sh
    - name: Installer milestone audit (INT-01..03)
      run: bash scripts/ci/installer-milestone-audit.sh          # see note on its PR-detect gate
    - name: Getting started doc contract
      run: bash scripts/ci/getting-started-contract.sh
    - name: Phase 34 UAT contracts
      run: scripts/ci/phase34-uat-contracts.sh
    - name: Snapshot drift guard (canary allowlist)
      run: bash scripts/ci/snapshot-canary-guard.sh --base "${{ steps.base.outputs.ref }}"
    - name: Snapshot drift guard — design lane
      run: |
        SNAP_DIR="test/example/priv/playwright/tests/admin-design.spec.ts-snapshots" \
        bash scripts/ci/snapshot-canary-guard.sh \
          --base "${{ steps.base.outputs.ref }}" \
          --allowlist test/example/priv/playwright/snapshot-allowlist-design \
          --canary board-notice
    - name: Quality ledger monotonic guard
      run: bash scripts/ci/quality-ledger-monotonic.sh --base "${{ steps.base.outputs.ref }}"
```

**LANDMINE — `installer_milestone_audit` PR-detect gate (L59-77):** The standalone job has a `Detect installer-related changes` step (`id: detect`) that sets `run=true/false` and the audit step is gated `if: steps.detect.outputs.run == 'true'`. When folded into a single job, you have two faithful options: (a) preserve the detect logic as a leading sub-step and gate the audit `run:` with `if: steps.detect.outputs.run == 'true'`, or (b) inline the path-diff into the audit step. Option (a) is the lossless port. The detect step also does its own `git fetch origin "$base_ref" --depth=1` — with the shared `fetch-depth:0` checkout + the single base-ref fetch already present, this is redundant but harmless; can be deduped. **Do not silently drop the path-gating** or the installer audit will start running on every PR (behavior change). `[VERIFIED: ci.yml L59-77]`

### Pattern 4: ci-gate rewire in lockstep (D-14)

Current `ci-gate.needs` (L1207-1217) lists 10 jobs including `snapshot_drift_guard` + `quality_ledger_monotonic`. After the fold:
- **Drop** from `needs`: `snapshot_drift_guard`, `quality_ledger_monotonic`
- **Add** to `needs`: `fast_checks`
- Update the env block (L1222-1231) and the loop list (L1235-1245): drop `SNAPSHOT_DRIFT_GUARD`, `QUALITY_LEDGER_MONOTONIC`; add `FAST_CHECKS: ${{ needs.fast_checks.result }}`.

Because all 6 guards run as steps in one job, a single red step fails `fast_checks` (`set -euo pipefail` per step), which surfaces as `needs.fast_checks.result != 'success'` → red `ci-gate`. Equivalent aggregation preserved. **Note:** `fast_checks` is the ONLY new aggregation entry; the other folded guards (`milestone_verification_gate`, `installer_milestone_audit`, `getting_started_uat_contract`, `phase_34_uat_contract`) were never in `ci-gate.needs` to begin with, so their signal newly enters `ci-gate` via `fast_checks` — a **net increase** in gate coverage, which is acceptable (equal-or-greater signal). Flag this in VERIFICATION.

### Anti-Patterns to Avoid
- **Gating `mix deps.get` on `cache-hit`:** Never. D-07 — it must stay unconditional. The dep-off lane (L264 `mix deps.compile`, L278 `mix compile`) already reconciles `_build` after any restore, which is exactly why a partial restore is safe (D-08).
- **Rewriting the 4 hex-registry caches into the D-04 shape:** They cache the registry, not `_build`; no correctness risk; out of D-04's namespace list.
- **Adding a new third-party action for cache-hit reporting:** Forbidden by D-09 (supply-chain surface). The native `cache-hit` output + `$GITHUB_STEP_SUMMARY` covers it.
- **Renaming any of the 5 protected lane names:** D-02. The fold touches only non-required jobs.
- **Folding `release_ref_guard` into `fast_checks`:** D-12 — it would put a checkout in front of every heavy lane's `needs:` gate.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Reporting cache hit/miss | A custom action or curl to the cache API | Native `steps.<id>.outputs.cache-hit` → `$GITHUB_STEP_SUMMARY` | Zero new deps, already the Phase-193 pattern (D-09) |
| Resolving OTP/Elixir version for the key | Parsing `.tool-versions` in shell | `steps.<id>.outputs.{otp,elixir}-version` from setup-beam | Resolved, canonical, no parsing |
| Aggregating guard results | A matrix or external status-check tool | The existing `ci-gate` `${{ needs.*.result }}` loop | Already in place; just rewire `needs` |

## Common Pitfalls

### Pitfall 1: `cache-hit` reads `'false'` on a successful partial restore
**What goes wrong:** A summary that says "cache hit: false" while the cache WAS partially restored looks like a miss.
**Why it happens:** `actions/cache` sets `cache-hit='true'` only on exact `key` match; `restore-keys` partial matches report `'false'`. `[VERIFIED: actions/cache docs + GitHub Docs]`
**How to avoid:** Label the summary line "exact hit" (`cache-hit == 'true'`). If `restore-keys` is added (D-08), optionally also note partial restores — but the current ci.yml has NO `restore-keys` on deps blocks, so today `cache-hit` is cleanly `'true'`/`''`.

### Pitfall 2: Cache key changes invalidate ALL existing caches on first run
**What goes wrong:** Adding `otp…-elixir…-v1` to the key produces a full cache miss on the first post-merge run (every lane recompiles cold once).
**Why it happens:** New key string = new cache namespace; old caches are unreachable.
**How to avoid:** Expected and acceptable — it is a one-time cold run. Document in the PR description. No `restore-keys` means no warm fallback on that first run; if that cold run is a concern, adding `restore-keys: ${{ runner.os }}-library-otp…-elixir…-test-` (prefix without the lockfile hash) gives a warm `_build` that `mix deps.get` + recompile then reconciles (D-08).

### Pitfall 3: Dropping the installer-audit path gate during the fold
**What goes wrong:** `installer_milestone_audit` runs on every PR instead of only installer-touching PRs → slower + noisier.
**Why it happens:** The detect/`if:` gate (L59-77) is easy to lose when flattening into one job.
**How to avoid:** Port the `id: detect` step + `if: steps.detect.outputs.run == 'true'` gate faithfully. `[VERIFIED: ci.yml L59-77]`

### Pitfall 4: Live ruleset drift between research and execution
**What goes wrong:** A 6th required context appears after research; the fold silently breaks enforcement.
**Why it happens:** Ruleset is mutable repo config, not in git.
**How to avoid:** D-03 — re-run `gh api repos/szTheory/sigra/rulesets/14941512` at execution time and diff against the 5 names before touching any job name.

## Runtime State Inventory

This is a CI-config phase. The "runtime state" that a file grep would miss is **GitHub repo configuration**, audited below.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no DB/datastore keys involve CI names | None |
| Live service config | **Ruleset 14941512** (`name: main`, active) holds the 5 required-check contexts in GitHub repo config, NOT in git. The folded job names (`snapshot_drift_guard`, `quality_ledger_monotonic`, etc.) are NOT in it. | Re-read at execution (D-03). No ruleset edit needed — folded jobs aren't required checks. Legacy branch-protection API returns 404 (none). |
| OS-registered state | None | None |
| Secrets/env vars | None renamed; `HEX_API_KEY`/`RELEASE_PLEASE_TOKEN` unaffected | None |
| Build artifacts | GitHub Actions **cache entries** keyed on the OLD key strings become unreachable after the D-04 key change | None required (one-time cold run; old caches expire by retention). Optionally bump nothing else. |

**Verified:** The 5 enforced contexts reference job `name:` strings that this phase does not touch. `ci-gate` and all 7 guards are non-required. So no GitHub-config edit is needed for the fold — only the in-git ci.yml + docs change.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `cache-hit` truthy on any restore | `cache-hit='true'` only on exact key; `'false'` on restore-keys partial | actions/cache v3+ | D-09 summary must label "exact hit" |
| Hash `.tool-versions` for version identity | setup-beam exposes resolved `otp-version`/`elixir-version` outputs | setup-beam v1.15+ | Cleaner key (D-04 preference) |

**Deprecated/outdated:**
- MAINTAINING.md L100-117 documents `Install golden + idempotency contract (subprocess harness)` as THE branch-protection required check. The live ruleset does NOT include it among the 5 enforced contexts. This is the stale doc D-15 must correct (note: install_golden flows into `ci-gate`, which is itself not the enforced check). `[VERIFIED: gh api + MAINTAINING.md L113]`

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Leaving the 4 `-hex-registry-` caches outside the D-04 fix is correct (they cache registry not `_build`, no stale-artifact risk) | Cache Block Inventory | LOW — if planner wants literal "all caches" uniformity, add the version segment to hex-registry too; harmless, just more churn |
| A2 | `runner.os` adequately encodes arch on this single-arch (`ubuntu-latest`, x64) pipeline; explicit `runner.arch` optional | Pattern 1 | LOW — single-runner pipeline; add `runner.arch` for literal CONTEXT "OS+arch" compliance if desired |
| A3 | The 6 guard scripts truly need no Elixir/Node/Postgres (mix/playwright strings in 2 scripts are inside `grep` matchers, not invocations) | Pattern 3 | LOW — verified by reading the scripts; a future script edit could add a toolchain need |

## Open Questions

1. **Add `restore-keys` (D-08) or not?**
   - What we know: No deps block currently has `restore-keys` (only the 4 hex-registry blocks do). The D-04 key change causes a one-time cold run.
   - What's unclear: Whether the warm-start hit-rate benefit justifies the added complexity (Claude's discretion per D-08/D-99 discretion list).
   - Recommendation: Add a single prefix `restore-keys` per namespace (everything before `${{ hashFiles('mix.lock') }}`) — it cushions the first post-merge cold run and every lockfile bump, and D-07's unconditional `mix deps.get` + each lane's recompile (esp. dep-off L264/L278) already reconciles a stale `_build`. Low risk, real benefit.

2. **Per-lane summary or only protected lanes for D-09?**
   - What we know: 11 deps cache steps; adding a summary step to each is verbose.
   - Recommendation: Add `id:` to all 11 (cheap), but only add `$GITHUB_STEP_SUMMARY` cache-hit lines to the 5 protected lanes + the 2 example lanes (the ones whose cache matters for the critical path), to keep the diff tight. Discretion per D-09.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `gh` CLI (authed to szTheory/sigra) | D-03 live-ruleset re-read | ✓ | — | None — D-03 is mandatory; without it, stop |
| `actions/cache` | All cache blocks | ✓ (pinned v5.0.5 `27d5ce7`) | v5.0.5 | None |
| `erlef/setup-beam` outputs | D-04 key | ✓ (pinned v1.24.0 `fc68ffb`) | v1.24.0 | Hash `.tool-versions` |
| The 6 guard scripts | fast_checks | ✓ (all present in `scripts/ci/`) | — | None |

**Missing dependencies with no fallback:** None. **Missing with fallback:** None.

## Validation Architecture

> No Elixir test framework is in scope — this phase changes CI YAML + bash guards + docs. Validation is CI-self-validation (the workflow must parse and run green) plus the existing guard scripts, not ExUnit.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None (CI infra). Validation = workflow parses + runs green on a PR; guard scripts are the executable contracts |
| Config file | `.github/workflows/ci.yml` |
| Quick run command | `actionlint .github/workflows/ci.yml` (YAML/expression lint, if available) or `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"` for parse-only |
| Full suite command | Push the branch → observe the live CI run; `gh run watch` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CACHE-01 | Every deps key carries OTP+Elixir+MIX_ENV+lockfile+buster | smoke (grep) | `grep -c "otp.*elixir.*-v1" .github/workflows/ci.yml` ≥ 11 | ✅ |
| CACHE-01 | `mix deps.get` still unconditional in every lane | smoke (grep) | `grep -c "name: Fetch.*deps\|name: Install Hex" ...` unchanged | ✅ |
| CACHE-01 | Cache-hit surfaced in step summary | smoke (grep) | `grep "outputs.cache-hit" .github/workflows/ci.yml` count increased | ✅ |
| CACHE-02 | 6 guards folded; `fast_checks` exists; `ci-gate.needs` rewired | smoke (grep) | `grep -c "fast_checks:" ...`==1; old guard job keys absent | ✅ |
| D-01/D-02 | 5 protected names byte-identical | live | `gh api …/rulesets/14941512` diff vs 5 names | ✅ (runtime) |

### Sampling Rate
- **Per task commit:** `actionlint` / YAML parse + targeted grep assertions.
- **Per wave merge:** Push branch, `gh run watch` the live CI; confirm green + the 5 contexts still report.
- **Phase gate:** Live CI green on the PR + D-03 ruleset re-read shows no drift.

### Wave 0 Gaps
- [ ] Confirm `actionlint` availability locally; if absent, fall back to `yaml.safe_load` parse + grep assertions. Framework install: `brew install actionlint` (optional).
- [ ] A VERIFICATION assertion script that greps ci.yml for the 11 keyed blocks + absence of the 6 folded job keys + presence of `fast_checks` — covers CACHE-01/CACHE-02 mechanically.

*(No ExUnit/Playwright work in this phase — those suites are unchanged consumers of the cache.)*

## Security Domain

> `security_enforcement` applies, but this phase touches no auth code, no input handling, no crypto. The relevant security surface is CI supply-chain + secrets, audited below.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V5 Input Validation | no | — |
| V6 Cryptography | no | — |
| V14 Configuration (CI/CD supply chain) | yes | All actions pinned to full SHA; D-09 forbids new unpinned actions; no new secrets |

### Known Threat Patterns for GitHub Actions CI
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Unpinned action tag → supply-chain swap | Tampering | All `uses:` pinned to full commit SHA (existing discipline); D-09 adds NO new action |
| Cache poisoning across incompatible toolchains | Tampering | D-04 binds key to resolved OTP+Elixir, preventing `_build` reuse across versions — this is the CACHE-01 correctness fix itself |
| Secret exposure in summary/logs | Information Disclosure | Summary echoes only version + cache-hit booleans; no secrets touched |

## Project Constraints (from CLAUDE.md)
- GSD workflow enforcement: file edits must flow through a GSD command (this is the research step of `/gsd-plan-phase`). The implementing tasks must run under `/gsd-execute-phase`.
- All actions pinned to full SHA (supply-chain discipline) — no new unpinned actions.
- SEED-004: phx_new pinned to 1.8.7 — unaffected by this phase (no install-fixture changes), but do not let any fold change the `mix archive.install --force hex phx_new 1.8.7` steps.
- Stepwise, reversible PRs; keep the `ci-gate` aggregator model (REQUIREMENTS Out-of-Scope).

## Sources

### Primary (HIGH confidence)
- `.github/workflows/ci.yml` (live, 1257 lines) — every cache block, guard job, `ci-gate` loop verified by direct read.
- `gh api repos/szTheory/sigra/rulesets/14941512` (live, 2026-06-19) — 5 enforced contexts, `enforcement: active`, `ci-gate` absent.
- `scripts/ci/{milestone-verification-gate,installer-milestone-audit,getting-started-contract,phase34-uat-contracts,snapshot-canary-guard,quality-ledger-monotonic}.sh` — toolchain-dependency audit.
- `.tool-versions` — `erlang 28.5`, `elixir 1.19.5-otp-28`.
- `MAINTAINING.md` (L100-121) — stale required-check doc (D-15 target) + cache-retention heading (D-10 target).

### Secondary (MEDIUM confidence)
- [github.com/erlef/setup-beam](https://github.com/erlef/setup-beam) — outputs `otp-version`, `elixir-version`, `gleam-version`, `rebar3-version`, `setup-beam-version`.
- [github.com/actions/cache](https://github.com/actions/cache) — `cache-hit` semantics: `'true'` exact only, empty on miss.
- [GitHub Docs / dependency-caching](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching) — partial match restores the most recent cache; `cache-hit` `'false'` on partial; new cache saved on key miss + job success.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Cache mechanics (CACHE-01): HIGH — actions/cache + setup-beam docs + live file all verified.
- Job topology (CACHE-02): HIGH — all 7 guards, ci-gate loop, base-ref pattern, and scripts read directly.
- Required-check safety (D-01/D-03): HIGH — live ruleset read this session; must re-read at execution (mutable).

**Research date:** 2026-06-19
**Valid until:** 2026-07-19 for cache/setup-beam mechanics (stable); **the live ruleset must be re-read at execution time regardless** (D-03 — it is mutable repo config).
