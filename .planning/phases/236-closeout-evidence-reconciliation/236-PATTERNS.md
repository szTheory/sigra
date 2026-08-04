# Phase 236: Closeout Evidence Reconciliation - Pattern Map

**Mapped:** 2026-08-04  
**Files analyzed:** 10  
**Analogs found:** 10 / 10

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `.planning/phases/231-gate-honesty-nightly-revival/231-11-SUMMARY.md` | config / evidence metadata | transform | `233-01-SUMMARY.md` | exact |
| `.planning/phases/231-gate-honesty-nightly-revival/231-06-SUMMARY.md` | config / evidence metadata | transform | `233-01-SUMMARY.md` | exact |
| `.planning/phases/233-library-suite-economics/233-05-SUMMARY.md` | config / evidence metadata | transform | `233-01-SUMMARY.md` | exact |
| `.planning/REQUIREMENTS.md` | config / traceability registry | transform | current v1.47 traceability table in the same file | exact |
| `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` | test / deterministic contract | file-I/O | `test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs` | role-match |
| `.planning/phases/230-tier-1-critical-path-reclamation/230-VALIDATION.md` | config / validation lifecycle | transform | `233-VALIDATION.md` | exact |
| `.planning/phases/231-gate-honesty-nightly-revival/231-VALIDATION.md` | config / validation lifecycle | transform | `233-VALIDATION.md` | exact |
| `.planning/phases/232-playwright-economics-authenticate-once-then-shard/232-VALIDATION.md` | config / validation lifecycle | transform | `233-VALIDATION.md` | exact |
| `.planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VALIDATION.md` | config / validation lifecycle | transform | `233-VALIDATION.md` | exact |
| `.planning/v1.47-v1.47-MILESTONE-AUDIT.md` | config / generated audit report | batch | `.planning/v1.47-MILESTONE-AUDIT.md` | role-match |

## Pattern Assignments

### Phase 231 and 233 SUMMARY frontmatter (config, transform)

**Apply to:** `231-11-SUMMARY.md`, `231-06-SUMMARY.md`, and `233-05-SUMMARY.md`.

**Analog:** `.planning/phases/233-library-suite-economics/233-01-SUMMARY.md`

**Frontmatter convention** (lines 1-30):

```yaml
key-files:
  created: [test/support/ci/ex_unit_timing_formatter.ex, test/support/ci/ex_unit_timing_formatter_test.exs, test/sigra/planning/phase_233_library_economics_contract_test.exs]
  modified: [.github/workflows/ci.yml, .planning/phases/233-library-suite-economics/233-VALIDATION.md]
key-decisions:
  - "Keep ExUnit.CLIFormatter and add Sigra.CI.ExUnitTimingFormatter in the same parallel mix test invocation."
requirements-completed: [TEST-01]
coverage:
  - id: D1
    description: Same-run parallel library shard writes and retains a deterministic timing receipt.
    requirement: TEST-01
```

**Apply narrowly:** replace only the existing empty scalar, retaining all coverage, decisions, narrative, and receipts byte-for-byte:

```yaml
# 231-11-SUMMARY.md:41
requirements-completed: [GATE-01]

# 231-06-SUMMARY.md:39
requirements-completed: [GATE-04]

# 233-05-SUMMARY.md frontmatter
requirements-completed: [TEST-02, TEST-03]
```

The audit names these exact SUMMARY ownership targets; do not add IDs to other summaries or alter the historical descriptions that predate the independent verification decision.

---

### `.planning/REQUIREMENTS.md` (config / traceability registry, transform)

**Analog:** existing v1.47 traceability table in `.planning/REQUIREMENTS.md` (lines 76-104).

**Table pattern** (lines 76-90):

```markdown
## Traceability

**24 requirements · 24 mapped · 0 orphaned.** Each maps to exactly one phase (see `ROADMAP.md` → Phase Details).

| Requirement | Phase | Status |
| --- | --- | --- |
| FAST-01 | Phase 235 | Complete (...) |
| GATE-01 | Phase 231 | Complete (scheduled run `30607570671`, merge SHA `4bba9c71`) |
| GATE-04 | Phase 231 | Complete (...) |
```

**Reconciliation target** (lines 96-104):

```markdown
| TEST-01 | Phase 233 | Gaps Found |
| TEST-02 | Phase 233 | Gaps Found |
| TEST-03 | Phase 233 | Gaps Found |
| DX-01 | Phase 234 | Gaps Found |
| DX-02 | Phase 234 | Gaps Found |
| DX-03 | Phase 234 | Gaps Found |
| DX-04 | Phase 234 | Gaps Found |
| DX-06 | Phase 234 | Gaps Found |
```

Update exactly these eight stale status cells to `Complete` only after a contract verifies each checked requirement has supporting phase verification and deterministic evidence. Preserve the 24-row cardinality, phase ownership, requirement text, and all unrelated status prose.

---

### `test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs` (test, file-I/O)

**Analog:** `test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs`

**Imports and root-path pattern** (lines 1-5):

```elixir
defmodule Sigra.Planning.Phase235Fast01GapClosureContractTest do
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)
  @phase ".planning/phases/235-terminal-ratification-measured-not-read"
```

**Read/decode and negative-mutation pattern** (lines 7-27, 68-146):

```elixir
remediation =
  File.read!(Path.join(@root, Path.join(@phase, "235-FAST-01-REMEDIATION.json")))
  |> Jason.decode!()

assert remediation["population_cutoff"]["sha"] == "54c33e904155a454255952666711c882afdd06e4"
...
assert_raise ArgumentError, ~r/at least ten/, fn ->
  receipt |> Map.put("runs", Enum.take(receipt["runs"], 9)) |> validate_gap_closure!()
end
```

