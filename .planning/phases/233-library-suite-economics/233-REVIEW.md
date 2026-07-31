---
phase: 233-library-suite-economics
reviewed: 2026-07-31T22:35:26Z
depth: standard
files_reviewed: 11
files_reviewed_list:
  - .github/workflows/ci.yml
  - test/support/ci/ex_unit_timing_formatter.ex
  - test/support/ci/ex_unit_timing_formatter_test.exs
  - test/support/ci/library_test_partitions.exs
  - test/sigra/planning/phase_233_library_economics_contract_test.exs
  - test/upgrade_test.exs
  - test/sigra/install/golden_diff_test.exs
  - test/sigra/install/idempotency_test.exs
  - test/sigra/install/generator_passkeys_opt_out_test.exs
  - test/sigra/install/features/passkeys_js_test.exs
  - test/sigra/install/vault_promotion_test.exs
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 233: Code Review Report

**Reviewed:** 2026-07-31T22:35:26Z
**Depth:** standard
**Files Reviewed:** 11
**Status:** issues_found

## Summary

The new explicit library-test partitioning omits tests introduced in this same phase. The required library gate can therefore report success without running the formatter behavior or the contract intended to protect this CI topology.

## Critical Issues

### CR-01: New untagged tests are silently excluded from every required library lane

**File:** `/Users/jon/projects/sigra/test/support/ci/library_test_partitions.exs:71-80`; `/Users/jon/projects/sigra/.github/workflows/ci.yml:561-562`
**Issue:** The shard command runs only the file paths derived from the pre-change evidence receipt, then excludes `:scaffold` tests. The manifest merely filters and assigns that historical list; it neither adds nor verifies the current test-file set. As a result, `test/support/ci/ex_unit_timing_formatter_test.exs` and `test/sigra/planning/phase_233_library_economics_contract_test.exs` are absent from the evidence's `per_file_costs` and are untagged, so they are not selected by either the ordinary shards or `mix test --only scaffold`. No other library CI job runs the repository test suite. The timing formatter and its guard contract can regress undetected while the required `Library tests` context stays green.
**Fix:** Make partition construction fail closed against the current non-scaffold test-file inventory, or explicitly append and validate newly introduced ordinary files before invoking `mix test`. For example, derive the current `test/**/*_test.exs` set (respecting the existing `test_load_filters` exclusions), subtract the scaffold-tagged set, and raise unless it exactly matches the union of the two manifest partitions. Update the committed measured manifest/evidence to include the two new tests (or tag and intentionally route them to the scaffold receiver), and add a regression test for a file present on disk but absent from `per_file_costs`.

---

_Reviewed: 2026-07-31T22:35:26Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
