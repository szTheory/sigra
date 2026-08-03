# Phase 235: Terminal Ratification — Measured, Not Read - Pattern Map

**Mapped:** 2026-08-02
**Files analyzed:** 5
**Analogs found:** 5 / 5

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json` | config/evidence artifact | batch | `.planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-EVIDENCE.json` | role-match |
| `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | test | transform / batch | `test/sigra/planning/phase_234_playwright_inventory_contract_test.exs` | exact |
| `CONTRIBUTING.md` | documentation | request-response (operator guidance) | `test/sigra/planning/phase_198_contributor_dx_contract_test.exs` + current `CONTRIBUTING.md` | role-match |
| `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` | planning record | transform / batch | its 2026-07-28 status addendum | exact in-place continuation |
| `.planning/MILESTONE-ARC.md` | planning record | transform / batch | its existing `CI-PERF` entry | exact in-place continuation |

The mandatory measurement script, workflow, and Phase 234 inventory are read-only inputs, not Phase 235 edit targets.

## Pattern Assignments

### `.planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json` (config/evidence artifact, batch)

**Analog:** `.planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-EVIDENCE.json`

Use a single JSON document with a schema version, explicit named evidence slots, literal commands, immutable identifiers, run/job URLs or IDs, timestamps, a sanitized digest where useful, and diagnostics. Do not create a second Playwright inventory: load Phase 234's existing JSON as the after-state source and add terminal before/after rows around it.

