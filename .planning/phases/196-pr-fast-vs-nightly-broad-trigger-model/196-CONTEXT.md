# Phase 196: PR-Fast vs Nightly-Broad Trigger Model - Context

**Gathered:** 2026-06-20 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Reduce every-PR CI cost to a fast representative gate while exhaustive / low-probability
coverage still runs (on a `schedule:` cron + main-push + release-dispatch), with the
required-check surface and child-check names held stable, and **no correctness-critical test
stranded on nightly only**. Requirements **CRIT-02** and **CRIT-03**.

The ONLY artifacts this phase changes: `.github/workflows/ci.yml`, CI docs
(`MAINTAINING.md`, `guides/recipes/local-development.md`), and the
`phase_51_install_golden_ci_contract_test.exs` contract anchor (todo fold).

**Out of scope (boundary notes):**
- The `example_playwright_smoke` `continue-on-error: true` "Run design gallery boards" step
  (SEED-006) is **Phase 197's** re-gate, not this phase. Do not move or re-gate it here.
- No Playwright sharding / boot-sharing (Phase 197).
- No new test coverage, no runner-size changes (Phase 195 D-21 stands: `ubuntu-latest` only).
</domain>

<decisions>
## Implementation Decisions

### Trigger topology (CRIT-02 mechanism)

- **D-01:** Keep **one `ci.yml`** (do NOT split into a separate `nightly.yml`). Add a
  `schedule:` cron trigger alongside the existing `workflow_dispatch` / `push:[main]` /
  `pull_request:[main]` triggers, mirroring the live in-repo precedent
  `.github/workflows/playwright-github-pages.yml:16-18` (`cron: '45 6 * * *'`). A separate
  workflow file would create a second required-check namespace and branch-protection churn for
  zero benefit — directly contrary to CRIT-03. (Planner picks the exact cron minute; avoid
  colliding with the existing `45 6` slot.)

- **D-02:** Gate every "broad" job with **job-level `if: github.event_name != 'pull_request'`**
  (runs on `schedule` + `push:[main]` + `workflow_dispatch`; skipped on PRs). This is the
  cleanest expression of "does not run on PRs" and is **safe** because every moved job is
  **non-required** (see D-08). Job-level `if:` would be the pending-check trap **only** for a
  *required* job — none of the moved jobs is required.

- **D-03:** The gate condition is `!= 'pull_request'` (NOT `== 'schedule'`). CRIT-02 says
  "`schedule:`/main": main pushes must still run the broad set (post-merge safety net) and the
  `workflow_dispatch`-from-`v*`-tag release-evidence path (`ci.yml:28-42`, `release_ref_guard`)
  must retain full coverage. `== 'schedule'` alone would strand main + dispatch coverage.

- **D-04:** Use **job-level `if:`** for whole-job removal, NOT step-level `event_name` gating.
  Step-level gating (the existing `fast_checks` / `install_golden_contract` change-detector
  idiom, `ci.yml:73-83,120-134`) is the right tool only when the JOB must keep reporting because
  it is required or feeds a required aggregator and we want to skip just the heavy *step*. For a
  pure non-required job that should not run at all on PRs, job-level `if:` is correct.

### Which jobs move off the PR path (CRIT-02 inventory)

- **D-05:** **MOVE to non-PR** (`schedule`/main/dispatch only):
  - `install_matrix` (`ci.yml:604`) — ×4 flag-combo sweep (`""`, `--no-passkeys`,
    `--no-organizations`, `--no-organizations --no-passkeys`); exhaustive/combinatorial.
  - `upgrade_smoke` (`ci.yml:502`) — published-series→local-candidate upgrade; release-boundary,
    not per-feature-PR.
  - `passkeys_manual_fallback_smoke` (`ci.yml:554`) — narrow Phase-20 non-standard-`app.js`
    manual-injection-refusal edge; low change frequency.
  - `passkeys_opt_out_smoke` (`ci.yml:733`) — `--no-passkeys` / `--no-organizations --no-passkeys`
    opt-out combos; same opt-out surface as `install_matrix`.
  - `generated_admin_playwright_smoke` (`ci.yml:1156`, ~60m, the single most expensive job) —
    full move (see D-07).

- **D-06:** **KEEP on every PR** (do NOT move):
  - The **5 ruleset-protected required lanes** (D-08).
  - `install_golden_contract` (`ci.yml:102`) — byte-exact generated-output golden diff
    (correctness contract); already PR-conditional via its own change-detector and feeds
    `ci-gate`. Stays; only its heavy steps skip when no installer files changed.
  - `library_tests_dep_off` (`ci.yml:298`) — compile + boot with `:threadline` absent
    correctness guard + hosts `mix docs --warnings-as-errors`; cheap relative to the matrix
    jobs, correctness-critical.

### Never-strand guarantee (CRIT-02 "never strand a correctness-critical test on nightly")

