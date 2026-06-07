<% auth_prefix = Keyword.get(binding(), :auth_prefix) %>
defmodule <%= repo_module %>.Migrations.CreateUserPasskeys do
  use Ecto.Migration
<%= if adapter == :postgres do %>
  @auth_prefix <%= inspect(auth_prefix) %>
  @prefix_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []
  @ref_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []
<% end %>

  def change do
    create table(:user_passkeys<%= if adapter == :postgres do %>, Keyword.merge(@prefix_opts, <%= if binary_id, do: "[primary_key: false]", else: "[]" %>)<% else %><%= if binary_id do %>, primary_key: false<% end %><% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:<%= table_name %><%= if adapter == :postgres do %>, Keyword.merge(@ref_opts, <%= if binary_id, do: "[type: :binary_id, on_delete: :delete_all]", else: "[on_delete: :delete_all]" %>)<% else %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all<% end %>), null: false
      add :credential_id, :binary, null: false
      add :public_key, :binary, null: false
      add :sign_count, :integer, default: 0, null: false
<%= if adapter == :postgres do %>      add :aaguid, :uuid
<% else %>      add :aaguid, :binary, size: 16
<% end %>      add :nickname, :string
      add :device_hint, :string
      add :transports, {:array, :string}, default: []
      add :rp_id, :string
      add :last_used_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:user_passkeys, [:user_id]<%= if adapter == :postgres do %>, @prefix_opts<% end %>)
    create unique_index(:user_passkeys, [:credential_id]<%= if adapter == :postgres do %>, @prefix_opts<% end %>)
  end
end
