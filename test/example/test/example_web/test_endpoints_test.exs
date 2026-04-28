defmodule ExampleWeb.TestEndpointsTest do
  @moduledoc """
  Regression coverage for the env-gated Phase 87 test-only endpoints.
  Without `EXAMPLE_DB_PROBE_ENABLED=1` and `EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1`,
  these routes must fail closed as 404s.
  """

  use ExampleWeb.ConnCase, async: false

  @moduletag :example_app

  describe "T-87-01: GET /test/db_probe without EXAMPLE_DB_PROBE_ENABLED=1" do
    test "returns 404 when the env var is absent", %{conn: conn} do
      assert System.get_env("EXAMPLE_DB_PROBE_ENABLED") in [nil, "0", ""]

      conn =
        get(conn, "/test/db_probe", %{
          "table" => "user_identities",
          "user_email" => "x@example.test"
        })

      assert conn.status == 404
    end
  end

  describe "T-87-02: POST /test/oauth_issuer/* without EXAMPLE_OAUTH_ISSUER_CTL_ENABLED=1" do
    test "setup returns 404 when the env var is absent", %{conn: conn} do
      assert System.get_env("EXAMPLE_OAUTH_ISSUER_CTL_ENABLED") in [nil, "0", ""]

      conn = post(conn, "/test/oauth_issuer/setup", %{"provider" => "google", "user" => %{}})

      assert conn.status == 404
    end

    test "reset returns 404 when the env var is absent", %{conn: conn} do
      conn = post(conn, "/test/oauth_issuer/reset", %{})

      assert conn.status == 404
    end
  end
end
