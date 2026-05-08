defmodule ExampleWeb.AdminWebhookFailuresLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  import ExampleWeb.ConnCaseHelpers
  import Example.WebhookAdminLiveFixtures

  test "failures inbox keeps replay shortcuts narrow and truthful", %{
    conn: conn
  } do
    admin = platform_admin_fixture()
    subscription = webhook_subscription_fixture(%{description: "Failure endpoint"})

    retrying =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-retrying",
        status: "retry_scheduled",
        attempt_count: 2,
        next_attempt_at: ~U[2026-05-06 11:00:00Z]
      })

    replayable =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-dead-letter",
        status: "dead_lettered",
        attempt_count: 6,
        dead_lettered_at: ~U[2026-05-06 11:05:00Z],
        terminal_reason: "retries_exhausted"
      })

    already_replayed =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-already-replayed",
        status: "dead_lettered",
        attempt_count: 5,
        dead_lettered_at: ~U[2026-05-06 11:10:00Z],
        terminal_reason: "retries_exhausted"
      })

    replay_child =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-already-replayed-child",
        status: "pending",
        attempt_count: 0,
        replayed_from_webhook_delivery_id: already_replayed.id,
        replay_root_webhook_delivery_id: already_replayed.id,
        replayed_at: ~U[2026-05-06 11:11:00Z],
        replayed_by_user_id: admin.id,
        replay_source: "admin.failures_inbox"
      })

    {:ok, _view, retrying_html} =
      conn
      |> log_in_user(admin)
      |> live("/admin/webhooks/failures?delivery_state=retrying")

    assert retrying_html =~ "Webhook failures"
    assert retrying_html =~ retrying.delivery_id
    assert retrying_html =~ "Replay unavailable: this delivery is still in flight."
    refute retrying_html =~ ">Replay<"
    refute retrying_html =~ replayable.delivery_id

    {:ok, _view, dead_letter_html} =
      conn
      |> log_in_user(admin)
      |> live("/admin/webhooks/failures?delivery_state=dead_lettered")

    assert dead_letter_html =~ replayable.delivery_id
    assert dead_letter_html =~ already_replayed.delivery_id
    assert dead_letter_html =~ replay_child.delivery_id
    assert dead_letter_html =~ "Replay"
    assert dead_letter_html =~ "Replay available"
    assert dead_letter_html =~ "Already replayed"
    assert dead_letter_html =~ "Open replay child"
    assert dead_letter_html =~ replay_child.delivery_id
    assert dead_letter_html =~ "Open delivery"
    refute dead_letter_html =~ "queue control"
  end

  test "failures inbox shows compact blocked-policy truth without adding new actions", %{
    conn: conn
  } do
    admin = platform_admin_fixture()
    subscription = webhook_subscription_fixture(%{description: "Blocked endpoint"})

    blocked =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "delivery-policy-row",
        status: "dead_lettered",
        attempt_count: 1,
        dead_lettered_at: ~U[2026-05-06 12:15:00Z],
        last_error_category: "local_policy_error",
        last_error_detail: "blocked by deployment callback",
        terminal_reason: "policy_denied"
      })

    {:ok, _view, html} =
      conn
      |> log_in_user(admin)
      |> live("/admin/webhooks/failures?delivery_state=dead_lettered")

    assert html =~ blocked.delivery_id
    assert html =~ "Blocked by local policy"
    assert html =~ "Policy reason"
    assert html =~ "policy_denied"
    assert html =~ "blocked by deployment callback"
    assert html =~ "Open delivery"
    refute html =~ "Open policy"
    refute html =~ "Policy details"
  end
end
