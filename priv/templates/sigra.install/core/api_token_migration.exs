defmodule <%= repo_module %>.Migrations.CreateUserAPITokens do
  use Ecto.Migration

  def up do
    create table(:user_api_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:<%= table_name %>, type: :binary_id, on_delete: :delete_all), null: false
      add :hashed_token, :binary, null: false
      add :prefix, :string
      add :name, :string, null: false, size: 255
      add :scopes, {:array, :string}, default: []
      add :last_used_at, :utc_datetime_usec
      add :expires_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :inserted_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create unique_index(:user_api_tokens, [:hashed_token])
    create index(:user_api_tokens, [:user_id])
    create index(:user_api_tokens, [:user_id, :revoked_at, :expires_at])

    alter table(:<%= table_name %>) do
      add_if_not_exists :token_epoch, :integer, default: 0, null: false
    end
  end

  def down do
    alter table(:<%= table_name %>) do
      remove_if_exists :token_epoch, :integer
    end

    drop table(:user_api_tokens)
  end
end
