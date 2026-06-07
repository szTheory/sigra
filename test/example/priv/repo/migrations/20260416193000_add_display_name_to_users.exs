defmodule Example.Repo.Migrations.AddDisplayNameToUsers do
  use Ecto.Migration

  @prefix_opts [prefix: "auth"]

  def change do
    alter table(:users, @prefix_opts) do
      add(:display_name, :string)
    end

    create(index(:users, [:display_name], @prefix_opts))
  end
end
