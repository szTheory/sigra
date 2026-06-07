
defmodule SigraInstallGoldenTmp.Repo.Migrations.CreateSigraAuthTables do
  use Ecto.Migration

  @auth_prefix "auth"
  @prefix_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []
  @user_table table(:users, @prefix_opts)
  @user_ref_opts if @auth_prefix, do: [prefix: @auth_prefix], else: []

  def up do
    if @auth_prefix do
      execute "CREATE SCHEMA IF NOT EXISTS #{@auth_prefix}"
    end

    execute "CREATE EXTENSION IF NOT EXISTS citext"

    create table(:users, Keyword.merge(@prefix_opts, [primary_key: false])) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
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
    create unique_index(:users, [:email], Keyword.merge(@prefix_opts, where: "deleted_at IS NULL", name: :users_email_active_index))
    # Partial unique index on pending_email
    create unique_index(:users, [:pending_email], Keyword.merge(@prefix_opts, where: "pending_email IS NOT NULL", name: :users_pending_email_index))

    create table(:user_tokens, Keyword.merge(@prefix_opts, [primary_key: false])) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, Keyword.merge(@user_ref_opts, [type: :binary_id, on_delete: :delete_all])), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :utc_datetime

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:user_tokens, [:user_id], @prefix_opts)
    create unique_index(:user_tokens, [:context, :token], @prefix_opts)

    create table(:user_sessions, Keyword.merge(@prefix_opts, [primary_key: false])) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, Keyword.merge(@user_ref_opts, [type: :binary_id, on_delete: :delete_all])), null: false
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

    create unique_index(:user_sessions, [:hashed_token], @prefix_opts)
    create index(:user_sessions, [:user_id], @prefix_opts)
    create index(:user_sessions, [:user_id, :type], @prefix_opts)
    create index(:user_sessions, [:inserted_at], @prefix_opts)

    # MFA Credentials (TOTP secrets, lockout tracking)
    create table(:user_mfa_credentials, Keyword.merge(@prefix_opts, [primary_key: false])) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, Keyword.merge(@user_ref_opts, [type: :binary_id, on_delete: :delete_all])), null: false
      add :type, :string, null: false
      add :encrypted_secret, :binary, null: false
      add :last_used_at, :utc_datetime_usec
      add :last_verified_step, :integer
      add :failed_attempts, :integer, default: 0, null: false
      add :locked_until, :utc_datetime_usec
      add :enabled_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:user_mfa_credentials, [:user_id, :type], @prefix_opts)

    # Backup Codes (one row per code, atomic consumption)
    create table(:user_backup_codes, Keyword.merge(@prefix_opts, [primary_key: false])) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, Keyword.merge(@user_ref_opts, [type: :binary_id, on_delete: :delete_all])), null: false
      add :hashed_code, :string, null: false
      add :used_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:user_backup_codes, [:user_id], @prefix_opts)

    # Trust epoch on users table for mass trust cookie revocation
    alter @user_table do
      add :mfa_trust_epoch, :integer, default: 0, null: false
    end
  end

  def down do
    alter @user_table do
      remove :mfa_trust_epoch
    end

    drop table(:user_backup_codes, @prefix_opts)
    drop table(:user_mfa_credentials, @prefix_opts)
    drop table(:user_sessions, @prefix_opts)
    drop table(:user_tokens, @prefix_opts)
    drop @user_table
    execute "DROP EXTENSION IF EXISTS citext"
  end
end
