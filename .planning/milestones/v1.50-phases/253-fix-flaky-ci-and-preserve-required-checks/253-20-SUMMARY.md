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
  tokens: 36212 # chars/4 over the realized scoped diff from plan base 2e369e1.
  tasks: 2
  commits: 8 # measured from plan base through source/proposal commits.
plan_head_before: 2e369e1d2f1a5e69190d6d5aaebc7c209c7d31b4
plan_head_after: 04d1b0ac52e519211fa065e66f3a1342d85f4193
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
  - "Keep the full candidate delta and fixed 2 MiB body limit; pack it into ordered tree requests and project 1 + B binary + 12 fixed + N tree calls under the existing 24-request reservation."
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
    rationale: "No production GitHub request was made. Fresh hosted parent availability and production create-ref readback remain for Plan 23. The complete local delta now fits through three bounded tree requests."
duration: 45min
completed: 2026-10-13
status: complete
---

# Phase 253 Plan 20: Bounded Git Object Publication Summary

**A measured, unsigned Git REST publisher now packs the complete product delta into ordered bounded tree requests and verifies both final object graphs before creating either scoped ref.**

## Performance

- **Duration:** 45 min for the complete plan execution and packing repair
- **Completed:** 2026-10-13
- **Tasks:** 2
- **Files modified:** 4 implementation and test files

## Accomplishments

- Implemented `--prepare`, `--check-manifest`, `--publish`, and `--verify-publication` for native Git blob/tree/unsigned-commit identities, parent preflight, object upload, and create-only scoped refs.
- Extended the existing measured HTTPS transport with bounded Git object routes and transmitted request-body byte/hash facts. Added strict source/repository/method/SHA/path checks; live requests remain limited to `api.github.com/szTheory/sigra`, while tests use a local TLS fixture.
- Added object-aware publication tests that compare the server journal to the measured ledger, reject missing objects and ref races, and verify exact metadata and workflow blob readback. The receipt verifier now rejects incomplete candidate or fixture ref proof.
- Repaired proposal generation by packing changed entries into an ordered tree chain. The refreshed proposal uses source `778be9c15b9a7128936036ac292ce60e183edd5a`, parent `84ebcea60024c9e8caee405d55cad1c76b0e858a`, candidate commit `7588b147d074e10fe9049e7e2706e56ecfdfcebb`, and fixture commit `775f0fed4ab38226c22c5314c4e58bb19787f2d7`. Product path/mode/blob parity is exact across all1,462 files.
- Candidate tree bodies are2,084,074 and949,228 bytes; the fixture tree body is17,332 bytes. Every body stays below2,097,152 bytes. The request projection is `1 parent preflight + 0 binary blobs + 12 fixed calls + 3 tree calls = 16`, under the unchanged24-request cap.
- Actual object-aware local HTTPS publication of a multi-file delta larger than2 MiB verified each uploaded tree base and SHA, exact final paths/modes/blob contents, server journal-to-ledger equality, and both refs after all candidate and fixture objects were available. Production server availability and publication remain unproven.

## Task Commits

1. **Task 1 RED:** `880218f30` — body-bound proposal contract and RED evidence.
2. **Task 1 GREEN:** `5a0281d96` — bounded object publication, transport routes, and object-aware fixture.
3. **Task 2 RED:** `a5873a3c1` — reject a receipt missing candidate-ref proof.
4. **Task 2 GREEN:** `d9e24f477` — validate required parent/object/workflow/ref receipts.

The task ledger measured four commits from `2e369e1d2f1a5e69190d6d5aaebc7c209c7d31b4` through `d9e24f4774411535c43f2b7336db9f03755a0182`. The separate plan metadata commit is reported in the executor result.

The complete plan ledger now measures eight commits from `2e369e1d2f1a5e69190d6d5aaebc7c209c7d31b4` through `04d1b0ac52e519211fa065e66f3a1342d85f4193`.
5. **Packing RED:** `6a9df8fef` — added a multi-file delta contract; the baseline publisher failed its readiness assertion and RED evidence passed the classifier.
6. **Packing GREEN:** `778be9c15` — implemented tree request packing and delayed both refs until final object verification.
7. **Proposal refresh:** `04d1b0ac5` — regenerated and validated the source-bound bounded proposal.

## Files Created/Modified

- `scripts/ci/ci-git-publication.py` — local candidate construction, finite request projection, measured publication, and receipt verification.
- `scripts/ci/ci-git-publication.test.py` — 25 local object-aware HTTPS publication and negative-path contracts.
- `scripts/ci/ci-hosted-transport.py` — typed Git blob/tree/commit GET/POST routes and safe body hash/byte accounting.
- `scripts/ci/ci-hosted-transport.test.py` — body facts are retained while raw source content is not.
- `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-REPLAN-PUBLICATION-PROPOSAL.json` — final source-bound object graph and finite16-request projection.
- `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-20-TDD-RED-03.json` and `253-20-TDD-RED-TASK2-02.json` — valid task RED evidence.
- `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-20-TDD-RED-PACKING.json` and `253-20-TDD-GREEN-PACKING.json` — machine-checked packing RED and GREEN/negative-path evidence.

## Decisions Made

- The publisher supports the exact production repository route for later authorized use, but this plan makes no GitHub request and creates no remote object, ref, or pull request.
- Tree bodies stay capped at 2 MiB and the allocation stays capped at 24 measured requests. Complete text deltas are split into ordered tree requests; a single oversized entry or over-budget request projection still blocks.
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

