defmodule Sigra.JWT.RefreshTokenTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.JWT.RefreshToken

  setup :verify_on_exit!

  defp config(overrides \\ []) do
    base = [
      repo: Sigra.MockRepo,
      user_schema: Sigra.TestUser,
      otp_app: :test_app,
      secret_key_base: String.duplicate("s", 64),
      jwt: [
        enabled: true,
        algorithm: "HS256",
        access_ttl: 900,
        refresh_ttl: 30 * 24 * 60 * 60
      ]
    ]

    Sigra.Config.new!(Keyword.merge(base, overrides))
  end

  defp test_user do
    %{id: 42, email: "user@example.com", token_epoch: 0}
  end

  defp token_opts do
    [user_token_schema: Sigra.TestUserToken]
  end

  describe "create/4" do
    test "returns {raw_token, token_record} with family_id and context api_refresh" do
      Sigra.MockRepo
      |> expect(:insert, fn struct ->
        assert struct.context == "api_refresh"
        assert struct.user_id == 42
        assert is_binary(struct.token)

        metadata = Jason.decode!(struct.sent_to)
        assert is_binary(metadata["family_id"])
        assert metadata["scopes"] == ["read:users"]
        assert metadata["superseded_at"] == nil

        {:ok, Map.put(struct, :id, 1)}
      end)

      {raw_token, record} =
        RefreshToken.create(config(), test_user(), ["read:users"], token_opts())

      assert is_binary(raw_token)
      assert record.context == "api_refresh"
    end
  end

  describe "rotate/3" do
    test "supersedes old token and creates new in same family" do
      cfg = config()
      family_id = Ecto.UUID.generate()

      metadata =
        Jason.encode!(%{family_id: family_id, scopes: ["read:users"], superseded_at: nil})

      Sigra.MockRepo
      |> expect(:get_by, fn Sigra.TestUserToken, [token: _, context: "api_refresh"] ->
        %Sigra.TestUserToken{
          id: 1,
          user_id: 42,
          token: "hashed",
          context: "api_refresh",
          sent_to: metadata,
          inserted_at: DateTime.utc_now()
        }
      end)
      |> expect(:update!, fn changeset ->
        # Verify old token is marked superseded
        changes = changeset.changes
        updated_meta = Jason.decode!(changes.sent_to)
        assert updated_meta["superseded_at"] != nil
        Ecto.Changeset.apply_changes(changeset)
      end)
      |> expect(:insert, fn struct ->
        # Verify new token is in same family
        new_meta = Jason.decode!(struct.sent_to)
        assert new_meta["family_id"] == family_id
        assert new_meta["superseded_at"] == nil
        {:ok, Map.merge(struct, %{id: 2, inserted_at: DateTime.utc_now()})}
      end)

      assert {:ok, new_raw, new_record, scopes} =
               RefreshToken.rotate(cfg, "some-raw-token", token_opts())

      assert is_binary(new_raw)
      assert new_record.context == "api_refresh"
      assert scopes == ["read:users"]
    end

    test "returns {:error, :invalid_token} when token not found" do
      Sigra.MockRepo
      |> expect(:get_by, fn Sigra.TestUserToken, [token: _, context: "api_refresh"] ->
        nil
      end)

      assert {:error, :invalid_token} =
               RefreshToken.rotate(config(), "nonexistent-token", token_opts())
    end

    test "returns {:error, :reuse_detected} on superseded token and revokes family" do
      cfg = config()
      family_id = Ecto.UUID.generate()

      superseded_metadata =
        Jason.encode!(%{
          family_id: family_id,
          scopes: ["read:users"],
          superseded_at: "2026-01-01T00:00:00Z"
        })

      # Another active token in the family
      active_metadata =
        Jason.encode!(%{family_id: family_id, scopes: ["read:users"], superseded_at: nil})

      Sigra.MockRepo
      |> expect(:get_by, fn Sigra.TestUserToken, [token: _, context: "api_refresh"] ->
        %Sigra.TestUserToken{
          id: 1,
          user_id: 42,
          token: "hashed",
          context: "api_refresh",
          sent_to: superseded_metadata,
          inserted_at: DateTime.utc_now()
        }
      end)
      # revoke_family: all (find tokens), then update! each
      |> expect(:all, fn _query ->
        [
          %Sigra.TestUserToken{
            id: 2,
            user_id: 42,
            token: "other-hashed",
            context: "api_refresh",
            sent_to: active_metadata,
            inserted_at: DateTime.utc_now()
          }
        ]
      end)
      |> expect(:update!, fn changeset ->
        updated = Jason.decode!(changeset.changes.sent_to)
        assert updated["superseded_at"] != nil
        Ecto.Changeset.apply_changes(changeset)
      end)

      assert {:error, :reuse_detected} =
               RefreshToken.rotate(cfg, "stolen-token", token_opts())
    end

    test "returns {:error, :token_expired} when token is past refresh_ttl" do
      cfg = config(jwt: [enabled: true, algorithm: "HS256", refresh_ttl: 60])

      metadata =
        Jason.encode!(%{family_id: "fam-1", scopes: [], superseded_at: nil})

      # Token inserted 120 seconds ago, TTL is 60
      Sigra.MockRepo
      |> expect(:get_by, fn Sigra.TestUserToken, [token: _, context: "api_refresh"] ->
        %Sigra.TestUserToken{
          id: 1,
          user_id: 42,
          token: "hashed",
          context: "api_refresh",
          sent_to: metadata,
          inserted_at: DateTime.add(DateTime.utc_now(), -120, :second)
        }
      end)

      assert {:error, :token_expired} =
               RefreshToken.rotate(cfg, "old-token", token_opts())
    end
  end

  describe "revoke_family/3" do
    test "sets superseded_at on all tokens in family" do
      cfg = config()
      family_id = Ecto.UUID.generate()

      active_meta =
        Jason.encode!(%{family_id: family_id, scopes: [], superseded_at: nil})

      Sigra.MockRepo
      |> expect(:all, fn _query ->
        [
          %Sigra.TestUserToken{
            id: 1,
            user_id: 42,
            token: "t1",
            context: "api_refresh",
            sent_to: active_meta,
            inserted_at: DateTime.utc_now()
          },
          %Sigra.TestUserToken{
            id: 2,
            user_id: 42,
            token: "t2",
            context: "api_refresh",
            sent_to: active_meta,
            inserted_at: DateTime.utc_now()
          }
        ]
      end)
      |> expect(:update!, 2, fn changeset ->
        Ecto.Changeset.apply_changes(changeset)
      end)

      assert {:ok, 2} = RefreshToken.revoke_family(cfg, family_id, token_opts())
    end
  end

  describe "revoke_all_for_user/3" do
    test "deletes all refresh tokens for user" do
      Sigra.MockRepo
      |> expect(:delete_all, fn _query -> {3, nil} end)

      assert {:ok, 3} =
               RefreshToken.revoke_all_for_user(config(), 42, token_opts())
    end
  end
end
