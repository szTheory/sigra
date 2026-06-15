defmodule Example.Repo.Migrations.CreateUserPasskeys do
  use Ecto.Migration

  @prefix_opts [prefix: "auth"]
  @ref_opts [prefix: "auth"]

  def change do
    create table(:user_passkeys, Keyword.merge(@prefix_opts, primary_key: false)) do
      add(:id, :binary_id, primary_key: true)

      add(
        :user_id,
        references(:users, Keyword.merge(@ref_opts, type: :binary_id, on_delete: :delete_all)),
        null: false
      )

      add(:credential_id, :binary, null: false)
      add(:public_key, :binary, null: false)
      add(:sign_count, :integer, default: 0, null: false)
      add(:aaguid, :uuid)
      add(:nickname, :string)
      add(:device_hint, :string)
      add(:transports, {:array, :string}, default: [])
      add(:rp_id, :string)
      add(:last_used_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:user_passkeys, [:user_id], @prefix_opts))
    create(unique_index(:user_passkeys, [:credential_id], @prefix_opts))
  end
end
