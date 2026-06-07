defmodule ExampleWeb.PageControllerTest do
  use ExampleWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Vaultr demo app · secured by Sigra"
    assert html =~ "Evaluate Sigra inside a distinct customer app."
    assert html =~ "Vaultr cohort domain"
    assert html =~ "Local evaluation host"
    assert html =~ "One login, two jobs."
    assert html =~ "/users/log_in"
    assert html =~ "admin@demo.vaultr.test"
    assert html =~ "@demo.vaultr.test"
    assert html =~ "Demo personas"
    assert html =~ ">9<"
    assert html =~ "Acme Corp"
    assert html =~ "Beta Labs"
    assert html =~ ~s(data-testid="home-featured-personas")
    assert html =~ "morgan@demo.vaultr.test"
    assert html =~ "/admin/organizations/acme-corp"
    assert html =~ "pat@demo.vaultr.test"
  end
end