**2. [Rule 3 - Blocking issue] Packed the complete product delta within the fixed limits**
- **Found during:** Additional Plan 20 publication repair.
- **Issue:** The original candidate tree body was3,019,411 bytes, over2 MiB, although its changed text entries could be split without dropping files.
- **Fix:** Group changed entries deterministically into intermediate trees; each request names the prior tree SHA as its base and records the reconstructed native tree SHA. Upload and verify both commit graphs before creating either scoped ref.
- **Files modified:** `scripts/ci/ci-git-publication.py`, `scripts/ci/ci-git-publication.test.py`, and the refreshed proposal.
- **Request impact:** The actual formula is `1 + B + 12 + N` (`B` separately uploaded binary blobs, `N` tree requests). The current proposal has `B=0`, `N=3`, total16; the existing24-request reservation is unchanged.
- **Prior bytes preserved:** The blocked proposal (source `d9e24f4774411535c43f2b7336db9f03755a0182`, SHA-256 `2333f1f85b6083f61fc04df34c23e960458489fd210f238211f2d49d6f34b4cb`) remains exactly recoverable from commit `ca29ed14b14b9eb3ff3e8fb23ea6850df8cadaaa`. Its prior summary bytes (SHA-256 `a24823bd9ca085796863a9634fc3d2d3a663483ac08ff80abecf3f8a135bc3a6`) were also read back from that commit before replacement.
- **Unrelated config preserved:** `.planning/config.json` remains unstaged at SHA-256 `8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d`; its exact blob `ab8aa3007f17294e2f224d4ac8482522b79bda24` remains at `refs/gsd/phase253-recovery-execution-unrelated-config`.
- **Verification:**28 publisher tests,16 measured transport tests, and manifest validation passed. Packing RED evidence was classified `RED_EVIDENCE_OK`.
- **Committed in:** `778be9c15` (implementation), `04d1b0ac5` (proposal).

## TDD Gate Compliance

- Task 1 RED evidence: `253-20-TDD-RED-03.json` classified `RED_EVIDENCE_OK`; task target failed before the CLI existed. Task 1 GREEN and tracer verification passed in `5a0281d96`.
- Task 2 RED evidence: `253-20-TDD-RED-TASK2-02.json` classified `RED_EVIDENCE_OK`; the object-aware publication succeeded but the receipt verifier accepted a removed candidate-ref row. Task 2 GREEN passed in `d9e24f477`.
- Both task suites were rerun after implementation. Existing transport, registration-verifier, and canary contracts also passed.
- Packing RED ran the named test against the baseline publisher and failed on the intended `blocked` versus `ready-local-proposal` assertion; `gsd_run check tdd-red-evidence ...253-20-TDD-RED-PACKING.json --raw` returned `RED_EVIDENCE_OK`.
- Packing GREEN passed the full publication suite (28 tests), measured transport suite (16 tests), and proposal validation. Negative cases reject a broken base, tampered tree SHA, incomplete chain, over24 projection, and a single request over2 MiB.

## Issues Encountered

- The earlier proposal based on the first implementation remains preserved as blob `22cd3c61a4d4e938f26a5483d8f349babe0396d4` under `refs/gsd/phase253-20-proposal-prewrite/22cd3c61a4d4e938f26a5483d8f349babe0396d4`; its SHA-256 was `cce6c43bc85b6481ab1414947af1a76600378537517b6f6112ae7c252e9d73b2`. The later3,019,411-byte blocked proposal is recoverable at `ca29...` as recorded above.
- An invalid interim RED record was preserved before removal: blob `cf870e26aff189036f05da705468d787c5a88c7f` under `refs/gsd/phase253-20-red-evidence-prewrite/invalid-task2-record-cf870e26aff189036f05da705468d787c5a88c7f`; prior status was untracked and prior SHA-256 was `48f90cd65631b6251741e5f148a075fff3d5a0dd4cc6f932e595d7ea6a782b1e`.
- The original unrelated `.planning/config.json` edit remains untouched at SHA-256 `8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d`; its exact prior blob remains under `refs/gsd/phase253-recovery-execution-unrelated-config` (`ab8aa3007f17294e2f224d4ac8482522b79bda24`). Earlier failed RED artifacts remain preserved under `refs/gsd/phase253-20-red-evidence-prewrite/9d088053c6571a20b5ec2959aeae0baff155f2d7cc508ae2262a2e889f1f23cb` (blob `e93a5ff0f2969c83b1efedc142d043c4e74745f6`) and `refs/gsd/phase253-20-red-evidence-prewrite/39d6902544053df6e17c38fdcd2bd3f6aa93267130c8e50a4485618a3b902232` (blob `a484056fc8deb07bf72c6f47b4a316e9902589dd`).

## User Setup Required

None. Production publication is deferred and no external service configuration or network access was used.

## Next Phase Readiness

The local publisher and transport contracts are ready for the separately planned publication window. Plan 23 must still establish fresh hosted parent availability and obtain actual production object/ref readback within its authorization and request budget. The refreshed proposal has no local body-size or request-projection blocker. No GitHub request, hosted publication, browser launch, production ref mutation, Phase 253 verification, or phase completion is claimed here.

## Self-Check: PASSED

The implementation/test files, refreshed proposal, packing RED/GREEN evidence, and three new scoped commits exist. The eight plan commits are ancestors of measured plan head `04d1b0ac52e519211fa065e66f3a1342d85f4193`.

---
*Phase: 253-fix-flaky-ci-and-preserve-required-checks*
*Completed: 2026-10-13*
