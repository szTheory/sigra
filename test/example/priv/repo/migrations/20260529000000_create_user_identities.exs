defmodule Example.Repo.Migrations.CreateUserIdentities do
  use Ecto.Migration

  @prefix_opts [prefix: "auth"]
  @ref_opts [prefix: "auth"]

  def change do
    create_if_not_exists table(:user_identities, Keyword.merge(@prefix_opts, primary_key: false)) do
      add(:id, :binary_id, primary_key: true)

      add(
        :user_id,
        references(:users, Keyword.merge(@ref_opts, type: :binary_id, on_delete: :delete_all)),
        null: false
      )

      add(:provider, :string, null: false)
      add(:provider_uid, :string, null: false)
      add(:encrypted_access_token, :binary)
      add(:encrypted_refresh_token, :binary)
      add(:token_expires_at, :utc_datetime)
      add(:provider_email, :string)
      add(:provider_name, :string)
      add(:provider_avatar_url, :string)
      add(:metadata, :map, default: %{})
      add(:last_used_at, :utc_datetime)

      timestamps(type: :utc_datetime)
    end

    create_if_not_exists(unique_index(:user_identities, [:user_id, :provider], @prefix_opts))
    create_if_not_exists(unique_index(:user_identities, [:provider, :provider_uid], @prefix_opts))
    create_if_not_exists(index(:user_identities, [:user_id], @prefix_opts))
  end
end
