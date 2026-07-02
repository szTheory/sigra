defmodule ExampleWeb.AccountActiveRedirectTest do
  @moduledoc """
  Wiring coverage for `ExampleWeb.UserAuth.check_account_active/2` in the
  `:require_authenticated` pipeline (todo: wire-check-account-active-reactivation).

  Deletion-scheduled users (`deleted_at != nil`) must be intercepted into the
  reactivation flow instead of landing on `/app`, AND the reactivation page
  itself must stay reachable so the redirect can't loop.
  """
  use ExampleWeb.ConnCase, async: true

  import Example.AccountsFixtures

  describe "check_account_active wired into :require_authenticated" do
    test "deletion-scheduled user is redirected from /app to reactivation", %{conn: conn} do
      user = scheduled_deletion_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/app")

      assert redirected_to(conn) == ~p"/users/reactivation"
    end

    test "deletion-scheduled user can reach the reactivation page (no loop)", %{conn: conn} do
      user = scheduled_deletion_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/users/reactivation")

      # Regression guard: with the exempt-path guard absent, this would 302 back
      # to /users/reactivation forever instead of rendering.
      assert html_response(conn, 200)
    end

    test "active user reaches /app normally (not redirected)", %{conn: conn} do
      user = user_fixture()

      conn =
        conn
        |> log_in_user(user)
        |> get(~p"/app")

      assert html_response(conn, 200)
    end
  end
end
