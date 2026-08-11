defmodule Example.Repo.Migrations.CreateCrosswakeContinuations do
  use Ecto.Migration

  @prefix_opts [prefix: "auth"]

  def change do
    create table(:crosswake_continuations, Keyword.merge(@prefix_opts, primary_key: false)) do
      add(:id, :binary_id, primary_key: true)
      add(:handle_digest, :binary, null: false)
      add(:state_digest, :binary, null: false)
      add(:pkce_challenge_digest, :binary, null: false)
      add(:return_ref, :string, null: false)
      add(:session_ref, :string, null: false)
      add(:subject_ref, :string, null: false)
      add(:session_version, :bigint, null: false)
      add(:route_id, :string, null: false)
      add(:return_route_id, :string, null: false)
      add(:issued_at, :utc_datetime_usec, null: false)
      add(:expires_at, :utc_datetime_usec, null: false)
      add(:consumed_at, :utc_datetime_usec)
      add(:outcome, :string)
      add(:reason, :string)
      add(:audit_correlation_ref, :string, null: false)
      timestamps(type: :utc_datetime)
    end

    create(unique_index(:crosswake_continuations, [:handle_digest], @prefix_opts))
    create(index(:crosswake_continuations, [:expires_at], @prefix_opts))
    create(index(:crosswake_continuations, [:consumed_at], @prefix_opts))
  end
end
