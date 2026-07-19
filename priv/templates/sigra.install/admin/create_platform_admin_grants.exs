<% auth_prefix = Keyword.get(binding(), :auth_prefix) %>
defmodule <%= repo_module %>.Migrations.CreatePlatformAdminGrants do
  use Ecto.Migration
<%= if adapter == :postgres do %>
  @auth_prefix <%= inspect(auth_prefix) %>
  @prefix_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []
<% end %>

  def change do
    create table(:sigra_platform_admin_grants<%= if adapter == :postgres do %>, Keyword.merge(@prefix_opts, primary_key: false)<% else %>, primary_key: false<% end %>) do
      add :id, :binary_id, primary_key: true
      add :user_id,
          references(:<%= table_name %>,
            type: <%= if binary_id, do: ":binary_id", else: ":bigint" %>,
            on_delete: :delete_all<%= if adapter == :postgres and auth_prefix do %>,
            prefix: @auth_prefix<% end %>
          ),
          null: false
      add :revoked_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:sigra_platform_admin_grants, [:user_id]<%= if adapter == :postgres do %>, @prefix_opts<% end %>)
    create index(:sigra_platform_admin_grants, [:revoked_at]<%= if adapter == :postgres do %>, @prefix_opts<% end %>)
  end
end
