defmodule Sigra.Testing do
  @moduledoc """
  Test assertion helpers for Sigra authentication.

  This module provides convenience assertions for testing authentication
  flows in your application. Import it in your test cases:

      use ExUnit.Case
      import Sigra.Testing

  ## Available Assertions

  - `assert_password_hashed/1` - verifies a user has a properly hashed password
  - `assert_session_created/1` - verifies a session was created on a conn (stub)
  - `assert_token_sent/2` - verifies a token email was sent (stub)

  Stub functions will be filled in by later phases as the corresponding
  features are implemented.
  """

  # --- Core Assertions ---

  @doc """
  Asserts that the given user struct has a properly hashed password.

  Checks that the `hashed_password` field starts with `"$argon2id$"`,
  indicating it was hashed with the Argon2id algorithm.

  ## Examples

      user = %{hashed_password: Sigra.Crypto.hash_password("password")}
      assert_password_hashed(user)

  """
  @doc since: "0.1.0"
  @spec assert_password_hashed(map()) :: true
  def assert_password_hashed(%{hashed_password: hashed}) when is_binary(hashed) do
    if String.starts_with?(hashed, "$argon2id$") do
      true
    else
      raise ExUnit.AssertionError,
        message: "Expected hashed_password to start with \"$argon2id$\", got: #{inspect(hashed)}"
    end
  end

  def assert_password_hashed(user) do
    raise ExUnit.AssertionError,
      message:
        "Expected user to have a binary :hashed_password field, got: #{inspect(user, limit: 50)}"
  end

  @doc """
  Asserts that a session was created on the given conn.

  > #### Stub {: .warning}
  >
  > This function is a stub that will be filled in by later phases
  > when session management is fully implemented.
  """
  @doc since: "0.1.0"
  @spec assert_session_created(term()) :: true
  def assert_session_created(_conn) do
    # Stub: will check conn for session token in assigns once session
    # management is implemented in later phases.
    true
  end

  @doc """
  Asserts that a token email was sent to the given address for the given context.

  Delegates to `assert_email_sent/1` with `:to` set to the given address.
  """
  @doc since: "0.1.0"
  @spec assert_token_sent(String.t(), atom()) :: true
  def assert_token_sent(to, _context) do
    assert_email_sent(to: to)
  end

  # --- Email ---

  @doc """
  Asserts that an email was sent (via Swoosh test adapter).

  Checks the Swoosh test mailbox for an email matching the given criteria.
  Uses `Swoosh.TestAssertions` under the hood when available.

  ## Options

  - `:to` - Expected recipient email
  - `:subject` - Expected subject (substring match)
  """
  @doc since: "0.3.0"
  @spec assert_email_sent(keyword()) :: true
  def assert_email_sent(opts \\ []) do
    to = Keyword.get(opts, :to)
    subject = Keyword.get(opts, :subject)

    if Code.ensure_loaded?(Swoosh.TestAssertions) do
      criteria = []
      criteria = if to, do: [{:to, [{nil, to}]} | criteria], else: criteria
      criteria = if subject, do: [{:subject, subject} | criteria], else: criteria
      apply(Swoosh.TestAssertions, :assert_email_sent, [criteria])
    else
      raise "Swoosh.TestAssertions not available. Add {:swoosh, \"~> 1.5\"} to test deps."
    end
  end

  @doc """
  Extracts the confirmation token from a confirmation URL string.

  Parses `/users/confirm/<token>` and returns the token portion.

  ## Examples

      iex> Sigra.Testing.extract_confirmation_token("https://example.com/users/confirm/abc123")
      "abc123"

  """
  @doc since: "0.3.0"
  @spec extract_confirmation_token(String.t()) :: String.t()
  def extract_confirmation_token(url) when is_binary(url) do
    uri = URI.parse(url)
    uri.path |> String.split("/") |> List.last()
  end

  @doc """
  Extracts the reset password token from a reset URL string.

  Parses `/users/reset-password/<token>` and returns the token portion.

  ## Examples

      iex> Sigra.Testing.extract_reset_token("https://example.com/users/reset-password/xyz789")
      "xyz789"

  """
  @doc since: "0.3.0"
  @spec extract_reset_token(String.t()) :: String.t()
  def extract_reset_token(url) when is_binary(url) do
    uri = URI.parse(url)
    uri.path |> String.split("/") |> List.last()
  end

  # --- Lockout ---

  @doc """
  Simulate a locked out user by setting failed_login_attempts to threshold.

  Returns the updated user struct. Requires a repo module that supports
  `update!/1`.

  ## Options

    * `:threshold` - The lockout threshold to simulate. Default: `5`.

  ## Examples

      locked_user = Sigra.Testing.simulate_lockout(MyApp.Repo, user)
      assert Sigra.Lockout.locked?(locked_user)

  """
  @doc since: "0.4.0"
  @spec simulate_lockout(module(), struct(), keyword()) :: struct()
  def simulate_lockout(repo, user, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 5)

    user
    |> Ecto.Changeset.change(%{failed_login_attempts: threshold, locked_at: DateTime.utc_now()})
    |> repo.update!()
  end

  @doc """
  Assert rate limited response (429 status with Retry-After header).

  Checks that the connection has a 429 status code and a non-empty
  `retry-after` response header.

  ## Examples

      conn = post(conn, "/login", %{email: "test@example.com", password: "wrong"})
      Sigra.Testing.assert_rate_limited(conn)

  """
  @doc since: "0.4.0"
  @spec assert_rate_limited(Plug.Conn.t()) :: true
  def assert_rate_limited(conn) do
    unless conn.status == 429 do
      raise ExUnit.AssertionError,
        message: "Expected status 429, got: #{conn.status}"
    end

    unless Plug.Conn.get_resp_header(conn, "retry-after") != [] do
      raise ExUnit.AssertionError,
        message: "Expected retry-after header to be present"
    end

    true
  end

  @doc """
  Executes the given function with a test mailer configured.

  > #### Stub {: .warning}
  >
  > This function is a stub that will be filled in by later phases
  > when the Mox-based mailer testing infrastructure is implemented.
  """
  @doc since: "0.1.0"
  @spec with_test_mailer((-> term())) :: term()
  def with_test_mailer(fun) when is_function(fun, 0) do
    # Stub: will set up Mox-based mailer capture once mailer
    # integration is implemented in later phases.
    fun.()
  end

  # --- MFA ---
  # -- MFA Testing Helpers (Phase 6) --

  @doc """
  Creates a fully enrolled MFA credential for the user.

  Generates a real TOTP secret, creates the credential in the DB,
  and generates backup codes. Returns the secret, credential, and
  raw formatted backup codes.

  ## Options

    * `:config` - `%Sigra.Config{}` (required)
    * `:mfa_credential_schema` - MFA credential schema module (required)
    * `:backup_code_schema` - Backup code schema module (required)
    * `:backup_code_count` - Number of backup codes (default: 8)

  ## Returns

      %{secret: raw_secret, credential: credential, backup_codes: [formatted_codes]}

  """
  @doc since: "0.6.0"
  @spec setup_totp(struct(), keyword()) :: map()
  def setup_totp(user, opts \\ []) do
    config = Keyword.fetch!(opts, :config)
    mfa_credential_schema = Keyword.fetch!(opts, :mfa_credential_schema)
    backup_code_schema = Keyword.fetch!(opts, :backup_code_schema)
    backup_count = Keyword.get(opts, :backup_code_count, 8)

    raw_secret = NimbleTOTP.secret()
    now = DateTime.utc_now()

    credential_params = %{
      user_id: user.id,
      type: "totp",
      encrypted_secret: raw_secret,
      last_verified_step: 0,
      failed_attempts: 0,
      locked_until: nil,
      enabled_at: now
    }

    # Use cast/4 so cloak_ecto's Encrypted.Binary type invokes dump/1
    # and encrypts the secret before storage.
    {:ok, db_credential} =
      mfa_credential_schema.__struct__()
      |> Ecto.Changeset.cast(credential_params, [
        :user_id,
        :type,
        :encrypted_secret,
        :last_verified_step,
        :failed_attempts,
        :locked_until,
        :enabled_at
      ])
      |> config.repo.insert()

    codes = Sigra.MFA.BackupCodes.generate(backup_count)

    entries =
      Enum.map(codes, fn {_formatted, hashed} ->
        %{
          user_id: user.id,
          hashed_code: hashed,
          used_at: nil,
          inserted_at: now,
          updated_at: now
        }
      end)

    config.repo.insert_all(backup_code_schema, entries)

    credential = Sigra.MFA.Credential.from_schema(db_credential)
    formatted_codes = Enum.map(codes, &elem(&1, 0))

    %{secret: raw_secret, credential: credential, backup_codes: formatted_codes}
  end

  @doc """
  Generates a valid TOTP code for the given raw secret.

  Uses `NimbleTOTP.verification_code/1` to produce a real 6-digit code
  valid for the current time window.

  ## Examples

      code = Sigra.Testing.generate_totp_code(raw_secret)
      assert String.length(code) == 6

  """
  @doc since: "0.6.0"
  @spec generate_totp_code(binary()) :: String.t()
  def generate_totp_code(secret) when is_binary(secret) do
    NimbleTOTP.verification_code(secret)
  end

  @doc """
  Generates backup codes for a user and stores hashes in the DB.

  Returns a list of raw formatted codes (shown once to user).

  ## Options

    * `:config` - `%Sigra.Config{}` (required)
    * `:backup_code_schema` - Backup code schema module (required)
    * `:count` - Number of codes to generate (default: 8)
  """
  @doc since: "0.6.0"
  @spec create_backup_codes(struct(), keyword()) :: [String.t()]
  def create_backup_codes(user, opts \\ []) do
    config = Keyword.fetch!(opts, :config)
    backup_code_schema = Keyword.fetch!(opts, :backup_code_schema)
    count = Keyword.get(opts, :count, 8)

    codes = Sigra.MFA.BackupCodes.generate(count)
    now = DateTime.utc_now()

    entries =
      Enum.map(codes, fn {_formatted, hashed} ->
        %{
          user_id: user.id,
          hashed_code: hashed,
          used_at: nil,
          inserted_at: now,
          updated_at: now
        }
      end)

    config.repo.insert_all(backup_code_schema, entries)
    Enum.map(codes, &elem(&1, 0))
  end

  @doc """
  Marks user's session as MFA-completed without requiring code entry.

  For tests that don't care about the MFA verification flow. Returns
  a conn with the session type set to `:standard`.

  ## Examples

      conn = Sigra.Testing.bypass_mfa(conn)

  """
  @doc since: "0.6.0"
  @spec bypass_mfa(Plug.Conn.t()) :: Plug.Conn.t()
  def bypass_mfa(conn) do
    Plug.Conn.put_session(conn, :sigra_session_type, :standard)
  end

  @doc """
  Simulates an MFA lockout by setting failed_attempts to threshold.

  Sets `failed_attempts` to the lockout threshold and `locked_until`
  to 15 minutes from now on the user's MFA credential.

  ## Options

    * `:config` - `%Sigra.Config{}` (required)
    * `:mfa_credential_schema` - MFA credential schema module (required)
    * `:threshold` - Lockout threshold (default: 5)
    * `:duration` - Lockout duration in seconds (default: 900)
  """
  @doc since: "0.6.0"
  @spec simulate_mfa_lockout(struct(), keyword()) :: :ok
  def simulate_mfa_lockout(user, opts \\ []) do
    config = Keyword.fetch!(opts, :config)
    mfa_credential_schema = Keyword.fetch!(opts, :mfa_credential_schema)
    threshold = Keyword.get(opts, :threshold, 5)
    duration = Keyword.get(opts, :duration, 900)

    import Ecto.Query

    locked_until = DateTime.add(DateTime.utc_now(), duration, :second)

    from(c in mfa_credential_schema,
      where: c.user_id == ^user.id,
      update: [
        set: [
          failed_attempts: ^threshold,
          locked_until: ^locked_until
        ]
      ]
    )
    |> config.repo.update_all([])

    :ok
  end

  @doc """
  Asserts that the user has MFA enabled (has credential with non-nil enabled_at).

  Raises `ExUnit.AssertionError` on failure.

  ## Options

    * `:config` - `%Sigra.Config{}` (required)
    * `:mfa_credential_schema` - MFA credential schema module (required)
  """
  @doc since: "0.6.0"
  @spec assert_mfa_enabled(struct(), keyword()) :: true
  def assert_mfa_enabled(user, opts \\ []) do
    config = Keyword.fetch!(opts, :config)
    mfa_credential_schema = Keyword.fetch!(opts, :mfa_credential_schema)

    import Ecto.Query

    count =
      from(c in mfa_credential_schema,
        where: c.user_id == ^user.id and not is_nil(c.enabled_at),
        select: count(c.id)
      )
      |> config.repo.one()

    if count > 0 do
      true
    else
      raise ExUnit.AssertionError,
        message: "Expected user #{inspect(user.id)} to have MFA enabled, but no enabled credential found"
    end
  end

  @doc """
  Asserts that the user does not have MFA enabled.

  Raises `ExUnit.AssertionError` on failure.

  ## Options

    * `:config` - `%Sigra.Config{}` (required)
    * `:mfa_credential_schema` - MFA credential schema module (required)
  """
  @doc since: "0.6.0"
  @spec assert_mfa_disabled(struct(), keyword()) :: true
  def assert_mfa_disabled(user, opts \\ []) do
    config = Keyword.fetch!(opts, :config)
    mfa_credential_schema = Keyword.fetch!(opts, :mfa_credential_schema)

    import Ecto.Query

    count =
      from(c in mfa_credential_schema,
        where: c.user_id == ^user.id and not is_nil(c.enabled_at),
        select: count(c.id)
      )
      |> config.repo.one()

    if count == 0 do
      true
    else
      raise ExUnit.AssertionError,
        message: "Expected user #{inspect(user.id)} to have MFA disabled, but found #{count} enabled credential(s)"
    end
  end

  @doc """
  Sets the `_sigra_mfa_trust` cookie on the conn for the given user.

  Simulates a trusted browser for MFA bypass in tests.

  ## Options

    * `:secret_key_base` - The app's secret key base (default: generates a test key)
    * `:trust_epoch` - The user's trust epoch (default: 0)
    * `:trust_ttl` - Trust cookie TTL in seconds (default: 2_592_000 = 30 days)
  """
  @doc since: "0.6.0"
  @spec trust_browser(Plug.Conn.t(), struct(), keyword()) :: Plug.Conn.t()
  def trust_browser(conn, user, opts \\ []) do
    secret_key_base = Keyword.get(opts, :secret_key_base, conn.secret_key_base || generate_test_secret())
    trust_epoch = Keyword.get(opts, :trust_epoch, 0)
    trust_ttl = Keyword.get(opts, :trust_ttl, 2_592_000)

    config = Keyword.get(opts, :config, %Sigra.Config{})

    cookie_value = Sigra.MFA.Trust.sign(secret_key_base, user.id, trust_epoch, trust_ttl)

    Plug.Conn.put_resp_cookie(
      conn,
      Sigra.MFA.Trust.cookie_name(),
      cookie_value,
      Sigra.MFA.Trust.cookie_opts(config) ++ [max_age: trust_ttl]
    )
  end

  defp generate_test_secret do
    :crypto.strong_rand_bytes(64) |> Base.encode64()
  end

  # --- API Tokens ---
  # -- API Token Testing Helpers (Phase 7) --

  @doc """
  Creates an API token and returns `{raw_key, token_record}`.

  ## Options

    * `:name` - Token name (default: `"test-token"`)
    * `:scopes` - List of scope strings (default: `["*"]`)
    * `:expires_at` - Expiration datetime (default: `nil`)
  """
  @doc since: "0.7.0"
  @spec create_api_token(Sigra.Config.t(), struct(), keyword()) :: {String.t(), struct()}
  def create_api_token(config, user, opts \\ []) do
    attrs = %{
      name: Keyword.get(opts, :name, "test-token"),
      scopes: Keyword.get(opts, :scopes, ["*"]),
      expires_at: Keyword.get(opts, :expires_at, nil)
    }

    case Sigra.APIToken.create(config, user, attrs) do
      {:ok, raw_key, token} -> {raw_key, token}
      {:error, reason} -> raise "Failed to create test API token: #{inspect(reason)}"
    end
  end

  @doc """
  Adds a Bearer token header to a conn for API testing.

  ## Examples

      conn = Sigra.Testing.put_bearer_token(conn, raw_token)

  """
  @doc since: "0.7.0"
  @spec put_bearer_token(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def put_bearer_token(conn, raw_token) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{raw_token}")
  end

  @doc """
  Alias for `put_bearer_token/2`.
  """
  @doc since: "0.7.0"
  @spec put_api_token(Plug.Conn.t(), String.t()) :: Plug.Conn.t()
  def put_api_token(conn, raw_token), do: put_bearer_token(conn, raw_token)

  @doc """
  Asserts that a token has been revoked.

  Raises `ExUnit.AssertionError` if the token's `revoked_at` is nil.
  """
  @doc since: "0.7.0"
  @spec assert_token_revoked(Sigra.Config.t(), term()) :: true
  def assert_token_revoked(config, token_id) do
    schema = Keyword.get(config.api_token, :api_token_schema)
    token = config.repo.get!(schema, token_id)

    if token.revoked_at != nil do
      true
    else
      raise ExUnit.AssertionError,
        message: "Expected token #{inspect(token_id)} to be revoked"
    end
  end

  @doc """
  Asserts that a conn received a 403 insufficient scope response.

  Checks that the status is 403 and the connection is halted.
  """
  @doc since: "0.7.0"
  @spec assert_scope_denied(Plug.Conn.t()) :: true
  def assert_scope_denied(conn) do
    unless conn.status == 403 do
      raise ExUnit.AssertionError,
        message: "Expected 403 Forbidden, got #{conn.status}"
    end

    unless conn.halted do
      raise ExUnit.AssertionError,
        message: "Expected conn to be halted"
    end

    true
  end

  @doc """
  Creates an expired API token fixture.
  """
  @doc since: "0.7.0"
  @spec expired_api_token_fixture(Sigra.Config.t(), struct(), keyword()) ::
          {String.t(), struct()}
  def expired_api_token_fixture(config, user, opts \\ []) do
    expired_at = DateTime.add(DateTime.utc_now(), -3600, :second)
    create_api_token(config, user, Keyword.put(opts, :expires_at, expired_at))
  end

  @doc """
  Creates a revoked API token fixture.
  """
  @doc since: "0.7.0"
  @spec revoked_api_token_fixture(Sigra.Config.t(), struct(), keyword()) ::
          {String.t(), struct()}
  def revoked_api_token_fixture(config, user, opts \\ []) do
    {raw_key, token} = create_api_token(config, user, opts)
    {:ok, revoked} = Sigra.APIToken.revoke(config, token.id)
    {raw_key, revoked}
  end

  @doc """
  Creates a scoped API token fixture.
  """
  @doc since: "0.7.0"
  @spec scoped_api_token_fixture(Sigra.Config.t(), struct(), [String.t()], keyword()) ::
          {String.t(), struct()}
  def scoped_api_token_fixture(config, user, scopes, opts \\ []) do
    create_api_token(config, user, Keyword.put(opts, :scopes, scopes))
  end

  # -- JWT Testing Helpers (Phase 7) --

  @doc """
  Generates a JWT access token for testing.

  ## Options

    * `:scopes` - List of scope strings (default: `["*"]`)
  """
  @doc since: "0.7.0"
  @spec generate_jwt(Sigra.Config.t(), struct(), keyword()) :: String.t()
  def generate_jwt(config, user, opts \\ []) do
    scopes = Keyword.get(opts, :scopes, ["*"])
    {:ok, tokens} = Sigra.JWT.generate_tokens(config, user, scopes)
    tokens.access_token
  end

  @doc """
  Generates an expired JWT for testing.

  Uses Joken directly to create a token with a past expiry timestamp.

  ## Options

    * `:scopes` - List of scope strings (default: `["*"]`)
  """
  @doc since: "0.7.0"
  @spec expired_jwt(Sigra.Config.t(), struct(), keyword()) :: String.t()
  def expired_jwt(config, user, opts \\ []) do
    scopes = Keyword.get(opts, :scopes, ["*"])
    signer = Sigra.JWT.Signer.create_signer(config)
    now = DateTime.utc_now() |> DateTime.to_unix()

    claims = %{
      "sub" => to_string(user.id),
      "iat" => now - 1000,
      "exp" => now - 1,
      "jti" => Ecto.UUID.generate(),
      "iss" => to_string(config.otp_app),
      "scopes" => scopes,
      "epoch" => Map.get(user, :token_epoch, 0)
    }

    {:ok, token, _} = Joken.encode_and_sign(claims, signer)
    token
  end

  @doc """
  Generates a JWT with specific scopes for testing.
  """
  @doc since: "0.7.0"
  @spec jwt_with_scopes(Sigra.Config.t(), struct(), [String.t()]) :: String.t()
  def jwt_with_scopes(config, user, scopes) do
    generate_jwt(config, user, scopes: scopes)
  end

  # --- Account Lifecycle ---
  # -- Account Lifecycle Testing Helpers (Phase 8) --

  @doc """
  Creates a user fixture with scheduled deletion.

  Sets `deleted_at` and `scheduled_deletion_at` on the user, plus
  stores the original email in `original_email` for restore on cancel.

  ## Options

    * `:grace_period_days` - Days until permanent deletion (default: 14)
  """
  @doc since: "0.8.0"
  @spec scheduled_deletion_fixture(module(), struct(), keyword()) :: struct()
  def scheduled_deletion_fixture(repo, user, opts \\ []) do
    grace_days = Keyword.get(opts, :grace_period_days, 14)
    now = DateTime.utc_now()
    scheduled_at = DateTime.add(now, grace_days * 86_400, :second)

    user
    |> Ecto.Changeset.change(%{
      deleted_at: now,
      scheduled_deletion_at: scheduled_at,
      original_email: user.email
    })
    |> repo.update!()
  end

  @doc """
  Creates a user fixture in fully deleted/anonymized state.

  Sets `deleted_at` to a past timestamp and anonymizes the email.
  """
  @doc since: "0.8.0"
  @spec deleted_user_fixture(module(), struct()) :: struct()
  def deleted_user_fixture(repo, user) do
    past = DateTime.add(DateTime.utc_now(), -30 * 86_400, :second)

    user
    |> Ecto.Changeset.change(%{
      deleted_at: past,
      scheduled_deletion_at: past,
      original_email: user.email,
      email: "deleted_#{user.id}@deleted.invalid",
      hashed_password: nil
    })
    |> repo.update!()
  end

  @doc """
  Asserts that the user account is scheduled for deletion.

  Raises `ExUnit.AssertionError` if `deleted_at` or `scheduled_deletion_at` is nil.
  """
  @doc since: "0.8.0"
  @spec assert_deletion_scheduled(struct()) :: true
  def assert_deletion_scheduled(user) do
    unless user.deleted_at do
      raise ExUnit.AssertionError,
        message: "Expected user #{inspect(user.id)} to have deleted_at set"
    end

    unless user.scheduled_deletion_at do
      raise ExUnit.AssertionError,
        message: "Expected user #{inspect(user.id)} to have scheduled_deletion_at set"
    end

    true
  end

  @doc """
  Asserts that the user account deletion was cancelled.

  Raises `ExUnit.AssertionError` if `deleted_at` or `scheduled_deletion_at` is not nil.
  """
  @doc since: "0.8.0"
  @spec assert_deletion_cancelled(struct()) :: true
  def assert_deletion_cancelled(user) do
    if user.deleted_at do
      raise ExUnit.AssertionError,
        message: "Expected user #{inspect(user.id)} to have deleted_at cleared, got: #{inspect(user.deleted_at)}"
    end

    if user.scheduled_deletion_at do
      raise ExUnit.AssertionError,
        message: "Expected user #{inspect(user.id)} to have scheduled_deletion_at cleared"
    end

    true
  end

  @doc """
  Asserts that the user account was permanently deleted or anonymized.

  Checks that the user either no longer exists or has an anonymized email.
  """
  @doc since: "0.8.0"
  @spec assert_account_deleted(module(), module(), term()) :: true
  def assert_account_deleted(repo, user_schema, user_id) do
    case repo.get(user_schema, user_id) do
      nil ->
        true

      user ->
        if String.starts_with?(user.email, "deleted_") do
          true
        else
          raise ExUnit.AssertionError,
            message: "Expected user #{inspect(user_id)} to be deleted or anonymized, but found active email: #{user.email}"
        end
    end
  end

  @doc """
  Simulates grace period expiry by setting `scheduled_deletion_at` to a past timestamp.

  Useful for testing the Oban deletion worker.
  """
  @doc since: "0.8.0"
  @spec simulate_grace_period_expiry(module(), struct()) :: struct()
  def simulate_grace_period_expiry(repo, user) do
    past = DateTime.add(DateTime.utc_now(), -86_400, :second)

    user
    |> Ecto.Changeset.change(%{scheduled_deletion_at: past})
    |> repo.update!()
  end

  @doc """
  Creates a user fixture with the force password change flag set.

  Sets `must_change_password` to `true` on the user.
  """
  @doc since: "0.8.0"
  @spec force_password_change_fixture(module(), struct()) :: struct()
  def force_password_change_fixture(repo, user) do
    user
    |> Ecto.Changeset.change(%{must_change_password: true})
    |> repo.update!()
  end

  @doc """
  Asserts that the user's password was recently changed.

  Checks that `password_changed_at` is set and within the last 60 seconds.
  """
  @doc since: "0.8.0"
  @spec assert_password_changed(struct()) :: true
  def assert_password_changed(user) do
    unless user.password_changed_at do
      raise ExUnit.AssertionError,
        message: "Expected user #{inspect(user.id)} to have password_changed_at set"
    end

    seconds_ago = DateTime.diff(DateTime.utc_now(), user.password_changed_at, :second)

    if seconds_ago > 60 do
      raise ExUnit.AssertionError,
        message: "Expected password_changed_at to be recent (within 60s), but it was #{seconds_ago}s ago"
    end

    true
  end

  @doc """
  Asserts that all sessions except the optionally specified one were invalidated.

  ## Options

    * `:except_token` - A session token to exclude from the count (the current session)
    * `:session_schema` - The session schema module (required)
  """
  @doc since: "0.8.0"
  @spec assert_sessions_invalidated(module(), struct(), keyword()) :: true
  def assert_sessions_invalidated(repo, user, opts \\ []) do
    session_schema = Keyword.fetch!(opts, :session_schema)
    except_token = Keyword.get(opts, :except_token)

    import Ecto.Query

    query =
      from(s in session_schema,
        where: s.user_id == ^user.id,
        select: count(s.id)
      )

    count = repo.one(query)

    expected = if except_token, do: 1, else: 0

    if count > expected do
      raise ExUnit.AssertionError,
        message: "Expected #{expected} session(s) remaining, but found #{count}"
    end

    true
  end

  # --- Hooks ---

  @doc """
  Temporarily overrides a hook for a test block.

  Swaps the hook configuration for the given operation, runs the test
  function, and restores the original configuration afterward.

  ## Examples

      Sigra.Testing.with_hook(:on_delete, {MyApp.TestHooks, :on_delete}, fn ->
        # test code that exercises the hook
      end)

  """
  @doc since: "0.8.0"
  @spec with_hook(atom(), {module(), atom()}, (-> term())) :: term()
  def with_hook(operation, {mod, fun}, test_fn) when is_atom(operation) and is_function(test_fn, 0) do
    original = Application.get_env(:sigra, :hooks, [])
    original_hook = Keyword.get(original, operation)

    try do
      updated = Keyword.put(original, operation, {mod, fun})
      Application.put_env(:sigra, :hooks, updated)
      test_fn.()
    after
      if original_hook do
        Application.put_env(:sigra, :hooks, Keyword.put(original, operation, original_hook))
      else
        Application.put_env(:sigra, :hooks, Keyword.delete(original, operation))
      end
    end
  end

  # --- OAuth ---
  # -- OAuth Testing Helpers (Phase 5) --

  @doc """
  Creates a mock OAuth callback result for testing.

  Returns a map matching the shape used by `Sigra.OAuth.Callback`.

  ## Options

    - `:provider` - Provider atom (default: `:google`)
    - `:email` - User email (default: `"oauth@example.com"`)
    - `:uid` - Provider UID (default: `"provider_123"`)
    - `:name` - User name (default: `"OAuth User"`)
    - `:email_verified` - Whether the email is verified (default: `true`)
  """
  @doc since: "0.5.0"
  @spec mock_oauth_callback(keyword()) :: map()
  def mock_oauth_callback(opts \\ []) do
    %{
      provider: Keyword.get(opts, :provider, :google),
      user_info: %{
        "sub" => Keyword.get(opts, :uid, "provider_123"),
        "email" => Keyword.get(opts, :email, "oauth@example.com"),
        "name" => Keyword.get(opts, :name, "OAuth User"),
        "picture" => "https://example.com/avatar.jpg",
        "email_verified" => Keyword.get(opts, :email_verified, true)
      },
      token: %{
        "access_token" =>
          "test_access_token_#{:crypto.strong_rand_bytes(8) |> Base.url_encode64()}",
        "refresh_token" => "test_refresh_token",
        "expires_in" => 3600
      }
    }
  end

  @doc """
  Creates an identity struct for testing.

  ## Options

    - `:provider` - Provider string (default: `"google"`)
    - `:provider_uid` - UID string (default: auto-generated)
    - `:user_id` - Associated user ID (required)
    - `:email` - Provider email (default: `"oauth@example.com"`)
    - `:name` - Provider name (default: `"Test User"`)
    - `:id` - Identity ID (default: auto-generated)
  """
  @doc since: "0.5.0"
  @spec create_identity(keyword()) :: Sigra.Identity.t()
  def create_identity(opts \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %Sigra.Identity{
      id: Keyword.get(opts, :id, System.unique_integer([:positive])),
      user_id: Keyword.fetch!(opts, :user_id),
      provider: Keyword.get(opts, :provider, "google"),
      provider_uid:
        Keyword.get(opts, :provider_uid, "uid_#{System.unique_integer([:positive])}"),
      provider_email: Keyword.get(opts, :email, "oauth@example.com"),
      provider_name: Keyword.get(opts, :name, "Test User"),
      metadata: %{},
      inserted_at: now,
      updated_at: now
    }
  end

  @doc """
  Creates a user registered via OAuth for testing.

  Returns `%{user: user_attrs, identity: identity}` map with default
  OAuth-specific values (confirmed_at set since OAuth auto-confirms).

  ## Options

    - `:email` - User email (default: `"oauth@example.com"`)
    - `:provider` - Provider string (default: `"google"`)
    - `:provider_uid` - Provider UID (default: auto-generated)
    - `:user_id` - User ID (default: auto-generated)
  """
  @doc since: "0.5.0"
  @spec oauth_user_fixture(keyword()) :: map()
  def oauth_user_fixture(opts \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    user_id = Keyword.get(opts, :user_id, System.unique_integer([:positive]))

    user = %{
      id: user_id,
      email: Keyword.get(opts, :email, "oauth@example.com"),
      hashed_password: nil,
      confirmed_at: now,
      inserted_at: now,
      updated_at: now
    }

    identity =
      create_identity(
        user_id: user_id,
        provider: Keyword.get(opts, :provider, "google"),
        provider_uid: Keyword.get(opts, :provider_uid),
        email: Keyword.get(opts, :email, "oauth@example.com")
      )

    %{user: user, identity: identity}
  end

  # --- Audit (Phase 9) ---

  @doc """
  Inserts an audit event directly via the configured repo, bypassing
  `Ecto.Multi` wrapping. Test-only — production audit writes go through
  `Sigra.Audit.log/2` or `Sigra.Audit.log_multi/3`.

  ## Options

    * `:repo` (required) — the Ecto repo module
    * `:audit_schema` (required) — the generated `audit_events` schema module
    * `:action` (default `"test.event"`)
    * `:outcome` (default `"success"`)
    * `:actor_id`, `:actor_type` (default `"user"`), `:target_id`, `:target_type`
    * `:metadata` (default `%{}`)
    * `:occurred_at` (default `DateTime.utc_now/0`)

  ## Examples

      audit_event_fixture(repo: MyApp.Repo, audit_schema: MyApp.AuditEvent)

      audit_event_fixture(
        repo: MyApp.Repo,
        audit_schema: MyApp.AuditEvent,
        action: "billing.charge.created",
        outcome: "failure",
        metadata: %{amount: 99}
      )

  """
  @doc since: "0.10.0"
  @spec audit_event_fixture(keyword()) :: struct()
  def audit_event_fixture(opts) when is_list(opts) do
    repo = Keyword.fetch!(opts, :repo)
    audit_schema = Keyword.fetch!(opts, :audit_schema)

    attrs = %{
      action: Keyword.get(opts, :action, "test.event"),
      outcome: Keyword.get(opts, :outcome, "success"),
      actor_id: Keyword.get(opts, :actor_id),
      actor_type: Keyword.get(opts, :actor_type, "user"),
      target_id: Keyword.get(opts, :target_id),
      target_type: Keyword.get(opts, :target_type),
      metadata: Keyword.get(opts, :metadata, %{}),
      occurred_at: Keyword.get(opts, :occurred_at, DateTime.utc_now())
    }

    audit_schema
    |> struct()
    |> Ecto.Changeset.change(attrs)
    |> repo.insert!()
  end

  @doc """
  Asserts that an audit event matches the given map.

  By default checks the most recent event (ordered by `inserted_at` desc);
  pass `:position` to check the Nth-most-recent (`0` is newest).

  Top-level keys (`:action`, `:outcome`, `:actor_id`, etc.) are compared
  with strict equality. The `:metadata` key, if present, deep-matches a
  subset — keys present in the expected map must equal the corresponding
  values on the event, but extra keys on the event are ignored. Both atom
  and string metadata keys are tolerated.

  Raises `ExUnit.AssertionError` with a diff-style message on mismatch.

  ## Options

    * `:repo` (required) — the Ecto repo module
    * `:audit_schema` (required) — the audit_events schema module
    * `:position` (default `0`) — 0-based offset from newest

  ## Examples

      assert_audit_event(
        %{action: "billing.charge.created", outcome: "success"},
        repo: MyApp.Repo,
        audit_schema: MyApp.AuditEvent
      )

      assert_audit_event(
        %{metadata: %{plan: "pro"}},
        repo: MyApp.Repo,
        audit_schema: MyApp.AuditEvent
      )

  """
  @doc since: "0.10.0"
  @spec assert_audit_event(map(), keyword()) :: true
  def assert_audit_event(expected, opts) when is_map(expected) and is_list(opts) do
    repo = Keyword.fetch!(opts, :repo)
    audit_schema = Keyword.fetch!(opts, :audit_schema)
    position = Keyword.get(opts, :position, 0)

    require Ecto.Query

    query =
      Ecto.Query.from(e in audit_schema,
        order_by: [desc: e.inserted_at],
        limit: 1,
        offset: ^position
      )

    event = repo.one(query)

    if is_nil(event) do
      raise ExUnit.AssertionError,
        message: "Expected an audit event at position #{position}, found none"
    end

    Enum.each(expected, fn
      {:metadata, expected_meta} when is_map(expected_meta) ->
        Enum.each(expected_meta, fn {k, v} ->
          actual =
            Map.get(event.metadata || %{}, to_string(k)) ||
              Map.get(event.metadata || %{}, k)

          unless actual == v do
            raise ExUnit.AssertionError,
              message:
                "Expected metadata[#{inspect(k)}] == #{inspect(v)}, got #{inspect(actual)}"
          end
        end)

      {key, expected_value} ->
        actual = Map.get(event, key)

        unless actual == expected_value do
          raise ExUnit.AssertionError,
            message: "Expected #{key} == #{inspect(expected_value)}, got #{inspect(actual)}"
        end
    end)

    true
  end
end
