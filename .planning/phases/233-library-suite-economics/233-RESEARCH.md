# Phase 233: Library Suite Economics - Research

**Researched:** 2026-07-31
**Domain:** ExUnit parallel test execution and GitHub Actions merge-gate topology
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

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

### the agent's Discretion

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

### Deferred Ideas (OUT OF SCOPE)

- All 29 automated todo matches remain in their existing backlog or phase ownership. The matches
  were predominantly Playwright, release, auth UI, installer-feature, and unrelated CI items; the
  user selected “Fold none.”
- Expanding golden coverage to generated policy files (W6) is a separate coverage capability, not
  part of preserving the existing Phase 233 contract.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TEST-01 | Slow-test visibility no longer forces the library suite to run serially. | Use an additional ExUnit formatter in the same ordinary run, remove `--slowest`, and emit deterministic JSON + summary. |
| TEST-02 | The two library shards finish within a comparable time of each other rather than one idling while the other works. | Replace round-robin assignment with a committed cost-balanced file manifest and compare real PR job durations. |
| TEST-03 | The subprocess-heavy install tests no longer dominate library shard wall-clock, whether by sharing fixture setup or by moving to a non-PR lane with recorded justification. | Apply one `:scaffold` module tag, exclude it from both ordinary shards, and run it in an unconditional PR receiving lane aggregated into `Library tests`. |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM system, use Rail Accent assets, support Light/Dark/System, and keep admin Playwright tests deterministic when admin UI work is in scope. [VERIFIED: AGENTS.md]
- Replace human/UAT evidence with deterministic tests, browser automation, CI polling, and committed machine-readable evidence for authorized work. [VERIFIED: AGENTS.md]
- Retry a transient automation failure once; diagnose and repair deterministic failures; never mark missing evidence as passed. [VERIFIED: AGENTS.md]

## Summary

