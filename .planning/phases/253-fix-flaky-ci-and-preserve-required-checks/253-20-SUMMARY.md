---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: '20'
subsystem: testing
tags: [git-objects, github-rest, publication, https, request-budget]
requires:
  - phase: 253-19
    provides: measured HTTPS transport, request allocation, source-bound ledger, and registration verifier
provides:
  - Bounded unsigned Git blob/tree/commit publication and create-only scoped-ref verification
  - Local object-aware HTTPS fixture proving missing-object upload, request accounting, and readback behavior
  - Complete receipt verification bound to parent, object, workflow, ledger, and exact scoped refs
affects: [253-23, phase-253-publication]
actuals:
  tokens: 45707 # chars/4 across the realized task code, evidence, proposal, and summary.
  tasks: 2
  commits: 4
plan_head_before: 2e369e1d2f1a5e69190d6d5aaebc7c209c7d31b4
plan_head_after: d9e24f4774411535c43f2b7336db9f03755a0182
tech-stack:
  added: []
  patterns:
    - Git REST object identities are recomputed with native Git serialization and verified by server readback.
    - Every external object request is debited and its transmitted body length and digest are retained without retaining source content.
key-files:
  created:
    - scripts/ci/ci-git-publication.py
    - scripts/ci/ci-git-publication.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-REPLAN-PUBLICATION-PROPOSAL.json
  modified:
    - scripts/ci/ci-hosted-transport.py
    - scripts/ci/ci-hosted-transport.test.py
key-decisions:
  - "Keep publication callable for the exact szTheory/sigra GitHub origin, while all Plan 20 tests use only the local HTTPS fixture."
  - "Keep the full candidate delta and report a blocked proposal when its serialized tree body exceeds 2 MiB; do not omit product files or increase the request reservation."
patterns-established:
  - "Receipts must prove exact parent, trees, commits, workflow blobs, and both refs, in addition to matching the measured ledger."
  - "A local object-aware HTTPS server rejects refs to unavailable commits and calculates canonical Git object IDs itself."
requirements-completed: []
coverage:
  - id: D1
    description: "Local bounded Git object publication and exact create-only ref readback, with a complete proposal for the current product source."
    verification:
      - kind: integration
        ref: "scripts/ci/ci-git-publication.test.py (25 tests); scripts/ci/ci-hosted-transport.test.py (16 tests); scripts/ci/ci-registration-recovery.test.mjs (27 tests); scripts/ci/ci-gate-canary.test.sh"
        status: pass
    human_judgment: true
    rationale: "No production GitHub request was made. Fresh hosted parent availability and production create-ref readback remain for Plan 23. The current local proposal is blocked because its complete tree body is 3,019,411 bytes, over the 2 MiB limit."
duration: 25min
completed: 2026-10-13
status: complete
---

# Phase 253 Plan 20: Bounded Git Object Publication Summary

**A measured, unsigned Git REST publisher now uploads and verifies complete Git object graphs through a local HTTPS fixture, while the current full product delta remains honestly blocked by the fixed 2 MiB tree-body limit.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-10-13T22:19:27Z
- **Completed:** 2026-10-13T22:44:37Z
- **Tasks:** 2
- **Files modified:** 4 implementation and test files

## Accomplishments

- Implemented `--prepare`, `--check-manifest`, `--publish`, and `--verify-publication` for native Git blob/tree/unsigned-commit identities, parent preflight, object upload, and create-only scoped refs.
- Extended the existing measured HTTPS transport with bounded Git object routes and transmitted request-body byte/hash facts. Added strict source/repository/method/SHA/path checks; live requests remain limited to `api.github.com/szTheory/sigra`, while tests use a local TLS fixture.
- Added object-aware publication tests that compare the server journal to the measured ledger, reject missing objects and ref races, and verify exact metadata and workflow blob readback. The receipt verifier now rejects incomplete candidate or fixture ref proof.
- Generated and validated the source-bound local proposal at source `d9e24f4774411535c43f2b7336db9f03755a0182` and locally resolved parent `84ebcea60024c9e8caee405d55cad1c76b0e858a`. The full product tree parity is exact across 1,462 product files. The complete tree body is 3,019,411 bytes; the proposal records the 2 MiB blocker, a 15-request projection, and `complete_product_delta_dropped: false`.

## Task Commits

1. **Task 1 RED:** `880218f30` — body-bound proposal contract and RED evidence.
2. **Task 1 GREEN:** `5a0281d96` — bounded object publication, transport routes, and object-aware fixture.
3. **Task 2 RED:** `a5873a3c1` — reject a receipt missing candidate-ref proof.
4. **Task 2 GREEN:** `d9e24f477` — validate required parent/object/workflow/ref receipts.

The task ledger measured four commits from `2e369e1d2f1a5e69190d6d5aaebc7c209c7d31b4` through `d9e24f4774411535c43f2b7336db9f03755a0182`. The separate plan metadata commit is reported in the executor result.

## Files Created/Modified

