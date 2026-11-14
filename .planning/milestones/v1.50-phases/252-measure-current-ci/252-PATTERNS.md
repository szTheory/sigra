# Phase 252: Measure Current CI - Pattern Map

**Mapped:** 2026-10-12  
**Files analyzed:** 7 responsibilities (some target paths remain a planner choice)  
**Analogs found:** 6 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `scripts/ci/ci-run-metrics.sh` (modify) | utility / CLI | request-response, batch, transform, file-I/O | same file; `scripts/ci/release-canary.sh` for run-bound API/artifact provenance | exact for existing CLI; role-match for collector trust boundary |
| `scripts/ci/ci-run-metrics.test.sh` (modify) | test | transform, request-response (stubbed) | same file; `scripts/ci/release-canary.test.sh` | exact |
| `test/support/<timing-formatter>.ex` (new; exact name discretionary) | test support / formatter | event-driven, file-I/O | `test/test_helper.exs`; no existing ExUnit formatter implementation found | partial |
| `test/<formatter-contract-test>.exs` (new; exact name discretionary) | test | event-driven, transform | `test/sigra/planning/phase_234_evidence_contract_test.exs` for contract assertions; no formatter contract exists | role-match |
| `test/example/priv/playwright/playwright.config.ts` (modify) | config | transform / file-I/O | same file | exact |
| `.github/workflows/ci.yml` (modify) | config / workflow | event-driven, batch, file-I/O | same file; `scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs` for structural workflow contracts | exact / role-match |
| Phase report/evidence artifact (new; filename discretionary) | report / evidence | transform, file-I/O | `scripts/ci/ci-run-metrics.sh` JSON output and source-page validation; no current report with this phase's fixed comparison contract | partial |

The context explicitly names the existing collector, its shell test, workflow, Playwright config, ExUnit bootstrap and Sandbox case. Research recommends an opt-in formatter and contract test, workflow contract coverage, and a concise report, but leaves their exact filenames open. Keep the test-only formatter out of production `lib/`; do not add a dependency. All analog source paths listed here were checked with `git ls-files` and are tracked.

## Pattern Assignments

### `scripts/ci/ci-run-metrics.sh` (utility / CLI, request-response + batch + transform)

**Analog:** `scripts/ci/ci-run-metrics.sh` (self-extension), with `scripts/ci/release-canary.sh` for strict source/artifact identity and durable-input handling.

**CLI and fail-closed input pattern** (`ci-run-metrics.sh`, lines 47-103):

```bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
...
while [[ $# -gt 0 ]]; do
  case "$1" in
    --jobs) RUN_ID="$2"; shift 2;;
    --format) FORMAT="$2"; shift 2;;
    --source-pages) SOURCE_PAGES="$2"; shift 2;;
    *) echo "ci-run-metrics: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done
...
if [[ -n "$SOURCE_PAGES" ]]; then
  [[ "$FORMAT" == "json" ]] || fail "source-pages requires --format json"
  [[ -s "$SOURCE_PAGES" ]] || fail "source_pages_missing_or_empty"
```

**Offline schema and calculation pattern** (`ci-run-metrics.sh`, lines 105-155): the current source-pages mode validates resource/query, requested page sequence, terminal page, counts, unique run IDs, literal conclusions and timestamps with `jq -e`; only after shape validation does it calculate statistics and emit sorted JSON. Extend this offline seam for replay and new source identities; use explicit GET in any new parameterized API call per D-07.

**API/artifact provenance pattern** (`scripts/ci/release-canary.sh`, lines 372-397 and 455-456): API reads are isolated in small helpers, rate limit is queried before work, and downloaded ZIP bytes are hashed and compared to the API digest. Its matching hermetic test records endpoint and argv (`scripts/ci/release-canary.test.sh`, lines 451-468). Copy the identity/hash validation ideas, but do not copy publishing, dispatch, cancellation, or write-permission behavior. For this phase compare artifact metadata to the source run; the embedded artifact name/manifest is not authority.

### `scripts/ci/ci-run-metrics.test.sh` (test, stubbed request-response + transform)

**Analog:** `scripts/ci/ci-run-metrics.test.sh`; use `scripts/ci/release-canary.test.sh` for a richer API fixture only where run/artifact provenance needs it.

**Hermetic shell setup and fixture pattern** (`ci-run-metrics.test.sh`, lines 39-77):

```bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/ci-run-metrics.sh"
TMPDIR_ROOT="$(mktemp -d)"
STUB_BIN_DIR="${TMPDIR_ROOT}/bin"
mkdir -p "$STUB_BIN_DIR"
GH_STUB_LOG="${TMPDIR_ROOT}/gh-calls.log"
: > "$GH_STUB_LOG"
```

Place a recording `gh` stub first on `PATH`, feed canned JSON, and assert argv, stdout, stderr, exit status and no partial output on failure. Existing cases already pin literal outcomes, negative-time clamping, odd/even p50 selection and malformed-source fail-closed behavior (`ci-run-metrics.test.sh`, lines 70-83 and 363-425). Add fixed-cutoff/cap, attempts, missing timestamps, rate limits, manifest, artifact origin, replay and incomplete-data cases using the same deterministic style.

**Confirmed runnable command:** `bash scripts/ci/ci-run-metrics.test.sh`. The research's `--source-dir` replay invocation is a proposed interface, not an existing command; plan its shape before documenting it as runnable.

### `test/support/<timing-formatter>.ex` (test support, event-driven + file-I/O)

**Analog:** `test/test_helper.exs` (test-only startup order); `test/support/postgres_case.ex` (explicit resource ownership). There is no tracked ExUnit event formatter to copy.

**Opt-in test bootstrap pattern** (`test/test_helper.exs`, lines 12-27):

```elixir
unless phx_new_ok? do
  ExUnit.configure(exclude: [:upgrade])
end

ExUnit.start()

if Code.ensure_loaded?(Postgrex) and Code.ensure_loaded?(Sigra.Test.PostgresRepo) do
  {:ok, _pid} = Sigra.Test.PostgresRepo.start_link(Sigra.Test.PostgresRepo.default_config())
  Ecto.Adapters.SQL.Sandbox.mode(Sigra.Test.PostgresRepo, :manual)
end
```

Load/enable the timing formatter only for an explicit timing output setting and preserve the regular CLI formatter and ordinary test scheduling. Follow the pinned ExUnit 1.19.5 formatter protocol from the research for `test_finished` and `suite_finished`; there is no repository implementation to quote. Keep output errors visible and retain the original test exit status. For DB-backed contract tests, preserve Sandbox ownership (`test/support/postgres_case.ex`, lines 22-31): start owner with `shared: not tags[:async]` and stop it in `on_exit`.

### `test/<formatter-contract-test>.exs` (test, event-driven + transform)

**Analog:** `test/sigra/planning/phase_234_evidence_contract_test.exs` for machine-readable artifact assertions. The formatter's event and duration contract has no exact analog.

Read existing contract tests before selecting placement: this project has focused ExUnit planning-contract tests and test support under `test/support`. Assert schema and duration units against a small deterministic formatter event sequence; include incomplete/failed output behavior and test-exit preservation. Do not treat a missing or partial report as a zero-time success.

**Confirmed project commands:** library gate in CI is `run: mix ci` (`.github/workflows/ci.yml`, lines 585-591); exact local environment is `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci` (research cites `mix.exs`, lines 146-157). A targeted contract command should use `MIX_ENV=test mix test <chosen-test-path>` with the required local Postgres service; the `<chosen-test-path>` is not a literal runnable path until the planner settles the filename.

### `test/example/priv/playwright/playwright.config.ts` (config, transform + file-I/O)

**Analog:** same tracked file.

**Reporter/scheduling pattern** (`playwright.config.ts`, lines 55-61):

```typescript
export default defineConfig({
  testDir: './tests',
  outputDir: './test-results',
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list'], ['html', { open: 'never' }]],
```

Add Playwright's built-in JSON reporter alongside `list` and HTML, with a deterministic output destination. Preserve one worker, serial execution and zero retries. The config is shared by five isolated seam invocations; identify seam/project/run/attempt from workflow invocation metadata rather than trusting test-authored report fields alone.

### `.github/workflows/ci.yml` (workflow config, event-driven + file-I/O)

**Analog:** same workflow; `scripts/ci/prohibitions/p20-green-04-evidence-step-parity.test.mjs` is the closest structural-test analog.

**Always-upload diagnostics pattern** (`ci.yml`, lines 1397-1407):

```yaml
      - name: Upload shard diagnostics
        if: always() && needs.changes.outputs.docs_only != 'true'
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
        with:
          name: example-playwright-${{ matrix.seam }}-${{ github.run_id }}
          path: |
            test/example/priv/playwright/playwright-report/
            test/example/priv/playwright/test-results/
            test/example/priv/playwright/artifacts/
          retention-days: 7
          if-no-files-found: warn
```