The phase needs no new dependency. The correct implementation is an in-repo ExUnit timing formatter running beside `ExUnit.CLIFormatter`, a two-leg ordinary matrix that no longer passes `--slowest`, and an unconditional PR scaffold lane. ExUnit formatters receive each completed test and its microsecond duration, so the formatter can produce a sorted, deterministic JSON receipt from the very same parallel run; `--slowest` cannot meet that requirement because it automatically enables `--trace`, which sets `--max-cases 1`. [CITED: https://hexdocs.pm/ex_unit/ExUnit.Formatter.html] [CITED: https://hexdocs.pm/mix/Mix.Tasks.Test.html]

The existing `library_tests_shard` already supplies isolated Postgres services, and the thin `library_tests` job is the byte-identical `Library tests` required context. Extend that aggregator to require both the matrix result and the new scaffold receiver, using `if: always()` so it produces a decisive red result even if either dependency fails. GitHub documents this `needs`/`always()` pattern for downstream aggregation after failed or skipped dependencies. [VERIFIED: .github/workflows/ci.yml] [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs]

**Primary recommendation:** Add a project-local `Sigra.CI.ExUnitTimingFormatter`, move the six observed `InstallFixture`-based modules into `:scaffold`, use a committed cost-balanced manifest for the remaining two partitions, and make a PR-always `library_tests_scaffold`-style receiver a hard dependency of the unchanged `Library tests` context. [VERIFIED: test/** and .github/workflows/ci.yml]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Run ordinary tests in parallel and collect per-test elapsed time | CI worker / test runtime | Repository test-support code | ExUnit scheduling and formatter events occur in each worker process. [CITED: https://hexdocs.pm/ex_unit/ExUnit.Formatter.html] |
| Keep ordinary shard costs comparable | CI workflow configuration | Committed partition manifest | The matrix chooses a worker while the manifest determines that worker's measured file set. [VERIFIED: .github/workflows/ci.yml] |
| Exercise expensive scaffold contracts on every PR | Dedicated CI worker | `InstallFixture` and tagged test modules | `phx.new` and generated-host subprocess lifecycle are test-runtime responsibilities, not a path filter. [VERIFIED: test/support/install_fixture.ex and .github/workflows/ci.yml] |
| Enforce merge-blocking result | GitHub Actions aggregator | Branch-protection required context | The named non-matrix aggregator is the stable required-check producer. [VERIFIED: .github/workflows/ci.yml]
| Preserve before/after proof | Committed planning evidence | GitHub Actions job data/artifact | Job duration is captured from a real run and the timing receipt remains machine-readable. [VERIFIED: scripts/ci/ci-run-metrics.sh] [CITED: https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Elixir ExUnit / Mix test | Elixir 1.19.5 installed locally | Parallel test execution, tags, process partitioning, formatter lifecycle | Already owns the suite; `--formatter`, `--exclude`, `--only`, and `--partitions` cover this phase without a dependency. [VERIFIED: `mix --version`; CITED: https://hexdocs.pm/mix/Mix.Tasks.Test.html] |
| GitHub Actions | repository CI service | Matrix workers, result aggregation, job summaries, PR evidence | Existing `ci.yml` owns the required check and services topology. [VERIFIED: .github/workflows/ci.yml] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `actions/upload-artifact` | pinned SHA for v7.0.1 in this repository | Retain timing JSON/log evidence from a run | Upload only the small per-shard timing receipts if the planner needs durable downloadable evidence beyond the job summary. [VERIFIED: .github/workflows/ci.yml] [CITED: https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts] |
| `scripts/ci/ci-run-metrics.sh` | in repository | Render run-level duration comparisons from `gh run view --json jobs` | Use for the before/after ledger; its hermetic self-test is already wired into `fast_checks`. [VERIFIED: scripts/ci/ci-run-metrics.sh and .github/workflows/ci.yml] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| In-process ExUnit timing formatter | A second serial `mix test --slowest` pass | Rejected: it violates D-01/D-02 and duplicates suite cost. [CITED: https://hexdocs.pm/mix/Mix.Tasks.Test.html] |
| Unconditional scaffold receiver | `install_golden_contract` path-detected job | Rejected: that job reports `run=false` on unrelated PRs, so it cannot be the universal receiver for `upgrade_test` and scaffold tests. [VERIFIED: .github/workflows/ci.yml] |
| Cost-based manifest | Existing ExUnit round-robin files | Rejected: Mix sorts test files and assigns partitions round-robin, while observed shard durations have been materially imbalanced. [CITED: https://hexdocs.pm/mix/Mix.Tasks.Test.html] [VERIFIED: 230-EVIDENCE.md] |

**Installation:** None — do not install a package. [VERIFIED: phase scope]

## Package Legitimacy Audit

No external package is proposed or installed in this phase; the package legitimacy gate is not applicable. [VERIFIED: Standard Stack]

## Architecture Patterns

### System Architecture Diagram

```text
pull_request (including docs-only)
        |
        +--> library_tests_shard [partition 1] --exclude scaffold
        |      |--> ExUnit CLI output
        |      `--> timing formatter --> sorted timing JSON + job summary
        |
        +--> library_tests_shard [partition 2] --exclude scaffold
        |      |--> ExUnit CLI output
        |      `--> timing formatter --> sorted timing JSON + job summary
        |
        `--> scaffold receiver --only scaffold
               |--> upgrade_test + golden + idempotency + other scaffold modules
               `--> hard failure on any contract failure

all three results --> library_tests (name: "Library tests", if: always())
                              |
                              +--> success only when shards AND receiver succeed
                              `--> required merge context / ci-gate input
```

### Recommended Project Structure

```text
test/support/
├── ci/                           # timing formatter and its focused tests
│   └── ex_unit_timing_formatter.ex
├── install_fixture.ex             # existing expensive generated-app lifecycle
└── library_partition_manifest.*   # committed measured assignment (exact format at discretion)
scripts/ci/
├── library-timing-receipt.*       # deterministic receipt validation if needed
└── ci-run-metrics.sh              # existing before/after job-duration collector
.planning/phases/233-library-suite-economics/
└── 233-EVIDENCE.md                # real-PR before/after and execution observations
```

### Pattern 1: Additive parallel-run formatter
**What:** Configure the normal CLI formatter plus `Sigra.CI.ExUnitTimingFormatter`; on `{:test_finished, test}`, retain `{file, module, test name, time_us, state}`; on `{:suite_finished, _}`, write one sorted JSON document to an environment-provided output path. [CITED: https://hexdocs.pm/ex_unit/ExUnit.Formatter.html] [CITED: https://hexdocs.pm/ex_unit/ExUnit.Test.html]

**When to use:** Every ordinary shard and the scaffold receiver when a receipt is needed; do not use `--slowest`, `--slowest-modules`, or trace mode. [CITED: https://hexdocs.pm/mix/Mix.Tasks.Test.html]

**Example:**
```elixir
# Source: https://hexdocs.pm/ex_unit/ExUnit.Formatter.html
# The implementation must keep ExUnit.CLIFormatter configured too.
def handle_cast({:test_finished, %ExUnit.Test{} = test}, state) do
  entry = %{file: test.tags.file, module: inspect(test.module), name: Atom.to_string(test.name),
            time_us: test.time, state: inspect(test.state)}
  {:noreply, [entry | state]}
end
```

### Pattern 2: Explicit, measured file manifests
**What:** Store each ordinary test file exactly once in one of two lists calculated from a prior parallel timing receipt; invoke `mix test` with that list plus `--exclude scaffold`, rather than relying on file-count round robin. [VERIFIED: .github/workflows/ci.yml] [CITED: https://hexdocs.pm/mix/Mix.Tasks.Test.html]

**When to use:** Recompute the manifest only from an observed receipt after source/test topology changes; preserve both lists in review so an accidental omission or duplication is mechanically testable. [ASSUMED]

### Pattern 3: Name-preserving, fail-closed aggregation
**What:** Keep job id `library_tests` and display name exactly `Library tests`; give it `needs: [library_tests_shard, library_tests_scaffold]` and `if: always()`, then fail unless both results are `success`. [VERIFIED: .github/workflows/ci.yml] [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs]

### Anti-Patterns to Avoid

- **Re-running the entire suite for timings:** adds cost and retains serial execution. [CITED: https://hexdocs.pm/mix/Mix.Tasks.Test.html]
- **Making the scaffold lane path-gated or docs-only-gated:** lets unrelated/docs PRs skip coverage prohibited by D-06/D-08. [VERIFIED: 233-CONTEXT.md and .github/workflows/ci.yml]
- **Adding the receiver only to `ci-gate`:** `ci-gate` is not the locked required context; the receiver must feed `library_tests`. [VERIFIED: 233-CONTEXT.md and .github/workflows/ci.yml]
- **Changing the required display name or making it a matrix name:** would orphan the byte-stable `Library tests` required check. [VERIFIED: .github/workflows/ci.yml]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Parallel test scheduling | Shell-level fan-out/retry orchestration | ExUnit normal scheduler plus its two existing OS partitions | ExUnit already runs async cases across modules and supports process partitioning. [CITED: https://hexdocs.pm/mix/Mix.Tasks.Test.html] |
| Per-test lifecycle timing | A second test invocation or log regex tied to `--slowest` | A small project-local ExUnit formatter | Formatter events expose finished-test timing in the same run. [CITED: https://hexdocs.pm/ex_unit/ExUnit.Formatter.html] [CITED: https://hexdocs.pm/ex_unit/ExUnit.Test.html] |
| Required-check enforcement | A new required name or ci-gate-only proxy | Existing `library_tests` name-preserving aggregator | The workflow already carries the required context through this aggregator. [VERIFIED: .github/workflows/ci.yml] |
| CI duration collection | Ad hoc hand-entered timing prose | Existing `ci-run-metrics.sh` output and a committed evidence ledger | The repository already has a fail-closed, tested run-metrics seam. [VERIFIED: scripts/ci/ci-run-metrics.sh] |

**Key insight:** The only custom code warranted is a narrow ExUnit formatter that serializes events already measured by the test framework; test execution, tag selection, OS partitioning, artifact retention, and GitHub result aggregation already have platform seams. [CITED: https://hexdocs.pm/ex_unit/ExUnit.Formatter.html] [CITED: https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts]

## Common Pitfalls

### Pitfall 1: Accidentally retaining serial execution
**What goes wrong:** The command removes visible `--trace` but leaves `--slowest` or `--slowest-modules`, restoring `--trace` implicitly. [CITED: https://hexdocs.pm/mix/Mix.Tasks.Test.html]

**How to avoid:** Add a focused workflow-contract test that rejects all three flags on ordinary shards and proves the timing formatter output was produced by the same command. [ASSUMED]

### Pitfall 2: Lost PR coverage behind a green gate
**What goes wrong:** `install_golden_contract` skips on unrelated PRs and `upgrade_smoke` is non-PR, so extracting `upgrade_test` from ordinary shards without an unconditional receiver creates a silent coverage hole. [VERIFIED: .github/workflows/ci.yml and 233-CONTEXT.md]

**How to avoid:** Run the receiver on every PR, including docs-only; assert its `success` result inside the required `library_tests` aggregator. [VERIFIED: 233-CONTEXT.md]

### Pitfall 3: A partition map that is syntactically valid but not balanced
**What goes wrong:** Round-robin partitioning is based on sorted file placement, not measured runtime; baseline shard results were 470s and 278s on the full docs-only PR evidence. [VERIFIED: 230-EVIDENCE.md] [CITED: https://hexdocs.pm/mix/Mix.Tasks.Test.html]

**How to avoid:** Store per-file timing data, generate/review a two-list manifest, and make the acceptance comparison use actual job durations, not file counts. [ASSUMED]

### Pitfall 4: Failing aggregator is skipped and never emits the required check
**What goes wrong:** A downstream job normally skips when a `needs` job fails or is skipped. [CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs]

**How to avoid:** Keep `if: always()` and explicitly inspect every needed result, failing any non-`success` value. [VERIFIED: .github/workflows/ci.yml]

### Pitfall 5: Tagging the fast template-render test as scaffold
**What goes wrong:** The phase would unnecessarily remove fast async template parsing from the ordinary suite, contrary to D-05. [VERIFIED: 233-CONTEXT.md and test/sigra/install/template_render_test.exs]

**How to avoid:** Add `:scaffold` only to the six observed `InstallFixture`-based heavy modules; retain `template_render_test.exs` as `:install`/async. [VERIFIED: test/**]

## Code Examples

### Parallel ordinary shard invocation
```bash
# Source: Mix v1.19.5 docs + phase D-01/D-05
MIX_TEST_PARTITION=1 \
  SIGRA_EXUNIT_TIMING_PATH=/tmp/library-shard-1.json \
  mix test --partitions 2 --exclude scaffold ${MANIFEST_FILES}
```
[CITED: https://hexdocs.pm/mix/Mix.Tasks.Test.html]

### Fail-closed required aggregator
```yaml
# Source: GitHub Actions needs/always docs; preserve the exact existing name.
library_tests:
  name: Library tests
  needs: [library_tests_shard, library_tests_scaffold]
  if: always()
  steps:
    - env:
        SHARDS: ${{ needs.library_tests_shard.result }}
        SCAFFOLD: ${{ needs.library_tests_scaffold.result }}
      run: test "$SHARDS" = success && test "$SCAFFOLD" = success
```
[CITED: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `mix test --partitions 2 --slowest 10`, log extraction from slowest block | Ordinary parallel run plus lifecycle-event timing receipt | This phase | Separates observability from scheduling; no second suite run. [VERIFIED: .github/workflows/ci.yml] [CITED: https://hexdocs.pm/ex_unit/ExUnit.Formatter.html] |
| File-count round-robin partitions | Measured two-list partition manifest | This phase | Addresses observed duration skew rather than merely changing a map. [VERIFIED: .github/workflows/ci.yml and 230-EVIDENCE.md] |
| Heavy modules mixed with ordinary library shards | `:scaffold` receiver running on every PR and aggregated by `Library tests` | This phase | Keeps the contracts merge-blocking while removing their serial tail from ordinary shards. [VERIFIED: 233-CONTEXT.md] |

**Deprecated/outdated:** `--slowest` as the library-shard timing mechanism is prohibited by locked D-01 because it implies trace-mode serialization. [VERIFIED: 233-CONTEXT.md] [CITED: https://hexdocs.pm/mix/Mix.Tasks.Test.html]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A committed generated file manifest is simpler and safer here than automatic assignment because it can be mechanically reviewed for one-to-one coverage. | Architecture Patterns / Pitfall 3 | Planner may choose an automatic assignment generator with an equivalently strong coverage guard. |
| A2 | A workflow-contract test can prove absence of serializing flags and receipt wiring without an external CI run. | Common Pitfalls | Live PR evidence remains mandatory; contract test alone cannot establish durations or coverage execution. |

## Open Questions (RESOLVED)

1. **RESOLVED — Should timing receipts be uploaded as artifacts or committed only into the phase evidence ledger?**
   - What we know: GitHub artifacts can retain timing JSON beyond a job, and `$GITHUB_STEP_SUMMARY` already publishes shard information. [CITED: https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts] [VERIFIED: .github/workflows/ci.yml]
   - Recommendation: emit JSON to the summary and attach it as a small artifact during the phase; commit only the analyzed real-PR evidence, not volatile raw timing output. [ASSUMED]
   - Resolution: upload the same-run timing artifacts while committing only the analyzed evidence.

2. **RESOLVED — Which six modules receive `:scaffold`?**
   - What we know: the canonical audit names generator passkeys opt-out, passkeys JS, golden diff, idempotency, vault promotion, and upgrade, while current source inspection finds each uses the expensive install fixture; `template_render_test.exs` is async and does not use it. [VERIFIED: SEED-005-CICD-AUDIT-2026-06-20.md and test/**]
   - Recommendation: make the list explicit in a contract test, treating it as an exact expected set. [ASSUMED]
   - Resolution: enforce the canonical exact six-module scaffold set in the contract while retaining `template_render_test.exs` in ordinary shards.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Mix | ExUnit formatter and test commands | ✓ | 1.19.5 | — [VERIFIED: local probe] |
| Erlang/OTP | ExUnit runtime | ✓ | 28 | — [VERIFIED: local probe] |
| GitHub CLI | Real-PR duration/evidence retrieval | ✓ | 2.95.0 | `gh run view` remains the repository-standard evidence command. [VERIFIED: local probe and scripts/ci/ci-run-metrics.sh] |
| GitHub-hosted Ubuntu Actions runner + PostgreSQL service | CI workers/receiver | ✗ locally | — | Validate through a real `pull_request` run; local ExUnit tests still validate formatter/tag contracts. [VERIFIED: .github/workflows/ci.yml] |

**Missing dependencies with no fallback:** None for planning; the required live PR run is an authorized execution/evidence checkpoint. [VERIFIED: phase D-08]

**Missing dependencies with fallback:** GitHub runner services are unavailable locally; use a pull-request CI run for topology proof. [VERIFIED: .github/workflows/ci.yml]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit (Elixir 1.19.5 locally) [VERIFIED: `mix --version`; test/test_helper.exs] |
| Config file | `test/test_helper.exs` [VERIFIED: test/test_helper.exs] |
| Quick run command | `mix test test/sigra/planning/<phase-233-contract>_test.exs` [ASSUMED] |
| Full suite command | `mix test` (or the two CI partitions plus scaffold receiver for topology proof) [CITED: https://hexdocs.pm/mix/Mix.Tasks.Test.html] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TEST-01 | Ordinary worker command contains no serializing slowest/trace option; timing JSON comes from the same run. | ExUnit workflow-contract | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` | ❌ Wave 0 |
| TEST-02 | Manifest has every ordinary test exactly once, excludes scaffold tests, and assigns both partitions deterministically. | ExUnit unit/contract | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs` | ❌ Wave 0 |
| TEST-03 | Exact scaffold tag set runs in a receiver that the unchanged required aggregator requires. | ExUnit workflow-contract + real PR observation | `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs`; `gh run view <run-id> --json jobs` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** focused ExUnit contract test plus formatter unit test. [ASSUMED]
- **Per wave merge:** `mix test` for source changes and workflow parsing/contract tests. [ASSUMED]
- **Phase gate:** one retry-free real `pull_request` run with named `upgrade_test`, golden/idempotency, both ordinary shard durations, receiver duration, and `Library tests` green. [VERIFIED: 233-CONTEXT.md]

### Wave 0 Gaps
- [ ] `test/support/ci/ex_unit_timing_formatter_test.exs` — deterministic sort/schema/error-path behavior.
- [ ] `test/sigra/planning/phase_233_library_economics_contract_test.exs` — tags, CI command, manifest, receiver, and aggregator edges.
- [ ] A tiny receipt-validation helper/test if raw JSON artifact shape is not otherwise mechanically asserted.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | CI topology does not alter user authentication. [VERIFIED: phase scope] |
| V3 Session Management | no | CI topology does not alter sessions. [VERIFIED: phase scope] |
| V4 Access Control | yes | Preserve the protected `Library tests` context and fail closed on any receiver failure. [VERIFIED: 233-CONTEXT.md] |
| V5 Input Validation | yes | Map GitHub context values through `env:` rather than interpolating event data directly into shell; retain `set -euo pipefail`. [VERIFIED: .github/workflows/ci.yml] |
| V6 Cryptography | no | No cryptographic feature is introduced. [VERIFIED: phase scope] |

### Known Threat Patterns for CI shell/workflow changes

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Crafted GitHub context reaches shell | Tampering | Use `env:` mapping and quoted shell variables; do not inline GitHub expressions in `run:` bodies. [VERIFIED: .github/workflows/ci.yml] |
| Required context becomes green despite skipped coverage | Tampering | `if: always()` aggregator checks exact success for shard and receiver; PR receiver is unconditional. [VERIFIED: 233-CONTEXT.md] |
| Timing artifact overwrites arbitrary path | Tampering | Formatter accepts only a CI-owned, fixed `/tmp` path from workflow configuration and validates an explicit output path in unit tests. [ASSUMED] |

## Sources

### Primary (HIGH confidence)
- `.github/workflows/ci.yml` — current shard command, required aggregator, path-gated golden job, non-PR upgrade smoke, and ci-gate topology. [VERIFIED: codebase]
- `test/support/install_fixture.ex`, `test/upgrade_test.exs`, and listed install tests — current subprocess fixtures and exact candidate extraction set. [VERIFIED: codebase]
- `233-CONTEXT.md`, `230-EVIDENCE.md`, and `SEED-005-CICD-AUDIT-2026-06-20.md` — locked decisions, baseline imbalance, canonical coverage hazard. [VERIFIED: planning artifacts]

### Secondary (MEDIUM confidence)
- [Mix test v1.19.5](https://hexdocs.pm/mix/Mix.Tasks.Test.html) — trace/slowest semantics, tags, process partitioning.
- [ExUnit formatter v1.19.5](https://hexdocs.pm/ex_unit/ExUnit.Formatter.html) and [ExUnit.Test](https://hexdocs.pm/ex_unit/ExUnit.Test.html) — formatter lifecycle and per-test microsecond time.
- [GitHub Actions jobs](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-jobs) and [workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts) — `needs`, `always()`, and retained run outputs.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all core facilities are already installed/configured and documented. [VERIFIED: local probe and codebase]
- Architecture: HIGH — locked decisions map directly to existing CI/test seams. [VERIFIED: 233-CONTEXT.md and .github/workflows/ci.yml]
- Pitfalls: HIGH — serializing flag behavior, path-gated coverage gap, and baseline imbalance are directly evidenced. [VERIFIED: codebase/planning artifacts; CITED: official docs]

**Research date:** 2026-07-31
**Valid until:** 2026-08-30
