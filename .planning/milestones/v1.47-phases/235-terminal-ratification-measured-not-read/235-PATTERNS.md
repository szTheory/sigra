# Phase 235: Terminal Ratification — Measured, Not Read - Pattern Map

**Mapped:** 2026-08-02
**Files analyzed:** 12
**Analogs found:** 12 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json` | config/evidence artifact | batch | `.planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-EVIDENCE.json` | role-match |
| `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs` | test | transform / batch | `test/sigra/planning/phase_234_playwright_inventory_contract_test.exs` | exact |
| `CONTRIBUTING.md` | documentation | request-response (operator guidance) | `test/sigra/planning/phase_198_contributor_dx_contract_test.exs` + current `CONTRIBUTING.md` | role-match |
| `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` | planning record | transform / batch | its 2026-07-28 status addendum | exact in-place continuation |
| `.planning/MILESTONE-ARC.md` | planning record | transform / batch | its existing `CI-PERF` entry | exact in-place continuation |
| `scripts/ci/ci-run-metrics.sh` + `.test.sh` | authoritative measurement instrument | transform / batch | existing wall-mode and `--jobs` contracts in the same files | exact in-place extension |
| `scripts/ci/capture-fast-01-gap-closure.sh` + `.test.sh` | protected source collector | external response → signed subject | `scripts/ci/capture-terminal-ratification-evidence.sh` + test | role-match |
| `.github/workflows/fast-01-gap-closure-evidence.yml` | protected evidence workflow | dispatch → attested artifact | `.github/workflows/terminal-ratification-evidence.yml` | exact |
| `scripts/ci/verify-fast-01-source-complete-attestation-offline.sh` | offline provenance/comparison verifier | signed subject → accepted evidence | `scripts/ci/verify-terminal-ratification-attestation-offline.sh` | exact |
| `test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs` | evidence contract | batch / adversarial transform | `phase_235_terminal_ratification_contract_test.exs` | exact |
| `235-FAST-01-SOURCE-COMPLETE-DISPATCH-CORRELATION.json` | preflight and dispatch selection receipt | retained preflight → authorization → bounded post set → one watcher ID | `scripts/ci/correlate-terminal-ratification-dispatch.sh` output contract | role-match |

The Phase 234 inventory and completed GATE-05 artifacts remain read-only inputs. Plans 16–17 intentionally extend the mandatory measurement script, protected collector/workflow, source-complete verifier/contract, and add a durable dispatch-correlation receipt; Plan 18 alone reconciles REQUIREMENTS, the FAST residual, SEED-005, and CI-PERF from that authenticated handoff.

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

**Plans 16–18 assignment:** Plans 16–17 extend this script with a hermetic source-page input seam so it remains the sole authoritative implementation of membership, wall seconds, ordering, p50, and pole selection. The collector records its exact command/output; the offline verifier separately recomputes from signed raw pages only as a comparison oracle. On a miss, follow the existing `--jobs` precedent while retaining the underlying paginated job response, including steps, so run/job/step linkage is independently auditable. Plan 18 consumes that authenticated result and does not introduce another measurement path.

### Retained preflight before authorization; durable dispatch correlation before watching

**Analog:** `scripts/ci/correlate-terminal-ratification-dispatch.sh` and the Plan 15 correlation failure record.

Before authorization, persist and validate the protected-main ancestry/blob receipts, authoritative readiness count, REST budget/reset facts, numeric workflow ID, protected-main SHA, bounded pre-dispatch projection, and UTC not-before boundary in `235-FAST-01-SOURCE-COMPLETE-DISPATCH-CORRELATION.json`. Present those exact retained facts at the blocking decision. After authorization, the single dispatch is the first external mutation; only then collect the bounded post projection, finalize the same receipt with the singleton candidate ID/URL and cardinality, validate exact set difference and identity fields, and read the sole watcher ID from it. A temporary-only preflight or selection record is not sufficient because the Phase 15 diagnostics show that correlation state otherwise cannot survive a selector or host-tool failure.

### Source-complete signed evidence and miss poles

**Analog:** `235-PROTECTED-RECEIPTS.json` plus `verify-terminal-ratification-attestation-offline.sh`.

Retain contiguous run pages through an explicit empty terminal page. If the authoritative result misses, also retain contiguous job pages through exhaustion for the selected median and maximum runs, including each job's ordered steps and timestamps. Verify repository/signer/ref/digest first, then compare raw-source replay with the metrics-script receipt and validate run→job→step linkage. GATE-05's original protected receipt, terminal ledger, verifier, and contract remain byte-stable non-regression inputs.

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
