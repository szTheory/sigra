defmodule Sigra.Test.RootAppSessionSchema do
  @moduledoc false

  use Ecto.Migration

  @version 20_260_816_180_000

  def version, do: @version

  def up do
    create_if_not_exists table(:sigra_app_session_users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :text, null: false
      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists table(:sigra_app_session_families, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:sigra_app_session_users, type: :binary_id), null: false
      add :client_ref, :string, null: false
      add :absolute_expires_at, :utc_datetime_usec, null: false
      add :revoked_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists index(:sigra_app_session_families, [:user_id],
                           name: :sigra_app_session_families_user_id_idx
                         )

    create_if_not_exists table(:sigra_app_session_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :family_id, references(:sigra_app_session_families, type: :binary_id), null: false
      add :kind, :string, size: 16, null: false
      add :digest, :binary, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :consumed_at, :utc_datetime_usec
      add :superseded_at, :utc_datetime_usec
      add :revoked_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:sigra_app_session_tokens, [:digest],
                           name: :sigra_app_session_tokens_digest_idx
                         )

    create_if_not_exists index(:sigra_app_session_tokens, [:family_id, :kind],
                           name: :sigra_app_session_tokens_family_kind_idx
                         )

    create_if_not_exists table(:sigra_app_login_attempts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :kind, :string, null: false, default: "hosted_code"
      add :digest, :binary, null: false
      add :approval_digest, :binary
      add :verifier_digest, :binary, null: false
      add :profile_id, :string, null: false
      add :callback, :text, null: false
      add :user_id, references(:sigra_app_session_users, type: :binary_id), null: false
      add :client_ref, :string, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :consumed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:sigra_app_login_attempts, [:digest],
                           name: :sigra_app_login_attempts_digest_index
                         )

    create_if_not_exists unique_index(:sigra_app_login_attempts, [:approval_digest],
                           name: :sigra_app_login_attempts_approval_digest_index
                         )

    create_if_not_exists table(:sigra_app_login_challenges, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :kind, :string, size: 32, null: false
      add :digest, :binary, null: false
      add :profile_id, :string, null: false
      add :user_id, references(:sigra_app_session_users, type: :binary_id), null: false
      add :client_ref, :string, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :consumed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:sigra_app_login_challenges, [:digest],
                           name: :sigra_app_login_challenges_digest_index
                         )

    create_if_not_exists table(:audit_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :occurred_at, :utc_datetime_usec, null: false
      add :action, :string, null: false
      add :outcome, :string, size: 32, null: false, default: "success"
      add :actor_id, :binary_id
      add :actor_type, :string, size: 64, null: false, default: "user"
      add :target_id, :binary_id
      add :target_type, :string, size: 64
      add :ip_address, :string, size: 64
      add :user_agent, :string, size: 512
      add :metadata, :map, null: false, default: %{}
      add :organization_id, :binary_id
      add :effective_user_id, :binary_id
      add :inserted_at, :utc_datetime_usec, null: false
    end
  end
end
