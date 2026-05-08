defmodule ExampleWeb.AccountsWebhookProofTest do
  use Example.DataCase, async: false

  import Example.WebhookAdminLiveFixtures

  alias Example.Accounts
  alias Example.Accounts.{WebhookDelivery, WebhookEvent}
  alias Example.Repo
  alias Oban.Job
  alias Sigra.Webhooks

  setup do
    ensure_replay_delivery_schema!()
    :ok
  end

  test "register_user emits a real user.created delivery under webhook-enabled config" do
    subscription =
      webhook_subscription_fixture(%{
        endpoint_url: "http://localhost:4002/webhooks/sigra",
        signing_secret: String.duplicate("k", 32)
      })

    {:ok, user} =
      Accounts.register_user(%{
        email: "proof-user-#{System.unique_integer([:positive])}@example.test",
        password: "CorrectHorseBatteryStaple123!"
      })

    assert user.email =~ "proof-user-"

    assert %WebhookEvent{type: "user.created"} = event =
             Repo.get_by!(WebhookEvent, type: "user.created", id: delivery_event_id(subscription))

    assert %WebhookDelivery{} = delivery =
             Repo.get_by!(WebhookDelivery,
               webhook_subscription_id: subscription.id,
               webhook_event_id: event.id
             )

    assert delivery.status == "pending"
    assert delivery.attempt_count == 0

    assert job_count_for_delivery_id(delivery.delivery_id) >= 1
  end

  test "rotation lifecycle produces pre-overlap, overlap, and post-retirement deliveries" do
    subscription =
      webhook_subscription_fixture(%{
        endpoint_url: "http://localhost:4002/webhooks/sigra",
        signing_secret: String.duplicate("k", 32)
      })

    assert {:ok, user_one} =
             Accounts.register_user(%{
               email: "pre-rotation-#{System.unique_integer([:positive])}@example.test",
               password: "CorrectHorseBatteryStaple123!"
             })

    assert user_one.email =~ "pre-rotation-"

    config = Accounts.sigra_config()
    scope = %{user: %{id: Ecto.UUID.generate()}}

    assert {:ok, prepared} = Webhooks.prepare_secret(config, subscription.id, scope: scope)

    assert {:ok, _overlap} =
             Webhooks.start_secret_overlap(config, prepared.id,
               scope: scope,
               retire_after_at: DateTime.utc_now() |> DateTime.add(1800, :second) |> DateTime.truncate(:second)
             )

    assert {:ok, user_two} =
             Accounts.register_user(%{
               email: "overlap-#{System.unique_integer([:positive])}@example.test",
               password: "CorrectHorseBatteryStaple123!"
             })

    assert user_two.email =~ "overlap-"

    assert {:ok, _completed} = Webhooks.complete_secret_rotation(config, subscription.id, scope: scope)

    assert {:ok, user_three} =
             Accounts.register_user(%{
               email: "post-rotation-#{System.unique_integer([:positive])}@example.test",
               password: "CorrectHorseBatteryStaple123!"
             })

    assert user_three.email =~ "post-rotation-"

    deliveries =
      Repo.all(
        from delivery in WebhookDelivery,
          where: delivery.webhook_subscription_id == ^subscription.id,
          order_by: [asc: delivery.inserted_at, asc: delivery.id]
      )

    assert length(deliveries) == 3
    assert Enum.all?(deliveries, &(&1.status == "pending"))
    assert delivery_event_count(subscription) == 3
    assert job_count_for_delivery_ids(Enum.map(deliveries, & &1.delivery_id)) >= 3
  end

  test "proof bundle correlates source and replay delivery lineage with receiver verification" do
    admin = platform_admin_fixture()

    subscription =
      webhook_subscription_fixture(%{
        endpoint_url: "http://localhost:4002/webhooks/sigra",
        signing_secret: String.duplicate("p", 32)
      })

    source =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "proof-source-delivery",
        status: "dead_lettered",
        dead_lettered_at: ~U[2026-05-07 12:00:00Z],
        terminal_reason: "http_5xx"
      })
      |> Repo.preload(:webhook_event)

    replay =
      webhook_delivery_fixture(subscription, %{
        delivery_id: "proof-replay-delivery",
        status: "delivered",
        replayed_from_webhook_delivery_id: source.id,
        replay_root_webhook_delivery_id: source.id,
        replayed_at: ~U[2026-05-07 12:20:00Z],
        replayed_by_user_id: admin.id,
        replay_source: "admin.delivery_detail",
        webhook_event: source.webhook_event
      })
      |> Repo.preload(:webhook_event)

    raw_body = Jason.encode!(source.webhook_event.payload)

    assert {:ok, _receipt, :created} =
             Accounts.record_webhook_receipt(source.delivery_id, raw_body, 1_746_622_800)

    assert {:ok, _receipt, :created} =
             Accounts.record_webhook_receipt(replay.delivery_id, raw_body, 1_746_623_100)

    source_bundle = Accounts.get_webhook_proof_bundle(source.delivery_id)
    replay_bundle = Accounts.get_webhook_proof_bundle(replay.delivery_id)

    assert source_bundle.lineage.source_delivery_id == source.delivery_id
    assert source_bundle.lineage.replay_delivery_id == replay.delivery_id
    assert source_bundle.lineage.root_delivery_id == source.delivery_id
    assert source_bundle.receiver_verification.source_delivery.verified_at
    assert source_bundle.receiver_verification.replay_delivery.verified_at

    assert replay_bundle.lineage.source_delivery_id == source.delivery_id
    assert replay_bundle.lineage.replay_delivery_id == replay.delivery_id
    assert replay_bundle.lineage.root_delivery_id == source.delivery_id
    assert replay_bundle.receiver_verification.current_delivery.verified_at
    assert replay_bundle.receiver_verification.source_delivery.signature_timestamp == 1_746_622_800
    assert replay_bundle.receiver_verification.replay_delivery.signature_timestamp == 1_746_623_100
  end

  defp delivery_event_id(subscription) do
    Repo.one!(
      from delivery in WebhookDelivery,
        where: delivery.webhook_subscription_id == ^subscription.id,
        select: delivery.webhook_event_id,
        limit: 1
    )
  end

  defp delivery_event_count(subscription) do
    Repo.aggregate(
      from(delivery in WebhookDelivery,
        where: delivery.webhook_subscription_id == ^subscription.id,
        select: delivery.webhook_event_id,
        distinct: true
      ),
      :count
    )
  end

  defp job_count_for_delivery_id(delivery_id) do
    Repo.aggregate(
      from(job in Job,
        where:
          job.queue == "sigra_webhooks" and
            fragment("?->>'delivery_id' = ?", job.args, ^delivery_id)
      ),
      :count
    )
  end

  defp job_count_for_delivery_ids(delivery_ids) do
    Repo.aggregate(
      from(job in Job,
        where:
          job.queue == "sigra_webhooks" and
            fragment("?->>'delivery_id' = ANY(?)", job.args, type(^delivery_ids, {:array, :string}))
      ),
      :count
    )
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
