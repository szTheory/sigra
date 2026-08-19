defmodule Example.Repo.Migrations.CreateLearningTwinTables do
  use Ecto.Migration

  @prefix_opts [prefix: "auth"]

  def change do
    create table(:learning_twin_leases, Keyword.merge(@prefix_opts, primary_key: false)) do
      add(:id, :binary_id, primary_key: true)

      add(
        :user_id,
        references(:users, Keyword.merge(@prefix_opts, type: :binary_id, on_delete: :delete_all)),
        null: false
      )

      add(:account_partition, :string, null: false)
      add(:issued_at, :utc_datetime_usec, null: false)
      add(:expires_at, :utc_datetime_usec, null: false)
      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:learning_twin_leases, [:account_partition], @prefix_opts))
    create(index(:learning_twin_leases, [:user_id, :expires_at], @prefix_opts))

    create table(:learning_twin_replay_receipts, Keyword.merge(@prefix_opts, primary_key: false)) do
      add(:id, :binary_id, primary_key: true)

      add(
        :user_id,
        references(:users, Keyword.merge(@prefix_opts, type: :binary_id, on_delete: :delete_all)),
        null: false
      )

      add(:account_partition, :string, null: false)
      add(:client_mutation_id, :string, null: false)
      add(:idempotency_key, :string, null: false)
      add(:base_checkpoint, :string, null: false)
      add(:outcome, :string, null: false)
      add(:terminal_at, :utc_datetime_usec, null: false)
      timestamps(type: :utc_datetime_usec)
    end

    create(
      unique_index(
        :learning_twin_replay_receipts,
        [:account_partition, :idempotency_key],
        @prefix_opts
      )
    )

    create(index(:learning_twin_replay_receipts, [:user_id, :terminal_at], @prefix_opts))
  end
end
