defmodule SigraInstallGoldenTmp.Accounts do
  @moduledoc """
  The authentication context.

  This module provides the primary API for user authentication,
  registration, and account management. All security-critical operations
  delegate to Sigra library functions.
  """

  import Ecto.Query, warn: false
  alias SigraInstallGoldenTmp.Repo, as: Repo
  alias SigraInstallGoldenTmp.Accounts.User
  alias SigraInstallGoldenTmp.Accounts.UserToken
  alias SigraInstallGoldenTmp.Accounts.WebhookDelivery
  alias SigraInstallGoldenTmp.Accounts.WebhookDeliveryAttempt
  alias SigraInstallGoldenTmp.Accounts.WebhookEvent
  alias SigraInstallGoldenTmp.Accounts.WebhookSubscription

  alias SigraInstallGoldenTmp.Accounts.Emails

  alias Sigra.Auth, as: SigraAuth


  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    case SigraAuth.authenticate(Repo, %{"email" => email, "password" => password}, user_schema: User) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs, opts \\ []) do
    changeset_fn = fn a -> User.registration_changeset(%User{}, a) end
    confirmation_url_fun = Keyword.get(opts, :confirmation_url_fun)

    case SigraAuth.register(Repo, attrs, changeset_fn: changeset_fn) do
      {:ok, user} ->
        # CONF-01: Auto-send confirmation email on registration
        if confirmation_url_fun do
          deliver_user_confirmation_instructions(user, confirmation_url_fun)
        end

        {:ok, user}

      {:error, :email_taken} -> {:error, :email_taken}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user_registration(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Magic link

  @doc """
  Requests a magic link for the given email.

  Returns `{:ok, {raw_token, url}}` for existing users, `{:ok, :sent}`
  for non-existent emails (enumeration-safe), or `{:error, :rate_limited}`.
  """
  def request_magic_link(email, url_fun) when is_binary(email) and is_function(url_fun, 1) do
    SigraAuth.request_magic_link(Repo, email,
      user_schema: User,
      user_token_schema: UserToken,
      url_fun: url_fun
    )
  end

  @doc """
  Verifies a magic link token.

  Returns `{:ok, user}` if valid (token is consumed), or `{:error, reason}`.
  Also confirms unconfirmed users.
  """
  def verify_magic_link(token) when is_binary(token) do
    SigraAuth.verify_magic_link(Repo, token,
      user_schema: User,
      user_token_schema: UserToken,
      magic_link_ttl: 600
    )
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(%User{} = user, attrs \\ %{}) do
    User.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_email_token_query(token, context),
         %User{} = user_from_token <- Repo.one(query),
         true <- user.id == user_from_token.id || :token_user_mismatch do
      user_changeset = user |> User.email_changeset(%{email: user_from_token.email}) |> User.confirm_changeset()
      Ecto.Multi.new()
      |> Ecto.Multi.update(:user, user_changeset)
      |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, [context]))
      |> Repo.transaction()
      |> case do
        {:ok, %{user: user}} -> {:ok, user}
        {:error, :user, changeset, _} -> {:error, changeset}
      end
    else
      _ -> :error
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(%User{} = user, attrs \\ %{}) do
    User.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %User{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(%User{} = user, password, attrs) do
    changeset =
      user
      |> User.password_changeset(attrs)
      |> User.validate_current_password(password)

    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, changeset)
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session

  @doc """
  Generates a session token by writing a row to Sigra's canonical
  `user_sessions` store via `Sigra.Auth.create_session/4`.

  Returns the raw (Base64url-encoded) token to put in the session cookie.
  The SHA-256 hash of the decoded raw bytes is what's persisted — never
  the raw token itself.

  ## Options

    * `:ip` - client IP address captured at login (string)
    * `:user_agent` - client user agent header at login (string)
    * `:type` - session type atom (default `:standard`)
  """
  def generate_user_session_token(%User{} = user, opts \\ []) do
    metadata = %{
      type: Keyword.get(opts, :type, :standard),
      ip: Keyword.get(opts, :ip),
      user_agent: Keyword.get(opts, :user_agent)
    }

    case Sigra.Auth.create_session(sigra_config(), user, metadata, []) do
      {:ok, session} ->
        session.token

      {:error, reason} ->
        raise "Sigra.Auth.create_session failed: #{inspect(reason)}"
    end
  end

  @doc """
  Gets the user for the given raw session token by looking up the
  hashed token in Sigra's canonical `user_sessions` store.
  """
  def get_user_by_session_token(raw_token) when is_binary(raw_token) do
    case get_user_and_session_by_token(raw_token) do
      {user, _session} -> user
      nil -> nil
    end
  end

  def get_user_by_session_token(_), do: nil

  @doc """
  Looks up both the user and the session record by raw session cookie
  token. Returns `{user, session}` on success or `nil` on failure. Used
  by code paths that need the session record itself — e.g. the sudo
  controller needs `session.hashed_token` to mark sudo confirmation.
  """
  def get_user_and_session_by_token(raw_token) when is_binary(raw_token) do
    with {:ok, raw_bytes} <- Base.url_decode64(raw_token, padding: false) do
      hashed = Sigra.Token.hash_token(raw_bytes)
      config = sigra_config()
      session_config = config.session
      store = Keyword.fetch!(session_config, :store)

      store_opts = [
        repo: config.repo,
        session_schema: Keyword.fetch!(session_config, :session_schema)
      ]

      case store.fetch(hashed, store_opts) do
        {:ok, session} ->
          case Repo.get(User, session.user_id) do
            nil -> nil
            user -> {user, session}
          end

        {:error, :not_found} ->
          nil
      end
    else
      _ -> nil
    end
  end

  def get_user_and_session_by_token(_), do: nil

  @doc """
  Deletes the session identified by the given raw token from
  Sigra's canonical `user_sessions` store. Idempotent — missing
  tokens are no-ops.
  """
  def delete_user_session_token(raw_token) when is_binary(raw_token) do
    case Base.url_decode64(raw_token, padding: false) do
      {:ok, raw_bytes} ->
        hashed = Sigra.Token.hash_token(raw_bytes)
        Sigra.Auth.delete_session(sigra_config(), hashed, [])
        :ok

      :error ->
        :ok
    end
  end

  def delete_user_session_token(_), do: :ok

  ## Confirmation

  @doc """
  Delivers the confirmation email to the given user.

  Generates both a link token (HMAC-signed) and a 6-digit code.
  Delivers via Oban (async) or inline (sync) based on config.

  Returns `{:ok, :sent}` on success, `{:error, :already_confirmed}` if
  already confirmed.
  """
  def deliver_user_confirmation_instructions(%User{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {signed_token, code, link_token, code_token} =
        Sigra.Auth.generate_confirmation_token(Repo, user,
          secret_key_base: SigraInstallGoldenTmpWeb.Endpoint.config(:secret_key_base),
          user_token_schema: UserToken
        )

      Repo.insert!(link_token)
      Repo.insert!(code_token)

      url = confirmation_url_fun.(signed_token)
      email = SigraInstallGoldenTmp.Accounts.Emails.confirmation_email(user, url, code)

      Sigra.Delivery.deliver(:confirmation, %{
        user_id: user.id,
        to: user.email,
        subject: email.subject,
        body: %{html: email.html_body, text: email.text_body},
        token: signed_token,
        code: code,
        url: url
      }, delivery_opts())

      {:ok, :sent}
    end
  end

  @doc """
  Confirms a user by HMAC-signed link token.

  Verifies the HMAC signature, looks up the token in the database,
  sets `confirmed_at`, and deletes all confirm/confirm_code tokens.
  """
  def confirm_user(signed_token) when is_binary(signed_token) do
    Sigra.Auth.confirm_user(Repo, signed_token,
      user_schema: User,
      user_token_schema: UserToken,
      secret_key_base: SigraInstallGoldenTmpWeb.Endpoint.config(:secret_key_base),
      confirmation_ttl: 48 * 60 * 60
    )
  end

  @doc """
  Confirms a user by 6-digit code entry.

  Rate-limited to 5 attempts per user per 15 minutes.
  """
  def confirm_user_by_code(%User{} = user, code) when is_binary(code) do
    # 10.1 IN-05: verify_confirmation_code/3 does NOT read :secret_key_base
    # (codes are hashed and looked up directly, no signed token round-trip).
    # Do not add it back unless the library signature changes.
    Sigra.Auth.verify_confirmation_code(Repo, code,
      user_id: user.id,
      user_schema: User,
      user_token_schema: UserToken
    )
  end

  ## Reset password

  @doc """
  Delivers the reset password email to the given email address.

  Enumeration-safe: always returns `{:ok, :sent}` regardless of whether
  the email exists. A dummy hash operation matches timing for non-existent
  emails.
  """
  def deliver_user_reset_password_instructions(email, reset_password_url_fun)
      when is_binary(email) and is_function(reset_password_url_fun, 1) do
    case Sigra.Auth.request_password_reset(Repo, email,
      user_schema: User,
      user_token_schema: UserToken,
      secret_key_base: SigraInstallGoldenTmpWeb.Endpoint.config(:secret_key_base),
      url_fun: reset_password_url_fun
    ) do
      {:ok, {signed_token, url}} ->
        user = get_user_by_email(email)

        if user do
          email_struct = SigraInstallGoldenTmp.Accounts.Emails.reset_password_email(user, url)

          Sigra.Delivery.deliver(:reset_password, %{
            user_id: user.id,
            to: user.email,
            subject: email_struct.subject,
            body: %{html: email_struct.html_body, text: email_struct.text_body},
            token: signed_token,
            url: url
          }, delivery_opts())
        end

        {:ok, :sent}

      {:ok, :sent} ->
        # Non-existent email -- enumeration safe
        {:ok, :sent}

      {:error, :rate_limited} ->
        {:error, :rate_limited}
    end
  end

  @doc """
  Gets the user by reset password token.

  Verifies the HMAC signature and looks up the token in the database.

  ## Examples

      iex> get_user_by_reset_password_token("validtoken")
      %User{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(signed_token) do
    secret_key_base = SigraInstallGoldenTmpWeb.Endpoint.config(:secret_key_base)

    with {:ok, signed} <- Base.url_decode64(signed_token, padding: false),
         {:ok, raw_token} <- Plug.Crypto.verify(secret_key_base, "sigra-reset-token", signed, max_age: 3600) do
      hashed_token = Sigra.Token.hash_token(raw_token)

      Repo.one(
        from t in UserToken,
          join: u in assoc(t, :user),
          where: t.token == ^hashed_token,
          where: t.context == "reset_password",
          select: u
      )
    else
      _ -> nil
    end
  end

  @doc """
  Resets the user password.

  Uses `Sigra.Auth.reset_password/4` which verifies the HMAC-signed token,
  updates the password, and invalidates all tokens (including sessions)
  in a single transaction. Per D-29: caller creates new session after reset.

  ## Examples

      iex> reset_user_password(signed_token, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %User{}}

  """
  def reset_user_password(signed_token, attrs) when is_binary(signed_token) do
    Sigra.Auth.reset_password(Repo, signed_token, attrs,
      secret_key_base: SigraInstallGoldenTmpWeb.Endpoint.config(:secret_key_base),
      user_token_schema: UserToken,
      user_schema: User,
      changeset_fn: &User.password_changeset/2,
      reset_ttl: 3600
    )
  end

  # Legacy API accepting a user struct. Test-only helper — bypasses the
  # HMAC signature rewind, audit log row, and telemetry events that the
  # signed-token clause above emits via `Sigra.Auth.reset_password/4`. Do
  # NOT call this from controllers; production flows must use the signed
  # token clause so security signals are preserved (10.1 IN-03). Tokens
  # are invalidated in a single transaction so the caller can create a
  # fresh session after reset (D-29).
  @doc false
  def reset_user_password(%User{} = user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, User.password_changeset(user, attrs))
    |> Ecto.Multi.delete_all(:tokens, UserToken.by_user_and_contexts_query(user, :all))
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user}} -> {:ok, user}
      {:error, :user, changeset, _} -> {:error, changeset}
    end
  end

  ## Session management

  @doc """
  Returns the Sigra config struct for this application.

  Used by generated controllers and plugs that need to pass
  configuration to Sigra library functions.
  """
  def sigra_config do
    Sigra.Config.new!(
      repo: SigraInstallGoldenTmp.Repo,
      user_schema: User,
      session: [
        store: Sigra.SessionStores.Ecto,
        session_schema: SigraInstallGoldenTmp.Accounts.UserSession
      ],
      lockout: [
        threshold: 5,
        duration: 900
      ],


      # Activate Sigra's built-in audit integration. Without this wiring,
      # Sigra.Audit.log_safe/2 is a silent no-op and no audit rows are
      # written for session.create, auth.login.*, etc.
      audit: [
        audit_schema: SigraInstallGoldenTmp.Accounts.AuditEvent
      ],
      webhooks: [
        enabled: false,
        webhook_subscription_schema: WebhookSubscription,
        webhook_event_schema: WebhookEvent,
        webhook_delivery_schema: WebhookDelivery,
        webhook_delivery_attempt_schema: WebhookDeliveryAttempt,
        oban_queue: "sigra_webhooks",
        oban_concurrency: 10,
        signature_tolerance: 300
      ]
    )
  end

  @doc "List all active sessions for a user."
  def list_sessions(user) do
    Sigra.Auth.list_sessions(sigra_config(), user.id)
  end

  @doc "Revoke a specific session by its hashed token."
  def revoke_session(hashed_token) do
    Sigra.Auth.revoke_session(sigra_config(), hashed_token)
  end

  @doc "Revoke all sessions for a user. Broadcasts PubSub disconnect."
  def revoke_all_sessions(user, opts \\ []) do
    Sigra.Auth.delete_all_sessions(sigra_config(), user.id, Keyword.put(opts, :pubsub, SigraInstallGoldenTmpWeb.PubSub))
  end

  @doc "Confirm sudo mode for a session."
  def confirm_sudo(hashed_token) do
    Sigra.Auth.confirm_sudo(sigra_config(), hashed_token)
  end

  @doc "List the explicit webhook event catalog."
  def webhook_event_types do
    Sigra.Webhooks.public_event_types()
  end

  @doc "List configured webhook subscriptions."
  def list_webhook_subscriptions do
    Sigra.Webhooks.list_subscriptions(sigra_config())
  end

  @doc "Create a webhook subscription."
  def create_webhook_subscription(attrs) do
    Sigra.Webhooks.create_subscription(sigra_config(), attrs)
  end

  @doc "Update a webhook subscription."
  def update_webhook_subscription(subscription, attrs) do
    Sigra.Webhooks.update_subscription(sigra_config(), subscription, attrs)
  end

  @doc "Enable a webhook subscription."
  def enable_webhook_subscription(subscription) do
    Sigra.Webhooks.enable_subscription(sigra_config(), subscription)
  end

  @doc "Disable a webhook subscription."
  def disable_webhook_subscription(subscription) do
    Sigra.Webhooks.disable_subscription(sigra_config(), subscription)
  end

  @doc "Check if user is locked out."
  def locked?(user) do
    Sigra.Lockout.locked?(user, lockout_opts())
  end

  @doc "Get lock status for a user."
  def lock_status(user) do
    Sigra.Lockout.lock_status(user, lockout_opts())
  end

  defp lockout_opts do
    config = sigra_config()
    [
      threshold: Keyword.get(config.lockout, :threshold, 5),
      duration: Keyword.get(config.lockout, :duration, 900)
    ]
  end

  ## MFA

  alias SigraInstallGoldenTmp.Accounts.UserMFACredential
  alias SigraInstallGoldenTmp.Accounts.UserBackupCode

  alias SigraInstallGoldenTmp.Accounts.UserPasskey


  @doc "Begin MFA enrollment. Returns secret, otpauth URI, and QR code SVG."
  def mfa_enroll(opts \\ []) do
    Sigra.MFA.enroll(sigra_config(), opts)
  end

  @doc "Confirm MFA enrollment with a TOTP code. Creates credential and backup codes."
  def mfa_confirm_enrollment(user, raw_secret, code, opts \\ []) do
    Sigra.MFA.confirm_enrollment(sigra_config(), user, raw_secret, code,
      Keyword.merge([
        mfa_credential_schema: UserMFACredential,
        backup_code_schema: UserBackupCode
      ], opts))
  end

  @doc "Verify a TOTP code for MFA challenge."
  def mfa_verify(user, code, opts \\ []) do
    Sigra.MFA.verify(sigra_config(), user, code,
      Keyword.merge([mfa_credential_schema: UserMFACredential], opts))
  end

  @doc "Verify a backup code for MFA challenge."
  def mfa_verify_backup(user, code, opts \\ []) do
    Sigra.MFA.verify_backup(sigra_config(), user, code,
      Keyword.merge([
        mfa_credential_schema: UserMFACredential,
        backup_code_schema: UserBackupCode
      ], opts))
  end

  @doc "Disable MFA for a user. Requires valid TOTP or backup code."
  def mfa_disable(user, code, opts \\ []) do
    Sigra.MFA.disable(sigra_config(), user, code,
      Keyword.merge([
        mfa_credential_schema: UserMFACredential,
        backup_code_schema: UserBackupCode
      ], opts))
  end

  @doc """
  Regenerates backup codes after verifying a TOTP code.

  Requires `{:totp, code}` — backup codes **cannot** authorize rotation.
  """
  def mfa_regenerate_backup_codes(user, {:totp, _} = verification, opts \\ []) do
    Sigra.MFA.regenerate_backup_codes(sigra_config(), user, verification,
      Keyword.merge([
        mfa_credential_schema: UserMFACredential,
        backup_code_schema: UserBackupCode
      ], opts))
  end

  @doc "Check if a user has MFA enabled."
  def mfa_enabled?(user) do
    config =
      Map.update(sigra_config(), :mfa, [mfa_credential_schema: UserMFACredential], fn mfa ->
        Keyword.put(mfa || [], :mfa_credential_schema, UserMFACredential)
      end)

    Sigra.MFA.enabled?(config, user)
  end

  @doc "Upgrade an MFA-pending Sigra session after second-factor verification."
  def complete_mfa_verification(user, old_session, opts \\ []) do
    Sigra.Auth.complete_mfa_verification(sigra_config(), user, old_session, opts)
  end

  @doc "Get MFA status for a user (enrollment state, backup code count, etc.)."
  def mfa_status(user) do
    Sigra.MFA.status(sigra_config(), user,
      mfa_credential_schema: SigraInstallGoldenTmp.Accounts.UserMFACredential,
      backup_code_schema: SigraInstallGoldenTmp.Accounts.UserBackupCode
    )
  end


  ## Passkeys

  @doc "List passkeys for a user."
  def passkeys_for_user(user) do
    Sigra.Passkeys.list_for_user(sigra_config(), user, user_passkey_schema: UserPasskey)
  end

  @doc "Count passkeys for a user."
  def passkey_count_for_user(user) do
    Sigra.Passkeys.count_for_user(sigra_config(), user, user_passkey_schema: UserPasskey)
  end

  @doc "Return the user-facing label for a passkey."
  def passkey_label(passkey) do
    Sigra.Passkeys.DeviceName.label(passkey)
  end

  @doc "Register a new passkey for a user."
  def register_passkey(user, attestation_params, details \\ %{}) do
    with :ok <- Sigra.Passkeys.rate_limit_ceremony(Sigra.Passkeys.config(), user.id, :registration),
         {:ok, normalized_params} <- normalize_passkey_registration_params(attestation_params, Map.get(attestation_params, "challenge") || Map.get(attestation_params, :challenge)) do
      case Sigra.Passkeys.register(sigra_config(), user, normalized_params, user_passkey_schema: UserPasskey) do
        {:ok, credential} ->
          deliver_passkey_registration_notification(user, Map.merge(details, %{passkey: credential}))
          {:ok, credential}

        {:error, %Ecto.Changeset{} = changeset} ->
          if duplicate_passkey_changeset?(changeset) do
            {:error, :duplicate_passkey}
          else
            {:error, changeset}
          end

        {:error, reason} ->
          {:error, reason}
      end
    else
      {:error, :rate_limited, _meta} -> {:error, :rate_limited}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Authenticate a passkey for a known user."
  def authenticate_passkey(user, assertion_params) do
    with :ok <- Sigra.Passkeys.rate_limit_ceremony(Sigra.Passkeys.config(), user.id, :authentication),
         {:ok, normalized_params} <- normalize_passkey_assertion_params(assertion_params, Map.get(assertion_params, "challenge") || Map.get(assertion_params, :challenge)) do
      Sigra.Passkeys.authenticate(sigra_config(), user, normalized_params, user_passkey_schema: UserPasskey)
    else
      {:error, :rate_limited, _meta} -> {:error, :invalid_passkey}
      {:error, _reason} -> {:error, :invalid_passkey}
    end
  end

  @doc "Authenticate a discoverable passkey without a typed email address."
  def authenticate_discoverable_passkey(assertion_params) do
    with {:ok, normalized_params} <- normalize_passkey_assertion_params(assertion_params, Map.get(assertion_params, "challenge") || Map.get(assertion_params, :challenge)),
         credential_id when is_binary(credential_id) <- Map.get(normalized_params, :credential_id),
         %UserPasskey{} = passkey <- Repo.get_by(UserPasskey, credential_id: credential_id),
         %User{} = user <- Repo.get(User, passkey.user_id),
         :ok <- verify_discoverable_user_handle(normalized_params, passkey),
         :ok <- Sigra.Passkeys.rate_limit_ceremony(Sigra.Passkeys.config(), user.id, :authentication),
         {:ok, credential} <- Sigra.Passkeys.authenticate(sigra_config(), user, normalized_params, user_passkey_schema: UserPasskey) do
      {:ok, user, credential}
    else
      _ -> {:error, :invalid_passkey}
    end
  end

  @doc "Rename a passkey."
  def rename_passkey(user, credential_id, nickname) do
    Sigra.Passkeys.rename(sigra_config(), user, credential_id, nickname || "", user_passkey_schema: UserPasskey)
  end

  @doc "Delete a passkey."
  def delete_passkey(user, credential_id) do
    Sigra.Passkeys.delete(sigra_config(), user, credential_id, user_passkey_schema: UserPasskey)
  end

  @doc "Returns true when passkey-primary login is enabled."
  def passkey_primary_enabled?() do
    case Application.fetch_env(:sigra_install_golden_tmp, :passkey_primary_enabled) do
      {:ok, bool} when is_boolean(bool) ->
        bool

      _ ->
        Keyword.get(sigra_config().passkeys, :passkey_primary_enabled, false)
    end
  end

  @doc "Returns true when a user may use passkey-primary login."
  def passkey_primary_user_eligible?(%User{} = user) do
    passkey_primary_enabled?() and user.confirmed_at != nil
  end

  def passkey_primary_user_eligible?(_user), do: false

  @doc "Checks whether a discovered user may use passkey-primary login."
  def ensure_passkey_primary_user_eligible(%User{} = user) do
    cond do
      not passkey_primary_enabled?() ->
        {:error, :passkey_primary_disabled}

      not passkey_primary_user_eligible?(user) ->
        {:error, :email_not_confirmed}

      true ->
        :ok
    end
  end

  def ensure_passkey_primary_user_eligible(_user), do: {:error, :invalid_user}


  @doc "Returns whether magic-link recovery is available for login."
  def magic_link_recovery_available?() do

    # PK-UX-07 makes magic-link recovery mandatory for passkey-primary accounts.
    if passkey_primary_enabled?() do
      true
    else
      sigra_config()
      |> Map.get(:magic_link, [])
      |> Keyword.get(:enabled, true)
    end

  end


  @doc "Delivers a passkey registration notification email."
  def deliver_passkey_registration_notification(user, details) do
    email = Emails.passkey_registration_email(user, details)

    Sigra.Delivery.deliver(:passkey_registration, %{
      user_id: user.id,
      to: user.email,
      subject: email.subject,
      body: %{html: email.html_body, text: email.text_body},
      details: details
    }, delivery_opts())
  end

  defp normalize_passkey_registration_params(params, challenge) when is_map(params) do
    response = Map.get(params, "response") || Map.get(params, :response) || %{}

    with {:ok, credential_id} <- decode_base64url(Map.get(params, "rawId") || Map.get(params, :rawId) || Map.get(params, "id") || Map.get(params, :id)),
         {:ok, attestation_object} <- decode_base64url(Map.get(response, "attestationObject") || Map.get(response, :attestationObject)),
         {:ok, client_data_json} <- decode_base64url(Map.get(response, "clientDataJSON") || Map.get(response, :clientDataJSON)),
         {:ok, challenge_bytes} <- normalize_challenge(challenge) do
      {:ok,
       %{
         credential_id: credential_id,
         attestation_object: attestation_object,
         client_data_json: client_data_json,
         challenge: challenge_bytes,
         nickname: blank_to_nil(Map.get(params, "nickname") || Map.get(params, :nickname)),
         device_hint: blank_to_nil(Map.get(params, "device_hint") || Map.get(params, :device_hint) || Map.get(params, "deviceHint") || Map.get(params, :deviceHint)),
         transports: Map.get(response, "transports") || Map.get(response, :transports) || []
       }}
    else
      _ -> {:error, :invalid_passkey}
    end
  end

  defp normalize_passkey_registration_params(_params, _challenge), do: {:error, :invalid_passkey}

  defp normalize_passkey_assertion_params(params, challenge) when is_map(params) do
    response = Map.get(params, "response") || Map.get(params, :response) || %{}

    with {:ok, credential_id} <- decode_base64url(Map.get(params, "rawId") || Map.get(params, :rawId) || Map.get(params, "id") || Map.get(params, :id)),
         {:ok, authenticator_data} <- decode_base64url(Map.get(response, "authenticatorData") || Map.get(response, :authenticatorData)),
         {:ok, signature} <- decode_base64url(Map.get(response, "signature") || Map.get(response, :signature)),
         {:ok, client_data_json} <- decode_base64url(Map.get(response, "clientDataJSON") || Map.get(response, :clientDataJSON)),
         {:ok, user_handle} <- decode_optional_base64url(Map.get(response, "userHandle") || Map.get(response, :userHandle)),
         {:ok, challenge_bytes} <- normalize_challenge(challenge) do
      {:ok,
       %{
         credential_id: credential_id,
         authenticator_data: authenticator_data,
         signature: signature,
         client_data_json: client_data_json,
         challenge: challenge_bytes,
         user_handle: user_handle
       }}
    else
      _ -> {:error, :invalid_passkey}
    end
  end

  defp normalize_passkey_assertion_params(_params, _challenge), do: {:error, :invalid_passkey}

  defp decode_base64url(value) when is_binary(value), do: Base.url_decode64(value, padding: false)
  defp decode_base64url(_value), do: {:error, :invalid_passkey}

  defp decode_optional_base64url(nil), do: {:ok, nil}
  defp decode_optional_base64url(""), do: {:ok, nil}
  defp decode_optional_base64url(value), do: decode_base64url(value)

  defp normalize_challenge(%Wax.Challenge{bytes: bytes}) when is_binary(bytes), do: {:ok, bytes}
  defp normalize_challenge(bytes) when is_binary(bytes), do: {:ok, bytes}
  defp normalize_challenge(_challenge), do: {:error, :invalid_passkey}

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_value), do: nil

  defp duplicate_passkey_changeset?(%Ecto.Changeset{} = changeset) do
    Enum.any?(changeset.errors, fn
      {:credential_id, {_message, opts}} -> Keyword.get(opts, :constraint) == :unique or Keyword.has_key?(opts, :constraint_name)
      _ -> false
    end)
  end

  defp verify_discoverable_user_handle(%{user_handle: nil}, _passkey), do: :ok
  defp verify_discoverable_user_handle(%{user_handle: user_handle}, passkey) do
    if user_handle == to_string(passkey.user_id), do: :ok, else: {:error, :invalid_passkey}
  end


  ## Account Lifecycle

  @doc """
  Request an email change. Sends confirmation to the new address and
  notification to the old address.

  Returns `{:ok, user, encoded_token}` or `{:error, changeset}`.
  """
  def request_email_change(user, new_email) do
    Sigra.Auth.request_email_change(sigra_config(), user, new_email,
      changeset_fn: &User.pending_email_changeset/2,
      user_token_schema: UserToken
    )
  end

  @doc """
  Confirm an email change via the token from the confirmation email.

  Returns `{:ok, user}` or `:error`.
  """
  def confirm_email_change(encoded_token, opts \\ []) do
    Sigra.Auth.confirm_email_change(sigra_config(), encoded_token,
      Keyword.merge([
        user_token_schema: UserToken,
        user_schema: User,
        session_store: Sigra.SessionStores.Ecto
      ], opts)
    )
  end

  @doc """
  Cancel a pending email change.

  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  def cancel_email_change(user) do
    Sigra.Auth.cancel_email_change(sigra_config(), user,
      changeset_fn: &User.pending_email_changeset/2,
      user_token_schema: UserToken
    )
  end

  @doc """
  Change the user's password, verifying the current password.

  All other sessions are invalidated on success.
  Returns `{:ok, user}` or `{:error, changeset}`.
  """
  def change_password(user, current_password, attrs) do
    Sigra.Auth.change_password(sigra_config(), user, current_password, attrs,
      changeset_fn: &User.password_changeset/3
    )
  end

  @doc """
  Set a password for an OAuth-only user who doesn't have one yet.

  Requires sudo mode. Returns `{:ok, user}` or `{:error, changeset}`.
  """
  def set_password(user, attrs) do
    Sigra.Auth.set_password(sigra_config(), user, attrs,
      changeset_fn: &User.password_changeset/3
    )
  end

  @doc """
  Schedule account deletion with configured grace period.

  Returns `{:ok, user, scheduled_date}` or `{:error, reason}`.
  """
  def schedule_deletion(user) do
    Sigra.Auth.schedule_deletion(sigra_config(), user,
      user_token_schema: UserToken,
      session_store: Sigra.SessionStores.Ecto
    )
  end

  @doc """
  Cancel a scheduled account deletion.

  Returns `{:ok, user}` or `{:error, reason}`.
  """
  def cancel_deletion(user, opts \\ []) do
    Sigra.Auth.cancel_deletion(sigra_config(), user,
      Keyword.merge([changeset_fn: &User.deletion_changeset/2], opts)
    )
  end

  @doc """
  Check if the user's account is scheduled for deletion.
  """
  def deletion_scheduled?(user) do
    Sigra.Account.deletion_scheduled?(user)
  end

  @doc """
  Get deletion status: `{:scheduled, days_remaining}` | `:not_scheduled` | `:deleted`.
  """
  def deletion_status(user) do
    Sigra.Account.deletion_status(user)
  end

  @doc """
  Check if the user must change their password.
  """
  def must_change_password?(user) do
    Sigra.Account.must_change_password?(user)
  end

  # -- Private helpers --

  defp delivery_opts do
    [
      mailer: SigraInstallGoldenTmp.Accounts.Mailer,
      delivery_mode: :auto,
      oban_queue: "sigra_mailer"
    ]
  end
end
