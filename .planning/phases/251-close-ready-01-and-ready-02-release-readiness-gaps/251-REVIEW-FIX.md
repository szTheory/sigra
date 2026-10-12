---
phase: 251
fixed_at: 2026-10-12T00:32:12Z
review_path: .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-REVIEW.md
iteration: 4
findings_in_scope: 5
fixed: 5
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

### CR-04: [BLOCKER] T-251-11: Package source assertions are generated from the claimed result

**Files modified:** `verify-247-readiness.mjs`, `verify-247-readiness.test.mjs`  
**Status:** fixed: requires human verification  
**Commits:** `4c4480e277fb399ae2263feb68cd97950bcf3d95`, `e11f9b5208232abde415f59c9eacdeb942f845f3`, `75d41c643456d4a751b3c71a34686a62ac24667c`  
**Applied fix:** The owner evaluator now reads every required immutable `commit:path` blob, checks its Git blob OID and SHA-256 against the trusted source record, and derives the named content predicate. Stored result labels and assertion booleans cannot establish a pass. Missing or unreadable bytes fail closed; a trusted exact-commit 404 remains a missing result. Fixture controls use actual Git objects and bytes.

**RED/GREEN proof:** The pre-fix verifier emitted `published_readme_guide_link.actual=true` when the check label was forged to `pass`, although the exact published README blob lacked the guide link. The regression now forges the same result and expects the owner evaluator to reject it. See [the regression receipt](251-CR04-CR07-REGRESSION-RECEIPT.json).

### CR-05: [BLOCKER] T-251-12: Independent audit trusts fabricated source digests and assertion booleans

**Files modified:** `verify-v149-traceability.mjs`, `verify-v149-traceability.test.mjs`  
**Status:** fixed: requires human verification  
**Commits:** `85e30ec6f76412296e64d904d86b156c56a8afd6`, `3127a7eb2acb4d0949fe149c504b710cd3681d3c`  
**Applied fix:** The independent audit now reads every expected source blob from the exact commit/path, recomputes its Git OID and SHA-256, and independently derives the assertion values before accepting a READY-01 pass. Rebound packet, report, and traceability hashes do not make fabricated blob metadata or booleans valid.

**RED/GREEN proof:** Before the audit fix, the forged source fixture left READY-01 satisfied. The regression now verifies that the same claim is unsatisfied when the audit reads the named immutable objects. The fixture preserves real source OIDs and hashes except for the deliberate fabricated attack rows.

### CR-06: [BLOCKER] T-251-13: READY-02 does not require every captured worktree item in the join

**Files modified:** `verify-v149-traceability.mjs`, `verify-v149-traceability.test.mjs`  
**Status:** fixed: requires human verification  
**Commits:** `0c2ad145a319187f91b631e07302de916876cbd6`, `e59a5c47c2afdfea78402496bd3d1a6114afb865`, `3127a7eb2acb4d0949fe149c504b710cd3681d3c`  
**Applied fix:** The audit derives the expected set from inherited commits, paths, and every dirty `status_entry` in both the source capture and READY-02 inventory. It requires exact, duplicate-free equality with observed IDs, disposition IDs, source dispositions, and preservation references; missing, null, or duplicate identities fail closed.

**RED/GREEN proof:** Before the fix, READY-02 remained satisfied after a dirty identity was removed from all three join arrays while packet and owner hashes were rebound. The same retained regression now makes READY-02 unsatisfied.


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

## Consolidated Closeout Evidence

Earlier CR-04–CR-06 fix records were read back from commit 8596fa340 and retained above. The final clean independent code review and `251-SECURITY-CLOSEOUT-CHECKS.json` verify CR-04 through CR-08 together. Current regression gate: 213 Node tests and 250 Elixir tests passed; source audit remains 8/9 because READY-01 is unsatisfied. All human-verification suggestions are superseded by committed automatic proof under project AGENTS.md.
