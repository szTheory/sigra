<% auth_prefix = Keyword.get(binding(), :auth_prefix) %>
defmodule <%= repo_module %>.Migrations.CreateOrganizationAuthPolicies do
  use Ecto.Migration
<%= if adapter == :postgres do %>
  @auth_prefix <%= inspect(auth_prefix) %>
  @prefix_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []
  @ref_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []
<% end %>

  def change do
    create table(:organization_auth_policies<%= if adapter == :postgres do %>, Keyword.merge(@prefix_opts, primary_key: false)<% else %>, primary_key: false<% end %>) do
      add :id, :binary_id, primary_key: true
      add :organization_id, references(:organizations<%= if adapter == :postgres do %>, Keyword.merge(@ref_opts, type: :binary_id, on_delete: :delete_all)<% else %>, type: :binary_id, on_delete: :delete_all<% end %>), null: false
      add :enforcement_mode, :string, null: false, default: "optional"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organization_auth_policies, [:organization_id]<%= if adapter == :postgres do %>, @prefix_opts<% end %>)

    create table(:organization_auth_policy_exemptions<%= if adapter == :postgres do %>, Keyword.merge(@prefix_opts, primary_key: false)<% else %>, primary_key: false<% end %>) do
      add :id, :binary_id, primary_key: true
      add :organization_id, references(:organizations<%= if adapter == :postgres do %>, Keyword.merge(@ref_opts, type: :binary_id, on_delete: :delete_all)<% else %>, type: :binary_id, on_delete: :delete_all<% end %>), null: false
      add :user_id, references(:users<%= if adapter == :postgres do %>, Keyword.merge(@ref_opts, type: :binary_id, on_delete: :delete_all)<% else %>, type: :binary_id, on_delete: :delete_all<% end %>), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:organization_auth_policy_exemptions, [:organization_id]<%= if adapter == :postgres do %>, @prefix_opts<% end %>)
    create unique_index(:organization_auth_policy_exemptions, [:organization_id, :user_id]<%= if adapter == :postgres do %>, @prefix_opts<% end %>)
  end
end
