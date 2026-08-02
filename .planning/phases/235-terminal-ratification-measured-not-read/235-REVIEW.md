---
phase: 235-terminal-ratification-measured-not-read
reviewed: 2026-08-02T19:08:36Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - CONTRIBUTING.md
  - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
findings:
  critical: 3
  warning: 2
  info: 0
  total: 5
status: issues_found
---

# Phase 235: Code Review Report

**Reviewed:** 2026-08-02T19:08:36Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

`CONTRIBUTING.md` accurately describes the checked CI topology. The focused contract test passes (13 tests), but several of its validators still accept self-consistent forged evidence. That leaves the terminal FAST-01 outcome and ownership ledger materially less trustworthy than the report claims.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: The capture endpoint is unpinned and can move the measured population

**Classification:** **BLOCKER**

**File:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:20-30, 661-690`

**Issue:** The validator requires only `capture_endpoint.status == "captured"`; it never pins or validates its `captured_at` value. Each measurement is merely required to echo that same mutable value. Changing the endpoint to a later timestamp, replacing the runs, and regenerating the self-derived statistics/receipt hash therefore still passes. A terminal ledger can consequently include a different post-ratification population and produce a different FAST-01 verdict while retaining the asserted immutable cutoff.

**Fix:** Declare the expected capture timestamp as a module attribute and require it exactly (and as a valid ISO-8601 instant) in `validate_capture!/1`/`validate_captured_ledger!/1`. Add a mutation test that changes `capture_endpoint.captured_at` and every mirrored measurement endpoint, and require validation to fail.

### CR-02: Retained run IDs are not validated as real, immutable identities

**Classification:** **BLOCKER**

**File:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:684-690`

**Issue:** `ids == Enum.map(runs, & &1["id"])` proves only that two mutable fields agree. It accepts `nil`, strings, or arbitrary unique integers as every run ID. Since the output receipt contains aggregate statistics rather than the source IDs, replacing all IDs with invented values leaves the population, statistics, digest, and verdict valid. The ledger can no longer be traced to the GitHub executions it purports to measure.

**Fix:** Require each ID to be a positive integer and bind the full ordered ID list to an immutable source receipt/digest captured from `gh run list` (or commit the canonical raw response and verify its SHA-256). Add mutations for a string ID, `nil`, and an unrecognized positive ID.

### CR-03: Binding-pole receipts are neither tied to the population nor cryptographically checked

**Classification:** **BLOCKER**

**File:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:741-750`

**Issue:** On a miss, a receipt need only be a nonempty list entry whose command contains its own `run_id`, whose hash is any binary, and whose pole has a name. It need not reference a retained pull-request run; its URL, wall duration, selection, conclusion, job duration, and hash are all unchecked. A fabricated receipt can therefore satisfy the evidence requirement and be copied into the residual closeout record.

**Fix:** Require every receipt `run_id` to occur in the retained PR IDs, verify the canonical GitHub URL and a 64-character SHA-256 against a stored per-run `--jobs` output receipt, and validate the receipt fields against that parsed output. Add mutation tests for an unknown run ID, malformed hash, and mismatched binding-pole duration/name.

## Warnings

### WR-01: Most ownership rows are accepted with arbitrary semantic values

**Classification:** **WARNING**

**File:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:643-656`

**Issue:** Apart from the special `library_scaffold_golden` assertions, every one of the remaining ownership rows is validated only for nonempty `direct_owner`, `receiver`, and `receipt` strings. A row can name a nonexistent job, wrong aggregate, or fabricated receipt and still pass the supposedly complete ownership contract.

**Fix:** Define the expected owner/receiver/receipt/aggregate mapping per family and event, then compare each row to it and to the parsed CI job IDs. Add mutations that substitute a plausible but nonexistent owner and receipt.

### WR-02: Closeout validation ignores the supplied contributor record

**Classification:** **WARNING**

**File:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:765-773`

**Issue:** `validate_closeout_records!/5` names its second argument `_contributing` and never reads it. The closeout test therefore passes even if it is given `nil` or a contributor document that contradicts the terminal record; checking a path string in the ledger does not reconcile the file.

**Fix:** Validate the contributor topology within this closeout check (or remove the parameter and claim from the test name). Add a mutation that passes a contradicted contributor record and assert a deterministic failure.

---

_Reviewed: 2026-08-02T19:08:36Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
