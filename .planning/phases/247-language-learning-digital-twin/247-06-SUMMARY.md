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
  modified:
    - test/example/lib/example/learning_twin.ex
    - test/example/priv/static/assets/js/learning_twin.js
    - test/example/priv/static/assets/css/app.css
    - test/example/priv/playwright/tests/twin-offline.spec.ts
key-decisions:
  - "Terminal rows are immutable and correlated only by the internal client mutation ID."
  - "The evidence receipt retains fixed booleans and source hashes only."
status: blocked
---

# Phase 247 Plan 06: Replay Receipts and Evidence Summary

Accessible foreground replay now renders exactly one chronological terminal receipt per queued practice action, and a credential-free receipt-last proof runner validates the source-bound evidence schema.

## Task Commits

1. `dcc1e5ab` — RED replay receipt coverage.
2. `a49b04ce` — durable receipt reconciliation, semantic UI, and conflict focus recovery.
3. `b25f909e` — exact-key evidence runner and phase evidence.
4. `92498b84` — Phoenix proof-process ownership and cleanup assertion.

## Verification

- Focused ExUnit learning-twin/controller/LiveView suite: PASS (17 tests).
- JavaScript syntax, Elixir formatting, evidence schema, and diff whitespace checks: PASS.
- Chromium proof retry passed media, tracer, form, accepted/duplicate, and rejected receipt cases. It failed the empty/queued receipt case because the preceding practice-form test leaves its browser context offline; the next case therefore boots into the expected expired-offline page instead of its online receipt fixture.

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 2 - Critical accessibility] Replaced the receipt placeholder paragraph with a semantic receipt container and focusable lesson target.
   - Files: `test/example/lib/example/learning_twin.ex`, `learning_twin.js`, `app.css`
   - Commit: `a49b04ce`

2. [Rule 3 - Verification environment] Started the repository-managed PostgreSQL test database and used the scoped Phoenix browser harness.

## Blocker

The repository-managed PostgreSQL container is currently saturated by concurrent clients (`FATAL 53300 too_many_connections`). Re-run `scripts/ci/phase-247-language-twin-proof.sh` once the shared test database has capacity; it will atomically replace evidence only after the complete ExUnit/Chromium matrix passes.

The retry also fixed the harness lifecycle: the Phoenix host is now launched with `exec`, tracked by its real process ID, terminated in the trap, and checked with `kill -0` after cleanup. The remaining browser failure is test isolation, not a server-process leak. The retained evidence predates this harness change and must be regenerated only by a green proof run.

## Self-Check: PASSED

All plan artifacts and the three task commits exist. The final full proof remains blocked on shared database capacity.
