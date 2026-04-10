defmodule <%= context_module %>Fixtures do
  @moduledoc """
  Test fixtures for authentication.

  This module provides helper functions for creating test users
  and extracting tokens from delivery functions.
  """

  import Phoenix.ConnTest, only: [build_conn: 0]
  import <%= web_module %>.ConnCaseHelpers, only: [log_in_user: 2, log_in_user: 3]

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

  # -- Account Lifecycle Fixtures (Phase 8) --

  @doc """
  Creates a user with account deletion scheduled.

  Returns the user with `deleted_at` and `scheduled_deletion_at` set.

  ## Options

    * `:grace_period_days` - Days until permanent deletion (default: 14)
  """
  def scheduled_deletion_fixture(attrs \\ %{}, opts \\ []) do
    user = user_fixture(attrs)

    Sigra.Testing.scheduled_deletion_fixture(
      <%= repo_module %>,
      user,
      opts
    )
  end

  @doc """
  Creates a user with the force password change flag set.

  Returns the user with `must_change_password: true`.
  """
  def force_password_change_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)

    Sigra.Testing.force_password_change_fixture(
      <%= repo_module %>,
      user
    )
  end

  # --- Scenario Fixtures (Phase 10, DX-03) ---
  #
  # Named wrappers composing the primitives above. Each returns a
  # non-uniform map containing only the keys the scenario needs (D-04).
  # Scenarios representing pre-login or blocked state (mfa_pending,
  # locked, unconfirmed) deliberately omit :conn (D-07).
  #
  # These are UNIT-level helpers — they bypass real CSRF, rate limiting,
  # and session-renewal flows. Integration tests exercising auth gates
  # must drive real register/log_in controllers, not these fixtures.

  @doc """
  Anonymous / unauthenticated scenario. Returns a fresh conn with no
  session.
  """
  def anonymous_fixture do
    %{conn: build_conn()}
  end

  @doc """
  Authenticated scenario. Returns user, session, and a logged-in conn.
  """
  def authenticated_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)
    session = session_fixture(user)
    %{user: user, session: session, conn: log_in_user(build_conn(), user)}
  end

  @doc """
  MFA-pending scenario. User has TOTP enrolled; session type is
  `"mfa_pending"`. Caller has NOT yet passed the challenge, so no
  `:conn` is returned (D-07).
  """
  def mfa_pending_fixture(attrs \\ %{}) do
    mfa_pending_session_fixture(attrs)
  end

  @doc """
  MFA-complete scenario. User has TOTP enrolled AND has passed the
  challenge.

  Phase 6 transitions the session type from `"mfa_pending"` to
  `"standard"` on successful verification rather than stamping a
  separate timestamp; this fixture therefore returns a post-transition
  standard session. Represents post-verification state only — real MFA
  gate behavior is verified by integration tests that drive the
  challenge controller.
  """
  def mfa_complete_fixture(attrs \\ %{}) do
    %{user: user, totp_secret: secret} = mfa_user_fixture(attrs)
    session = session_fixture(user, %{type: "standard"})
    conn = log_in_user(build_conn(), user)
    %{user: user, session: session, conn: conn, totp_secret: secret}
  end

  @doc """
  Sudo scenario. Authenticated user whose session has a recent
  `sudo_at`, suitable for testing sensitive operations that require
  sudo mode.
  """
  def sudo_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)
    session = sudo_session_fixture(user)
    %{user: user, session: session, conn: log_in_user(build_conn(), user)}
  end

  @doc """
  Locked scenario. User with `failed_login_attempts == 5` and
  `locked_at` set. No `:conn` — locked users cannot log in (D-07).
  """
  def locked_fixture(attrs \\ %{}) do
    user = attrs |> user_fixture() |> locked_user_fixture()
    %{user: user}
  end

  @doc """
  Unconfirmed scenario. User exists but `confirmed_at` is nil (email
  not yet confirmed per D-06). No `:conn` (D-07).
  """
  def unconfirmed_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)
    %{user: user}
  end

  @doc """
  Dispatcher for parametric test setup. Accepts one of:
  `:anonymous | :authenticated | :mfa_pending | :mfa_complete | :sudo | :locked | :unconfirmed`.

  Raises `FunctionClauseError` on any other value, including string
  scenario names.
  """
  def scenario(name, attrs \\ %{})
  def scenario(:anonymous, _attrs), do: anonymous_fixture()
  def scenario(:authenticated, attrs), do: authenticated_fixture(attrs)
  def scenario(:mfa_pending, attrs), do: mfa_pending_fixture(attrs)
  def scenario(:mfa_complete, attrs), do: mfa_complete_fixture(attrs)
  def scenario(:sudo, attrs), do: sudo_fixture(attrs)
  def scenario(:locked, attrs), do: locked_fixture(attrs)
  def scenario(:unconfirmed, attrs), do: unconfirmed_fixture(attrs)
end
