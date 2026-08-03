---
phase: 235-terminal-ratification-measured-not-read
reviewed: 2026-08-03T00:40:06Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - CONTRIBUTING.md
  - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
findings:
  critical: 4
  warning: 0
  info: 0
  total: 4
status: issues_found
---

# Phase 235: Code Review Report

**Reviewed:** 2026-08-03T00:40:06Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

The contributor guidance is internally consistent with the tested topology. The contract test itself passes, but it does not establish the claimed ratification boundary: an ownership execution check is a no-op, the retained run population is capped and not proven exhaustive, and the evidence hashes are self-authenticating. These gaps allow a coherent but incomplete or fabricated ledger to be accepted.

## Critical Issues

### CR-01: Ownership execution validation always succeeds

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:821-822`

**Issue:** `event_job_executed?/2` returns `true` for every event and owner. Consequently the `"executed"` branch at lines 781-784 never examines the workflow, so a ledger can claim that a direct owner ran on an event where its job is disabled, skipped, or absent. This defeats the test's advertised per-event ownership proof.

**Fix:** Pass the parsed workflow/job configuration into this helper and determine execution from the actual trigger and job-level `if` expression (or, more robustly, retain and validate a terminal job receipt for each event/owner). Add mutation tests that make a required owner unavailable on `push` and `schedule` and assert rejection.

### CR-02: The asserted source population is a capped prefix, not a complete capture window

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:620-624, 840-842, 903-923`

**Issue:** The required capture command hard-codes `gh run list --limit 100`, and validation only reconciles against the returned bytes. The committed receipt contains exactly 100 records, demonstrating that the limit was reached. Nothing proves that later pages contain no additional runs inside the cutoff window. A selected first page plus internally consistent measurements can therefore omit qualifying runs and alter the reported p50/verdict while passing every check.

**Fix:** Capture the complete paginated API response (including page/Link exhaustion evidence) and filter it locally by the immutable timestamps. Record and assert an explicit total and page count, reject a capture that reaches a configured limit without an exhaustion marker, and add a test with an omitted second-page in-window run.

### CR-03: Receipt digests have no independent trust anchor

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:16, 906-909, 1016-1019, 1037-1056`

**Issue:** The source-population hash is a mutable module attribute in the same submitted change as the ledger, while the other receipts only assert `sha256(output)`. An author can replace the run list, job output, metrics, ledger values, and `@population_sha` with a coherent fabricated set; all digest checks still pass. SHA-256 detects accidental modification after capture, but does not prove the bytes originated with GitHub.

**Fix:** Bind evidence to an independently immutable provenance source: for example, have a protected workflow upload a GitHub-attested artifact and verify its certificate/subject/digest, or query GitHub from a protected verifier using recorded run IDs and compare the API response. Keep expected digests outside the PR-under-test and add a negative test that replaces both the receipt and its local expected hash.

### CR-04: Inverted run timestamps are converted into zero-duration measurements

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:1312-1315, 1347-1353`

**Issue:** The validator parses both timestamps and bounds them, but never rejects `updated_at < created_at`. Both `recompute_statistics!/2` and `wall_seconds!/1` clamp a negative difference to zero. Thus a forged receipt can give selected runs inverted, in-window timestamps and lower their wall durations to zero, producing a coherent but false p50 and FAST-01 verdict.

**Fix:** Reject an inverted interval before computing statistics, e.g. `if DateTime.compare(updated_at, created_at) == :lt, do: raise(ArgumentError, "inverted run interval")`, and add a mutation test for both ledger and source-receipt timestamps.

---

_Reviewed: 2026-08-03T00:40:06Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
