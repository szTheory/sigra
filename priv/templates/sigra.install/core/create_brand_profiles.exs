<% auth_prefix = Keyword.get(binding(), :auth_prefix) %>
defmodule <%= repo_module %>.Migrations.CreateSigraBrandProfiles do
  use Ecto.Migration
<%= if adapter == :postgres do %>
  @auth_prefix <%= inspect(auth_prefix) %>
  @prefix_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []

  def up do
    if @auth_prefix do
      execute "CREATE SCHEMA IF NOT EXISTS #{@auth_prefix}"
    end

    create table(:sigra_brand_profiles, @prefix_opts) do
      add :scope, :string, null: false
      add :settings, :map, null: false, default: %{}
      add :updated_by_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sigra_brand_profiles, [:scope], @prefix_opts)
  end

  def down do
    drop table(:sigra_brand_profiles, @prefix_opts)
  end
<% end %><%= if adapter == :mysql do %>
  def change do
    create table(:sigra_brand_profiles) do
      add :scope, :string, null: false
      add :settings, :map, null: false, default: %{}
      add :updated_by_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sigra_brand_profiles, [:scope])
  end
<% end %><%= if adapter == :sqlite do %>
  def change do
    create table(:sigra_brand_profiles) do
      add :scope, :string, null: false
      add :settings, :map, null: false, default: %{}
      add :updated_by_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sigra_brand_profiles, [:scope])
  end
<% end %>end
