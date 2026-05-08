defmodule <%= app_module %>.Repo.Migrations.CreateWebhookTables do
  use Ecto.Migration

  def change do
    create table(:webhook_subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :endpoint_url, :string, null: false
      add :event_types, {:array, :string}, null: false, default: []
      add :enabled, :boolean, null: false, default: true
      add :description, :string
      add :signing_secret, :binary, null: false
      add :next_signing_secret, :binary
      add :rotation_state, :string, null: false, default: "stable"
      add :rotation_prepared_at, :utc_datetime_usec
      add :rotation_overlap_started_at, :utc_datetime_usec
      add :rotation_retire_after_at, :utc_datetime_usec
      add :rotation_completed_at, :utc_datetime_usec
      add :rotation_last_changed_by_user_id, :binary_id
      add :signing_secret_fingerprint, :string
      add :next_signing_secret_fingerprint, :string

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
      add :attempt_count, :integer, null: false, default: 0
      add :endpoint_url, :string, null: false
      add :dispatched_at, :utc_datetime_usec
      add :last_attempted_at, :utc_datetime_usec
      add :next_attempt_at, :utc_datetime_usec
      add :last_http_status, :integer
      add :last_error_category, :string
      add :last_error_detail, :string
      add :dead_lettered_at, :utc_datetime_usec
      add :terminal_reason, :string
      add :replayed_from_webhook_delivery_id, references(:webhook_deliveries, type: :binary_id)
      add :replay_root_webhook_delivery_id, references(:webhook_deliveries, type: :binary_id)
      add :replayed_at, :utc_datetime_usec
      add :replayed_by_user_id, :binary_id
      add :replay_source, :string

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
    create index(:webhook_deliveries, [:next_attempt_at])
    create index(:webhook_deliveries, [:dead_lettered_at])
    create index(:webhook_deliveries, [:replay_root_webhook_delivery_id])
    create index(:webhook_deliveries, [:webhook_subscription_id])
    create index(:webhook_deliveries, [:webhook_event_id])
    create unique_index(:webhook_deliveries, [:replayed_from_webhook_delivery_id],
             where: "replayed_from_webhook_delivery_id IS NOT NULL",
             name: :webhook_deliveries_replayed_from_unique_index
           )

    create table(:webhook_delivery_attempts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :delivery_id, :string, null: false
      add :attempt_number, :integer, null: false
      add :endpoint_url, :string, null: false
      add :started_at, :utc_datetime_usec, null: false
      add :finished_at, :utc_datetime_usec
      add :response_status, :integer
      add :retryable, :boolean, null: false, default: false
      add :retry_after_seconds, :integer
      add :error_category, :string
      add :error_detail, :string
      add :terminal_reason, :string

      add :webhook_delivery_id,
          references(:webhook_deliveries, type: :binary_id, on_delete: :delete_all)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:webhook_delivery_attempts, [:delivery_id, :attempt_number])
    create index(:webhook_delivery_attempts, [:webhook_delivery_id, :attempt_number])
    create index(:webhook_delivery_attempts, [:response_status])
    create index(:webhook_delivery_attempts, [:terminal_reason])
    create index(:webhook_delivery_attempts, [:retry_after_seconds])
  end
end
