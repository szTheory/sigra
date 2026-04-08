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
end
