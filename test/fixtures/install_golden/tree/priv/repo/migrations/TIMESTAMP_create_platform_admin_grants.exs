
defmodule SigraInstallGoldenTmp.Repo.Migrations.CreatePlatformAdminGrants do
  use Ecto.Migration

  @auth_prefix "auth"
  @prefix_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []


  def change do
    create table(:sigra_platform_admin_grants, Keyword.merge(@prefix_opts, primary_key: false)) do
      add :id, :binary_id, primary_key: true
      add :user_id,
          references(:users,
            type: :binary_id,
            on_delete: :delete_all,
            prefix: @auth_prefix
          ),
          null: false
      add :revoked_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:sigra_platform_admin_grants, [:user_id], @prefix_opts)
    create index(:sigra_platform_admin_grants, [:revoked_at], @prefix_opts)
  end
end
