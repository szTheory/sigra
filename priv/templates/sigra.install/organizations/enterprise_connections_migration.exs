<% auth_prefix = Keyword.get(binding(), :auth_prefix) %>
defmodule <%= app_module %>.Repo.Migrations.CreateEnterpriseConnections do
  use Ecto.Migration
<%= if adapter == :postgres do %>
  @auth_prefix <%= inspect(auth_prefix) %>
  @prefix_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []
  @ref_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []
<% end %>

  def change do
    create table(:enterprise_connections<%= if adapter == :postgres do %>, Keyword.merge(@prefix_opts, primary_key: false)<% else %>, primary_key: false<% end %>) do
<%= if binary_id do %>
      add :id, :binary_id, primary_key: true
<% end %>
      add :organization_id, references(:organizations<%= if adapter == :postgres do %>, Keyword.merge(@ref_opts, type: <%= if binary_id, do: ":binary_id", else: ":id" %>, on_delete: :delete_all)<% else %>, type: <%= if binary_id, do: ":binary_id", else: ":id" %>, on_delete: :delete_all<% end %>), null: false
      add :protocol, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :display_name, :string, null: false
      add :login_hint_domains, {:array, :string}, default: []
      add :oidc_settings, :map, null: false, default: %{}
      add :last_validated_at, :utc_datetime_usec
      add :last_validation_error, :string

      timestamps(type: :utc_datetime)
    end

    create index(:enterprise_connections, [:organization_id]<%= if adapter == :postgres do %>, @prefix_opts<% end %>)

    create unique_index(:enterprise_connections, [:organization_id, :protocol, :display_name],
             <%= if adapter == :postgres do %>Keyword.merge(@prefix_opts,
               where: "status = 'active'",
               name: :enterprise_connections_active_display_name_index
             )<% else %>where: "status = 'active'",
             name: :enterprise_connections_active_display_name_index<% end %>
           )
  end
end
