defmodule ExampleWeb.SessionControllerTest do
  @moduledoc """
  Phase 10.1.1 Plan 04 (B9): ConnTest locking the login page as a plain
  controller + HEEx render rather than a LiveView. See
  .planning/phases/10.1.1-example-app-repair-ci-install-usage-smoke-harness/10.1.1-04-PLAN.md.

  These tests prove:
    1. `GET /users/log_in` is a dead render (no `phx-submit`, no
       `data-phx-session` — i.e. no LiveView intercepts the form submit).
    2. `POST /users/log_in` with valid credentials produces a 302 + a
       Set-Cookie for the Plug session, matching the canonical
       phx.gen.auth shape.
    3. `POST /users/log_in` with invalid credentials redirects back to
       the login page with an enumeration-safe error flash.
    4. `POST /users/log_in` with `_action=magic_link` returns the
       enumeration-safe info flash.
  """
  use ExampleWeb.ConnCase, async: true
  import Example.AccountsFixtures

  alias Example.Accounts
  alias Example.Accounts.Scope
  alias Example.Demo.Branding

  @moduletag :example_app

  setup do
    attrs = valid_user_attributes()
    {:ok, user} = Accounts.register_user(attrs)
    %{user: user, password: attrs.password}
  end

  describe "GET /users/log_in (B9 plain-controller login page)" do
    test "renders 200 with compact password, passkey, magic-link, and SSO controls", %{conn: conn} do
      conn = get(conn, ~p"/users/log_in")
      body = html_response(conn, 200)

      assert body =~ ~s(data-testid="vaultr-login")
      # Real login is the plain Vaultr app surface — no demo-brand switcher hooks
      # (so neither the cookie nor demo_branding.js re-skins it) and no inline brand
      # style (it uses the global Vaultr palette + OS light/dark like the homepage).
      refute body =~ "data-demo-brand"
      assert body =~ "Log in to Vaultr"
      assert body =~ ~s(src="/images/vaultr-mark.svg")
      assert body =~ ~s(id="passkey_login_form")
      assert body =~ ~s(id="magic_link_form")
      assert body =~ ~s(id="login_form")
      assert body =~ ~s(id="enterprise_login_form")
      assert body =~ ~s(action="/users/log_in")
      assert body =~ ~s(method="post")
      assert body =~ "Log in to"
      assert body =~ "New to"
      assert body =~ "Create an account."
      assert body =~ "Use a passkey"
      assert body =~ "Email me a magic link"
      assert body =~ "Enterprise SSO"
      assert body =~ "Keep me signed in"
      assert body =~ ~s(data-passkey-login-status)
      assert body =~ ~s(data-passkey-status="")
      assert body =~ ~s(autocomplete="username webauthn")
      refute body =~ "Use your email and password"
      refute body =~ "Passkeys appear through browser autofill"
      refute body =~ "Secured by Sigra"
      refute body =~ "Keep me logged in"
      refute body =~ "shared demo login for Vaultr users and Sigra Admin operators"
      refute body =~ "admin@demo.vaultr.test"
      refute body =~ "We couldn't finish passkey sign-in"
    end

    test "ignores the demo brand cookie — the real login is always Vaultr", %{conn: conn} do
      # The homepage brand-lab can preview Night Ops / Meridian, but selecting one
      # (which writes the sigra_demo_brand cookie) must NOT re-brand the real login.
      conn =
        conn
        |> put_req_cookie(Branding.cookie_name(), "meridian")
        |> put_req_cookie(Branding.theme_cookie_name(), "dark")
        |> get(~p"/users/log_in")

      body = html_response(conn, 200)

      assert body =~ "Log in to Vaultr"
      assert body =~ ~s(src="/images/vaultr-mark.svg")
      refute body =~ "data-demo-brand"
      refute body =~ "Meridian"
      refute body =~ "Night Ops"
    end

    test "login page is a dead render (no phx-* attributes)", %{conn: conn} do
      body = conn |> get(~p"/users/log_in") |> html_response(200)

      # If LiveView were still in use, these would appear on the rendered
      # container or form. Their absence proves the page is a plain
      # controller render and the browser will issue a real HTTP POST.
      refute body =~ "phx-submit"
      refute body =~ "data-phx-session"
    end
  end

  describe "POST /users/log_in (password path)" do
    test "valid credentials return 302 + set session cookie", %{
      conn: conn,
      user: user,
      password: password
    } do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => password}
        })

      assert redirected_to(conn) == ~p"/app"
      # Plug session cookie is set when renew_session runs during log_in_user.
      assert get_resp_header(conn, "set-cookie") != []
    end

    test "invalid credentials return 302 back to /users/log_in with error flash", %{
      conn: conn,
      user: user
    } do
      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => "wrong-password"}
        })

      assert redirected_to(conn) == ~p"/users/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Invalid email or password"
    end

    test "SSO-only denial redirects to the organization enterprise sign-in route", %{
      conn: conn,
      user: user,
      password: password
    } do
      owner = user_fixture(%{email: "owner-#{System.unique_integer([:positive])}@example.com"})
      organization = create_organization(%{name: "Acme", slug: "acme-sso"})
      create_membership(owner, organization, :owner)
      create_membership(user, organization, :member)
      create_enterprise_connection(organization, ["example.com"])

      assert {:ok, _policy_state} =
               Example.Organizations.enable_sso_only(
                 %Scope{user: owner, active_organization: organization},
                 [owner.id]
               )

      conn =
        post(conn, ~p"/users/log_in", %{
          "user" => %{"email" => user.email, "password" => password}
        })

      assert redirected_to(conn) ==
               ~p"/organizations/acme-sso/sso?#{%{routing_source: "local_policy"}}"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "requires enterprise sign-in"
    end
  end

  describe "POST /users/log_in (_action=magic_link)" do
    test "returns 302 with enumeration-safe info flash", %{conn: conn, user: user} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "_action" => "magic_link",
          "user" => %{"email" => user.email}
        })

      assert redirected_to(conn) == ~p"/users/log_in"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "magic link"
    end
  end

  describe "POST /users/log_in (_action=enterprise)" do
    test "redirects an exact domain match to the canonical organization SSO route", %{conn: conn} do
      organization = create_organization(%{name: "Acme", slug: "acme"})
      create_enterprise_connection(organization, ["acme.example"])

      conn =
        post(conn, ~p"/users/log_in", %{
          "_action" => "enterprise",
          "user" => %{"email" => "person@acme.example"}
        })

      assert redirected_to(conn) ==
               ~p"/organizations/acme/sso?#{%{routing_source: "domain_discovery"}}"
    end

    test "shows a bounded error when discovery has no exact match", %{conn: conn} do
      conn =
        post(conn, ~p"/users/log_in", %{
          "_action" => "enterprise",
          "user" => %{"email" => "person@unknown.example"}
        })

      assert redirected_to(conn) == ~p"/users/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "couldn't find an organization"
    end
  end

  defp create_enterprise_connection(organization, login_hint_domains) do
    %Example.Accounts.EnterpriseConnection{}
    |> Example.Accounts.EnterpriseConnection.changeset(%{
      organization_id: organization.id,
      protocol: :oidc,
      status: :active,
      display_name: "Enterprise #{System.unique_integer([:positive])}",
      login_hint_domains: login_hint_domains,
      oidc_settings: %{
        issuer: "https://idp.example.com",
        discovery_document_uri: "https://idp.example.com/.well-known/openid-configuration",
        client_id: "client-id",
        encrypted_client_secret: "super-secret",
        client_authentication_method: "client_secret_basic",
        scopes: ["openid", "profile", "email"]
      }
    })
    |> Example.Repo.insert!()
  end
end
