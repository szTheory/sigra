defmodule ExampleWeb.AppLiveTest do
  use ExampleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Example.AccountsFixtures

  describe "/app account home" do
    test "redirects unauthenticated visitors to the login page", %{conn: conn} do
      assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/app")
      assert path =~ "/users/log_in"
    end

    test "greets a standard user and hides operator surfaces", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/app")

      assert html =~ "Welcome back"
      assert html =~ user.email
      assert html =~ "app-account-home"
      assert html =~ "app-security"
      # A standard user has no admin scope — no operator card, no /admin lure.
      refute html =~ "app-platform-admin"
      refute html =~ "Open Sigra Admin"
      # Dev-only "Demo personas" switch bar is compiled out under mix test
      # (dev_routes=false) — mirrors the existing /demo/credentials 404 proof.
      refute html =~ "demo-persona-switch"
    end

    test "shows the Sigra Admin card for a platform admin", %{conn: conn} do
      admin = user_fixture(%{email: "platform-admin+app@example.test"})
      conn = log_in_user(conn, admin)

      {:ok, _lv, html} = live(conn, ~p"/app")

      assert html =~ "app-platform-admin"
      assert html =~ "Open Sigra Admin"
      assert html =~ ~p"/admin"
    end
  end
end
