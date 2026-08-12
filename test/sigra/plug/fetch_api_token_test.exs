defmodule Sigra.Plug.FetchAPITokenTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Mox

  alias Sigra.Plug.FetchAPIToken

  defmodule TestScope do
    @moduledoc false
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

  defp config do
    %Sigra.Config{
      repo: Sigra.MockRepo,
      user_schema: Sigra.TestUser,
      otp_app: :test_app,
      secret_key_base: String.duplicate("a", 64),
      api_token: [prefix: "test_app_sk_", api_token_schema: Sigra.TestAPIToken],
      jwt: [enabled: false]
    }
  end

  defp opts, do: FetchAPIToken.init(config: config(), scope_module: TestScope)

  test "a valid PAT loads its current user into a normal Scope and stores exact trusted facts" do
    raw_token = "test_app_sk_secret"
    token = %{id: "pat-1", user_id: "user-1", scopes: ["profile:read"], revoked_at: nil, expires_at: nil}
    user = %Sigra.TestUser{id: "user-1"}

    expect(Sigra.MockRepo, :get_by, fn Sigra.TestAPIToken, hashed_token: _hash -> token end)
    expect(Sigra.MockRepo, :get, fn Sigra.TestUser, "user-1" -> user end)

    conn =
      conn(:get, "/api/resource")
      |> Plug.Conn.put_req_header("authorization", "Bearer " <> raw_token)
      |> FetchAPIToken.call(opts())

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

  test "missing, malformed, invalid, and deleted-user PATs assign nil without credential facts" do
    for authorization <- [nil, "Basic nope"] do
      conn = conn(:get, "/api/resource")
      conn = if authorization, do: Plug.Conn.put_req_header(conn, "authorization", authorization), else: conn
      result = FetchAPIToken.call(conn, opts())
      assert result.assigns.current_scope == nil
      refute Map.has_key?(result.private, :sigra_auth)
    end

    expect(Sigra.MockRepo, :get_by, fn Sigra.TestAPIToken, hashed_token: _hash -> nil end)

    expect(Sigra.MockRepo, :get_by, fn Sigra.TestAPIToken, hashed_token: _hash ->
      %{id: "pat-2", user_id: "gone", scopes: [], revoked_at: nil, expires_at: nil}
    end)

    expect(Sigra.MockRepo, :get, fn Sigra.TestUser, "gone" -> nil end)

    for raw_token <- ["test_app_sk_invalid", "test_app_sk_deleted"] do
      result =
        conn(:get, "/api/resource")
        |> Plug.Conn.put_req_header("authorization", "Bearer " <> raw_token)
        |> FetchAPIToken.call(opts())

      assert result.assigns.current_scope == nil
      refute Map.has_key?(result.private, :sigra_auth)
    end
  end

  test "a pre-existing Scope skips header parsing, verification, and Repo work" do
    existing_scope = %TestScope{user: %Sigra.TestUser{id: "user-1"}}

    result =
      conn(:get, "/api/resource")
      |> Plug.Conn.put_req_header("authorization", "Bearer test_app_sk_secret")
      |> Plug.Conn.assign(:current_scope, existing_scope)
      |> FetchAPIToken.call(opts())

    assert result.assigns.current_scope == existing_scope
    refute Map.has_key?(result.private, :sigra_auth)
  end
end