- **D-07 (USER-CONFIRMED):** `generated_admin_playwright_smoke` is **fully moved** to nightly
  (NOT a thin PR slice). Admin *behavior* is proxied on PR by `example_playwright_smoke`'s admin
  specs (`ci.yml:959-993`). The residual gap — generated-host **template parity** (installer-
  emitted shell vs library admin) becomes nightly-only — is **accepted** because it is
  backstopped by the **DIST-06 generated-host acceptance-smoke automation**
  (`scripts/ci/admin-acceptance-smoke.sh`, RUN_PARITY). This residual MUST be recorded
  explicitly in MAINTAINING.md and VERIFICATION (honest-truth requirement), not silently moved.

- **D-08:** Per-moved-job never-strand rationale (record in VERIFICATION):
  - `install_matrix` → default `""` leg proxied on PR by `install_smoke` (bare default
    `mix sigra.install`, `scripts/ci/install-smoke.sh:61`). Matrix adds only flag-combo breadth.
  - `passkeys_*` → enabled passkey happy-path covered on PR by `example_playwright_smoke`
    (`passkeys-hooks.spec.ts`, `passkey-login.spec.ts`, `ci.yml:1047-1053`) + library shards;
    only opt-out / manual-fallback edges move.
  - `upgrade_smoke` → no per-PR behavioral proxy, but it is release-boundary coverage that still
    runs on `push:[main]` + release-dispatch; acceptable to gate off PRs.
  - `generated_admin_playwright_smoke` → see D-07.

### ci-gate aggregation under conditional jobs (CRIT-03)

- **D-09:** Change the `ci-gate` per-lane check from `[[ "$result" != "success" ]]`
  (`ci.yml:1317`) to **fail only on `failure`/`cancelled`** — i.e.
  `[[ "$result" != "success" && "$result" != "skipped" ]]`. A `needs` job skipped by its own
  job-level `if:` propagates `result == 'skipped'`; `ci-gate` already runs `if: always()`
  (`ci.yml:1289`) so it still executes. Without this change `ci-gate` would go red on every PR.
  A real `failure` on a still-PR-running lane stays red (no weakening of the PR gate).

- **D-10:** Only **`upgrade_smoke`** and **`generated_admin_playwright_smoke`** are both moved
  *and* currently in `ci-gate.needs` (`ci.yml:1284,1287`), so only those two yield `skipped` on
  PRs. `install_matrix` / `passkeys_*` are NOT in `ci-gate.needs` today (`ci.yml:1279-1288`) → no
  further aggregator wiring change for them. Verify this `needs` list at execution; do not add
  the moved jobs to `ci-gate.needs` (the skip-tolerant loop handles the two that are already
  there).

### Required-check stability + doc reconciliation (CRIT-03)

- **D-11:** The **5 ruleset-protected lane `name:` strings stay byte-identical AND unconditional
  on PR** (NO `event_name` gating, NO rename): `Library tests`, `Example unit smoke (ExUnit +
  ConnTest)`, `Install smoke (fresh phx.new + sigra.install)`, `Example HTTP smoke (boot + curl
  critical routes)`, `Example Playwright smoke (full lifecycle)`. None is in the move list, so
  required-check stability is structurally preserved.

- **D-12 (MANDATORY at execution):** Re-read the live ruleset
  (`gh api repos/szTheory/sigra/rulesets/14941512`) and treat it — not ROADMAP/MAINTAINING — as
  ground truth for required-check names (standing 194-D03 mandate). If a 6th/renamed context has
  appeared, stop and reconcile before touching any job name.

- **D-13:** Reconcile the **stale premise** in docs. The ROADMAP/CRIT-03 phrase "single stable
  required check (`ci-gate` aggregator)" is outdated: the enforced required checks are the **5
  lane names**, and `ci-gate` is an **internal aggregator, NOT a required check** (194-D01/D15).
  Update MAINTAINING.md to the reconciled reality; record the correction in VERIFICATION rather
  than perpetuating the stale framing.

### Forced-failure verification probe (zero-human-UAT)

- **D-14:** Add a forced-failure probe as a **`workflow_dispatch` input** (e.g.
  `inputs.force_fail_probe`) that, when truthy, runs an `exit 1` step **inside a nightly-gated
  job** — proving the nightly lane still fails red and propagates to its own check. Document the
  one-line `gh workflow run "CI" -f force_fail_probe=true` invocation in MAINTAINING.md. Reuses
  the existing `workflow_dispatch` trigger; no cron wait, no separate workflow, no synthetic code
  regression. The probe step MUST live in a moved/non-PR-gated job (not a PR-path job) so it
  exercises the nightly trigger path specifically.

### Folded Todos

- **D-15 (FOLD — `2026-06-20-phase51-installer-milestone-audit-ci-contract-stale.md`):**
  Re-anchor `test/sigra/planning/phase_51_install_golden_ci_contract_test.exs` (~line 28) from
  the removed `installer_milestone_audit:` **job** key (Phase 194 folded it into `fast_checks`)
  to the surviving `fast_checks` **step** (assert the workflow contains the `Installer milestone
  audit` step / `scripts/ci/installer-milestone-audit.sh` run). This test is **already red on
  `main`** and MUST be green for this phase to merge. This phase is the natural home — it is the
  next phase to edit `ci.yml`.

