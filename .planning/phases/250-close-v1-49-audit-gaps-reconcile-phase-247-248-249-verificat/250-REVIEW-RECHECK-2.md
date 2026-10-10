---
phase: 250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat
reviewed: 2026-10-10T17:23:34Z
depth: deep
files_reviewed: 13
files_reviewed_list:
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-247-readiness.test.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.test.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-249-release.test.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.mjs
  - .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs
  - scripts/ci/release-receipt.sh
  - scripts/ci/release-canary.sh
  - scripts/ci/release-canary.test.sh
  - .github/workflows/release-receipt-canary.yml
  - .github/workflows/release-run-observer.yml
findings:
  critical: 1
  warning: 0
  info: 0
  total: 1
status: issues_found
---

# Phase 250: Independent Review Recheck 2

**Reviewed:** 2026-10-10T17:23:34Z  
**Depth:** deep  
**Files Reviewed:** 13  
**Status:** issues_found

## Summary

The Phase 247 fixes now resolve one proposal-first CI identity for capture and evaluation, and malformed receipt JSON produces a bounded blocker. Phase 248 now downloads both terminal artifacts and checks their archive digest, extracted receipt digest, owner, artifact identity, and run metadata. However, the new Phase 248 positive fixture does not use the current producer's receipt JSON shape. The actual capture path therefore rejects valid hosted terminal artifacts and AUTO-02 cannot pass.

The stored Phase 248 and Phase 249 owner report checks each return zero errors against the current snapshots and recomputed predicates. The read-only milestone audit remains `gaps_found` at 5/9; missing hosted canary artifacts and the other live evidence gaps remain separate blockers.

## Critical Issues

### CR-01: Phase 248 still expects a different terminal receipt schema from its producer

**Classification:** BLOCKER  
**File:** `scripts/ci/release-receipt.sh:100-113`; `.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-248-release.mjs:137-184`

**Issue:** The current producer serializes `probe_id` and `scenario` at the receipt's top level (`release-receipt.sh:102-104`) and places the source run fields at top level (`:105-112`). The controller proof embeds that parsed receipt unchanged (`release-canary.sh:440-449`). Phase 248 instead reads `record.receipt.canary.probe_id` when constructing the failure artifact name (`verify-248-release.mjs:141-146`) and reads `receipt.canary.scenario` when validating the downloaded receipt (`:169-177`). Its evaluator repeats the nested-schema assumption for the failure artifact name and both retrieved receipt scenarios (`:338-340`, `:351-378`).

**Concrete reproduction:** I passed `captureCanaryTerminalReceipts()` a deterministic stub matching the producer output (`receipt_kind`, top-level `probe_id`, top-level `scenario`, exact source identity, and a matching listed artifact named `release-canary-failure-101-1-<probe>`). It returned `{status:"blocked",reason:"terminal_artifact_identity_missing"}` because it searched for an artifact ending in `undefined`. The cancellation artifact is found by its run-based name, but its downloaded receipt is then rejected because `receipt.canary.scenario` is absent. This reproducer used injected local download metadata and no network.

The new passing test fixture at `verify-248-release.test.mjs:48-50` builds receipts with `canary: { scenario, probe_id }`, unlike the actual serializer, so the capture-path test passes only for the invented nested shape. `captureSnapshot()` passes the raw producer proof to this helper and stores its results (`verify-248-release.mjs:240-253`, `:274-278`), so this mismatch is on the executable capture path. The complete actual producer shape has no other field-name mismatch in the receipt fields inspected: the source ID/attempt, workflow, URL, time, event/ref/SHA, terminal verdict, and cancellation observer fields line up with the helper's comparisons.

**Fix:** Read `probe_id` and `scenario` from the top level emitted by `release-receipt.sh`, or normalize the actual receipt once to a documented internal shape before every artifact-name and evaluator check. Change the positive capture fixture to use the exact unmodified producer JSON, and exercise the helper plus evaluator with matching authoritative failure/cancellation artifact metadata.

## Rechecked Original Findings

- **CR-01:** Open — the controller proof normalization and artifact download checks are present, but the actual receipt schema mismatch above prevents valid capture.
- **CR-02:** Fixed in the prior recheck — requirement verdicts include the applicable source, tuple, capture-race, and disposition blockers.
- **CR-03:** Fixed — capture and evaluation use the same proposal-first CI identity; stubbed tests distinguish it from saved readiness CI and reject authoritative SHA drift.
- **CR-04:** Fixed in the prior recheck — inherited work requires an explicit observed ID set and an exact disposition/preservation join.
- **CR-05:** Fixed in the prior recheck — owner requirement statuses are recomputed from their snapshots and checked against report markers.
- **CR-06:** Fixed in the prior recheck — preservation refs must resolve to matching commit bytes and record identity.
- **WR-01:** Fixed in the prior recheck — canary validation rejoins saved proof to authoritative run and artifact records.
- **WR-02:** Fixed in the prior recheck — source receipt URLs are validated against the canonical HTTPS GitHub path before fetching, and redirects are disabled.
- **WR-03:** Fixed — malformed receipt JSON is read once and returned as a bounded blocking diagnostic.

## Verification

The focused Node suites passed: readiness 14/14, Phase 248 release 10/10, Phase 249 release 9/9, and traceability 10/10. The canary shell suite passed 34/34. Syntax checks passed for all four verifier scripts and `scripts/ci/release-canary.sh`. The producer-schema reproduction above failed closed as described, demonstrating the uncovered positive-path mismatch despite the fixture suites passing.

Phase 248 and Phase 249 canonical report checks returned no errors against the current stored snapshots. The read-only traceability audit recomputed `gaps_found`, 5/9; it left AUTO-02 and REL-02 unsatisfied. No snapshot or owner report was refreshed, and no hosted canary, workflow dispatch, release, publish, or network probe was run. Phase verification remains incomplete while CR-01 and the existing live evidence blockers remain.

---

_Reviewed: 2026-10-10T17:23:34Z_  
_Reviewer: independent recheck agent_  
_Depth: deep_
