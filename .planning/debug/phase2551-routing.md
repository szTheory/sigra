---
status: resolved
trigger: "What do you mean no gsd plans safe now? Can't you unblock us and figure out like there has to be some kind of way to debug this, clean it up, get us back on track?"
created: 2026-11-03
updated: 2026-11-03
goal: find_and_fix_offline
---

## Symptoms

- Expected: recover the approved Plan 06 preparation to a valid next step without re-entering the phase/discussion loop; keep CISPEED-01/02 completion evidence honest.
- Actual: Plan 06 Task 14c stopped before control collection, and prior resumes repeated Phase 255.1 or discussion. The routing fix now marks Plan 06 halted and Plan 07 blocked, leaving no runnable plan.
- Error: offline source validation cannot resolve control commit `de7d80d67de7c9f57e0a67cff90b36620c384f01` or candidate commit `856c02bbd0dac83a29e388a0644d0fd51839b38f`; both `git rev-parse` checks returned exit 128. No collector HTTP request was made.
- Timeline: repeated recovery attempts are recorded across Phase 255.1 artifacts; the latest stop and routing repair were recorded on 2026-11-03.
- Reproduction: the latest approved preparation flow validates the source commits before collector access. It stopped because those objects were missing locally. The exact approval forbids retry; this session is offline-only and must not fetch/push, dispatch CI, create a PR, or spend acceptance budget.
- Source of symptoms: the user's latest request plus PREP-VERIFY, the halted Plan 06 summary, the recovery reset, state/handoff, and OpenGSD readiness output. No further interview is needed.

## Current Focus

reasoning_checkpoint:
  hypothesis: Native-inventory validation fails because the collector reads only the root Git object database, while both exact clean source commits remain in the explicitly contract-bound child object store.
  confirming_evidence:
    - Unchanged production comparison_native_inventories fails with comparison_inventory_source_unavailable for both roles using default root lookup.
    - Changing only GIT_ALTERNATE_OBJECT_DIRECTORIES to the named retained child store makes the same unchanged function validate all five browser owners for each role.
    - Both retained archives match their manifest SHA-256 and exact original commit header; no source reconstruction was required.
  falsification_test: The unchanged inventory validator must still fail when the child store is removed from lookup and must pass when exact retained objects are readable; independent archive and object checks must also match.
  fix_rationale: Recover exact retained Git objects into a durable local readable store without changing any source, code, old proposal, approval or hosted budget. Avoid a source rewrite or nearby commit substitution.
  blind_spots: Independent Git closure/archive/scope reviews completed successfully. Local validation never supplies missing real cache restore or performance evidence, nor authorizes retry.
  candidate_causes:
    - code: collector performs root-only Git reads while the fresh policy preflight explicitly reads the child store
    - environment: exact frozen commits were intentionally created outside the root object database with one-way alternates
    - data: archive corruption or stale native proof would independently invalidate recovery; actual archive hashes/headers and native validator pass rule this out so far
  and_gate: yes — child-only object placement plus root-only collector lookup cause the failure together; neither object loss nor source divergence is needed.

bug_class: bohrbug
hypothesis: The exact source commits were retained in the contract's separate objects.git but the collector validates inventories through the root checkout, whose object lookup cannot see that child store.
test: Compare the unchanged production native-inventory validator using the root lookup versus the exact retained source store; validate the bundle, source archives and provenance independently before any local object transfer.
expecting: Both exact archives and commit/tree closure remain recoverable; making exact objects readable to the root validator addresses the local failure without changing source, code, approval or hosted authority.
next_action: return the completed offline source-recovery result to the parent; keep hosted execution stopped and make no further root Git mutations. A distinct preparation-only proposal and separate consent are required before any future hosted request.

resolution_scope: offline source recovery only; no phase/performance completion and no old hosted retry
result_artifact: .planning/debug/phase2551-offline-source-recovery-20261103/LOCAL-RESULT.json

