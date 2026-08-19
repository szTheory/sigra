---
phase: 248-crosswake-native-proof
plan: "01"
subsystem: auth
tags: [crosswake, sigra, native-evidence, offline-replay, exunit]
requires:
  - phase: 247-language-learning-digital-twin
    provides: Host-owned account partitions, leases, and terminal replay receipts
provides:
  - Typed, allowlisted native-return evidence evaluated only after a fresh host session lookup
  - Released Crosswake replay request and outcome projection over LearningTwin terminal receipts
affects: [248-crosswake-native-proof, native shells, crosswake]
tech-stack:
  added: []
  patterns: [fresh host authority before evaluator invocation, host-owned replay terminal authority]
key-files:
  created:
    - test/example/lib/example/accounts/crosswake_native_bridge.ex
  modified:
    - test/example/lib/example/accounts/crosswake_session_adapter.ex
    - test/example/test/example/accounts/crosswake_native_bridge_test.exs
key-decisions:
  - "Native callbacks enter Crosswake only as an exact allowlisted NativeEvidence envelope; credentials and authority claims are rejected."
  - "Crosswake replay structures correlation while LearningTwin retains account selection, exactly-once storage, and terminal outcome authority."
patterns-established:
  - "Validate a released typed return envelope, then delegate to the adapter's fresh session and binding check."
  - "Project only a host receipt's bounded correlation and terminal timestamp into Crosswake outcomes."
requirements-completed: [XW-01]
coverage:
  - id: D1
    description: "Native iOS and Android posture is allowlisted into NativeEvidence and denied before evaluator invocation on stale or mismatched host authority."
    requirement: XW-01
    verification:
      - kind: integration
        ref: "test/example/test/example/accounts/crosswake_native_bridge_test.exs#projects allowlisted iOS and Android evidence only after fresh host authority"
        status: pass
      - kind: integration
        ref: "test/example/test/example/accounts/crosswake_native_bridge_test.exs#revoked binding mismatched and sensitive native input deny before evaluator invocation"
        status: pass
    human_judgment: false
  - id: D2
    description: "Released Crosswake replay vocabulary preserves journal correlation while LearningTwin remains the account-isolated exactly-once terminal authority."
    requirement: XW-01
    verification:
      - kind: integration
        ref: "test/example/test/example/accounts/crosswake_native_bridge_test.exs#maps journal identity exactly and leaves terminal status to the host"
        status: pass
      - kind: integration
        ref: "test/example/test/example/accounts/crosswake_native_bridge_test.exs#duplicate and account-isolated replay receipts remain host-owned"
        status: pass
    human_judgment: false
duration: 12min
completed: 2026-08-19
status: complete
---

# Phase 248 Plan 01: Crosswake Native Proof Summary

**A secret-free native-return bridge now projects exact typed Crosswake evidence only after fresh Sigra authority, with LearningTwin retaining replay ownership.**

## Performance

- **Duration:** 12 min
- **Tasks:** 2
- **Files modified:** 3
- **Verification:** 28 focused ExUnit tests passed.

## Accomplishments

- Added `CrosswakeNativeBridge.evaluate_return/6`, which accepts only the six released native posture fields and delegates session authority to `CrosswakeSessionAdapter`.
- Preserved fresh-session, revocation, and callback-binding denial precedence, including evaluator non-invocation proofs.
- Added released journal/replay request and outcome projection; host receipts still determine accepted, rejected, conflict, duplicate, and account-isolated behavior.

## Task Commits

1. **Task 1: Trace one native return through fresh host authority and released NativeEvidence**
   - `0db201fa` `test(248-01): add failing native bridge contract tests`
   - `9f60ad5c` `feat(248-01): bridge native evidence through fresh sessions`
2. **Task 2: Map native outbox identity and terminal host outcomes onto Crosswake replay**
   - `5f6c66a9` `test(248-01): add failing replay projection tests`
   - `241fd9b6` `feat(248-01): project host replay into Crosswake`

## Files Created/Modified

- `test/example/lib/example/accounts/crosswake_native_bridge.ex` — bounded native evidence and host-owned replay projection bridge.
- `test/example/lib/example/accounts/crosswake_session_adapter.ex` — validates a prebuilt released envelope without reparsing it.
- `test/example/test/example/accounts/crosswake_native_bridge_test.exs` — authority, secret-boundary, replay, duplicate, and account-isolation coverage.

## Decisions Made

- Native posture maps must have exactly the released allowlisted fields, making sensitive callback or credential injection fail closed.
- The `Replay.Outcome` contains only bounded host receipt state; it cannot set the persisted result or account partition.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The local test database was not running initially; the repository's deterministic `scripts/db/up.sh` lifecycle provided the scoped PostgreSQL instance before verification.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

The host-owned proof seam is ready for the native shell and evidence plans. Physical-device and Android-emulator claims still require their separate deterministic execution lanes.

## Self-Check: PASSED

- Verified the bridge source and focused test files exist.
- Verified task commits `0db201fa`, `9f60ad5c`, `5f6c66a9`, and `241fd9b6` exist.
