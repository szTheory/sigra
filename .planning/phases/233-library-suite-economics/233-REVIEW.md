---
phase: 233-library-suite-economics
reviewed: 2026-07-31T23:28:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - .github/workflows/ci.yml
  - test/sigra/install/features/passkeys_js_test.exs
  - test/sigra/install/generator_passkeys_opt_out_test.exs
  - test/sigra/install/golden_diff_test.exs
  - test/sigra/install/idempotency_test.exs
  - test/sigra/install/vault_promotion_test.exs
  - test/sigra/planning/phase_233_library_economics_contract_test.exs
  - test/support/ci/library_test_partitions.exs
  - test/upgrade_test.exs
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 233: Code Review Report

**Reviewed:** 2026-07-31T23:28:00Z  
**Depth:** standard  
**Files Reviewed:** 9  
**Status:** issues_found

## Summary

The CI split correctly validates the live ordinary-test universe before selecting either shard, and the scaffold receiver is required by the name-preserving aggregate. One test reliability defect remains: the phase contract loads the partition module only at test runtime, so the Elixir compiler reports its direct calls as undefined on every invocation.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Partition contract emits undefined-function compiler warnings

**File:** `test/sigra/planning/phase_233_library_economics_contract_test.exs:112-231`  
**Issue:** `Sigra.CI.LibraryTestPartitions` is introduced only with `Code.require_file/1` inside individual test bodies. Remote calls to `validate!/1`, `assign!/1`, `build_partitions!/1`, `current_ordinary_paths!/1`, and `validate_current_universe!/2` are therefore unresolved during compilation. Running this file produces repeated “module … is not available or is yet to be defined” warnings, hiding genuine new compiler warnings in the required CI suite.  
**Fix:** Require the manifest at module load time, before the test functions are compiled, and remove the per-test runtime requires. For example:

```elixir
@partition_manifest_path "test/support/ci/library_test_partitions.exs"
Code.require_file(@partition_manifest_path)
```

Alternatively, promote the helper to a compiled `.ex` file under `test/support` and reference it normally.

---

_Reviewed: 2026-07-31T23:28:00Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_

