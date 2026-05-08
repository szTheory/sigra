defmodule Example.Accounts do
  @moduledoc """
  The authentication context.

  This module provides the primary API for user authentication,
  registration, and account management. All security-critical operations
  delegate to Sigra library functions.
  """

  import Ecto.Query, warn: false
  alias Example.Repo, as: Repo
  alias Example.Accounts.User
  alias Example.Accounts.UserIdentity
  alias Example.Accounts.UserToken
  alias Example.Accounts.WebhookDelivery
  alias Example.Accounts.WebhookDeliveryAttempt
  alias Example.Accounts.WebhookEvent
  alias Example.Accounts.WebhookReceipt
  alias Example.Accounts.WebhookSubscription
  alias Example.Accounts.Emails
  alias Example.Accounts.Emails.{ProviderLinked, ProviderUnlinked}
  alias Sigra.Auth, as: SigraAuth
  require Sigra.Application

  Sigra.Application.warn_for_enabled_optional_deps!(
    jwt: [enabled: true],
    dependency_loaded?: fn spec ->
      case Application.compile_env(:sigra, :compile_dependency_loaded_override, nil) do
        fun when is_function(fun, 1) -> fun.(spec)
        _ -> Enum.any?(spec.dependency_modules, &Code.ensure_loaded?/1)
      end
    end
  )

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
    # Pass full Sigra.Config so lockout + audit (`auth.login.*`) run on the
    # same paths as HTTP authentication (repo-only overload skips audit).
    case SigraAuth.authenticate(sigra_config(), %{"email" => email, "password" => password}) do
      {:ok, user} -> user
      {:ok, user, _session_meta} -> user
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

  def admin_user_hooks, do: Example.SigraAdminUsers

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

    case SigraAuth.register(sigra_config(), attrs, changeset_fn: changeset_fn) do
      {:ok, user} ->
        # CONF-01: Auto-send confirmation email on registration
        if confirmation_url_fun do
          deliver_user_confirmation_instructions(user, confirmation_url_fun)
        end

        {:ok, user}

      {:error, :email_taken} ->
        {:error, :email_taken}

      {:error, changeset} ->
        {:error, changeset}
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
      user_changeset =
        user |> User.email_changeset(%{email: user_from_token.email}) |> User.confirm_changeset()

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
  def update_user_password(%User{} = user, password, attrs, opts \\ []) do
    with :ok <- forbid_sensitive_operation(opts, user, "account.password_change") do
      do_update_user_password(user, password, attrs)
    end
  end

  defp do_update_user_password(%User{} = user, password, attrs) do
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
      {signed_token, code} = insert_confirmation_tokens!(user)

      url = confirmation_url_fun.(signed_token)
      email = Example.Accounts.Emails.confirmation_email(user, url, code)

      Sigra.Delivery.deliver(
        :confirmation,
        %{
          user_id: user.id,
          to: user.email,
          subject: email.subject,
          body: %{html: email.html_body, text: email.text_body},
          token: signed_token,
          code: code,
          url: url
        },
        delivery_opts()
      )

      {:ok, :sent}
    end
  end

  defp insert_confirmation_tokens!(user, attempts \\ 5)

  defp insert_confirmation_tokens!(_user, 0) do
    raise "unable to generate unique confirmation tokens after multiple attempts"
  end

  defp insert_confirmation_tokens!(user, attempts) do
    {signed_token, code, link_token, code_token} =
      Sigra.Auth.generate_confirmation_token(Repo, user,
        secret_key_base: ExampleWeb.Endpoint.config(:secret_key_base),
        user_token_schema: UserToken
      )

    Repo.transaction(fn ->
      Repo.insert!(link_token)
      Repo.insert!(code_token)
    end)

    {signed_token, code}
  rescue
    error in Ecto.ConstraintError ->
      if error.constraint == "user_tokens_context_token_index" do
        insert_confirmation_tokens!(user, attempts - 1)
      else
        reraise error, __STACKTRACE__
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
      secret_key_base: ExampleWeb.Endpoint.config(:secret_key_base),
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
           secret_key_base: ExampleWeb.Endpoint.config(:secret_key_base),
           url_fun: reset_password_url_fun
         ) do
      {:ok, {signed_token, url}} ->
        user = get_user_by_email(email)

        if user do
          email_struct = Example.Accounts.Emails.reset_password_email(user, url)

          Sigra.Delivery.deliver(
            :reset_password,
            %{
              user_id: user.id,
              to: user.email,
              subject: email_struct.subject,
              body: %{html: email_struct.html_body, text: email_struct.text_body},
              token: signed_token,
              url: url
            },
            delivery_opts()
          )
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
    secret_key_base = ExampleWeb.Endpoint.config(:secret_key_base)

    with {:ok, signed} <- Base.url_decode64(signed_token, padding: false),
         {:ok, raw_token} <-
           Plug.Crypto.verify(secret_key_base, "sigra-reset-token", signed, max_age: 3600) do
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
      secret_key_base: ExampleWeb.Endpoint.config(:secret_key_base),
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
    app_sigra_config = Application.get_env(:example, :sigra_config, [])

    Sigra.Config.new!(
      repo: Example.Repo,
      user_schema: User,
      secret_key_base: ExampleWeb.Endpoint.config(:secret_key_base),
      scope_module: Example.Accounts.Scope,
      organizations_module: Example.Organizations,
      session:
        Keyword.merge(
          Keyword.get(app_sigra_config, :session, []),
          store: Sigra.SessionStores.Ecto,
          session_schema: Example.Accounts.UserSession
        ),
      jwt: [
        enabled: true,
        algorithm: "HS256",
        access_ttl: 900,
        client_credentials_access_ttl: 3600,
        refresh_ttl: 2_592_000
      ],
      lockout: [
        threshold: 5,
        duration: 900
      ],
      # Activate Sigra's built-in audit integration. Without this wiring,
      # Sigra.Audit.log_safe/2 is a silent no-op and no audit rows are
      # written for session.create, auth.login.*, etc.
      audit:
        Keyword.merge(
          Keyword.get(app_sigra_config, :audit, []),
          audit_schema: Example.Accounts.AuditEvent
        ),
      webhooks:
        Keyword.merge(
          Keyword.get(app_sigra_config, :webhooks, []),
          endpoint_policy: &__MODULE__.webhook_endpoint_policy/1,
          webhook_subscription_schema: WebhookSubscription,
          webhook_event_schema: WebhookEvent,
          webhook_delivery_schema: WebhookDelivery,
          webhook_delivery_attempt_schema: WebhookDeliveryAttempt
        ),
      passkeys:
        Keyword.merge(
          Keyword.get(app_sigra_config, :passkeys, []),
          origin: example_base_url(),
          user_passkey_schema: Example.Accounts.UserPasskey
        ),
      service_accounts: [
        service_account_schema: Example.Accounts.ServiceAccount,
        service_account_credential_schema: Example.Accounts.ServiceAccountCredential,
        client_id_prefix: "sigra_sa_"
      ],
      oauth: oauth_config()
    )
    |> Map.put(:identity_schema, UserIdentity)
  end

  def webhook_endpoint_policy(%{uri: %URI{} = uri}) do
    case webhook_endpoint_policy_config() do
      %{mode: :deny_exact_endpoint, detail: detail} ->
        if deny_endpoint?(uri, webhook_endpoint_policy_config().endpoint_url) do
          {:error, :policy_denied, detail}
        else
          :ok
        end

      _other ->
        :ok
    end
  end

  def webhook_endpoint_policy(_context), do: :ok

  defp oauth_config do
    base_oauth = Application.get_env(:example, :sigra, [])[:oauth] || []
    base_providers = Keyword.get(base_oauth, :providers, [])
    override_providers = Application.get_env(:sigra, :oauth_provider_overrides, [])

    merged_providers =
      Keyword.merge(base_providers, override_providers, fn _provider, base, override ->
        Keyword.merge(base, override)
      end)

    Keyword.put(base_oauth, :providers, merged_providers)
  end

  defp example_base_url do
    System.get_env("SIGRA_EXAMPLE_URL") || ExampleWeb.Endpoint.url()
  end

  def oauth_providers do
    sigra_config()
    |> Sigra.Config.oauth_providers()
  end

  def list_user_identities(%User{} = user) do
    from(i in UserIdentity,
      where: i.user_id == ^user.id,
      order_by: [asc: i.provider, asc: i.inserted_at]
    )
    |> Repo.all()
  end

  def create_identity(attrs) when is_map(attrs) do
    %UserIdentity{}
    |> UserIdentity.changeset(attrs)
    |> Repo.insert()
  end

  def get_user_identity!(id), do: Repo.get!(UserIdentity, id)

  def complete_oauth_link(%User{} = user, intent) when is_map(intent) do
    provider = intent["provider"] || intent[:provider]
    provider_uid = intent["provider_uid"] || intent[:provider_uid]
    email = intent["email"] || intent[:email]

    attrs = %{
      user_id: user.id,
      provider: provider |> to_string() |> String.downcase(),
      provider_uid: provider_uid,
      provider_email: email,
      provider_name: nil,
      provider_avatar_url: nil,
      metadata: %{},
      last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    with {:ok, identity} <- create_identity(attrs),
         {:ok, _metadata} <- deliver_provider_linked_email(user, provider) do
      {:ok, identity}
    end
  end

  def complete_oauth_link(_user, _intent), do: {:error, :invalid_link_intent}

  def unlink_oauth_identity(%User{} = user, identity_id) do
    identity = Repo.get_by!(UserIdentity, id: identity_id, user_id: user.id)

    other_identities? =
      Repo.exists?(from(i in UserIdentity, where: i.user_id == ^user.id and i.id != ^identity.id))

    has_password? = not is_nil(user.hashed_password) and user.hashed_password != ""

    cond do
      not has_password? and not other_identities? ->
        {:error, :last_provider}

      true ->
        Repo.delete!(identity)
        {:ok, _metadata} = deliver_provider_unlinked_email(user, identity.provider)
        {:ok, :unlinked}
    end
  end

  defp deliver_provider_linked_email(user, provider) do
    user
    |> ProviderLinked.build(provider_display_name(provider), settings_url())
    |> Example.Mailer.deliver()
  end

  defp deliver_provider_unlinked_email(user, provider) do
    user
    |> ProviderUnlinked.build(provider_display_name(provider), settings_url())
    |> Example.Mailer.deliver()
  end

  defp provider_display_name(provider) when is_atom(provider),
    do: provider |> to_string() |> provider_display_name()

  defp provider_display_name("google"), do: "Google"
  defp provider_display_name("github"), do: "GitHub"
  defp provider_display_name("apple"), do: "Apple"
  defp provider_display_name("facebook"), do: "Facebook"
  defp provider_display_name(provider), do: provider |> to_string() |> String.capitalize()

  defp raw_body_sha256(raw_body) do
    :sha256
    |> :crypto.hash(raw_body)
    |> Base.encode16(case: :lower)
  end

  defp receipt_duplicate?(%Ecto.Changeset{} = changeset) do
    Enum.any?(changeset.errors, fn
      {:delivery_id, {"has already been taken", _details}} -> true
      _other -> false
    end)
  end

  defp settings_url, do: "#{ExampleWeb.Endpoint.url()}/users/settings"

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
    Sigra.Auth.delete_all_sessions(
      sigra_config(),
      user.id,
      maybe_put_pubsub(opts)
    )
  end

  @doc "Revoke all sibling sessions while preserving the current session."
  def revoke_other_sessions(user, current_hashed_token, opts \\ []) do
    Sigra.Auth.revoke_other_sessions(
      sigra_config(),
      user.id,
      maybe_put_pubsub(opts)
      |> Keyword.put(:current_hashed_token, current_hashed_token)
    )
  end

  @doc "Resolve the persisted hashed token for the current raw session token."
  def current_session_hashed_token(raw_token) when is_binary(raw_token) do
    case get_user_and_session_by_token(raw_token) do
      {_user, session} -> session.hashed_token
      nil -> nil
    end
  end

  def current_session_hashed_token(_raw_token), do: nil

  @doc "List recent persisted security activity for a user."
  def recent_security_activity(user, opts \\ []) do
    Sigra.SecurityActivity.list_recent_activity(sigra_config(), user.id, opts)
  end

  @doc "Log out the current user's session with explicit voluntary-logout audit truth."
  def log_out_user_session_token(raw_token, user, opts \\ [])

  def log_out_user_session_token(raw_token, %User{} = user, opts) when is_binary(raw_token) do
    case get_user_and_session_by_token(raw_token) do
      {%User{id: user_id} = token_user, session} when user_id == user.id ->
        Sigra.Auth.logout(sigra_config(), token_user, session, opts)
        :ok

      _other ->
        delete_user_session_token(raw_token)
    end
  end

  def log_out_user_session_token(raw_token, _user, _opts) when is_binary(raw_token) do
    delete_user_session_token(raw_token)
  end

  def log_out_user_session_token(_raw_token, _user, _opts), do: :ok

  @doc "Confirm sudo mode for a session."
  def confirm_sudo(hashed_token) do
    Sigra.Auth.confirm_sudo(sigra_config(), hashed_token)
  end

  defp maybe_put_pubsub(opts) do
    if Process.whereis(ExampleWeb.PubSub) do
      Keyword.put(opts, :pubsub, ExampleWeb.PubSub)
    else
      opts
    end
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

  @doc "List admin webhook subscriptions with URL-driven params."
  def list_admin_webhook_subscriptions(admin_scope, params \\ %{}) do
    Sigra.Admin.Webhooks.Query.list_subscriptions(sigra_config(), admin_scope, params)
  end

  @doc "Load one admin webhook subscription detail."
  def get_admin_webhook_subscription!(admin_scope, subscription_id) do
    Sigra.Admin.Webhooks.Detail.load_subscription!(sigra_config(), admin_scope, subscription_id)
  end

  @doc "List retrying and dead-letter webhook deliveries for admins."
  def list_admin_webhook_failures(admin_scope, params \\ %{}) do
    Sigra.Admin.Webhooks.Failures.list_deliveries(sigra_config(), admin_scope, params)
  end

  @doc "Load one shared admin webhook delivery detail."
  def get_admin_webhook_delivery!(admin_scope, delivery_id) do
    Sigra.Admin.Webhooks.Detail.load_delivery!(sigra_config(), admin_scope, delivery_id)
  end

  @doc "Replay a dead-letter webhook delivery through the admin action seam."
  def replay_admin_webhook_delivery(admin_scope, delivery_id, opts \\ []) do
    Sigra.Admin.Webhooks.Actions.replay_delivery(sigra_config(), admin_scope, delivery_id, opts)
  end

  @doc "Create a webhook subscription through the admin action seam."
  def create_admin_webhook_subscription(admin_scope, attrs) do
    Sigra.Admin.Webhooks.Actions.create(sigra_config(), admin_scope, attrs)
  end

  @doc "Update a webhook subscription through the admin action seam."
  def update_admin_webhook_subscription(admin_scope, subscription_id, attrs) do
    Sigra.Admin.Webhooks.Actions.update(sigra_config(), admin_scope, subscription_id, attrs)
  end

  @doc "Enable a webhook subscription through the admin action seam."
  def enable_admin_webhook_subscription(admin_scope, subscription_id) do
    Sigra.Admin.Webhooks.Actions.enable(sigra_config(), admin_scope, subscription_id)
  end

  @doc "Disable a webhook subscription through the admin action seam."
  def disable_admin_webhook_subscription(admin_scope, subscription_id) do
    Sigra.Admin.Webhooks.Actions.disable(sigra_config(), admin_scope, subscription_id)
  end

  @doc "Reveal a webhook signing secret through an explicit admin action."
  def reveal_admin_webhook_secret(admin_scope, subscription_id) do
    Sigra.Admin.Webhooks.Actions.reveal_secret(sigra_config(), admin_scope, subscription_id)
  end

  @doc "Rotate a webhook signing secret through an explicit admin action."
  def rotate_admin_webhook_secret(admin_scope, subscription_id) do
    Sigra.Admin.Webhooks.Actions.rotate_secret(sigra_config(), admin_scope, subscription_id)
  end

  @doc "Prepare a webhook signing secret rotation through an explicit admin action."
  def prepare_admin_webhook_secret(admin_scope, subscription_id) do
    Sigra.Admin.Webhooks.Actions.prepare_secret(sigra_config(), admin_scope, subscription_id)
  end

  @doc "Discard a prepared webhook signing secret through an explicit admin action."
  def discard_prepared_admin_webhook_secret(admin_scope, subscription_id) do
    Sigra.Admin.Webhooks.Actions.discard_prepared_secret(
      sigra_config(),
      admin_scope,
      subscription_id
    )
  end

  @doc "Start a webhook signing secret overlap window through an explicit admin action."
  def start_admin_webhook_secret_overlap(admin_scope, subscription_id, opts \\ []) do
    Sigra.Admin.Webhooks.Actions.start_secret_overlap(
      sigra_config(),
      admin_scope,
      subscription_id,
      opts
    )
  end

  @doc "Complete a webhook signing secret rotation through an explicit admin action."
  def complete_admin_webhook_secret_rotation(admin_scope, subscription_id) do
    Sigra.Admin.Webhooks.Actions.complete_secret_rotation(
      sigra_config(),
      admin_scope,
      subscription_id
    )
  end

  @doc "Load one delivery with its subscription and event for proof correlation."
  def get_webhook_delivery_context(delivery_id) when is_binary(delivery_id) do
    from(delivery in WebhookDelivery,
      where: delivery.delivery_id == ^delivery_id,
      left_join: subscription in assoc(delivery, :webhook_subscription),
      left_join: event in assoc(delivery, :webhook_event),
      preload: [webhook_subscription: subscription, webhook_event: event]
    )
    |> Repo.one()
  end

  @doc "Return receiver-owned candidate secrets for webhook verification."
  def webhook_receiver_secrets do
    webhook_receiver_secret_config()
    |> Map.values()
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
    |> Enum.uniq()
  end

  @doc false
  def webhook_receiver_secret_config do
    configured = Application.get_env(:example, :webhook_receiver_secrets, [])

    %{
      current:
        Keyword.get(configured, :current) || System.get_env("SIGRA_WEBHOOK_SECRET_CURRENT"),
      previous:
        Keyword.get(configured, :previous) || System.get_env("SIGRA_WEBHOOK_SECRET_PREVIOUS")
    }
  end

  @doc "Return the configured test-only receiver mode."
  def webhook_receiver_mode do
    Application.get_env(:example, :webhook_receiver_mode, :healthy)
    |> normalize_webhook_receiver_mode()
  end

  @doc "True when the test-only receiver should fail after successful verification."
  def webhook_receiver_fail_after_verify? do
    webhook_receiver_mode() == :fail_after_verify
  end

  @doc false
  def webhook_endpoint_policy_config do
    configured = Application.get_env(:example, :webhook_endpoint_policy, [])

    %{
      mode:
        configured
        |> Keyword.get(:mode, :healthy)
        |> normalize_webhook_endpoint_policy_mode(),
      endpoint_url: Keyword.get(configured, :endpoint_url),
      detail:
        Keyword.get(configured, :detail) || "blocked by deployment callback"
    }
  end

  @doc false
  def configure_webhook_receiver_secrets(attrs) when is_list(attrs) or is_map(attrs) do
    current = fetch_secret_attr(attrs, [:current, "current", :current_secret, "current_secret"])

    previous =
      fetch_secret_attr(attrs, [:previous, "previous", :previous_secret, "previous_secret"])

    mode = fetch_secret_attr(attrs, [:mode, "mode"])

    Application.put_env(
      :example,
      :webhook_receiver_secrets,
      current: blank_to_nil(current),
      previous: blank_to_nil(previous)
    )

    Application.put_env(:example, :webhook_receiver_mode, normalize_webhook_receiver_mode(mode))

    :ok
  end

  @doc false
  def configure_webhook_endpoint_policy(attrs) when is_list(attrs) or is_map(attrs) do
    mode = fetch_secret_attr(attrs, [:mode, "mode"])
    endpoint_url = fetch_secret_attr(attrs, [:endpoint_url, "endpoint_url"])
    detail = fetch_secret_attr(attrs, [:detail, "detail"])

    Application.put_env(
      :example,
      :webhook_endpoint_policy,
      mode: normalize_webhook_endpoint_policy_mode(mode),
      endpoint_url: blank_to_nil(endpoint_url),
      detail: blank_to_nil(detail) || "blocked by deployment callback"
    )

    :ok
  end

  @doc false
  def get_webhook_subscription_secret_material(subscription_id) when is_binary(subscription_id) do
    case Repo.get(WebhookSubscription, subscription_id) do
      nil ->
        nil

      subscription ->
        %{
          subscription_id: subscription.id,
          current_secret: subscription.signing_secret,
          next_secret: Map.get(subscription, :next_signing_secret),
          rotation_state: Map.get(subscription, :rotation_state) || :stable
        }
    end
  end

  @doc "Load one persisted receiver receipt by delivery id."
  def get_webhook_receipt_by_delivery_id(delivery_id) when is_binary(delivery_id) do
    Repo.get_by(WebhookReceipt, delivery_id: delivery_id)
  end

  @doc "Build one correlated proof bundle for a delivery id."
  def get_webhook_proof_bundle(delivery_id) when is_binary(delivery_id) do
    case get_webhook_delivery_context(delivery_id) do
      %{webhook_event: event, webhook_subscription: subscription} = delivery ->
        receipt = get_webhook_receipt_by_delivery_id(delivery_id)
        replay_parent = load_webhook_delivery_by_id(Map.get(delivery, :replayed_from_webhook_delivery_id))
        replay_root =
          load_webhook_delivery_by_id(
            Map.get(delivery, :replay_root_webhook_delivery_id) || Map.get(delivery, :id)
          )

        source_delivery = replay_parent || delivery
        replay_child = load_replay_child(source_delivery)
        source_receipt = get_webhook_receipt_by_delivery_id(source_delivery.delivery_id)

        replay_receipt =
          case replay_child do
            %{delivery_id: replay_delivery_id} -> get_webhook_receipt_by_delivery_id(replay_delivery_id)
            _other -> nil
          end

        %{
          delivery_id: delivery.delivery_id,
          delivery_status: delivery.status,
          endpoint_url: delivery.endpoint_url,
          event_id: event && event.event_id,
          event_type: event && event.type,
          subscription_id: subscription && subscription.id,
          subscription_description: subscription && subscription.description,
          lineage: %{
            source_delivery_id: source_delivery.delivery_id,
            replay_delivery_id: replay_child && replay_child.delivery_id,
            root_delivery_id: (replay_root || source_delivery).delivery_id,
            replay_parent_delivery_id: replay_parent && replay_parent.delivery_id
          },
          receiver_verification: %{
            current_delivery: build_receipt_proof(receipt),
            source_delivery: build_receipt_proof(source_receipt),
            replay_delivery: build_receipt_proof(replay_receipt)
          },
          receipt:
            build_receipt_proof(receipt)
        }

      nil ->
        nil
    end
  end

  @doc "Persist one verified webhook receipt, deduped by delivery_id."
  def record_webhook_receipt(delivery_id, raw_body, timestamp)
      when is_binary(delivery_id) and is_binary(raw_body) do
    payload = Jason.decode!(raw_body)

    attrs = %{
      delivery_id: delivery_id,
      event_id: payload["id"],
      event_type: payload["type"],
      payload: payload,
      raw_body_sha256: raw_body_sha256(raw_body),
      signature_timestamp: timestamp,
      verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    %WebhookReceipt{}
    |> WebhookReceipt.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, receipt} ->
        {:ok, receipt, :created}

      {:error, changeset} ->
        if receipt_duplicate?(changeset) do
          {:ok, Repo.get_by!(WebhookReceipt, delivery_id: delivery_id), :duplicate}
        else
          {:error, changeset}
        end
    end
  end

  defp fetch_secret_attr(attrs, keys) when is_list(attrs) do
    Enum.find_value(keys, fn key ->
      if is_atom(key) do
        Keyword.get(attrs, key)
      end
    end)
  end

  defp fetch_secret_attr(attrs, keys) when is_map(attrs) do
    Enum.find_value(keys, &Map.get(attrs, &1))
  end

  defp load_webhook_delivery_by_id(nil), do: nil

  defp load_webhook_delivery_by_id(id) when is_binary(id) do
    Repo.get(WebhookDelivery, id)
  end

  defp load_replay_child(%WebhookDelivery{id: source_id}) do
    from(delivery in WebhookDelivery,
      where: delivery.replayed_from_webhook_delivery_id == ^source_id,
      order_by: [asc: delivery.inserted_at, asc: delivery.id],
      limit: 1
    )
    |> Repo.one()
  end

  defp build_receipt_proof(nil), do: nil

  defp build_receipt_proof(receipt) do
    %{
      verified_at: receipt.verified_at,
      raw_body_sha256: receipt.raw_body_sha256,
      signature_timestamp: receipt.signature_timestamp
    }
  end

  defp normalize_webhook_receiver_mode(mode) when mode in [nil, ""], do: :healthy
  defp normalize_webhook_receiver_mode(:healthy), do: :healthy
  defp normalize_webhook_receiver_mode(:fail_after_verify), do: :fail_after_verify
  defp normalize_webhook_receiver_mode("healthy"), do: :healthy
  defp normalize_webhook_receiver_mode("fail_after_verify"), do: :fail_after_verify
  defp normalize_webhook_receiver_mode(_mode), do: :healthy

  defp normalize_webhook_endpoint_policy_mode(mode) when mode in [nil, ""], do: :healthy
  defp normalize_webhook_endpoint_policy_mode(:healthy), do: :healthy
  defp normalize_webhook_endpoint_policy_mode(:deny_exact_endpoint), do: :deny_exact_endpoint
  defp normalize_webhook_endpoint_policy_mode("healthy"), do: :healthy
  defp normalize_webhook_endpoint_policy_mode("deny_exact_endpoint"), do: :deny_exact_endpoint
  defp normalize_webhook_endpoint_policy_mode(_mode), do: :healthy

  defp deny_endpoint?(%URI{}, expected_endpoint_url) when expected_endpoint_url in [nil, ""], do: true

  defp deny_endpoint?(%URI{} = actual_uri, expected_endpoint_url) when is_binary(expected_endpoint_url) do
    case URI.new(expected_endpoint_url) do
      {:ok, %URI{} = expected_uri} ->
        actual_uri.scheme == expected_uri.scheme and
          actual_uri.host == expected_uri.host and
          effective_port(actual_uri) == effective_port(expected_uri) and
          actual_uri.path == expected_uri.path

      _other ->
        true
    end
  end

  defp effective_port(%URI{port: port}) when is_integer(port), do: port
  defp effective_port(%URI{scheme: "https"}), do: 443
  defp effective_port(%URI{}), do: 80

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

  ## API tokens

  @impersonation_api_token_denial_message "You can't manage API tokens while impersonating."

  @doc "Parity helper for generated API-token wrapper behavior."
  def create_api_token(user, attrs, opts \\ []) do
    with :ok <- forbid_api_token_operation(user, opts, "api_token.create") do
      token = %{
        id: Ecto.UUID.generate(),
        name: Map.get(attrs, :name) || Map.get(attrs, "name"),
        scopes: Map.get(attrs, :scopes) || Map.get(attrs, "scopes") || [],
        expires_at: Map.get(attrs, :expires_at) || Map.get(attrs, "expires_at"),
        prefix: "sigra_sk_test"
      }

      {:ok, "sigra_sk_test_raw", token}
    end
  end

  @doc "Parity helper for generated API-token revoke behavior."
  def revoke_api_token(user, token_id, opts \\ []) do
    with :ok <- forbid_api_token_operation(user, opts, "api_token.revoke") do
      {:ok, %{id: token_id}}
    end
  end

  @doc "Parity helper for generated API-token bulk revoke behavior."
  def revoke_all_api_tokens(user, opts \\ []) do
    with :ok <- forbid_api_token_operation(user, opts, "api_token.revoke_all") do
      {:ok, 1}
    end
  end

  ## MFA

  alias Example.Accounts.UserMFACredential
  alias Example.Accounts.UserBackupCode
  alias Example.Accounts.UserPasskey

  @doc "Begin MFA enrollment. Returns secret, otpauth URI, and QR code SVG."
  def mfa_enroll(opts \\ []) do
    Sigra.MFA.enroll(sigra_config(), opts)
  end

  @doc "Confirm MFA enrollment with a TOTP code. Creates credential and backup codes."
  def mfa_confirm_enrollment(user, raw_secret, code, opts \\ []) do
    Sigra.MFA.confirm_enrollment(
      sigra_config(),
      user,
      raw_secret,
      code,
      Keyword.merge(
        [
          mfa_credential_schema: UserMFACredential,
          backup_code_schema: UserBackupCode
        ],
        opts
      )
    )
  end

  @doc "Verify a TOTP code for MFA challenge."
  def mfa_verify(user, code, opts \\ []) do
    Sigra.MFA.verify(
      sigra_config(),
      user,
      code,
      Keyword.merge([mfa_credential_schema: UserMFACredential], opts)
    )
  end

  @doc "Verify a backup code for MFA challenge."
  def mfa_verify_backup(user, code, opts \\ []) do
    Sigra.MFA.verify_backup(
      sigra_config(),
      user,
      code,
      Keyword.merge(
        [
          mfa_credential_schema: UserMFACredential,
          backup_code_schema: UserBackupCode
        ],
        opts
      )
    )
  end

  @doc "Disable MFA for a user. Requires valid TOTP or backup code."
  def mfa_disable(user, code, opts \\ []) do
    with :ok <- forbid_sensitive_operation(opts, user, "mfa.disable") do
      Sigra.MFA.disable(
        sigra_config(),
        user,
        code,
        Keyword.merge(
          [
            mfa_credential_schema: UserMFACredential,
            backup_code_schema: UserBackupCode
          ],
          opts
        )
      )
    end
  end

  @doc """
  Regenerates backup codes after verifying a TOTP code.

  Requires `{:totp, code}` — backup codes **cannot** authorize rotation.
  """
  def mfa_regenerate_backup_codes(user, {:totp, _} = verification, opts \\ []) do
    with :ok <- forbid_sensitive_operation(opts, user, "mfa.regenerate_backup_codes") do
      Sigra.MFA.regenerate_backup_codes(
        sigra_config(),
        user,
        verification,
        Keyword.merge(
          [
            mfa_credential_schema: UserMFACredential,
            backup_code_schema: UserBackupCode
          ],
          opts
        )
      )
    end
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
      mfa_credential_schema: Example.Accounts.UserMFACredential,
      backup_code_schema: Example.Accounts.UserBackupCode
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
    with :ok <- forbid_sensitive_operation(details, user, "passkey.register"),
         :ok <-
           Sigra.Passkeys.rate_limit_ceremony(Sigra.Passkeys.config(), user.id, :registration),
         {:ok, normalized_params} <-
           normalize_passkey_registration_params(
             attestation_params,
             Map.get(attestation_params, "challenge") || Map.get(attestation_params, :challenge)
           ) do
      case passkey_ceremony_module().register(sigra_config(), user, normalized_params,
             user_passkey_schema: UserPasskey
           ) do
        {:ok, credential} ->
          deliver_passkey_registration_notification(
            user,
            Map.merge(details, %{passkey: credential})
          )

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
    with :ok <-
           Sigra.Passkeys.rate_limit_ceremony(Sigra.Passkeys.config(), user.id, :authentication),
         {:ok, normalized_params} <-
           normalize_passkey_assertion_params(
             assertion_params,
             Map.get(assertion_params, "challenge") || Map.get(assertion_params, :challenge)
           ) do
      case passkey_ceremony_module().authenticate(sigra_config(), user, normalized_params,
             user_passkey_schema: UserPasskey
           ) do
        {:ok, ^user, credential} -> {:ok, credential}
        other -> other
      end
    else
      {:error, :rate_limited, _meta} -> {:error, :invalid_passkey}
      {:error, _reason} -> {:error, :invalid_passkey}
    end
  end

  @doc "Authenticate a discoverable passkey without a typed email address."
  def authenticate_discoverable_passkey(assertion_params) do
    with {:ok, normalized_params} <-
           normalize_passkey_assertion_params(
             assertion_params,
             Map.get(assertion_params, "challenge") || Map.get(assertion_params, :challenge)
           ),
         credential_id when is_binary(credential_id) <- Map.get(normalized_params, :credential_id),
         %{user_id: user_id} = passkey <- Repo.get_by(UserPasskey, credential_id: credential_id),
         %User{} = user <- Repo.get(User, user_id),
         :ok <- verify_discoverable_user_handle(normalized_params, passkey),
         :ok <-
           Sigra.Passkeys.rate_limit_ceremony(Sigra.Passkeys.config(), user.id, :authentication),
         {:ok, credential} <-
           authenticate_discoverable_passkey_with_ceremony(user, normalized_params) do
      {:ok, user, credential}
    else
      _ -> {:error, :invalid_passkey}
    end
  end

  @doc "Rename a passkey."
  def rename_passkey(user, credential_id, nickname, opts \\ []) do
    with :ok <- forbid_sensitive_operation(opts, user, "passkey.rename") do
      Sigra.Passkeys.rename(sigra_config(), user, credential_id, nickname || "",
        user_passkey_schema: UserPasskey
      )
    end
  end

  @doc "Delete a passkey."
  def delete_passkey(user, credential_id, opts \\ []) do
    with :ok <- forbid_sensitive_operation(opts, user, "passkey.delete") do
      Sigra.Passkeys.delete(sigra_config(), user, credential_id, user_passkey_schema: UserPasskey)
    end
  end

  @doc "Returns true when passkey-primary login is enabled."
  def passkey_primary_enabled?() do
    case Application.fetch_env(:example, :passkey_primary_enabled) do
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

    Sigra.Delivery.deliver(
      :passkey_registration,
      %{
        user_id: user.id,
        to: user.email,
        subject: email.subject,
        body: %{html: email.html_body, text: email.text_body},
        details: details
      },
      delivery_opts()
    )
  end

  defp normalize_passkey_registration_params(params, challenge) when is_map(params) do
    response = Map.get(params, "response") || Map.get(params, :response) || %{}

    with {:ok, credential_id} <-
           decode_base64url(
             Map.get(params, "rawId") || Map.get(params, :rawId) || Map.get(params, "id") ||
               Map.get(params, :id)
           ),
         {:ok, attestation_object} <-
           decode_base64url(
             Map.get(response, "attestationObject") || Map.get(response, :attestationObject)
           ),
         {:ok, client_data_json} <-
           decode_base64url(
             Map.get(response, "clientDataJSON") || Map.get(response, :clientDataJSON)
           ),
         {:ok, challenge_bytes} <- normalize_challenge(challenge) do
      {:ok,
       %{
         credential_id: credential_id,
         attestation_object: attestation_object,
         client_data_json: client_data_json,
         challenge: challenge_bytes,
         nickname: blank_to_nil(Map.get(params, "nickname") || Map.get(params, :nickname)),
         device_hint:
           blank_to_nil(
             Map.get(params, "device_hint") || Map.get(params, :device_hint) ||
               Map.get(params, "deviceHint") || Map.get(params, :deviceHint)
           ),
         transports: Map.get(response, "transports") || Map.get(response, :transports) || []
       }}
    else
      _ -> {:error, :invalid_passkey}
    end
  end

  defp normalize_passkey_registration_params(_params, _challenge), do: {:error, :invalid_passkey}

  defp normalize_passkey_assertion_params(params, challenge) when is_map(params) do
    response = Map.get(params, "response") || Map.get(params, :response) || %{}

    with {:ok, credential_id} <-
           decode_base64url(
             Map.get(params, "rawId") || Map.get(params, :rawId) || Map.get(params, "id") ||
               Map.get(params, :id)
           ),
         {:ok, authenticator_data} <-
           decode_base64url(
             Map.get(response, "authenticatorData") || Map.get(response, :authenticatorData)
           ),
         {:ok, signature} <-
           decode_base64url(Map.get(response, "signature") || Map.get(response, :signature)),
         {:ok, client_data_json} <-
           decode_base64url(
             Map.get(response, "clientDataJSON") || Map.get(response, :clientDataJSON)
           ),
         {:ok, user_handle} <-
           decode_optional_base64url(
             Map.get(response, "userHandle") || Map.get(response, :userHandle)
           ),
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

  defp normalize_challenge(%Wax.Challenge{} = challenge), do: {:ok, challenge}
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
      {:credential_id, {_message, opts}} ->
        Keyword.get(opts, :constraint) == :unique or Keyword.has_key?(opts, :constraint_name)

      _ ->
        false
    end)
  end

  defp passkey_ceremony_module do
    Application.get_env(:example, :passkey_ceremony_module, Sigra.Passkeys)
  end

  defp authenticate_discoverable_passkey_with_ceremony(user, normalized_params) do
    case passkey_ceremony_module().authenticate(sigra_config(), user, normalized_params,
           user_passkey_schema: UserPasskey
         ) do
      {:ok, ^user, credential} -> {:ok, credential}
      other -> other
    end
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
    Sigra.Auth.confirm_email_change(
      sigra_config(),
      encoded_token,
      Keyword.merge(
        [
          user_token_schema: UserToken,
          user_schema: User,
          session_store: Sigra.SessionStores.Ecto
        ],
        opts
      )
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
      changeset_fn: &User.password_changeset/2
    )
  end

  @doc """
  Set a password for an OAuth-only user who doesn't have one yet.

  Requires sudo mode. Returns `{:ok, user}` or `{:error, changeset}`.
  """
  def set_password(user, attrs) do
    Sigra.Auth.set_password(sigra_config(), user, attrs, changeset_fn: &User.password_changeset/2)
  end

  @doc """
  Schedule account deletion with configured grace period.

  Returns `{:ok, user, scheduled_date}` or `{:error, reason}`.
  """
  def schedule_deletion(user, opts \\ []) do
    with :ok <- forbid_sensitive_operation(opts, user, "account.deletion_schedule") do
      Sigra.Auth.schedule_deletion(
        sigra_config(),
        user,
        Keyword.merge(
          [
            user_token_schema: UserToken,
            session_store: Sigra.SessionStores.Ecto
          ],
          opts
        )
      )
    end
  end

  @doc """
  Cancel a scheduled account deletion.

  Returns `{:ok, user}` or `{:error, reason}`.
  """
  def cancel_deletion(user, opts \\ []) do
    with :ok <- forbid_sensitive_operation(opts, user, "account.deletion_cancel") do
      Sigra.Auth.cancel_deletion(
        sigra_config(),
        user,
        Keyword.merge([changeset_fn: &User.deletion_changeset/2], opts)
      )
    end
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
      mailer: Example.Accounts.Mailer,
      delivery_mode: :auto,
      oban_queue: "sigra_mailer"
    ]
  end

  defp forbid_sensitive_operation(opts_or_details, user, operation) do
    case extract_scope(opts_or_details) do
      %{impersonating_from: impersonator} = scope when not is_nil(impersonator) ->
        Sigra.Audit.log_safe("admin.impersonation.denied", scope,
          audit_schema: Example.Accounts.AuditEvent,
          repo: Repo,
          actor_id: impersonator.id,
          target_id: user.id,
          outcome: "failure",
          metadata: %{operation: operation}
        )

        {:error, :impersonation_forbidden}

      _ ->
        :ok
    end
  end

  defp forbid_api_token_operation(user, opts_or_details, operation) do
    case extract_scope(opts_or_details) do
      %{impersonating_from: impersonator} = scope when not is_nil(impersonator) ->
        Sigra.Audit.log_safe("admin.impersonation.denied", scope,
          audit_schema: Example.Accounts.AuditEvent,
          repo: Repo,
          actor_id: impersonator.id,
          target_id: user.id,
          outcome: "failure",
          metadata: %{operation: operation}
        )

        {:error, :impersonation_forbidden, @impersonation_api_token_denial_message}

      _ ->
        :ok
    end
  end

  defp extract_scope(opts) when is_list(opts), do: Keyword.get(opts, :scope)
  defp extract_scope(%{} = opts), do: Map.get(opts, :scope)
  defp extract_scope(_other), do: nil
end