**Evidence-shape pattern** ([234-EVIDENCE.json lines 1-13](../234-hygiene-supply-chain-and-contributor-dx/234-EVIDENCE.json#L1-L13)):

```json
{
  "schema_version": 1,
  "local_mix_ci": {
    "status": "success",
    "conclusion": "success",
    "commit_sha": "...",
    "command": "MIX_ENV=test mix ci",
    "started_at": "...",
    "completed_at": "..."
  }
}
```

**Live-receipt pattern** ([234-EVIDENCE.json lines 41-61](../234-hygiene-supply-chain-and-contributor-dx/234-EVIDENCE.json#L41-L61)):

```json
"pr_ci": {
  "status": "success",
  "event": "pull_request",
  "run_id": "30722736494",
  "job_id": "91429048026",
  "direct_mix_ci_step_count": 1,
  "library_suite_owner_count": 1,
  "log_sha256": "...",
  "diagnostics": "..."
}
```

**Required Phase 235 ledger shape:** preserve immutable `topology_cutoff` (SHA, timestamp, source commit), one `capture_endpoint`, the three same-window commands using `scripts/ci/ci-run-metrics.sh --mode wall --since <cutoff> --event <event> --format json`, selected run IDs/outcomes, FAST-01 computed verdict, binding-pole `--jobs` receipt when the verdict misses, a source pointer/hash for `234-PLAYWRIGHT-INVENTORY.json`, and sorted before/after ownership rows. Each row names family/spec, event, direct owner, seam/invocation, terminal aggregate (if any), state, receiver when moved, phase/run provenance, and a real execution receipt.

### `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` (test, transform / batch)

**Analog:** `test/sigra/planning/phase_234_playwright_inventory_contract_test.exs`

This is the closest pattern: async ExUnit, literal paths in module attributes, decode once into maps, reconcile a machine artifact against live files, and demonstrate every failure mode through in-memory mutations.

**Setup/import pattern** ([phase_234_playwright_inventory_contract_test.exs lines 1-18](../../../test/sigra/planning/phase_234_playwright_inventory_contract_test.exs#L1-L18)):

```elixir
defmodule Sigra.Planning.Phase234PlaywrightInventoryContractTest do
  use ExUnit.Case, async: true

  @workflow_path ".github/workflows/ci.yml"
  @config_path "test/example/priv/playwright/playwright.config.ts"
  @inventory_path ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-PLAYWRIGHT-INVENTORY.json"
end
```

**Fail-closed exact-universe pattern** ([lines 226-255](../../../test/sigra/planning/phase_234_playwright_inventory_contract_test.exs#L226-L255)):

```elixir
live_specs = live_specs()
inventory_specs = Enum.map(specs, &Map.fetch!(&1, "spec"))
duplicate_specs = inventory_specs -- Enum.uniq(inventory_specs)

if duplicate_specs != [], do: raise(ArgumentError, "duplicate inventory spec: ...")

missing = MapSet.difference(MapSet.new(live_specs), MapSet.new(inventory_specs))
stale = MapSet.difference(MapSet.new(inventory_specs), MapSet.new(live_specs))

if MapSet.size(missing) > 0, do: raise(ArgumentError, "missing live specs: ...")
if MapSet.size(stale) > 0, do: raise(ArgumentError, "stale inventory specs: ...")
```

**Executable-row validation pattern** ([lines 271-306](../../../test/sigra/planning/phase_234_playwright_inventory_contract_test.exs#L271-L306)):

```elixir
for field <- ["workflow", "job", "seam", "events", "command_marker", "project", "config_seam"] do
  unless Map.has_key?(lane, field), do: raise(ArgumentError, "missing lane field: #{field}")
end

job = workflow_job!(workflow, lane["job"])
unless job =~ lane["seam"], do: raise(ArgumentError, "missing workflow seam: ...")
validate_invocation!(spec, lane, job)
```

**Required Phase 235 test cases:** mutate the terminal ledger in memory to reject missing, stale, duplicate, unowned, non-executable, no-receiver-for-move, absent/malformed receipt, wrong cutoff/window/command, fewer than ten PR runs, a pre-cutoff PR ID, and an undocumented closeout claim. Require exact ledger keys rather than accepting extra evidence slots, following the evidence contract's exact-set check ([phase_234_evidence_contract_test.exs lines 640-669](../../../test/sigra/planning/phase_234_evidence_contract_test.exs#L640-L669)).

**Status/receipt branch pattern:** evidence can be explicitly pending during a real capture, but it is never silently treated as success ([phase_234_evidence_contract_test.exs lines 68-80](../../../test/sigra/planning/phase_234_evidence_contract_test.exs#L68-L80)). Terminal completion/closeout must only allow a populated, validated measured verdict.

### `CONTRIBUTING.md` (documentation, request-response/operator guidance)

**Analog:** current `CONTRIBUTING.md` plus `test/sigra/planning/phase_198_contributor_dx_contract_test.exs`

Keep the existing contributor-command section and make topology claims testable by asserting literal job IDs, aggregate names, commands, and non-PR conditions. Do not describe `example_playwright_smoke` as the executor; it is the terminal aggregate.

**Current direct-owner vs aggregate prose** ([CONTRIBUTING.md lines 11-25](../../../CONTRIBUTING.md#L11-L25)):

```markdown
CI's `library_tests_shard` job is the sole library-suite owner and calls the same
command directly with `MIX_ENV=test mix ci`. The byte-stable `Library tests` job
remains the protected aggregation of that owner.
```

**Mechanically checked documentation pattern** ([phase_198_contributor_dx_contract_test.exs lines 67-86](../../../test/sigra/planning/phase_198_contributor_dx_contract_test.exs#L67-L86)):

```elixir
for text <- [
  "mix ci", "library_tests_shard", "Library tests", "MIX_ENV=test mix ci", "retry-free"
] do
  assert contributing =~ text
end
```

Add exact, test-checked prose for: `example_playwright_shard` as the direct five-seam owner; `Example Playwright smoke (full lifecycle)` as byte-stable aggregate; the supported `test/example/priv/playwright` reproduction seam; and `admin_eval_render` / `admin_design_recapture` (plus any documented receipts) as intentionally non-PR. The workflow proves the distinction: shards execute literal spec invocations ([ci.yml lines 1232-1250](../../../.github/workflows/ci.yml#L1232-L1250)), while the aggregate only reads shard status ([lines 1360-1386](../../../.github/workflows/ci.yml#L1360-L1386)).

### `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` (planning record, transform / batch)

**Analog:** the existing in-place status addendum ([lines 208-217](../../seeds/SEED-005-ci-cd-pipeline-performance-audit.md#L208-L217)).

Append a dated terminal addendum rather than rewriting the original audit or its baseline. State that the audit was already completed and its remediation sequence was executed through Phases 230–235. Link the ratification artifact and branch honestly on its FAST-01 verdict: if it misses, preserve/file a concrete residual with binding-pole receipt rather than declaring the target achieved.

### `.planning/MILESTONE-ARC.md` (planning record, transform / batch)

**Analog:** the only existing `CI-PERF` item ([lines 267-270](../../MILESTONE-ARC.md#L267-L270)).

Replace the stale `ACTIVE` framing with a completed/reconciled entry that points to SEED-005 and the terminal ledger. Preserve the historical baseline wording as history; do not delete it or recast it as the terminal result. The completion state must match the ledger's measured pass/miss and residual link.

## Shared Patterns

### Baseline-compatible measurement

**Source:** `scripts/ci/ci-run-metrics.sh`
**Apply to:** ledger measurement commands and FAST-01 contract assertions

```bash
# Default mode is wall; cutoff filters on createdAt and event filters are explicit.
MODE="wall"
RUNS_JSON="$(gh run list --repo "$REPO" --workflow "$WORKFLOW" --limit "$LIMIT" \
  --json databaseId,event,createdAt,updatedAt,conclusion)"
FILTERED_RUNS="$(echo "$FILTERED_RUNS" | jq --arg since "$SINCE" \
  'map(select(.createdAt >= $since))')"
```

Source: [lines 51-69 and 130-154](../../../scripts/ci/ci-run-metrics.sh#L51-L69). The p50 is locked to `floor(n/2)` and failures remain in the outcome count ([lines 174-190](../../../scripts/ci/ci-run-metrics.sh#L174-L190)). Per-job binding-pole evidence comes only from `--jobs <run_id>` ([lines 92-124](../../../scripts/ci/ci-run-metrics.sh#L92-L124)).

### Ownership means direct executable lane plus aggregate, not aggregate alone

**Source:** `.github/workflows/ci.yml`
**Apply to:** every before/after row and CONTRIBUTING topology wording

```yaml
library_tests:
  name: Library tests
  needs: [library_tests_shard]
  if: always()
  # Fails unless the direct owner succeeds.
```

Source: [ci.yml lines 543-569](../../../.github/workflows/ci.yml#L543-L569). Apply the same distinction to Playwright's direct `example_playwright_shard` matrix and its `example_playwright_smoke` terminal. For non-PR visibility, preserve the actual `admin_eval_render` event condition and its harness receipt ([lines 2094-2099 and 2129-2151](../../../.github/workflows/ci.yml#L2094-L2099)).

### Phase 234 inventory is an input, not a replacement

**Source:** `234-PLAYWRIGHT-INVENTORY.json` and its contract test
**Apply to:** terminal ledger and new contract

```json
{
  "schema_version": "sigra.playwright-ownership/v1",
  "generated_from": "test/example/priv/playwright/tests/*.spec.ts",
  "phase_235_gate_input": true
}
```

Source: [inventory lines 1-5](../234-hygiene-supply-chain-and-contributor-dx/234-PLAYWRIGHT-INVENTORY.json#L1-L5). Reconcile its sorted 20 rows and its two sanctioned harness indirections; do not rescan into a competing ownership model.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| None | — | — | All Phase 235 edit types have a close repository precedent; the terminal before/after schema itself is new but composes the Phase 234 evidence and inventory patterns. |

## Metadata

**Analog search scope:** `scripts/ci/`, `test/sigra/planning/`, `.github/workflows/`, `CONTRIBUTING.md`, `.planning/phases/230-234/`, `.planning/seeds/`, `.planning/`
**Files scanned:** 14 primary analog/input files
**Pattern extraction date:** 2026-08-02
