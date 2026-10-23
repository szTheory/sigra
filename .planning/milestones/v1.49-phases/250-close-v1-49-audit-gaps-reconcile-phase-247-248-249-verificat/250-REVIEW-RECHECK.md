---
phase: 250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat
reviewed: 2026-10-10T17:13:15Z
depth: deep
files_reviewed: 10
files_reviewed_list:
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.test.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.test.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs
  - scripts/ci/release-canary.sh
  - scripts/ci/release-canary.test.sh
findings:
  critical: 2
  warning: 1
  info: 0
  total: 3
status: issues_found
---

# Phase 250: Independent Review Recheck

**Reviewed:** 2026-10-10T17:13:15Z  
**Depth:** deep  
**Files Reviewed:** 10  
**Status:** issues_found

## Summary

Rechecked the Phase 250 fixes against the producer code, the stored Phase 247–249 source artifacts and reports, and the focused fixtures. The population join, exact CI predicate, recomputed Phase 248/249 traceability verdicts, canary proof revalidation, and receipt URL allowlist address the reported forged-evidence and SSRF cases. The 5/9 milestone score and missing hosted canary evidence remain genuine evidence blockers; they are not implementation findings.

Three defects remain in the executable capture paths. The Phase 248 capture cannot produce the artifact-retrieval fields its own evaluator requires, and the Phase 247 capture queries a different CI run from the one it later requires. A malformed exact-head CI receipt can also escape the capture fallback and terminate the verifier.

## Critical Issues

### CR-01: Phase 248 capture omits retrieval evidence required by its own evaluator

**Classification:** BLOCKER  
**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.mjs:206-208`

**Issue:** `captureSnapshot()` constructs `canary.failure` and `canary.cancellation` with run metadata and artifact listings, but never sets either `artifact_retrieved` field. `evaluateSnapshot()` requires both fields to have `status: "passed"`, a SHA-256 digest, and a receipt identity at lines 282–283. The controller proof is downloaded and its embedded receipts are normalized, but that does not fill the separate fields checked by the evaluator. Therefore, even a valid producer proof and matching authoritative run/artifact records captured by this path cannot satisfy AUTO-02. The passing fixture at `verify-248-release.test.mjs:34-35` hand-adds the missing fields, so it does not exercise `captureSnapshot()`'s output shape.

**Fix:** Capture and digest-validate the terminal receipt artifact contents into the two `artifact_retrieved` records, or change the evaluator to validate the receipts actually captured from the controller proof and authoritative artifact records. Add a capture-shape test proving a complete valid producer artifact yields both required validated records.

### CR-03: Phase 247 captures CI metadata for a different run than it validates

**Classification:** BLOCKER  
**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:146-151,227-237`

**Issue:** The evaluator selects the expected exact-head CI run from `proposal.ci` first (lines 146–149), but `captureExactHeadCi()` queries only `readiness.candidate.review_check_state.updated_head_ci` (lines 227–233). The stored inputs confirm these are different identities: proposal CI is run `37819712610` on child candidate `0e773d…`, while saved readiness CI is run `37800067568` on parent candidate `d76d7f…`. A valid standalone receipt for the proposed candidate is therefore compared with authoritative metadata for the old readiness run and rejected. Conversely, no receipt can make the evaluator validate the actual proposal run through this capture path.

**Fix:** Pass the evaluator's resolved `ciExpected` identity into capture, query that run and its matching attempt/job, and validate the fetched run's head SHA before creating the authoritative record. Add a test where proposal CI and saved readiness CI differ and the proposal's complete valid receipt joins successfully.

## Warnings

### WR-03: Malformed exact-head CI JSON can still crash evidence capture

**Classification:** WARNING  
**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:227-239`

**Issue:** If parsing the receipt at line 235 throws, the catch block immediately calls `readJson(playrightPath)` again at line 239. The same malformed bytes throw outside the catch, aborting `captureEvidence()` instead of producing a blocked reconciliation with a diagnostic. This is especially likely for interrupted or partially written evidence files, which should fail closed without preventing a report from being emitted.

**Fix:** In the catch block return `{ receipt: null, authoritative: null }` (and retain a bounded capture diagnostic), or parse the receipt through a helper that returns a structured error without throwing.

## Original Finding Disposition Recheck

- **CR-01:** Open — producer schema normalization works, but Phase 248's capture/evaluator field mismatch still prevents a complete proof from passing.
- **CR-02:** Fixed — relevant candidate/readiness/capture blockers now make READY requirement verdicts unsatisfied.
- **CR-03:** Open — receipt and authoritative metadata are compared, but capture queries the stale readiness run instead of the proposal CI run.
- **CR-04:** Fixed — inherited work must have an explicit observed population and exact disposition join.
- **CR-05:** Fixed — Phase 248/249 requirements are recomputed from source snapshots and report markers are checked against those results.
- **CR-06:** Fixed — each preservation reference must resolve to a commit and a digest-matching record for its item and decision.
- **WR-01:** Fixed — saved canary proof is rejoined to current Actions run and artifact metadata.
- **WR-02:** Fixed — source URLs are canonicalized and constrained before the source request; redirects are disabled.

## Verification

Focused tests passed: all 40 tests across the four verifier suites, and all 34 `scripts/ci/release-canary.test.sh` cases. `node --check` passed for the four verifier scripts; `bash -n scripts/ci/release-canary.sh` passed. Read-only `verify-v149-traceability.mjs --check-sources` recomputed `gaps_found`, 5/9, with AUTO-02 and REL-02 unsatisfied. No hosted canary, workflow dispatch, release, publish, or network fetch was run.

The current stored Phase 248 snapshot remains blocked because its controller proof lacks the hosted failure and cancellation artifacts. The defects above are independent capture-path issues and remain even if those artifacts later become available. Phase implementation fixes are present; phase verification and closure remain incomplete pending these code fixes and the existing genuine source-evidence blockers.

---

_Reviewed: 2026-10-10T17:13:15Z_  
_Reviewer: independent recheck agent_  
_Depth: deep_
