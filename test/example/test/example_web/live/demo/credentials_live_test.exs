defmodule ExampleWeb.Demo.CredentialsLiveTest do
  use ExampleWeb.ConnCase, async: false

  alias ExampleWeb.Demo.CredentialsLive
  alias Example.Demo.Personas

  describe "env-guard: /demo/credentials" do
    test "route returns 404 in test env (compile_env gate compiles route out)" do
      conn = build_conn() |> get("/demo/credentials")
      assert conn.status == 404
    end
  end

  describe "rendered HTML contract" do
    test "contains required testids and branding" do
      credentials =
        Personas.all()
        |> Enum.map(fn p ->
          local = p.email |> String.split("@") |> hd()
          Map.merge(p, %{local: local, feature: Personas.feature_map()[local]})
        end)

      html =
        CredentialsLive.render(%{
          flash: %{},
          page_title: "Demo Credentials",
          credentials: credentials
        })
        |> Phoenix.HTML.Safe.to_iodata()
        |> IO.iodata_to_binary()

      # DEMO-01: credentials table testids
      assert html =~ ~s(data-testid="demo-credentials-table")
      assert html =~ ~s(data-testid="demo-persona-row-admin")
      assert html =~ ~s(data-testid="demo-persona-row-alice")
      assert html =~ ~s(data-testid="demo-persona-row-bob")
      assert html =~ ~s(data-testid="demo-persona-row-carol")
      assert html =~ ~s(data-testid="demo-persona-row-dave")
      assert html =~ ~s(data-testid="demo-persona-row-frank")
      assert html =~ ~s(data-testid="demo-persona-row-morgan")
      assert html =~ ~s(data-testid="demo-persona-row-pat")
      assert html =~ ~s(data-testid="demo-persona-row-grace")
      assert html =~ ~s(data-testid="demo-dev-only-badge")

      # DEMO-02: branding
      assert html =~ ~s(data-testid="app-name")
      assert html =~ "Vaultr"
      assert html =~ "Sigra supplies its auth"
      assert html =~ "@demo.vaultr.test"
      assert html =~ "admin@demo.vaultr.test"
      assert html =~ "morgan@demo.vaultr.test"
      assert html =~ "/admin/organizations/acme-corp"
    end
  end
end
