# Account Lifecycle

Sigra handles the full post-registration account lifecycle: changing email, changing password, setting a password on OAuth-only accounts, sudo mode for sensitive actions, and scheduled account deletion with a grace period. This guide covers each flow and the sudo-mode gating pattern.

## What Sigra gives you

- **`Sigra.Auth.request_email_change/4`** — generates a change-email token and sends verification to the new address.
- **`Sigra.Auth.confirm_email_change/3`** — verifies the token, updates the email, invalidates all sessions.
- **`Sigra.Auth.cancel_email_change/3`** — clears a pending email change.
- **`Sigra.Auth.change_password/5`** — verifies the current password, updates, and keeps only the current session.
- **`Sigra.Auth.set_password/4`** — adds a password to an OAuth-only account. Requires sudo mode.
- **`Sigra.Auth.confirm_sudo/3`** — elevates a session to sudo mode for a short window (default 15 min).
- **`Sigra.Auth.schedule_deletion/3`** — starts the grace-period deletion flow.
- **`Sigra.Auth.cancel_deletion/3`** — cancels scheduled deletion.
- **`Sigra.Auth.execute_deletion/3`** — called by the Oban worker when the grace period expires.
- **Generated `SettingsLive`** — the settings page that wires all of these up.

## Change email

The user enters a new email address. Sigra generates a token and sends a verification link to the **new** address. Only when the new address confirms does the email actually change.

    def handle_event("change_email", %{"user" => %{"email" => new_email}}, socket) do
      user = socket.assigns.current_scope.user
      config = MyApp.Auth.sigra_config()

      case Sigra.Auth.request_email_change(config, user, new_email,
             user_token_schema: MyApp.Accounts.UserToken,
             changeset_fn: &MyApp.Accounts.User.email_changeset/2
           ) do
        {:ok, _user, token} ->
          MyApp.Accounts.deliver_user_email_change_instructions(
            user,
            new_email,
            &url(~p"/users/settings/confirm-email/#{&1}")
          )

          {:noreply, put_flash(socket, :info, "Check #{new_email} for a confirmation link.")}

        {:error, changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end

The current email stays active until confirmation. When the user clicks the link, `SettingsLive.handle_params/3` calls `confirm_email_change/3`, which:

1. Verifies the HMAC-signed token.
2. Updates `user.email` and clears `user.pending_email`.
3. Deletes **all** sessions for that user (security-critical: an attacker who compromised the old email should not retain session access).

Log out → log in again with the new email.

## Change password

Sensitive — requires **current password** in addition to the new one:

    def handle_event("change_password", %{"user" => params}, socket) do
      user = socket.assigns.current_scope.user
      current_password = params["current_password"]

      case Sigra.Auth.change_password(config(), user, current_password, params,
             changeset_fn: &MyApp.Accounts.User.password_changeset/2
           ) do
        {:ok, _user} ->
          {:noreply,
           socket
           |> put_flash(:info, "Password updated.")
           |> push_navigate(to: ~p"/users/settings")}

        {:error, :invalid_current_password} ->
          {:noreply, put_flash(socket, :error, "Current password is incorrect.")}

        {:error, changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end

`change_password/5` uses `Ecto.Multi` to atomically update the password and delete every session **except the current one**. The user stays logged in on the current device but is logged out everywhere else.

## Set password (OAuth-only users)

Users who signed up via Google/GitHub have no password. To let them add one (so they can log in without the provider), use `set_password/4` — gated by sudo mode:

    def handle_event("set_password", %{"user" => params}, socket) do
      user = socket.assigns.current_scope.user

      unless sudo_mode?(socket.assigns.current_scope.session) do
        # Redirect to sudo confirmation first
        {:noreply, redirect(socket, to: ~p"/users/sudo?return_to=/users/settings/password")}
      else
        case Sigra.Auth.set_password(config(), user, params, changeset_fn: &User.password_changeset/2) do
          {:ok, _user} -> {:noreply, put_flash(socket, :info, "Password set.")}
          {:error, changeset} -> {:noreply, assign(socket, form: to_form(changeset))}
        end
      end
    end

## Sudo mode

Sudo mode elevates a normal session for a short window (default 15 minutes) after the user re-confirms their password. Guard any destructive action with it:

- Deleting the account
- Setting a password on an OAuth-only account
- Unlinking the last OAuth provider
- Revoking all API tokens
- Viewing sensitive personal data exports

The generated `SudoController` renders a password form and calls `Sigra.Auth.confirm_sudo/3` on success. The session row's `sudo_at` field is set to `DateTime.utc_now()`; `Sigra.Session.sudo?` returns true until `sudo_at + sudo_ttl < now`.

## Scheduled deletion

Immediate deletion is dangerous: users change their minds, and you lose audit history. Sigra's pattern is a grace period (default 14 days) during which the account is deactivated but recoverable.

### Step 1: Schedule

    def handle_event("delete_account", _params, socket) do
      user = socket.assigns.current_scope.user
      config = MyApp.Auth.sigra_config()

      case Sigra.Auth.schedule_deletion(config, user, user_token_schema: MyApp.Accounts.UserToken) do
        {:ok, _user, delete_at} ->
          {:noreply,
           socket
           |> put_flash(:info, "Account will be deleted on #{delete_at}. Log in again to cancel.")
           |> UserAuth.log_out_user()}
      end
    end

`schedule_deletion/3` sets `deletion_scheduled_at` on the user, **immediately revokes all sessions and tokens** (the user is logged out everywhere), and enqueues an Oban job for `delete_at`.

### Step 2: Cancel (before grace period ends)

If the user logs in during the grace window, show a reactivation banner:

    def handle_event("cancel_deletion", _params, socket) do
      user = socket.assigns.current_scope.user
      Sigra.Auth.cancel_deletion(config(), user)
      {:noreply, put_flash(socket, :info, "Deletion cancelled. Welcome back.")}
    end

`cancel_deletion/3` clears `deletion_scheduled_at` and cancels the Oban job.

### Step 3: Execute (grace period expires)

The Oban worker (`Sigra.Workers.DeleteAccount`) calls `execute_deletion/3` which applies your configured strategy:

    config :my_app, MyApp.Auth.Config,
      deletion: [
        strategy: :anonymize  # :soft_delete | :hard_delete | :anonymize
      ]

- `:hard_delete` — `Repo.delete(user)`. Cascades remove tokens, sessions, audit events.
- `:soft_delete` — sets `deleted_at`, keeps the row (and PII) in the DB. Good for audit compliance.
- `:anonymize` — clears PII fields (email, name) but keeps the row for referential integrity. Recommended default.

## Testing

    test "change_password keeps the current session and kills the rest" do
      %{user: user, conn: conn} = Sigra.Testing.authenticated_fixture()

      assert {:ok, _} = Accounts.change_password(user, "oldpassword12", %{"password" => "newpassword12"})

      # Current session is still valid
      assert get(conn, ~p"/dashboard").status == 200
    end

    test "schedule_deletion logs out and sets deletion_scheduled_at" do
      %{user: user, conn: conn} = Sigra.Testing.authenticated_fixture()

      {:ok, _, delete_at} = Sigra.Auth.schedule_deletion(config(), user, user_token_schema: UserToken)

      Sigra.Testing.assert_deletion_scheduled(Repo.reload(user))
      assert delete_at > DateTime.utc_now()
    end

## Related

- [OAuth and Social Login](oauth.html) — set_password flow for OAuth-only accounts.
- [Audit Logging](audit-logging.html) — every lifecycle event is logged.
- `Sigra.Account` — the underlying primitive module.
- `Sigra.Session` — sudo? and mfa_verified? helpers.
