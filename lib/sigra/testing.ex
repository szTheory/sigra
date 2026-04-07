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
end
