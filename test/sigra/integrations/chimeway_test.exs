defmodule Sigra.Integrations.ChimewayTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.Integrations.Chimeway

  @notifiers [Chimeway.MagicLinkNotifier, Chimeway.ConfirmationCodeNotifier]

  setup :verify_on_exit!

  test "auth notifiers separate opaque durable references from normalized delivery identities" do
    for notifier <- @notifiers do
      assert {:ok, [recipient]} =
               notifier.recipients(%{
                 "user_id" => "user-42",
                 "email" => "  Alice@Example.TEST  "
               })

      assert recipient == %{
               recipient_ref: "cw_sigra_user_6d894aa3ee802549d7f340e7c1cf0d1c",
               recipient_identity: "user:alice@example.test",
               recipient_type: "email"
             }

      refute recipient.recipient_ref =~ "alice"
      refute recipient.recipient_ref =~ "example.test"
    end
  end

  test "recipient references are stable per user and differ across users" do
    first = Chimeway.recipient_reference("user-42")

    assert first == Chimeway.recipient_reference("user-42")
    assert first != Chimeway.recipient_reference("user-43")
    assert first =~ ~r/^cw_[a-z0-9][a-z0-9_-]*$/
  end

  test "auth notifiers reject missing recipient inputs" do
    for notifier <- @notifiers do
      assert {:error, :missing_email} = notifier.recipients(%{"user_id" => "user-42"})

      assert {:error, :missing_email} =
               notifier.recipients(%{"user_id" => "user-42", "email" => "  "})

      assert {:error, :missing_user_id} =
               notifier.recipients(%{"email" => "alice@example.test"})
    end
  end

  test "magic-link lookup hashes decoded URL-safe token bytes for each request" do
    user = %{id: 17, email: "user@example.com"}
    {first_token, first_stored_hash} = Sigra.Token.generate_hashed_token()
    {second_token, second_stored_hash} = Sigra.Token.generate_hashed_token()

    Sigra.MockRepo
    |> expect(:one, fn query ->
      assert_query_token(query, first_stored_hash)
      nil
    end)
    |> expect(:one, fn query ->
      assert_query_token(query, second_stored_hash)
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

  test "malformed magic-link tokens fail without querying the repository" do
    user = %{id: 17, email: "user@example.com"}

    assert {:error, :magic_link_token_not_found} =
             Chimeway.dispatch_magic_link(
               Sigra.MockRepo,
               user,
               "not-valid-base64*",
               "https://example.com/magic/invalid",
               user_token_schema: Sigra.TestUserToken
             )
  end

  defp assert_query_token(%Ecto.Query{wheres: [where]}, expected_hash) do
    assert {expected_hash, {0, :token}} in where.params
    refute Enum.any?(where.params, fn {_value, {_binding, field}} -> field == :inserted_at end)
  end
end
