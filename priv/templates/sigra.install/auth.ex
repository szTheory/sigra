defmodule <%= context_module %> do
  @moduledoc """
  The authentication context.

  This module provides the primary API for user authentication,
  registration, and account management. All security-critical operations
  delegate to Sigra library functions.
  """

  import Ecto.Query, warn: false
  alias <%= repo_module %>, as: Repo
  alias <%= context_module %>.<%= schema_alias %>
  alias <%= context_module %>.UserToken
  alias Sigra.Auth, as: SigraAuth

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %<%= schema_alias %>{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(<%= schema_alias %>, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %<%= schema_alias %>{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    case SigraAuth.authenticate(Repo, %{"email" => email, "password" => password}, user_schema: <%= schema_alias %>) do
      {:ok, user} -> user
      {:error, _} -> nil
    end
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %<%= schema_alias %>{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(<%= schema_alias %>, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %<%= schema_alias %>{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs, opts \\ []) do
    changeset_fn = fn a -> <%= schema_alias %>.registration_changeset(%<%= schema_alias %>{}, a) end
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
      %Ecto.Changeset{data: %<%= schema_alias %>{}}

  """
  def change_user_registration(%<%= schema_alias %>{} = user, attrs \\ %{}) do
    <%= schema_alias %>.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

  ## Magic link

  @doc """
  Requests a magic link for the given email.

  Returns `{:ok, {raw_token, url}}` for existing users, `{:ok, :sent}`
  for non-existent emails (enumeration-safe), or `{:error, :rate_limited}`.
  """
  def request_magic_link(email, url_fun) when is_binary(email) and is_function(url_fun, 1) do
    SigraAuth.request_magic_link(Repo, email,
      user_schema: <%= schema_alias %>,
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
      user_schema: <%= schema_alias %>,
      user_token_schema: UserToken,
      magic_link_ttl: 600
    )
  end

  ## Settings

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %<%= schema_alias %>{}}

  """
  def change_user_email(%<%= schema_alias %>{} = user, attrs \\ %{}) do
    <%= schema_alias %>.email_changeset(user, attrs, validate_email: false)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  The confirmed_at date is also updated to the current time.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    with {:ok, query} <- UserToken.verify_email_token_query(token, context),
         %<%= schema_alias %>{} = user_from_token <- Repo.one(query),
         true <- user.id == user_from_token.id || :token_user_mismatch do
      user_changeset = user |> <%= schema_alias %>.email_changeset(%{email: user_from_token.email}) |> <%= schema_alias %>.confirm_changeset()
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
      %Ecto.Changeset{data: %<%= schema_alias %>{}}

  """
  def change_user_password(%<%= schema_alias %>{} = user, attrs \\ %{}) do
    <%= schema_alias %>.password_changeset(user, attrs, hash_password: false)
  end

  @doc """
  Updates the user password.

  ## Examples

      iex> update_user_password(user, "valid password", %{password: ...})
      {:ok, %<%= schema_alias %>{}}

      iex> update_user_password(user, "invalid password", %{password: ...})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(%<%= schema_alias %>{} = user, password, attrs) do
    changeset =
      user
      |> <%= schema_alias %>.password_changeset(attrs)
      |> <%= schema_alias %>.validate_current_password(password)

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
  Generates a session token.
  """
  def generate_user_session_token(%<%= schema_alias %>{} = user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## Confirmation

  @doc """
  Delivers the confirmation email to the given user.

  Generates both a link token (HMAC-signed) and a 6-digit code.
  Delivers via Oban (async) or inline (sync) based on config.

  Returns `{:ok, :sent}` on success, `{:error, :already_confirmed}` if
  already confirmed.
  """
  def deliver_user_confirmation_instructions(%<%= schema_alias %>{} = user, confirmation_url_fun)
      when is_function(confirmation_url_fun, 1) do
    if user.confirmed_at do
      {:error, :already_confirmed}
    else
      {signed_token, code, link_token, code_token} =
        Sigra.Auth.generate_confirmation_token(Repo, user,
          secret_key_base: <%= web_module %>.Endpoint.config(:secret_key_base),
          user_token_schema: UserToken
        )

      Repo.insert!(link_token)
      Repo.insert!(code_token)

      url = confirmation_url_fun.(signed_token)
      email = <%= context_module %>.Emails.confirmation_email(user, url, code)

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
      user_schema: <%= schema_alias %>,
      user_token_schema: UserToken,
      secret_key_base: <%= web_module %>.Endpoint.config(:secret_key_base),
      confirmation_ttl: 48 * 60 * 60
    )
  end

  @doc """
  Confirms a user by 6-digit code entry.

  Rate-limited to 5 attempts per user per 15 minutes.
  """
  def confirm_user_by_code(%<%= schema_alias %>{} = user, code) when is_binary(code) do
    Sigra.Auth.verify_confirmation_code(Repo, code,
      user_id: user.id,
      user_schema: <%= schema_alias %>,
      user_token_schema: UserToken,
      secret_key_base: <%= web_module %>.Endpoint.config(:secret_key_base)
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
      user_schema: <%= schema_alias %>,
      secret_key_base: <%= web_module %>.Endpoint.config(:secret_key_base),
      url_fun: reset_password_url_fun
    ) do
      {:ok, {signed_token, url}} ->
        user = get_user_by_email(email)

        if user do
          email_struct = <%= context_module %>.Emails.reset_password_email(user, url)

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
      %<%= schema_alias %>{}

      iex> get_user_by_reset_password_token("invalidtoken")
      nil

  """
  def get_user_by_reset_password_token(signed_token) do
    secret_key_base = <%= web_module %>.Endpoint.config(:secret_key_base)

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
      {:ok, %<%= schema_alias %>{}}

  """
  def reset_user_password(signed_token, attrs) when is_binary(signed_token) do
    Sigra.Auth.reset_password(Repo, signed_token, attrs,
      secret_key_base: <%= web_module %>.Endpoint.config(:secret_key_base),
      user_token_schema: UserToken,
      user_schema: <%= schema_alias %>,
      changeset_fn: &<%= schema_alias %>.password_changeset/2,
      reset_ttl: 3600
    )
  end

  @doc """
  Resets the user password (legacy API accepting user struct).

  ## Examples

      iex> reset_user_password(user, %{password: "new long password", password_confirmation: "new long password"})
      {:ok, %<%= schema_alias %>{}}

  """
  def reset_user_password(%<%= schema_alias %>{} = user, attrs) do
    Ecto.Multi.new()
    |> Ecto.Multi.update(:user, <%= schema_alias %>.password_changeset(user, attrs))
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
      repo: <%= repo_module %>,
      user_schema: <%= schema_alias %>,
      session: [
        store: Sigra.SessionStore.Ecto,
        session_schema: <%= context_module %>.UserSession
      ],
      lockout: [
        threshold: 5,
        duration: 900
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
    Sigra.Auth.delete_all_sessions(sigra_config(), user.id, Keyword.put(opts, :pubsub, <%= web_module %>.PubSub))
  end

  @doc "Confirm sudo mode for a session."
  def confirm_sudo(hashed_token) do
    Sigra.Auth.confirm_sudo(sigra_config(), hashed_token)
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

  # -- Private helpers --

  defp delivery_opts do
    [
      mailer: <%= context_module %>.Mailer,
      delivery_mode: :auto,
      oban_queue: "sigra_mailer"
    ]
  end
end
