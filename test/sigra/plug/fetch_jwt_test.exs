defmodule Sigra.Plug.FetchJWTTest do
  use ExUnit.Case, async: true

  import Mox
  import Plug.Test

  alias Sigra.JWT
  alias Sigra.Plug.FetchJWT

  defmodule TestScope do
    @moduledoc false
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

  @secret_key_base String.duplicate("j", 64)

  defp config(overrides \\ []) do
    Sigra.Config.new!(
      repo: Sigra.MockRepo,
      user_schema: Sigra.TestUser,
      otp_app: :test_app,
      secret_key_base: @secret_key_base,
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

  defp opts, do: FetchJWT.init(config: config(), scope_module: TestScope)

  defp jwt_for(user, scopes \\ ["profile:read"]) do
    {:ok, %{access_token: jwt}} = JWT.generate_tokens(config(), user, scopes)
    jwt
  end

  test "a valid JWT reloads its string subject into a normal Scope and stores exact trusted facts" do
    user = %Sigra.TestUser{id: 42}
    jwt = jwt_for(user)

    expect(Sigra.MockRepo, :get, fn Sigra.TestUser, "42" -> user end)

    conn =
      conn(:get, "/api/resource")
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> jwt)
      |> FetchJWT.call(opts())

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

  test "missing, malformed, invalid, and deleted-user JWTs assign nil without credential facts" do
    for authorization <- [nil, "Basic nope", "Bearer not.a.valid.jwt"] do
      conn = conn(:get, "/api/resource")

      request_conn =
        if authorization,
          do: Plug.Conn.put_req_header(conn, "authorization", authorization),
          else: conn

      result = FetchJWT.call(request_conn, opts())

      assert result.assigns.current_scope == nil
      refute Map.has_key?(result.private, :sigra_auth)
    end

    jwt = jwt_for(%Sigra.TestUser{id: 99})
    expect(Sigra.MockRepo, :get, fn Sigra.TestUser, "99" -> nil end)

    result =
      conn(:get, "/api/resource")
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> jwt)
      |> FetchJWT.call(opts())

    assert result.assigns.current_scope == nil
    refute Map.has_key?(result.private, :sigra_auth)
  end

  test "a correctly signed JWT is rejected when JWT support is disabled" do
    user = %Sigra.TestUser{id: 42}
    jwt = jwt_for(user)

    disabled_opts =
      FetchJWT.init(
        config: config(jwt: [enabled: false, algorithm: "HS256", issuer: "test_issuer"]),
        scope_module: TestScope
      )

    result =
      conn(:get, "/api/resource")
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> jwt)
      |> FetchJWT.call(disabled_opts)

    assert result.assigns.current_scope == nil
    refute Map.has_key?(result.private, :sigra_auth)
  end

  test "a pre-existing Scope skips header parsing, JWT verification, and Repo work" do
    existing_scope = %TestScope{user: %Sigra.TestUser{id: "user-1"}}

    result =
      conn(:get, "/api/resource")
      |> Plug.Conn.put_req_header("authorization", "Bearer not.a.jwt")
      |> Plug.Conn.assign(:current_scope, existing_scope)
      |> FetchJWT.call(opts())

    assert result.assigns.current_scope == existing_scope
    refute Map.has_key?(result.private, :sigra_auth)
  end
end
