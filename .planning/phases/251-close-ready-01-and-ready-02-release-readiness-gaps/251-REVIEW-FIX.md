---
phase: 251
fixed_at: 2026-10-12T00:08:00Z
review_path: .planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-REVIEW.md
iteration: 2
findings_in_scope: 2
fixed: 2
skipped: 0
status: all_fixed
---

# Phase 251: Code Review Fix Report

**Fixed at:** 2026-10-12T00:08:00Z
**Source review:** `.planning/phases/251-close-ready-01-and-ready-02-release-readiness-gaps/251-REVIEW.md`
**Iteration:** 2

**Summary:**
- Residual findings in scope: 2
- Fixed: 2
- Skipped: 0
- Iteration 1 fixes remain in commit `8596fa340`; its exact report bytes are preserved at `refs/heads/phase251-review-fix-iteration1` (SHA-256 `47387f35ef3aecbe8e9ce1351a7ff724bd1ce63a805aca127f96cf6e07340bed`).

## Fixed Issues

### CR-07: [BLOCKER] T-251-14: Preservation validation ignores the named ref and record decision

**Files modified:** `verify-v149-traceability.mjs`, `verify-v149-traceability.test.mjs`
**Commit:** `266a28d57`
**Applied fix:** The independent audit now strictly decodes canonical base64 source bytes and hashes the decoded bytes against both the immutable preservation record digest and the captured dirty-item digest. It rejects unreadable or noncanonical payloads. Empty file payloads remain valid when their empty-byte digest matches. Deleted paths require a tombstone bound to the observed worktree, head, status, path, and captured preimage digest. The five current dirty records were checked through the default Git object reader; all decoded payloads match their recorded and captured hashes.

**RED/GREEN proof:** The RED fixture created a real forged Git commit/ref and coherently rebound the record hash, preservation reference, owner packet, report binding, and traceability digest while changing one byte in `source_bytes_base64`. Before the fix, READY-02 remained satisfied. After the fix, the independent audit rejects the same fixture. The fixture deletes its temporary ref in `finally`.

### Correctness gap: `candidate_package_version_requirement` was declared but missing from both content predicate switches

**Files modified:** `verify-247-readiness.mjs`, `verify-v149-traceability.mjs`, `verify-v149-traceability.test.mjs`
**Commit:** `266a28d57`
**Applied fix:** The owner verifier and independent audit each implement a byte-derived candidate package predicate requiring the `mix.exs` version to be `1.6.0` and the package version field to reference that version. A regression asserts every declared package assertion ID has a case in both switches.

**RED/GREEN proof:** The candidate `mix.exs` 1.6.0 bytes failed the previously missing predicate before the fix; the coherent version control also confirmed that 1.5.0 must fail. After the fix, both verifier implementations accept the actual 1.6.0 bytes and reject the 1.5.0 control.

## Verification

Verification ran in the main checkout (`workflow.use_worktrees=false`).

- `node -c` passed for both modified verifier modules.
- `verify-247-readiness.test.mjs`: 54 passed, 0 failed.
- `verify-v149-traceability.test.mjs`: 34 passed, 2 failed. Both failures are existing Nyquist classification expectations for Phase 251; the tests expect `251-VALIDATION.md` to say `validated`, while the canonical file remains `not_validated` and is root-owned.
- `validate-release-readiness.test.mjs`: 31 passed, 0 failed.
- Default independent audit verified all 5 current dirty preservation records: each strict base64 decode matched both source-byte SHA-256 values, and READY-02 remained satisfied.
- `verify-247-readiness.mjs --check-251`: exit 0, valid; packet SHA-256 `fc1ff22f496c41b6baf01c0ec15480dd3cbaecdc6f94fecf769feab414910140`, capture ID `phase251-939607ff3f17e03b22aa`.
- `verify-v149-traceability.mjs --check-sources`: exit 0; 8/9 requirements, READY-01 unsatisfied and READY-02 satisfied.
- `verify-v149-traceability.mjs --check-audit .planning/v1.49-MILESTONE-AUDIT.md`: exit 1; the canonical audit rendering is stale. Root owns refreshing that artifact.

The source and regression changes are committed; this updated report remains uncommitted for root reconciliation.

---

_Iteration: 2_
_Fixer: the agent (gsd-code-fixer)_
