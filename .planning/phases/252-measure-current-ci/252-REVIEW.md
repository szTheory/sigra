---
phase: 252-measure-current-ci
reviewed: 2026-10-13T00:42:04Z
depth: standard
files_reviewed: 21
files_reviewed_list:
  - .github/workflows/ci.yml
  - scripts/ci/ci-exunit-timing.test.sh
  - scripts/ci/ci-measure-report.sh
  - scripts/ci/ci-measure-report.test.sh
  - scripts/ci/ci-measure-workflow.test.mjs
  - scripts/ci/ci-metrics-security.test.py
  - scripts/ci/ci-playwright-report.mjs
  - scripts/ci/ci-playwright-report.test.mjs
  - scripts/ci/ci-run-metrics-comparison.test.sh
  - scripts/ci/ci-run-metrics-replay.test.mjs
  - scripts/ci/ci-run-metrics.sh
  - scripts/ci/ci-run-metrics.test.sh
  - scripts/ci/ci_metrics_security.py
  - scripts/ci/exunit_timing_contract.py
  - scripts/ci/exunit_timing_contract_test.py
  - scripts/ci/sigra-dep-off.sh
  - scripts/ci/test-sigra-dep-off.sh
  - test/example/priv/playwright/playwright.config.ts
  - test/sigra/planning/ci_timing_formatter_test.exs
  - test/support/ci_timing_formatter.ex
  - test/test_helper.exs
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 252: Code Review Report

**Reviewed:** 2026-10-13T00:42:04Z  
**Depth:** standard  
**Files Reviewed:** 21  
**Status:** issues_found

## Summary

The review found one measurement-contract defect and one misleading artifact diagnostic. The snapshot collector can calculate a required-result wait using a changed set of required checks, and a failed artifact download can still be recorded as verified metadata. No source files were changed; no tests were run as part of this read-only review.

## Narrative Findings (AI reviewer)

### CR-01: BLOCKER — Snapshot replay accepts a changed required-check set

**File:** `scripts/ci/ci-run-metrics.sh:838`

**Issue:** `collect_window` copies required contexts only from the rules endpoint and does not compare them with the five approved contexts or use the branch-protection fallback implemented by `run_preflight`. Later, `source_bound_full_pr` calculates the endpoint from whatever non-empty set the snapshot contains, and replay can report that wait as measured even when an enforced context was removed or renamed. This violates the contract that a changed set must make the affected measurement unknown. Classic branch protection can also be reported as ready by preflight while the collection records an empty required-context set and cannot produce the measurement.

**Fix:** Derive the collected context set from the live effective rules, falling back to branch-protection contexts when that endpoint has no required checks. Compare the resulting set with the approved names during collection, persist `required_rules_changed` and its expected/actual values, and make replay return an unknown required-result wait whenever the sets differ.

### WR-01: WARNING — Failed artifact downloads retain a `verified` result

**File:** `scripts/ci/ci-run-metrics.sh:717-727`

**Issue:** When artifact metadata passes validation but `api_download_no_follow` fails, the `else` branch copies `artifact_status` into `artifact_record`. That status is `verified`, even though the archive was never fetched and its bytes were not checked against the advertised digest. The failure-family diagnostic therefore reports a stronger result than the evidence supports.

**Fix:** If the download fails, set the record to `status: "unknown"` and include the download stop reason. Reserve `verified` for a downloaded archive whose digest has been checked; use `accepted` only after safe extraction succeeds.

---

_Reviewed: 2026-10-13T00:42:04Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
