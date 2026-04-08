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
end
