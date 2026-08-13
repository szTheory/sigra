---
phase: 246-hosted-and-direct-login-ceremonies
reviewed: 2026-08-13T04:32:10Z
depth: standard
files_reviewed: 31
files_reviewed_list:
  - .github/workflows/generated-app-login-runtime-proof.yml
  - guides/flows/api-authentication.md
  - guides/introduction/contract.md
  - lib/sigra/app_login.ex
  - lib/sigra/app_login/attempt.ex
  - lib/sigra/install/features/app_sessions.ex
  - priv/templates/sigra.install/app_sessions/app_login_approve.html.heex
  - priv/templates/sigra.install/app_sessions/app_login_continuation.ex
  - priv/templates/sigra.install/app_sessions/app_login_controller.ex
  - priv/templates/sigra.install/app_sessions/app_login_html.ex
  - priv/templates/sigra.install/app_sessions/app_sessions_migration.exs
  - priv/templates/sigra.install/app_sessions/auth_app_sessions.ex
  - priv/templates/sigra.install/app_sessions/first_party_apps.ex
  - priv/templates/sigra.install/app_sessions/router_injection.ex
  - priv/templates/sigra.install/app_sessions/user_app_login_attempt.ex
  - priv/templates/sigra.install/app_sessions/user_app_session_family.ex
  - priv/templates/sigra.install/app_sessions/user_app_session_token.ex
  - priv/templates/sigra.install/core/mfa_challenge_controller.ex
  - priv/templates/sigra.install/core/mfa_challenge_live.ex
  - priv/templates/sigra.install/core/session_controller.ex
  - priv/templates/sigra.install/core/user_auth.ex
  - scripts/ci/generated-app-login-runtime-proof.sh
  - test/sigra/app_login/concurrency_test.exs
  - test/sigra/app_login_direct_fault_test.exs
  - test/sigra/app_login_direct_test.exs
  - test/sigra/credential_boundary_docs_test.exs
  - test/sigra/install/app_sessions_auth_continuation_test.exs
  - test/sigra/install/app_sessions_generator_test.exs
  - test/sigra/install/app_sessions_routes_test.exs
  - test/sigra/planning/phase_246_generated_app_login_runtime_test.exs
  - test/support/app_login_schemas.ex
findings:
  critical: 1
  warning: 1
  info: 0
  total: 2
status: issues_found
---

# Phase 246: Code Review Report

**Reviewed:** 2026-08-13T04:32:10Z
**Depth:** standard
**Files Reviewed:** 31
**Status:** issues_found

## Summary

The hosted/direct ceremony implementation correctly keeps raw credentials out of persisted ceremony state and applies bounded public-route rate limiting. However, the newly wired hosted MFA continuation cannot complete for MFA-enabled users: successful TOTP/backup verification leaves the server-side session at `:mfa_pending`, so the approval endpoint sends the user back to the MFA page. The approval continuation is also replayable until expiry and can mint multiple authorization codes from one decision.

## Critical Issues

### CR-01: Hosted MFA completion never upgrades the pending browser session

**File:** `priv/templates/sigra.install/core/mfa_challenge_controller.ex:43-62`; `priv/templates/sigra.install/core/mfa_challenge_live.ex:374-429`

**Issue:** Both TOTP and backup-code paths call only `Auth.mfa_verify` / `Auth.mfa_verify_backup`, then delete the Plug-session marker and redirect to `/app-login/continue`. Those verification functions validate a factor but do not replace the database-backed `:mfa_pending` Sigra session. On the redirected request, `FetchSession` reloads that pending session and `AppLoginController.require_authenticated_browser/2` redirects back to `/users/mfa`. This makes a hosted app-login request for any MFA-enabled user loop indefinitely (including the LiveView path added for `--live`).

**Fix:** After successful factor verification, call the host's `Auth.complete_mfa_verification(user, old_session, remember_me: ...)`, write its new token with `UserAuth.put_user_session_token/2`, and only then clear `:mfa_pending`/redirect. Share this completion logic between controller and LiveView (or route LiveView completion through the controller) so both paths rotate the pending session before following the app-login continuation. Add an integration test for hosted login + MFA that asserts `/app-login/continue` renders approval rather than redirecting to `/users/mfa`.

## Warnings

### WR-01: A single approval continuation can mint multiple authorization codes

**File:** `lib/sigra/app_login.ex:73-96`; `priv/templates/sigra.install/app_sessions/app_login_controller.ex:33-42`

**Issue:** The signed continuation is stateless and `approve_hosted/5` only verifies it before inserting a new hosted-code row. It is not consumed in the database. `AppLoginContinuation.take/1` clears the browser cookie only after the insert, so concurrent/retried POSTs carrying the same pre-clear session cookie can each pass verification and mint a separate code/session family during the five-minute token lifetime. The code-replay protection tests do not cover replay of the approval decision itself.

**Fix:** Persist a digest/nonce for the continuation (or create the attempt before approval) and atomically mark it consumed in the same transaction that creates the hosted code; reject subsequent approvals. Add a concurrency test that submits the same continuation twice and asserts exactly one hosted code/family is issued.

---

_Reviewed: 2026-08-13T04:32:10Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
