---
phase: 251-close-ready-01-and-ready-02-release-readiness-gaps
reviewed: 2026-10-11T21:25:51Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs
  - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs
  - .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.test.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs
findings:
  critical: 3
  warning: 0
  info: 0
  total: 3
status: issues_found
---

# Phase 251: Code Review Report

**Reviewed:** 2026-10-11T21:25:51Z  
**Depth:** standard  
**Files Reviewed:** 6  
**Status:** issues_found

## Summary

Reviewed the six readiness and traceability source/test files in the supplied Phase 251 scope. Three blockers can produce or preserve incorrect READY verdicts: final inventory reuses stale PR dispositions after identity changes, READY-01 package checks are not bound to the evidence they claim to evaluate, and READY-02 capture can overlook dirty secondary worktrees.

## Critical Issues

### CR-01: [BLOCKER] Final inventory carries old PR dispositions onto changed identities

**File:** `.planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs:761-764`
**Issue:** When a live PR already has a saved row, `finalInventory` copies its old disposition and only overwrites `head_sha` and `base`. It leaves `base_sha` and the disposition's evidence untouched. `validateFinalReadiness` then compares inventory to live PRs using only number, head SHA, and base ref, and checks only that disposition fields are nonempty (`:426-432`). A PR can therefore change head or base commit and still inherit a disposition made for its earlier identity; the fresh inventory can pass with stale reasoning and preservation evidence.
**Fix:** Bind every disposition to the complete captured identity, including `base_sha`, and invalidate or recapture the disposition whenever any identity field changes. Compare full identities in final validation and require the disposition identity to match the live row.

### CR-02: [BLOCKER] READY-01 accepts package checks with unbound evidence text

**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:106-114`
**Issue:** `namedPackageCheckFailure` accepts a check when its result is `pass`, its `source_identity` and `evidence_detail` are any nonempty strings, and its finding text begins `No finding:`. It never verifies that the check's identity or evidence points to the source path(s) relevant to that check. Those results directly contribute to `acceptance_satisfied` and the READY-01 verdict (`:153-163`). The independent traceability check has the same gap: it validates generic nonempty evidence text and a `No finding` prefix (`verify-v149-traceability.mjs:446-449`). A fabricated or accidentally mismatched set of “pass” rows can therefore satisfy READY-01 without demonstrating package-version, tag, guide, compatibility, or adopter checks against the claimed files. The test fixture uses the same generic identity/detail for every package check (`verify-247-readiness.test.mjs:331-335`), so it does not guard this boundary.
**Fix:** Define the expected source identities and paths for each named check, verify each check references those exact records, and derive/check its evidence from the recorded source bytes rather than accepting free-form “No finding” text.

### CR-03: [BLOCKER] READY-02 can pass while a secondary worktree is dirty

**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:265-270`
**Issue:** `localInheritedSnapshot` records status for every worktree, but the READY-02 pass predicate only checks that every worktree status was readable. Its inherited-work join is built from commits and raw status in the current checkout (`:267-270`), so dirty files in another worktree never enter the join and do not prevent `ready02Satisfied` from becoming true. The packet can consequently publish READY-02 as satisfied despite captured secondary-worktree changes; the traceability verifier later rejects such a packet because it requires all worktrees to be clean (`verify-v149-traceability.mjs:475-488`), leaving the owner verdict and its independent audit inconsistent.
**Fix:** Include every worktree's status entries in the inherited-work population and disposition join, or require every captured worktree to have an empty status before READY-02 can pass.

---

_Reviewed: 2026-10-11T21:25:51Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
