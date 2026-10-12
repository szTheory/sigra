---
phase: 250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat
reviewed: 2026-10-10T16:53:22Z
depth: standard
files_reviewed: 18
files_reviewed_list:
  - .github/workflows/release-receipt-canary-controller.yml
  - .github/workflows/release-receipt-canary.yml
  - .github/workflows/release-run-observer.yml
  - scripts/ci/phase-250-contract.tap.test.mjs
  - scripts/ci/release-canary.sh
  - scripts/ci/release-canary.test.sh
  - scripts/ci/release-observer.sh
  - scripts/ci/release-receipt.sh
  - test/sigra/planning/phase_248_release_observer_contract_test.exs
  - test/sigra/planning/phase_250_canary_contract_test.exs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.test.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.test.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs
findings:
  critical: 6
  warning: 2
  info: 0
  total: 8
status: issues_found
---

# Phase 250: Code Review Report

**Reviewed:** 2026-10-10T16:53:22Z  
**Depth:** standard  
**Files Reviewed:** 18  
**Status:** issues_found

## Summary

Reviewed the five Phase 250 plan/summary pairs and all 18 explicitly scoped implementation files. The evaluation-scope cross-check resolved only the initial 10-file canary/observer/receipt subset; this review also covered the broader verifier and contract-test source list supplied for Phase 250. The main risks are false-positive requirement evidence and incompatible canary proof schemas across the producer and verifier.

## Critical Issues

### CR-01: Phase 248 cannot accept the current canary controller proof

**Classification:** BLOCKER  
**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.mjs:132-164`

**Issue:** The verifier consumes the old proof schema (`controller_run`, `source_failure.id`, and a `passed` status). The current controller script emits `status: "pass"`, `source_failure.run_id`, and no `controller_run` object in its proof JSON ([release-canary.sh](/Users/jon/projects/sigra/scripts/ci/release-canary.sh:432)). On a successful run, `captureSnapshot()` dereferences `proof.controller_run.id` and crashes; even if those fields are translated, `evaluateSnapshot()` requires `proof_status === "passed"` ([verify-248-release.mjs](/Users/jon/projects/sigra/.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.mjs:212)). Consequently the evidence path cannot promote a valid proof from the current producer.

**Fix:** Define one proof schema shared by both files. Adapt capture to the emitted field names and status, and pass the controller run/artifact identity as an explicit, validated input from the authoritative Actions metadata query.

### CR-02: READY verdicts omit required evidence blockers

**Classification:** BLOCKER  
**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:95-111,151-153`

**Issue:** `evaluateEvidence()` adds blockers for missing/mismatched candidate blobs, missing diff digest, missing readiness commit object, and live refs changing during capture, but the `READY-01`/`READY-02` verdict filters omit several of these blocker IDs. In particular, `READY-01` can be reported `satisfied` despite `candidate_source_blobs_unverified`, `candidate_diff_digest_missing`, `readiness_candidate_object_unavailable`, or `live_refs_changed_during_capture`. The overall result may be `blocked` while the requirement-level report falsely marks the requirement satisfied.

**Fix:** Compute each requirement verdict from its complete predicate set (or treat any blocker relevant to that requirement as unsatisfied). Include all source, readiness-object, diff, and capture-race blockers in the appropriate verdict.

### CR-03: Exact-head CI is accepted on file existence alone

**Classification:** BLOCKER  
**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:111-127,145-153`

**Issue:** The only check for the referenced exact-head CI result is `existsSync(playrightPath)`. Its contents, run ID, attempt, conclusion, and head SHA are never parsed or joined to the candidate tuple. Any file at that path—including malformed or stale evidence—clears `exact_head_ci_source_missing` and can let `READY-01` pass.

**Fix:** Parse and validate the CI receipt schema, require a passing conclusion and exact candidate SHA, and compare its run/attempt identity to the referenced authoritative run before satisfying `READY-01`.

### CR-04: Inherited-work dispositions can be empty and still satisfy READY-02

**Classification:** BLOCKER  
**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:118-119,151-153`

**Issue:** READY-02 only checks that `inheritedWork.observed` is truthy and `dispositions` is an array. It never joins observed inherited-work IDs to disposition IDs or checks their decisions and preservation references. `{ observed: true, dispositions: [] }` therefore counts as complete regardless of the actual inherited population.

**Fix:** Record the observed inherited-work population explicitly and run it through the same duplicate, exact-set, decision, and recoverable-preservation checks used for open PRs. Require the joined result to pass before satisfying READY-02.

### CR-05: Traceability trusts requirement statuses embedded in owner reports

**Classification:** BLOCKER  
**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs:143-160,233-268`

**Issue:** For Phase 248, the checker reads `requirements` from the report’s HTML evidence marker and only compares its source SHA with the snapshot. It does not compare those requirement statuses with `snapshot.requirements` or rerun the owner report validator. `reportRequirementStatus()` then trusts the marker value ahead of the report’s `gaps_found` status. Changing the marker to say `AUTO-01: satisfied` can therefore suppress the owner-status blocker for that row even when the source snapshot says it is unsatisfied. The Phase 249 marker is also used as requirement authority without a full comparison to the snapshot’s computed verdicts.

**Fix:** Recompute owner verdicts from each source snapshot and compare every embedded requirement status and identity field against the corresponding owner verifier output. Treat any disagreement or an invalid report check as a blocker.

### CR-06: A preservation reference can be absent while a disposition passes

**Classification:** BLOCKER  
**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs:55-64`

**Issue:** `joinPopulation()` accepts a disposition when `preservation_ref_recoverable === true`, but never requires `preservation_ref` to contain an identity. It can return `status: "passed"` and serialize `ref: null`, allowing READY-02 to treat an absent preservation record as recoverable.

**Fix:** Require a non-empty, validated preservation ref for each disposition and verify that the referenced record is recoverable before returning `passed`.

## Warnings

### WR-01: Canary proof validation does not bind all terminal outcomes and observer identity fields

**Classification:** WARNING  
**File:** `scripts/ci/release-canary.sh:492-529`

**Issue:** `--validate-proof` checks receipt verdicts and some source/observer fields, but does not require the recorded failure run conclusion to be `failure`, the cancellation run conclusion to be `cancelled`, or the observer workflow ID/attempt in run metadata to equal the values embedded in the cancellation receipt. The orchestration path checks some of these before writing its proof, but the standalone validator accepts a contradictory edited proof because it never repeats those joins.

**Fix:** Validate both source conclusions and compare observer ID, attempt, workflow ID, path, event, ref, and conclusion between the proof’s authoritative run records, preflight identity, and embedded receipt. Where `--validate-proof` is expected to verify a saved hosted proof independently, re-query the run/artifact metadata or validate a cryptographic capture that binds those fields.

### WR-02: The release verifier makes a network request to an unvalidated receipt URL

**Classification:** WARNING  
**File:** `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.mjs:280-295`

**Issue:** `publicProof()` passes `receipt.source_reference.href` directly to `curl`. A modified or malformed local receipt can make `--capture` issue requests to arbitrary hosts, including internal addresses. This creates an SSRF path in a verifier that processes repository evidence.

**Fix:** Validate the URL before invoking `curl`: require HTTPS and an exact `github.com/sztheory/sigra/blob/v1.6.0/` path, reject credentials, ports, redirects to other hosts, and pass `--` before the URL argument.

---

_Reviewed: 2026-10-10T16:53:22Z_  
_Reviewer: the agent (gsd-code-reviewer)_  
_Depth: standard_