- **D-16:** Also re-audit `test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs` —
  it slices the workflow by splitting on the `library_tests:` boundary string
  (`phase_58_...test.exs:28-30`). The D-02 job-level-`if:` approach does NOT reorder
  `library_tests*`, so it should stay green, but **verify, do not assume** after the ci.yml edit.

### Claude's Discretion

- Exact cron minute/hour for the new `schedule:` (avoid the `45 6` collision with
  `playwright-github-pages.yml`); exact `if:` expression form; the `force_fail_probe` input name
  and which nightly job hosts the probe step; precise wording of the skip-tolerant `ci-gate` loop.
- Where the reconciled required-check docs + nightly-cadence note + probe runbook land within
  MAINTAINING.md (and whether the local-development guide needs a one-line nightly mention).
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

- `.github/workflows/ci.yml` — the single file restructured this phase (jobs, `ci-gate`,
  triggers).
- `.github/workflows/playwright-github-pages.yml` — live `schedule: cron` precedent (lines 16-18).
- `.planning/phases/194-caching-correctness-micro-job-consolidation/194-CONTEXT.md` — required-
  check ground truth (D-01/D-02/D-03/D-15: the 5 names, ruleset 14941512, `ci-gate` not required,
  re-read-ruleset mandate, `fast_checks` fold of the 6 guards).
- `.planning/phases/195-test-suite-performance-partition-async-dep-off-slim/195-CONTEXT.md` —
  `library_tests` shard/aggregator shape (D-01/D-02) and `ubuntu-latest`-only runner policy (D-21).
- `test/sigra/planning/phase_51_install_golden_ci_contract_test.exs` — contract test to re-anchor
  (D-15).
- `test/sigra/planning/phase_58_oauth_oa01_ci_contract_test.exs` — workflow-slicing contract to
  re-verify (D-16).
- `MAINTAINING.md` — required-check list + cache runbook + new nightly-cadence/probe docs land here.
- `.planning/ROADMAP.md` (Phase 196 block) + `.planning/REQUIREMENTS.md` (CRIT-02, CRIT-03).
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`schedule: cron` precedent**: `.github/workflows/playwright-github-pages.yml:16-18` already
  runs a nightly cron in this repo — copy its shape.
- **`workflow_dispatch` trigger** already present in `ci.yml:6` — reuse for the D-14 forced-fail
  probe input (no new trigger needed).
- **`if: always()` aggregator** already on `ci-gate` (`ci.yml:1289`) — only the result loop
  (`ci.yml:1317`) needs the skip-tolerant tweak (D-09).
- **Event-name / change-detector idiom** already in `fast_checks` (`ci.yml:60-83`) and
  `install_golden_contract` (`ci.yml:120-134`) — the established step-level gating pattern;
  reused conceptually for D-04's contrast (we use JOB-level for whole-job removal).

### Established Patterns
- Required-check surface = **5 lane `name:` strings** in ruleset 14941512; `ci-gate` is an
  internal aggregator. Never rename/gate the 5; always re-read the ruleset at execution (194-D03).
- `library_tests` is a thin aggregator over `library_tests_shard` (Phase 195) holding the
  byte-identical required name — do not disturb its ordering (protects the Phase58 slicer, D-16).
- Each heavy lane carries its own `services.postgres` + per-job `$GITHUB_STEP_SUMMARY`
  observability (Phases 193-195) — preserved unchanged; moved jobs keep their bodies, gain only
  the `if:` gate.

### Integration Points
- `ci-gate.needs` (`ci.yml:1279-1288`) — the two moved-and-aggregated jobs (`upgrade_smoke`,
  `generated_admin_playwright_smoke`) flow through D-09's skip-tolerant loop.
- `test/sigra/planning/phase_51_*` and `phase_58_*` contract tests assert against `ci.yml`
  structure — they are part of `mix test` and gate this phase's own merge (D-15, D-16).
- DIST-06 acceptance-smoke automation (`scripts/ci/admin-acceptance-smoke.sh`) is the backstop
  that makes D-07's nightly-only generated-host parity acceptable.
</code_context>

<specifics>
## Specific Ideas

- User-confirmed: **full move** of `generated_admin_playwright_smoke` to nightly with a
  documented residual (the largest single PR wall-clock saving), rather than a thin PR slice or
  keeping it fully on PR.
</specifics>

<deferred>
## Deferred Ideas

- Re-gating the `continue-on-error` admin-design gallery (SEED-006) → **Phase 197**.
- Playwright sharding / boot-sharing / deterministic readiness → **Phase 197**.
- `mix ci` local-CI-equivalent + milestone acceptance measurement → **Phase 198**.

### Reviewed Todos (not folded)
- `2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md` (score 0.9) — admin-design
  pagination test data-dependency; design-gallery/Playwright domain → **Phase 197**, not this
  trigger-model phase.
- `2026-06-18-token-reference-completeness-ci-guard.md` (score 0.9) — net-new optional CI guard
  (admin-token-reference completeness); adding a new guard is out of CRIT-02/CRIT-03 scope.
- `2026-06-17-page04-branding-explicit-scoring.md` (score 0.6) — admin-UI quality-ledger scoring;
  unrelated to CI trigger model.
</deferred>
