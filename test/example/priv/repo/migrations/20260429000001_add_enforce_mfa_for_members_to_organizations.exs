defmodule Example.Repo.Migrations.AddEnforceMfaForMembersToOrganizations do
  use Ecto.Migration

  def change do
    alter table(:organizations) do
      add :enforce_mfa_for_members, :boolean, null: false, default: false
    end
  end
end
