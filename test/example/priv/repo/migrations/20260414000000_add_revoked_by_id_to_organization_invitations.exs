defmodule Example.Repo.Migrations.AddRevokedByIdToOrganizationInvitations do
  use Ecto.Migration

  @moduledoc """
  Phase 17 Plan 17-06 — `Sigra.Organizations.Invitations.revoke/3` writes
  `revoked_by_id` via `Ecto.Changeset.change/2`, which requires the field
  to exist on the schema AND the column to exist in the table. Plan 17-03
  Deviation #4 flagged this as Plan 17-06 work (library code is correct;
  only the generated schema + migration needed updating).
  """

  def change do
    alter table(:organization_invitations) do
      add :revoked_by_id,
          references(:users, type: :binary_id, on_delete: :nilify_all)
    end
  end
end
