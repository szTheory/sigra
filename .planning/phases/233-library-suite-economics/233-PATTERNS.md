# Phase 233: Library Suite Economics - Pattern Map

**Mapped:** 2026-07-31  
**Files analyzed:** 12 planned new/modified files  
**Analogs found:** 11 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.github/workflows/ci.yml` | config | event-driven | `.github/workflows/ci.yml` `library_tests_shard` / `library_tests` | exact seam |
| `test/support/ci/ex_unit_timing_formatter.ex` | utility | event-driven | `test/support/install_fixture.ex` | role-match |
| `test/support/ci/ex_unit_timing_formatter_test.exs` | test | event-driven | `test/sigra/planning/phase_230_ci_timeouts_test.exs` | role-match |
| `test/support/ci/library_test_partitions.exs` (or another committed two-list manifest) | config | transform | `.github/ci-skip-manifest.tsv` plus workflow matrix data | partial |
| `test/sigra/planning/phase_233_library_economics_contract_test.exs` | test | request-response | `test/sigra/planning/phase_232_playwright_economics_test.exs` | exact |
| `test/upgrade_test.exs` | test | file-I/O | `test/sigra/install/golden_diff_test.exs` | exact |
| `test/sigra/install/generator_passkeys_opt_out_test.exs` | test | file-I/O | `test/sigra/install/idempotency_test.exs` | exact |
| `test/sigra/install/features/passkeys_js_test.exs` | test | file-I/O | `test/sigra/install/idempotency_test.exs` | exact |
| `test/sigra/install/golden_diff_test.exs` | test | file-I/O | `test/sigra/install/idempotency_test.exs` | exact |
| `test/sigra/install/idempotency_test.exs` | test | file-I/O | `test/sigra/install/golden_diff_test.exs` | exact |
| `test/sigra/install/vault_promotion_test.exs` | test | file-I/O | `test/sigra/install/generator_passkeys_opt_out_test.exs` | exact |
| `.planning/phases/233-library-suite-economics/233-EVIDENCE.md` | config/evidence | batch | `.planning/phases/230-tier-1-critical-path-reclamation/230-EVIDENCE.md` | exact |

`test/sigra/install/template_render_test.exs` is deliberately **not** a Phase 233 edit: it is `async: true`, does not invoke `InstallFixture`, and must remain in the ordinary suite.

## Pattern Assignments

### `.github/workflows/ci.yml` (config, event-driven)

**Analog:** existing `library_tests_shard` and `library_tests` blocks in the same file.

**Matrix worker / service pattern** ([lines 497-546](../../../../.github/workflows/ci.yml#L497-L546)):

```yaml
library_tests_shard:
  name: Library tests shard ${{ matrix.partition }}
  needs: release_ref_guard
  strategy:
    fail-fast: false
    matrix:
      partition: [1, 2]
  services:
    postgres:
      image: postgres:15
```

Keep the two-leg isolated-Postgres topology and `fail-fast: false`. Replace only the serial invocation: pass explicit measured-manifest files, `--exclude scaffold`, the timing output environment variable, and no `--slowest`, `--slowest-modules`, or `--trace`.

**Fail-closed, name-preserving terminal pattern** ([lines 604-622](../../../../.github/workflows/ci.yml#L604-L622)):

```yaml
library_tests:
  name: Library tests
  needs: [library_tests_shard]
  if: always()
  steps:
    - env:
        SHARDS: ${{ needs.library_tests_shard.result }}
      run: |
        set -euo pipefail
        if [[ "$SHARDS" != "success" ]]; then
          exit 1
        fi
```

Extend `needs` with the unconditional scaffold receiver and map both result expressions through `env:`. The job id and exact `name: Library tests` are protected integration contracts; its explicit shell check must reject every non-`success` result.

**Shell/context safety pattern** ([lines 1648-1673](../../../../.github/workflows/ci.yml#L1648-L1673)):

```yaml
env:
  EVENT_NAME: ${{ github.event_name }}
  LIBRARY_TESTS: ${{ needs.library_tests.result }}
run: |
  set -euo pipefail
  bash scripts/ci/honest-skip-verdict.sh --event "${EVENT_NAME}" \
    --lane library_tests="${LIBRARY_TESTS}"
