---
phase: 249-publish-and-prove-sigra-1-6-0
plan: 01
subsystem: release
tags: [github-actions, hex, hexdocs, provenance, receipt]
requires:
  - phase: 248
    provides: validated Release Please terminal artifact for the published release
provides:
  - live, exact-source proof for the published Sigra 1.6.0 package
  - sanitized receipt bound to package-source CI and tagged documentation source
affects: [release engineering, phase 249 closeout]
actuals:
  tokens: 9624
  tasks: 1
  commits: 2
tech-stack:
  added: []
  patterns:
    - read-only live identity joins before receipt projection
    - archive member allowlist and explicit receipt projection
key-files:
  created:
    - scripts/ci/release-public-proof.sh
    - scripts/ci/release-public-proof.test.sh
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-PREFLIGHT.json
    - .planning/phases/249-publish-and-prove-sigra-1-6-0/249-RELEASE-RECEIPT.json
  modified: []
key-decisions: []
patterns-established:
  - "Package-source CI and later protected-main CI remain distinct identities."
  - "Downloaded release artifacts are parsed as data and projected through an explicit allowlist."
requirements-completed: [REL-01, REL-02]
coverage:
  - id: D1
    description: "A ready preflight and live proof join the 1.6.0 tag, release artifact, package-source CI, Hex release, versioned HexDocs, and rendered source destination."
    requirement: REL-01
    verification:
      - kind: integration
        ref: .planning/phases/249-publish-and-prove-sigra-1-6-0/249-PREFLIGHT.json#verdict
        status: pass
      - kind: e2e
        ref: .planning/phases/249-publish-and-prove-sigra-1-6-0/249-RELEASE-RECEIPT.json#source_reference
        status: pass
    human_judgment: false
  - id: D2
    description: "Hermetic fixtures prove the successful identity join and fail closed when package-source CI is missing."
    requirement: REL-02
    verification:
      - kind: unit
        ref: bash scripts/ci/release-public-proof.test.sh
        status: pass
    human_judgment: false
duration: 16 min
completed: 2026-10-09
status: complete
---

# Phase 249 Plan 01: End-to-End 1.6.0 Release Identity Summary

**Sigra 1.6.0 now has a live, source-bound receipt joining its published package to the exact tagged source and successful required CI.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-10-09T12:50:05Z
- **Completed:** 2026-10-09T13:05:57Z
- **Tasks:** 1/1
- **Files modified:** 4

## Accomplishments

- Added a read-only verifier that records current-main and release-source identities, downloads only the expected artifact JSON member, checks exact-source `ci-gate`, and follows the live HexDocs source link through to its tagged GitHub path.
- Recorded a ready preflight and sanitized receipt for tag `v1.6.0` at source `9e80cb78d6374b1ed4074d5fef6b613fee879dca`, including release run 37875238705 attempt 3 and required CI run 37875238741 attempt 2.
- Added hermetic positive-join and missing-source-CI fixtures; both pass.

## Task Commits

1. **Task 1: End-to-end tracer: prove one live 1.6.0 identity from artifact to receipt** — `59a6c54b1` (`feat`)

**Plan metadata:** pending.

## Files Created/Modified

- `scripts/ci/release-public-proof.sh` — read-only public release identity verifier and allowlisted receipt writer.
- `scripts/ci/release-public-proof.test.sh` — hermetic positive and fail-closed source-CI fixtures.
- `.planning/phases/249-publish-and-prove-sigra-1-6-0/249-PREFLIGHT.json` — live readiness checks and evidence identities.
- `.planning/phases/249-publish-and-prove-sigra-1-6-0/249-RELEASE-RECEIPT.json` — sanitized package-source release proof.

## Decisions Made

None beyond the locked Phase 249 decisions; the verifier consumes Phase 248's actual flattened artifact schema.

## Deviations from Plan

None. The live probe exposed the retained artifact's flattened schema, and the helper was aligned to that existing contract before passing the live check.

## Issues Encountered

The first live attempt correctly blocked because the draft parser expected nested release/source objects. Inspection of the retained artifact showed its established top-level fields; the parser and fixture were corrected, then both hermetic fixtures and the live proof passed.

## User Setup Required

None.

## Next Phase Readiness

Plan 01 is ready for its metadata closeout. Wave 2 plans 249-02, 249-04, and 249-07 can proceed after the summary commit; preserve all inherited work, including the dirty `ci.yml` edits, while applying their scoped changes.

---
*Phase: 249-publish-and-prove-sigra-1-6-0*
*Completed: 2026-10-09*
