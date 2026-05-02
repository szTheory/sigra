defmodule Sigra.Plug.FetchBearerTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Sigra.Plug.FetchBearer

  # -- Test scope module --

  defmodule TestScope do
    @moduledoc false
    def new(data), do: data
  end

  # -- Test helpers --

  defp test_config(overrides \\ []) do
    %Sigra.Config{
      repo: Sigra.TestRepo,
      user_schema: Sigra.TestUser,
      otp_app: :test_app,
      secret_key_base: String.duplicate("a", 64),
      api_token:
        Keyword.get(overrides, :api_token,
          prefix: "test_app_sk_",
          api_token_schema: Sigra.TestAPIToken
        ),
      jwt: Keyword.get(overrides, :jwt, enabled: false)
    }
  end

  defp default_opts(config_overrides \\ []) do
    [config: test_config(config_overrides), scope_module: TestScope]
  end

  describe "init/1" do
    test "passes options through" do
      result = FetchBearer.init(default_opts())
      assert Keyword.has_key?(result, :config)
      assert Keyword.has_key?(result, :scope_module)
    end
  end

  describe "call/2 skip behavior" do
    test "skips if current_scope already assigned (D-53)" do
      existing_scope = %{id: 1, auth_method: :session}

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.put_req_header("authorization", "Bearer some_token")
        |> Plug.Conn.assign(:current_scope, existing_scope)

      result = FetchBearer.call(conn, FetchBearer.init(default_opts()))

      # Should remain unchanged -- plug skips entirely
      assert result.assigns.current_scope == existing_scope
    end
  end

  describe "call/2 no token" do
    test "assigns nil when no Authorization header" do
      conn =
        conn(:get, "/api/resource")
        |> FetchBearer.call(FetchBearer.init(default_opts()))

      assert conn.assigns[:current_scope] == nil
    end

    test "assigns nil when Authorization header is not Bearer format" do
      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.put_req_header("authorization", "Basic dXNlcjpwYXNz")
        |> FetchBearer.call(FetchBearer.init(default_opts()))

      assert conn.assigns[:current_scope] == nil
    end
  end

  describe "call/2 auto-detection routing" do
    test "token with configured prefix routes to opaque path" do
      # Token starts with "test_app_sk_" prefix -> opaque path
      # Will call Sigra.APIToken.verify which needs a real repo
      # We verify it takes the opaque path by the error it raises
      opts = FetchBearer.init(default_opts())

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.put_req_header("authorization", "Bearer test_app_sk_abc123def456")

      # APIToken.verify will try to use the repo -- this confirms opaque path taken
      assert_raise UndefinedFunctionError, ~r/Sigra\.TestRepo/, fn ->
        FetchBearer.call(conn, opts)
      end
    end

    test "token starting with eyJ and JWT enabled routes to JWT path" do
      jwt_opts = default_opts(jwt: [enabled: true])
      opts = FetchBearer.init(jwt_opts)

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.put_req_header("authorization", "Bearer eyJhbGciOiJIUzI1NiJ9.payload.sig")

      # JWT path taken: Joken is loaded, invalid JWT returns {:error, :invalid_token}
      # which results in nil scope (NOT an UndefinedFunctionError from the repo,
      # which would happen if the opaque path were taken instead)
      result = FetchBearer.call(conn, opts)
      assert result.assigns.current_scope == nil
    end

    test "token starting with eyJ but JWT disabled falls to opaque path" do
      opts = FetchBearer.init(default_opts(jwt: [enabled: false]))

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.put_req_header("authorization", "Bearer eyJhbGciOiJIUzI1NiJ9.test.sig")

      # JWT disabled -> falls through to opaque path -> APIToken.verify -> repo error
      assert_raise UndefinedFunctionError, ~r/Sigra\.TestRepo/, fn ->
        FetchBearer.call(conn, opts)
      end
    end

    test "prefix match checked FIRST before eyJ check (D-38)" do
      # Token starts with prefix AND would match eyJ check -- prefix wins
      jwt_opts =
        default_opts(
          jwt: [enabled: true],
          api_token: [prefix: "test_app_sk_", api_token_schema: Sigra.TestAPIToken]
        )

      opts = FetchBearer.init(jwt_opts)

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.put_req_header("authorization", "Bearer test_app_sk_eyJsomething")

      # Should go through opaque path (prefix match), NOT JWT path
      # The error will be from APIToken.verify (repo), not JWT
      assert_raise UndefinedFunctionError, ~r/Sigra\.TestRepo/, fn ->
        FetchBearer.call(conn, opts)
      end
    end

    test "token without any prefix falls to default opaque path" do
      opts = FetchBearer.init(default_opts())

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.put_req_header("authorization", "Bearer random_unknown_token")

      # Default fallback -> opaque -> APIToken.verify -> repo error
      assert_raise UndefinedFunctionError, ~r/Sigra\.TestRepo/, fn ->
        FetchBearer.call(conn, opts)
      end
    end
  end

  describe "call/2 prefix derivation" do
    test "derives prefix from otp_app when no explicit prefix" do
      config = %Sigra.Config{
        repo: Sigra.TestRepo,
        user_schema: Sigra.TestUser,
        otp_app: :my_app,
        secret_key_base: String.duplicate("a", 64),
        api_token: [api_token_schema: Sigra.TestAPIToken],
        jwt: [enabled: false]
      }

      opts = FetchBearer.init(config: config, scope_module: TestScope)

      # Token with derived prefix "my_app_sk_" should route to opaque
      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.put_req_header("authorization", "Bearer my_app_sk_token123")

      assert_raise UndefinedFunctionError, ~r/Sigra\.TestRepo/, fn ->
        FetchBearer.call(conn, opts)
      end
    end
  end

  describe "behaviour" do
    test "implements Plug behaviour" do
      Code.ensure_loaded!(FetchBearer)
      assert function_exported?(FetchBearer, :init, 1)
      assert function_exported?(FetchBearer, :call, 2)
    end
  end

  describe "module contents" do
    test "contains required auto-detection patterns" do
      source = File.read!("lib/sigra/plug/fetch_bearer.ex")

      # D-53: skip check
      assert source =~ "conn.assigns[:current_scope]"

      # D-38: eyJ detection
      assert source =~ ~s|String.starts_with?(raw_token, "eyJ")|

      # Delegates to both verification modules
      assert source =~ "Sigra.APIToken.verify"
      assert source =~ "Sigra.JWT.verify_access"

      # Assigns auth_method for both paths
      assert source =~ "auth_method: :api_token"
      assert source =~ "auth_method: :jwt"

      # Token scopes assigned
      assert source =~ "token_scopes:"

      # Config-based option
      assert source =~ ":config"
    end
  end

  # ---------------------------------------------------------------------------
  # Service-account JWT path tests (Gap #2 closure)
  #
  # Inline schemas and mock repo to avoid coupling to Sigra.TestRepo (undefined
  # outside the library's Postgres test context). Uses Process.put/get for
  # per-test state (async: true isolates each test process).
  # ---------------------------------------------------------------------------

  defmodule SAScopeSchemas do
    @moduledoc false

    defmodule ServiceAccount do
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
    end

    defmodule Credential do
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
    end

    defmodule Organization do
      use Ecto.Schema

      @primary_key {:id, :binary_id, autogenerate: false}
      schema "organizations" do
        field :name, :string
      end
    end

    defmodule User do
      use Ecto.Schema

      @primary_key {:id, :integer, autogenerate: false}
      embedded_schema do
        field :email, :string
        field :token_epoch, :integer, default: 0
      end
    end
  end

  # Organizations module stub — required by FetchBearer.load_organization/2
  # to return a non-nil organization, enabling build_jwt_scope to populate
  # active_organization on the SA scope (D-93-11).
  defmodule SATestOrganizations do
    @moduledoc false
    alias Sigra.Plug.FetchBearerTest.SAScopeSchemas

    def __sigra_org_config__ do
      %{
        schemas: %{
          organization: SAScopeSchemas.Organization
        }
      }
    end
  end

  # In-process mock repo for SA JWT path tests — uses Process dictionary for
  # per-test state. Implements all repo callbacks called by:
  #   verify_service_account_epoch/2  (2x get: SA + Credential)
  #   build_jwt_scope/3               (1x get: SA)
  #   load_organization/2             (1x get: Org)
  #   build_user_scope/4              (1x get: User)
  #   generate_service_account_tokens (1x transaction)
  defmodule SAMockRepo do
    @moduledoc false
    alias Sigra.Plug.FetchBearerTest.SAScopeSchemas

    def get(SAScopeSchemas.ServiceAccount, id), do: Process.get({:sa, id})
    def get(SAScopeSchemas.Credential, id), do: Process.get({:credential, id})
    def get(SAScopeSchemas.Organization, id), do: Process.get({:org, id})
    def get(SAScopeSchemas.User, id), do: Process.get({:user, id})
    def get(_schema, _id), do: nil

    def transaction(%Ecto.Multi{} = _multi) do
      # Return success for issuance audit (append_token_issued_audit)
      {:ok, %{credential_last_used: nil, audit_service_account_token_issued: nil}}
    end

    def update(changeset, _opts \\ []), do: {:ok, Ecto.Changeset.apply_changes(changeset)}
    def insert(changeset, _opts \\ []) do
      {:ok, Ecto.Changeset.apply_changes(changeset)}
    end
    def insert_all(_schema, _rows, _opts \\ []), do: {0, nil}
  end

  @sa_secret_key_base String.duplicate("b", 64)

  defp sa_jwt_config do
    Sigra.Config.new!(
      repo: Sigra.Plug.FetchBearerTest.SAMockRepo,
      user_schema: Sigra.Plug.FetchBearerTest.SAScopeSchemas.User,
      otp_app: :test_app,
      secret_key_base: @sa_secret_key_base,
      organizations_module: Sigra.Plug.FetchBearerTest.SATestOrganizations,
      service_accounts: [
        service_account_schema: Sigra.Plug.FetchBearerTest.SAScopeSchemas.ServiceAccount,
        service_account_credential_schema: Sigra.Plug.FetchBearerTest.SAScopeSchemas.Credential,
        client_id_prefix: "sigra_sa_",
        client_id_byte_size: 24
      ],
      jwt: [
        enabled: true,
        algorithm: "HS256",
        issuer: "test_issuer",
        access_ttl: 900,
        client_credentials_access_ttl: 3600,
        refresh: false,
        verify_epoch: true
      ]
    )
  end

  defp build_sa_fixture do
    sa_id = Ecto.UUID.generate()
    org_id = Ecto.UUID.generate()
    cred_id = Ecto.UUID.generate()
    client_id = "sigra_sa_" <> String.slice(Ecto.UUID.generate(), 0, 24)

    sa = %Sigra.Plug.FetchBearerTest.SAScopeSchemas.ServiceAccount{
      id: sa_id,
      name: "CI Account",
      scopes: ["deploy:read", "deploy:write"],
      role: "ci",
      token_epoch: 0,
      revoked_at: nil,
      organization_id: org_id
    }

    cred = %Sigra.Plug.FetchBearerTest.SAScopeSchemas.Credential{
      id: cred_id,
      client_id: client_id,
      hashed_client_secret: :crypto.hash(:sha256, "secret"),
      expires_at: nil,
      last_used_at: nil,
      revoked_at: nil,
      service_account_id: sa_id
    }

    org = %Sigra.Plug.FetchBearerTest.SAScopeSchemas.Organization{
      id: org_id,
      name: "Test Org"
    }

    {sa, cred, org}
  end

  defp put_sa_state(sa, cred, org) do
    Process.put({:sa, sa.id}, sa)
    Process.put({:credential, cred.id}, cred)
    Process.put({:org, org.id}, org)
  end

  defp generate_sa_jwt(cfg, sa, cred) do
    # generate_service_account_tokens calls transaction for audit
    {:ok, %{access_token: jwt}} = Sigra.JWT.generate_service_account_tokens(cfg, sa, cred)
    jwt
  end

  describe "call/2 service-account JWT path" do
    setup do
      cfg = sa_jwt_config()
      {sa, cred, org} = build_sa_fixture()
      put_sa_state(sa, cred, org)

      # Generate a valid SA JWT via the library (transaction mocked by SAMockRepo)
      jwt = generate_sa_jwt(cfg, sa, cred)

      # Also generate an expired SA JWT for the verify-failure test
      signer =
        Joken.Signer.create(
          "HS256",
          :crypto.mac(:hmac, :sha256, @sa_secret_key_base, "sigra-jwt-signing-key")
        )

      now = DateTime.utc_now() |> DateTime.to_unix()

      expired_claims = %{
        "sub" => cred.client_id,
        "iat" => now - 7200,
        "exp" => now - 3600,
        "jti" => Ecto.UUID.generate(),
        "iss" => "test_issuer",
        "scopes" => sa.scopes,
        "epoch" => sa.token_epoch,
        "actor_type" => "service_account",
        "service_account_id" => sa.id,
        "credential_id" => cred.id,
        "org_id" => sa.organization_id
      }

      {:ok, expired_jwt, _} = Joken.generate_and_sign(%{}, expired_claims, signer)

      # Generate a user JWT for the parity regression guard test
      user = %Sigra.Plug.FetchBearerTest.SAScopeSchemas.User{id: 99, email: "user@example.com", token_epoch: 0}
      Process.put({:user, "99"}, user)

      user_signer = signer

      user_claims = %{
        "sub" => "99",
        "iat" => now,
        "exp" => now + 900,
        "jti" => Ecto.UUID.generate(),
        "iss" => "test_issuer",
        "scopes" => ["read:users"],
        "epoch" => 0
      }

      {:ok, user_jwt, _} = Joken.generate_and_sign(%{}, user_claims, user_signer)

      {:ok,
       config: cfg,
       sa: sa,
       cred: cred,
       org: org,
       jwt: jwt,
       expired_jwt: expired_jwt,
       user_jwt: user_jwt,
       user: user}
    end

    test "valid SA JWT builds scope with actor_type: :service_account, service_account_id populated, user: nil",
         %{config: cfg, sa: sa, jwt: jwt} do
      conn =
        conn(:get, "/")
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> jwt)
        |> FetchBearer.call(FetchBearer.init(config: cfg, scope_module: TestScope))

      scope = conn.assigns.current_scope
      assert scope != nil
      assert scope.actor_type == :service_account
      assert scope.service_account_id == sa.id
      # D-93-04: plug-built scope has user: nil for SA tokens.
      # This is a READ assertion on the assigned scope — NOT passing %{user: nil}
      # to a ServiceAccounts mutation (which would raise via ensure_user_scope!/2).
      assert is_nil(scope.user)
      assert scope.active_organization.id == sa.organization_id
    end

    test "valid SA JWT does NOT populate :membership (single auth entry-point invariant — ROADMAP SC #5)",
         %{config: cfg, jwt: jwt} do
      conn =
        conn(:get, "/")
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> jwt)
        |> FetchBearer.call(FetchBearer.init(config: cfg, scope_module: TestScope))

      scope = conn.assigns.current_scope
      assert scope != nil
      # SA path bypasses user-membership lookup — no :membership key populated.
      assert is_nil(Map.get(scope, :membership))
      assert scope.actor_type == :service_account
    end

    test "expired SA JWT assigns current_scope: nil",
         %{config: cfg, expired_jwt: expired_jwt} do
      conn =
        conn(:get, "/")
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> expired_jwt)
        |> FetchBearer.call(FetchBearer.init(config: cfg, scope_module: TestScope))

      # Expired token -> verify_access returns {:error, :token_expired} -> scope nil
      assert is_nil(conn.assigns.current_scope)
    end

    test "valid user JWT still builds a user scope (parity regression guard)",
         %{config: cfg, user_jwt: user_jwt, user: user} do
      conn =
        conn(:get, "/")
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> user_jwt)
        |> FetchBearer.call(FetchBearer.init(config: cfg, scope_module: TestScope))

      scope = conn.assigns.current_scope
      assert scope != nil
      # User path: actor_type is :user; SA actor_type must not be set
      assert scope.actor_type == :user
      assert scope.user != nil
      assert scope.user.id == user.id
      assert is_nil(Map.get(scope, :service_account_id))
    end
  end
end
