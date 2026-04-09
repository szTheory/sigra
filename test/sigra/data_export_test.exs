defmodule Sigra.DataExportTest do
  use ExUnit.Case, async: true

  alias Sigra.DataExport

  describe "export_auth_data/3" do
    test "returns {:ok, map} with expected keys" do
      user = %{
        id: 1,
        email: "test@example.com",
        confirmed_at: ~U[2026-01-01 00:00:00Z],
        inserted_at: ~U[2026-01-01 00:00:00Z]
      }

      # Without schemas, sessions and identities default to empty lists
      assert {:ok, data} = DataExport.export_auth_data(nil, user, [])

      assert Map.has_key?(data, :user)
      assert Map.has_key?(data, :sessions)
      assert Map.has_key?(data, :identities)
    end

    test "user map contains :id, :email, :confirmed_at, :inserted_at" do
      user = %{
        id: 42,
        email: "user@example.com",
        confirmed_at: nil,
        inserted_at: ~U[2026-03-15 12:00:00Z]
      }

      {:ok, data} = DataExport.export_auth_data(nil, user, [])

      assert data.user.id == 42
      assert data.user.email == "user@example.com"
      assert data.user.confirmed_at == nil
      assert data.user.inserted_at == ~U[2026-03-15 12:00:00Z]
    end

    test "sessions and identities default to empty lists without schemas" do
      user = %{
        id: 1,
        email: "test@example.com",
        confirmed_at: nil,
        inserted_at: ~U[2026-01-01 00:00:00Z]
      }

      {:ok, data} = DataExport.export_auth_data(nil, user, [])

      assert data.sessions == []
      assert data.identities == []
    end
  end

  describe "behaviour" do
    test "defines export_user_data/1 callback" do
      callbacks = Sigra.DataExport.behaviour_info(:callbacks)
      assert {:export_user_data, 1} in callbacks
    end
  end
end
