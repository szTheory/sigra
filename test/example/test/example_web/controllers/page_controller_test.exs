defmodule ExampleWeb.PageControllerTest do
  use ExampleWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    assert html =~ "Vaultr demo app"
    assert html =~ "A realistic SaaS auth surface for evaluating Sigra."
  end
end
