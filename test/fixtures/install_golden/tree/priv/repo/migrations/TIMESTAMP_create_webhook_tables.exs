defmodule SigraInstallGoldenTmp.Repo.Migrations.CreateWebhookTables do
  use Ecto.Migration

  def change do
    create table(:webhook_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :endpoint_url, :string, null: false
      add :event_types, {:array, :string}, null: false, default: []
      add :enabled, :boolean, null: false, default: true
      add :description, :string
      add :signing_secret, :binary, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:webhook_subscriptions, [:enabled])

    create table(:webhook_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :event_id, :string, null: false
      add :type, :string, null: false
      add :schema_version, :string, null: false
      add :occurred_at, :utc_datetime_usec, null: false
      add :payload, :map, null: false, default: %{}
      add :actor_id, :binary_id
      add :actor_type, :string
      add :organization_id, :binary_id
      add :request_id, :string

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:webhook_events, [:event_id])
    create index(:webhook_events, [:type, :occurred_at])

    create table(:webhook_deliveries, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :delivery_id, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :endpoint_url, :string, null: false
      add :dispatched_at, :utc_datetime_usec
      add :webhook_subscription_id,
          references(:webhook_subscriptions, type: :binary_id, on_delete: :delete_all),
          null: false

      add :webhook_event_id,
          references(:webhook_events, type: :binary_id, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:webhook_deliveries, [:delivery_id])
    create index(:webhook_deliveries, [:status])
    create index(:webhook_deliveries, [:webhook_subscription_id])
    create index(:webhook_deliveries, [:webhook_event_id])
  end
end
