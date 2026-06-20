# Phase 194: Caching Correctness & Micro-Job Consolidation - Context

**Gathered:** 2026-06-19 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Make GitHub Actions caching **correct and observable** (no stale-artifact
correctness risk) and eliminate per-job runner-startup overhead from trivial
guard jobs — **without losing any required-check name**. Scope is `.github/workflows/ci.yml`,
its `scripts/ci/*` guard scripts, and the CI runbook docs (MAINTAINING.md).
Covers CACHE-01 (caching correctness) and CACHE-02 (micro-job consolidation).

Out of scope: test-suite partitioning / async / larger runners (Phase 195,
CACHE-03), PR-fast vs nightly trigger split (Phase 196), Playwright lane
restructuring (Phase 197).
</domain>

<decisions>
## Implementation Decisions

### Required-check safety (the consolidation guardrail)
- **D-01:** The live enforced required checks are **5 lane `name:` strings** in
  repo **ruleset 14941512** (`enforcement: active`): `Library tests`,
  `Example unit smoke (ExUnit + ConnTest)`, `Install smoke (fresh phx.new + sigra.install)`,
  `Example HTTP smoke (boot + curl critical routes)`, `Example Playwright smoke (full lifecycle)`.
  `ci-gate` is **NOT** a required check; legacy branch protection is absent (404).
  None of the 7 micro-guards is independently required.
- **D-02:** **Never rename or remove those 5 protected lane names.** Consolidation
  and cache changes must leave them byte-identical.
- **D-03 (MANDATORY):** At execution time, **re-read the live ruleset** (`gh api repos/szTheory/sigra/rulesets/14941512`)
  and treat it — not MAINTAINING.md, not the ROADMAP — as ground truth for which
  check names are required. If a 6th/renamed context has appeared, stop and reconcile
  before touching any job name.

### Cache key precision (CACHE-01 core)
- **D-04:** Add **OTP + Elixir identity + a manual buster** to every `deps`+`_build`
  cache key, applied **uniformly** across all ~10 cache blocks (library, `-dep-off-`,
  `-example-`, `-example-dev-`). Shape (illustrative):
  `${{ runner.os }}-<namespace>-otp${OTP}-elixir${ELIXIR}-${MIX_ENV}-${{ hashFiles('.tool-versions','mix.lock') }}-v1`.
  Prefer setup-beam's resolved `outputs.elixir-version` / `outputs.otp-version` where
  available; otherwise hash `.tool-versions`. The trailing manual buster (`-v1`) is the
  documented bust handle.
- **D-05:** Preserve the existing cache **namespaces** so lanes don't cross-contaminate:
  `-library-` (test), `-library-dep-off-` (threadline-absent compile), `-example-` (test),
  `-example-dev-` (dev). The precision fix applies to all of them identically.

### deps / _build / PLT separation + restore guarantee
- **D-06:** **Keep `deps` and `_build` co-located** in one cache entry (current behavior).
  No PLT/dialyzer exists in ci.yml today, so "separate deps cache from any PLT cache"
  is satisfied **forward-lookingly** — i.e., do NOT introduce a shared deps+PLT key.
  Document this so a future Dialyzer addition gets its own PLT cache.
- **D-07:** `mix deps.get` already runs as an **unconditional separate step** in every
  lane — preserve that exactly (never gate it on `cache-hit`). This satisfies "never skip
  deps.get after a partial restore."
- **D-08:** `restore-keys` (partial restore / warm start) **may** be added for hit-rate,
  but only because D-07 guarantees `deps.get` reconciles afterward. If added, verify
  partial restores don't leave a half-restored `_build` un-recompiled.

### Cache hit-rate observability + bust documentation
- **D-09:** Surface cache hit-rate by **extending the existing Phase-193
  `$GITHUB_STEP_SUMMARY` pattern** (`ci.yml:197-217` style: `if: always()` shell step
  appending to `$GITHUB_STEP_SUMMARY`). Add an `id:` to every cache step and read
  `steps.<id>.outputs.cache-hit`. **No new third-party action** (keeps the pinned-SHA
  supply-chain surface 193 deliberately minimized).
- **D-10:** Document the **buster value + how-to-bust** in **MAINTAINING.md**, as a
  subsection under the existing cache-retention / Actions runbook headings.

### Micro-job consolidation shape
- **D-11:** Fold the **6 leaf guards** into ONE `fast_checks` job:
  `milestone_verification_gate`, `installer_milestone_audit`, `getting_started_uat_contract`,
  `phase_34_uat_contract`, `snapshot_drift_guard`, `quality_ledger_monotonic`.
- **D-12:** **KEEP `release_ref_guard` as a separate standalone job** — deviating from
  the literal ROADMAP/CACHE-02 list. Rationale: it is a no-checkout (~2s) `needs:` DAG gate
  for ~9 heavy lanes; folding it into a checkout-bearing job would add checkout latency in
  front of every heavy lane and erode the CRIT-01 parallelization win. (User-confirmed deviation.)
