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

  # ---------------------------------------------------------------------------
  # Service-account tokens
  # Inline schemas (Pattern B: Mox-mocked repo; FK integrity on actor_id is
  # not validated, so synthetic UUIDs are appropriate for the user scope).
  # ---------------------------------------------------------------------------

  defmodule SASchema do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "service_accounts" do
      field :name, :string
      field :scopes, {:array, :string}, default: []
      field :role, :string
      field :token_epoch, :integer, default: 0
      field :revoked_at, :utc_datetime
      field :organization_id, :binary_id
    end

    def changeset(struct, attrs) do
      import Ecto.Changeset

      struct
      |> cast(attrs, [:id, :name, :scopes, :role, :token_epoch, :organization_id])
      |> validate_required([:name, :organization_id])
    end
  end

  defmodule CredentialSchema do
    @moduledoc false
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "service_account_credentials" do
      field :client_id, :string
      field :hashed_client_secret, :binary
      field :expires_at, :utc_datetime
      field :last_used_at, :utc_datetime
      field :revoked_at, :utc_datetime
      field :service_account_id, :binary_id
    end

    def changeset(struct, attrs) do
      import Ecto.Changeset

      struct
      |> cast(attrs, [:id, :client_id, :hashed_client_secret, :expires_at, :service_account_id])
      |> validate_required([:client_id, :hashed_client_secret, :service_account_id])
    end
  end

  defp sa_config(overrides \\ []) do
    base = [
      repo: Sigra.MockRepo,
      user_schema: Sigra.TestUser,
      otp_app: :test_app,
      secret_key_base: @secret_key_base,
      service_accounts: [
        service_account_schema: Sigra.JWTTest.SASchema,
        service_account_credential_schema: Sigra.JWTTest.CredentialSchema,
        client_id_prefix: "sigra_sa_",
        client_id_byte_size: 24
      ],
      jwt: [
        enabled: true,
        algorithm: "HS256",
        issuer: "test_issuer",
        access_ttl: 900,
        client_credentials_access_ttl: 3600,
        refresh: true,
        verify_epoch: true
      ]
    ]

    Sigra.Config.new!(Keyword.merge(base, overrides))
  end

  defp make_sa(overrides \\ %{}) do
    id = Ecto.UUID.generate()
    org_id = Ecto.UUID.generate()

    Map.merge(
      %Sigra.JWTTest.SASchema{
        id: id,
        name: "CI Service Account",
        scopes: ["deploy:read", "deploy:write"],
        role: "ci",
        token_epoch: 0,
        revoked_at: nil,
        organization_id: org_id
      },
      overrides
    )
  end

  defp make_credential(sa_id, overrides \\ %{}) do
    id = Ecto.UUID.generate()
    client_id = "sigra_sa_" <> String.slice(Ecto.UUID.generate(), 0, 24)

    Map.merge(
      %Sigra.JWTTest.CredentialSchema{
        id: id,
        client_id: client_id,
        hashed_client_secret: :crypto.hash(:sha256, "secret"),
        expires_at: nil,
        last_used_at: nil,
        revoked_at: nil,
        service_account_id: sa_id
      },
      overrides
    )
  end

  describe "service-account tokens" do
    setup do
      sa = make_sa()
      cred = make_credential(sa.id)

      # Pattern B synthetic UUID — appropriate because parent uses Mox-mocked
      # repo and FK integrity on actor_id is NOT validated.
      sa_scope = %{
        user: %{id: Ecto.UUID.generate()},
        active_organization: %{id: sa.organization_id}
      }

      {:ok, sa: sa, cred: cred, sa_scope: sa_scope}
    end

    test "generate_service_account_tokens/3 returns {:ok, %{access_token, expires_in, scopes}} with no refresh_token",
         %{sa: sa, cred: cred} do
      cfg = sa_config()

      # Mock transaction for append_token_issued_audit
      # (Multi.update :credential_last_used + Audit.log_multi_safe)
      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        updated_cred = %{cred | last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)}
        {:ok, %{credential_last_used: updated_cred, audit_service_account_token_issued: nil}}
      end)

      assert {:ok, %{access_token: access_token, expires_in: 3600} = response} =
               JWT.generate_service_account_tokens(cfg, sa, cred)

      assert is_binary(access_token)
      # D-93-07: no refresh tokens on client_credentials. The key is present but nil.
      assert Map.get(response, :refresh_token) == nil
    end

    test "service-account access token contains actor_type, service_account_id, credential_id, org_id, scopes, epoch, sub claims",
         %{sa: sa, cred: cred} do
      cfg = sa_config()

      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        updated_cred = %{cred | last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)}
        {:ok, %{credential_last_used: updated_cred, audit_service_account_token_issued: nil}}
      end)
      |> expect(:get, fn Sigra.JWTTest.SASchema, _id -> sa end)
      |> expect(:get, fn Sigra.JWTTest.CredentialSchema, _id -> cred end)

      {:ok, %{access_token: jwt}} = JWT.generate_service_account_tokens(cfg, sa, cred)
      {:ok, claims} = JWT.verify_access(cfg, jwt)

      # D-93-10: all claims present
      assert claims["actor_type"] == "service_account"
      assert claims["service_account_id"] == sa.id
      assert claims["credential_id"] == cred.id
      assert claims["org_id"] == sa.organization_id
      assert claims["scopes"] == sa.scopes
      assert claims["epoch"] == sa.token_epoch
      # D-93-09: sub == credential.client_id
      assert claims["sub"] == cred.client_id
    end

    test "verify_access/2 returns {:ok, claims} for a fresh SA token (parity with user path)",
         %{sa: sa, cred: cred} do
      cfg = sa_config()

      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        updated_cred = %{cred | last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)}
        {:ok, %{credential_last_used: updated_cred, audit_service_account_token_issued: nil}}
      end)
      |> expect(:get, fn Sigra.JWTTest.SASchema, _id -> sa end)
      |> expect(:get, fn Sigra.JWTTest.CredentialSchema, _id -> cred end)

      {:ok, %{access_token: jwt}} = JWT.generate_service_account_tokens(cfg, sa, cred)
      assert {:ok, %{"actor_type" => "service_account"}} = JWT.verify_access(cfg, jwt)
    end

    test "verify_access/2 returns {:error, :epoch_mismatch} after Sigra.ServiceAccounts.revoke/3 bumps token_epoch",
         %{sa: sa, cred: cred, sa_scope: sa_scope} do
      cfg = sa_config()

      # Step 1: generate token (mock transaction for issuance audit)
      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        updated_cred = %{cred | last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)}
        {:ok, %{credential_last_used: updated_cred, audit_service_account_token_issued: nil}}
      end)

      {:ok, %{access_token: jwt}} = JWT.generate_service_account_tokens(cfg, sa, cred)

      # Step 2: revoke the SA (bumps token_epoch, sets revoked_at)
      # Sigra.ServiceAccounts.revoke/3 runs Multi.update + audit — MUST pass non-nil user scope.
      # Pattern B: synthetic UUID in sa_scope (fixture); ensure_user_scope!/2 at
      # lib/sigra/service_accounts.ex:347 raises ArgumentError on %{user: nil, ...}.
      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        revoked_sa = %{sa | token_epoch: sa.token_epoch + 1, revoked_at: DateTime.utc_now()}
        {:ok, %{service_account: revoked_sa, audit_service_account_revoke: nil}}
      end)

      assert {:ok, _revoked_sa} = Sigra.ServiceAccounts.revoke(cfg, sa_scope, sa)

      # Step 3: verify_access uses updated SA state.
      # Mock returns the bumped-epoch SA to simulate DB state after revoke.
      revoked_sa = %{sa | token_epoch: sa.token_epoch + 1, revoked_at: DateTime.utc_now()}

      Sigra.MockRepo
      |> expect(:get, fn Sigra.JWTTest.SASchema, _id -> revoked_sa end)
      |> expect(:get, fn Sigra.JWTTest.CredentialSchema, _id -> cred end)

      # D-93-12: epoch mismatch after revocation invalidates live token.
      assert {:error, :epoch_mismatch} = JWT.verify_access(cfg, jwt)
    end

    test "verify_access/2 fails after Sigra.ServiceAccounts.revoke_credential/3 (per-credential revoke)",
         %{sa: sa, cred: cred, sa_scope: sa_scope} do
      cfg = sa_config()

      # Step 1: generate token
      Sigra.MockRepo
      |> expect(:transaction, fn _multi ->
        updated_cred = %{cred | last_used_at: DateTime.utc_now() |> DateTime.truncate(:second)}
        {:ok, %{credential_last_used: updated_cred, audit_service_account_token_issued: nil}}
      end)

      {:ok, %{access_token: jwt}} = JWT.generate_service_account_tokens(cfg, sa, cred)

      # Step 2: revoke the credential.
      # revoke_credential/3 calls load_service_account (get) + Multi.update + audit.
      # Pattern B: synthetic UUID in sa_scope; ensure_user_scope!/2 requires non-nil user.
      Sigra.MockRepo
      |> expect(:get, fn Sigra.JWTTest.SASchema, _id -> sa end)
      |> expect(:transaction, fn _multi ->
        revoked_cred = %{cred | revoked_at: DateTime.utc_now()}
        {:ok, %{credential: revoked_cred, audit_service_account_credential_revoke: nil}}
      end)

      assert {:ok, _revoked_cred} = Sigra.ServiceAccounts.revoke_credential(cfg, sa_scope, cred)

      # Step 3: verify_access returns error — credential has revoked_at set.
      # verify_service_account_epoch checks `credential.revoked_at == nil`; when
      # revoked it returns {:error, :epoch_mismatch} (single error atom for all
      # SA verify failures in lib/sigra/jwt.ex lines 491-499).
      revoked_cred = %{cred | revoked_at: DateTime.utc_now()}

      Sigra.MockRepo
      |> expect(:get, fn Sigra.JWTTest.SASchema, _id -> sa end)
      |> expect(:get, fn Sigra.JWTTest.CredentialSchema, _id -> revoked_cred end)

      # Lock: result MUST be {:error, _atom}, NOT {:ok, _claims}.
      assert {:error, _atom} = JWT.verify_access(cfg, jwt)
    end

    test "user JWT path is unaffected (parity regression guard)" do
      # Reuses the user-token path. Generates a user token, verifies it, and
      # asserts that actor_type is NOT 'service_account' and verify returns {:ok, _}.
      # This pins the parity invariant: the SA describe block is purely additive.
      user = test_user(%{token_epoch: 0})
      cfg = config(jwt: [enabled: true, algorithm: "HS256", issuer: "test_issuer", access_ttl: 900, refresh: false, verify_epoch: true])

      {:ok, tokens} = JWT.generate_tokens(cfg, user, ["read:users"], token_opts())

      Sigra.MockRepo
      |> expect(:get, fn Sigra.TestUser, "42" ->
        %{id: 42, token_epoch: 0}
      end)

      assert {:ok, claims} = JWT.verify_access(cfg, tokens.access_token)
      # User path: actor_type is nil or absent — NOT "service_account"
      refute claims["actor_type"] == "service_account"
      assert claims["sub"] == "42"
    end
  end
end
