---
phase: 251
fixed_at: 2026-10-12T00:32:12Z
review_path: .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-REVIEW.md
iteration: 4
findings_in_scope: 1
fixed: 1
skipped: 0
status: all_fixed
---

# Phase 251: Code Review Fix Report

**Fixed at:** 2026-10-12T00:32:12Z
**Source review:** `.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-REVIEW.md`
**Iteration:** 4

**Summary:**
- Residual finding in scope: 1 (CR-08)
- Fixed: 1
- Skipped: 0
- Earlier fixes remain in commits `8596fa340`, `266a28d57`, `9c92f1052`, and `167b59a586b4035f01b9d2a51b3dda9f3b9faceb`. The exact iteration-3 report bytes were preserved and read back at `refs/heads/phase251-review-fix-iteration3-preserved`, commit `714d24967fc64bcea9dbc33d196499037ad81b70`, SHA-256 `b3892e953124123eafdeeee03ed33c5fe4f91815e7490d1c39e9ca44c945f799`.

## Fixed Issues

### CR-07: [BLOCKER] T-251-14: Preservation validation ignores the named ref and record decision

**Files modified:** `verify-247-readiness.mjs`, `verify-v149-traceability.mjs`, `verify-v149-traceability.test.mjs`
**Commit:** `167b59a586b4035f01b9d2a51b3dda9f3b9faceb`
**Applied fix:** The auditor now chooses dirty-path validation from membership in the captured dirty-item set and requires the captured row to be `dirty_path`. It binds worktree path, head, branch, path, original path, status, readability, and byte digest to the disposition and preserved record. Deletion tombstones are required from the captured dirty status, so a relabeled disposition cannot downgrade a deletion to a modification. The owner capture writer now records branch and original-path metadata in new preservation records.

**RED/GREEN proof:** Two coherent immutable-record regressions reproduced the bypasses against the pre-fix auditor: a dirty item relabeled as `committed_path` with its base64 removed, and a captured ` D` item represented as ` M` with its tombstone removed. Both left READY-02 satisfied before the fix and are rejected afterward. Additional controls reject wrong worktree, head, path, original path, and branch. Valid modification, empty-byte payload with the exact empty digest, and correctly bound deletion tombstone controls pass. The five current dirty records continue to pass the default proof reader.

### CR-08: [BLOCKER] T-251-14: Dirty preservation metadata can diverge from its captured status row

**Files modified:** `verify-v149-traceability.mjs`, `verify-v149-traceability.test.mjs`
**Commits:** `441489e126f7febe3b4abeb6d25eae4d308e0951`, `6e2058961`
**Applied fix:** The auditor derives a canonical dirty-row population from READY-02 worktree status entries, including worktree path, head, branch, status, path, original path, readability, and source digest. It requires full metadata equality for source-capture status rows, redundant dirty rows, and READY-02 status rows before validation. It also reconciles raw root status entries with parsed rows and passes only canonical-derived dirty items to immutable preservation validation.

**RED/GREEN proof:** Against pre-fix auditor `ea89df4c4`, a coherent immutable preservation record and rebound packet/report changed the dirty row's branch while retaining its valid ID; READY-02 remained satisfied. The new regression now rejects coherent changes to path, original path, omitted original path, status, worktree path/head/branch, source digest/readability, kind, and mismatched status metadata between the inventories. A valid original five-dirty-item proof, ordinary modification, empty-byte source, and correctly tombstoned deletion still pass.

The updated receipt is committed at `e15fe0432` and `16b612942` in `251-CR04-CR07-REGRESSION-RECEIPT.json`. The two Nyquist failures remain pending the root-owned Phase 251 validation refresh; `--check-audit` still reports stale canonical audit rendering for root reconciliation.

## Verification

Verification ran in the main checkout (`workflow.use_worktrees=false`).

- `node -c` passed for the modified verifier and test modules.
- `verify-247-readiness.test.mjs`: 54 passed, 0 failed.
- `verify-v149-traceability.test.mjs`: 39 passed, 2 failed. Both are existing Nyquist classification expectations for Phase 251; the tests expect `251-VALIDATION.md` to say `validated`, while that canonical root-owned file remains `not_validated`.
- `validate-release-readiness.test.mjs`: 31 passed, 0 failed.
- `verify-247-readiness.mjs --check-251`: exit 0, valid; packet SHA-256 `fc1ff22f496c41b6baf01c0ec15480dd3cbaecdc6f94fecf769feab414910140`, capture ID `phase251-939607ff3f17e03b22aa`.
- `verify-v149-traceability.mjs --check-sources`: exit 0; 8/9 requirements, READY-01 unsatisfied and READY-02 satisfied.
- `verify-v149-traceability.mjs --check-audit .planning/v1.49-MILESTONE-AUDIT.md`: exit 1; canonical milestone audit rendering is stale. Root owns refreshing it.

The source and regression changes are committed; this updated report remains uncommitted for root reconciliation.

---

_Iteration: 4_
_Fixer: the agent (gsd-code-fixer)_

## Automatic Independent Verification

The earlier independent security audit verified CR-04 through CR-07 with 22/22 registered mitigations closed. CR-08 has an added independent recheck pending root reconciliation. Evidence from the earlier audit: `251-SECURITY-FINAL-CHECKS.json`, including 16 preservation controls, five real dirty-record readbacks, all 23 source assertion predicates, and seven targeted tests. Project AGENTS.md replaces human verification with deterministic proof.
