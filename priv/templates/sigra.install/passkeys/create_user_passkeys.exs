defmodule <%= repo_module %>.Migrations.CreateUserPasskeys do
  use Ecto.Migration

  def change do
    create table(:user_passkeys<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :credential_id, :binary, null: false
      add :public_key, :binary, null: false
      add :sign_count, :integer, default: 0, null: false
      add :aaguid, :uuid
      add :nickname, :string
      add :device_hint, :string
      add :transports, {:array, :string}, default: []
      add :rp_id, :string
      add :last_used_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:user_passkeys, [:user_id])
    create unique_index(:user_passkeys, [:credential_id])
  end
end
