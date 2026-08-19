---
phase: 247-language-learning-digital-twin
plan: 06
subsystem: learning-twin
tags: [playwright, phoenix, indexeddb, replay, evidence]
requires:
  - phase: 247-04
    provides: durable replay outcomes
  - phase: 247-05
    provides: partitioned queued practice actions
provides:
  - accessible one-row durable replay receipts
  - receipt-last source-bound evidence runner
affects: [TWIN-01, OFF-01, OFF-02]
tech-stack:
  added: []
  patterns: [foreground replay reconciliation, exact-key evidence]
key-files:
  created:
    - scripts/ci/phase-247-language-twin-proof.sh
    - .planning/phases/247-language-learning-digital-twin/247-EVIDENCE.json
    - test/sigra/planning/phase_247_language_twin_browser_lane_test.exs
  modified:
    - .github/workflows/ci.yml
    - test/example/lib/example/learning_twin.ex
    - test/example/priv/static/assets/js/learning_twin.js
    - test/example/priv/static/assets/css/app.css
    - test/example/priv/playwright/tests/twin-offline.spec.ts
key-decisions:
  - "Terminal rows are immutable and correlated only by the internal client mutation ID."
  - "The evidence receipt retains fixed booleans and source hashes only."
status: complete
---

# Phase 247 Plan 06: Replay Receipts and Evidence Summary

Accessible foreground replay now renders exactly one chronological terminal receipt per queued practice action, and a credential-free receipt-last proof runner validates the source-bound evidence schema.

## Task Commits

1. `dcc1e5ab` — RED replay receipt coverage.
2. `a49b04ce` — durable receipt reconciliation, semantic UI, and conflict focus recovery.
3. `b25f909e` — exact-key evidence runner and phase evidence.
4. `92498b84` — Phoenix proof-process ownership and cleanup assertion.
5. `460ae2d0` / `06fda08f` — browser offline-state isolation and conflict reconnect repair.
6. `4b31c54c` — exact evidence validator repair.

## Verification

- Focused ExUnit learning-twin/controller/LiveView suite: PASS (19 tests).
- Focused practice-form → empty/queued receipt transition: PASS (2 Chromium tests).
- Complete phase proof: PASS (19 ExUnit tests and 18 Chromium tests); exact-key evidence was atomically regenerated last.
- Browser ownership integration: PASS (14 Phase 232/234/247 tests plus the pinned Phase 235 ledger check); the CI command lists exactly 18 Chromium cases.
- JavaScript syntax, Elixir formatting, evidence schema, source hashes, diff whitespace, and Phoenix cleanup assertion: PASS.
- Repository regression diagnostic: NON-PASSING (2,792 tests, 12 unrelated failures); no Phase 247 test or artifact failed, and the Phase 234/235 inventory regressions introduced by the first ownership repair are absent.

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 2 - Critical accessibility] Replaced the receipt placeholder paragraph with a semantic receipt container and focusable lesson target.
   - Files: `test/example/lib/example/learning_twin.ex`, `learning_twin.js`, `app.css`
   - Commit: `a49b04ce`

2. [Rule 3 - Verification environment] Started the repository-managed PostgreSQL test database and used the scoped Phoenix browser harness.

## Retry Resolution

The first retry exposed transient shared PostgreSQL connection saturation. After capacity was restored, the browser matrix surfaced two deterministic test defects: offline state leaked from the form test and the conflict test dispatched replay before restoring connectivity. The suite now restores online state in `afterEach`, waits for offline-media readiness before queuing, restores connectivity before conflict replay, and passes end to end.

The proof harness launches Phoenix with `exec`, tracks its real process ID, terminates it in the trap, and asserts no tracked server remains after exit. Evidence is generated only after the complete matrix passes and source hashes validate.

The browser proof is registered as its own explicit retry-zero Chromium invocation in the existing
non-admin shard. The archived Phase 234 inventory remains byte-for-byte pinned for Phase 235, while
the successor-aware historical contract validates only its captured 20-spec baseline and Phase 247's
new contract validates the live twin lane.

## Self-Check: PASSED

All plan artifacts and task commits exist; complete proof, exact-key evidence, source hashes, and cleanup assertion pass.
