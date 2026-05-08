defmodule Example.WebhookAdminLiveFixtures do
  @moduledoc false

  import Ecto.Query

  alias Example.Accounts
  alias Example.Accounts.{WebhookDelivery, WebhookDeliveryAttempt, WebhookEvent, WebhookSubscription}
  alias Example.Repo
  alias Sigra.Admin.Scope

  def platform_admin_fixture(attrs \\ %{}) do
    Example.AccountsFixtures.user_fixture(
      Map.merge(
        %{
          email: "platform-admin+#{System.unique_integer([:positive])}@example.com",
          display_name: "Platform Admin"
        },
        attrs
      )
    )
  end

  def global_admin_scope(user) do
    %Scope{
      mode: :global,
      scope: Example.Accounts.Scope.for_user(user),
      organization: nil,
      organization_id: nil,
      organization_slug: nil,
      platform_admin?: true,
      admin_org_ids: []
    }
  end

  def webhook_subscription_fixture(attrs \\ %{}) do
    defaults = %{
      endpoint_url: "https://example.com/webhooks/#{System.unique_integer([:positive])}",
      description: "Webhook subscription #{System.unique_integer([:positive])}",
      enabled: true,
      signing_secret: String.duplicate("s", 32),
      event_types: ["user.created"]
    }

    {:ok, subscription} =
      defaults
      |> Map.merge(attrs)
      |> Accounts.create_webhook_subscription()

    subscription
  end

  def set_subscription_inserted_at!(subscription, inserted_at) do
    from(s in WebhookSubscription, where: s.id == ^subscription.id)
    |> Repo.update_all(set: [inserted_at: inserted_at, updated_at: inserted_at])

    Repo.get!(WebhookSubscription, subscription.id)
  end

  def webhook_delivery_fixture(subscription, attrs \\ %{}) do
    ensure_replay_delivery_schema!()

    event =
      Map.get_lazy(attrs, :webhook_event, fn ->
        %WebhookEvent{}
        |> WebhookEvent.changeset(%{
          event_id: Ecto.UUID.generate(),
          type: Map.get(attrs, :event_type, "user.created"),
          schema_version: "2026-05-06",
          occurred_at: Map.get(attrs, :occurred_at, ~U[2026-05-06 09:00:00Z]),
          payload: %{
            "id" => Ecto.UUID.generate(),
            "type" => Map.get(attrs, :event_type, "user.created")
          }
        })
        |> Repo.insert!()
      end)

    inserted_at = Map.get(attrs, :inserted_at, ~U[2026-05-06 09:00:00Z])

    %WebhookDelivery{}
    |> WebhookDelivery.changeset(%{
      delivery_id: Map.get(attrs, :delivery_id, Ecto.UUID.generate()),
      status: Map.get(attrs, :status, "pending"),
      attempt_count: Map.get(attrs, :attempt_count, 0),
      endpoint_url: Map.get(attrs, :endpoint_url, subscription.endpoint_url),
      dispatched_at: Map.get(attrs, :dispatched_at),
      last_attempted_at: Map.get(attrs, :last_attempted_at),
      next_attempt_at: Map.get(attrs, :next_attempt_at),
      last_http_status: Map.get(attrs, :last_http_status),
      last_error_category: Map.get(attrs, :last_error_category),
      last_error_detail: Map.get(attrs, :last_error_detail),
      dead_lettered_at: Map.get(attrs, :dead_lettered_at),
      terminal_reason: Map.get(attrs, :terminal_reason),
      replayed_from_webhook_delivery_id: Map.get(attrs, :replayed_from_webhook_delivery_id),
      replay_root_webhook_delivery_id: Map.get(attrs, :replay_root_webhook_delivery_id),
      replayed_at: Map.get(attrs, :replayed_at),
      replayed_by_user_id: Map.get(attrs, :replayed_by_user_id),
      replay_source: Map.get(attrs, :replay_source),
      webhook_subscription_id: subscription.id,
      webhook_event_id: Map.get(attrs, :webhook_event_id, event.id)
    })
    |> Repo.insert!()
    |> then(fn delivery ->
      from(d in WebhookDelivery, where: d.id == ^delivery.id)
      |> Repo.update_all(set: [inserted_at: inserted_at, updated_at: inserted_at])

      Repo.get!(WebhookDelivery, delivery.id)
    end)
  end

  def webhook_attempt_fixture(delivery, attrs \\ %{}) do
    %WebhookDeliveryAttempt{}
    |> WebhookDeliveryAttempt.changeset(%{
      delivery_id: delivery.delivery_id,
      attempt_number: Map.get(attrs, :attempt_number, 1),
      endpoint_url: Map.get(attrs, :endpoint_url, delivery.endpoint_url),
      started_at: Map.get(attrs, :started_at, ~U[2026-05-06 09:00:00Z]),
      finished_at: Map.get(attrs, :finished_at),
      response_status: Map.get(attrs, :response_status),
      retryable: Map.get(attrs, :retryable, false),
      retry_after_seconds: Map.get(attrs, :retry_after_seconds),
      error_category: Map.get(attrs, :error_category),
      error_detail: Map.get(attrs, :error_detail),
      terminal_reason: Map.get(attrs, :terminal_reason),
      webhook_delivery_id: delivery.id
    })
    |> Repo.insert!()
  end

  defp ensure_replay_delivery_schema! do
    Ecto.Adapters.SQL.query!(
      Repo,
      """
      ALTER TABLE webhook_deliveries
      ADD COLUMN IF NOT EXISTS replayed_from_webhook_delivery_id uuid REFERENCES webhook_deliveries(id),
      ADD COLUMN IF NOT EXISTS replay_root_webhook_delivery_id uuid REFERENCES webhook_deliveries(id),
      ADD COLUMN IF NOT EXISTS replayed_at timestamp(6) without time zone,
      ADD COLUMN IF NOT EXISTS replayed_by_user_id uuid,
      ADD COLUMN IF NOT EXISTS replay_source text
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      Repo,
      """
      CREATE INDEX IF NOT EXISTS webhook_deliveries_replay_root_index
      ON webhook_deliveries (replay_root_webhook_delivery_id)
      """,
      []
    )

    Ecto.Adapters.SQL.query!(
      Repo,
      """
      CREATE UNIQUE INDEX IF NOT EXISTS webhook_deliveries_replayed_from_unique_index
      ON webhook_deliveries (replayed_from_webhook_delivery_id)
      WHERE replayed_from_webhook_delivery_id IS NOT NULL
      """,
      []
    )
  end
end
