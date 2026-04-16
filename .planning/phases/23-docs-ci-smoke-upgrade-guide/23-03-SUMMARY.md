---
phase: 23-docs-ci-smoke-upgrade-guide
plan: 03
subsystem: browser-smoke
tags: [playwright, ci, organizations, passkeys, example-app, dx-07]
requires:
  - phase: 16-org-liveviews-switcher
    provides: shipped organizations UI flow and switcher behavior
  - phase: 17-organizations-invitations
    provides: invitation accept flow and mailbox-driven invite lifecycle
  - phase: 21-passkey-liveviews-post-auth-controller
    provides: login and MFA passkey browser flows
provides:
  - CI-owned Playwright smoke covering organizations and invitation acceptance
  - browser smoke wired to the served example app on the same localhost origin as passkeys
  - example-app fixes for confirmation-token consumption, invitation mail delivery, and confirmation-token collision retry
affects: [ci, playwright, example-app, browser-smoke]
tech-stack:
  added: []
  patterns: [same-origin passkey smoke, mailbox-link normalization, clean browser-context invite acceptance]
key-files:
  created:
    - .planning/phases/23-docs-ci-smoke-upgrade-guide/23-03-SUMMARY.md
  modified:
    - .github/workflows/ci.yml
    - test/example/lib/example/accounts.ex
    - test/example/lib/example/accounts/emails.ex
    - test/example/lib/example_web/live/confirmation_live.ex
    - test/example/priv/playwright/fixtures/mailbox.ts
    - test/example/priv/playwright/tests/organizations.spec.ts
    - test/example/priv/playwright/tests/passkey-options.spec.ts
key-decisions:
  - "Kept the smoke suite on `http://localhost:4000` because WebAuthn RP ID validation rejects `127.0.0.1` for the current example-app passkey config."
  - "Used separate Playwright browser contexts for inviter and invitee flows so invitation acceptance reflects real session boundaries."
  - "Fixed the example app where the smoke exposed real defects instead of weakening the assertions around those defects."
patterns-established:
  - "Mailbox-derived links used in browser smoke should be normalized back to the current page origin before navigation."
  - "Cross-user flows in Playwright should use separate browser contexts instead of clearing cookies in the same page."
requirements-completed: [DX-07]
duration: 70 min
completed: 2026-04-16
---

# Phase 23 Plan 03: Browser smoke and CI wiring summary

**The example-app browser smoke now covers organizations, invitation acceptance, and passkey flows on the real served app, and it passes under the same localhost origin used in CI.**

## Performance

- **Duration:** 70 min
- **Completed:** 2026-04-16
- **Files modified:** 8

## Accomplishments

- Expanded the organizations smoke to cover invitation acceptance for both anonymous signup and signed-in matching-user paths.
- Wired the CI browser-smoke step to run the organizations and passkey specs together against the served example app.
- Fixed three example-app defects the smoke surfaced: confirmation links being consumed on disconnected render, invitation emails being built but never delivered, and rare confirmation-code collisions during rapid registrations.

## Files Created/Modified

- `.github/workflows/ci.yml` - runs the organizations and passkey Playwright smoke set against the served example app.
- `test/example/lib/example/accounts.ex` - retries confirmation token generation on the global `confirm_code` uniqueness collision.
- `test/example/lib/example/accounts/emails.ex` - delivers organization invitation emails instead of only building them.
- `test/example/lib/example_web/live/confirmation_live.ex` - avoids double-consuming confirmation links by only confirming on the connected LiveView mount.
- `test/example/priv/playwright/fixtures/mailbox.ts` - normalizes mailbox links back to the active origin before navigation.
- `test/example/priv/playwright/tests/organizations.spec.ts` - adds invitation acceptance coverage and uses separate browser contexts for inviter/invitee flows.
- `test/example/priv/playwright/tests/passkey-options.spec.ts` - keeps the passkey enrollment assertions on the real options/completion requests without relying on brittle response-body access.
- `.planning/phases/23-docs-ci-smoke-upgrade-guide/23-03-SUMMARY.md` - records execution outcomes for this plan.

## Decisions Made

- Treated the `localhost` vs `127.0.0.1` mismatch as an origin bug in local verification, not as a reason to weaken passkey assertions.
- Kept the invitation smoke mailbox-driven so the test exercises the actual delivery and acceptance path instead of manufacturing tokens in-process.
- Repaired the example app inline where the smoke exposed user-visible behavior gaps.

## Deviations from Plan

### Auto-fixed Issues

**1. [Blocking] Confirmation links were consumed twice in `ConfirmationLive`**
- **Issue:** disconnected render plus connected mount could both call confirmation, leaving browser confirmation links expired before the intended redirect.
- **Fix:** only call `Auth.confirm_user/1` on the connected mount and stop dereferencing a missing `current_scope.user`.

**2. [Blocking] Invitation emails were never delivered to the dev mailbox**
- **Issue:** the invitation email function built an email struct but never passed it to the mailer, so the browser smoke had no invitation link to follow.
- **Fix:** deliver the built invitation email and return it.

**3. [Blocking] Rapid registrations could collide on the global `confirm_code` unique index**
- **Issue:** the example app inserted confirmation tokens directly and could crash registration on an unlucky 6-digit collision.
- **Fix:** retry token generation when the `user_tokens_context_token_index` constraint trips.

## Verification

- `mix test test/sigra/auth_fixtures_scenario_test.exs test/sigra/testing_test.exs test/sigra/testing/assert_audit_logged_test.exs --max-failures 1`
- `mix test test/sigra/guides_dx02_test.exs --max-failures 1`
- `mix test test/upgrade_test.exs --max-failures 1`
- `mix docs --warnings-as-errors`
- `SIGRA_EXAMPLE_URL=http://localhost:4000 npx playwright test tests/organizations.spec.ts tests/passkey-login.spec.ts tests/passkey-options.spec.ts`

## Issues Encountered

- Running the passkey browser smoke on `127.0.0.1` causes WebAuthn registration to fail with `SecurityError: This is an invalid domain.` because the example app emits a `localhost` RP ID; the smoke is stable on `localhost`, which is already the CI posture.

## User Setup Required

None.

## Next Phase Readiness

- Phase 23 plan 03 now has a passing browser-smoke gate for the served example app.
- Later docs and CI work can rely on real invitation and passkey browser coverage instead of manual spot checks.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/23-docs-ci-smoke-upgrade-guide/23-03-SUMMARY.md`.
- Browser smoke passed on `http://localhost:4000`.
