---
phase: 235-terminal-ratification-measured-not-read
reviewed: 2026-08-02T18:23:32Z
depth: standard
files_reviewed: 2
files_reviewed_list:
  - CONTRIBUTING.md
  - test/sigra/planning/phase_235_terminal_ratification_contract_test.exs
findings:
  critical: 1
  warning: 2
  info: 0
  total: 3
status: issues_found
---

# Phase 235: Code Review Report

**Reviewed:** 2026-08-02T18:23:32Z
**Depth:** standard
**Files Reviewed:** 2
**Status:** issues_found

## Summary

The contributor guidance accurately describes the current `mix ci` alias and the current CI job names. The focused ExUnit file passes, but its claimed fail-closed measurement and topology contracts are materially weaker than the Phase 235 requirements: they can approve forged FAST-01 evidence and an ownership universe that contains unreviewed rows.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Captured FAST-01 evidence is not recomputed or bound to its receipt

**Classification:** **BLOCKER**

**File:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:376-422`

**Issue:** `validate_captured_ledger!/1` accepts any map for `statistics` and any binary for `output_sha256`; `validate_verdict!/1` only copies the stored p50 into the verdict. It never derives duration, count, outcome counts, mean, p50, or max from the retained runs, validates the SHA-256 format/content, or requires `eligible_pr_run_count` to equal the retained PR population. Therefore an edited ledger can change the PR p50 to 719, set the verdict to `pass`, use an arbitrary string such as `"x"` as the receipt hash, and still satisfy these validators. This defeats the plan's explicit prohibition on declaring FAST-01 achieved from substituted timing semantics or falsified/filtered data.

**Fix:** Parse each retained run's ISO-8601 timestamps, derive clamped wall durations, and assert the exact statistics shape equals the recomputed values (including `n`, `pass`, and `fail`); require the verdict count to equal `statistics["n"]`. Store the command's canonical JSON output (or an immutable checked-in receipt) and verify a 64-hex SHA-256 of those bytes rather than merely checking that a hash field is binary. Add mutation tests for a forged p50/count/hash and mismatched outcome totals.

## Warnings

### WR-01: Ownership validation permits rows outside the declared terminal universe

**Classification:** **WARNING**

**File:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:340-362`

**Issue:** The validator proves that every expected family/spec has the three expected events, but it never asserts that the actual key set equals that expected universe. An extra non-Playwright family, an extra `workflow_dispatch` row, or another unrecognized ownership row passes as long as it has a nonempty owner, receiver, and receipt. That makes the ledger's claimed complete, exact ownership surface silently extensible and leaves newly introduced work unreviewed.

**Fix:** Construct the full expected `{family, spec, event}` set and require `MapSet.new(keys) == expected_keys`; reject event values outside `@events`. Add mutations for an extra family and an extra event row.

### WR-02: The contributor-topology contract only searches unrelated substrings

**Classification:** **WARNING**

**File:** `test/sigra/planning/phase_235_terminal_ratification_contract_test.exs:473-500`

**Issue:** `validate_contributor_topology!/5` does not parse or relate the workflow and documentation facts it claims to bind. For example, it accepts a document that retains `example_playwright_shard`, the aggregate name, all seam names, and the non-PR phrase while also stating elsewhere that the aggregate executes the browser suites or that a signal is a PR executor. It also only checks each signal job name in the workflow, not its `on`/job conditions. Future misleading contributor guidance can therefore pass the contract unchanged.

**Fix:** Parse `ci.yml` (or use narrowly scoped YAML/job-block assertions) to prove the aggregate `needs` the shard and does not run Playwright commands, and prove the two diagnostic jobs are excluded from pull requests. Assert the corresponding documentation statements as complete, unique sentences/sections rather than independent token presence; add contradiction mutations that leave the required tokens elsewhere in the document.

---

_Reviewed: 2026-08-02T18:23:32Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
