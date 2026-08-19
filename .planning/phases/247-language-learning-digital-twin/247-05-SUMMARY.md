---
phase: 247-language-learning-digital-twin
plan: 05
subsystem: offline-learning-ui
tags: [pwa, indexeddb, service-worker, playwright, accessibility]
requires:
  - phase: 247-02
    provides: marker-last verified media cache
  - phase: 247-03
    provides: strict current-Scope lease and partition contract
provides:
  - Partition-first activation and bounded offline practice enqueueing
  - Accessible Tasklane practice form and generic expired offline recovery shell
  - Deterministic Chromium proof for media, shell, and bounded form behavior
affects: [247-06, offline-lease, account-isolation]
tech-stack:
  added: []
  patterns: [partition-leading IndexedDB keys, strict lease gate, credential-free outbox]
key-files:
  created: []
  modified:
    - test/example/lib/example/learning_twin.ex
    - test/example/priv/static/assets/js/learning_twin.js
    - test/example/priv/static/assets/css/app.css
    - test/example/priv/static/learning-twin-worker.js
    - test/example/priv/static/learning-twin-offline.html
    - test/example/priv/playwright/tests/twin-offline.spec.ts
key-decisions:
  - "Offline activation and practice writes require a current partition, strict unexpired lease, matching partitioned records, ready markers, and cached media."
  - "Invalid practice input stays local with inline feedback and cannot create a receipt or outbox row."
metrics:
  duration: 17min
  completed: 2026-08-19
  tasks: 1
  files: 6
status: complete
---

# Phase 247 Plan 05: Partition-First Offline Practice Summary

**The learning twin now gates offline practice on the current account partition and valid lease, with accessible inline form validation and a generic recovery shell.**

## Accomplishments

- Added current-activation invalidation for expiry and changed-account bootstrap before local state can be used.
- Added a Tasklane-tokenized practice form that preserves invalid input and queues only bounded, credential-free partitioned actions.
- Updated the worker shell to remain generic and cache only its static assets; browser proof covers shell fallback, marker integrity, and practice submission.

## Task Commits

1. **Task 1 RED: add failing offline practice form coverage** — `e3f6648c`
2. **Task 1 GREEN: enforce partitioned offline practice** — `f37b3573`

## Verification

- `SIGRA_EXAMPLE_URL=http://localhost:4002 npm test -- twin-offline.spec.ts --project=chromium` — passed (7 tests).
- `node --check test/example/priv/static/assets/js/learning_twin.js` — passed.
- `mix format --check-formatted test/example/lib/example/learning_twin.ex` — passed.

## Deviations from Plan

### Auto-fixed Issues

1. **[Rule 2 - Critical UI support] Added the host-rendered accessible practice form.**
   - **Found during:** Task 1
   - **Issue:** The planned client validation had no labelled form, checkpoint context, receipt empty state, or Tasklane-scoped surface to operate on.
   - **Fix:** Added semantic form markup and `vt-twin-*` styles using existing shared tokens.
   - **Files modified:** `test/example/lib/example/learning_twin.ex`, `test/example/priv/static/assets/css/app.css`
   - **Verification:** Focused Chromium matrix passed.
   - **Commit:** `f37b3573`

2. **[Rule 3 - Verification environment] Started the repository-provided test PostgreSQL and Phoenix host.**
   - **Found during:** Task 1 RED verification
   - **Issue:** No example application server was listening for the Playwright base URL.
   - **Fix:** Used `scripts/db/up.sh` and the test-mode Phoenix server at port 4002 for deterministic browser verification.
   - **Verification:** Focused Chromium matrix passed.

**Total deviations:** 2 auto-fixed (Rule 2: 1, Rule 3: 1). No product scope expanded beyond the planned client and UI contract.

## Known Stubs

None.

## Self-Check: PASSED

- Confirmed all six modified implementation and proof files exist.
- Confirmed `e3f6648c` and `f37b3573` exist in git history.
- Confirmed the focused browser, JavaScript syntax, and formatting checks passed.
