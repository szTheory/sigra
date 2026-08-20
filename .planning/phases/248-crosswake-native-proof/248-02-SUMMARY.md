---
phase: 248-crosswake-native-proof
plan: "02"
subsystem: testing
tags: [node-test, native-proof, crosswake, evidence, security]
requires:
  - phase: 248-01
    provides: Host-owned Crosswake native evidence and replay projection boundary
provides:
  - Fail-closed, target-specific native proof receipt validator and atomic receipt-last writer
  - Machine-proven Crosswake authority, retained-secret, embedded-browser, and target-overclaim boundary
affects: [248-03, 248-04, 248-05, 248-06, 248-07, 248-08]
tech-stack:
  added: []
  patterns: [exact allowlist validation, source-SHA-bound atomic receipts, non-vacuous prohibition facts]
key-files:
  created:
    - scripts/ci/lib/native-proof-receipt.mjs
    - scripts/ci/lib/native-proof-receipt.test.mjs
    - scripts/ci/prohibitions/p17-crosswake-native-boundary.test.mjs
  modified:
    - test/example/priv/native-fixtures/native-proof-status.json
    - test/fixtures/prohibitions/p17-crosswake-native-boundary-bad.json
    - test/fixtures/prohibitions/p17-crosswake-native-boundary-clean.json
key-decisions:
  - "Native evidence accepts only physical_iphone or android_emulator receipts with exact target-specific fields."
  - "Receipts bind a caller-supplied immutable implementation SHA and publish atomically only after terminal validation."
  - "The P17 guard derives non-empty repository facts and uses injected bad/clean subjects to prove red/green causation."
patterns-established:
  - "Receipt-last evidence validates exact recursive allowlists, source binding, cleanup, secret scan, scenarios, and terminal status before publication."
  - "Prohibition guards fail on malformed facts or parser floors instead of treating absence as a clean result."
requirements-completed: [XW-01]
coverage:
  - id: D1
    description: Native proof receipts reject incomplete, wrong-target, unclean, secret-shaped, and premature evidence.
    verification:
      - kind: unit
        ref: node --test scripts/ci/lib/native-proof-receipt.test.mjs
        status: pass
    human_judgment: false
  - id: D2
    description: Crosswake/native authority and retained-secret boundaries have real-source, injected-red, and injected-clean proof.
    requirement: XW-01
    verification:
      - kind: unit
        ref: node --test scripts/ci/prohibitions/p17-crosswake-native-boundary.test.mjs
        status: pass
      - kind: unit
        ref: GSD_PROHIB_SUBJECT=bad/clean node --test scripts/ci/prohibitions/p17-crosswake-native-boundary.test.mjs
        status: pass
    human_judgment: false
duration: 16min
completed: 2026-08-20
status: complete
---

# Phase 248 Plan 02: Native Receipt Contract Summary

**Fail-closed, SHA-bound physical-iPhone and Android-emulator evidence receipts with a non-vacuous Crosswake authority and redaction guard.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-08-19T23:55:12Z
- **Completed:** 2026-08-20T00:01:31Z
- **Tasks:** 2/2
- **Files modified:** 6

## Accomplishments

- Added exact shared and target-specific receipt schemas that reject unknown keys, invalid hashes, identity/secret-shaped values, incomplete scenarios, unclean state, and false transport claims.
- Added receipt-last atomic publication after the implementation SHA, cleanup, secret scan, and terminal completion all validate.
- Added P17 source-derived Crosswake/native boundary proof with deliberate bad-fixture failure and clean-fixture success.

## Task Commits

1. **Task 1: Define and prove the native receipt-last schema** - `c822f12a` (test), `c879bf30` (feat)
2. **Task 2: Enforce the Crosswake/native authority and retained-secret prohibition** - `f2f67698` (test), `1fc39d23` (feat)

## Files Created/Modified

- `scripts/ci/lib/native-proof-receipt.mjs` - Exact validator and atomic receipt-last writer.
- `scripts/ci/lib/native-proof-receipt.test.mjs` - Deterministic tests for receipt target, terminal state, transport, hashing, and atomic writing.
- `scripts/ci/prohibitions/p17-crosswake-native-boundary.test.mjs` - Non-vacuous source guard and fixture subject adapter.
- `test/example/priv/native-fixtures/native-proof-status.json` - Credential-free iPhone posture fixture.
- `test/fixtures/prohibitions/p17-crosswake-native-boundary-{bad,clean}.json` - Proven red and clean fact subjects.

## Decisions Made

- The iPhone lane can record only `controlled_transport_failure`; it cannot represent physical radio disconnection.
- Android terminal proof requires every transport and cold-start/force-stop control to be positively recorded.
- The retained status fixture exposes posture fields only and is independently run through the shared validator.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the telemetry allowlist marker floor to the released source's 18 entries.**
- **Found during:** Task 2
- **Issue:** The initial test/fixture expectation used 19 entries while the released telemetry allowlist has 18.
- **Fix:** Set the non-vacuous floor and injected fixture values to 18, preserving all sensitive-field checks.
- **Files modified:** `scripts/ci/prohibitions/p17-crosswake-native-boundary.test.mjs`, `test/fixtures/prohibitions/p17-crosswake-native-boundary-{bad,clean}.json`
- **Verification:** Real-source, known-bad, and known-clean P17 runs passed in the expected sequence.
- **Committed in:** `1fc39d23`

**2. [AGENTS.md evidence-truth adjustment] Retained NAT-01 and NAT-02 as pending.**
- **Found during:** Final planning-state update
- **Issue:** The generic plan requirement updater marked physical-device and emulator evidence complete even though this plan delivers only the shared proof contract.
- **Fix:** Restored the two requirements to pending; later platform receipt plans must supply their terminal evidence before claiming them.
- **Files modified:** `.planning/REQUIREMENTS.md`, `248-02-SUMMARY.md`

**Total deviations:** 1 auto-fixed (Rule 1), 1 AGENTS.md evidence-truth adjustment

## Issues Encountered

None remaining.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Platform lanes can now emit only validated, source-bound terminal receipts and must retain their authority/redaction constraints in P17.

## Self-Check: PASSED

- Required files exist and all four task commits are present in git history.

---

*Phase: 248-crosswake-native-proof*
*Completed: 2026-08-20*
