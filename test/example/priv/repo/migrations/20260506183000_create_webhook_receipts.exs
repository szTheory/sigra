defmodule Example.Repo.Migrations.CreateWebhookReceipts do
  use Ecto.Migration

  def change do
    create table(:webhook_receipts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :delivery_id, :string, null: false
      add :event_id, :string, null: false
      add :event_type, :string, null: false
      add :payload, :map, null: false, default: %{}
      add :raw_body_sha256, :string, null: false
      add :signature_timestamp, :bigint, null: false
      add :verified_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:webhook_receipts, [:delivery_id])
    create index(:webhook_receipts, [:event_type, :verified_at])
  end
end