Retain upload after test failure, add timing JSON to the relevant artifact paths and include stable run/attempt/seam metadata. Avoid turning absent files into a passing/zero measurement. Current library owner remains the single `mix ci` invocation (`ci.yml`, lines 585-591). Existing browser invocations are selection-specific across the five seams; do not replace them with a whole-suite command.

For a static workflow guard, follow P20's pattern: `node:test`, read committed workflow text, extract ordered steps, reject empty parses, and compare the relevant commands/conditions (`p20-green-04-evidence-step-parity.test.mjs`, lines 38-80). Its guard is intentionally offline. Keep such structural contract checks deterministic and separate from hosted timestamp measurements.

### Phase report/evidence artifact (report, transform + file-I/O)

**Analog:** current metrics JSON output (`ci-run-metrics.sh`, lines 125-155) and the new saved manifest/replay schema. There is no existing report that implements Phase 252's required-context endpoint and fixed 20-pair later comparison contract.

Keep raw records, manifest, completeness diagnostics and derived rankings as distinct data. The short report should point to exact saved inputs and replay commands, explain unknown values, separate PR/push/nightly populations and workload class, and preserve failure/cancellation/rerun outcomes. Do not claim that archived timing notes or configured timeouts are measurements.

## Shared Patterns

### Fail-closed, offline-first validation

**Sources:** `scripts/ci/ci-run-metrics.sh` lines 97-155; `scripts/ci/ci-run-metrics.test.sh` lines 363-425.  
**Apply to:** collector, replay, test timing validators and report generation.

Validate schema, identity, chronology, counts and completeness before calculation. Keep literal statuses and null timestamps; emit concrete diagnostics for missing inputs. Never convert missing/partial results to zero or green.

### Source identity and retained artifacts

**Source:** `scripts/ci/release-canary.sh` lines 372-397, 455-456; test stub in `scripts/ci/release-canary.test.sh` lines 451-468.  
**Apply to:** run/job/artifact acquisition and evidence manifest.

Use read-only GitHub API calls, count pages/retries/downloads against the locked budgets, inspect rate-limit state, bind artifacts to GitHub's producing-run metadata, and hash retained bytes. Do not persist credentials or signed redirect URLs. New parameterized reads must specify `--method GET` even though the legacy helper uses `gh api`'s default GET.

### Test ownership and non-perturbing timing

**Sources:** `test/test_helper.exs` lines 22-27; `test/support/postgres_case.ex` lines 22-31; `playwright.config.ts` lines 55-61.  
**Apply to:** ExUnit formatter, Playwright report and their contract tests.

Keep instrumentation opt-in and test-only, preserve the ordinary `mix ci` owner and selection, preserve Ecto Sandbox setup, and keep Playwright `workers: 1`, `fullyParallel: false`, `retries: 0`. Use native formatter/reporter output, not ExUnit trace/slowest mode or scraped human-readable output.

### Workflow artifact collection

**Source:** `.github/workflows/ci.yml` lines 1397-1407.  
**Apply to:** Playwright JSON and ExUnit timing artifact uploads.

Use the existing `if: always()` diagnostics-upload behavior so failures still retain evidence. Keep cache outputs and step timings separate: the shared Playwright boot action installs OS browser dependencies even on a browser binary cache hit (`.github/actions/example-playwright-boot/action.yml`, lines 116-154).

## No Exact Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `test/support/<timing-formatter>.ex` | test support / formatter | event-driven, file-I/O | No ExUnit formatter implementation exists in tracked source; use pinned upstream API plus local test-helper conventions. |
| Phase 252 ranked report / later comparison contract | report | transform, file-I/O | No current report represents the required-context wait, workload-matched 20 pairs, nearest-rank p95 and completeness rules. |

## Metadata

**Analog search scope:** `scripts/ci/`, `scripts/ci/prohibitions/`, `test/support/`, `test/sigra/planning/`, `test/example/priv/playwright/`, `.github/workflows/`, `.github/actions/`.  
**Files scanned:** 11 primary analogs/configs. All named source analogs passed `git ls-files`.  
**Runnable existing checks confirmed:** `bash scripts/ci/ci-run-metrics.test.sh`; `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci`; Playwright install/run command shape is selection-specific in `.github/workflows/ci.yml` (see lines 1210-1255), so the research placeholder with `<same-workflow-selection>` is not itself runnable.  
**Pattern extraction date:** 2026-10-12
