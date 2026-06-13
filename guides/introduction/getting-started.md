> **Reading map:** [GA evidence & audit posture](../../docs/ga-evidence.md) · [Maintaining & releasing](../../MAINTAINING.md) · [Audit semantics](../../docs/audit-semantics.md) · [Contributing](../../CONTRIBUTING.md) · [Security policy](../../SECURITY.md)

# Getting Started

This guide takes you from a fresh Phoenix app with Sigra installed to a working auth experience: register a user, log in, protect a route, log out, request a password reset, click the reset link, and log in again with the new password. **Budget: under 30 minutes of reading.** Every code block here runs against the scaffolding `mix sigra.install` generates.

If you have not installed Sigra yet, read [Installation](installation.html) first.

**Faster path:** [First hour with Sigra](first-hour.html) · [Troubleshooting install](troubleshooting-install.html) · [Upgrading notes — v1.7](upgrading-to-v1.7.html) · [Upgrading notes — v1.8](upgrading-to-v1.8.html) · [Upgrading notes — v1.10](upgrading-to-v1.10.html) · [Upgrading notes — v1.11](upgrading-to-v1.11.html) · [Upgrading notes — v1.12](upgrading-to-v1.12.html)

## Prerequisites

- Phoenix 1.8+ app named `MyApp` (substitute your app name throughout)
- PostgreSQL running
- `{:sigra, "~> 1.0"}` in `mix.exs` and `mix deps.get` already run. If you are reading `main` before Hex shows `1.0.0`, use the latest published Sigra package or a source checkout until the release PR lands.
- `mix sigra.install && mix ecto.migrate` already run (Sigra generates `uuid` / binary_id primary keys by default; pass `--no-binary-id` to `mix sigra.install` if you need bigint integer IDs instead)

Verify the install by checking for the generated `Accounts` context and `UserAuth` plug:

    ls lib/my_app/accounts.ex lib/my_app_web/user_auth.ex

Both files should exist. If they don't, run `mix sigra.install` and then `mix ecto.migrate`.

## 1. Start the server

    mix phx.server

The server boots at <http://localhost:4000>. Leave it running in a separate terminal — you'll use it throughout this walkthrough.

## 2. Register your first user

Visit <http://localhost:4000/users/register>. The generated `RegistrationLive` renders a form with two fields: email and password. Under the hood, submitting the form calls:

    # lib/my_app_web/live/user_registration_live.ex
    def handle_event("save", %{"user" => user_params}, socket) do
      case Accounts.register_user(user_params) do
        {:ok, user} ->
          {:ok, _} =
            Accounts.deliver_user_confirmation_instructions(
              user,
              &url(~p"/users/confirm/#{&1}")
            )

          {:noreply,
           socket
           |> put_flash(:info, "User created successfully.")
           |> push_navigate(to: ~p"/users/log_in")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, check_errors: true) |> assign_form(changeset)}
      end
    end

Submit the form with a real-looking email (`alice@example.com`) and a strong password (12+ characters). On success you are redirected to the login page with a flash message.

