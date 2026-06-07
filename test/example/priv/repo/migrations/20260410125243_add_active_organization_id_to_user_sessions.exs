defmodule Example.Repo.Migrations.AddActiveOrganizationIdToUserSessions do
  use Ecto.Migration

  @prefix_opts [prefix: "auth"]

  def change do
    alter table(:user_sessions, @prefix_opts) do
      add(:active_organization_id, :binary_id)
    end
  end
end
