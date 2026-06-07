<% auth_prefix = Keyword.get(binding(), :auth_prefix) %>
defmodule <%= repo_module %>.Migrations.AddActiveOrganizationIdToUserSessions do
  use Ecto.Migration
<%= if adapter == :postgres do %>
  @auth_prefix <%= inspect(auth_prefix) %>
  @prefix_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []
<% end %>

  def change do
    alter table(:user_sessions<%= if adapter == :postgres do %>, @prefix_opts<% end %>) do
      add :active_organization_id, :binary_id
    end
  end
end