- **D-13:** `fast_checks` uses a **single `checkout` with `fetch-depth: 0`** plus the
  per-PR `git fetch origin <base_ref> --depth=1` pattern (snapshot + ledger guards diff the
  base ref). Each of the 6 guards runs as a **distinct named `run:` step** so per-guard
  failure signal is preserved in the Actions UI even though the job is one unit. None of the
  6 needs Postgres/Elixir/Node.
- **D-14:** **Rewire `ci-gate.needs`** in lockstep: drop `snapshot_drift_guard` +
  `quality_ledger_monotonic`, add `fast_checks`, and update the result-aggregation loop
  accordingly. ci-gate must keep aggregating an equivalent set of results (a red guard step
  → red `fast_checks` → red ci-gate).

### Reality reconciliation (in scope this phase)
- **D-15:** **Correct the stale CI docs.** Update MAINTAINING.md's required-check list to
  match the live ruleset (the 5 names in D-01) and note that `ci-gate` is an internal
  aggregator, **not** the enforced required check. Honest closure — the ROADMAP success
  criteria #4 ("ci-gate remains the single required check") reflects an outdated premise;
  record the corrected reality in CONTEXT/VERIFICATION rather than perpetuating it.

### Claude's Discretion
- Exact key string format/order (so long as OS+arch+OTP+Elixir+MIX_ENV+lockfile+buster are
  all represented and namespaces preserved per D-04/D-05).
- Whether to add `restore-keys` (D-08) — decide on measured hit-rate benefit vs. simplicity.
- Step ordering within `fast_checks` and exact summary block formatting.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.github/workflows/ci.yml` — the single workflow under change (cache blocks, the 7
  guard jobs, `ci-gate` aggregator at ~L1204).
- `.tool-versions` — single Elixir/OTP pin (`erlang 28.5`, `elixir 1.19.5-otp-28`); the
  version source the cache key must bind to.
- `MAINTAINING.md` — CI/Actions runbook; home for the cache-bust doc (D-10) and the
  required-check reconciliation (D-15). Note its current required-check list is stale.
- `scripts/ci/milestone-verification-gate.sh`, `installer-milestone-audit.sh`,
  `getting-started-contract.sh`, `phase34-uat-contracts.sh`, `snapshot-canary-guard.sh`,
  `quality-ledger-monotonic.sh` — the 6 guard scripts folded into `fast_checks`.
- `.planning/phases/193-*/193-BASELINE.md` — the Phase 193 before-state baseline
  (cache + per-job overhead measurements to compare against).
- `.planning/phases/193-*/193-03-PLAN.md` + `193-03-SUMMARY.md` — the `$GITHUB_STEP_SUMMARY`
  observability seam (BASE-03) that cache hit-rate extends (D-09).
- Live ruleset (runtime, not a file): `gh api repos/szTheory/sigra/rulesets/14941512` — D-03 ground truth.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **Phase-193 step-summary mechanism** (`ci.yml:197-217`): `if: always()` shell steps that
  append to `$GITHUB_STEP_SUMMARY`; already wired `cache-hit` on 2 lanes (`deps_cache`,
  `example_deps_cache`). Reuse for cache hit-rate (D-09).
- **Existing cache namespaces** (`-library-`, `-library-dep-off-`, `-example-`, `-example-dev-`):
  keep; only add precision (D-04/D-05).
- **Per-PR base-ref fetch pattern** (`ci.yml:1156-1171`, `1187-1202`): `fetch-depth: 0` +
  `git fetch origin <base_ref> --depth=1` — reuse once in `fast_checks` (D-13).

### Established Patterns
- All actions pinned to full SHA (supply-chain discipline) — no new unpinned actions (D-09).
- `mix deps.get` is an explicit always-run step per lane (D-07).
- `release_ref_guard` is intentionally no-checkout/fast to gate the DAG cheaply (D-12).

### Integration Points
- `ci-gate.needs` + its `${{ needs.*.result }}` aggregation loop must be rewired in lockstep
  with the fold (D-14).
- The 5 ruleset-protected lane `name:` strings are the hard boundary — touch nothing that
  renames them (D-01/D-02).
- A future Dialyzer/PLT addition must get its own cache key, never merged into the deps key (D-06).
</code_context>

<specifics>
## Specific Ideas

- Buster handle is a trailing `-v1` segment in the key; bumping it (with a one-line
  MAINTAINING.md note) is the documented bust mechanism (D-04/D-10).
- Prefer setup-beam resolved version outputs over hashing `.tool-versions` where the action
  exposes them, for a cleaner key (D-04).
</specifics>

<deferred>
## Deferred Ideas

- Splitting `deps` into its own cache separate from `_build` for higher hit-rate — a
  perf optimization, not a correctness need; revisit under Phase 195 if measurement justifies.
- Introducing a Dialyzer/PLT lane (would need its own PLT cache per D-06) — not in this milestone.
- Larger runners for long poles — Phase 195 (CACHE-03).

### Reviewed Todos (not folded)
None — no pending todos matched this phase's scope.
</deferred>
