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

    test "account map contains lifecycle fields" do
      user = %{
        id: 42,
        email: "user@example.com",
        confirmed_at: nil,
        inserted_at: ~U[2026-03-15 12:00:00Z],
        deleted_at: ~U[2026-03-16 12:00:00Z],
        scheduled_deletion_at: ~U[2026-03-20 12:00:00Z]
      }

      {:ok, data} = DataExport.export_auth_data(nil, user, [])

      assert data.account.id == 42
      assert data.account.email == "user@example.com"
      assert data.account.confirmed_at == nil
      assert data.account.inserted_at == ~U[2026-03-15 12:00:00Z]
      assert data.account.deleted_at == ~U[2026-03-16 12:00:00Z]
      assert data.account.scheduled_deletion_at == ~U[2026-03-20 12:00:00Z]
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
      assert Enum.any?(data.omissions, &String.contains?(&1, "Audit events are omitted"))
    end
  end

  describe "behaviour" do
    test "defines export_user_data/1 callback" do
      callbacks = Sigra.DataExport.behaviour_info(:callbacks)
      assert {:export_user_data, 1} in callbacks
    end
  end
end
