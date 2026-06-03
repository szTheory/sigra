defmodule ExampleWeb.OrganizationSettingsLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.Accounts.EnterpriseConnection
  alias Example.Accounts.OrganizationAuthPolicy
  alias Example.Accounts.OrganizationAuthPolicyExemption
  alias Example.Accounts.Scope
  alias Example.Repo

  defp seed_connection!(organization) do
    %EnterpriseConnection{}
    |> EnterpriseConnection.changeset(%{
      organization_id: organization.id,
      display_name: "Acme Identity",
      login_hint_domains: ["acme.example"],
      status: :active,
      oidc_settings: %{
        issuer: "https://id.acme.example",
        discovery_document_uri: "https://id.acme.example/.well-known/openid-configuration",
        client_id: "client-id",
        encrypted_client_secret: "secret",
        client_authentication_method: "client_secret_basic",
        scopes: ["openid", "profile", "email"]
      }
    })
    |> Repo.insert!()
  end

  describe "organization settings SSO-only controls" do
    setup :register_and_log_in_user

    test "renders enterprise connection and SSO-only policy as separate controls",
         %{conn: conn, user: user} do
      organization = create_organization(%{name: "Acme", slug: "acme-settings"})
      create_membership(user, organization, :owner)
      seed_connection!(organization)

      conn =
        conn
        |> get(~p"/organizations/#{organization.slug}/settings")

      html = html_response(conn, 200)

      assert html =~ "Enterprise SSO"
      assert html =~ "Setup"
      assert html =~ "Routing"
      assert html =~ "Reconciliation"
      assert html =~ "Enforcement"
      assert html =~ "validation_failed"
      assert html =~ "SSO-only policy"
      assert html =~ "Enterprise connection status and SSO-only enforcement are separate controls"
      assert html =~ "Break-glass is password sign-in plus password reset only"
      assert html =~ "Enable SSO-only"
    end

    test "requires an explicit break-glass member before enabling SSO-only",
         %{user: user} do
      organization = create_organization(%{name: "Lockout Org", slug: "lockout-org"})
      create_membership(user, organization, :owner)
      scope = %Scope{user: user, active_organization: organization}

      assert {:error, :break_glass_required} =
               Example.Organizations.enable_sso_only(scope, [])
    end

    test "persists explicit break-glass exemptions through organization-owned rows",
         %{user: user} do
      organization = create_organization(%{name: "Persisted Org", slug: "persisted-org"})
      create_membership(user, organization, :owner)
      scope = %Scope{user: user, active_organization: organization}

      assert {:ok, %{policy: policy, exemptions: exemptions}} =
               Example.Organizations.enable_sso_only(scope, [user.id])

      assert policy.organization_id == organization.id
      assert policy.enforcement_mode == :sso_required
      assert [%{user_id: user_id}] = exemptions
      assert user_id == user.id

      assert Repo.get_by(OrganizationAuthPolicy, organization_id: organization.id)

      assert Repo.get_by(OrganizationAuthPolicyExemption,
               organization_id: organization.id,
               user_id: user.id
             )
    end
  end
end
