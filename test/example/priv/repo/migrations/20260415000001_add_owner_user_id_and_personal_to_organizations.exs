defmodule Example.Repo.Migrations.AddOwnerUserIdAndPersonalToOrganizations do
  use Ecto.Migration

  # Phase 24.1 (absorbing Phase 18 Plan 18-03): the sigra library's
  # Sigra.Organizations.create_organization/3 writes owner_user_id +
  # personal via Changeset.put_change/3. The Example.Accounts.Organization
  # schema was missing these columns, breaking
  # Example.Organizations.LastOwnerTest which calls
  # create_org_with_owner(user).
  def change do
    alter table(:organizations) do
      add :owner_user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :personal, :boolean, default: false, null: false
    end

    create index(:organizations, [:owner_user_id])

    create unique_index(:organizations, [:owner_user_id],
             where: "personal = true",
             name: :organizations_personal_owner_unique_index
           )
  end
end