write_ahead_preservation:
  ref: refs/gsd-preservation/phase2551-offline-source-audit-20261103
  commit: e3ab5ef1fc3fef7b6d97a544cda6976b6042f2c4
  original_path: .planning/debug/phase2551-routing.md
  recovery_path: phase2551-routing.md
  sha256: 220fa9d5a0a825e0e099b13307f7a9d0698185039e51a79cd00b1a17877c3511
  readback_equal: true

## Evidence

- Post-import verify.py --stage recovered passed: root-default production native validation accepts all five owners in both roles; exact source/archive/helper results match baseline; six old approval/contract/ledger artifacts and ten source-closure artifact hashes are unchanged; all 46,305 preexisting root refs are unchanged, with exactly the two new recovery refs added.
- Full production verify_local_source_scope_refreeze against the original MERGE-FREEZE.json returned verified_local, exact base/control/candidate IDs and 219 changed paths. The held-out ci-metrics-security.test.py suite passed with 38 tests; no product/source/orchestration code patch was applied.
- Independent scope/readiness/cost/security review confirmed exact local recovery adds no API/runner/cache/sample cost or hosted authority. Fresh init execute-phase 255.1 still reports Plan 06 halted, Plan 07 blocked and zero runnable plans.
- Offline goal is complete using deterministic verification; no redundant human test acknowledgement is required under the user's automation-first instruction. The debug record stays at its current path for parent synthesis and was not archived or committed after the parent's no-further-Git-writes instruction.

- The receipt-matching original local bundle was imported into root and two new refs/gsd-recovery/phase2551-offline-source-recovery refs were created atomically. The initial sandbox write was blocked; this local recovery command then used require_escalated and automatic approval allowed it. No network or hosted command ran. import-receipt.json retains exact operation/read-back.
- The parent's instruction to cancel root import and use only alternate lookup arrived after the import command had completed. Parent was informed immediately of completion/timing and that automatic sandbox approval permitted the escalation; this does not claim the parent approved that escalation. No further root Git mutation will occur; verification remains read-only, and this record does not claim the cancellation preceded import.

- Independent Git audit found both exact commits in all four retained clean-source stores, each with complete 24,899-object reachable closure and no missing objects through its configured root alternate. Retry04 connectivity checks passed. This rejects object-loss reconstruction as a prerequisite.
- Independent archive/native review confirmed active collector/source/equivalence/coverage/approval hashes, archive byte equality, unchanged non-.planning root entries, exact base .planning subtree and historical inventory identities. It recommended adding full linked-closure hash preservation and durable root-ref assertions; these were added to recovered verification.
- New baseline.json records the reproduced failure, successful single-variable alternate lookup, bundle verify/hash, exact archive regeneration and actual environment helper checks. closure-before.json records ten linked artifact hashes and a compact digest/count of every existing root ref before local repair.

- Counterfactual experiment changed only GIT_ALTERNATE_OBJECT_DIRECTORIES to the contract-named child store. The unchanged production validator then accepted all five native browser owners for each role. Removing that environment override leaves the original root-only failure reproducible. No Git objects or refs were mutated by this experiment.

- Direct reproduction: calling `ci_metrics_security.comparison_native_inventories` with the retained collector contract returns `comparison_inventory_source_unavailable` for both before and after roles.
- The active PREP-CONTRACT names `task14-clean-source-refreeze-20261101-retry04/objects.git`; its inventory contains exact loose commit paths and a `CLEAN-SOURCES.bundle` with a SHA-256 receipt. Fresh policy preflight uses this store explicitly, while native-inventory validation uses `git -C ROOT`.
- Both refreeze source tarballs match the active manifest's SHA-256 and native Git commit PAX header; each has 1777 members, excludes .planning and has no absolute/traversal member names. These are retained exact sources, not a nearby-source substitution.

