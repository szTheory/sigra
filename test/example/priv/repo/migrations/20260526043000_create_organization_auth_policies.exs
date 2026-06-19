defmodule Example.Repo.Migrations.CreateOrganizationAuthPolicies do
  use Ecto.Migration

  @prefix_opts [prefix: "auth"]
  @ref_opts [prefix: "auth"]

  def change do
    create table(:organization_auth_policies, Keyword.merge(@prefix_opts, primary_key: false)) do
      add(:id, :binary_id, primary_key: true)

      add(
        :organization_id,
        references(
          :organizations,
          Keyword.merge(@ref_opts, type: :binary_id, on_delete: :delete_all)
        ),
        null: false
      )

      add(:enforcement_mode, :string, null: false, default: "optional")

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:organization_auth_policies, [:organization_id], @prefix_opts))

    create table(
             :organization_auth_policy_exemptions,
             Keyword.merge(@prefix_opts, primary_key: false)
           ) do
      add(:id, :binary_id, primary_key: true)

      add(
        :organization_id,
        references(
          :organizations,
          Keyword.merge(@ref_opts, type: :binary_id, on_delete: :delete_all)
        ),
        null: false
      )

      add(
        :user_id,
        references(:users, Keyword.merge(@ref_opts, type: :binary_id, on_delete: :delete_all)),
        null: false
      )

      timestamps(type: :utc_datetime)
    end

    create(index(:organization_auth_policy_exemptions, [:organization_id], @prefix_opts))

    create(
      unique_index(
        :organization_auth_policy_exemptions,
        [:organization_id, :user_id],
        @prefix_opts
      )
    )
  end
end
