defmodule ExampleWeb.PageControllerTest do
  use ExampleWeb.ConnCase

  alias Example.Demo.Branding

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
    assert html =~ ~s(data-testid="demo-brand-lab")
    assert html =~ ~s(data-demo-brand-select)
    assert html =~ "White-label preview"
    assert html =~ "Switch the auth brand"
    assert html =~ "Meridian Health"
    assert html =~ "Night Ops"
    assert html =~ ~s(data-demo-brand-default="night-ops")
    assert html =~ ~s(data-demo-brand-theme-default="dark")
    assert html =~ ~s(data-theme="dark")
    assert html =~ "Brand theme"
    assert html =~ ~s(data-demo-brand-theme)
    assert html =~ "Confirm your Night Ops account"
    assert html =~ "security@night-ops.test"
    assert html =~ "--vt-dark-color-primary: #48d6ca"
    assert html =~ "--vt-dark-color-panel: #0d242b"
    assert html =~ "--vt-light-color-primary: #087d87"
    assert html =~ "Demo personas"
    assert html =~ ">9<"
    assert html =~ "Acme Corp"
    assert html =~ "Beta Labs"
    assert html =~ ~s(data-testid="home-featured-personas")
    assert html =~ "morgan@demo.vaultr.test"
    assert html =~ "/admin/organizations/acme-corp"
    assert html =~ "pat@demo.vaultr.test"
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
