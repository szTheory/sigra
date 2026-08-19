---
phase: 247-language-learning-digital-twin
reviewed: 2026-08-19T03:33:06Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - .github/workflows/ci.yml
  - .planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-PLAYWRIGHT-INVENTORY.json
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
  - test/sigra/planning/phase_234_playwright_inventory_contract_test.exs
findings:
  critical: 2
  warning: 0
  info: 0
  total: 2
status: issues_found
---

# Phase 247: Code Review Report

**Reviewed:** 2026-08-19T03:33:06Z
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

The prior fresh-online replay repair is present: boot assigns `currentTwin` before replaying the authenticated current partition, and the expanded Chromium file produces 16 cases (15 declarations, including one two-row parameterized test). The canonical retry-zero lane, inventory entry, and all ten evidence source hashes match the reviewed files.

However, lease expiry cannot recover while connected, and a failed bootstrap/replay leaves logout unprotected even when an offline activation exists. Both conditions can retain account-bound offline data across a logout or permanently lock a learner out of the feature.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: An expired lease permanently prevents an online learner from receiving a replacement lease

**File:** `test/example/lib/example/learning_twin.ex:86-101`
**Issue:** `bootstrap_for_current_scope/2` only calls `active_or_new_lease/2` for `{:error, :unavailable}` (no lease row). Once the user's most recent lease reaches `expires_at`, `active_lease/2` returns `{:error, :expired}` and the final branch returns an error. Consequently, a signed-in user following the advertised “Connect and sign in to continue” recovery path receives a 403 / expired page forever; the normal bootstrap path cannot issue the replacement partition.
**Fix:** When no partition is requested, treat an expired current lease like an unavailable one and issue a new lease. Preserve the rejection path when an explicit old partition is supplied.

```elixir
{:error, reason} when reason in [:unavailable, :expired] and is_nil(requested_partition) ->
  {:ok, bootstrap_payload(active_or_new_lease(user_id, now))}
```

Add a controller or browser test that expires the current lease, reconnects while authenticated, and proves bootstrap returns a different, valid partition.

### CR-02: Bootstrap/replay failure bypasses the logout cleanup guard and can retain the prior account activation

**File:** `test/example/priv/static/assets/js/learning_twin.js:276-299`
**Issue:** The logout capture listener is installed only after successful bootstrap and `await replayQueued()`. A non-OK bootstrap response returns at line 278, and a rejected replay fetch propagates through line 283 to the outer `boot().catch(setUnavailable)` at line 304. In either case the page still has the normal header logout control, but clicks are no longer intercepted to run `clearCurrent()`. A valid `current_activation` and its cached lesson can therefore remain after logout and be exposed to the next user of the browser offline shell. The existing logout test only makes IndexedDB fail after successful boot, so it does not exercise this earlier bypass.
**Fix:** Bind the logout handler before any fallible bootstrap/replay work, and ensure it is installed exactly once. Keep replay failures local so they leave queued rows for retry rather than aborting boot.

```javascript
bindLogoutCleanup();
const response = await fetch('/app/lesson/bootstrap', { headers: { accept: 'application/json' } });
// ...
await replayQueued().catch(() => {});
```

Add deterministic tests for both a failed bootstrap and a rejected replay request: click logout, assert DELETE is not submitted until `current_activation` is removed, then sign in as the other account and prove the offline shell cannot render the first account's lesson.

---

_Reviewed: 2026-08-19T03:33:06Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
