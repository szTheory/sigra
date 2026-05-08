defmodule ExampleWeb.SigraWebhookControllerTest do
  use ExampleWeb.ConnCase, async: false

  import Example.WebhookAdminLiveFixtures

  alias Example.Accounts
  alias Example.Accounts.WebhookReceipt
  alias Example.Repo
  alias Sigra.Webhooks.Signature
  import Ecto.Query

  setup do
    on_exit(fn -> Application.delete_env(:example, :webhook_receiver_secrets) end)
    on_exit(fn -> Application.delete_env(:example, :webhook_receiver_mode) end)
    :ok
  end

  test "accepts a valid signed request, persists one receipt, and dedupes by delivery_id", %{conn: conn} do
    initial_count = receipt_count_for("delivery-proof-1")

    subscription = webhook_subscription_fixture(%{signing_secret: String.duplicate("s", 32)})
    configure_receiver_secrets(current: subscription.signing_secret)

    delivery =
      subscription
      |> webhook_delivery_fixture(%{delivery_id: "delivery-proof-1"})
      |> Repo.preload(:webhook_event)

    raw_body = Jason.encode!(delivery.webhook_event.payload)

    headers =
      Signature.headers(delivery.delivery_id, raw_body, subscription.signing_secret,
        timestamp: System.os_time(:second)
      )

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("sigra-webhook-id", headers["Sigra-Webhook-Id"])
      |> put_req_header("sigra-webhook-timestamp", headers["Sigra-Webhook-Timestamp"])
      |> put_req_header("sigra-webhook-signature", headers["Sigra-Webhook-Signature"])
      |> post(~p"/webhooks/sigra", raw_body)

    assert response(conn, 202) == ""

    assert %WebhookReceipt{delivery_id: "delivery-proof-1", event_type: "user.created"} =
             Accounts.get_webhook_receipt_by_delivery_id("delivery-proof-1")

    duplicate_conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("sigra-webhook-id", headers["Sigra-Webhook-Id"])
      |> put_req_header("sigra-webhook-timestamp", headers["Sigra-Webhook-Timestamp"])
      |> put_req_header("sigra-webhook-signature", headers["Sigra-Webhook-Signature"])
      |> post(~p"/webhooks/sigra", raw_body)

    assert response(duplicate_conn, 202) == ""
    assert receipt_count_for("delivery-proof-1") == initial_count + 1
  end

  test "accepts an overlap-window request when any candidate secret matches", %{conn: conn} do
    subscription =
      webhook_subscription_fixture(%{
        signing_secret: String.duplicate("s", 32),
        next_signing_secret: String.duplicate("n", 32),
        rotation_state: :overlap_active
      })

    configure_receiver_secrets(
      current: subscription.next_signing_secret,
      previous: subscription.signing_secret
    )

    delivery =
      subscription
      |> webhook_delivery_fixture(%{delivery_id: "delivery-proof-overlap"})
      |> Repo.preload(:webhook_event)

    raw_body = Jason.encode!(delivery.webhook_event.payload)

    headers =
      Signature.headers(
        delivery.delivery_id,
        raw_body,
        [subscription.signing_secret, subscription.next_signing_secret],
        timestamp: System.os_time(:second)
      )

    conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("sigra-webhook-id", headers["Sigra-Webhook-Id"])
      |> put_req_header("sigra-webhook-timestamp", headers["Sigra-Webhook-Timestamp"])
      |> put_req_header("sigra-webhook-signature", headers["Sigra-Webhook-Signature"])
      |> post(~p"/webhooks/sigra", raw_body)

    assert response(conn, 202) == ""
    assert %WebhookReceipt{delivery_id: "delivery-proof-overlap"} =
             Accounts.get_webhook_receipt_by_delivery_id("delivery-proof-overlap")
  end

  test "rejects missing, stale, and invalid signatures without persisting receipts", %{conn: conn} do
    initial_count = receipt_count_for("delivery-proof-2")

    subscription = webhook_subscription_fixture(%{signing_secret: String.duplicate("z", 32)})
    configure_receiver_secrets(
      current: String.duplicate("y", 32),
      previous: subscription.signing_secret
    )

    delivery =
      subscription
      |> webhook_delivery_fixture(%{delivery_id: "delivery-proof-2"})
      |> Repo.preload(:webhook_event)

    raw_body = Jason.encode!(delivery.webhook_event.payload)

    missing_signature_conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("sigra-webhook-id", delivery.delivery_id)
      |> put_req_header("sigra-webhook-timestamp", Integer.to_string(System.os_time(:second)))
      |> post(~p"/webhooks/sigra", raw_body)

    assert response(missing_signature_conn, 400) == "missing webhook signature"

    stale_headers =
      Signature.headers(delivery.delivery_id, raw_body, subscription.signing_secret,
        timestamp: System.os_time(:second) - 600
      )

    stale_conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("sigra-webhook-id", stale_headers["Sigra-Webhook-Id"])
      |> put_req_header("sigra-webhook-timestamp", stale_headers["Sigra-Webhook-Timestamp"])
      |> put_req_header("sigra-webhook-signature", stale_headers["Sigra-Webhook-Signature"])
      |> post(~p"/webhooks/sigra", raw_body)

    assert response(stale_conn, 400) == "stale webhook timestamp"

    invalid_signature_conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("sigra-webhook-id", delivery.delivery_id)
      |> put_req_header("sigra-webhook-timestamp", Integer.to_string(System.os_time(:second)))
      |> put_req_header("sigra-webhook-signature", "v1=#{String.duplicate("0", 64)}")
      |> post(~p"/webhooks/sigra", raw_body)

    assert response(invalid_signature_conn, 401) == "invalid webhook signature"
    assert receipt_count_for("delivery-proof-2") == initial_count
  end

  test "verified failing mode keeps dedupe on delivery_id while returning 503", %{conn: conn} do
    initial_count = receipt_count_for("delivery-proof-failing")

    subscription = webhook_subscription_fixture(%{signing_secret: String.duplicate("f", 32)})

    configure_receiver(%{
      current: subscription.signing_secret,
      mode: :fail_after_verify
    })

    delivery =
      subscription
      |> webhook_delivery_fixture(%{delivery_id: "delivery-proof-failing"})
      |> Repo.preload(:webhook_event)

    raw_body = Jason.encode!(delivery.webhook_event.payload)

    headers =
      Signature.headers(delivery.delivery_id, raw_body, subscription.signing_secret,
        timestamp: System.os_time(:second)
      )

    failing_conn =
      conn
      |> put_req_header("content-type", "application/json")
      |> put_req_header("sigra-webhook-id", headers["Sigra-Webhook-Id"])
      |> put_req_header("sigra-webhook-timestamp", headers["Sigra-Webhook-Timestamp"])
      |> put_req_header("sigra-webhook-signature", headers["Sigra-Webhook-Signature"])
      |> post(~p"/webhooks/sigra", raw_body)

    assert response(failing_conn, 503) == "receiver downstream unavailable"

    assert %WebhookReceipt{delivery_id: "delivery-proof-failing"} =
             Accounts.get_webhook_receipt_by_delivery_id("delivery-proof-failing")

    duplicate_conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("sigra-webhook-id", headers["Sigra-Webhook-Id"])
      |> put_req_header("sigra-webhook-timestamp", headers["Sigra-Webhook-Timestamp"])
      |> put_req_header("sigra-webhook-signature", headers["Sigra-Webhook-Signature"])
      |> post(~p"/webhooks/sigra", raw_body)

    assert response(duplicate_conn, 503) == "receiver downstream unavailable"
    assert receipt_count_for("delivery-proof-failing") == initial_count + 1
  end

  defp configure_receiver(attrs) do
    :ok = Accounts.configure_webhook_receiver_secrets(attrs)
  end

  defp configure_receiver_secrets(secrets) do
    configure_receiver(secrets)
  end

  defp receipt_count_for(delivery_id) do
    Repo.aggregate(
      from(receipt in WebhookReceipt, where: receipt.delivery_id == ^delivery_id),
      :count
    )
  end
end
