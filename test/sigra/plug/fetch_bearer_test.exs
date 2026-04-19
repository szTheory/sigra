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
end
