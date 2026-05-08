defmodule Example.Repo.Migrations.AddWebhookRotationFields do
  use Ecto.Migration

  def change do
    alter table(:webhook_subscriptions) do
      add_if_not_exists :next_signing_secret, :binary
      add_if_not_exists :rotation_state, :string, null: false, default: "stable"
      add_if_not_exists :rotation_prepared_at, :utc_datetime_usec
      add_if_not_exists :rotation_overlap_started_at, :utc_datetime_usec
      add_if_not_exists :rotation_retire_after_at, :utc_datetime_usec
      add_if_not_exists :rotation_completed_at, :utc_datetime_usec
      add_if_not_exists :rotation_last_changed_by_user_id, :binary_id
      add_if_not_exists :signing_secret_fingerprint, :string
      add_if_not_exists :next_signing_secret_fingerprint, :string
    end
  end
end
