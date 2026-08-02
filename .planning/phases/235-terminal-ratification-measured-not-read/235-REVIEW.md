---
phase: 235-terminal-ratification-measured-not-read
reviewed: 2026-08-02T22:45:02Z
depth: standard
files_reviewed: 1
files_reviewed_list:
  - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 235: Code Review Report

**Reviewed:** 2026-08-02T22:45:02Z
**Depth:** standard
**Files Reviewed:** 1
**Status:** issues_found

## Summary

The terminal-ratification contract test passes as committed, but its binding-pole validation does not prove that the receipts actually identify the median and maximum evidence used to diagnose the FAST-01 miss. A forged receipt can retain a valid source-run payload while altering the claimed command, digest, selection, and wall duration without being rejected.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Binding-pole receipts are not bound to the claimed pole evidence

**File:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:792-839`
**Issue:** For a miss, validation only requires a non-empty receipt list and that each `command` string contains `--jobs <run_id>` plus that `output_sha256` is a binary. It never validates the receipt's `selection`, `wall_seconds`, or `output_sha256`, and it does not require receipts for the measured median and maximum runs. `validate_binding_pole_receipts!/2` merely proves the referenced run has one job whose name/conclusion/duration matches the nested pole. Consequently, a ledger can claim an arbitrary median/max diagnosis (or a fabricated command and digest) while preserving a valid `source_receipt` and still pass the contract.

**Fix:** Derive the expected median-neighbor and maximum run IDs/durations from the retained pull-request runs, require exactly those selections, and bind every claimed receipt field to canonical data. For example:

```elixir
expected = %{
  "median_neighbor" => median_run,
  "maximum_duration" => max_run
}

for receipt <- receipts do
  run = Map.fetch!(expected, receipt["selection"])
  assert receipt["run_id"] == run["id"]
  assert receipt["wall_seconds"] == wall_duration(run)
  assert receipt["command"] ==
           "bash scripts/ci/ci-run-metrics.sh --jobs #{run["id"]} --format json"
  assert receipt["output_sha256"] =~ ~r/\A[0-9a-f]{64}\z/
end
```

Also include the actual metrics output whose SHA is claimed (or remove the unprovable top-level digest) and verify that digest against those bytes.

---

_Reviewed: 2026-08-02T22:45:02Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
