defmodule Example.Repo.Migrations.CreateEnterpriseConnections do
  use Ecto.Migration

  @prefix_opts [prefix: "auth"]
  @ref_opts [prefix: "auth"]

  def change do
    create table(:enterprise_connections, Keyword.merge(@prefix_opts, primary_key: false)) do
      add(:id, :binary_id, primary_key: true)

      add(
        :organization_id,
        references(
          :organizations,
          Keyword.merge(@ref_opts, type: :binary_id, on_delete: :delete_all)
        ),
        null: false
      )

      add(:protocol, :string, null: false)
      add(:status, :string, null: false, default: "draft")
      add(:display_name, :string, null: false)
      add(:login_hint_domains, {:array, :string}, default: [])
      add(:oidc_settings, :map, null: false, default: %{})
      add(:last_validated_at, :utc_datetime_usec)
      add(:last_validation_error, :string)

      timestamps(type: :utc_datetime)
    end

    create(index(:enterprise_connections, [:organization_id], @prefix_opts))

    create(
      unique_index(
        :enterprise_connections,
        [:organization_id, :protocol, :display_name],
        Keyword.merge(@prefix_opts,
          where: "status = 'active'",
          name: :enterprise_connections_active_display_name_index
        )
      )
    )
  end
end
