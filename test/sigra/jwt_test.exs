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
        audience: ["sigra-api", "sigra-web"],
        typ: "JWT",
        access_ttl: 900,
        refresh_ttl: 30 * 24 * 60 * 60,
        refresh: true,
        verify_epoch: true
      ]
    ]

    overrides =
      Keyword.update(overrides, :jwt, base[:jwt], fn jwt ->
        Keyword.merge(base[:jwt], jwt)
      end)

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

  describe "advanced access-token contract" do
    test "issues configured protected type and registered claims before verifying a valid token" do
      cfg = config(jwt: [enabled: true, refresh: false, typ: "sigra-access+jwt"])
      user = test_user()

      {:ok, tokens} = JWT.generate_tokens(cfg, user, ["read:users"], token_opts())

      Sigra.MockRepo
      |> expect(:get, fn Sigra.TestUser, "42" -> %{id: 42, token_epoch: 0} end)

      assert {:ok, claims} = JWT.verify_access(cfg, tokens.access_token)
      assert claims["iss"] == "test_issuer"
      assert claims["aud"] == ["sigra-api", "sigra-web"]
      assert claims["sub"] == "42"
      assert is_integer(claims["iat"])
      assert is_integer(claims["exp"])
      assert is_binary(claims["jti"])

      assert {:ok, %{"typ" => "sigra-access+jwt"}} =
               tokens.access_token |> JOSE.JWS.peek_protected() |> Jason.decode()
    end

    test "checks a configured signer before accepting a protected typ" do
      token = signed_token(%{}, signer_headers: %{"typ" => "JWT"}, algorithm: "HS384")

      assert {:error, :invalid_token} = JWT.verify_access(config(), token)
    end

    test "rejects a validly signed token with wrong or missing protected typ" do
      assert {:error, :invalid_token} =
               JWT.verify_access(
                 config(),
                 signed_token(%{}, signer_headers: %{"typ" => "not-jwt"})
               )

      assert {:error, :invalid_token} =
               JWT.verify_access(config(), signed_token(%{}, missing_typ: true))
    end

    for {claim, invalid_values} <- [
          {"iss", [nil, "", 7, "wrong-issuer"]},
          {"sub", [nil, "", 7]},
          {"iat", [nil, "", "now"]},
          {"exp", [nil, "", "later", DateTime.utc_now() |> DateTime.to_unix() |> Kernel.-(1)]},
          {"jti", [nil, "", 7]}
        ] do
      test "rejects missing or malformed #{claim}" do
        unquote(invalid_values)
        |> Enum.each(fn value ->
          claims =
            if is_nil(value),
              do: Map.delete(valid_claims(), unquote(claim)),
              else: Map.put(valid_claims(), unquote(claim), value)

          assert {:error, :invalid_token} =
                   JWT.verify_access(config(), signed_token(%{}, claims: claims))
        end)
      end
    end

    test "accepts scalar and non-empty string-array audiences with exact configured recipients" do
      for audience <- ["sigra-api", ["other", "sigra-web"]] do
        Sigra.MockRepo
        |> expect(:get, fn Sigra.TestUser, "42" -> %{id: 42, token_epoch: 0} end)

        assert {:ok, _} = JWT.verify_access(config(), signed_token(%{"aud" => audience}))
      end
    end

    test "rejects missing, empty, malformed, or case-different audiences" do
      for audience <- [nil, "", [], [""], ["sigra-api", 7], "SIGRA-API", ["other"]] do
        claims =
          if is_nil(audience), do: Map.delete(valid_claims(), "aud"), else: %{"aud" => audience}

        assert {:error, :invalid_token} =
                 JWT.verify_access(config(), signed_token(%{}, claims: claims))
      end
    end

    test "enforces optional nbf without making it an identity claim" do
      now = DateTime.utc_now() |> DateTime.to_unix()

      assert {:error, :invalid_token} =
               JWT.verify_access(config(), signed_token(%{"nbf" => now + 60}))

      for nbf <- [now, now - 60] do
        Sigra.MockRepo
        |> expect(:get, fn Sigra.TestUser, "42" -> %{id: 42, token_epoch: 0} end)

        assert {:ok, _} = JWT.verify_access(config(), signed_token(%{"nbf" => nbf}))
      end
    end

    test "prevents custom claims from overwriting server-owned fields" do
      defmodule ReservedClaimsBuilder do
        @behaviour Sigra.JWT.ClaimsBuilder

        @impl true
        def extra_claims(_user),
          do: %{"sub" => "attacker", "aud" => "attacker", "scopes" => ["admin"]}
      end

      cfg = config(jwt: [enabled: true, refresh: false, claims_builder: ReservedClaimsBuilder])
      {:ok, tokens} = JWT.generate_tokens(cfg, test_user(), ["read:users"], token_opts())
      {:ok, claims} = Joken.verify(tokens.access_token, configured_signer())

      assert claims["sub"] == "42"
      assert claims["aud"] == ["sigra-api", "sigra-web"]
      assert claims["scopes"] == ["read:users"]
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
      claims = valid_claims() |> Map.put("iat", now - 2000) |> Map.put("exp", now - 1000)
      {:ok, jwt, _} = Joken.generate_and_sign(%{}, claims, signer)

      assert {:error, :invalid_token} = JWT.verify_access(config(), jwt)
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

  defp valid_claims do
    now = DateTime.utc_now() |> DateTime.to_unix()

    %{
      "iss" => "test_issuer",
      "aud" => ["sigra-api", "sigra-web"],
      "sub" => "42",
      "iat" => now,
      "exp" => now + 900,
      "jti" => Ecto.UUID.generate(),
      "scopes" => ["read:users"],
      "epoch" => 0
    }
  end

  defp signed_token(overrides, opts \\ []) do
    claims = Keyword.get(opts, :claims, Map.merge(valid_claims(), overrides))
    algorithm = Keyword.get(opts, :algorithm, "HS256")
    headers = Keyword.get(opts, :signer_headers, %{"typ" => "JWT"})
    signer = configured_signer(algorithm, headers)

    signer =
      if Keyword.get(opts, :missing_typ, false) do
        %{signer | jws: JOSE.JWS.from_map(%{"alg" => algorithm})}
      else
        signer
      end

    {:ok, jwt, _} = Joken.generate_and_sign(%{}, claims, signer)
    jwt
  end

  defp configured_signer(algorithm \\ "HS256", headers \\ %{}) do
    Joken.Signer.create(
      algorithm,
      :crypto.mac(:hmac, :sha256, @secret_key_base, "sigra-jwt-signing-key"),
      headers
    )
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

      # The locked lifecycle returns persistence values only after its transaction succeeds.
      old_metadata =
        Jason.encode!(%{family_id: "fam-1", scopes: ["read:users"], superseded_at: nil})

      Sigra.MockRepo
      |> expect(:transaction, fn multi ->
        assert Keyword.has_key?(Ecto.Multi.to_list(multi), :jwt_refresh_classification)

        old_record = %Sigra.TestUserToken{
          id: 1,
          user_id: 42,
          token: "hashed",
          context: "api_refresh",
          sent_to: old_metadata,
          inserted_at: DateTime.utc_now()
        }

        new_record = %{old_record | id: 2, token: "new-hashed"}

        {:ok,
         %{
           jwt_refresh_classification: {:rotate, old_record, Jason.decode!(old_metadata)},
           jwt_refresh_new_token: {"new-refresh-token", new_record, ["read:users"]}
         }}
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
      |> expect(:transaction, fn multi ->
        assert Keyword.has_key?(Ecto.Multi.to_list(multi), :jwt_refresh_classification)

        token_record = %Sigra.TestUserToken{
          id: 1,
          user_id: 42,
          token: "hashed",
          context: "api_refresh",
          sent_to: superseded_metadata,
          inserted_at: DateTime.utc_now()
        }

        {:ok,
         %{
           jwt_refresh_classification: {:reuse, token_record, Jason.decode!(superseded_metadata)},
           jwt_reuse_revoke_family: 0
         }}
      end)

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
