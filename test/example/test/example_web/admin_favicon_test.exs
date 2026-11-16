defmodule ExampleWeb.AdminFaviconTest do
  @moduledoc """
  BTOK-05 asset wiring: the book's favicon pair is linked only on Sigra-owned
  pages (the admin and the design gallery under `/admin`), never on a host-facing
  Tasklane page, and the demo's root `/favicon.ico` keeps serving unchanged.

  The design gallery (`/admin/_design`) is mounted only under `dev_routes`, so it is
  not reachable in the test build; its path shape is covered by the
  `sigra_owned_page?/1` cases below and its rendered links by the Playwright lane.

  The brand stylesheet (`sigra_admin_brand.css`, the two self-hosted web fonts) is
  linked from the shared root layout, so it is present on both kinds of page; its
  font tokens are scoped to `.sg-admin-shell` and only the admin shell opts in.
  """

  use ExampleWeb.ConnCase, async: false

  @moduletag :example_app

  alias Example.AccountsFixtures

  @ico_href ~s(href="/images/sigra-favicon.ico")
  @svg_href ~s(href="/favicon.svg")
  @brand_css_href ~s(href="/assets/css/sigra_admin_brand.css")

  describe "Sigra-owned pages" do
    test "the admin overview links the ICO first, then the SVG, and the brand stylesheet" do
      conn = build_conn() |> log_in_user(platform_admin()) |> get(~p"/admin")

      html = html_response(conn, 200)

      assert {ico_at, _} = :binary.match(html, @ico_href)
      assert {svg_at, _} = :binary.match(html, @svg_href)
      assert ico_at < svg_at, "the ICO link must be emitted before the SVG link"

      assert html =~ ~s(rel="icon" href="/images/sigra-favicon.ico" sizes="16x16 32x32")
      assert html =~ ~s(rel="icon" href="/favicon.svg" type="image/svg+xml")
      assert html =~ @brand_css_href
    end

    test "another admin page links both favicons too" do
      conn = build_conn() |> log_in_user(platform_admin()) |> get(~p"/admin/users")

      html = html_response(conn, 200)

      assert html =~ @ico_href
      assert html =~ @svg_href
    end

    test "the brand stylesheet is linked after app.css" do
      conn = build_conn() |> log_in_user(platform_admin()) |> get(~p"/admin")

      html = html_response(conn, 200)

      assert {app_at, _} = :binary.match(html, ~s(href="/assets/css/app.css"))
      assert {brand_at, _} = :binary.match(html, @brand_css_href)
      assert app_at < brand_at
    end
  end

  describe "host-facing Tasklane pages" do
    test "the login page emits no icon link but still links the brand stylesheet" do
      conn = get(build_conn(), ~p"/users/log_in")

      html = html_response(conn, 200)

      refute html =~ ~s(rel="icon")
      refute html =~ @ico_href
      refute html =~ @svg_href
      assert html =~ @brand_css_href
    end
  end

  describe "static assets" do
    test "the SVG favicon is served" do
      conn = get(build_conn(), ~p"/favicon.svg")

      assert response(conn, 200) =~ "<svg"
    end

    test "the ICO favicon is served from the images path" do
      conn = get(build_conn(), ~p"/images/sigra-favicon.ico")

      assert response(conn, 200)
    end

    test "the demo's root favicon.ico still serves" do
      conn = get(build_conn(), ~p"/favicon.ico")

      assert response(conn, 200)
    end

    test "the brand stylesheet is served" do
      conn = get(build_conn(), ~p"/assets/css/sigra_admin_brand.css")

      assert response(conn, 200) =~ "Instrument Sans"
    end
  end

  describe "sigra_owned_page?/1" do
    test "is true for /admin and anything beneath it" do
      for path <- ["/admin", "/admin/users", "/admin/_design", "/admin/organizations/acme/users"] do
        assert ExampleWeb.Layouts.sigra_owned_page?(%Plug.Conn{request_path: path}), path
      end
    end

    test "is false for Tasklane paths, a lookalike prefix and anything that is not a conn" do
      for path <- ["/", "/users/log_in", "/app", "/administrator", "/demo/credentials"] do
        refute ExampleWeb.Layouts.sigra_owned_page?(%Plug.Conn{request_path: path}), path
      end

      refute ExampleWeb.Layouts.sigra_owned_page?(nil)
    end
  end

  defp platform_admin do
    AccountsFixtures.user_fixture(%{
      email: "platform-admin+#{System.unique_integer([:positive])}@example.com"
    })
  end
end
