defmodule Sigra.Test.EmailFixtures do
  @moduledoc """
  Test fixtures for email flow testing.

  Provides helpers to create confirmation tokens, reset tokens,
  and pre-confirmed users for test setup.
  """

  alias Sigra.Token

  @default_secret "test_secret_key_base_at_least_64_bytes_long_for_plug_crypto_signing_operations_1234"

  @doc "Generates a confirmation token pair (link token + code) for testing."
  def confirmation_token_fixture(user, opts \\ []) do
    secret = Keyword.get(opts, :secret_key_base, @default_secret)

    {raw_bytes, hashed} = Token.generate_hashed_token()
    signed = Plug.Crypto.sign(secret, "sigra-confirm-token", raw_bytes)
    encoded = Base.url_encode64(signed, padding: false)

    code = (:rand.uniform(900_000) + 99_999) |> Integer.to_string()
    hashed_code = Token.hash_token(code)

    %{
      encoded_token: encoded,
      code: code,
      hashed_token: hashed,
      hashed_code: hashed_code,
      user_id: user.id,
      email: user.email
    }
  end

  @doc "Generates a reset password token for testing."
  def reset_token_fixture(user, opts \\ []) do
    secret = Keyword.get(opts, :secret_key_base, @default_secret)

    {raw_bytes, hashed} = Token.generate_hashed_token()
    signed = Plug.Crypto.sign(secret, "sigra-reset-token", raw_bytes)
    encoded = Base.url_encode64(signed, padding: false)

    %{
      encoded_token: encoded,
      hashed_token: hashed,
      user_id: user.id,
      email: user.email
    }
  end

  @doc "Returns a user map with confirmed_at set."
  def confirmed_user_attrs(attrs \\ %{}) do
    Map.merge(
      %{confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)},
      attrs
    )
  end

  @doc "Returns a user map without confirmed_at (unconfirmed)."
  def unconfirmed_user_attrs(attrs \\ %{}) do
    Map.merge(%{confirmed_at: nil}, attrs)
  end
end
