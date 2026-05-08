defmodule ExampleWeb.AdminWebhookDeliveryShowLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  import ExampleWeb.ConnCaseHelpers
  import Example.WebhookAdminLiveFixtures

  alias Example.Repo
  alias Example.Accounts.WebhookDelivery

  test "delivery detail keeps replay lineage separate from the attempt timeline", %{
    conn: conn
  } do
    admin = platform_admin_fixture()
    subscription = webhook_subscription_fixture(%{description: "Timeline endpoint"})

    source =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-lineage-source",
        status: "dead_lettered",
        attempt_count: 2,
        last_http_status: 502,
        dead_lettered_at: ~U[2026-05-06 12:10:00Z],
        last_attempted_at: ~U[2026-05-06 12:05:00Z],
        terminal_reason: "retries_exhausted"
      })

    webhook_attempt_fixture(source, %{
      attempt_number: 1,
      response_status: 500,
      retryable: true,
      started_at: ~U[2026-05-06 12:00:00Z],
      error_category: "http_error"
    })

    webhook_attempt_fixture(source, %{
      attempt_number: 2,
      response_status: 502,
      retryable: true,
      started_at: ~U[2026-05-06 12:05:00Z],
      error_category: "http_error"
    })

    replay_child =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-lineage-child",
        status: "delivered",
        attempt_count: 1,
        last_http_status: 200,
        dispatched_at: ~U[2026-05-06 12:20:00Z],
        last_attempted_at: ~U[2026-05-06 12:21:00Z],
        replayed_from_webhook_delivery_id: source.id,
        replay_root_webhook_delivery_id: source.id,
        replayed_at: ~U[2026-05-06 12:15:00Z],
        replayed_by_user_id: admin.id,
        replay_source: "admin.delivery_detail",
        webhook_event: Repo.get!(source.__struct__.__schema__(:association, :webhook_event).related, source.webhook_event_id)
      })

    webhook_attempt_fixture(replay_child, %{
      attempt_number: 1,
      response_status: 200,
      started_at: ~U[2026-05-06 12:21:00Z]
    })

    {:ok, _view, html} =
      conn
      |> log_in_user(admin)
      |> live(
        "/admin/webhooks/deliveries/#{source.delivery_id}?return_to=%2Fadmin%2Fwebhooks%2Ffailures"
      )

    assert html =~ "Webhook delivery"
    assert html =~ "Current status"
    assert html =~ "Attempt timeline"
    assert html =~ "Replay lineage"
    assert html =~ "Delivery ID"
    assert html =~ "Event ID"
    assert html =~ "Endpoint"
    assert html =~ "Last HTTP status"
    assert html =~ "Attempt 2"
    assert html =~ "Attempt 1"
    assert html =~ source.delivery_id
    assert html =~ replay_child.delivery_id
    assert html =~ "Replay child"
    assert html =~ "Open replay child"
    refute html =~ "Attempt 3"
  end

  test "delivery detail exposes replay confirmation for eligible dead-lettered rows and explicit blocked reasons otherwise",
       %{conn: conn} do
    admin = platform_admin_fixture()
    subscription = webhook_subscription_fixture(%{description: "Replay detail"})

    replayable =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-replayable-detail",
        status: "dead_lettered",
        attempt_count: 4,
        last_http_status: 503,
        dead_lettered_at: ~U[2026-05-06 14:00:00Z],
        terminal_reason: "retries_exhausted"
      })

    {:ok, replayable_view, replayable_html} =
      conn
      |> log_in_user(admin)
      |> live("/admin/webhooks/deliveries/#{replayable.delivery_id}")

    assert replayable_html =~ "Replay delivery"
    assert replayable_html =~ "Replay is available for this dead-lettered delivery."

    replayable_html = render_click(replayable_view, :open_replay, %{})
    assert replayable_html =~ "Replay this dead-lettered delivery?"
    assert replayable_html =~ "Sigra will create a new child delivery"
    assert replayable_html =~ "Confirm replay"

    replayable_html = render_click(replayable_view, :confirm_replay, %{})
    assert replayable_html =~ "Replay queued as a new delivery lifecycle."
    assert replayable_html =~ "Replay child"

    replay_child =
      Repo.get_by!(WebhookDelivery, replayed_from_webhook_delivery_id: replayable.id)

    assert replayable_html =~ replay_child.delivery_id

    in_flight =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-still-retrying",
        status: "retry_scheduled",
        attempt_count: 2,
        next_attempt_at: ~U[2026-05-06 14:30:00Z]
      })

    {:ok, _view, in_flight_html} =
      conn
      |> log_in_user(admin)
      |> live("/admin/webhooks/deliveries/#{in_flight.delivery_id}")

    assert in_flight_html =~ "Replay unavailable: this delivery is still in flight."
    refute in_flight_html =~ "Confirm replay"

    incomplete =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-context-missing",
        status: "dead_lettered",
        attempt_count: 3,
        dead_lettered_at: ~U[2026-05-06 15:00:00Z],
        terminal_reason: "delivery_dependency_missing"
      })

    {:ok, _view, incomplete_html} =
      conn
      |> log_in_user(admin)
      |> live("/admin/webhooks/deliveries/#{incomplete.delivery_id}")

    assert incomplete_html =~ "Replay unavailable: delivery context is incomplete."

    already_replayed =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-already-replayed",
        status: "dead_lettered",
        attempt_count: 5,
        dead_lettered_at: ~U[2026-05-06 15:30:00Z],
        terminal_reason: "retries_exhausted"
      })

    replayed_child =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-already-replayed-child",
        status: "pending",
        attempt_count: 0,
        replayed_from_webhook_delivery_id: already_replayed.id,
        replay_root_webhook_delivery_id: already_replayed.id,
        replayed_at: ~U[2026-05-06 15:31:00Z],
        replayed_by_user_id: admin.id,
        replay_source: "admin.failures_inbox"
      })

    {:ok, _view, already_replayed_html} =
      conn
      |> log_in_user(admin)
      |> live("/admin/webhooks/deliveries/#{already_replayed.delivery_id}")

    assert already_replayed_html =~ "Replay unavailable: a replay child already exists."
    assert already_replayed_html =~ replayed_child.delivery_id
  end

  test "delivery detail renders blocked-policy truth without changing replay or attempt authority", %{
    conn: conn
  } do
    admin = platform_admin_fixture()
    subscription = webhook_subscription_fixture(%{description: "Blocked policy endpoint"})

    blocked =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-policy-blocked",
        status: "dead_lettered",
        attempt_count: 1,
        dead_lettered_at: ~U[2026-05-06 16:00:00Z],
        last_error_category: "local_policy_error",
        last_error_detail: "blocked by deployment callback",
        terminal_reason: "policy_denied"
      })

    webhook_attempt_fixture(blocked, %{
      attempt_number: 1,
      retryable: false,
      started_at: ~U[2026-05-06 16:00:00Z],
      error_category: "local_policy_error",
      error_detail: "blocked by deployment callback",
      terminal_reason: "policy_denied"
    })

    {:ok, _view, html} =
      conn
      |> log_in_user(admin)
      |> live("/admin/webhooks/deliveries/#{blocked.delivery_id}")

    assert html =~ "Endpoint policy result"
    assert html =~ "Sigra blocked this delivery before any outbound request was attempted."
    assert html =~ "Reason code"
    assert html =~ "policy_denied"
    assert html =~ "Operator detail"
    assert html =~ "blocked by deployment callback"
    assert html =~ "This denial came from Sigra"
    assert html =~ "local webhook endpoint policy"
    assert html =~ "not from the remote receiver."
    assert html =~ "Replay delivery"
    assert html =~ "Attempt timeline"
  end
end
