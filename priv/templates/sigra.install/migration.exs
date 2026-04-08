defmodule <%= repo_module %>.Migrations.CreateSigraAuthTables do
  use Ecto.Migration
<%= if adapter == :postgres do %>
  def up do
    execute "CREATE EXTENSION IF NOT EXISTS citext"

    create table(:<%= table_name %><%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :email, :citext, null: false
      add :hashed_password, :string
      add :confirmed_at, :utc_datetime
      add :failed_login_attempts, :integer, default: 0, null: false
      add :locked_at, :utc_datetime
      add :password_changed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:<%= table_name %>, [:email])

    create table(:user_tokens<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:user_tokens, [:user_id])
    create unique_index(:user_tokens, [:context, :token])

    create table(:user_sessions<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :hashed_token, :binary, null: false
      add :type, :string, null: false, default: "standard"
      add :ip, :string
      add :user_agent, :text
      add :geo_city, :string
      add :geo_country_code, :string, size: 2
      add :last_active_at, :utc_datetime_usec, null: false
      add :sudo_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:user_sessions, [:hashed_token])
    create index(:user_sessions, [:user_id])
    create index(:user_sessions, [:user_id, :type])
    create index(:user_sessions, [:inserted_at])
  end

  def down do
    drop table(:user_sessions)
    drop table(:user_tokens)
    drop table(:<%= table_name %>)
    execute "DROP EXTENSION IF EXISTS citext"
  end
<% end %><%= if adapter == :mysql do %>
  def change do
    create table(:<%= table_name %><%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :email, :string, null: false, size: 160
      add :hashed_password, :string
      add :confirmed_at, :utc_datetime
      add :failed_login_attempts, :integer, default: 0, null: false
      add :locked_at, :utc_datetime
      add :password_changed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:<%= table_name %>, [:email])

    create table(:user_tokens<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:user_tokens, [:user_id])
    create unique_index(:user_tokens, [:context, :token])

    create table(:user_sessions<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :hashed_token, :binary, null: false
      add :type, :string, null: false, default: "standard"
      add :ip, :string
      add :user_agent, :text
      add :geo_city, :string
      add :geo_country_code, :string, size: 2
      add :last_active_at, :utc_datetime_usec, null: false
      add :sudo_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:user_sessions, [:hashed_token])
    create index(:user_sessions, [:user_id])
    create index(:user_sessions, [:user_id, :type])
    create index(:user_sessions, [:inserted_at])
  end
<% end %><%= if adapter == :sqlite do %>
  def change do
    create table(:<%= table_name %><%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :email, :string, null: false, collate: :nocase
      add :hashed_password, :string
      add :confirmed_at, :utc_datetime
      add :failed_login_attempts, :integer, default: 0, null: false
      add :locked_at, :utc_datetime
      add :password_changed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:<%= table_name %>, [:email])

    create table(:user_tokens<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:user_tokens, [:user_id])
    create unique_index(:user_tokens, [:context, :token])

    create table(:user_sessions<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :hashed_token, :binary, null: false
      add :type, :string, null: false, default: "standard"
      add :ip, :string
      add :user_agent, :text
      add :geo_city, :string
      add :geo_country_code, :string, size: 2
      add :last_active_at, :utc_datetime_usec, null: false
      add :sudo_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:user_sessions, [:hashed_token])
    create index(:user_sessions, [:user_id])
    create index(:user_sessions, [:user_id, :type])
    create index(:user_sessions, [:inserted_at])
  end
<% end %>end
