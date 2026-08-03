defmodule Sigra.Integrations.ChimewayTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Integrations.Chimeway

  setup :verify_on_exit!

  test "magic-link lookup is bound to each request's exact raw token" do
    user = %{id: 17, email: "user@example.com"}
    first_token = "first-raw-token"
    second_token = "second-raw-token"

    Sigra.MockRepo
    |> expect(:one, fn query ->
      assert_query_token(query, first_token)
      nil
    end)
    |> expect(:one, fn query ->
      assert_query_token(query, second_token)
      nil
    end)

    opts = [user_token_schema: Sigra.TestUserToken]

    assert {:error, :magic_link_token_not_found} =
             Chimeway.dispatch_magic_link(
               Sigra.MockRepo,
               user,
               first_token,
               "https://example.com/magic/first",
               opts
             )

    assert {:error, :magic_link_token_not_found} =
             Chimeway.dispatch_magic_link(
               Sigra.MockRepo,
               user,
               second_token,
               "https://example.com/magic/second",
               opts
             )
  end

  defp assert_query_token(%Ecto.Query{wheres: [where]}, raw_token) do
    expected_hash = Sigra.Token.hash_token(raw_token)

    assert {expected_hash, {0, :token}} in where.params
    refute Enum.any?(where.params, fn {_value, {_binding, field}} -> field == :inserted_at end)
  end
end
