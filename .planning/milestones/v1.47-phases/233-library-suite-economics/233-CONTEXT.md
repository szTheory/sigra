# Phase 233: Library Suite Economics - Context

**Gathered:** 2026-07-31 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Keep the library suite from becoming the post-Playwright critical-path pole: restore within-shard
ExUnit parallelism without losing slow-test visibility, reduce the duration gap between the two
library shards, and move the subprocess-heavy Phoenix scaffold/install tests out of those shards
without losing pull-request coverage.

Owns **TEST-01, TEST-02, and TEST-03**. Proof is a before/after per-job duration comparison plus
observed test/spec execution on a real `pull_request`. Deleting tests is out of scope. A test may
move only when its receiving lane is named, observed running, and connected to a merge-blocking
verdict. The byte-identical required-check name `Library tests` remains unchanged.
</domain>

<decisions>
## Implementation Decisions

### Parallelism and slow-test evidence

- **D-01:** Remove `--slowest` from the library shard's test invocation. It forces `--trace` and
  `--max-cases 1`, so retaining it would leave each shard serial and fail TEST-01.
- **D-02:** Preserve slow-test visibility with a committed, non-serial timing artifact produced
  from the parallel run. Do not regain timing visibility by serially re-running the suite or by
  adding another full test pass.

### Shard balance

- **D-03:** Retain the existing two-shard topology and the thin, byte-identical `Library tests`
  aggregator. Do not add shards before proving that extraction plus rebalancing is insufficient.
- **D-04:** After extracting the scaffold-heavy set, rebalance the remaining library files using
  measured test cost rather than file count alone. Record both shard durations before and after;
  the acceptance signal is a measurably smaller gap, not merely a changed partition map.

### Subprocess-heavy test placement

- **D-05:** Apply one unified `:scaffold` classification to the Phoenix-scaffolding/subprocess
  test modules identified by the canonical audit, exclude that class from the ordinary library
  shards, and keep the fast `template_render_test.exs` in the ordinary suite.
- **D-06:** Run the extracted class in a dedicated receiving lane that executes on every pull
  request, including unrelated and docs-only PRs. The path-detected `install_golden_contract` job
  cannot be its sole receiver because that job legitimately skips many PRs.
- **D-07 (hard-fail boundary):** Feed the receiving lane's result into the existing required-name
  `library_tests` aggregator, alongside the ordinary shard result. A scaffold, upgrade, golden, or
  idempotency failure must make the required `Library tests` context red; `ci-gate` alone is not a
  merge-blocking substitute.

### PR coverage and evidence

- **D-08:** Close the phase on a real `pull_request` run that names observed execution of
  `upgrade_test` and golden/idempotency coverage after extraction, with retry-free green results.
  Also capture before/after durations for both ordinary shards and the extracted receiving lane.
  YAML inspection, a skipped lane, or nightly-only `upgrade_smoke` is not sufficient proof.

### The agent's Discretion

- Exact formatter, telemetry hook, or artifact schema used for non-serial slow-test reporting,
  provided it derives from the parallel run and is deterministic in CI.
- Exact cost-balancing mechanism: a committed measured file manifest or deterministic automatic
  assignment are both acceptable if the before/after run proves a smaller shard gap.
- Exact receiving-lane job id and display name; only the terminal required context is locked to
  `Library tests`.
- Whether golden/idempotency tests remain duplicated in `install_golden_contract` on matching
  changes or ownership is consolidated, provided the drift detector and all existing assertions
  remain hard-failing and PR-observed.
- Plan/wave decomposition and evidence helper names, following existing machine-readable CI
  receipt patterns.

### Folded Todos

None. The user reviewed the automated phase matcher and chose to fold no backlog items into the
fixed TEST-01/02/03 boundary.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope, requirements, and prior contracts

- `.planning/ROADMAP.md` — Phase 233 goal, success criteria, coverage hazard, and proof discipline.
- `.planning/REQUIREMENTS.md` — TEST-01, TEST-02, and TEST-03.
- `.planning/METHODOLOGY.md` — decisive-defaulting, escalation, and proof-truth lenses.
- `.planning/research/SEED-005-CICD-AUDIT-2026-06-20.md` — canonical P1-5 scaffold extraction,
  subprocess timing evidence, and PR-routing hazard.
