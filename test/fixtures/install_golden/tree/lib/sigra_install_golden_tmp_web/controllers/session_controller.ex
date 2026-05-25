defmodule SigraInstallGoldenTmpWeb.SessionController do
  use SigraInstallGoldenTmpWeb, :controller

  alias SigraInstallGoldenTmp.Accounts, as: Auth
  alias SigraInstallGoldenTmpWeb.UserAuth

  @impersonation_denial_message "You can't change account security settings while impersonating."

  plug Sigra.Plug.ForbidDuringImpersonation,
       [
         message: @impersonation_denial_message,
         redirect_to: "/users/settings/mfa#passkeys",
         audit_action: "admin.impersonation.denied",
         audit_metadata: %{operation: "account_security_mutation"},
         audit_opts_fun: &__MODULE__.impersonation_denial_audit_opts/2
       ]
       when action in [:complete_passkey_registration, :delete_passkey]

  def impersonation_denial_audit_opts(conn, _scope) do
    Sigra.Auth.audit_opts_from_config(Auth.sigra_config(),
      ip_address: client_ip(conn),
      user_agent: client_user_agent(conn)
    )
  end

  def new(conn, _params) do
    email = Phoenix.Flash.get(conn.assigns.flash, :email) || ""
    form = Phoenix.Component.to_form(%{"email" => email}, as: "user")
    magic_link_form = Phoenix.Component.to_form(%{"email" => email}, as: "user")
    render(conn, :new,
      form: form,
      magic_link_form: magic_link_form,
      passkey_primary_enabled: Auth.passkey_primary_enabled?()
    )
  end

  def create(conn, %{"_action" => "magic_link", "user" => %{"email" => email}}) do
    url_fun = fn token -> url(conn, ~p"/users/log_in/#{token}") end

    case Auth.request_magic_link(email, url_fun) do
      {:ok, _} -> :ok
      {:error, :rate_limited} -> :ok
    end

    # Always show same message for enumeration prevention
    conn
    |> put_flash(:info, "If your email is registered, you will receive a magic link shortly.")
    |> redirect(to: ~p"/users/log_in")
  end

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Auth.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log_in")
    end
  end

  def magic_link(conn, %{"token" => token}) do
    case Auth.verify_magic_link(token) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome!")
        |> UserAuth.log_in_user(user)

      {:error, _} ->
        conn
        |> put_flash(:error, "Magic link is invalid or has expired.")
        |> redirect(to: ~p"/users/log_in")
    end
  end


  def passkey_registration_options(conn, _params) do
    user = conn.assigns.current_scope.user
    config = Sigra.Passkeys.config()
    {conn, challenge} = Sigra.Plug.PasskeyChallenge.issue(conn, :registration, config)

    json(conn, %{
      options: passkey_registration_options_json(user, challenge, Auth.passkeys_for_user(user), config)
    })
  end

  def passkey_authentication_options(conn, %{"conditional" => "true"}) do
    config = Sigra.Passkeys.config()
    {conn, challenge} = Sigra.Plug.PasskeyChallenge.issue(conn, :authentication, config)

    json(conn, %{options: conditional_passkey_authentication_options_json(challenge, config)})
  end

  def passkey_authentication_options(conn, %{"user" => %{"email" => email}}) do
    config = Sigra.Passkeys.config()

    case Auth.get_user_by_email(email) do
      nil ->
        json(conn, %{error: "unavailable"})

      user ->
        {conn, challenge} = Sigra.Plug.PasskeyChallenge.issue(conn, :authentication, config)

        json(conn, %{
          options: passkey_authentication_options_json(user, challenge, Auth.passkeys_for_user(user), config)
        })
    end
  end

  def passkey_authentication_options(conn, _params), do: json(conn, %{error: "unavailable"})

  def passkey_mfa_options(conn, _params) do
    if get_session(conn, :mfa_pending) == true do
      user = conn.assigns.current_scope.user
      config = Sigra.Passkeys.config()
      {conn, challenge} = Sigra.Plug.PasskeyChallenge.issue(conn, :authentication, config)

      json(conn, %{
        options: passkey_authentication_options_json(user, challenge, Auth.passkeys_for_user(user), config)
      })
    else
      json(conn, %{error: "unavailable"})
    end
  end

  def complete_passkey_registration(conn, %{"passkey" => passkey_params}) do
    user = conn.assigns.current_scope.user

    with {:ok, decoded_response} <- decode_passkey_response(passkey_params),
         {:ok, conn, credential} <-
           Sigra.Plug.PasskeyChallenge.verify(conn, :registration, Sigra.Passkeys.config(), [], fn challenge ->
             Auth.register_passkey(user, Map.put(decoded_response, "challenge", challenge), passkey_registration_details(conn))
           end) do
      _ = credential

      conn
      |> put_flash(:info, "Passkey added.")
      |> redirect(to: ~p"/users/settings/mfa#passkeys")
    else
      {:error, _conn, :duplicate_passkey} ->
        conn
        |> put_flash(:warning, "This passkey is already registered.")
        |> redirect(to: ~p"/users/settings/mfa#passkeys")

      {:error, :duplicate_passkey} ->
        conn
        |> put_flash(:warning, "This passkey is already registered.")
        |> redirect(to: ~p"/users/settings/mfa#passkeys")

      _ ->
        conn
        |> put_flash(:error, "We couldn't finish adding this passkey. Try again or use another way to continue.")
        |> redirect(to: ~p"/users/settings/mfa#passkeys")
    end
  end

  def complete_passkey(conn, %{"user" => %{"email" => email}, "passkey" => passkey_params}) do
    user = Auth.get_user_by_email(email)

    with {:ok, decoded_response} <- decode_passkey_response(passkey_params),
         %{} <- user,
         :ok <- Auth.ensure_passkey_primary_user_eligible(user),
         {:ok, conn, _credential} <-
           Sigra.Plug.PasskeyChallenge.verify(conn, :authentication, Sigra.Passkeys.config(), [], fn challenge ->
             Auth.authenticate_passkey(user, Map.put(decoded_response, "challenge", challenge))
           end) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user, %{})
    else
      {:error, :email_not_confirmed} ->
        passkey_login_failed(conn, email)

      _ -> passkey_login_failed(conn, email)
    end
  end

  def complete_passkey(conn, %{"passkey" => passkey_params}) do
    with {:ok, decoded_response} <- decode_passkey_response(passkey_params),
         {:ok, conn, {user, _credential}} <-
           Sigra.Plug.PasskeyChallenge.verify(conn, :authentication, Sigra.Passkeys.config(), [], fn challenge ->
             case Auth.authenticate_discoverable_passkey(Map.put(decoded_response, "challenge", challenge)) do
               {:ok, user, credential} -> {:ok, {user, credential}}
               {:error, reason} -> {:error, reason}
             end
           end),
         :ok <- Auth.ensure_passkey_primary_user_eligible(user) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user, %{})
    else
      {:error, :email_not_confirmed} -> passkey_login_failed(conn, nil)
      _ -> passkey_login_failed(conn, nil)
    end
  end

  def complete_passkey(conn, params) do
    email = get_in(params, ["user", "email"])
    passkey_login_failed(conn, email)
  end

  def complete_mfa_passkey(conn, %{"passkey" => passkey_params}) do
    return_to = get_session(conn, :mfa_return_to) || ~p"/"
    remember_me = get_session(conn, :mfa_remember_me) == true
    user = conn.assigns.current_scope.user
    old_session = conn.private[:sigra_session]

    with true <- get_session(conn, :mfa_pending) == true,
         %{type: :mfa_pending} <- old_session,
         {:ok, decoded_response} <- decode_passkey_response(passkey_params),
         {:ok, conn, _credential} <-
           Sigra.Plug.PasskeyChallenge.verify(conn, :authentication, Sigra.Passkeys.config(), [], fn challenge ->
             Auth.authenticate_passkey(user, Map.put(decoded_response, "challenge", challenge))
           end),
         {:ok, %{session: upgraded_session}} <- Auth.complete_mfa_verification(user, old_session, remember_me: remember_me) do
      conn
      |> UserAuth.put_user_session_token(upgraded_session.token)
      |> delete_session(:mfa_pending)
      |> delete_session(:mfa_return_to)
      |> delete_session(:mfa_remember_me)
      |> put_flash(:info, "Two-factor authentication verified.")
      |> redirect(to: return_to)
    else
      _ ->
        conn
        |> put_flash(:error, "We couldn't finish passkey sign-in. Try again or use another way to continue.")
        |> redirect(to: ~p"/users/mfa")
    end
  end

  def delete_passkey(conn, %{"id" => credential_id}) do
    user = conn.assigns.current_scope.user

    case Auth.delete_passkey(user, credential_id) do
      {:ok, %{remaining_passkeys: 0}} ->
        conn
        |> put_flash(:info, delete_passkey_success_message(:last_deleted))
        |> redirect(to: ~p"/users/settings/mfa#passkeys")

      {:ok, %{}} ->
        conn
        |> put_flash(:info, delete_passkey_success_message(:deleted))
        |> redirect(to: ~p"/users/settings/mfa#passkeys")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "We couldn't delete that passkey. Re-authenticate and try again.")
        |> redirect(to: ~p"/users/settings/mfa#passkeys")
    end
  end

  defp delete_passkey_success_message(:last_deleted) do
    "Last passkey deleted. Next time, sign in with your password, authenticator code, backup code, or magic link until you add another passkey."
  end

  defp delete_passkey_success_message(:deleted), do: "Passkey deleted."


  def delete(conn, _params) do
    Sigra.Telemetry.event(
      [:sigra, :auth, :logout, :stop],
      %{},
      %{user_id: conn.assigns[:current_scope] && conn.assigns.current_scope.user.id}
    )

    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end

  defp client_ip(conn) do
    conn.remote_ip && to_string(:inet.ntoa(conn.remote_ip))
  end

  defp client_user_agent(conn) do
    conn |> get_req_header("user-agent") |> List.first() || ""
  end


  defp passkey_registration_options_json(user, challenge, passkeys, config) do
    %{
      challenge: Base.url_encode64(challenge.bytes, padding: false),
      rp: %{id: challenge.rp_id, name: Keyword.get(config.passkeys, :rp_name, "Sigra")},
      user: %{
        id: Base.url_encode64(to_string(user.id), padding: false),
        name: user.email,
        displayName: user.email
      },
      pubKeyCredParams: [%{type: "public-key", alg: -7}, %{type: "public-key", alg: -257}],
      timeout: Keyword.get(config.passkeys, :timeout_ms, 60_000),
      attestation: to_string(Keyword.get(config.passkeys, :attestation, :none)),
      authenticatorSelection: %{
        userVerification: to_string(Keyword.get(config.passkeys, :user_verification, :preferred))
      },
      excludeCredentials: passkey_credentials_json(passkeys)
    }
  end

  defp passkey_authentication_options_json(_user, challenge, passkeys, config) do
    %{
      challenge: Base.url_encode64(challenge.bytes, padding: false),
      rpId: challenge.rp_id,
      timeout: Keyword.get(config.passkeys, :timeout_ms, 60_000),
      userVerification: to_string(Keyword.get(config.passkeys, :user_verification, :preferred)),
      allowCredentials: passkey_credentials_json(passkeys)
    }
  end

  defp conditional_passkey_authentication_options_json(challenge, config) do
    %{
      challenge: Base.url_encode64(challenge.bytes, padding: false),
      rpId: challenge.rp_id,
      timeout: Keyword.get(config.passkeys, :timeout_ms, 60_000),
      userVerification: to_string(Keyword.get(config.passkeys, :user_verification, :preferred)),
      allowCredentials: [],
      useBrowserAutofill: true
    }
  end

  defp passkey_credentials_json(passkeys) do
    Enum.map(passkeys, fn passkey ->
      %{
        type: "public-key",
        id: Base.url_encode64(passkey.credential_id, padding: false),
        transports: passkey.transports || []
      }
    end)
  end

  # Hooks submit WebAuthn results in passkey[response] as a JSON string.
  defp decode_passkey_response(%{"response" => json}), do: decode_passkey_response(json)
  defp decode_passkey_response(json) when is_binary(json), do: JSON.decode(json)
  defp decode_passkey_response(_params), do: {:error, :invalid_passkey_response}

  defp passkey_registration_details(conn) do
    %{
      device: conn |> get_req_header("user-agent") |> List.first() || "Unknown device",
      ip: conn.remote_ip && to_string(:inet.ntoa(conn.remote_ip)),
      city: "Unknown",
      time: DateTime.utc_now()
    }
  end

  defp passkey_login_failed(conn, email) do
    conn
    |> put_flash(:error, "We couldn't finish passkey sign-in. Try again or use another way to continue.")
    |> maybe_put_passkey_email(email)
    |> redirect(to: ~p"/users/log_in")
  end

  defp maybe_put_passkey_email(conn, email) when is_binary(email) do
    put_flash(conn, :email, String.slice(to_string(email), 0, 160))
  end

  defp maybe_put_passkey_email(conn, _email), do: conn

end
