---
phase: 251
fixed_at: 2026-10-12T00:17:00Z
review_path: .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-REVIEW.md
iteration: 3
findings_in_scope: 1
fixed: 1
skipped: 0
status: all_fixed
---

# Phase 251: Code Review Fix Report

**Fixed at:** 2026-10-12T00:17:00Z
**Source review:** `.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-REVIEW.md`
**Iteration:** 3

**Summary:**
- Residual finding in scope: 1
- Fixed: 1
- Skipped: 0
- Earlier fixes remain in commits `8596fa340`, `266a28d57`, and `9c92f1052`. The iteration-2 report bytes are preserved at `refs/heads/phase251-review-fix-iteration2` (SHA-256 `cc22eaadab95922f6dcc090794dab08b21e59bab647600edce0be9266a31aa3b`).

## Fixed Issues

### CR-07: [BLOCKER] T-251-14: Preservation validation ignores the named ref and record decision

**Files modified:** `verify-247-readiness.mjs`, `verify-v149-traceability.mjs`, `verify-v149-traceability.test.mjs`
**Commit:** `167b59a586b4035f01b9d2a51b3dda9f3b9faceb`
**Applied fix:** The auditor now chooses dirty-path validation from membership in the captured dirty-item set and requires the captured row to be `dirty_path`. It binds worktree path, head, branch, path, original path, status, readability, and byte digest to the disposition and preserved record. Deletion tombstones are required from the captured dirty status, so a relabeled disposition cannot downgrade a deletion to a modification. The owner capture writer now records branch and original-path metadata in new preservation records.

**RED/GREEN proof:** Two coherent immutable-record regressions reproduced the bypasses against the pre-fix auditor: a dirty item relabeled as `committed_path` with its base64 removed, and a captured ` D` item represented as ` M` with its tombstone removed. Both left READY-02 satisfied before the fix and are rejected afterward. Additional controls reject wrong worktree, head, path, original path, and branch. Valid modification, empty-byte payload with the exact empty digest, and correctly bound deletion tombstone controls pass. The five current dirty records continue to pass the default proof reader.

## Verification

Verification ran in the main checkout (`workflow.use_worktrees=false`).

- `node -c` passed for the modified verifier and test modules.
- `verify-247-readiness.test.mjs`: 54 passed, 0 failed.
- `verify-v149-traceability.test.mjs`: 38 passed, 2 failed. Both are existing Nyquist classification expectations for Phase 251; the tests expect `251-VALIDATION.md` to say `validated`, while that canonical root-owned file remains `not_validated`.
- `validate-release-readiness.test.mjs`: 31 passed, 0 failed.
- `verify-247-readiness.mjs --check-251`: exit 0, valid; packet SHA-256 `fc1ff22f496c41b6baf01c0ec15480dd3cbaecdc6f94fecf769feab414910140`, capture ID `phase251-939607ff3f17e03b22aa`.
- `verify-v149-traceability.mjs --check-sources`: exit 0; 8/9 requirements, READY-01 unsatisfied and READY-02 satisfied.
- `verify-v149-traceability.mjs --check-audit .planning/v1.49-MILESTONE-AUDIT.md`: exit 1; canonical milestone audit rendering is stale. Root owns refreshing it.

The source and regression changes are committed; this updated report remains uncommitted for root reconciliation.

---

_Iteration: 3_
_Fixer: the agent (gsd-code-fixer)_
