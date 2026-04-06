defmodule Sigra.Plug.FetchBearerTest do
  use ExUnit.Case, async: true
  import Plug.Test

  alias Sigra.Plug.FetchBearer

  defmodule MockTokenVerifier do
    def verify("valid-api-key", _opts), do: {:ok, %{user_id: 42}}
    def verify(_, _opts), do: {:error, :invalid}
  end

  @default_opts [token_verifier: MockTokenVerifier]

  describe "init/1" do
    test "returns opts with token_verifier" do
      opts = FetchBearer.init(@default_opts)
      assert opts[:token_verifier] == MockTokenVerifier
    end
  end

  describe "call/2" do
    test "assigns current_scope when valid Bearer token is present" do
      opts = FetchBearer.init(@default_opts)

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.put_req_header("authorization", "Bearer valid-api-key")
        |> FetchBearer.call(opts)

      assert conn.assigns[:current_scope] == %{user_id: 42}
    end

    test "assigns current_scope as nil when no authorization header" do
      opts = FetchBearer.init(@default_opts)

      conn =
        conn(:get, "/api/resource")
        |> FetchBearer.call(opts)

      assert conn.assigns[:current_scope] == nil
    end

    test "assigns current_scope as nil when token is invalid" do
      opts = FetchBearer.init(@default_opts)

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.put_req_header("authorization", "Bearer bad-token")
        |> FetchBearer.call(opts)

      assert conn.assigns[:current_scope] == nil
    end

    test "assigns current_scope as nil when authorization header is not Bearer" do
      opts = FetchBearer.init(@default_opts)

      conn =
        conn(:get, "/api/resource")
        |> Plug.Conn.put_req_header("authorization", "Basic dXNlcjpwYXNz")
        |> FetchBearer.call(opts)

      assert conn.assigns[:current_scope] == nil
    end
  end

  describe "behaviour" do
    test "implements Plug behaviour" do
      Code.ensure_loaded!(FetchBearer)
      assert function_exported?(FetchBearer, :init, 1)
      assert function_exported?(FetchBearer, :call, 2)
    end
  end
end
