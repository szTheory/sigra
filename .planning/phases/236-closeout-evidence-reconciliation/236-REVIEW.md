---
phase: 236-closeout-evidence-reconciliation
reviewed: 2026-08-04T16:45:00-04:00
depth: standard
files_reviewed: 3
files_reviewed_list:
  - scripts/planning/phase-236-audit-snapshot.exs
  - scripts/planning/phase-236-audit-snapshot-test.exs
  - test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 236: Code Review Report

**Reviewed:** 2026-08-04T16:45:00-04:00
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed the snapshot utility, its focused ExUnit coverage, and the Phase 236 reconciliation contract. The new per-commit collector handles transient changes in a linear history, but it does not inspect merge-commit changes. This leaves the scope fence bypassable through a forbidden path introduced during merge conflict resolution.

## Critical Issues

### CR-01: Merge-commit changes bypass the committed-range scope fence

**Classification:** BLOCKER
**File:** `/Users/jon/projects/sigra/test/sigra/planning/phase_236_closeout_evidence_reconciliation_contract_test.exs:724`
**Issue:** `git diff-tree` emits no diff for a merge commit unless a merge-diff mode is requested. The collector calls it once per commit without `-m`, so `rev-list` includes a merge commit but the path set omits every path changed only by that merge's resolution. A forbidden path can therefore be added or altered while resolving a conflict, retained at the endpoint, and still pass `validate_scope_paths!/2`. This violates the stated fail-closed, every-commit scope fence.

**Fix:** Request per-parent merge diffs and preserve the deduplicated union; add a temporary-repository regression that introduces a forbidden change in a non-fast-forward merge resolution.

```elixir
command_runner.(repository, "diff-tree", [
  "--no-commit-id", "--name-only", "-r", "-m", commit
])
```

The regression should assert that `changed_paths_between!/3` returns the forbidden path and that `validate_scope_paths!/2` raises.

---

_Reviewed: 2026-08-04T16:45:00-04:00_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
