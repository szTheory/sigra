defmodule Sigra.Auth do
  @moduledoc """
  Core authentication orchestrator.

  All security-critical auth operations live here. The generated
  `MyApp.Auth` context delegates to these functions for registration,
  authentication, session management, and magic link flows.

  ## Usage

      Sigra.Auth.register(MyApp.Repo, attrs, changeset_fn: &MyApp.User.registration_changeset/1)
      Sigra.Auth.authenticate(MyApp.Repo, params, user_schema: MyApp.User)

  ## Security Properties

  - User enumeration prevention: generic error messages, constant-time operations
  - Hash upgrade: transparent bcrypt-to-Argon2id migration on successful login
  - Failed attempt tracking: incremented on wrong password, reset on success
  - Magic link: single-use, 10-minute TTL, rate limited
  - Telemetry: all operations emit structured events
  """

  alias Ecto.Multi
  alias Sigra.{Crypto, Email, Telemetry, Token}

  @doc """
  Registers a user.

  Takes a repo module, attributes map, and options. The `:changeset_fn`
  option must be a function that takes attrs and returns an `Ecto.Changeset`.

  Returns `{:ok, user}` on success, `{:error, changeset}` for validation
  errors, or `{:error, :email_taken}` when the email uniqueness constraint
  is violated (enumeration-safe -- callers should show a generic message).

  ## Options

  - `:changeset_fn` - Required. Function `(attrs -> Ecto.Changeset.t())`.

  ## Telemetry

  Emits `[:sigra, :auth, :register, :start | :stop | :exception]` span.
  On success, metadata includes `%{user_id: id}`.
  """
  @doc since: "0.2.0"
  @spec register(module(), map(), keyword()) ::
          {:ok, struct()} | {:error, Ecto.Changeset.t()} | {:error, :email_taken}
  def register(repo, attrs, opts \\ []) do
    changeset_fn = Keyword.fetch!(opts, :changeset_fn)

    Telemetry.span([:sigra, :auth, :register], %{}, fn ->
      changeset = changeset_fn.(attrs)

      case repo.insert(changeset) do
        {:ok, user} ->
          Telemetry.event([:sigra, :auth, :register, :stop], %{}, %{user_id: user.id})
          {:ok, user}

        {:error, changeset} ->
          if email_taken_error?(changeset) do
            {:error, :email_taken}
          else
            {:error, changeset}
          end
      end
    end)
  end

  @doc """
  Authenticates a user by email and password.

  Normalizes the email, looks up the user, verifies the password with
  automatic hash upgrade support (bcrypt -> Argon2id), and tracks failed
  login attempts.

  Returns `{:ok, user}` on success with failed attempts reset to 0,
  `{:error, :invalid_credentials}` on failure, or `{:error, :unconfirmed}`
  when confirmation is required and the user has not confirmed their email.

  ## Options

  - `:user_schema` - Required. The Ecto schema module for users.
  - `:require_confirmation` - Whether to check `confirmed_at`. Default: `false`.

  ## Telemetry

  - `[:sigra, :auth, :login, :start | :stop | :exception]` span
  - `[:sigra, :auth, :hash_upgraded]` event when hash is upgraded
  """
  @doc since: "0.2.0"
  @spec authenticate(module() | Sigra.Config.t(), map(), keyword()) ::
          {:ok, struct()}
          | {:ok, struct(), map()}
          | {:error, :invalid_credentials | :unconfirmed | :account_locked}
  def authenticate(repo_or_config, params, opts \\ [])

  def authenticate(%Sigra.Config{} = config, params, _opts) do
    authenticate_with_config(config, params)
  end

  def authenticate(repo, params, opts) do
    user_schema = Keyword.fetch!(opts, :user_schema)
    require_confirmation = Keyword.get(opts, :require_confirmation, false)

    email =
      (params["email"] || params[:email] || "")
      |> Email.normalize()

    user = repo.get_by(user_schema, email: email)
    password = params["password"] || params[:password] || ""
    hashed_password = user && Map.get(user, :hashed_password)

    case Crypto.verify_with_upgrade(password, hashed_password) do
      {:ok, :valid} ->
        handle_valid_login(repo, user, require_confirmation, %{}, opts)

      {:ok, :valid, new_hash} ->
        Telemetry.event([:sigra, :auth, :hash_upgraded], %{}, %{user_id: user.id})
        handle_valid_login(repo, user, require_confirmation, %{hashed_password: new_hash}, opts)

      {:error, :invalid} ->
        if user do
          # Increment failed login attempts for existing users
          increment_failed_attempts(repo, user)
        end

        {:error, :invalid_credentials}
    end
  end

  defp authenticate_with_config(config, params) do
    repo = config.repo
    user_schema = config.user_schema
    require_confirmation = config.require_confirmation
    lockout_opts = [
      threshold: Keyword.get(config.lockout, :threshold, 5),
      duration: Keyword.get(config.lockout, :duration, 900)
    ]

    email =
      (params["email"] || params[:email] || "")
      |> Email.normalize()

    login_ip = params["ip"] || params[:ip]
    user = repo.get_by(user_schema, email: email)

    # Step 1: Check lockout BEFORE password verification (D-29)
    case Sigra.Lockout.check(user, lockout_opts) do
      {:error, :account_locked, _remaining} ->
        {:error, :account_locked}

      :ok ->
        password = params["password"] || params[:password] || ""
        hashed_password = user && Map.get(user, :hashed_password)

        case Crypto.verify_with_upgrade(password, hashed_password) do
          {:ok, :valid} ->
            handle_valid_login_with_security(config, repo, user, require_confirmation, %{}, login_ip)

          {:ok, :valid, new_hash} ->
            Telemetry.event([:sigra, :auth, :hash_upgraded], %{}, %{user_id: user.id})
            handle_valid_login_with_security(config, repo, user, require_confirmation, %{hashed_password: new_hash}, login_ip)

          {:error, :invalid} ->
            if user do
              handle_failed_login_with_lockout(config, repo, user, login_ip, lockout_opts)
            else
              {:error, :invalid_credentials}
            end
        end
    end
  end

  @doc """
  Requests a magic link for the given email.

  If the user exists and is not rate-limited, generates a token and returns
  `{:ok, {raw_token, url}}`. If the user does not exist, returns `{:ok, :sent}`
  to prevent email enumeration. If rate-limited, returns `{:error, :rate_limited}`.

  ## Options

  - `:user_schema` - Required. The Ecto schema module for users.
  - `:url_fun` - Required. Function `(token -> url_string)`.
  - `:rate_limiter` - Module implementing `Sigra.RateLimiter`. Default: `nil` (no rate limiting).
  - `:max_requests` - Max magic link requests per window. Default: `3`.
  - `:window_ms` - Rate limit window in milliseconds. Default: `900_000` (15 min).
  """
  @doc since: "0.2.0"
  @spec request_magic_link(module(), String.t(), keyword()) ::
          {:ok, {String.t(), String.t()}} | {:ok, :sent} | {:error, :rate_limited}
  def request_magic_link(repo, email, opts \\ []) do
    user_schema = Keyword.fetch!(opts, :user_schema)
    url_fun = Keyword.fetch!(opts, :url_fun)
    rate_limiter = Keyword.get(opts, :rate_limiter)
    max_requests = Keyword.get(opts, :max_requests, 3)
    window_ms = Keyword.get(opts, :window_ms, 900_000)

    normalized_email = Email.normalize(email)
    user = repo.get_by(user_schema, email: normalized_email)

    cond do
      is_nil(user) ->
        # Enumeration-safe: return generic response without DB write
        {:ok, :sent}

      rate_limiter && rate_limited?(rate_limiter, "magic_link:#{normalized_email}", max_requests, window_ms) ->
        {:error, :rate_limited}

      true ->
        {raw_token, hashed_token} = Token.generate_hashed_token()

        token_struct = %{
          token: hashed_token,
          context: "magic_link",
          sent_to: user.email,
          user_id: user.id
        }

        repo.insert!(token_struct)
        url = url_fun.(raw_token)

        {:ok, {raw_token, url}}
    end
  end

  @doc """
  Verifies a magic link token. Confirms user if unconfirmed.

  The token is single-use: it is deleted from the database after successful
  verification. If the user has not confirmed their email, `confirmed_at`
  is set to the current time.

  ## Options

  - `:user_schema` - Required. The Ecto schema module for users.
  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  - `:magic_link_ttl` - Token TTL in seconds. Default: `600` (10 minutes).
  """
  @doc since: "0.2.0"
  @spec verify_magic_link(module(), String.t(), keyword()) ::
          {:ok, struct()} | {:error, :invalid | :expired}
  def verify_magic_link(repo, raw_token, opts \\ []) do
    user_schema = Keyword.fetch!(opts, :user_schema)
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)
    magic_link_ttl = Keyword.get(opts, :magic_link_ttl, 600)

    # Decode and hash the token
    hashed_token =
      case Base.url_decode64(raw_token, padding: false) do
        {:ok, decoded} -> Token.hash_token(decoded)
        :error -> nil
      end

    if is_nil(hashed_token) do
      {:error, :invalid}
    else
      case repo.get_by(user_token_schema, token: hashed_token, context: "magic_link") do
        nil ->
          {:error, :invalid}

        token_record ->
          # Check TTL
          age_seconds = DateTime.diff(DateTime.utc_now(), token_record.inserted_at, :second)

          if age_seconds > magic_link_ttl do
            {:error, :expired}
          else
            user = repo.get!(user_schema, token_record.user_id)

            # Single-use: delete token
            repo.delete!(token_record)

            # Auto-confirm unconfirmed users
            user = maybe_confirm_user(repo, user)

            {:ok, user}
          end
      end
    end
  end

  @doc """
  Generates a confirmation link token AND a 6-digit code for the given user.

  Returns `{encoded_token, code, link_token_struct, code_token_struct}`.
  The encoded_token is HMAC-signed for URL use. The code is a random 6-digit
  numeric string. Both are stored as SHA-256 hashes in the DB.

  Per D-01: link-first, code as fallback. Both generated together.

  ## Options

  - `:secret_key_base` - Required. The host app's secret key base.
  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  """
  @doc since: "0.3.0"
  @spec generate_confirmation_token(module(), struct(), keyword()) ::
          {String.t(), String.t(), struct(), struct()}
  def generate_confirmation_token(_repo, user, opts \\ []) do
    secret_key_base = Keyword.fetch!(opts, :secret_key_base)
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)

    # Generate link token: random bytes -> HMAC sign -> base64 encode
    {raw_token, hashed_token} = Token.generate_hashed_token()
    signed = Plug.Crypto.sign(secret_key_base, "sigra-confirm-token", raw_token)
    encoded_token = Base.url_encode64(signed, padding: false)

    # Generate 6-digit code (100000-999999) using rejection sampling
    # to eliminate modulo bias from the 4-byte random integer.
    code =
      (uniform_random(900_000) + 100_000)
      |> Integer.to_string()
    hashed_code = Token.hash_token(code)

    # Build token structs
    link_struct = struct!(user_token_schema, %{
      token: hashed_token,
      context: "confirm",
      sent_to: user.email,
      user_id: user.id
    })

    code_struct = struct!(user_token_schema, %{
      token: hashed_code,
      context: "confirm_code",
      sent_to: user.email,
      user_id: user.id
    })

    {encoded_token, code, link_struct, code_struct}
  end

  @doc """
  Confirms a user by HMAC-signed link token.

  Verifies the HMAC signature, decodes the raw token, hashes it,
  looks up in DB. On success, sets confirmed_at and deletes all
  confirm/confirm_code tokens for the user in a single transaction.

  Returns `{:ok, user}`, `{:error, :token_expired}`, `{:error, :token_invalid}`,
  or `{:error, :already_confirmed}`.

  ## Options

  - `:secret_key_base` - Required. The host app's secret key base.
  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  - `:user_schema` - Required. The Ecto schema module for users.
  - `:confirmation_ttl` - Token TTL in seconds. Default: `172800` (48 hours).
  """
  @doc since: "0.3.0"
  @spec confirm_user(module(), String.t(), keyword()) ::
          {:ok, struct()} | {:error, :token_expired | :token_invalid | :already_confirmed}
  def confirm_user(repo, encoded_token, opts \\ []) do
    secret_key_base = Keyword.fetch!(opts, :secret_key_base)
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)
    user_schema = Keyword.fetch!(opts, :user_schema)
    ttl = Keyword.get(opts, :confirmation_ttl, 48 * 60 * 60)

    # Decode base64, then verify HMAC
    with {:ok, signed} <- Base.url_decode64(encoded_token, padding: false),
         {:ok, raw_token} <- Plug.Crypto.verify(secret_key_base, "sigra-confirm-token", signed, max_age: ttl) do
      hashed_token = Token.hash_token(raw_token)

      # Look up token in DB
      case repo.get_by(user_token_schema, token: hashed_token, context: "confirm") do
        nil ->
          {:error, :token_invalid}

        token_record ->
          # Build atomic transaction: confirm user + delete all confirm tokens
          multi =
            Multi.new()
            |> Multi.run(:confirm_user, fn _repo, _changes ->
              user = repo.get!(user_schema, token_record.user_id)

              if user.confirmed_at do
                {:error, :already_confirmed}
              else
                now = DateTime.utc_now() |> DateTime.truncate(:second)
                changeset = Ecto.Changeset.change(user, confirmed_at: now)

                case repo.update(changeset) do
                  {:ok, updated} -> {:ok, updated}
                  {:error, changeset} -> {:error, changeset}
                end
              end
            end)
            |> Multi.run(:delete_tokens, fn _repo, _changes ->
              import Ecto.Query

              query =
                from(t in user_token_schema,
                  where: t.user_id == ^token_record.user_id,
                  where: t.context in ["confirm", "confirm_code"]
                )

              repo.delete_all(query)
              {:ok, :deleted}
            end)

          case repo.transaction(multi) do
            {:ok, %{confirm_user: user}} ->
              Telemetry.event([:sigra, :confirmation, :verify, :stop], %{}, %{user_id: user.id})
              {:ok, user}

            {:error, :confirm_user, :already_confirmed, _changes} ->
              {:error, :already_confirmed}

            {:error, _step, reason, _changes} ->
              {:error, reason}
          end
      end
    else
      {:error, :expired} -> {:error, :token_expired}
      {:error, _} -> {:error, :token_invalid}
      :error -> {:error, :token_invalid}
    end
  end

  @doc """
  Confirms a user by 6-digit code.

  SHA-256 hashes the submitted code, looks up in DB with context "confirm_code".
  Rate-limited to 5 attempts per user per 15 minutes.

  ## Options

  - `:user_id` - Required. The user ID to confirm.
  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  - `:user_schema` - Required. The Ecto schema module for users.
  - `:secret_key_base` - Required. The host app's secret key base.
  - `:rate_limiter` - Module implementing `Sigra.RateLimiter`. Default: `nil`.
  - `:max_code_attempts` - Max code verification attempts per window. Default: `5`.
  - `:code_window_ms` - Rate limit window in milliseconds. Default: `900_000` (15 min).
  """
  @doc since: "0.3.0"
  @spec verify_confirmation_code(module(), String.t(), keyword()) ::
          {:ok, struct()} | {:error, :invalid_code | :rate_limited | :already_confirmed}
  def verify_confirmation_code(repo, code, opts \\ []) do
    user_id = Keyword.fetch!(opts, :user_id)
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)
    user_schema = Keyword.fetch!(opts, :user_schema)
    rate_limiter = Keyword.get(opts, :rate_limiter)
    max_attempts = Keyword.get(opts, :max_code_attempts, 5)
    window_ms = Keyword.get(opts, :code_window_ms, 900_000)

    # Check rate limit first
    if rate_limiter do
      case rate_limiter.check_rate("sigra:confirm_code:#{user_id}", max_attempts, window_ms) do
        {:allow, _count} -> :ok
        {:deny, _retry_after} -> {:error, :rate_limited}
      end
    else
      :ok
    end
    |> case do
      {:error, :rate_limited} = err ->
        err

      :ok ->
        hashed_code = Token.hash_token(code)

        case repo.get_by(user_token_schema, token: hashed_code, context: "confirm_code") do
          nil ->
            {:error, :invalid_code}

          token_record ->
            # Build atomic transaction: confirm user + delete all confirm tokens
            multi =
              Multi.new()
              |> Multi.run(:confirm_user, fn _repo, _changes ->
                user = repo.get!(user_schema, token_record.user_id)

                if user.confirmed_at do
                  {:error, :already_confirmed}
                else
                  now = DateTime.utc_now() |> DateTime.truncate(:second)
                  changeset = Ecto.Changeset.change(user, confirmed_at: now)

                  case repo.update(changeset) do
                    {:ok, updated} -> {:ok, updated}
                    {:error, changeset} -> {:error, changeset}
                  end
                end
              end)
              |> Multi.run(:delete_tokens, fn _repo, _changes ->
                import Ecto.Query

                query =
                  from(t in user_token_schema,
                    where: t.user_id == ^token_record.user_id,
                    where: t.context in ["confirm", "confirm_code"]
                  )

                repo.delete_all(query)
                {:ok, :deleted}
              end)

            case repo.transaction(multi) do
              {:ok, %{confirm_user: user}} ->
                Telemetry.event([:sigra, :confirmation, :verify, :stop], %{}, %{user_id: user.id})
                {:ok, user}

              {:error, :confirm_user, :already_confirmed, _changes} ->
                {:error, :already_confirmed}

              {:error, _step, reason, _changes} ->
                {:error, reason}
            end
        end
    end
  end

  @doc """
  Requests a password reset for the given email.

  Enumeration-safe: always returns `{:ok, :sent}` for non-existent emails
  with a dummy hash operation to match timing (per D-38).

  ## Options

  - `:user_schema` - Required. The Ecto schema module for users.
  - `:secret_key_base` - Required. The host app's secret key base.
  - `:url_fun` - Required. Function `(token -> url_string)`.
  - `:rate_limiter` - Module implementing `Sigra.RateLimiter`. Default: `nil`.
  - `:max_requests` - Max reset requests per window. Default: `3`.
  - `:window_ms` - Rate limit window in milliseconds. Default: `900_000` (15 min).
  """
  @doc since: "0.3.0"
  @spec request_password_reset(module(), String.t(), keyword()) ::
          {:ok, {String.t(), String.t()}} | {:ok, :sent} | {:error, :rate_limited}
  def request_password_reset(repo, email, opts \\ []) do
    user_schema = Keyword.fetch!(opts, :user_schema)
    secret_key_base = Keyword.fetch!(opts, :secret_key_base)
    url_fun = Keyword.fetch!(opts, :url_fun)
    rate_limiter = Keyword.get(opts, :rate_limiter)
    max_requests = Keyword.get(opts, :max_requests, 3)
    window_ms = Keyword.get(opts, :window_ms, 900_000)

    normalized_email = Email.normalize(email)
    user = repo.get_by(user_schema, email: normalized_email)

    cond do
      is_nil(user) ->
        # Enumeration-safe: dummy hash to match timing
        Crypto.hash_password("dummy_password_for_timing")
        {:ok, :sent}

      rate_limiter && rate_limited?(rate_limiter, "sigra:reset:#{normalized_email}", max_requests, window_ms) ->
        {:error, :rate_limited}

      true ->
        {raw_token, hashed_token} = Token.generate_hashed_token()
        signed = Plug.Crypto.sign(secret_key_base, "sigra-reset-token", raw_token)
        encoded_token = Base.url_encode64(signed, padding: false)

        token_struct = %{
          token: hashed_token,
          context: "reset_password",
          sent_to: user.email,
          user_id: user.id
        }

        repo.insert!(token_struct)
        url = url_fun.(encoded_token)

        Telemetry.event([:sigra, :reset, :requested], %{}, %{user_id: user.id})

        {:ok, {encoded_token, url}}
    end
  end

  @doc """
  Resets a user's password using a valid reset token.

  Verifies HMAC signature, looks up token in DB, changes password,
  and invalidates ALL tokens (including sessions) in a single transaction.
  Per D-29: auto-login after reset (caller creates new session).

  ## Options

  - `:secret_key_base` - Required. The host app's secret key base.
  - `:user_token_schema` - Required. The Ecto schema module for user tokens.
  - `:user_schema` - Required. The Ecto schema module for users.
  - `:changeset_fn` - Required. Function `(user, attrs -> Ecto.Changeset.t())`.
  - `:reset_ttl` - Token TTL in seconds. Default: `3600` (1 hour).
  """
  @doc since: "0.3.0"
  @spec reset_password(module(), String.t(), map(), keyword()) ::
          {:ok, struct()} | {:error, :token_expired | :token_invalid | Ecto.Changeset.t()}
  def reset_password(repo, encoded_token, password_attrs, opts \\ []) do
    secret_key_base = Keyword.fetch!(opts, :secret_key_base)
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)
    user_schema = Keyword.fetch!(opts, :user_schema)
    changeset_fn = Keyword.fetch!(opts, :changeset_fn)
    ttl = Keyword.get(opts, :reset_ttl, 60 * 60)

    # Decode base64, then verify HMAC
    with {:ok, signed} <- Base.url_decode64(encoded_token, padding: false),
         {:ok, raw_token} <- Plug.Crypto.verify(secret_key_base, "sigra-reset-token", signed, max_age: ttl) do
      hashed_token = Token.hash_token(raw_token)

      case repo.get_by(user_token_schema, token: hashed_token, context: "reset_password") do
        nil ->
          {:error, :token_invalid}

        token_record ->
          multi =
            Multi.new()
            |> Multi.run(:reset_password, fn _repo, _changes ->
              user = repo.get!(user_schema, token_record.user_id)
              changeset = changeset_fn.(user, password_attrs)

              case repo.update(changeset) do
                {:ok, updated} -> {:ok, updated}
                {:error, changeset} -> {:error, changeset}
              end
            end)
            |> Multi.run(:delete_all_tokens, fn _repo, _changes ->
              import Ecto.Query

              query =
                from(t in user_token_schema,
                  where: t.user_id == ^token_record.user_id
                )

              repo.delete_all(query)
              {:ok, :deleted}
            end)

          case repo.transaction(multi) do
            {:ok, %{reset_password: user}} ->
              Telemetry.event([:sigra, :reset, :completed], %{}, %{user_id: user.id})
              {:ok, user}

            {:error, :reset_password, %Ecto.Changeset{} = changeset, _changes} ->
              {:error, changeset}

            {:error, _step, reason, _changes} ->
              {:error, reason}
          end
      end
    else
      {:error, :expired} -> {:error, :token_expired}
      {:error, _} -> {:error, :token_invalid}
      :error -> {:error, :token_invalid}
    end
  end

  # -- Session Management (Phase 4 Plan 02) --

  @doc """
  Create a new session for the user with connection metadata.

  Creates a session via the configured SessionStore and emits a
  `[:sigra, :session, :create]` telemetry span.

  ## Options

  - `:session_store` - Override the session store from config.
  """
  @doc since: "0.4.0"
  @spec create_session(Sigra.Config.t(), struct(), map(), keyword()) ::
          {:ok, Sigra.Session.t()} | {:error, term()}
  def create_session(config, user, metadata, opts \\ []) do
    {session_store, store_opts} = session_store_and_opts(config, opts)

    Telemetry.span([:sigra, :session, :create], %{user_id: user.id, type: Map.get(metadata, :type, :standard)}, fn ->
      session_store.create(user.id, metadata, store_opts)
    end)
  end

  @doc """
  Delete a specific session by its hashed token.

  Emits a `[:sigra, :session, :delete]` telemetry span.
  """
  @doc since: "0.4.0"
  @spec delete_session(Sigra.Config.t(), binary(), keyword()) :: :ok
  def delete_session(config, hashed_token, opts \\ []) do
    {session_store, store_opts} = session_store_and_opts(config, opts)

    Telemetry.span([:sigra, :session, :delete], %{}, fn ->
      session_store.delete(hashed_token, store_opts)
    end)
  end

  @doc """
  Delete all sessions for a user. Broadcasts PubSub disconnect per D-16.

  Returns `{count, nil}` where count is the number of deleted sessions.

  ## Options

  - `:except_token` - Hashed token to exclude (current session).
  - `:pubsub` - Phoenix.PubSub module name for LiveView disconnect broadcasts.
  """
  @doc since: "0.4.0"
  @spec delete_all_sessions(Sigra.Config.t(), term(), keyword()) :: {non_neg_integer(), nil}
  def delete_all_sessions(config, user_id, opts \\ []) do
    {session_store, store_opts} = session_store_and_opts(config, opts)

    # Get all sessions BEFORE deleting (need tokens for PubSub broadcast)
    sessions = session_store.list_by_user(user_id, store_opts)

    except_token = Keyword.get(opts, :except_token)

    delete_opts =
      if except_token,
        do: Keyword.put(store_opts, :except_token, except_token),
        else: store_opts

    {count, _} = session_store.delete_all_for_user(user_id, delete_opts)

    # Broadcast disconnect to LiveView sockets per D-16
    pubsub = Keyword.get(opts, :pubsub)

    if pubsub do
      sessions
      |> Enum.reject(fn s -> except_token && s.hashed_token == except_token end)
      |> Enum.each(fn session ->
        live_socket_id = "users_sessions:#{Base.url_encode64(session.hashed_token)}"
        Phoenix.PubSub.broadcast(pubsub, live_socket_id, :disconnect)
      end)
    end

    Telemetry.event([:sigra, :session, :revoke_all, :stop], %{count: count}, %{user_id: user_id})
    {count, nil}
  end

  @doc """
  List all active sessions for a user.

  Excludes `:mfa_pending` sessions from the listing since they represent
  incomplete authentication attempts, not active sessions (D-29).
  """
  @doc since: "0.4.0"
  @spec list_sessions(Sigra.Config.t(), term(), keyword()) :: [Sigra.Session.t()]
  def list_sessions(config, user_id, opts \\ []) do
    {session_store, store_opts} = session_store_and_opts(config, opts)

    session_store.list_by_user(user_id, store_opts)
    |> Enum.reject(fn session -> session.type == :mfa_pending end)
  end

  @doc """
  Revoke a specific session by hashed_token.

  Delegates to `delete_session/3`.
  """
  @doc since: "0.4.0"
  @spec revoke_session(Sigra.Config.t(), binary(), keyword()) :: :ok
  def revoke_session(config, hashed_token, opts \\ []) do
    delete_session(config, hashed_token, opts)
  end

  @doc """
  Confirm sudo mode by updating sudo_at timestamp.

  Emits a `[:sigra, :session, :sudo]` telemetry span.
  """
  @doc since: "0.4.0"
  @spec confirm_sudo(Sigra.Config.t(), binary(), keyword()) :: :ok | {:error, :not_found}
  def confirm_sudo(config, hashed_token, opts \\ []) do
    {session_store, store_opts} = session_store_and_opts(config, opts)

    Telemetry.span([:sigra, :session, :sudo], %{}, fn ->
      session_store.update_sudo(hashed_token, DateTime.utc_now(), store_opts)
    end)
  end

  # -- OAuth Integration (Phase 5 Plan 02) --

  @doc """
  Registers a new user via OAuth provider callback data.

  Creates user + identity in a transaction. Sets confirmed_at if provider
  email is trusted. Creates a session with auth_method: :oauth metadata.

  Delegates to `Sigra.OAuth.Callback.process_callback/4` for the full
  account routing logic (register/login/link-confirm).
  """
  @doc since: "0.5.0"
  @spec register_oauth(Sigra.Config.t() | map(), atom(), map(), map()) ::
          {:ok, :registered, map(), map()} | {:error, term()}
  def register_oauth(config, provider, user_info, token) do
    Sigra.OAuth.Callback.process_callback(config, provider, user_info, token)
  end

  @doc """
  Logs in an existing user via OAuth identity match.

  Looks up identity by (provider, provider_uid), updates identity fields,
  creates session with auth_method: :oauth metadata.

  Delegates to `Sigra.OAuth.Callback.process_callback/4`.
  """
  @doc since: "0.5.0"
  @spec login_oauth(Sigra.Config.t() | map(), atom(), map(), map()) ::
          {:ok, :logged_in, map(), map()} | {:link_confirmation_required, map()} | {:error, term()}
  def login_oauth(config, provider, user_info, token) do
    Sigra.OAuth.Callback.process_callback(config, provider, user_info, token)
  end

  @doc """
  Links an OAuth provider to an existing authenticated user.

  Requires sudo mode active. Creates identity record, sends notification email.

  Returns `{:ok, identity}` or `{:error, reason}`.
  """
  @doc since: "0.5.0"
  @spec link_provider(Sigra.Config.t() | map(), map(), map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def link_provider(config, user, provider_info, opts \\ []) do
    Sigra.OAuth.link_provider(config, user, provider_info, opts)
  end

  @doc """
  Unlinks an OAuth provider from a user.

  Blocks if last auth method and no password set (D-03).
  Sends notification email. Returns `{:ok, :unlinked}` or `{:error, reason}`.
  """
  @doc since: "0.5.0"
  @spec unlink_provider(Sigra.Config.t() | map(), map(), atom() | String.t(), keyword()) ::
          {:ok, :unlinked} | {:error, :last_provider | :not_found}
  def unlink_provider(config, user, provider, opts \\ []) do
    Sigra.OAuth.unlink_provider(config, user, provider, opts)
  end

  # -- MFA Session Management (Phase 6 Plan 02) --

  @doc """
  Completes MFA verification by rotating the session token and upgrading
  the session type from :mfa_pending to :standard or :remember_me.

  Called after successful TOTP or backup code verification. The old
  mfa_pending session token is invalidated and a new token is issued,
  preventing session fixation attacks.

  ## Options

    * `:remember_me` - If `true`, upgrades to `:remember_me` session. Default: `false`.
    * `:trust_browser` - If `true`, includes trust_browser flag in result for
      "trust this browser" cookie. Default: `false`.

  ## Returns

    * `{:ok, %{session: session, trust_browser: boolean}}` on success
    * `{:error, reason}` if session creation fails
  """
  @doc since: "0.6.0"
  @spec complete_mfa_verification(Sigra.Config.t(), struct(), Sigra.Session.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def complete_mfa_verification(config, user, old_session, opts \\ []) do
    remember_me = Keyword.get(opts, :remember_me, false)
    trust_browser = Keyword.get(opts, :trust_browser, false)
    target_type = if remember_me, do: :remember_me, else: :standard

    {session_store, store_opts} = session_store_and_opts(config, opts)

    # Delete old mfa_pending session (invalidate old token)
    session_store.delete(old_session.hashed_token, store_opts)

    # Create new session with upgraded type
    metadata = %{type: target_type}

    case create_session(config, user, metadata) do
      {:ok, new_session} ->
        Telemetry.event([:sigra, :mfa, :verification_complete], %{}, %{
          user_id: user.id,
          target_type: target_type,
          trust_browser: trust_browser
        })

        {:ok, %{session: new_session, trust_browser: trust_browser}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # -- Private helpers --

  defp session_store_and_opts(config, opts) do
    session_config = config.session
    session_store = Keyword.get(opts, :session_store) || Keyword.get(session_config, :store)
    store_opts = [repo: config.repo, session_schema: Keyword.get(session_config, :session_schema)]
    {session_store, store_opts}
  end

  defp email_taken_error?(%Ecto.Changeset{errors: errors}) do
    Enum.any?(errors, fn
      {:email, {_msg, opts}} -> Keyword.get(opts, :constraint) == :unique
      _ -> false
    end)
  end

  defp handle_valid_login(repo, user, require_confirmation, extra_changes, _opts) do
    if require_confirmation and is_nil(Map.get(user, :confirmed_at)) do
      {:error, :unconfirmed}
    else
      failed_before = Map.get(user, :failed_login_attempts, 0)

      # Reset failed attempts + apply any extra changes (hash upgrade)
      changes = Map.merge(%{failed_login_attempts: 0}, extra_changes)
      changeset = Ecto.Changeset.change(user, changes)

      case repo.update(changeset) do
        {:ok, updated_user} ->
          Telemetry.event([:sigra, :auth, :login, :stop], %{}, %{
            user_id: updated_user.id,
            failed_attempts_before: failed_before
          })

          {:ok, updated_user}

        {:error, _changeset} ->
          # Best-effort update -- still return success for auth
          Telemetry.event([:sigra, :auth, :login, :stop], %{}, %{
            user_id: user.id,
            failed_attempts_before: failed_before
          })

          {:ok, user}
      end
    end
  end

  defp increment_failed_attempts(repo, user) do
    current = Map.get(user, :failed_login_attempts, 0)
    changeset = Ecto.Changeset.change(user, failed_login_attempts: current + 1)

    # Best-effort update
    repo.update(changeset)
  end

  defp rate_limited?(rate_limiter, key, max_requests, window_ms) do
    case rate_limiter.check_rate(key, max_requests, window_ms) do
      {:allow, _count} -> false
      {:deny, _retry_after} -> true
    end
  end

  defp maybe_confirm_user(repo, user) do
    if is_nil(Map.get(user, :confirmed_at)) do
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      changeset = Ecto.Changeset.change(user, confirmed_at: now)

      case repo.update(changeset) do
        {:ok, updated} -> updated
        {:error, _} -> user
      end
    else
      user
    end
  end

  # -- Config-based authenticate helpers (Phase 4 Plan 04) --

  defp handle_valid_login_with_security(config, repo, user, require_confirmation, extra_changes, login_ip) do
    if require_confirmation and is_nil(Map.get(user, :confirmed_at)) do
      {:error, :unconfirmed}
    else
      # Reset lockout state on successful login (D-26)
      updated_user = Sigra.Lockout.reset!(repo, user)

      # Apply any extra changes (hash upgrade)
      updated_user =
        if map_size(extra_changes) > 0 do
          changeset = Ecto.Changeset.change(updated_user, extra_changes)
          case repo.update(changeset) do
            {:ok, u} -> u
            {:error, _} -> updated_user
          end
        else
          updated_user
        end

      Telemetry.event([:sigra, :auth, :login, :stop], %{}, %{
        user_id: updated_user.id,
        failed_attempts_before: Map.get(user, :failed_login_attempts, 0)
      })

      # Check suspicious login (D-44)
      suspicious_details =
        case Sigra.SuspiciousLogin.detect(config, updated_user.id, login_ip || "") do
          {:suspicious, details} ->
            maybe_deliver_suspicious_login_email(config, updated_user, details)
            %{suspicious_login: details}

          :ok ->
            %{}
        end

      # Check MFA enrollment and create appropriate session (D-22, D-27, D-30)
      mfa_config = Map.get(config, :mfa, [])
      mfa_check_fn = Keyword.get(mfa_config, :check_fn)
      mfa_enabled = mfa_check_fn && mfa_check_fn.(updated_user.id)

      session_type = if mfa_enabled, do: :mfa_pending, else: :standard
      metadata = %{type: session_type, ip: login_ip}

      case create_session(config, updated_user, metadata) do
        {:ok, session} ->
          result = Map.merge(suspicious_details, %{session: session})
          result = if mfa_enabled, do: Map.put(result, :mfa_required, true), else: result
          {:ok, updated_user, result}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp handle_failed_login_with_lockout(config, repo, user, login_ip, lockout_opts) do
    threshold = Keyword.get(lockout_opts, :threshold, 5)
    updated_user = Sigra.Lockout.increment!(repo, user, lockout_opts)
    new_count = updated_user.failed_login_attempts

    if new_count >= threshold do
      # Lockout just triggered
      Telemetry.event([:sigra, :security, :lockout], %{}, %{
        user_id: user.id,
        ip: login_ip,
        reason: :threshold_reached
      })

      maybe_deliver_lockout_email(config, user, %{ip: login_ip})
      {:error, :account_locked}
    else
      {:error, :invalid_credentials}
    end
  end

  defp maybe_deliver_suspicious_login_email(config, user, details) do
    notify? = Keyword.get(config.suspicious_login, :notify, true)
    email_module = config.email_module
    mailer = config.mailer

    if notify? && email_module && mailer do
      email = email_module.suspicious_login_email(user, details)
      mailer.deliver(email.to, email.subject, email.body)
    end
  end

  defp maybe_deliver_lockout_email(config, user, details) do
    notify? = Keyword.get(config.lockout, :notify, true)
    email_module = config.email_module
    mailer = config.mailer

    if notify? && email_module && mailer do
      email = email_module.lockout_notification_email(user, details)
      mailer.deliver(email.to, email.subject, email.body)
    end
  end

  # -- API Token Management (Phase 7 Plan 03) --

  @doc """
  Creates an API token for the user.

  Returns `{:ok, raw_key, token}` on success. Sends a notification email
  on successful creation if the email module is configured (D-62).

  ## Parameters

  - `config` - A `%Sigra.Config{}` struct
  - `user` - The user struct (must have an `:id` field)
  - `attrs` - A map with `:name`, `:scopes`, and optional `:expires_at`
  """
  @doc since: "0.7.0"
  @spec create_api_token(Sigra.Config.t(), struct(), map()) ::
          {:ok, String.t(), struct()} | {:error, term()}
  def create_api_token(config, user, attrs) do
    result = Sigra.APIToken.create(config, user, attrs)

    case result do
      {:ok, _raw_key, token} ->
        maybe_send_api_token_email(config, user, token)
        result

      _ ->
        result
    end
  end

  @doc """
  Revokes an API token by ID.
  """
  @doc since: "0.7.0"
  @spec revoke_api_token(Sigra.Config.t(), term()) :: {:ok, struct()} | {:error, :not_found}
  def revoke_api_token(config, token_id) do
    Sigra.APIToken.revoke(config, token_id)
  end

  @doc """
  Revokes all active API tokens for a user.
  """
  @doc since: "0.7.0"
  @spec revoke_all_api_tokens(Sigra.Config.t(), struct()) :: {:ok, non_neg_integer()}
  def revoke_all_api_tokens(config, user) do
    Sigra.APIToken.revoke_all(config, user)
  end

  @doc """
  Lists active API tokens for a user with cursor pagination.
  """
  @doc since: "0.7.0"
  @spec list_api_tokens(Sigra.Config.t(), term(), keyword()) :: {[struct()], String.t() | nil}
  def list_api_tokens(config, user_id, opts \\ []) do
    Sigra.APIToken.list_active(config, user_id, opts)
  end

  @doc """
  Returns all registered API token scopes.
  """
  @doc since: "0.7.0"
  @spec list_api_scopes(Sigra.Config.t()) :: [String.t()]
  def list_api_scopes(config) do
    Sigra.APIToken.list_scopes(config)
  end

  # -- JWT (Phase 7 Plan 03) --

  @doc """
  Generates JWT access + refresh tokens for a user.
  """
  @doc since: "0.7.0"
  @spec generate_jwt_tokens(Sigra.Config.t(), struct(), [String.t()]) ::
          {:ok, map()} | {:error, term()}
  def generate_jwt_tokens(config, user, scopes) do
    Sigra.JWT.generate_tokens(config, user, scopes)
  end

  @doc """
  Refreshes JWT tokens using a refresh token.
  """
  @doc since: "0.7.0"
  @spec refresh_jwt(Sigra.Config.t(), String.t()) ::
          {:ok, map()} | {:error, :invalid_token | :token_expired | :reuse_detected}
  def refresh_jwt(config, raw_refresh_token) do
    Sigra.JWT.refresh(config, raw_refresh_token)
  end

  @doc """
  Revokes a JWT refresh token.
  """
  @doc since: "0.7.0"
  @spec revoke_jwt_refresh(Sigra.Config.t(), String.t()) :: :ok | {:error, :invalid_token}
  def revoke_jwt_refresh(config, raw_refresh_token) do
    Sigra.JWT.revoke_refresh(config, raw_refresh_token)
  end

  defp maybe_send_api_token_email(config, user, token) do
    if config.email_module && config.mailer do
      try do
        email = config.email_module.api_token_created_email(user, token)
        config.mailer.deliver(email.to, email.subject, email.body)
      rescue
        UndefinedFunctionError -> :ok
      end
    end
  end

  # -- Account Lifecycle (Phase 8 Plan 03) --

  @doc """
  Request an email change for the user.

  Generates a verification token for the new email address and returns
  it for delivery. The email is not changed until confirmed via
  `confirm_email_change/3`.
  """
  @doc since: "0.8.0"
  @spec request_email_change(Sigra.Config.t(), struct(), String.t(), keyword()) ::
          {:ok, struct(), String.t()} | {:error, term()}
  def request_email_change(config, user, new_email, opts \\ []) do
    repo = config.repo
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)

    merged_opts =
      Keyword.merge(
        [
          changeset_fn: Keyword.fetch!(opts, :changeset_fn),
          user_token_schema: user_token_schema,
          secret_key_base: config.secret_key_base,
          config: config,
          build_email_token_fn: fn user, context ->
            user_token_schema.build_email_token(user, context)
          end,
          token_query_fn: fn user, contexts ->
            user_token_schema.by_user_and_contexts_query(user, contexts)
          end,
          email_taken_fn: fn repo, email ->
            repo.get_by(config.user_schema, email: email) != nil
          end
        ],
        opts
      )

    Sigra.Account.request_email_change(repo, user, new_email, merged_opts)
  end

  @doc """
  Confirm an email change via token.

  Verifies the HMAC-signed token, updates the user's email, and
  invalidates all existing sessions (forcing re-authentication).
  """
  @doc since: "0.8.0"
  @spec confirm_email_change(Sigra.Config.t(), String.t(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def confirm_email_change(config, encoded_token, opts \\ []) do
    repo = config.repo

    merged_opts =
      Keyword.merge(
        [
          user_token_schema: Keyword.fetch!(opts, :user_token_schema),
          user_schema: config.user_schema,
          session_store: get_session_store(config),
          config: config
        ],
        opts
      )

    Sigra.Account.confirm_email_change(repo, encoded_token, merged_opts)
  end

  @doc """
  Cancel a pending email change.

  Clears the `pending_email` field and deletes the email change token.
  """
  @doc since: "0.8.0"
  @spec cancel_email_change(Sigra.Config.t(), struct(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def cancel_email_change(config, user, opts \\ []) do
    repo = config.repo
    user_token_schema = Keyword.fetch!(opts, :user_token_schema)

    merged_opts =
      Keyword.merge(
        [
          changeset_fn: Keyword.fetch!(opts, :changeset_fn),
          user_token_schema: user_token_schema,
          token_query_fn: fn user, contexts ->
            user_token_schema.by_user_and_contexts_query(user, contexts)
          end
        ],
        opts
      )

    Sigra.Account.cancel_email_change(repo, user, merged_opts)
  end

  @doc """
  Change password with current password verification.

  Verifies the current password, updates to the new password, and
  invalidates all sessions except the current one.
  """
  @doc since: "0.8.0"
  @spec change_password(Sigra.Config.t(), struct(), String.t(), map(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def change_password(config, user, current_password, attrs, opts \\ []) do
    repo = config.repo

    merged_opts =
      Keyword.merge(
        [
          changeset_fn: Keyword.fetch!(opts, :changeset_fn),
          session_store: get_session_store(config),
          config: config
        ],
        opts
      )

    Sigra.Account.change_password(repo, user, current_password, attrs, merged_opts)
  end

  @doc """
  Set password for OAuth-only user.

  Allows users who registered via OAuth (no password set) to add a
  password to their account. Requires sudo mode.
  """
  @doc since: "0.8.0"
  @spec set_password(Sigra.Config.t(), struct(), map(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def set_password(config, user, attrs, opts \\ []) do
    repo = config.repo

    merged_opts =
      Keyword.merge(
        [
          changeset_fn: Keyword.fetch!(opts, :changeset_fn),
          config: config
        ],
        opts
      )

    Sigra.Account.set_password(repo, user, attrs, merged_opts)
  end

  @doc """
  Schedule account deletion with grace period.

  Immediately deactivates the account (revokes sessions/tokens) and
  schedules final deletion after the configured grace period.
  """
  @doc since: "0.8.0"
  @spec schedule_deletion(Sigra.Config.t(), struct(), keyword()) ::
          {:ok, struct(), DateTime.t()} | {:error, term()}
  def schedule_deletion(config, user, opts \\ []) do
    repo = config.repo

    merged_opts =
      Keyword.merge(
        [
          config: config,
          session_store: get_session_store(config),
          user_token_schema: Keyword.fetch!(opts, :user_token_schema)
        ],
        opts
      )

    Sigra.Account.schedule_deletion(repo, user, merged_opts)
  end

  @doc """
  Cancel scheduled account deletion.

  Clears deletion timestamps and reactivates the account. The user
  must re-authenticate (all sessions were revoked on scheduling).
  """
  @doc since: "0.8.0"
  @spec cancel_deletion(Sigra.Config.t(), struct(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def cancel_deletion(config, user, opts \\ []) do
    Sigra.Account.cancel_deletion(config.repo, user, opts)
  end

  @doc """
  Execute account deletion (called by Oban worker).

  Applies the configured deletion strategy (soft_delete, hard_delete,
  or anonymize) to finalize the account removal.
  """
  @doc since: "0.8.0"
  @spec execute_deletion(Sigra.Config.t(), struct(), keyword()) ::
          {:ok, atom()} | {:error, term()}
  def execute_deletion(config, user, opts \\ []) do
    Sigra.Account.execute_deletion(config.repo, user, opts)
  end

  # -- Private helpers --

  defp get_session_store(config) do
    Keyword.get(config.session, :store, Sigra.SessionStores.Ecto)
  end

  # Rejection sampling to eliminate modulo bias. A 4-byte unsigned integer
  # has max value 4,294,967,295. Values >= floor(2^32 / range) * range are
  # rejected to ensure uniform distribution across [0, range).
  @max_uint32 4_294_967_296
  defp uniform_random(range) when range > 0 do
    limit = div(@max_uint32, range) * range

    n =
      :crypto.strong_rand_bytes(4)
      |> :binary.decode_unsigned()

    if n >= limit do
      uniform_random(range)
    else
      rem(n, range)
    end
  end
end
