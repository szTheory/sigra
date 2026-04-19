defmodule Sigra.JWTTest do
  use ExUnit.Case, async: true

  import Mox

  alias Sigra.JWT

  setup :verify_on_exit!

  @secret_key_base String.duplicate("s", 64)

  defp config(overrides \\ []) do
    base = [
      repo: Sigra.MockRepo,
      user_schema: Sigra.TestUser,
      otp_app: :test_app,
      secret_key_base: @secret_key_base,
      jwt: [
        enabled: true,
        algorithm: "HS256",
        issuer: "test_issuer",
        access_ttl: 900,
        refresh_ttl: 30 * 24 * 60 * 60,
        refresh: true,
        verify_epoch: true
      ]
    ]

    Sigra.Config.new!(Keyword.merge(base, overrides))
  end

  defp test_user(overrides \\ %{}) do
    Map.merge(%{id: 42, email: "user@example.com", token_epoch: 0}, overrides)
  end

  defp token_opts do
    [user_token_schema: Sigra.TestUserToken]
  end

  describe "generate_tokens/3" do
    test "returns {:ok, %{access_token, refresh_token, expires_in}}" do
      user = test_user()

      # Mock the repo.insert for refresh token creation
      Sigra.MockRepo
      |> expect(:insert, fn struct ->
        {:ok, Map.put(struct, :id, 1)}
      end)

      assert {:ok, tokens} = JWT.generate_tokens(config(), user, ["read:users"], token_opts())
      assert is_binary(tokens.access_token)
      assert is_binary(tokens.refresh_token)
      assert tokens.expires_in == 900
    end

    test "access token contains sub, iat, exp, jti, iss, scopes, epoch claims" do
      user = test_user(%{token_epoch: 3})

      Sigra.MockRepo
      |> expect(:insert, fn struct ->
        {:ok, Map.put(struct, :id, 1)}
      end)

      {:ok, tokens} =
        JWT.generate_tokens(config(), user, ["read:users", "write:users"], token_opts())

      # Verify the JWT by decoding it
      signer =
        Joken.Signer.create(
          "HS256",
          :crypto.mac(:hmac, :sha256, @secret_key_base, "sigra-jwt-signing-key")
        )

      {:ok, claims} = Joken.verify(tokens.access_token, signer)

      assert claims["sub"] == "42"
      assert is_integer(claims["iat"])
      assert is_integer(claims["exp"])
      assert claims["exp"] - claims["iat"] == 900
      assert is_binary(claims["jti"])
      assert claims["iss"] == "test_issuer"
      assert claims["scopes"] == ["read:users", "write:users"]
      assert claims["epoch"] == 3
    end

    test "with claims_builder merges extra claims" do
      defmodule TestClaimsBuilder do
        @behaviour Sigra.JWT.ClaimsBuilder

        @impl true
        def extra_claims(user) do
          %{"role" => user.role, "custom" => "value"}
        end
      end

      user = test_user(%{role: "admin"})

      cfg =
        config(
          jwt: [
            enabled: true,
            algorithm: "HS256",
            issuer: "test",
            access_ttl: 900,
            refresh: false,
            claims_builder: TestClaimsBuilder
          ]
        )

      {:ok, tokens} = JWT.generate_tokens(cfg, user, [], token_opts())

      signer =
        Joken.Signer.create(
          "HS256",
          :crypto.mac(:hmac, :sha256, @secret_key_base, "sigra-jwt-signing-key")
        )

      {:ok, claims} = Joken.verify(tokens.access_token, signer)

      assert claims["role"] == "admin"
      assert claims["custom"] == "value"
      assert claims["sub"] == "42"
    end

    test "with refresh: false, refresh_token is nil" do
      user = test_user()
      cfg = config(jwt: [enabled: true, algorithm: "HS256", access_ttl: 900, refresh: false])

      {:ok, tokens} = JWT.generate_tokens(cfg, user, [], token_opts())

      assert is_binary(tokens.access_token)
      assert tokens.refresh_token == nil
    end
  end

  describe "verify_access/2" do
    test "returns {:ok, claims} for valid token" do
      user = test_user()
      cfg = config()

      # Generate a token first (no refresh)
      cfg_no_refresh =
        config(
          jwt: [
            enabled: true,
            algorithm: "HS256",
            issuer: "test_issuer",
            access_ttl: 900,
            refresh: false,
            verify_epoch: true
          ]
        )

      {:ok, tokens} = JWT.generate_tokens(cfg_no_refresh, user, ["read:users"], token_opts())

      # Mock the repo.get for epoch verification
      Sigra.MockRepo
      |> expect(:get, fn Sigra.TestUser, "42" ->
        %{id: 42, token_epoch: 0}
      end)

      assert {:ok, claims} = JWT.verify_access(cfg, tokens.access_token)
      assert claims["sub"] == "42"
      assert claims["scopes"] == ["read:users"]
    end

    test "returns {:error, :token_expired} for expired token" do
      # Create a token with exp in the past
      signer =
        Joken.Signer.create(
          "HS256",
          :crypto.mac(:hmac, :sha256, @secret_key_base, "sigra-jwt-signing-key")
        )

      now = DateTime.utc_now() |> DateTime.to_unix()
      claims = %{"sub" => "42", "iat" => now - 2000, "exp" => now - 1000, "epoch" => 0}
      {:ok, jwt, _} = Joken.generate_and_sign(%{}, claims, signer)

      assert {:error, :token_expired} = JWT.verify_access(config(), jwt)
    end

    test "returns {:error, :invalid_token} for tampered token" do
      assert {:error, :invalid_token} = JWT.verify_access(config(), "not.a.valid.jwt")
    end

    test "with verify_epoch: true checks user.token_epoch matches claim" do
      user = test_user(%{token_epoch: 5})

      cfg =
        config(
          jwt: [
            enabled: true,
            algorithm: "HS256",
            issuer: "test_issuer",
            access_ttl: 900,
            refresh: false,
            verify_epoch: true
          ]
        )

      {:ok, tokens} = JWT.generate_tokens(cfg, user, [], token_opts())

      # User with matching epoch
      Sigra.MockRepo
      |> expect(:get, fn Sigra.TestUser, "42" ->
        %{id: 42, token_epoch: 5}
      end)

      assert {:ok, _claims} = JWT.verify_access(cfg, tokens.access_token)
    end

    test "returns {:error, :epoch_mismatch} when epoch doesn't match" do
      user = test_user(%{token_epoch: 5})

      cfg =
        config(
          jwt: [
            enabled: true,
            algorithm: "HS256",
            issuer: "test_issuer",
            access_ttl: 900,
            refresh: false,
            verify_epoch: true
          ]
        )

      {:ok, tokens} = JWT.generate_tokens(cfg, user, [], token_opts())

      # User changed password, epoch incremented
      Sigra.MockRepo
      |> expect(:get, fn Sigra.TestUser, "42" ->
        %{id: 42, token_epoch: 6}
      end)

      assert {:error, :epoch_mismatch} = JWT.verify_access(cfg, tokens.access_token)
    end

    test "returns {:error, :invalid_token} when user not found (deleted)" do
      user = test_user()

      cfg =
        config(
          jwt: [
            enabled: true,
            algorithm: "HS256",
            issuer: "test_issuer",
            access_ttl: 900,
            refresh: false,
            verify_epoch: true
          ]
        )

      {:ok, tokens} = JWT.generate_tokens(cfg, user, [], token_opts())

      Sigra.MockRepo
      |> expect(:get, fn Sigra.TestUser, "42" -> nil end)

      assert {:error, :invalid_token} = JWT.verify_access(cfg, tokens.access_token)
    end
  end

  describe "refresh/2" do
    test "returns new access + refresh tokens" do
      user = test_user()
      cfg = config()

      # Create initial tokens
      Sigra.MockRepo
      |> expect(:insert, fn struct ->
        {:ok, Map.merge(struct, %{id: 1, inserted_at: DateTime.utc_now()})}
      end)

      {:ok, initial} = JWT.generate_tokens(cfg, user, ["read:users"], token_opts())

      # Set up mocks for rotate: get_by (find old token), update! (supersede), insert (new token), get! (user for claims)
      old_metadata =
        Jason.encode!(%{family_id: "fam-1", scopes: ["read:users"], superseded_at: nil})

      Sigra.MockRepo
      |> expect(:get_by, fn Sigra.TestUserToken, [token: _, context: "api_refresh"] ->
        %Sigra.TestUserToken{
          id: 1,
          user_id: 42,
          token: "hashed",
          context: "api_refresh",
          sent_to: old_metadata,
          inserted_at: DateTime.utc_now()
        }
      end)
      |> expect(:update!, fn changeset ->
        Ecto.Changeset.apply_changes(changeset)
      end)
      |> expect(:insert, fn struct ->
        {:ok, Map.merge(struct, %{id: 2, inserted_at: DateTime.utc_now()})}
      end)
      |> expect(:get!, fn Sigra.TestUser, 42 ->
        %{id: 42, token_epoch: 0, email: "user@example.com"}
      end)

      assert {:ok, new_tokens} = JWT.refresh(cfg, initial.refresh_token, token_opts())
      assert is_binary(new_tokens.access_token)
      assert is_binary(new_tokens.refresh_token)
      assert new_tokens.access_token != initial.access_token
      assert new_tokens.refresh_token != initial.refresh_token
    end

    test "reuse of superseded token triggers reuse detection and revokes family" do
      cfg = config()

      superseded_metadata =
        Jason.encode!(%{
          family_id: "fam-1",
          scopes: ["read:users"],
          superseded_at: "2026-01-01T00:00:00Z"
        })

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
      # revoke_family calls: all (find family tokens)
      |> expect(:all, fn _query -> [] end)

      assert {:error, :reuse_detected} = JWT.refresh(cfg, "some-token", token_opts())
    end
  end

  describe "revoke_refresh/2" do
    test "revokes a specific refresh token" do
      cfg = config()
      metadata = Jason.encode!(%{family_id: "fam-1", scopes: [], superseded_at: nil})

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
        Ecto.Changeset.apply_changes(changeset)
      end)

      assert :ok = JWT.revoke_refresh(cfg, "some-token", token_opts())
    end
  end
end
