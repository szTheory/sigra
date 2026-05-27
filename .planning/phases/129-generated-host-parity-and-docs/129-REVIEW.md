---
phase: 129-generated-host-parity-and-docs
reviewed: 2026-05-27T09:51:02Z
depth: standard
files_reviewed: 17
files_reviewed_list:
  - guides/flows/account-lifecycle.md
  - guides/flows/audit-logging.md
  - guides/recipes/testing.md
  - priv/templates/sigra.install/core/auth.ex
  - priv/templates/sigra.install/core/emails.ex
  - priv/templates/sigra.install/core/reactivation_live.ex
  - priv/templates/sigra.install/core/settings_live.ex
  - test/example/lib/example/accounts.ex
  - test/example/lib/example/accounts/emails.ex
  - test/example/lib/example_web/live/reactivation_live.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/emails.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/reactivation_live.ex
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/settings_live.ex
  - test/sigra/guides_dx02_test.exs
  - test/sigra/install/isolation_test.exs
  - test/sigra/templates/settings_live_test.exs
findings:
  critical: 1
  warning: 2
  info: 1
  total: 4
status: issues_found
---

# Phase 129: Code Review Report

**Reviewed:** 2026-05-27T09:51:02Z
**Depth:** standard
**Files Reviewed:** 17
**Status:** issues_found

## Summary

Reviewed the Phase 129 guide, generator-template, example-host, golden-fixture, and test changes for correctness, security posture, generated parity, and documentation drift. The main issue is that generated account settings exposes sensitive account lifecycle actions without the sudo protection the product docs and library comments require. Two correctness problems also remain in generated LiveView flows: email-change confirmation emails are never sent, and the reactivation sign-out link targets a DELETE-only route with LiveView navigation.

## Critical Issues

### CR-01: Account deletion and OAuth password setup bypass sudo protection

**File:** `priv/templates/sigra.install/core/settings_live.ex:249`
**Issue:** The generated `SettingsLive` lets OAuth-only users submit `set_password` directly from the normal authenticated `/users/settings` route. The same LiveView schedules deletion at line 273 without sudo gating. This contradicts the lifecycle guide's sudo requirement for setting OAuth passwords and destructive actions (`guides/flows/account-lifecycle.md:81` and `guides/flows/account-lifecycle.md:99`) and means a stolen or unattended authenticated session can set a password on an OAuth-only account or schedule account deletion without re-authentication.
**Fix:**
```elixir
def handle_event("set_password", %{"password" => params}, socket) do
  unless sudo_fresh?(socket.assigns.current_scope) do
    {:noreply, push_navigate(socket, to: ~p"/users/sudo?return_to=/users/settings#password")}
  else
    user = socket.assigns.current_scope.user
    attrs = Map.take(params, ["password", "password_confirmation"])
    # existing Auth.set_password branch
  end
end

def handle_event("confirm_delete", _params, socket) do
  unless sudo_fresh?(socket.assigns.current_scope) do
    {:noreply, push_navigate(socket, to: ~p"/users/sudo?return_to=/users/settings#delete")}
  else
    # existing Auth.schedule_deletion branch
  end
end
```

Apply the same generated-output expectation to `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/settings_live.ex:249` and add template tests that assert sudo redirection or route-level sudo protection for these sensitive events.

## Warnings

### WR-01: Email change UI claims a confirmation email was sent but no email is delivered

**File:** `priv/templates/sigra.install/core/settings_live.ex:196`
**Issue:** `Auth.request_email_change/2` returns `{:ok, _user, _token}`, but the LiveView discards the token and only flashes "We sent a confirmation link". The generated context wrapper in `priv/templates/sigra.install/core/auth.ex:972` also only delegates to `Sigra.Auth.request_email_change/4`; it does not deliver `Emails.email_change_confirmation_email/3` or the old-address notification from `priv/templates/sigra.install/core/emails.ex:514`. As generated, users cannot receive the token needed by `handle_params/3` to confirm the new email.
**Fix:** Add a generated delivery wrapper and call it from `SettingsLive`:
```elixir
def deliver_user_email_change_instructions(user, new_email, token, url_fun) do
  url = url_fun.(token)
  email = Emails.email_change_confirmation_email(user, new_email, url)

  Sigra.Delivery.deliver(:email_change_confirmation, %{
    user_id: user.id,
    to: new_email,
    subject: email.subject,
    body: %{html: email.html_body, text: email.text_body},
    token: token,
    url: url
  }, delivery_opts())
end
```

Then update the generated LiveView to use the returned `updated_user` and `token`, and add parity coverage for the template, example app, and golden fixture.

### WR-02: Reactivation sign-out link uses LiveView navigation for a DELETE-only route

**File:** `priv/templates/sigra.install/core/reactivation_live.ex:54`
**Issue:** The "I understand, sign me out" link uses `navigate={~p"/users/log_out"}`, but the generated router defines logout as `delete "/log_out", SessionController, :delete`. LiveView `navigate` issues client-side navigation and will not submit a DELETE request, so this sign-out option can fail instead of logging the user out. The same issue is present in the example and golden generated files at `test/example/lib/example_web/live/reactivation_live.ex:49` and `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/reactivation_live.ex:54`.
**Fix:**
```elixir
<.link
  href={~p"/users/log_out"}
  method="delete"
  class="block text-center text-sm text-gray-500 hover:underline"
>
  I understand, sign me out
</.link>
```

## Info

### IN-01: Account lifecycle guide references a nonexistent host delivery helper

**File:** `guides/flows/account-lifecycle.md:31`
**Issue:** The guide tells users to call `MyApp.Accounts.deliver_user_email_change_instructions/3`, but neither the reviewed generated context template nor the example/golden contexts define that function. This is documentation truth drift and currently masks the missing delivery path described in WR-01.
**Fix:** Either add the generated helper to `auth.ex` and keep this guide example, or rewrite the guide to show the actual generated helper name and arguments after WR-01 is fixed.

---

_Reviewed: 2026-05-27T09:51:02Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
