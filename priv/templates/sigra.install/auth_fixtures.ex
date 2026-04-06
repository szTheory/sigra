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
end
