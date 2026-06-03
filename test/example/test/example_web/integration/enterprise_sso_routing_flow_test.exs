defmodule ExampleWeb.EnterpriseSSORoutingFlowTest do
  use ExampleWeb.ConnCase, async: true

  import Example.AccountsFixtures

  alias Example.Repo

  @moduletag :example_app

  test "enterprise discovery routes the user into the canonical organization entry page", %{
    conn: conn
  } do
    organization = create_organization(%{name: "Acme", slug: "acme"})
    create_enterprise_connection(organization, ["acme.example"])

    conn =
      post(conn, ~p"/users/log_in", %{
        "_action" => "enterprise",
        "user" => %{"email" => "person@acme.example"}
      })

    assert redirected_to(conn) == ~p"/organizations/acme/sso?#{%{routing_source: "domain_discovery"}}"

    redirected_conn =
      conn
      |> recycle()
      |> get(~p"/organizations/acme/sso?#{%{routing_source: "domain_discovery"}}")

    body = html_response(redirected_conn, 200)

    assert body =~ "Continue to Acme enterprise sign-in"
    assert body =~ ~s(name="routing_source" value="domain_discovery")
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
    |> Repo.insert!()
  end
end
