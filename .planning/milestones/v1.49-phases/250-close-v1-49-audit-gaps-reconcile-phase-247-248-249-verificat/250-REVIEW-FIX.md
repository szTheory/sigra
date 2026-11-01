---
phase: "250"
fixed_at: "2026-10-10T17:31:12Z"
review_path: .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-REVIEW.md
iteration: 3
findings_in_scope: 1
fixed: 1
skipped: 0
status: all_fixed
verification_location: main_checkout
---

# Phase 250: Code Review Fix Report

**Fixed at:** 2026-10-10T17:31:12Z
**Source review:** `250-REVIEW.md`  
**Iteration:** 3 (recheck 2 fix; iterations 1 and 2 remain recorded below)

**Iteration 1 summary:**
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

### CR-05: Traceability trusts requirement statuses embedded in owner reports

**Files modified:** `verify-v149-traceability.mjs`, `verify-v149-traceability.test.mjs`  
**Commit:** `698f5d6cc`  
**Applied fix:** Recompute Phase 248/249 requirement verdicts with the owner evaluators, run their report checks, and report embedded marker drift as a blocker. A forged satisfied marker against an unsatisfied source verdict is rejected.  
**Tests:** `node --test .../verify-v149-traceability.test.mjs` (10/10 passed).  

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

### WR-02: The release verifier makes a network request to an unvalidated receipt URL

**Files modified:** `verify-249-release.mjs`, `verify-249-release.test.mjs`  
**Commit:** `abc187698`  
**Applied fix:** Validate the source path and exact HTTPS GitHub blob URL before issuing the source request. Reject credentials, ports, query strings, encoded or traversal paths, and alternate hosts; disable redirects and pass the URL after `--`. Invalid references return blocked without making the source request.  
**Tests:** `node --test .../verify-249-release.test.mjs` (9/9 passed); `node --check .../verify-249-release.mjs`.

## Iteration 2: Independent Recheck Fixes

**Findings in scope:** 3
**Fixed:** 3
**Skipped:** 0

### CR-01: Phase 248 capture omits retrieval evidence required by its evaluator

**Files modified:** `verify-248-release.mjs`, `verify-248-release.test.mjs`
**Commit:** `866dfd735`
**Applied fix:** `captureSnapshot()` now captures the failure artifact from the source run and cancellation artifact from the observer run. It verifies unique listing membership, owner, name, expiry, and ZIP digest, then parses the expected receipt and binds its complete canonical JSON to the producer proof and source/observer run identities. Both resulting `artifact_retrieved` records carry the content SHA-256, artifact ID/name/digest, and validated receipt.
**Tests:** `node --test .../verify-248-release.test.mjs` (10/10 passed). Local injected GitHub/unzip responses exercise valid artifacts, source identity drift, observer identity drift, wrong artifact owner, and malformed receipt JSON.

### CR-03: Phase 247 captures CI metadata for a different run than it validates

**Files modified:** `verify-247-readiness.mjs`, `verify-247-readiness.test.mjs`
**Commit:** `e806ccf07`
**Applied fix:** One proposal-first exact-CI identity resolver feeds both evaluation and capture. Capture queries that exact run and attempt plus its `ci-gate` job, checks run ID/attempt/SHA/workflow identity before creating an authoritative record, and retains a bounded diagnostic on mismatch.
**Tests:** `node --test .../verify-247-readiness.test.mjs` (14/14 passed). The proposal run differs from saved readiness CI; a complete exact proposal receipt joins, while an authoritative SHA mismatch is blocked.

### WR-03: Malformed exact-head CI JSON crashes capture

**Files modified:** `verify-247-readiness.mjs`, `verify-247-readiness.test.mjs`
**Commit:** `e806ccf07`
**Applied fix:** Parse the standalone receipt once; malformed JSON yields `exact_head_ci_receipt_invalid`, with no retry parse and no raw parser detail. Capture returns blocked evidence so reconciliation can still emit its report.
**Tests:** Same 14/14 readiness suite. A throwing malformed-input stub verifies one read, no metadata request, and a bounded diagnostic.

## Iteration 2 Verification

Focused capture suites passed from the main checkout: readiness 14/14 and Phase 248 release 10/10. `node --check` passed for both changed verifiers, and `git diff --check` passed. Tests use injected local tool responses; no hosted canary, workflow dispatch, release, publication, or network fixture was run.

The stored Phase 250 source snapshots and canonical owner reports remain untouched because they require new hosted evidence, including the already-consumed canary authorization. The source audit remains blocked by genuine missing evidence; no requirement or acceptance status was promoted.

## Iteration 3: Producer-Shape Recheck Fix

**Finding:** CR-01 — Phase 248 terminal receipt validation expected a nested `canary.*` receipt that the producer does not emit.
**Disposition:** Fixed.
**Files modified:** `verify-248-release.mjs`, `verify-248-release.test.mjs`
**Commit:** `d9c74aac0`
**Applied fix:** Capture, normalization, and evaluation now read the producer's actual top-level `probe_id` and `scenario`. Receipt identity is checked against source run metadata and its display title, controller proof, downloaded bytes, and source artifact listing. Producer artifact ID/name/digest/expiry must also match the captured authoritative listing. No alternate nested receipt schema is accepted.
**Automated evidence:** The test invokes `scripts/ci/release-receipt.sh --mode canary` with local failure and cancellation inputs, parses its serialized output, and passes those receipts through the capture helper, full snapshot evaluator, Phase 248 report check, and traceability recomputation. The positive path passes; missing and incorrect top-level probe/scenario values are rejected for both outcomes.
**Tests:** Phase 248 release suite 10/10 and traceability suite 10/10 passed. Syntax checks and `git diff --check` passed. No hosted probe, workflow dispatch, publication, or network fixture ran.

The stored snapshots and owner reports remain unchanged. The read-only audit and source evidence remain blocked by missing hosted proof; no acceptance or original-owner requirement was promoted.

## Iteration 3 Verification

Focused Phase 248 release and traceability suites passed from the main checkout (10/10 each). `node --check` passed for the changed verifier and test. The actual receipt producer ran only against temporary local fixtures; no hosted canary, workflow dispatch, release, publication, or network fixture was run.

Focused regression suites passed from the main checkout: readiness 12/12, Phase 248 release 9/9, Phase 249 release 9/9, traceability 10/10, and canary shell 34/34. JavaScript syntax checks for the changed verifiers and `bash -n` for the canary script passed. No hosted probe, workflow dispatch, release, publication, or network fixture was run.

The stored Phase 250 source snapshots and canonical owner reports were not refreshed: doing so would require new hosted evidence, including the already-consumed canary authorization. The current source audit was recomputed read-only and remains `gaps_found` at 5/9. `READY-01`, `READY-02`, `AUTO-02`, and `REL-02` remain blocked by absent or incomplete source proof. No owner requirement or acceptance status was promoted.

---

_Fixed: 2026-10-10T17:31:12Z_
_Fixer: the agent (gsd-code-fixer)_  
_Iteration: 3_
