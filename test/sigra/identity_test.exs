defmodule Sigra.IdentityTest do
  use ExUnit.Case, async: true

  alias Sigra.Identity

  describe "struct" do
    test "has all D-25 fields with defaults" do
      identity = %Identity{}

      assert identity.id == nil
      assert identity.user_id == nil
      assert identity.provider == nil
      assert identity.provider_uid == nil
      assert identity.encrypted_access_token == nil
      assert identity.encrypted_refresh_token == nil
      assert identity.token_expires_at == nil
      assert identity.provider_email == nil
      assert identity.provider_name == nil
      assert identity.provider_avatar_url == nil
      assert identity.metadata == %{}
      assert identity.last_used_at == nil
      assert identity.inserted_at == nil
      assert identity.updated_at == nil
    end

    test "can be constructed with fields" do
      identity = %Identity{
        id: 1,
        user_id: 42,
        provider: "google",
        provider_uid: "abc123",
        provider_email: "user@example.com",
        provider_name: "Test User",
        metadata: %{"locale" => "en"}
      }

      assert identity.id == 1
      assert identity.user_id == 42
      assert identity.provider == "google"
      assert identity.provider_uid == "abc123"
      assert identity.provider_email == "user@example.com"
      assert identity.provider_name == "Test User"
      assert identity.metadata == %{"locale" => "en"}
    end
  end

  describe "from_schema/1" do
    test "maps schema struct fields to Identity struct" do
      schema = %{
        __struct__: SomeSchema,
        id: 1,
        user_id: 42,
        provider: "google",
        provider_uid: "abc123",
        encrypted_access_token: "enc_token",
        encrypted_refresh_token: "enc_refresh",
        token_expires_at: ~U[2026-04-08 12:00:00Z],
        provider_email: "user@example.com",
        provider_name: "Test User",
        provider_avatar_url: "https://example.com/avatar.jpg",
        metadata: %{"locale" => "en"},
        last_used_at: ~U[2026-04-08 11:00:00Z],
        inserted_at: ~U[2026-04-08 10:00:00Z],
        updated_at: ~U[2026-04-08 10:00:00Z]
      }

      identity = Identity.from_schema(schema)

      assert %Identity{} = identity
      assert identity.id == 1
      assert identity.user_id == 42
      assert identity.provider == "google"
      assert identity.provider_uid == "abc123"
      assert identity.encrypted_access_token == "enc_token"
      assert identity.encrypted_refresh_token == "enc_refresh"
      assert identity.token_expires_at == ~U[2026-04-08 12:00:00Z]
      assert identity.provider_email == "user@example.com"
      assert identity.provider_name == "Test User"
      assert identity.provider_avatar_url == "https://example.com/avatar.jpg"
      assert identity.metadata == %{"locale" => "en"}
      assert identity.last_used_at == ~U[2026-04-08 11:00:00Z]
      assert identity.inserted_at == ~U[2026-04-08 10:00:00Z]
      assert identity.updated_at == ~U[2026-04-08 10:00:00Z]
    end

    test "handles map input (not just struct)" do
      map = %{
        id: 1,
        provider: "github",
        provider_uid: "456",
        metadata: %{}
      }

      identity = Identity.from_schema(map)

      assert %Identity{} = identity
      assert identity.id == 1
      assert identity.provider == "github"
      assert identity.provider_uid == "456"
    end
  end

  describe "to_params/1" do
    test "converts Identity struct to map suitable for Ecto changeset" do
      identity = %Identity{
        id: 1,
        provider: "google",
        provider_uid: "abc123",
        provider_email: "user@example.com",
        provider_name: "Test User",
        metadata: %{"locale" => "en"},
        inserted_at: ~U[2026-04-08 10:00:00Z],
        updated_at: ~U[2026-04-08 10:00:00Z]
      }

      params = Identity.to_params(identity)

      assert is_map(params)
      # Drops :id, :inserted_at, :updated_at
      refute Map.has_key?(params, :id)
      refute Map.has_key?(params, :inserted_at)
      refute Map.has_key?(params, :updated_at)
      # Keeps the rest
      assert params.provider == "google"
      assert params.provider_uid == "abc123"
      assert params.provider_email == "user@example.com"
    end

    test "normalizes provider to lowercase (D-30)" do
      identity = %Identity{provider: "Google", provider_uid: "abc"}
      params = Identity.to_params(identity)
      assert params.provider == "google"
    end

    test "normalizes atom provider to lowercase string" do
      identity = %Identity{provider: :GitHub, provider_uid: "abc"}
      params = Identity.to_params(identity)
      assert params.provider == "github"
    end

    test "drops nil values from params" do
      identity = %Identity{
        provider: "google",
        provider_uid: "abc",
        provider_email: nil,
        provider_name: nil,
        metadata: %{}
      }

      params = Identity.to_params(identity)

      refute Map.has_key?(params, :provider_email)
      refute Map.has_key?(params, :provider_name)
      # metadata is not nil (it's %{}), so it stays
      assert Map.has_key?(params, :metadata)
    end
  end
end
