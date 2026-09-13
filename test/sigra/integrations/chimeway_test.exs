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
