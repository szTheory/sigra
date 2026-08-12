defmodule Sigra.Plug.FetchAppSessionTest do
  use ExUnit.Case, async: true

  import Plug.Test

  alias Sigra.Plug.FetchAppSession

  @opts [config: %Sigra.Config{}, scope_module: Sigra.Plug.FetchAppSessionTest.Scope]

  defmodule Scope do
    @moduledoc false
    defstruct [:user]
  end

  test "exports the Plug interface and retains forward-compatible host pipeline options" do
    assert FetchAppSession.init(@opts) == @opts
    assert function_exported?(FetchAppSession, :init, 1)
    assert function_exported?(FetchAppSession, :call, 2)
  end

  test "fails closed without parsing credentials or producing credential state" do
    result =
      conn(:get, "/api/resource")
      |> Plug.Conn.put_req_header("authorization", "Bearer opaque-app-session")
      |> Plug.Conn.put_req_header("cookie", "app_session=opaque-cookie")
      |> FetchAppSession.call(FetchAppSession.init(@opts))

    assert result.assigns.current_scope == nil
    refute Map.has_key?(result.private, :sigra_auth)
    refute Map.has_key?(result.private, :sigra_session)
    refute inspect(result.assigns) =~ "opaque-app-session"
    refute inspect(result.private) =~ "opaque-app-session"
  end

  test "returns an existing authenticated Scope unchanged" do
    existing_scope = %Scope{user: %{id: "user-1"}}

    result =
      conn(:get, "/api/resource")
      |> Plug.Conn.assign(:current_scope, existing_scope)
      |> FetchAppSession.call(FetchAppSession.init(@opts))

    assert result.assigns.current_scope == existing_scope
    refute Map.has_key?(result.private, :sigra_auth)
    refute Map.has_key?(result.private, :sigra_session)
  end
end
