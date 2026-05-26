defmodule SigraInstallGoldenTmp.Repo.Migrations.CreateOrganizationAuthPolicies do
  use Ecto.Migration

  def change do
    create table(:organization_auth_policies, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all), null: false
      add :enforcement_mode, :string, null: false, default: "optional"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:organization_auth_policies, [:organization_id])

    create table(:organization_auth_policy_exemptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :organization_id, references(:organizations, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:organization_auth_policy_exemptions, [:organization_id])
    create unique_index(:organization_auth_policy_exemptions, [:organization_id, :user_id])
  end
end
