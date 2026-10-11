---
phase: 251
fixed_at: 2026-10-11T23:56:39Z
review_path: .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-REVIEW.md
iteration: 1
findings_in_scope: 4
fixed: 4
skipped: 0
status: all_fixed
---

# Phase 251: Code Review Fix Report

**Fixed at:** 2026-10-11T23:56:39Z  
**Source review:** `.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-REVIEW.md`  
**Iteration:** 1

**Summary:**
- Findings in scope: 4
- Fixed: 4
- Skipped: 0

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

**Files modified:** `verify-v149-traceability.mjs`, `verify-v149-traceability.test.mjs`  
**Status:** fixed: requires human verification  
**Commits:** `0c2ad145a319187f91b631e07302de916876cbd6`, `e59a5c47c2afdfea78402496bd3d1a6114afb865`, `3127a7eb2acb4d0949fe149c504b710cd3681d3c`  
**Applied fix:** The audit resolves each named preservation ref to a commit and requires that commit to equal the recorded expected commit. It reads the record through the resolved ref and matches the reference fields, decision, reason, source identity, captured item, and dirty source-byte hash against the observed disposition.

**RED/GREEN proof:** Before the fix, READY-02 remained satisfied when the named ref was nonexistent but the commit object stayed readable. The regression also rejects wrong resolved commits, changed decisions/reasons, and changed source identity.

## Verification

Verification ran in the main checkout because `.planning/config.json` sets `workflow.use_worktrees=false`.

- `verify-247-readiness.test.mjs`: 54 passed, 0 failed.
- `verify-v149-traceability.test.mjs`: 31 passed, 2 failed. The two existing Nyquist assertions expect Phase 251 to be validated; the current `251-VALIDATION.md` classifies it as `not_validated`.
- `validate-release-readiness.test.mjs`: 31 passed, 0 failed.
- `verify-247-readiness.mjs --check-251`: valid; packet SHA-256 `fc1ff22f496c41b6baf01c0ec15480dd3cbaecdc6f94fecf769feab414910140`, capture ID `phase251-939607ff3f17e03b22aa`.
- `verify-v149-traceability.mjs --check-sources`: exit 0; source-derived audit is `gaps_found` at 8/9, with READY-01 unsatisfied and READY-02 satisfied. It preserves the missing published README link, missing published guide, and absent trusted historical approval.
- `verify-v149-traceability.mjs --check-audit .planning/v1.49-MILESTONE-AUDIT.md`: exit 1 because the checked-in audit does not match the new complete source-derived rendering. The canonical audit was outside this fixer's ownership and remains for root reconciliation.

Machine-readable RED/GREEN evidence and exact test/check outcomes are recorded in [251-CR04-CR07-REGRESSION-RECEIPT.json](251-CR04-CR07-REGRESSION-RECEIPT.json).

## Skipped Issues

None.

---

_Fixed: 2026-10-11T23:56:39Z_  
_Fixer: the agent (gsd-code-fixer)_  
_Iteration: 1_
