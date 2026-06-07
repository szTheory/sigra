
defmodule SigraInstallGoldenTmp.Repo.Migrations.AddActiveOrganizationIdToUserSessions do
  use Ecto.Migration

  @auth_prefix "auth"
  @prefix_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []


  def change do
    alter table(:user_sessions, @prefix_opts) do
      add :active_organization_id, :binary_id
    end
  end
end
