defmodule Example.Repo.Migrations.AddWebhookReplayFields do
  use Ecto.Migration

  def change do
    alter table(:webhook_deliveries) do
      add_if_not_exists :replayed_from_webhook_delivery_id,
                        references(:webhook_deliveries, type: :binary_id)

      add_if_not_exists :replay_root_webhook_delivery_id,
                        references(:webhook_deliveries, type: :binary_id)

      add_if_not_exists :replayed_at, :utc_datetime_usec
      add_if_not_exists :replayed_by_user_id, :binary_id
      add_if_not_exists :replay_source, :string
    end

    create_if_not_exists index(:webhook_deliveries, [:replay_root_webhook_delivery_id])

    create_if_not_exists unique_index(
                          :webhook_deliveries,
                          [:replayed_from_webhook_delivery_id],
                          where: "replayed_from_webhook_delivery_id IS NOT NULL",
                          name: :webhook_deliveries_replayed_from_unique_index
                        )
  end
end
