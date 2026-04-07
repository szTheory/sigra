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
  @spec authenticate(module(), map(), keyword()) ::
          {:ok, struct()} | {:error, :invalid_credentials | :unconfirmed}
  def authenticate(repo, params, opts \\ []) do
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

    # Generate 6-digit code (100000-999999)
    code = (:rand.uniform(900_000) + 99_999) |> Integer.to_string()
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

  # -- Private helpers --

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
end