- `.planning/phases/230-tier-1-critical-path-reclamation/230-CONTEXT.md` — required-check name and
  docs-only execution constraints.
- `.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md` — observed 470s/278s
  library-shard imbalance on a full docs-only PR run.
- `.planning/phases/231-gate-honesty-nightly-revival/231-CONTEXT.md` — honest-skip contract and
  nightly-only `upgrade_smoke` posture.
- `.planning/phases/232-playwright-economics-authenticate-once-then-shard/232-CONTEXT.md` — locked
  Playwright topology and the handoff that makes library economics the next pole.

### Implementation and coverage seams

- `.github/workflows/ci.yml` — library shard worker, required-name aggregator,
  `install_golden_contract`, `upgrade_smoke`, and `ci-gate` topology.
- `scripts/ci/honest-skip-verdict.sh` — manifest-driven skipped-lane legitimacy contract.
- `test/support/install_fixture.ex` — shared `phx.new`, dependency, compile, migration, and
  installer subprocess machinery.
- `test/upgrade_test.exs` — heavy upgrade coverage that currently reaches PRs through library
  shards while `upgrade_smoke` is non-PR.
- `test/sigra/install/generator_passkeys_opt_out_test.exs`
- `test/sigra/install/features/passkeys_js_test.exs`
- `test/sigra/install/golden_diff_test.exs`
- `test/sigra/install/idempotency_test.exs`
- `test/sigra/install/vault_promotion_test.exs`
- `test/sigra/install/template_render_test.exs` — fast install-tagged test explicitly excluded
  from the heavy scaffold classification.
- `MAINTAINING.md` — live required-check and CI operating contract.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- `.github/workflows/ci.yml` already has two isolated Postgres-backed matrix workers plus a thin
  `library_tests` aggregator that preserves the required `Library tests` context.
- The shard job already tees its test log and writes `$GITHUB_STEP_SUMMARY`, providing the natural
  publication point for a replacement timing artifact.
- `Sigra.Test.InstallFixture` centralizes the expensive scaffold lifecycle, giving the extracted
  class a coherent implementation seam.
- Existing CI evidence files and honest-skip scripts provide machine-readable receipt and
  negative-control patterns.

### Established Patterns

- `MIX_TEST_PARTITION` currently assigns test files round-robin across two workers; observed
  durations show file count is not a sufficient cost proxy.
- `mix test --partitions 2 --slowest 10` preserves timing output but serializes each worker; the
  phase must separate observability from execution scheduling.
- `install_golden_contract` path-detects relevant changes, while `upgrade_smoke` deliberately does
  not run on PRs. Neither can independently prove universal PR coverage for extracted tests.
- The required context is produced by a thin aggregator, not directly by the matrix worker. That
  is the correct seam for adding the receiving lane to the merge-blocking verdict.

### Integration Points

- `.github/workflows/ci.yml` — alter the shard command, add the scaffold receiver, rebalance files,
  and extend the required-name aggregator.
- Heavy scaffold test modules — add the unified classification without changing assertions.
- Slow-test reporting helper/formatter — generate deterministic timing evidence from parallel
  execution.
- Phase evidence artifacts — record before/after job durations and observed PR test names/counts.
</code_context>

<specifics>
## Specific Ideas

- “Slow-test visibility” and “parallel execution” must appear together in the same observed job;
  trading one for the other does not satisfy TEST-01.
- Preserve exactly two ordinary shards unless measurements prove a stronger need.
- Treat `upgrade_test` and golden/idempotency execution on PR as a hard-fail boundary, not a
  documentation note or nightly receipt.
- Keep `Library tests` byte-identical and merge-blocking throughout the topology change.
</specifics>

<deferred>
## Deferred Ideas

- All 29 automated todo matches remain in their existing backlog or phase ownership. The matches
  were predominantly Playwright, release, auth UI, installer-feature, and unrelated CI items; the
  user selected “Fold none.”
- Expanding golden coverage to generated policy files (W6) is a separate coverage capability, not
  part of preserving the existing Phase 233 contract.
</deferred>

---

*Phase: 233-library-suite-economics*
*Context gathered: 2026-07-31*
