defmodule Example.Repo.Migrations.CreateSigraBrandProfiles do
  use Ecto.Migration

  @auth_prefix "auth"
  @prefix_opts [prefix: @auth_prefix]

  def up do
    execute("CREATE SCHEMA IF NOT EXISTS #{@auth_prefix}")

    create table(:sigra_brand_profiles, @prefix_opts) do
      add(:scope, :string, null: false)
      add(:settings, :map, null: false)
      add(:updated_by_id, :string)

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:sigra_brand_profiles, [:scope], @prefix_opts))
  end

  def down do
    drop(table(:sigra_brand_profiles, @prefix_opts))
  end
end
