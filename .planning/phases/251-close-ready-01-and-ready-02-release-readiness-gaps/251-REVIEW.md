---
phase: 251-close-ready-01-and-ready-02-release-readiness-gaps
reviewed: 2026-10-12T00:22:56Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs
  - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 251: Code Review Report

**Reviewed:** 2026-10-12T00:22:56Z  
**Depth:** standard  
**Files Reviewed:** 6  
**Status:** issues_found

## Summary

Re-reviewed all six scoped source and test files and checked the regression receipt, final security checks, and fix report against the current implementation. The CR-04 through CR-07 bypasses are addressed: source predicates read immutable blobs, inherited populations are recomputed from captured status rows, and preservation refs, decisions, bytes, dirty kind, and deletion evidence are checked. One related READY-02 bypass remains: the auditor joins dirty items to captured status entries by ID but does not bind the dirty item's other identity fields to the canonical worktree status row. An isolated clone reproduction changed a captured dirty path while retaining its original ID and consistently updated disposition and preservation record; the audit still returned READY-02 satisfied at 8/9. READY-01 remains unsatisfied for its documented historical evidence gaps, which are not implementation defects.

## Critical Issues

### CR-08: [BLOCKER] T-251-14: Dirty preservation metadata can diverge from its captured status row

**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs:753-790`  
**Issue:** `expectedInheritedIds` derives canonical dirty IDs from each worktree's status entries, but it checks `inherited_dirty_entries` against that population using only `row.id`. Later, `preservationRecordsMatch` validates the dirty row's `worktree_path`, `status`, `path`, branch, original path, and byte digest against the disposition and immutable preservation record, but never checks those fields against the status entry that generated the ID. A packet can therefore retain the valid original ID while changing the separately stored dirty row's path or status and making the disposition and preservation record agree with the forged metadata. I reproduced this in an isolated clone by changing the dirty row path to `forged/path-that-never-appeared-in-status.txt`, preserving its original ID, and updating the disposition and immutable record; the audit still accepted READY-02 and reported 8/9.
**Fix:** Build a canonical map from each worktree status entry keyed by its computed dirty ID, then require the full dirty row to equal that canonical identity, including `kind`, worktree path and head, branch, status, path, original path, readability, and byte digest. Pass the canonical rows into preservation validation so record metadata is compared to the captured status source as well as to the disposition. Keep explicit controls for empty-file bytes and deletion tombstones.

---

_Reviewed: 2026-10-12T00:22:56Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
