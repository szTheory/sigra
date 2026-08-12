defmodule Sigra.Plug.FetchBearerTest do
  use ExUnit.Case, async: true

  import Mox
  import Plug.Test

  alias Sigra.JWT
  alias Sigra.Plug.FetchBearer

  defmodule TestScope do
    @moduledoc false
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

  @secret_key_base String.duplicate("b", 64)

  defp config(overrides \\ []) do
    Sigra.Config.new!(
      repo: Sigra.MockRepo,
      user_schema: Sigra.TestUser,
      otp_app: :test_app,
      secret_key_base: @secret_key_base,
      api_token:
        Keyword.get(overrides, :api_token,
          prefix: "test_app_sk_",
          api_token_schema: Sigra.TestAPIToken
        ),
      jwt:
        Keyword.get(overrides, :jwt,
          enabled: true,
          algorithm: "HS256",
          issuer: "test_issuer",
          access_ttl: 900,
          refresh: false,
          verify_epoch: false
        )
    )
  end

  defp opts(overrides \\ []),
    do: FetchBearer.init(config: config(overrides), scope_module: TestScope)

  defp jwt_for(user, config) do
    {:ok, %{access_token: jwt}} = JWT.generate_tokens(config, user, ["profile:read"])
    jwt
  end

  test "configured prefix dispatches to FetchAPIToken before enabled JWT detection" do
    raw_token = "eyJ_prefers_configured_pat"

    token = %{
      id: "pat-1",
      user_id: "user-1",
      scopes: ["profile:read"],
      revoked_at: nil,
      expires_at: nil,
      last_used_at: nil
    }

    user = %Sigra.TestUser{id: "user-1"}
    options = opts(api_token: [prefix: "eyJ_", api_token_schema: Sigra.TestAPIToken])

    expect(Sigra.MockRepo, :get_by, fn Sigra.TestAPIToken, hashed_token: _hash -> token end)
    expect(Sigra.MockRepo, :get, fn Sigra.TestUser, "user-1" -> user end)

    conn =
      conn(:get, "/api/resource")
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> raw_token)
      |> FetchBearer.call(options)

    assert %TestScope{user: ^user} = conn.assigns.current_scope

    assert conn.private[:sigra_auth] == %{
             credential_kind: :personal_access_token,
             credential_id: "pat-1",
             scopes: ["profile:read"],
             auth_method: :api_token,
             assurance: []
           }

    refute inspect(conn.assigns) =~ raw_token
    refute inspect(conn.private[:sigra_auth]) =~ raw_token
  end

  test "enabled eyJ bearer dispatches to FetchJWT and preserves its bounded facts" do
    config = config()
    user = %Sigra.TestUser{id: 42}
    jwt = jwt_for(user, config)

    expect(Sigra.MockRepo, :get, fn Sigra.TestUser, "42" -> user end)

    conn =
      conn(:get, "/api/resource")
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> jwt)
      |> FetchBearer.call(FetchBearer.init(config: config, scope_module: TestScope))

    assert %TestScope{user: ^user} = conn.assigns.current_scope

    assert conn.private[:sigra_auth] == %{
             credential_kind: :jwt,
             credential_id: conn.private[:sigra_auth].credential_id,
             scopes: ["profile:read"],
             auth_method: :jwt,
             assurance: []
           }

    assert is_binary(conn.private[:sigra_auth].credential_id)
    refute inspect(conn.assigns) =~ jwt
    refute inspect(conn.private[:sigra_auth]) =~ jwt
  end

  test "opaque default retains PAT dispatch and authentication failures have no facts" do
    token = %{
      id: "pat-2",
      user_id: "user-2",
      scopes: [],
      revoked_at: nil,
      expires_at: nil,
      last_used_at: nil
    }

    user = %Sigra.TestUser{id: "user-2"}

    expect(Sigra.MockRepo, :get_by, fn Sigra.TestAPIToken, hashed_token: _hash -> token end)
    expect(Sigra.MockRepo, :get, fn Sigra.TestUser, "user-2" -> user end)

    successful =
      conn(:get, "/api/resource")
      |> Plug.Conn.put_req_header("authorization", "Bearer opaque_legacy_token")
      |> FetchBearer.call(opts())

    assert %TestScope{user: ^user} = successful.assigns.current_scope
    assert successful.private[:sigra_auth].credential_kind == :personal_access_token

    failed = FetchBearer.call(conn(:get, "/api/resource"), opts())
    assert failed.assigns.current_scope == nil
    refute Map.has_key?(failed.private, :sigra_auth)
  end

  test "an existing Scope skips every compatibility branch" do
    existing_scope = %TestScope{user: %Sigra.TestUser{id: "user-1"}}

    result =
      conn(:get, "/api/resource")
      |> Plug.Conn.put_req_header("authorization", "Bearer eyJ.not.a.jwt")
      |> Plug.Conn.assign(:current_scope, existing_scope)
      |> FetchBearer.call(opts())

    assert result.assigns.current_scope == existing_scope
    refute Map.has_key?(result.private, :sigra_auth)
  end

  test "documents FetchBearer as deprecated compatibility-only migration surface" do
    source = File.read!("lib/sigra/plug/fetch_bearer.ex")

    assert source =~ "@deprecated"
    assert source =~ "FetchAPIToken"
    assert source =~ "FetchJWT"
    assert source =~ "compatibility"
  end
end