**Important:** Sigra uses the [phx.gen.auth naming convention](https://hexdocs.pm/phoenix/mix_phx_gen_auth.html). The context function is `register_user/2`, never `create_user/1` or `signup/1`. Keep your custom code in the same vocabulary to avoid churn when you upgrade.

### What just happened in the database

    mix run -e 'MyApp.Repo.all(MyApp.Accounts.User) |> IO.inspect()'

You should see one `%MyApp.Accounts.User{}` struct with:

- `email: "alice@example.com"`
- `hashed_password: "$argon2id$v=19$..."` (Argon2id, never the plaintext)
- `confirmed_at: nil` (confirmation email sent but not yet clicked)
- `inserted_at` and `updated_at` timestamps

The password was hashed by `Sigra.Crypto.hash_password/1` inside `Accounts.register_user/2`. The raw password is never stored.

## 3. Confirm the email (optional but recommended)

Sigra ships with the Swoosh dev mailer by default, so confirmation emails land at <http://localhost:4000/dev/mailbox> in development. Open that URL in another tab.

You'll see one message: **"Confirmation instructions"** addressed to `alice@example.com`. Open it. The body contains a link like:

    http://localhost:4000/users/confirm/SFMyNTY.g2gDbQAAABJh...

Click the link. `ConfirmationLive` calls `Accounts.confirm_user/1` under the hood, which verifies the HMAC-signed token, sets `confirmed_at: DateTime.utc_now()`, and invalidates the token so it can't be replayed.

If you skip this step, the user can still log in unless you set `require_confirmation: true` in your Sigra config (see [User Registration](registration.html#requiring-confirmation)).

## 4. Log in

Visit <http://localhost:4000/users/log_in>. Enter `alice@example.com` and the password you chose in step 2.

The form posts to `SessionController.create/2`, which calls:

    # lib/my_app_web/controllers/session_controller.ex  (or the LiveView handler)
    case Accounts.get_user_by_email_and_password(email, password) do
      %User{} = user ->
        UserAuth.log_in_user(conn, user, params)

      nil ->
        conn
        |> put_flash(:error, "Invalid email or password")
        |> redirect(to: ~p"/users/log_in")
    end

`UserAuth.log_in_user/3` generates a session token, writes it to the Phoenix session cookie, and (if `remember_me` is checked) sets a long-lived remember-me cookie with the Sigra-signed token. The user is redirected to `/` and you see their email rendered in the default layout.

### Verify the session

Open your browser's devtools → Application → Cookies. You should see:

- `_my_app_key` — the Phoenix session cookie, containing the signed session token.
- `_my_app_web_user_remember_me` — only if you checked the remember-me box. HTTP-only, Secure in prod, SameSite=Lax.

Neither cookie contains the user's password or any reversible identifier.

## 5. Protect a route

Open `lib/my_app_web/router.ex`. The generator added auth pipelines — find the one called `:require_authenticated_user`:

    pipeline :require_authenticated_user do
      plug :fetch_current_scope
      plug :require_authenticated_user
    end

And the authenticated `live_session` block:

    scope "/", MyAppWeb do
      pipe_through [:browser, :require_authenticated_user]

      live_session :require_authenticated_user,
        on_mount: [{MyAppWeb.UserAuth, :ensure_authenticated}] do
        live "/dashboard", DashboardLive
      end
    end

Any route inside this block rejects unauthenticated visitors and redirects them to `/users/log_in`. Add a route like `/dashboard` and visit it — you'll see the LiveView only because you're logged in. Log out (next section) and try again — you'll be bounced to the login page.

`UserAuth.require_authenticated_user/2` is a plug; `MyAppWeb.UserAuth.on_mount(:require_authenticated, ...)` is its LiveView counterpart. Both are in the generated `user_auth.ex` and both read the current user from the session cookie.

## 6. Log out

The default layout includes a "Log out" link that posts to `DELETE /users/log_out`. That route calls:

    # lib/my_app_web/user_auth.ex
    def log_out_user(conn) do
      user_token = get_session(conn, :user_token)
      user_token && Accounts.delete_user_session_token(user_token)

      conn
      |> renew_session()
      |> delete_resp_cookie(@remember_me_cookie)
      |> redirect(to: ~p"/")
    end

`delete_user_session_token/1` removes the row from `auth.user_tokens` on Postgres installs, `renew_session/1` rotates the Phoenix session ID to defeat session-fixation, and the remember-me cookie is cleared. After the redirect, the user is anonymous again and protected routes bounce them to `/users/log_in`.

Confirm: open devtools → Cookies. The `_my_app_key` value should have changed (session renewed) and `_my_app_web_user_remember_me` should be gone.

## 7. Request a password reset

Visit <http://localhost:4000/users/reset-password>. Enter `alice@example.com` and submit. The generated `ResetPasswordLive` calls:

    Accounts.deliver_user_reset_password_instructions(
      user,
      &url(~p"/users/reset-password/#{&1}")
    )

This generates an HMAC-signed reset token, stores its hash in `auth.user_tokens` with a 60-minute TTL, and sends the email via the configured mailer. **By design, the form shows the same success message whether or not the email exists in your database** — this prevents enumeration attacks.

Check <http://localhost:4000/dev/mailbox> again. You'll see a new message: **"Reset password instructions"**. The body contains a link like:

    http://localhost:4000/users/reset-password/SFMyNTY.g2gDbQAAACBl...

## 8. Click the reset link

Click the link (or copy it into your browser). `ResetPasswordLive` looks up the token via `Accounts.get_user_by_reset_password_token/1`, which:

1. Decodes the HMAC-signed token (rejects tampered tokens immediately).
2. Looks up the matching row in `auth.user_tokens` by the token's hash (not the raw value).
3. Checks that `inserted_at + 60 minutes > now`.
4. Returns the associated user, or `nil` if any check fails.

If the token is valid, you see a form with two fields: **new password** and **confirm new password**. Enter a new password (`mynewsecret12345`) in both fields and submit. The form calls:

    Accounts.reset_user_password(user, %{"password" => new_password, "password_confirmation" => confirm})

which updates the `hashed_password` field and — critically — deletes **all** sessions and tokens for that user via `Accounts.delete_all_user_session_tokens/1`. Anyone who was logged in as `alice@example.com` on any device is now logged out.

You're redirected to the login page with a "Password reset successfully" flash.

## 9. Log in with the new password

Enter `alice@example.com` and the new password. You're logged in again, and a brand-new session token is written to the cookie. The old tokens are gone forever.

## 10. Organizations & Passkeys

The default `mix sigra.install` flow now gives you logical organizations and passkeys out of the box. Keep the app from steps 1-9 running and continue on the same happy path.

If you intentionally want the old posture, install with `--no-organizations` or `--no-passkeys`. Treat those as exceptions. The mainline install remains:

    mix sigra.install

### 10.1 Check the generated organizations surface

Look for the generated organization-aware modules:

    ls \
      lib/my_app/organizations.ex \
      lib/my_app/accounts/organization.ex \
      lib/my_app/accounts/organization_membership.ex \
      lib/my_app/accounts/user_session.ex

On the default install, a newly registered user gets a personal organization and the session can track an `active_organization_id`. You will also see organization routes such as `/organizations`, `/organizations/:slug/settings`, and `/organizations/:slug/members`.

### 10.2 Sign in and confirm the org-aware redirect

Log in with the user you created earlier. On a fresh default install the post-login landing page is either:

- `/` when the user already has an active personal organization
- `/organizations` when the user needs to create or accept one

That behavior is intentional. The generated app keeps you on an org-safe path instead of letting tenant-aware pages render without an active organization.

### 10.3 Scope tenant-owned queries with `for_org/2`

Sigra ships logical multi-tenancy, not schema-per-tenant. Tenant-owned data stays in the same database and is scoped by `organization_id`.

When you add your own org-owned schemas, scope them explicitly:

    def list_projects(scope) do
      Project
      |> Sigra.Organizations.Query.for_org(scope)
      |> MyApp.Repo.all()
    end

`for_org/2` accepts either the current scope or a raw organization ID and raises if the schema has no `organization_id` column. Keep that explicit discipline in app code; it is the main guard against cross-org leaks.

### 10.4 Enroll a passkey from MFA settings

Visit <http://localhost:4000/users/settings/mfa>. The generated settings page includes a **Passkeys** section with an **Add passkey** button.

The default config injected by `mix sigra.install` looks like:

    config :my_app, :sigra_config,
      passkeys: [
        rp_id: "localhost",
        rp_name: "My App",
        origin: "http://localhost:4000",
        passkey_primary_enabled: true
      ]

When you click **Add passkey**, the app posts to `/users/settings/mfa/passkeys/options`, the browser completes the WebAuthn ceremony, and the generated controller finishes registration at `/users/settings/mfa/passkeys`.

### 10.5 Try the passkey-primary login path

Open a private window and visit <http://localhost:4000/users/log_in>. With `passkey_primary_enabled: true`, the generated page keeps all three entry points visible:

- **Use a passkey**
- **Use password instead**
- **Email me a magic link**

That fallback mix is deliberate. Passkeys can be primary without removing recovery paths for devices that do not support WebAuthn or users who lose a credential.

### 10.6 Know the two production values you will eventually rename

Before production, update the passkey RP values in `config/runtime.exs`:

- `rp_id` must match the relying-party domain the browser should trust
- `origin` must match the full browser origin, including scheme

For local dev, `localhost` and `http://localhost:4000` are correct. For production, use your real hostnames and update both values together when you rename domains.

## 11. What you just built

In under 30 minutes you:

1. Registered a user with `Accounts.register_user/2` — Argon2id hashing, validation, audit log.
2. Delivered a confirmation email via `deliver_user_confirmation_instructions/2`.
3. Logged in with `UserAuth.log_in_user/3` — session token, remember-me cookie.
4. Protected a route with `:require_authenticated_user`.
5. Logged out with `UserAuth.log_out_user/1` — session renewed, cookies cleared, token deleted.
6. Delivered a password reset email with `deliver_user_reset_password_instructions/2`.
7. Reset the password with `reset_user_password/2` — all sessions invalidated.

8. Continued into the default organizations + passkeys surface.
9. Scoped tenant-owned queries with `Sigra.Organizations.Query.for_org/2`.
10. Enrolled a passkey and verified the passkey-primary login posture keeps password and magic link recovery available.

Every one of those calls is in the generated `Accounts`, `Organizations`, and `UserAuth` modules. You own that code: read it, edit it, extend it. Security-critical primitives (hashing, HMAC, TOTP, WebAuthn) live in the library and update via `mix deps.update sigra`.

## What's next

You've covered the core session auth flow. Most apps need one or more of:

- **[Generator and install options](../reference/generator-options.html)** — canonical `mix sigra.install` switches and defaults.
- **[After the first hour: toward solo production](intermediate-production-path.html)** — ordered path toward solo production confidence (links out to deployment + flows).
- **[Multi-factor authentication](mfa.html)** — TOTP enrollment, backup codes, trust-this-browser.
- **[Upgrading to v1.1](upgrading-to-v1.1.html)** — the tested `mix sigra.upgrade` path from v1.0.
- **[OAuth and social login](oauth.html)** — Google, GitHub, Apple via Assent.
- **[API authentication](api-authentication.html)** — Bearer tokens and JWT for non-browser clients.
- **[Account lifecycle](account-lifecycle.html)** — email change, password change, scheduled deletion.
- **[Audit logging](audit-logging.html)** — every auth event logged to `audit_events` with actor, target, metadata.

And a few cross-cutting recipes:

- **[Testing auth flows](testing.html)** — fixtures, scenario setup, `Sigra.Testing` helpers.
- **[Passkeys](passkeys.html)** — enrollment, passkey-primary config, RP ID/origin operations, recovery.
- **[Subdomain authentication](subdomain-auth.html)** — `cookie_domain` for `app.example.com` + `api.example.com`.
- **[Custom user fields](custom-user-fields.html)** — adding columns to the generated schema.
- **[Multi-tenant apps](multi-tenant.html)** — shipped logical-org posture and `for_org/2` discipline.
- **[Deployment](deployment.html)** — env vars, Fly.io, cookie config in production.

## Troubleshooting

- **"Invalid email or password" on a user you just created** — check `confirmed_at`. If you have `require_confirmation: true` in your Sigra config, you must click the confirmation link first. Otherwise click through <http://localhost:4000/dev/mailbox>.
- **Reset email never arrives in dev** — Swoosh dev mailer stores emails in memory at `/dev/mailbox`. For prod, configure a real adapter (Postmark, Mailgun, SES) in `config/runtime.exs`.
- **Remember-me cookie not persisting across browser restart** — verify you checked the box on the login form, then check devtools → Cookies for `_my_app_web_user_remember_me`. If it's missing, check your Phoenix endpoint's `secure_browser_headers` config.
- **Password reset link shows "Reset password link is invalid or it has expired"** — the token is older than 60 minutes, or the password has already been reset (tokens are single-use), or the URL was copied incorrectly.

## Before you ship to production

Skim the **[Production checklist (read first)](../recipes/deployment.html#production-checklist-read-first)** for HTTPS, cookies, and origin alignment. For mail queues and retries, read **[Mail delivery: inline vs Oban (TL;DR)](../recipes/deployment.html#mail-delivery-inline-vs-oban-tl-dr)**.
