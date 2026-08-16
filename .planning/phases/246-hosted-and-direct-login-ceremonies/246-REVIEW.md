---
phase: 246-hosted-and-direct-login-ceremonies
reviewed: 2026-08-16T18:00:00Z
depth: standard
files_reviewed: 34
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
  - test/sigra/app_login_audit_cofate_test.exs
  - test/sigra/app_login_direct_fault_test.exs
  - test/sigra/app_login_direct_test.exs
  - test/sigra/app_login_test.exs
  - test/sigra/credential_boundary_docs_test.exs
  - test/sigra/install/app_sessions_auth_continuation_test.exs
  - test/sigra/install/app_sessions_generator_test.exs
  - test/sigra/install/app_sessions_mfa_session_upgrade_test.exs
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

**Reviewed:** 2026-08-16T18:00:00Z
**Depth:** standard
**Files Reviewed:** 34
**Status:** issues_found

## Summary

The hosted and direct ceremony code correctly uses database locking for exchange/MFA consumption and bounds the hosted callback/profile/PKCE inputs. However, the generated controller verifies and consumes MFA factors before it establishes that the request is in the MFA-pending session state. That lets an ordinary authenticated session consume a one-time backup code (or advance a TOTP replay marker) and then fail session upgrade. Cancellation also only deletes the browser-held continuation and does not make the signed continuation unusable.

## Critical Issues

### CR-01: MFA endpoint consumes factors outside an MFA-pending session

**File:** `priv/templates/sigra.install/core/mfa_challenge_controller.ex:38-54`

**Issue:** `create/2` reads the current user and calls `Auth.mfa_verify/2` or `Auth.mfa_verify_backup/2` before it checks either `:mfa_pending` or that `conn.private[:sigra_session]` has type `:mfa_pending`. `finish_mfa_verification/5` only detects the invalid session afterwards (lines 88-118). A normally authenticated user can submit this CSRF-protected endpoint with a valid backup code: `Sigra.MFA.verify_backup/3` consumes that code, then `complete_mfa_session/4` rejects the standard session and returns an error. The same ordering can consume a valid TOTP step/replay state without completing MFA. This is one-time credential loss and breaks the normal MFA lifecycle.

**Fix:** Gate the action before calling either factor verifier, and redirect/reject invalid state without performing verification. For example:

```elixir
def create(conn, %{"mfa" => mfa_params}) do
  with true <- get_session(conn, :mfa_pending) == true,
       %{type: :mfa_pending} = old_session <- conn.private[:sigra_session],
       %{user: user} <- conn.assigns.current_scope do
    verify_and_finish_mfa(conn, user, old_session, mfa_params)
  else
    _ -> conn |> redirect(to: ~p"/users/log_in") |> halt()
  end
end
```

Keep the factor verification and `Auth.complete_mfa_verification/3` in the same valid-state path, and add controller-mode tests for regular-session submissions with valid TOTP and backup codes proving no factor state changes.

## Warnings

### WR-01: Cancelling a hosted ceremony does not invalidate its signed continuation

**File:** `lib/sigra/app_login.ex:72-75`

**Issue:** The `:cancel` clause returns success for any inputs and creates no consumed/revoked state. The controller only removes the continuation from the current Plug session (`app_login_controller.ex:46-51`). Because the continuation itself is a valid stateless signed token until its five-minute TTL, a copied/pre-cancel session cookie can still submit that continuation to `:approve` and obtain a code. This makes cancellation local to one browser cookie rather than terminal for the ceremony.

**Fix:** Persist cancellation/approval state keyed by the signed continuation nonce and atomically mark it terminal for either decision; have approval reject any nonce already marked cancelled or consumed. Add a regression test that cancels, restores the pre-cancel continuation/session handle, and verifies approval is rejected.

---

_Reviewed: 2026-08-16T18:00:00Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
