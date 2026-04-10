# Multi-Factor Authentication

Sigra ships TOTP-based MFA (RFC 6238) with QR code enrollment, hashed backup codes, a challenge flow that integrates with the session token lifecycle, and a trust-this-browser cookie to reduce challenge friction. This guide covers the full enrollment and challenge lifecycle.

## What Sigra gives you

- **`MyAppWeb.MfaSettingsLive`** — enrollment LiveView: generates a TOTP secret, displays the QR code, verifies the first code, issues backup codes.
- **`MyAppWeb.MfaChallengeLive`** (and `MfaChallengeController`) — challenge LiveView shown during login when MFA is required. Accepts a TOTP code or a backup code.
- **`Sigra.MFA.enroll/2`** — library primitive: generates a secret, returns it for QR code display.
- **`Sigra.MFA.verify_totp/4`** — verifies a code against the stored secret. Uses RFC 6238 time-window tolerance.
- **`Sigra.MFA.BackupCodes.generate/1`** — generates N single-use codes, returns raw codes once and their SHA-256 hashes for storage.
- **`Sigra.MFA.Trust.cookie_opts/1`** — cookie options for the trust-this-browser cookie (honors `cookie_domain`).
- **`Sigra.Session`** — the session schema exposes `:mfa_pending` vs `:standard` types so the challenge flow can pin the session state.

## Happy path: enrollment

When a logged-in user clicks "Enable two-factor authentication," `MfaSettingsLive` calls:

    def handle_event("start_enrollment", _params, socket) do
      user = socket.assigns.current_scope.user

      case Sigra.MFA.enroll(config(), user) do
        {:ok, %{secret: secret, otpauth_uri: uri}} ->
          {:noreply, assign(socket, secret: secret, qr_uri: uri, step: :verify)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not start enrollment: #{inspect(reason)}")}
      end
    end

The QR code is rendered from `uri` (use any QR library — `eqrcode`, `QRCodeEx`). The user scans it in their authenticator app (Google Authenticator, 1Password, Authy, etc.).

The user enters the first 6-digit code shown in the app to prove enrollment worked:

    def handle_event("verify_enrollment", %{"code" => code}, socket) do
      user = socket.assigns.current_scope.user
      secret = socket.assigns.secret

      case Sigra.MFA.confirm_enrollment(config(), user, secret, code) do
        {:ok, user} ->
          {:ok, backup_codes} = Sigra.MFA.BackupCodes.generate(10)
          {:noreply, assign(socket, user: user, backup_codes: backup_codes, step: :show_backup_codes)}

        {:error, :invalid_code} ->
          {:noreply, put_flash(socket, :error, "Code is incorrect. Try again.")}
      end
    end

The 10 backup codes are shown to the user **once**. Their hashes are stored in the DB; the raw values are shown in the UI with a "Download" button and never again. If the user loses their phone without saving backup codes, they lose MFA access — they must contact support (or your account-recovery flow).

## Happy path: challenge

After enrollment, every login request for that user enters the MFA challenge flow. `UserAuth.log_in_user/3` detects the user has MFA enabled and creates a session with `type: :mfa_pending` instead of `:standard`. The router then redirects any protected request to the challenge page:

    pipeline :require_authenticated_user do
      plug :fetch_current_scope
      plug :require_authenticated_user
      plug :require_mfa_verified  # redirects to /users/mfa-challenge if :mfa_pending
    end

`MfaChallengeLive` renders a form with one field: **6-digit code**. Submitting calls:

    def handle_event("verify", %{"code" => code}, socket) do
      user = socket.assigns.current_scope.user
      session = socket.assigns.current_scope.session

      case Sigra.MFA.verify_totp(config(), user, code) do
        {:ok, _} ->
          {:ok, new_session} = Sigra.Auth.complete_mfa_verification(config(), user, session)
          # Session type flips to :standard; mfa_verified_at is set.
          {:noreply, push_navigate(socket, to: ~p"/dashboard")}

        {:error, :invalid_code} ->
          {:noreply, put_flash(socket, :error, "Invalid code")}
      end
    end

`complete_mfa_verification/4` updates the session row in place: `type: :standard`, `mfa_verified_at: DateTime.utc_now()`. The cookie does not change — the same token continues working. Only the server-side row flips.

## Backup codes

If the user cannot produce a TOTP code (lost phone), they can enter one of the 10 backup codes instead:

    case Sigra.MFA.verify_backup_code(config(), user, input) do
      {:ok, _} -> # mark this backup code as used; complete MFA
      {:error, :invalid_code} -> # fall through
    end

Backup codes are **single-use**. Each code's hash has a `used_at` column; verification rejects codes where `used_at != nil`. When the user runs low (say, 2 remaining), show a warning in `MfaSettingsLive` suggesting they regenerate.

## Trust this browser

The challenge page includes a "Remember this browser for 30 days" checkbox. When checked, `mfa_challenge_controller` sets a signed cookie via `Sigra.MFA.Trust.cookie_opts(config)`:

    # Generated mfa_challenge_controller.ex
    conn
    |> put_resp_cookie(
      Sigra.MFA.Trust.cookie_name(),
      trust_token,
      Sigra.MFA.Trust.cookie_opts(config) ++ [max_age: trust_ttl]
    )

The cookie is HTTP-only, Secure in prod, SameSite=Lax, and honors `cookie_domain` at runtime (see [Subdomain Authentication](subdomain-auth.html)). Next time this browser logs in, `UserAuth.log_in_user/3` reads the cookie, verifies it matches the user, and skips the MFA challenge entirely — the session goes straight to `:standard`.

The trust cookie does **not** replace MFA; it only bypasses the challenge on a pre-trusted device. If the user clears cookies, reinstalls their OS, or switches browsers, they'll see the challenge again.

## Enforcement policies

You can require MFA for all users, a subset (admins), or leave it opt-in:

    # Require MFA for users with an :admin role
    defp require_mfa_for_admins(conn, _opts) do
      user = conn.assigns.current_scope.user

      if user.role == :admin and not Sigra.MFA.enrolled?(user) do
        conn
        |> put_flash(:error, "Admins must enroll in MFA.")
        |> redirect(to: ~p"/users/settings/mfa")
        |> halt()
      else
        conn
      end
    end

## Testing

    test "MFA-enabled user sees challenge on login" do
      user = Sigra.Testing.user_fixture()
      secret = Sigra.Testing.setup_totp(user, config: MyApp.Auth.sigra_config())

      conn = post(build_conn(), ~p"/users/log-in", %{"user" => %{"email" => user.email, "password" => "secret123456"}})

      # Session exists but is :mfa_pending
      assert redirected_to(conn) == ~p"/users/mfa-challenge"
    end

    test "bypass MFA in tests when you don't care about the flow" do
      %{user: user, conn: conn} = Sigra.Testing.mfa_complete_fixture()
      conn = Sigra.Testing.bypass_mfa(conn)

      assert get(conn, ~p"/dashboard").status == 200
    end

## Related

- [Login and Logout](login-and-logout.html) — session token lifecycle that MFA plugs into.
- [Subdomain Authentication](subdomain-auth.html) — trust cookie honors `cookie_domain`.
- `Sigra.MFA` — enroll, verify_totp, verify_backup_code, enrolled?
- `Sigra.MFA.BackupCodes` — generate, verify
- `Sigra.MFA.Trust` — cookie_name, cookie_opts/1
