---
phase: 238-generated-auth-runtime-proof
reviewed: 2026-08-05T21:45:30Z
depth: standard
files_reviewed: 13
files_reviewed_list:
  - lib/sigra/auth.ex
  - lib/sigra/config.ex
  - priv/templates/sigra.gen.oauth/oauth_controller.ex
  - priv/templates/sigra.install/core/auth.ex
  - priv/templates/sigra.install/core/reset_password_live.ex
  - priv/templates/sigra.install/core/session_controller.ex
  - scripts/ci/generated-auth-runtime-proof.sh
  - test/example/priv/playwright/fixtures/mailbox.ts
  - test/example/priv/playwright/playwright.config.ts
  - test/example/priv/playwright/tests/generated-auth.spec.ts
  - test/example/priv/playwright/tests/generated-auth-oauth-probe.spec.ts
  - test/sigra/config_test.exs
  - test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs
findings:
  critical: 1
  warning: 2
  info: 0
  total: 3
status: issues_found
---

# Phase 238: Code Review Report

**Reviewed:** 2026-08-05T21:45:30Z
**Depth:** standard
**Files Reviewed:** 13
**Status:** issues_found

## Summary

Reviewed the Phase 238 generated-host OAuth, password-reset, email-delivery, Playwright, and retained-CI changes in context with their template callers. The reset browser journey reports success while taking a documented legacy reset path that does not revalidate the signed reset token; this is a release blocker. The runtime proof also leaves two realistic regressions unobserved: email normalization can create undelivered credentials, and logout is not actually asserted.

## Critical Issues

### CR-01: Reset completion bypasses signed-token verification

**File:** `priv/templates/sigra.install/core/reset_password_live.ex:190`

**Issue:** The LiveView resolves a user from the signed token at mount (line 143), but submits `socket.assigns.user` to the legacy `reset_user_password/2` clause. That overload in `auth.ex:564-572` is explicitly test-only and bypasses HMAC validation, token expiry, reset-token lookup, audit, and telemetry. A LiveView mounted before a token expires or is invalidated can still change the password afterwards. The Phase 238 journey exercises this bypass and therefore does not prove the promised signed reset-token completion path.

**Fix:** Submit the saved signed token and handle invalid/expired results, rather than the user struct.

```elixir
case Accounts.reset_user_password(socket.assigns.token, password_params) do
  {:ok, _user} ->
    {:noreply,
     socket
     |> put_flash(:info, dgettext("sigra", "Password reset successfully!"))
     |> redirect(to: ~p"/users/log_in")}

  {:error, :token_invalid} ->
    {:noreply, assign(socket, token_invalid?: true, form: nil)}

  {:error, :token_expired} ->
    {:noreply, assign(socket, token_invalid?: true, form: nil)}

  {:error, %Ecto.Changeset{} = changeset} ->
    {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
end
```

Add a deterministic regression test that mounts with a valid token, invalidates or expires it before the `reset` event, and proves the event cannot update the password.

## Warnings

### WR-01: Normalized requests can mint a token without delivering its email

**File:** `priv/templates/sigra.install/core/auth.ex:152-165`

**Issue:** `request_magic_link/2` normalizes its email in `Sigra.Auth`, but the new delivery wrapper subsequently calls `get_user_by_email(email)` with the original input. The same raw-lookup pattern appears in reset delivery at lines 460 and 470. For a caller that supplies whitespace or a Unicode-normalization variant, the library can find the normalized account and persist a token, while the raw `Repo.get_by` returns `nil`; no mail is delivered. This creates unusable credentials and makes request behavior inconsistent with authentication.

**Fix:** Normalize once at the generated-context boundary and use the normalized value for both lookup and the Sigra request, ideally returning the resolved user/token together from the core operation to avoid a second query.

### WR-02: Logout proof accepts a redirect without proving session invalidation

**File:** `test/example/priv/playwright/tests/generated-auth.spec.ts:117-125`

**Issue:** `logOut` only asserts that a manual `fetch` receives an `opaqueredirect`, then navigates to the login page. Any redirect response satisfies that assertion even if the server fails to revoke the session; a login page can still render for an authenticated client. Subsequent steps can therefore pass with a live session, so this does not meet the phase's deterministic generated logout claim.

**Fix:** Exercise the generated logout control/form and verify a protected authenticated route redirects after it, or assert the session cookie/token is absent and a request requiring authentication receives the anonymous response. Keep this as a browser assertion rather than relying on separate ConnTest coverage.

---

_Reviewed: 2026-08-05T21:45:30Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
