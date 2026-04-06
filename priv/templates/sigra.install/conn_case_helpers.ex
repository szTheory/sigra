defmodule <%= web_module %>.ConnCaseHelpers do
  @moduledoc """
  Authentication test helpers for ConnCase.

  Import this module in your ConnCase to get authentication
  helper functions for integration tests.

  ## Setup

  Add to your `test/support/conn_case.ex`:

      import <%= web_module %>.ConnCaseHelpers

  Also add to your `config/test.exs`:

      # Speed up password hashing in tests
      config :argon2_elixir, t_cost: 1, m_cost: 8
  """

  alias <%= context_module %>
  alias <%= context_module %>Fixtures

  @doc """
  Sets up the connection with a logged-in user.

  It creates a new user, generates a session token, and puts
  the token in the connection session.

      setup :register_and_log_in_user

  Alternatively, you can log in an existing user:

      user = user_fixture()
      conn = log_in_user(conn, user)

  """
  def register_and_log_in_user(%{conn: conn}) do
    user = Fixtures.user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user) do
    token = <%= context_module %>.generate_user_session_token(user)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end
end
