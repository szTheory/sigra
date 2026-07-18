defmodule ExampleWeb.PageControllerTest do
  use ExampleWeb.ConnCase

  alias Example.Demo.Branding

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Tasklane demo app · secured by Sigra"
    assert html =~ "Evaluate Sigra inside a distinct customer app."
    assert html =~ "Tasklane cohort domain"
    assert html =~ "Local evaluation host"
    assert html =~ "One login, two jobs."
    assert html =~ "/users/log_in"
    assert html =~ "admin@demo.tasklane.test"
    assert html =~ ~s(data-testid="demo-brand-lab")
    assert html =~ ~s(data-demo-brand-select)
    assert html =~ "White-label preview"
    assert html =~ "Switch the auth brand"
    # The brand-lab still lists every preset (these are preview options)…
    assert html =~ "Meridian Health"
    assert html =~ "Night Ops"
    # …but the brand-lab now DEFAULTS to Tasklane (matching the app identity).
    assert html =~ ~s(data-demo-brand-default="tasklane")
    assert html =~ ~s(data-demo-brand-theme-default="light")
    assert html =~ ~s(data-theme="light")
    assert html =~ "Brand theme"
    assert html =~ ~s(data-demo-brand-theme)
    assert html =~ "Confirm your Tasklane account"
    assert html =~ "noreply@demo.tasklane.test"
    assert html =~ "--vt-light-color-primary: #045f73"
    assert html =~ "--vt-light-color-panel: #fbfefd"
    assert html =~ "--vt-dark-color-primary: #5eead4"
    assert html =~ "Demo personas"
    assert html =~ ">10<"
    assert html =~ "Acme Corp"
    assert html =~ "Beta Labs"
    assert html =~ ~s(data-testid="home-featured-personas")
    assert html =~ "morgan@demo.tasklane.test"
    assert html =~ "/admin/organizations/acme-corp"
    assert html =~ "pat@demo.tasklane.test"
    assert html =~ ~s(id="get-started")
    assert html =~ "dave@demo.tasklane.test"
    assert html =~ "demo=dave"
    assert html =~ "Sign in as"
  end

  test "GET / renders cookie-selected brand on first paint", %{conn: conn} do
    conn =
      conn
      |> put_req_cookie(Branding.cookie_name(), "meridian")
      |> get(~p"/")

    html = html_response(conn, 200)

    assert html =~ ~s(data-demo-brand-default="meridian")
    assert html =~ ~s(data-demo-brand-theme-default="system")
    assert html =~ ~s(data-theme="system")
    assert html =~ "Meridian Health"
    assert html =~ "care@meridian.test"
    assert html =~ "Confirm your Meridian Health account"
    assert html =~ "--vt-light-color-primary: #176b43"
    assert html =~ "--vt-light-color-panel: #ffffff"
    assert html =~ "--vt-dark-color-primary: #72e0aa"
  end

  test "GET / renders cookie-selected brand theme on first paint", %{conn: conn} do
    conn =
      conn
      |> put_req_cookie(Branding.cookie_name(), "meridian")
      |> put_req_cookie(Branding.theme_cookie_name(), "dark")
      |> get(~p"/")

    html = html_response(conn, 200)

    assert html =~ ~s(data-demo-brand-default="meridian")
    assert html =~ ~s(data-demo-brand-theme-default="dark")
    assert html =~ ~s(data-theme="dark")
    assert html =~ "Meridian Health"
    assert html =~ "--vt-dark-color-primary: #72e0aa"
    assert html =~ "--vt-dark-color-panel: #0d281e"
  end
end
