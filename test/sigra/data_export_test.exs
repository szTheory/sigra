defmodule Sigra.DataExportTest do
  use ExUnit.Case, async: true

  alias Sigra.DataExport

  describe "export_auth_data/3" do
    test "returns {:ok, map} with versioned export sections" do
      user = %{
        id: 1,
        email: "test@example.com",
        confirmed_at: ~U[2026-01-01 00:00:00Z],
        inserted_at: ~U[2026-01-01 00:00:00Z]
      }

      # Without schemas, sessions and identities default to empty lists
      assert {:ok, data} = DataExport.export_auth_data(nil, user, [])

      assert data.schema_version == 1
      assert %DateTime{} = data.exported_at
      assert Map.has_key?(data, :account)
      assert Map.has_key?(data, :sessions)
      assert Map.has_key?(data, :identities)
      assert Map.has_key?(data, :audit)
      assert Map.has_key?(data, :mfa)
      assert Map.has_key?(data, :organizations)
      assert Map.has_key?(data, :enterprise)
      assert Map.has_key?(data, :omissions)
    end

    test "account map contains raw lifecycle fields and scheduled lifecycle status" do
      scheduled_deletion_at =
        DateTime.utc_now()
        |> DateTime.add(3, :day)
        |> DateTime.truncate(:second)

      user = %{
        id: 42,
        email: "user@example.com",
        confirmed_at: nil,
        inserted_at: ~U[2026-03-15 12:00:00Z],
        deleted_at: DateTime.utc_now() |> DateTime.truncate(:second),
        scheduled_deletion_at: scheduled_deletion_at
      }

      {:ok, data} = DataExport.export_auth_data(nil, user, [])

      assert data.account.id == 42
      assert data.account.email == "user@example.com"
      assert data.account.confirmed_at == nil
      assert data.account.inserted_at == ~U[2026-03-15 12:00:00Z]
      assert data.account.deleted_at == user.deleted_at
      assert data.account.scheduled_deletion_at == scheduled_deletion_at
      assert %{state: :scheduled, days_remaining: days_remaining} = data.account.lifecycle_status
      assert days_remaining in 0..3
    end

    test "account lifecycle status reports deleted users" do
      user = %{
        id: 43,
        email: "deleted@example.com",
        confirmed_at: nil,
        inserted_at: ~U[2026-03-15 12:00:00Z],
        deleted_at: ~U[2026-03-16 12:00:00Z],
        scheduled_deletion_at: nil
      }

      {:ok, data} = DataExport.export_auth_data(nil, user, [])

      assert data.account.lifecycle_status == %{state: :deleted}
    end

    test "account lifecycle status reports not scheduled users" do
      user = %{
        id: 44,
        email: "active@example.com",
        confirmed_at: nil,
        inserted_at: ~U[2026-03-15 12:00:00Z],
        deleted_at: nil,
        scheduled_deletion_at: nil
      }

      {:ok, data} = DataExport.export_auth_data(nil, user, [])

      assert data.account.lifecycle_status == %{state: :not_scheduled}
    end

    test "optional sections degrade honestly without schemas" do
      user = %{
        id: 1,
        email: "test@example.com",
        confirmed_at: nil,
        inserted_at: ~U[2026-01-01 00:00:00Z]
      }

      {:ok, data} = DataExport.export_auth_data(nil, user, [])

      assert data.sessions == []
      assert data.identities == []
      assert data.audit == []
      assert data.mfa.credentials == []
      assert data.mfa.passkeys == []
      assert data.mfa.backup_codes.count == 0
      assert data.organizations.memberships == []
      assert data.enterprise.exported == false

      assert data.omissions == [
               %{section: :sessions, schema_option: :session_schema},
               %{section: :identities, schema_option: :identity_schema},
               %{section: :audit, schema_option: :audit_schema},
               %{section: :mfa_credentials, schema_option: :mfa_credential_schema},
               %{section: :passkeys, schema_option: :user_passkey_schema},
               %{section: :backup_codes, schema_option: :backup_code_schema},
               %{section: :memberships, schema_option: :membership_schema}
             ]
    end
  end

  describe "behaviour" do
    test "defines export_user_data/1 callback" do
      callbacks = Sigra.DataExport.behaviour_info(:callbacks)
      assert {:export_user_data, 1} in callbacks
    end
  end
end
