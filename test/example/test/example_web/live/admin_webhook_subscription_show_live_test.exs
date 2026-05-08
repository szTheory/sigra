defmodule ExampleWeb.AdminWebhookSubscriptionShowLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  import ExampleWeb.ConnCaseHelpers
  import Example.WebhookAdminLiveFixtures

  alias Example.Repo
  alias Example.Accounts.{WebhookDelivery, WebhookSubscription}

  test "detail renders lifecycle state, replay context in recent history, and keeps replay on delivery detail",
       %{conn: conn} do
    admin = platform_admin_fixture()

    subscription =
      webhook_subscription_fixture(%{
        description: "Detail subscription",
        signing_secret: String.duplicate("a", 32)
      })

    source_delivery =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-detail-1",
        status: "dead_lettered",
        attempt_count: 2,
        last_http_status: 502,
        dead_lettered_at: ~U[2026-05-06 15:30:00Z],
        terminal_reason: "retries_exhausted"
      })

    replay_child =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-detail-1-replay",
        status: "delivered",
        attempt_count: 1,
        last_http_status: 200,
        replayed_from_webhook_delivery_id: source_delivery.id,
        replay_root_webhook_delivery_id: source_delivery.id,
        replayed_at: ~U[2026-05-06 15:45:00Z],
        replayed_by_user_id: admin.id,
        replay_source: "admin.delivery_detail"
      })

    {:ok, view, html} =
      conn
      |> log_in_user(admin)
      |> live("/admin/webhooks/subscriptions/#{subscription.id}?return_to=%2Fadmin%2Fwebhooks")

    assert html =~ "Setup"
    assert html =~ "Disable subscription"
    assert html =~ "Reveal secret"
    assert html =~ "Rotation lifecycle"
    assert html =~ "Prepare next secret"
    assert html =~ "Recent deliveries"
    assert html =~ "Verify against the raw request body."
    assert html =~ "Use delivery_id for dedupe."
    assert html =~ "current and previous receiver secrets"
    assert html =~ source_delivery.delivery_id
    assert html =~ replay_child.delivery_id
    assert html =~ "Replay child"
    assert html =~ "Original failed delivery"
    assert html =~ "Replay lineage lives on delivery detail."
    assert html =~ "Open delivery"
    refute html =~ "Replay delivery"
    refute html =~ "Test event"

    html = render_click(view, :reveal_secret, %{})

    assert html =~ String.duplicate("a", 32)
    assert html =~ "Copy secret"

    html = render_click(view, :open_prepare, %{})
    assert html =~ "Prepare a new secret?"

    html = render_click(view, :confirm_action, %{})
    assert html =~ "Prepared a staged secret. Update the receiver, then start overlap."
    assert html =~ "Prepared"
    assert html =~ "Start overlap"
    assert html =~ "Discard prepared secret"

    prepared = Repo.get!(WebhookSubscription, subscription.id)
    assert prepared.rotation_state == :prepared
    assert prepared.next_signing_secret

    html = render_click(view, :open_start_overlap, %{})
    assert html =~ "Start overlap now?"

    html = render_click(view, :confirm_action, %{})
    assert html =~ "Overlap started. Sigra now signs deliveries with both secrets."
    assert html =~ "Overlap active"
    assert html =~ "Complete rotation"

    overlap = Repo.get!(WebhookSubscription, subscription.id)
    assert overlap.rotation_state == :overlap_active

    html = render_click(view, :open_complete_rotation, %{})
    assert html =~ "Complete the rotation?"

    html = render_click(view, :confirm_action, %{})
    assert html =~ "Rotation completed. Verify a post-retirement delivery with the new active secret."
    assert html =~ "Completed"

    rotated = Repo.get!(WebhookSubscription, subscription.id)
    assert rotated.signing_secret != String.duplicate("a", 32)
    assert rotated.next_signing_secret == nil

    html = render_click(view, :open_disable, %{})
    assert html =~ "Disable this subscription?"

    html = render_click(view, :confirm_action, %{})
    assert html =~ "Webhook subscription disabled."

    disabled = Repo.get!(WebhookSubscription, subscription.id)
    refute disabled.enabled

    root =
      Repo.get_by!(WebhookDelivery, delivery_id: source_delivery.delivery_id)

    assert root.delivery_id == "delivery-detail-1"
  end
end