- `scripts/ci/ci-git-publication.py` — local candidate construction, finite request projection, measured publication, and receipt verification.
- `scripts/ci/ci-git-publication.test.py` — 25 local object-aware HTTPS publication and negative-path contracts.
- `scripts/ci/ci-hosted-transport.py` — typed Git blob/tree/commit GET/POST routes and safe body hash/byte accounting.
- `scripts/ci/ci-hosted-transport.test.py` — body facts are retained while raw source content is not.
- `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-REPLAN-PUBLICATION-PROPOSAL.json` — final source-bound object graph and blocked finite request projection.
- `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-20-TDD-RED-03.json` and `253-20-TDD-RED-TASK2-02.json` — valid task RED evidence.

## Decisions Made

- The publisher supports the exact production repository route for later authorized use, but this plan makes no GitHub request and creates no remote object, ref, or pull request.
- Tree bodies stay capped at 2 MiB and allocations stay capped at 24 measured requests. The proposal blocks with the complete delta intact when either bound is exceeded.
- The two transport files were added to the scoped implementation because publication could not be safely production-callable through the existing typed allowlist/body-ledger interface without them.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking issue] Added the missing measured Git object transport interface**
- **Found during:** Task 1 (object upload and readback)
- **Issue:** The existing measured transport did not expose typed Git blob/tree/commit routes or persist transmitted body length/hash facts required by the publisher.
- **Fix:** Added narrowly scoped GET/POST routes and safe body facts while retaining existing transport authentication, rate-limit, page, redirect, and request accounting behavior.
- **Files modified:** `scripts/ci/ci-hosted-transport.py`, `scripts/ci/ci-hosted-transport.test.py`
- **Verification:** 16 transport tests and 25 object-aware publication tests passed.
- **Committed in:** `5a0281d96`

**Total deviations:** 1 auto-fixed (Rule 3).
**Impact on plan:** This was the minimal dependency change required for the requested publisher; no unrelated transport behavior was changed.

## TDD Gate Compliance

- Task 1 RED evidence: `253-20-TDD-RED-03.json` classified `RED_EVIDENCE_OK`; task target failed before the CLI existed. Task 1 GREEN and tracer verification passed in `5a0281d96`.
- Task 2 RED evidence: `253-20-TDD-RED-TASK2-02.json` classified `RED_EVIDENCE_OK`; the object-aware publication succeeded but the receipt verifier accepted a removed candidate-ref row. Task 2 GREEN passed in `d9e24f477`.
- Both task suites were rerun after implementation. Existing transport, registration-verifier, and canary contracts also passed.

## Issues Encountered

- The first generated proposal was based on the earlier implementation commit and was preserved before replacement. Its exact blob is `22cd3c61a4d4e938f26a5483d8f349babe0396d4` under `refs/gsd/phase253-20-proposal-prewrite/22cd3c61a4d4e938f26a5483d8f349babe0396d4`; prior SHA-256 was `cce6c43bc85b6481ab1414947af1a76600378537517b6f6112ae7c252e9d73b2`.
- An invalid interim RED record was preserved before removal: blob `cf870e26aff189036f05da705468d787c5a88c7f` under `refs/gsd/phase253-20-red-evidence-prewrite/invalid-task2-record-cf870e26aff189036f05da705468d787c5a88c7f`; prior status was untracked and prior SHA-256 was `48f90cd65631b6251741e5f148a075fff3d5a0dd4cc6f932e595d7ea6a782b1e`.
- The original unrelated `.planning/config.json` edit remains untouched at SHA-256 `8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d`; its exact prior blob remains under `refs/gsd/phase253-recovery-execution-unrelated-config` (`ab8aa3007f17294e2f224d4ac8482522b79bda24`). Earlier failed RED artifacts remain preserved under `refs/gsd/phase253-20-red-evidence-prewrite/9d088053c6571a20b5ec2959aeae0baff155f2d7cc508ae2262a2e889f1f23cb` (blob `e93a5ff0f2969c83b1efedc142d043c4e74745f6`) and `refs/gsd/phase253-20-red-evidence-prewrite/39d6902544053df6e17c38fdcd2bd3f6aa93267130c8e50a4485618a3b902232` (blob `a484056fc8deb07bf72c6f47b4a316e9902589dd`).

## User Setup Required

None. Production publication is deferred and no external service configuration or network access was used.

## Next Phase Readiness

The local publisher and its transport contracts are ready for the separately planned publication window. Plan 23 must still establish fresh hosted parent availability and obtain actual production object/ref readback within its authorization and request budget. The 3,019,411-byte complete tree body currently prevents this manifest from being published under the 2 MiB cap. This summary records completion of Plan 20 only; it does not claim Phase 253 verification or phase completion.

## Self-Check: PASSED

All four implementation/test files, the final proposal, and both valid RED evidence records exist. The four task commits are ancestors of the measured plan head `d9e24f4774411535c43f2b7336db9f03755a0182`.

---
*Phase: 253-fix-flaky-ci-and-preserve-required-checks*
*Completed: 2026-10-13*
