defmodule Example.Repo.Migrations.CreateUserAppSessions do
  use Ecto.Migration

  @prefix_opts [prefix: "auth"]
  @ref_opts [prefix: "auth"]

  def change do
    create table(:user_app_session_families, Keyword.merge(@prefix_opts, primary_key: false)) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, Keyword.merge(@ref_opts, type: :binary_id, on_delete: :delete_all)), null: false
      add :client_ref, :string, null: false
      add :absolute_expires_at, :utc_datetime_usec, null: false
      add :revoked_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create index(:user_app_session_families, [:user_id, :revoked_at], @prefix_opts)

    create table(:user_app_session_tokens, Keyword.merge(@prefix_opts, primary_key: false)) do
      add :id, :binary_id, primary_key: true
      add :family_id, references(:user_app_session_families, Keyword.merge(@ref_opts, type: :binary_id, on_delete: :delete_all)), null: false
      add :kind, :string, null: false
      add :digest, :binary, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :consumed_at, :utc_datetime_usec
      add :superseded_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:user_app_session_tokens, [:digest], @prefix_opts)
    create index(:user_app_session_tokens, [:family_id, :kind, :consumed_at], @prefix_opts)
    create index(:user_app_session_tokens, [:family_id, :revoked_at], @prefix_opts)

    create table(:user_app_login_attempts, Keyword.merge(@prefix_opts, primary_key: false)) do
      add :id, :binary_id, primary_key: true
      add :kind, :string, null: false
      add :digest, :binary, null: false
      add :approval_digest, :binary
      add :verifier_digest, :binary
      add :profile_id, :string, null: false
      add :client_ref, :string, null: false
      add :callback, :string
      add :audit_correlation, :string
      add :user_id, references(:users, Keyword.merge(@ref_opts, type: :binary_id, on_delete: :delete_all)), null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :consumed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:user_app_login_attempts, [:digest], @prefix_opts)
    create unique_index(:user_app_login_attempts, [:approval_digest], Keyword.merge(@prefix_opts, name: :user_app_login_attempts_approval_digest_index))
    create index(:user_app_login_attempts, [:kind, :expires_at, :consumed_at], @prefix_opts)
    create index(:user_app_login_attempts, [:user_id, :profile_id, :consumed_at], @prefix_opts)
  end
end
