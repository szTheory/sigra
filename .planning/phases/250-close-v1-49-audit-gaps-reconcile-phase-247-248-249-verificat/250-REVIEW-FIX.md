---
phase: "250"
fixed_at: "2026-10-10T17:08:40Z"
review_path: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-REVIEW.md
iteration: 1
findings_in_scope: 8
fixed: 8
skipped: 0
status: all_fixed
verification_location: main_checkout
---

# Phase 250: Code Review Fix Report

**Fixed at:** 2026-10-10T17:08:40Z  
**Source review:** `250-REVIEW.md`  
**Iteration:** 1

**Summary:**
- Findings in scope: 8
- Fixed: 8
- Skipped: 0

## Fixed Issues

### CR-01: Phase 248 cannot accept the current canary controller proof

**Files modified:** `verify-248-release.mjs`, `verify-248-release.test.mjs`  
**Commits:** `13d11e69a`, `27ddb4ea1`  
**Applied fix:** Normalize the controller's actual `status: pass` and `run_id` producer schema, join both terminal receipt identities to source records and authoritative Actions run metadata, and bind observer run/attempt/workflow identity. The valid complete proof fixture remains accepted; contradictory terminal outcome and source identity drift are rejected.  
**Tests:** `node --test .../verify-248-release.test.mjs` (9/9 passed); `node --check .../verify-248-release.mjs`.

### CR-02: READY verdicts omit required evidence blockers

**Files modified:** `verify-247-readiness.mjs`, `verify-247-readiness.test.mjs`  
**Commit:** `da7d33053`  
**Applied fix:** Build READY requirement verdicts from their complete relevant blocker sets, including source, readiness, diff, exact-CI, and capture-race failures. A candidate source-blob drift now makes READY-01 unsatisfied even when the commit object exists.  
**Tests:** `node --test .../verify-247-readiness.test.mjs` (12/12 passed).  
**Review status:** fixed; requires human verification of the requirement-to-blocker mapping.

### CR-03: Exact-head CI is accepted on file existence alone

**Files modified:** `verify-247-readiness.mjs`, `verify-247-readiness.test.mjs`  
**Commit:** `da7d33053`  
**Applied fix:** Parse the standalone receipt and join full head SHA, workflow, run, attempt, conclusion, job, and job result to authoritative Actions metadata. The valid exact-source receipt passes; a stale attempt or mismatched authoritative SHA fails closed.  
**Tests:** `node --test .../verify-247-readiness.test.mjs` (12/12 passed).

### CR-04: Inherited-work dispositions can be empty and still satisfy READY-02

**Files modified:** `verify-247-readiness.mjs`, `verify-247-readiness.test.mjs`  
**Commit:** `da7d33053`  
**Applied fix:** Require an explicit observed inherited-work ID population and join every observed ID to exactly one disposition with a decision and recoverable preservation identity. An explicitly observed empty population remains valid only with matching empty dispositions.  
**Tests:** `node --test .../verify-247-readiness.test.mjs` (12/12 passed).  
**Review status:** fixed; requires human verification of the requirement-to-population mapping.

### CR-05: Traceability trusts requirement statuses embedded in owner reports

**Files modified:** `verify-v149-traceability.mjs`, `verify-v149-traceability.test.mjs`  
**Commit:** `698f5d6cc`  
**Applied fix:** Recompute Phase 248/249 requirement verdicts with the owner evaluators, run their report checks, and report embedded marker drift as a blocker. A forged satisfied marker against an unsatisfied source verdict is rejected.  
**Tests:** `node --test .../verify-v149-traceability.test.mjs` (10/10 passed).  
**Review status:** fixed; requires human verification of the cross-report reconciliation logic.

### CR-06: A preservation reference can be absent while a disposition passes

**Files modified:** `verify-247-readiness.mjs`, `verify-247-readiness.test.mjs`  
**Commit:** `da7d33053`  
**Applied fix:** Require a non-empty preservation ref, commit, record path, content digest, and decision; resolve the ref and commit, read the referenced record bytes, verify its digest, and compare its identity. The positive fixture uses a real temporary Git ref and record.  
**Tests:** `node --test .../verify-247-readiness.test.mjs` (12/12 passed).

### WR-01: Canary proof validation does not bind all terminal outcomes and observer identity fields

**Files modified:** `scripts/ci/release-canary.sh`, `scripts/ci/release-canary.test.sh`  
**Commit:** `b300f227c`  
**Applied fix:** The standalone validator re-queries authoritative source and observer run records plus artifact listings, then binds conclusion, attempt, workflow, event, branch/ref, SHA, artifact ID/name/owner/digest/expiry, and embedded observer identity. Tests use only local `gh` fixtures and reject authoritative conclusion drift and observer-attempt mismatch.  
**Tests:** `bash -n scripts/ci/release-canary.sh`; `bash scripts/ci/release-canary.test.sh` (34/34 passed).  
**Review status:** fixed; requires human verification of the evidence-join logic.

### WR-02: The release verifier makes a network request to an unvalidated receipt URL

**Files modified:** `verify-249-release.mjs`, `verify-249-release.test.mjs`  
**Commit:** `abc187698`  
**Applied fix:** Validate the source path and exact HTTPS GitHub blob URL before issuing the source request. Reject credentials, ports, query strings, encoded or traversal paths, and alternate hosts; disable redirects and pass the URL after `--`. Invalid references return blocked without making the source request.  
**Tests:** `node --test .../verify-249-release.test.mjs` (9/9 passed); `node --check .../verify-249-release.mjs`.

## Verification

Focused regression suites passed from the main checkout: readiness 12/12, Phase 248 release 9/9, Phase 249 release 9/9, traceability 10/10, and canary shell 34/34. JavaScript syntax checks for the changed verifiers and `bash -n` for the canary script passed. No hosted probe, workflow dispatch, release, publication, or network fixture was run.

The stored Phase 250 source snapshots and canonical owner reports were not refreshed: doing so would require new hosted evidence, including the already-consumed canary authorization. The current source audit was recomputed read-only and remains `gaps_found` at 5/9. `READY-01`, `READY-02`, `AUTO-02`, and `REL-02` remain blocked by absent or incomplete source proof. No owner requirement or acceptance status was promoted.

---

_Fixed: 2026-10-10T17:08:40Z_  
_Fixer: the agent (gsd-code-fixer)_  
_Iteration: 1_
