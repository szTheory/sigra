defmodule <%= app_module %>.Repo.Migrations.CreateServiceAccounts do
  use Ecto.Migration

  def change do
    create table(:service_accounts<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>
      add :id, :binary_id, primary_key: true
<% end %>
      add :organization_id, references(:organizations,<%= if binary_id do %> type: :binary_id,<% end %> on_delete: :delete_all), null: false
      add :created_by_user_id, references(:users,<%= if binary_id do %> type: :binary_id,<% end %> on_delete: :nilify_all)
      add :name, :string, null: false
      add :scopes, {:array, :string}, null: false, default: []
      add :role, :string
      add :token_epoch, :integer, null: false, default: 0
      add :revoked_at, :utc_datetime_usec
      add :last_used_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:service_accounts, [:organization_id])
    create unique_index(:service_accounts, [:organization_id, :name], name: :service_accounts_organization_id_name_index)

    create table(:service_account_credentials<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>
      add :id, :binary_id, primary_key: true
<% end %>
      add :service_account_id, references(:service_accounts,<%= if binary_id do %> type: :binary_id,<% end %> on_delete: :delete_all), null: false
      add :client_id, :string, null: false
      add :hashed_client_secret, :binary, null: false
      add :expires_at, :utc_datetime_usec
      add :last_used_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:service_account_credentials, [:client_id])
    create index(:service_account_credentials, [:service_account_id], name: :service_account_credentials_active_index, where: "revoked_at IS NULL")
  end
end
