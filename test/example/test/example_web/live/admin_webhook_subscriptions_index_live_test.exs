defmodule ExampleWeb.AdminWebhookSubscriptionsIndexLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  import ExampleWeb.ConnCaseHelpers
  import Example.WebhookAdminLiveFixtures

  alias Example.Accounts
  alias Example.Repo
  alias Example.Accounts.WebhookSubscription

  test "index uses delivery_state params and filters retrying rows before pagination", %{
    conn: conn
  } do
    admin = platform_admin_fixture()

    matching =
      webhook_subscription_fixture(%{
        description: "Retrying endpoint",
        endpoint_url: "https://example.com/webhooks/retrying",
        enabled: false
      })
      |> set_subscription_inserted_at!(~U[2026-05-06 09:00:00Z])

    dead_lettered =
      webhook_subscription_fixture(%{
        description: "Dead letter endpoint",
        endpoint_url: "https://example.com/webhooks/dead-letter"
      })
      |> set_subscription_inserted_at!(~U[2026-05-06 10:00:00Z])

    healthy =
      webhook_subscription_fixture(%{
        description: "Healthy endpoint",
        endpoint_url: "https://example.com/webhooks/healthy"
      })
      |> set_subscription_inserted_at!(~U[2026-05-06 11:00:00Z])

    _matching_delivery =
      webhook_delivery_fixture(matching, %{
        delivery_id: "needs-retry",
        status: "retry_scheduled",
        attempt_count: 2,
        last_http_status: 500,
        next_attempt_at: ~U[2026-05-06 12:00:00Z],
        inserted_at: ~U[2026-05-06 12:00:00Z]
      })

    _dead_letter_delivery =
      webhook_delivery_fixture(dead_lettered, %{
        delivery_id: "dead-letter",
        status: "dead_lettered",
        attempt_count: 6,
        terminal_reason: "retries_exhausted",
        inserted_at: ~U[2026-05-06 12:10:00Z]
      })

    _healthy_delivery =
      webhook_delivery_fixture(healthy, %{
        delivery_id: "delivered-ok",
        status: "delivered",
        attempt_count: 1,
        last_http_status: 204,
        inserted_at: ~U[2026-05-06 12:15:00Z]
      })

    {:ok, view, html} =
      conn
      |> log_in_user(admin)
      |> live("/admin/webhooks?delivery_state=retrying&q=Retrying&page_size=1")

    assert html =~ "Webhook subscriptions"
    assert html =~ "View failures and retrying deliveries"
    assert html =~ "Delivery state"
    refute html =~ ~s(name="status")
    assert html =~ ~s(name="delivery_state")
    assert html =~ ~s(value="Retrying")
    assert html =~ "Retrying endpoint"
    refute html =~ "Dead letter endpoint"
    refute html =~ "Healthy endpoint"

    html = render_click(view, :open_create, %{})

    assert html =~ "Create webhook subscription"
    assert html =~ "User lifecycle"
    assert html =~ "All current Sigra webhook events"
    assert html =~ "Included event types"

    html = render_click(view, :apply_preset, %{"preset" => "all"})

    assert html =~ ~s(value="user.created")
    assert html =~ ~s(value="session.created")

    html =
      view
      |> form("#webhook-subscription-form",
        subscription: %{
          endpoint_url: "https://example.com/webhooks/new-subscription",
          description: "New subscription",
          enabled: "true",
          event_types: ["user.created", "session.created"]
        }
      )
      |> render_submit()

    assert html =~ "Webhook subscription created."

    created =
      Repo.get_by!(WebhookSubscription,
        endpoint_url: "https://example.com/webhooks/new-subscription"
      )

    assert created.event_types == ["user.created", "session.created"]

    assert {:ok, {rows, _meta, _normalized}} =
             Accounts.list_admin_webhook_subscriptions(global_admin_scope(admin), %{
               "q" => "New subscription"
             })

    assert Enum.any?(rows, &(&1.subscription.id == created.id))
  end

  test "index uses latest delivery state instead of historical dead-letter state", %{conn: conn} do
    admin = platform_admin_fixture()

    recovered =
      webhook_subscription_fixture(%{
        description: "Recovered endpoint",
        endpoint_url: "https://example.com/webhooks/recovered"
      })
      |> set_subscription_inserted_at!(~U[2026-05-06 09:30:00Z])

    active_dead_letter =
      webhook_subscription_fixture(%{
        description: "Still dead lettered",
        endpoint_url: "https://example.com/webhooks/still-dead-lettered"
      })
      |> set_subscription_inserted_at!(~U[2026-05-06 09:45:00Z])

    _older_dead_letter =
      webhook_delivery_fixture(recovered, %{
        delivery_id: "recovered-old-dead-letter",
        status: "dead_lettered",
        attempt_count: 5,
        terminal_reason: "retries_exhausted",
        inserted_at: ~U[2026-05-06 10:00:00Z]
      })

    _newer_success =
      webhook_delivery_fixture(recovered, %{
        delivery_id: "recovered-success",
        status: "delivered",
        attempt_count: 1,
        last_http_status: 204,
        inserted_at: ~U[2026-05-06 10:05:00Z]
      })

    _active_dead_letter =
      webhook_delivery_fixture(active_dead_letter, %{
        delivery_id: "still-dead-lettered",
        status: "dead_lettered",
        attempt_count: 6,
        terminal_reason: "retries_exhausted",
        inserted_at: ~U[2026-05-06 10:10:00Z]
      })

    {:ok, _view, html} =
      conn
      |> log_in_user(admin)
      |> live("/admin/webhooks?delivery_state=dead_lettered")

    assert html =~ "Delivery state"
    assert html =~ "Still dead lettered"
    refute html =~ "Recovered endpoint"
  end
end
