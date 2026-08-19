---
phase: 247-language-learning-digital-twin
reviewed: 2026-08-19T03:07:00Z
depth: standard
files_reviewed: 14
files_reviewed_list:
  - scripts/ci/phase-247-language-twin-proof.sh
  - test/example/config/config.exs
  - test/example/lib/example/learning_twin.ex
  - test/example/lib/example_web.ex
  - test/example/lib/example_web/router.ex
  - test/example/priv/playwright/tests/twin-offline.spec.ts
  - test/example/priv/repo/migrations/20260819000000_create_learning_twin_tables.exs
  - test/example/priv/static/assets/css/app.css
  - test/example/priv/static/assets/js/learning_twin.js
  - test/example/priv/static/learning-twin-offline.html
  - test/example/priv/static/learning-twin-worker.js
  - test/example/test/example/learning_twin/learning_twin_test.exs
  - test/example/test/example_web/controllers/learning_twin_controller_test.exs
  - test/example/test/example_web/live/learning_twin_live_test.exs
findings:
  critical: 2
  warning: 3
  info: 0
  total: 5
status: issues_found
---

# Phase 247: Code Review Report

**Reviewed:** 2026-08-19T03:07:00Z
**Depth:** standard
**Files Reviewed:** 14
**Status:** issues_found

## Summary

The server-side lease and receipt boundaries are generally constrained to the authenticated scope, but the browser implementation does not deliver the required offline lesson and breaks the existing logout action. The browser suite also omits the specified offline, expiry, logout/account-switch, theme, and small-viewport proof, leaving these high-risk transitions untested.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: BLOCKER — Valid offline navigation cannot render or operate the cached lesson

**File:** `test/example/priv/static/assets/js/learning_twin.js:164-170`

**Issue:** `renderOffline/0` verifies the activation gate but only unhides the empty `data-testid="twin-lesson"` section supplied by the generic shell. It never renders `state.lesson`, media, the practice form, or receipts, and it never binds the form/replay listeners that `boot/0` installs online. Consequently a valid offline `/app/lesson` reload has no usable lesson or ability to queue an offline action, contrary to the phase offline contract.

**Fix:** Render the same safe lesson/form/receipt structure from the validated `lesson_state` (prefer a shared DOM template/render helper), bind the local form and replay handlers after the gate succeeds, and retain the generic expired shell only when the gate fails. Add a deterministic reload-offline test that asserts the title, image/audio, form, and one queued action.

### CR-02: BLOCKER — Intercepted logout navigates with GET and fails open if pointer deletion fails

**File:** `test/example/priv/static/assets/js/learning_twin.js:226-230`

**Issue:** The listener cancels Phoenix's method-aware DELETE link, then calls `window.location.assign('/users/log_out')`. The router exposes only `DELETE /users/log_out` (`router.ex:167`), so this sends an unmatched GET instead of logging the user out. Additionally, `.finally(...)` navigates even when `clearCurrent()` fails, violating the required “delete `current_activation` before navigation” boundary and leaving prior activation metadata available for a later offline reload.

**Fix:** Do not cancel the native method link until the deletion succeeds, or submit a CSRF-protected DELETE request/form after `await clearCurrent()`. On deletion failure, remain on the page in an explicit safe error state and do not navigate. Cover both the DELETE request and forced IndexedDB-delete failure in the same-context logout/offline test.

## Warnings

### WR-01: WARNING — Client accepts and stores unbounded offline answers

**File:** `test/example/priv/static/assets/js/learning_twin.js:172-187`

**Issue:** Client validation requires only a non-empty trimmed answer, then persists the original unbounded `form.elements.answer.value` into IndexedDB. The server caps answers at 120 bytes, so large offline entries occupy local storage and later fail replay rather than being rejected before persistence. This violates the phase's bounded offline-record contract.

**Fix:** Validate the exact transport schema before `put`, including `action === 'answer'` and `new TextEncoder().encode(answer).byteLength <= 120`; expose an inline validation message and create no outbox row when it fails. Add a browser assertion for an oversized multibyte answer.

### WR-02: WARNING — Offline shell requests a differently encoded JavaScript cache key

**File:** `test/example/priv/static/learning-twin-offline.html:3`

**Issue:** The shell loads `/assets/js/learning%5Ftwin.js`, while the worker installs `/assets/js/learning_twin.js` and later calls `cache.match(event.request)`. The worker identifies the encoded path only for interception, but cache matching uses the original request URL; percent-encoded and literal URL serializations are distinct cache keys. Offline script loading can therefore fall through to a failed network request even when the worker cache was installed.

**Fix:** Use the literal canonical URL in the shell (`/assets/js/learning_twin.js`) or match the canonical decoded shell key (for example `cache.match(decodeURIComponent(url.pathname), {ignoreSearch: true})`). Add a test that confirms the offline shell's JavaScript response is served from the shell cache while offline.

### WR-03: WARNING — Required browser boundary and accessibility matrix is absent

**File:** `test/example/priv/playwright/tests/twin-offline.spec.ts:163-243`

**Issue:** The only purported offline tracer asserts the generic “Connect and sign in” shell (lines 201-205), not the required valid cached lesson. The following describe block tests only form queuing. There are no deterministic cases for lease expiry, logout, account switch, valid offline rendering, Light/Dark/System resolution, or a 320px overflow/control check despite the phase plan requiring all of them. This leaves the defects above and account-isolation regressions undetected.

**Fix:** Add the specified pre-armed worker/controller, direct Cache Storage/IndexedDB inspection, offline reload, expiry, same-context logout/account-switch, theme, and 320px cases. Use the existing stable hooks and role selectors; do not use sleeps.

---

_Reviewed: 2026-08-19T03:07:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
