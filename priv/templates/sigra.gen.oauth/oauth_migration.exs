<% auth_prefix = Keyword.get(binding(), :auth_prefix) %>
defmodule <%= context_module %>.Repo.Migrations.CreateUserIdentities do
  use Ecto.Migration
  @auth_prefix <%= inspect(auth_prefix) %>
  @prefix_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []
  @ref_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []

  def change do
    create table(:user_identities, Keyword.merge(@prefix_opts, <%= if binary_id, do: "[primary_key: false]", else: "[]" %>)) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:users, Keyword.merge(@ref_opts, <%= if binary_id, do: "[type: :binary_id, on_delete: :delete_all]", else: "[on_delete: :delete_all]" %>)), null: false
      add :provider, :string, null: false
      add :provider_uid, :string, null: false
      add :encrypted_access_token, :binary
      add :encrypted_refresh_token, :binary
      add :token_expires_at, :utc_datetime
      add :provider_email, :string
      add :provider_name, :string
      add :provider_avatar_url, :string
      add :metadata, :map, default: %{}
      add :last_used_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_identities, [:user_id, :provider], @prefix_opts)
    create unique_index(:user_identities, [:provider, :provider_uid], @prefix_opts)
    create index(:user_identities, [:user_id], @prefix_opts)
  end
end