```

Do not interpolate GitHub expressions inside shell bodies. The new receiver must have no `changes`/docs-only condition, because the existing golden job is intentionally path-gated ([lines 407-492](../../../../.github/workflows/ci.yml#L407-L492)).

### `test/support/ci/ex_unit_timing_formatter.ex` (utility, event-driven)

**Analog:** `test/support/install_fixture.ex` ([lines 1-59](../../../../test/support/install_fixture.ex#L1-L59), [lines 191-240](../../../../test/support/install_fixture.ex#L191-L240)); no in-repository `ExUnit.Formatter` exists.

**Test-support module/error convention**:

```elixir
defmodule Sigra.Test.InstallFixture do
  @spec setup_tmp_app(keyword()) :: {:ok, map()}
  def setup_tmp_app(opts \\ []) do
    {phx_out, phx_status} = System.cmd("mix", ["phx.new", app_name, "--no-assets", "--no-install"], ...)

    if phx_status != 0 do
      raise "mix phx.new failed (status #{phx_status}):\n#{phx_out}"
    end
  end
end
```

Place the formatter under `test/support/` so `mix.exs` compiles it only in test (`elixirc_paths(:test)` is `['lib', 'test/support']`, [lines 55-56](../../../../mix.exs#L55-L56)). Use a narrow `Sigra.CI.*` module, collect only completed-test fields, sort deterministically before one `File.write!`, and fail clearly if the CI-owned timing-path environment variable is absent or invalid. Preserve `ExUnit.CLIFormatter`; this is additive, not a replacement.

**No exact analog found:** the formatter lifecycle itself is new to this repository. Follow RESEARCH.md’s ExUnit formatter event contract, while copying the local support-module naming, specs, and explicit error semantics above.

### `test/support/ci/ex_unit_timing_formatter_test.exs` (test, event-driven)

**Analog:** `test/sigra/planning/phase_230_ci_timeouts_test.exs` ([lines 1-50](../../../../test/sigra/planning/phase_230_ci_timeouts_test.exs#L1-L50)).

```elixir
defmodule Sigra.Planning.Phase230CiTimeoutsTest do
  use ExUnit.Case, async: true

  @ci ".github/workflows/ci.yml"

  defp job_blocks do
    content = File.read!(@ci)
    # Parse only the bounded project text required by the contract.
  end
end
```

Use an isolated temporary output path, synthetic formatter events, then decode/assert the exact sorted receipt. Exercise invalid/missing path handling as a named failure; do not run a second suite to manufacture timings.

### `test/support/ci/library_test_partitions.exs` (config, transform)

**Analog:** the matrix’s explicitly enumerated deterministic values ([lines 504-508](../../../../.github/workflows/ci.yml#L504-L508)) and the repository’s single-source manifest doctrine in [`scripts/ci/honest-skip-verdict.sh`](../../../../scripts/ci/honest-skip-verdict.sh#L70-L126).

```bash
LANES=(
  install_golden_contract
  library_tests
  library_tests_dep_off
  install_smoke
  upgrade_smoke
)

for lane in "${LANES[@]}"; do
  found=false
  # fail if the committed source and workflow declaration diverge
done
```

The exact manifest format is discretionary, but it must be committed and reviewable: two explicit lists, every ordinary test exactly once, every scaffold test excluded, no glob/round-robin fallback. Put its validation in the Phase 233 contract test rather than relying on comments.

### `test/sigra/planning/phase_233_library_economics_contract_test.exs` (test, request-response)

**Analog:** `test/sigra/planning/phase_232_playwright_economics_test.exs` ([lines 1-8](../../../../test/sigra/planning/phase_232_playwright_economics_test.exs#L1-L8), [lines 107-169](../../../../test/sigra/planning/phase_232_playwright_economics_test.exs#L107-L169)).

```elixir
workflow = File.read!(@workflow_path)
shard = job_body(workflow, "example_playwright_shard")
terminal = job_body(workflow, "example_playwright_smoke")

assert shard =~ "fail-fast: false"
refute shard =~ "continue-on-error"
assert terminal =~ "if: always()"
assert terminal =~ "needs.example_playwright_shard.result"

defp job_body(workflow, job_id) do
  pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m
  case Regex.named_captures(pattern, workflow) do
    %{"body" => body} -> body
    _ -> flunk("missing workflow job #{job_id}")
  end
end
```

Read committed source files with `File.read!`, extract bounded job bodies, and assert positive and negative contracts. Cover: exactly two ordinary partitions; no serializing flags; timing formatter/output is wired into the same command; expected six `:scaffold` modules; `template_render` is not scaffold; manifest one-to-one coverage; unconditional receiver; and `library_tests` has `if: always()` plus both results. Do not parse YAML with a new dependency.

### Heavy scaffold module tags (tests, file-I/O)

**Files:** `test/upgrade_test.exs`, `test/sigra/install/generator_passkeys_opt_out_test.exs`, `test/sigra/install/features/passkeys_js_test.exs`, `test/sigra/install/golden_diff_test.exs`, `test/sigra/install/idempotency_test.exs`, and `test/sigra/install/vault_promotion_test.exs`.

**Analog:** existing module-level ExUnit setup and `InstallFixture` lifecycle, especially [`golden_diff_test.exs` lines 34-86](../../../../test/sigra/install/golden_diff_test.exs#L34-L86) and [`idempotency_test.exs` lines 19-39](../../../../test/sigra/install/idempotency_test.exs#L19-L39).

```elixir
use ExUnit.Case, async: false
alias Sigra.Test.InstallFixture

