defmodule Example.Repo.Migrations.AddDisplayNameToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:display_name, :string)
    end

    create(index(:users, [:display_name]))
  end
end
