defmodule Sigra.Integrations.ChimewayRecipientTest do
  use ExUnit.Case, async: true

  alias Sigra.Integrations.Chimeway

  @notifiers [Chimeway.MagicLinkNotifier, Chimeway.ConfirmationCodeNotifier]

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
end
