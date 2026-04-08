defmodule <%= context_module %>Fixtures do
  @moduledoc """
  Test fixtures for authentication.

  This module provides helper functions for creating test users
  and extracting tokens from delivery functions.
  """

  alias <%= context_module %>

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> <%= context_module %>.register_user()

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_token} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_token, "[TOKEN]")
    token
  end

  @doc """
  Creates a standard session for the given user.

  Accepts optional attributes to override defaults (e.g., `:ip`, `:user_agent`, `:type`).
  """
  def session_fixture(user, attrs \\ %{}) do
    token = :crypto.strong_rand_bytes(32)
    hashed_token = :crypto.hash(:sha256, token)

    now = DateTime.utc_now()

    defaults = %{
      hashed_token: hashed_token,
      type: "standard",
      ip: "127.0.0.1",
      user_agent: "ExUnit/1.0",
      last_active_at: now,
      inserted_at: now
    }

    session_attrs = Map.merge(defaults, attrs)

    %<%= context_module %>.UserSession{}
    |> Ecto.Changeset.change(Map.put(session_attrs, :user_id, user.id))
    |> <%= repo_module %>.insert!()
  end

  @doc """
  Creates a remember-me session for the given user.
  """
  def remembered_session_fixture(user, attrs \\ %{}) do
    session_fixture(user, Map.put(attrs, :type, "remember_me"))
  end

  @doc """
  Locks the given user by setting failed login attempts and locked_at.
  """
  def locked_user_fixture(user) do
    user
    |> Ecto.Changeset.change(%{failed_login_attempts: 5, locked_at: DateTime.utc_now()})
    |> <%= repo_module %>.update!()
  end

  @doc """
  Creates a session with sudo mode activated for the given user.
  """
  def sudo_session_fixture(user, attrs \\ %{}) do
    session = session_fixture(user, Map.put(attrs, :sudo_at, DateTime.utc_now()))
    session
  end

  @doc """
  Creates a user with MFA (TOTP) enabled.

  Returns `%{user: user, totp_secret: secret, backup_codes: codes}` where
  `secret` is the raw Base32 TOTP secret and `codes` are the plaintext
  backup codes (before hashing).
  """
  def mfa_user_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)
    config = Auth.sigra_config()

    %{totp_secret: secret, backup_codes: codes} =
      Sigra.Testing.setup_totp(user,
        config: config,
        mfa_credential_schema: <%= context_module %>.UserMFACredential,
        backup_code_schema: <%= context_module %>.UserBackupCode
      )

    %{user: user, totp_secret: secret, backup_codes: codes}
  end

  @doc """
  Creates a user with MFA enabled and an `mfa_pending` session.

  Returns `%{user: user, session: session, totp_secret: secret}`.
  """
  def mfa_pending_session_fixture(attrs \\ %{}) do
    %{user: user, totp_secret: secret} = mfa_user_fixture(attrs)
    session = session_fixture(user, %{type: "mfa_pending"})
    %{user: user, session: session, totp_secret: secret}
  end

  @doc """
  Creates a user with MFA enabled whose MFA credential is locked out
  (failed_attempts >= threshold).

  Returns `%{user: user, credential: credential}`.
  """
  def mfa_locked_fixture(attrs \\ %{}) do
    %{user: user} = mfa_user_fixture(attrs)
    config = Auth.sigra_config()

    credential =
      Sigra.Testing.simulate_mfa_lockout(user,
        config: config,
        mfa_credential_schema: <%= context_module %>.UserMFACredential
      )

    %{user: user, credential: credential}
  end
end