- The dirty debug checkpoint was preserved under the scoped ref above; exact byte read-back and unchanged source bytes were verified before this replacement. No parent-owned state, old proposal or approval was changed.
- The local debug knowledge base contains source-closure warnings but no exact missing-object recovery. No MemPalace tool is available; offline file fallback was used. SBFL is inapplicable because this is retained-input availability, without a failing/passing per-test coverage spectrum.

- `.planning/execution/255.1/protected-delivery-scope/prep-policy-20261102/PREP-VERIFY.json` records the local stop, missing commit objects, empty collector request budget, and zero acceptance samples.
- `.planning/phases/255.1-close-gap-cispeed-01-cispeed-02-prove-ci-performance-targets/255.1-06-SUMMARY.md` now records Plan 06 as halted, not successful; Plan 07 depends on Plan 06.
- `init.execute-phase 255.1` reports Plan 06 halted, Plan 07 blocked, and zero runnable plans.
- The previous exact-byte versions of dirty handoff/state files were preserved before correction at `.planning/execution/255.1/write-ahead-preservation/phase2551-loop-fix-before-refresh-20261103T041737Z/PRESERVATION-REF.json`.

## Eliminated

- hypothesis: exact frozen source archives are missing or are only nearby replacement inputs
  evidence: both original tarballs exist with exact manifest hashes and original Git archive commit headers; native provenance checks pass with the exact retained child store
- hypothesis: the failure requires a new source rebuild or relabelling historical native results
  evidence: the unchanged production native-inventory validator passes both roles by changing only local object lookup

## Resolution

root_cause: The collector's native-inventory validator reads only the root checkout object database. The exact approved clean source commits are present in the separately retained contract-bound objects.git, whose alternates point toward root; root lookup cannot see the child store. The fresh-policy preflight used the child explicitly and therefore passed before the collector failed locally.
fix: Imported the exact receipt-matching retained bundle into root's object database and created two new scoped local recovery refs, preserving the original frozen commit IDs and all code/source/approval bytes. No root Git mutations will follow the parent's subsequently delivered cancellation.
verification: Recovered production preflight passes both roles under default root lookup, exact archives regenerate identically, reviewed environment helper passes each exact source, complete closure has no missing objects, all captured old artifact/ref identities are unchanged, full source-scope verifier returns verified_local, and held-out security suite passes. See LOCAL-RESULT.json, baseline.json, recovered.json and import-receipt.json for actual results and limitations.
files_changed:
  - .planning/debug/phase2551-routing.md
  - .planning/debug/phase2551-offline-source-recovery-20261103/RECOVERY.md
  - .planning/debug/phase2551-offline-source-recovery-20261103/verify.py
  - .planning/debug/phase2551-offline-source-recovery-20261103/baseline.json
  - .planning/debug/phase2551-offline-source-recovery-20261103/closure-before.json
  - .planning/debug/phase2551-offline-source-recovery-20261103/import-receipt.json
  - .planning/debug/phase2551-offline-source-recovery-20261103/recovered.json
  - .planning/debug/phase2551-offline-source-recovery-20261103/LOCAL-RESULT.json
phase_status: Phase 255.1 remains incomplete; CISPEED-01/02 and performance results remain unproved.


## Follow-up: phase execution routing loop (2026-11-03)

This was a separate routing problem from the source-object lookup bug above. The live `phase-plan-index` and `init.execute-phase` showed Plan09 halted by its matching summary, Plan07 blocked on Plan09, and no runnable plan. Meanwhile duplicated handoff/state fields still described the old Wave2 command as active. Plan07 also retained a second approval checkpoint after the user authorized bounded project CI without per-run approval.

The repair preserved the exact halted Plan09 summary under `.planning/execution/255.1/diagnostics/halted-attempts/`, removed it from the scanned phase directory, and reopened the same Plan09 against generation03. Plan07 now applies standing CI authority only by binding the exact proposal and existing limits with `authorize-standing-ci --stage measurement`; its human checkpoint is removed. No source-bound stopped generation is retried, no new plan number is added, and the phase remains open until measured and independently verified evidence passes.