**Adaptation:** use `File.read!` for the three target SUMMARYs, `REQUIREMENTS.md`, the four targeted VALIDATION files, and the protected receipt/VERIFICATION inputs. Assert an exact ownership map (`GATE-01 → 231-11`, `GATE-04 → 231-06`, `TEST-02/03 → 233-05`), reject extra completion IDs, require only the eight approved traceability rows to become `Complete`, and compare protected receipt/VERIFICATION content digests before and after the metadata operation. Keep `async: true`; this is a filesystem-only planning contract.

**Existing evidence/topology assertion style:** `test/sigra/planning/phase_233_library_economics_contract_test.exs` (lines 1-31):

```elixir
@workflow_path ".github/workflows/ci.yml"

test "library execution universe is fail-closed and has one full-suite owner" do
  workflow = File.read!(@workflow_path)
  assert library_job_ids(workflow) == @library_jobs
  ...
  refute workflow =~ "library_tests_scaffold:"
end
```

Use the same fail-closed posture: exact expected values and explicit `refute` checks instead of permissive substring-only success checks.

---

### Phase 230/231/232/234 VALIDATION artifacts (config, transform)

**Analog:** `.planning/phases/233-library-suite-economics/233-VALIDATION.md`

**Canonical frontmatter** (lines 1-9):

```yaml
---
phase: 233
slug: library-suite-economics
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-31
---
```

**Validator-owned audit trail** (lines 83-91):

```markdown
## Validation Audit 2026-07-31

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

All three phase requirements and all twelve plan tasks map to green deterministic verification.
```

**Lifecycle rule:** invoke `$gsd-validate-phase 230`, `231`, `232`, and `234`; do not manually set `status: validated`. The workflow is the only authority for updating task coverage, lifecycle frontmatter, and its dated audit trail. This matters because the current source states are heterogeneous: 230 currently declares `validated` despite the stale audit snapshot, 231 is `draft`/false (lines 1-9), 232 is `ready` (lines 1-8), and 234 is `complete` (frontmatter). Preserve all non-lifecycle evidence unless the validator itself changes it.

---

### `.planning/v1.47-v1.47-MILESTONE-AUDIT.md` (generated audit report, batch)

**Analog:** `.planning/v1.47-MILESTONE-AUDIT.md`

**Frontmatter/results structure** (lines 1-37):

```yaml
---
milestone: v1.47
milestone_name: CI-EFFICIENCY
audited: 2026-08-03T14:26:11Z
status: gaps_found
scores:
  requirements: 18/24
  phases: 5/6
  integration: 11/12
  flows: 6/7
gaps:
  requirements:
    - id: FAST-01
      status: unsatisfied
      phase: "235"
---
```

**Closure sequencing source:** `.planning/v1.47-v1.47-MILESTONE-AUDIT.md` (lines 164-185) specifies its own closeout order:

```markdown
## Closure Path

1. Add the four missing requirement IDs to the appropriate existing SUMMARY `requirements-completed` frontmatter and reconcile the stale REQUIREMENTS traceability statuses.
2. Run `$gsd-validate-phase 230`, `231`, `232`, and `234` to reconcile Nyquist lifecycle state.
3. Re-run `$gsd-audit-milestone`; no new product implementation phase is indicated by the current evidence.
```

Regenerate through `$gsd-audit-milestone v1.47`; never hand-edit scores, Nyquist classifications, gaps, or the ready-to-close verdict. Retain the exact resulting diagnostics if it remains noncompliant.

## Shared Patterns

### Minimal, provenance-preserving metadata edits

**Sources:** `233-01-SUMMARY.md:1-30`; `231-11-SUMMARY.md:41-105`; `231-06-SUMMARY.md:39-73`.

The existing frontmatter places requirement completion in a single `requirements-completed` list while leaving detailed `coverage` entries intact. Modify one scalar/list per selected SUMMARY; do not rewrite historical execution narratives or receipts.

### Deterministic filesystem contracts

**Source:** `test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs:1-146`.

Use `async: true`, repository-root-relative constants, `File.read!`, exact values, and deliberate adverse mutations. The closeout test must fail on a wrong ownership mapping, added completion ID, stale traceability row, lifecycle shortcut, or protected-evidence change.

### Validator and auditor own state transitions

**Sources:** `233-VALIDATION.md:1-9,83-91`; `/Users/jon/.codex/gsd-core/workflows/validate-phase.md:185-237`.

`$gsd-validate-phase` owns `status: validated` and the Validation Audit append. `$gsd-audit-milestone` owns the regenerated milestone report and closeout verdict. No local script should substitute either workflow.

### Fail closed and retain diagnostics

**Sources:** `phase_233_library_economics_contract_test.exs:1-31`; `v1.47-v1.47-MILESTONE-AUDIT.md:144-185`.

Use exact assertions and `refute` checks. If a validator or the final audit fails, preserve its outcome and stop; do not manufacture passing evidence or recapture runtime proof.

## No Analog Found

None. The new Phase 236 planning contract is a narrow composition of the existing Phase 235 filesystem/evidence contract and Phase 233 fail-closed topology contract.

## Metadata

**Analog search scope:** `.planning/`, `test/sigra/planning/`, `/Users/jon/.codex/gsd-core/workflows/validate-phase.md`  
**Files scanned:** 18  
**Pattern extraction date:** 2026-08-04
