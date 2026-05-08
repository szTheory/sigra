---
phase: 108-revoke-other-sessions-and-session-truth
plan: 02
subsystem: ui
tags: [liveview, generated-host, templates, sessions, auth]
requires:
  - phase: 108-revoke-other-sessions-and-session-truth
    provides: preserve-current session revoke API in Sigra.Auth
provides:
  - generated user session UI wired to preserve-current revoke semantics
  - template parity for current-session hashing and revoke-others copy
  - focused example LiveView test coverage for preserve-current session UX
affects: [admin session truth, install golden snapshots, session docs]
tech-stack:
  added: []
  patterns: [authoritative current-session hashing from user_token, preserve-current LiveView refresh flow]
key-files:
  created:
    - .planning/phases/108-revoke-other-sessions-and-session-truth/108-02-SUMMARY.md
    - test/example/test/example_web/live/auth/session_live_test.exs
  modified:
    - test/example/lib/example/accounts.ex
    - test/example/lib/example_web/live/auth/session_live.ex
    - priv/templates/sigra.install/core/auth.ex
    - priv/templates/sigra.install/core/session_live.ex
    - test/sigra/templates/session_templates_test.exs
    - test/mix/tasks/sigra.install_test.exs
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/auth/session_live.ex
key-decisions:
  - "Derive the current hashed session token from the authenticated user_token instead of the old raw-token-vs-hashed-token LiveView comparison."
  - "Keep the preserve-current action in place with flash + refresh semantics rather than redirecting to log in."
patterns-established:
  - "Generated hosts should expose a thin revoke_other_sessions wrapper that injects PubSub and delegates to Sigra.Auth."
  - "Current-session labeling should depend on authoritative hashed-token resolution, not connect-param decoding heuristics."
requirements-completed: [SESS-02, SESS-04, SESS-05]
duration: 30min
completed: 2026-05-08
---

# Phase 108 Plan 02 Summary

**The generated user sessions surface now keeps the current device signed in while revoking sibling sessions through the library-owned preserve-current seam**

## Performance

- **Duration:** 30 min
- **Started:** 2026-05-08T11:30:00Z
- **Completed:** 2026-05-08T11:59:32Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- Added generated-host wrappers for `revoke_other_sessions/3` and `current_session_hashed_token/1`.
- Replaced the destructive `revoke_all` user-session action with an in-place `revoke_others` flow and truthful flash messaging.
- Mirrored the same behavior into install templates, template tests, mix install template assertions, and the committed install-golden fixture.

## Task Commits

Atomic task commits were not created.

- The repo already had extensive unrelated unstaged changes, including pre-existing edits in `test/example/lib/example/accounts.ex` and template-adjacent files.
- Safe per-task commits in the shared working tree would have mixed unrelated work with the Phase 108 delta.

## Files Created/Modified

- `test/example/lib/example/accounts.ex` - added preserve-current wrapper and current hashed-token helper.
- `test/example/lib/example_web/live/auth/session_live.ex` - switched the user action to `revoke_others`, kept the session page live, and used authoritative current-session hashing.
- `priv/templates/sigra.install/core/auth.ex` - mirrored generated-host wrapper helpers.
- `priv/templates/sigra.install/core/session_live.ex` - mirrored preserve-current LiveView behavior and copy.
- `test/example/test/example_web/live/auth/session_live_test.exs` - added focused preserve-current example-app coverage.
- `test/sigra/templates/session_templates_test.exs` - updated raw template assertions for the new helper contract.
- `test/mix/tasks/sigra.install_test.exs` - updated rendered template copy expectations.
- `test/fixtures/install_golden/tree/...` - refreshed committed install-golden artifacts for the new helper and UI copy.

## Verification

- `bash -lc 'cd test/example && MIX_ENV=test mix compile --warnings-as-errors'`
  Result: pass
- `rg -n "Log out of other devices|revoke_others|current_session_hashed_token|This device" test/example/lib/example_web/live/auth/session_live.ex priv/templates/sigra.install/core/session_live.ex test/example/test/example_web/live/auth/session_live_test.exs`
  Result: pass
- `bash -lc 'cd test/example && CLOAK_KEY=... MIX_ENV=test mix test test/example_web/live/auth/session_live_test.exs --no-color'`
  Result: blocked before tests ran by a pre-existing example-app migration failure in `20260507220000_add_webhook_replay_fields` (`webhook_deliveries_replayed_from_webhook_delivery_id_fkey` already exists)

## Decisions Made

- Removed the old connect-param decode check for current-session truth because it compared the wrong identity shape against persisted session rows.
- Used `{:error, :current_session_not_found}` as a user-visible fail-closed branch instead of silently degrading to revoke-all behavior.

## Deviations from Plan

None in implementation scope. Verification was blocked by an unrelated pre-existing example-app migration defect.

## Issues Encountered

- The example-app test database cannot migrate cleanly because `test/example/priv/repo/migrations/20260507220000_add_webhook_replay_fields.exs` attempts to add a foreign-key constraint that already exists. This prevented the new LiveView test from executing even after the example test DB was dropped and recreated.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The generated user surface and install templates are aligned on the preserve-current session model.
- Full example-app runtime verification still needs the unrelated webhook replay migration defect fixed first.

## Self-Check

FAILED

- Verified the example app compiles with warnings denied.
- Verified the preserve-current code paths and template parity markers exist in the expected files.
- Could not execute the new example-app LiveView test because migrations fail before tests start due to a pre-existing webhook replay schema issue.

---
*Phase: 108-revoke-other-sessions-and-session-truth*
*Completed: 2026-05-08*
