defmodule Sigra.Plug.RequireScopesTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Sigra.Plug.RequireScopes

  defmodule TestErrorHandler do
    @behaviour Sigra.Plug.ErrorHandler

    @impl true
    def auth_error(conn, type, opts) do
      body =
        case type do
          :insufficient_scope ->
            "insufficient_scope:required=#{inspect(Keyword.get(opts, :required_scopes, []))},provided=#{inspect(Keyword.get(opts, :provided_scopes, []))}"

          other ->
            "#{other}"
        end

      conn
      |> Plug.Conn.put_resp_content_type("text/plain")
      |> Plug.Conn.send_resp(403, body)
    end
  end

  defp opts(overrides \\ []) do
    RequireScopes.init(
      Keyword.merge([scopes: ["profile:read"], error_handler: TestErrorHandler], overrides)
    )
  end

  defp scoped_conn(facts, scope \\ %{user: %{id: "user-1"}}) do
    conn(:get, "/api/resource")
    |> Plug.Conn.assign(:current_scope, scope)
    |> maybe_put_facts(facts)
  end

  defp maybe_put_facts(conn, nil), do: conn
  defp maybe_put_facts(conn, facts), do: Plug.Conn.put_private(conn, :sigra_auth, facts)

  describe "init/1" do
    test "preserves options and validates required fields" do
      assert opts()[:scopes] == ["profile:read"]

      assert_raise ArgumentError, ~r/non-empty list/, fn ->
        RequireScopes.init(scopes: [], error_handler: TestErrorHandler)
      end

      assert_raise KeyError, fn -> RequireScopes.init(scopes: ["profile:read"]) end
    end
  end

  test "halts unauthenticated connections through the configured handler" do
    result = conn(:get, "/api/resource") |> RequireScopes.call(opts())

    assert result.halted
    assert result.status == 403
    assert result.resp_body == "unauthenticated"
  end

  test "missing, browser, app-session, and empty facts fail closed with no provided scopes" do
    cases = [
      nil,
      %{credential_kind: :browser_session, scopes: ["profile:read"]},
      %{credential_kind: :app_session, scopes: ["profile:read"]},
      %{credential_kind: :personal_access_token, scopes: []}
    ]

    for facts <- cases do
      result = scoped_conn(facts) |> RequireScopes.call(opts())

      assert result.halted
      assert result.status == 403
      assert result.resp_body =~ "insufficient_scope"
      assert result.resp_body =~ "provided=[]"
    end
  end

  test "trusted PAT and JWT facts pass matching wildcard, all, and any requirements" do
    pat_facts = %{
      credential_kind: :personal_access_token,
      scopes: ["profile:read", "sessions:read"]
    }

    jwt_facts = %{credential_kind: :jwt, scopes: ["*"]}

    refute scoped_conn(pat_facts)
           |> RequireScopes.call(opts(scopes: ["profile:read", "sessions:read"]))
           |> Map.fetch!(:halted)

    refute scoped_conn(pat_facts)
           |> RequireScopes.call(opts(scopes: ["sessions:read", "admin:write"], match: :any))
           |> Map.fetch!(:halted)

    refute scoped_conn(jwt_facts)
           |> RequireScopes.call(opts(scopes: ["anything:write"]))
           |> Map.fetch!(:halted)
  end

  test "spoofed Scope auth fields never grant access" do
    spoofed_scope = %{
      user: %{id: "user-1"},
      auth_method: :api_token,
      token_scopes: ["*", "profile:read"]
    }

    result = scoped_conn(nil, spoofed_scope) |> RequireScopes.call(opts())

    assert result.halted
    assert result.status == 403
    assert result.resp_body =~ "provided=[]"
  end
end