setup_all do
  {:ok, %{app_dir: app_dir, stdout: first_stdout}} = InstallFixture.setup_tmp_app()
  {:ok, %{app_dir: app_dir, first_stdout: first_stdout}}
end
```

Add one module-level `@moduletag :scaffold` beside the existing `use ExUnit.Case`/aliases. Do not change tests, fixture assertions, async mode, or timeouts. These modules already centralize the slow lifecycle: e.g. upgrade uses `setup_tmp_app_without_install`, install, compile, migrate, and upgrade ([`test/upgrade_test.exs` lines 22-113](../../../../test/upgrade_test.exs#L22-L113)); golden/idempotency use `setup_tmp_app` ([`golden_diff_test.exs` lines 45-86](../../../../test/sigra/install/golden_diff_test.exs#L45-L86)).

**Explicit exclusion:** [`template_render_test.exs` lines 1-16](../../../../test/sigra/install/template_render_test.exs#L1-L16) is an `async: true` template-only test and says it does not require the full fixture; retain it in ordinary shards without `:scaffold`.

### `.planning/phases/233-library-suite-economics/233-EVIDENCE.md` (config/evidence, batch)

**Analog:** [`230-EVIDENCE.md` lines 1-40](../../230-tier-1-critical-path-reclamation/230-EVIDENCE.md#L1-L40) and its actual PR table ([lines 44-67](../../230-tier-1-critical-path-reclamation/230-EVIDENCE.md#L44-L67)).

> **A claim without a verbatim run ID is not evidence.**
>
> Command: `bash scripts/ci/ci-run-metrics.sh --jobs <run-id>`
>
> Preserve the command output verbatim in a fenced `text` block.

Record a baseline and retry-free real `pull_request` result. Include the two ordinary shard durations before/after, the extracted receiver duration, the `Library tests` result, and log evidence naming `upgrade_test` plus golden/idempotency execution. Static YAML reads and skipped/nightly lanes are not evidence.

## Shared Patterns

### CI result aggregation and shell safety

**Source:** `.github/workflows/ci.yml` ([lines 604-622](../../../../.github/workflows/ci.yml#L604-L622), [lines 1648-1673](../../../../.github/workflows/ci.yml#L1648-L1673))  
**Apply to:** scaffold receiver and `library_tests` update.

- Use `if: always()` on a terminal required-check job.
- Map every GitHub expression through `env:` and quote shell variables.
- Use `set -euo pipefail` and explicitly fail any non-success dependency.

### Expensive generated-app lifecycle

**Source:** `test/support/install_fixture.ex` ([lines 43-104](../../../../test/support/install_fixture.ex#L43-L104), [lines 191-270](../../../../test/support/install_fixture.ex#L191-L270))  
**Apply to:** only the six tagged scaffold modules and the receiver’s explicit test selection.

The fixture owns `phx.new`, compile, installer/upgrade commands, and errors; the phase should classify those consumers, not reimplement the harness.

### Deterministic CI/evidence contracts

**Source:** `test/sigra/planning/phase_230_ci_timeouts_test.exs` ([lines 24-50](../../../../test/sigra/planning/phase_230_ci_timeouts_test.exs#L24-L50)) and `scripts/ci/ci-run-metrics.sh` ([lines 1-34](../../../../scripts/ci/ci-run-metrics.sh#L1-L34)).  
**Apply to:** Phase 233 workflow contract test, partition manifest validation, and evidence ledger.

Use no added YAML dependency, make parsing fail closed, and treat run IDs plus the script’s verbatim output as the sole source for duration claims.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `test/support/ci/ex_unit_timing_formatter.ex` | utility | event-driven | No custom `ExUnit.Formatter` exists in the repository; use the ExUnit lifecycle documented in RESEARCH.md and the local test-support module conventions. |

## Metadata

**Analog search scope:** `.github/workflows/`, `scripts/ci/`, `test/support/`, `test/sigra/planning/`, `test/sigra/install/`, `test/`, `.planning/phases/230-*`  
**Files scanned:** 22  
**Pattern extraction date:** 2026-07-31
