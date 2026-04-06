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

      rate_limiter && rate_limited?(rate_limiter, normalized_email, max_requests, window_ms) ->
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

  defp rate_limited?(rate_limiter, email, max_requests, window_ms) do
    case rate_limiter.check_rate("magic_link:#{email}", max_requests, window_ms) do
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
