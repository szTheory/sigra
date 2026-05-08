---
phase: 108-revoke-other-sessions-and-session-truth
plan: 03
subsystem: ui
tags: [admin, docs, sessions, liveview, guides]
requires:
  - phase: 108-revoke-other-sessions-and-session-truth
    provides: preserve-current session revoke API and generated session truth model
provides:
  - admin self-view current-session labeling based on authoritative session-token hashing
  - public docs that distinguish revoke-other-sessions from revoke-all
  - focused admin LiveView tests for self-view truth and non-self-view restraint
affects: [session docs, admin user detail UX, future session-control-plane follow-ons]
tech-stack:
  added: []
  patterns: [prepared admin session presentation, self-view-only current-session truth]
key-files:
  created:
    - .planning/phases/108-revoke-other-sessions-and-session-truth/108-03-SUMMARY.md
  modified:
    - lib/sigra/admin/users/detail.ex
    - lib/sigra/admin/live/user_show_live.ex
    - test/example/test/example_web/live/admin_user_show_live_test.exs
    - guides/flows/login-and-logout.md
    - guides/flows/account-lifecycle.md
key-decisions:
  - "Only self-view may mark a session as current on the admin surface; viewing another user must stay silent."
  - "Docs should describe revoke-other-sessions and revoke-all as distinct contracts without implying new activity-feed or timeout-precision features."
patterns-established:
  - "Admin detail loaders should prepare current-session truth from the authenticated user token and pass presentation-ready session fields into the LiveView."
  - "User-facing docs should call out fail-closed preserve-current semantics explicitly."
requirements-completed: [SESS-04, SESS-05]
duration: 25min
completed: 2026-05-08
---

# Phase 108 Plan 03 Summary

**Admin session rendering and public session docs now align with the preserve-current truth model without adding a new admin-only bulk action**

## Performance

- **Duration:** 25 min
- **Started:** 2026-05-08T11:35:00Z
- **Completed:** 2026-05-08T11:59:32Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Prepared admin session rows with authoritative self-view current-session truth and presentation-ready labels.
- Updated the admin user detail LiveView to render a `Current session` badge only when the signed-in admin is viewing their own session row.
- Updated login/logout and account-lifecycle guides to distinguish preserve-current revoke from destructive revoke-all behavior.

## Task Commits

Atomic task commits were not created.

- The repo already had extensive unrelated unstaged changes, and the admin/doc files live in the same shared working tree.
- Safe per-task commits would have risked bundling unrelated edits.

## Files Created/Modified

- `lib/sigra/admin/users/detail.ex` - added self-view current-session derivation and presentation-ready session maps.
- `lib/sigra/admin/live/user_show_live.ex` - rendered prepared current-session/state labels and threaded the authenticated user token into detail reloads.
- `test/example/test/example_web/live/admin_user_show_live_test.exs` - added self-view and non-self-view truth assertions.
- `guides/flows/login-and-logout.md` - documented preserve-current session revocation separately from revoke-all.
- `guides/flows/account-lifecycle.md` - aligned password-change preserve-current semantics with the new explicit revoke-other-sessions contract.

## Verification

- `MIX_ENV=test mix compile --warnings-as-errors`
  Result: pass
- `rg -n "Current session|Session type: standard|other sessions|revoke_other_sessions|delete_all_sessions|revoke all sessions" lib/sigra/admin/users/detail.ex lib/sigra/admin/live/user_show_live.ex test/example/test/example_web/live/admin_user_show_live_test.exs guides/flows/login-and-logout.md guides/flows/account-lifecycle.md`
  Result: pass
- `bash -lc 'cd test/example && CLOAK_KEY=... MIX_ENV=test mix test test/example_web/live/admin_user_show_live_test.exs --no-color'`
  Result: blocked before tests ran by the same pre-existing example-app migration failure in `20260507220000_add_webhook_replay_fields`

## Decisions Made

- Kept the admin surface bounded to rendering truth and existing controls only; no new admin-only preserve-current bulk action was added.
- Prepared session labels in the detail loader so the LiveView remains a renderer rather than a policy engine.

## Deviations from Plan

None in scope. Verification remained blocked by the unrelated example-app migration defect.

## Issues Encountered

- Example-app LiveView execution is still blocked by the existing webhook replay migration failure, so the new admin test could not run after the code compiled.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Admin and user surfaces now share the same current-session truth model in code and docs.
- Full example-app runtime proof still requires the webhook replay migration issue to be repaired outside Phase 108 scope.

## Self-Check

FAILED

- Verified the library compiles with warnings denied.
- Verified the admin truth and doc markers exist in the expected files.
- Could not execute the new admin example-app LiveView test because the example-app test DB migrations fail before tests start.

---
*Phase: 108-revoke-other-sessions-and-session-truth*
*Completed: 2026-05-08*
