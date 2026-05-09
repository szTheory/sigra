defmodule <%= repo_module %>.Migrations.AddEnforceMfaForMembersToOrganizations do
  @moduledoc """
  Adds `enforce_mfa_for_members` to organizations (org-level MFA enforcement).

  Uses additive `*_if_not_exists` helpers so reruns on already-upgraded
  schemas are safe no-ops.
  """

  use Ecto.Migration

  def up do
    alter table(:organizations) do
      add_if_not_exists :enforce_mfa_for_members, :boolean, null: false, default: false
    end
  end

  def down do
    alter table(:organizations) do
      remove_if_exists :enforce_mfa_for_members, :boolean
    end
  end
end
