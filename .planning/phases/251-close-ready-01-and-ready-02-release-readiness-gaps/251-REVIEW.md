---
phase: 251-close-ready-01-and-ready-02-release-readiness-gaps
reviewed: 2026-10-11T23:16:30Z
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
  critical: 4
  warning: 0
  info: 0
  total: 4
status: issues_found
---

# Phase 251: Code Review Report

**Reviewed:** 2026-10-11T23:16:30Z  
**Depth:** standard  
**Files Reviewed:** 6  
**Status:** issues_found

## Summary

Reviewed the six Phase 251 scoped readiness and traceability scripts and tests. Four independently reproducible acceptance bypasses remain: READY-01 package assertions can be synthesized from result labels without checking source bytes, the independent audit trusts those assertion fields and source digests without reading the cited blobs, READY-02 does not join every captured worktree status item into its disposition population, and its preservation check ignores the named ref and decision/source-byte proof. The current READY-01 `authorization_pending` state is a separate historical evidence gap; these findings describe unsafe paths that could accept fabricated future evidence. In-memory audit reproductions still reported READY-02 satisfied at 8/9 after each READY-02 mutation.

## Critical Issues

### CR-04: [BLOCKER] T-251-11: Package source assertions are generated from the claimed result

**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:225-232`  
**Issue:** `bindPhase251PackageSourceEvidence` creates each assertion's `result` and `actual` from `check.result`; for a readable source, `result: 'pass'` yields `actual: true` without examining the cited bytes. `namedPackageCheckFailure` then validates that these generated fields are internally consistent and path-bound, not that the asserted package, guide, or README condition is present in the source. A check falsely labeled pass can therefore satisfy the owner package gate. A direct in-memory reproduction with a passing README check and source metadata produced a passing `candidate_readme_guide_link` assertion without reading README content.
**Fix:** Compute each named assertion by parsing the exact source bytes for its predicate. Make source reading return the bytes (or a verified parsed result) and have `namedPackageCheckFailure` reject assertions unless their values are derived from that source content.

### CR-05: [BLOCKER] T-251-12: Independent audit trusts fabricated source digests and assertion booleans

**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs:509-520`  
**Issue:** `sourceBytesComplete` only checks stored status fields and equality between stored Git/API blob IDs and stored SHA-256 values. The following source-reference and assertion checks at lines 536-567 compare packet fields to each other and require `actual: true`; they never read `commit:path`, compute a blob digest, or evaluate the named predicate. The existing `ownerEvidenceFixture` builds READY-01 source rows with synthetic blob IDs and digests and passing assertions, and the independent audit accepts that fixture as satisfied. A forged packet can claim source bytes that were never present at the named commit and manufacture all named check results.
**Fix:** For each expected source, read the blob from the exact commit, recompute its Git blob OID and SHA-256, and derive the mapped assertion from those bytes. Reject missing blobs and do not treat packet booleans or API/Git equality claims as content proof.

### CR-06: [BLOCKER] T-251-13: READY-02 does not require every captured worktree item in the join

**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs:602-633`  
**Issue:** `completeWorktrees` verifies that each listed status entry has a readable source hash, but `inheritedMatches` only compares `inheritedObserved` with `inheritedDispositions` and their preservation references. It never derives the expected dirty-path identities from `source_capture.local_inherited_work.worktrees[*].status_entries` and compares that complete population to the join. Removing the same dirty-path ID from `observedIds`, `dispositionIds`, and `preservationRefs` left those join arrays mutually consistent; the independent audit still reported READY-02 satisfied and 8/9.
**Fix:** Recompute the inherited-work identity set from every captured worktree's committed and status-entry population, then require exact equality with join observations, dispositions, and preservation references. Reject omitted, added, or duplicate identities.

### CR-07: [BLOCKER] T-251-14: Preservation validation ignores the named ref and record decision

**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs:406-443`  
**Issue:** `preservationRecordsMatch` validates that `ref` is merely a string, then reads `commitSha:recordPath` through `git cat-file --batch`. It does not resolve `ref` to confirm it names `commitSha`, and it checks the stored record's ID but not its disposition decision or captured source-byte digest against the join. Replacing a live preservation ref with `refs/heads/definitely-nonexistent-phase251` still left the in-memory audit at READY-02 satisfied and 8/9 because the commit object remained readable.
**Fix:** Resolve `ref^{commit}` and require it to equal `commitSha`; read the record through the resolved ref. Compare the record ID, decision, and captured source-byte identity/digest with the corresponding disposition and observed work item before accepting the join.

---

_Reviewed: 2026-10-11T23:16:30Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
