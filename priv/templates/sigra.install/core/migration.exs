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

      # Account lifecycle fields (Phase 8)
      add :pending_email, :citext
      add :deleted_at, :utc_datetime
      add :scheduled_deletion_at, :utc_datetime
      add :original_email, :string, size: 255
      add :must_change_password, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    # Partial unique index: only enforce email uniqueness for active users
    create unique_index(:<%= table_name %>, [:email], where: "deleted_at IS NULL", name: :<%= table_name %>_email_active_index)
    # Partial unique index on pending_email
    create unique_index(:<%= table_name %>, [:pending_email], where: "pending_email IS NOT NULL", name: :<%= table_name %>_pending_email_index)

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

    # MFA Credentials (TOTP secrets, lockout tracking)
    create table(:user_mfa_credentials<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :encrypted_secret, :binary, null: false
      add :last_used_at, :utc_datetime_usec
      add :last_verified_step, :integer
      add :failed_attempts, :integer, default: 0, null: false
      add :locked_until, :utc_datetime_usec
      add :enabled_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:user_mfa_credentials, [:user_id, :type])

    # Backup Codes (one row per code, atomic consumption)
    create table(:user_backup_codes<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :hashed_code, :string, null: false
      add :used_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:user_backup_codes, [:user_id])

    # Trust epoch on users table for mass trust cookie revocation
    alter table(:<%= table_name %>) do
      add :mfa_trust_epoch, :integer, default: 0, null: false
    end
  end

  def down do
    alter table(:<%= table_name %>) do
      remove :mfa_trust_epoch
    end

    drop table(:user_backup_codes)
    drop table(:user_mfa_credentials)
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

      # Account lifecycle fields (Phase 8)
      add :pending_email, :string, size: 160
      add :deleted_at, :utc_datetime
      add :scheduled_deletion_at, :utc_datetime
      add :original_email, :string, size: 255
      add :must_change_password, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:<%= table_name %>, [:email])
    # Composite index for application-level uniqueness enforcement on active users
    create index(:<%= table_name %>, [:email, :deleted_at])
    create index(:<%= table_name %>, [:pending_email])

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

    # MFA Credentials (TOTP secrets, lockout tracking)
    create table(:user_mfa_credentials<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :encrypted_secret, :binary, null: false
      add :last_used_at, :utc_datetime_usec
      add :last_verified_step, :integer
      add :failed_attempts, :integer, default: 0, null: false
      add :locked_until, :utc_datetime_usec
      add :enabled_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:user_mfa_credentials, [:user_id, :type])

    # Backup Codes (one row per code, atomic consumption)
    create table(:user_backup_codes<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :hashed_code, :string, null: false
      add :used_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:user_backup_codes, [:user_id])

    # Trust epoch on users table for mass trust cookie revocation
    alter table(:<%= table_name %>) do
      add :mfa_trust_epoch, :integer, default: 0, null: false
    end
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

      # Account lifecycle fields (Phase 8)
      add :pending_email, :string, collate: :nocase
      add :deleted_at, :utc_datetime
      add :scheduled_deletion_at, :utc_datetime
      add :original_email, :string, size: 255
      add :must_change_password, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:<%= table_name %>, [:email])
    # Composite index for application-level uniqueness enforcement on active users
    create index(:<%= table_name %>, [:email, :deleted_at])
    create index(:<%= table_name %>, [:pending_email])

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

    # MFA Credentials (TOTP secrets, lockout tracking)
    create table(:user_mfa_credentials<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :encrypted_secret, :binary, null: false
      add :last_used_at, :utc_datetime_usec
      add :last_verified_step, :integer
      add :failed_attempts, :integer, default: 0, null: false
      add :locked_until, :utc_datetime_usec
      add :enabled_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:user_mfa_credentials, [:user_id, :type])

    # Backup Codes (one row per code, atomic consumption)
    create table(:user_backup_codes<%= if binary_id do %>, primary_key: false<% end %>) do
<%= if binary_id do %>      add :id, :binary_id, primary_key: true
<% end %>      add :user_id, references(:<%= table_name %><%= if binary_id do %>, type: :binary_id<% end %>, on_delete: :delete_all), null: false
      add :hashed_code, :string, null: false
      add :used_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:user_backup_codes, [:user_id])

    # Trust epoch on users table for mass trust cookie revocation
    alter table(:<%= table_name %>) do
      add :mfa_trust_epoch, :integer, default: 0, null: false
    end
  end
<% end %>end
