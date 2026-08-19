---
phase: 247
fixed_at: 2026-08-19T03:33:06Z
review_path: /Users/jon/projects/sigra/.planning/phases/247-language-learning-digital-twin/247-REVIEW.md
iteration: 3
findings_in_scope: 9
fixed: 7
skipped: 2
status: partial
---

# Phase 247: Code Review Fix Report

**Fixed at:** 2026-08-19T03:33:06Z
**Source review:** /Users/jon/projects/sigra/.planning/phases/247-language-learning-digital-twin/247-REVIEW.md
**Iteration:** 3 (maximum)

**Summary:**

- Findings in scope across iterations: 9
- Fixed: 7
- Remaining: 2

## Fixed Issues

### CR-01: BLOCKER — Queued offline practice never replays after reopening online

**Files modified:** `test/example/priv/static/assets/js/learning_twin.js`, `test/example/priv/playwright/tests/twin-offline.spec.ts`
**Commit:** db7ccaa3
**Status:** fixed: requires human verification
**Applied fix:** Online boot now drains only the valid current-partition outbox through the existing cookie/CSRF replay route. A single in-flight foreground replay is coalesced, and a browser regression test reopens online without an `online` event and asserts one durable accepted receipt row.

### CR-02: BLOCKER — The automated proof asserts browser guarantees it does not test

**Files modified:** `test/example/priv/playwright/tests/twin-offline.spec.ts`, `.planning/phases/247-language-learning-digital-twin/247-EVIDENCE.json`
**Commit:** b9dc7b9f
**Applied fix:** Added deterministic Chromium coverage for lease expiry, cleanup failure and CSRF-protected DELETE logout, Bob/Alice partition isolation, Light/Dark/System resolution, and 320px long-copy control geometry/focus. Regenerated the exact-key source-bound evidence after the complete proof passed.

## Remaining Issues After Final Re-review

### CR-01: Expired online leases cannot be renewed

`bootstrap_for_current_scope/2` returns the expired lease error when no partition is requested instead of issuing a replacement lease. A signed-in learner can therefore remain permanently locked out after expiry.

### CR-02: Bootstrap/replay failures bypass logout cleanup

The logout cleanup handler is bound only after successful bootstrap and replay. Failure before that point leaves the normal logout control able to navigate without first clearing `current_activation`.

---

_Fixed: 2026-08-19T03:33:06Z_
_Fixer: the agent (gsd-code-fixer)_
_Iteration: 3 (maximum; partial)_
