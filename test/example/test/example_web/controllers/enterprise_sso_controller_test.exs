defmodule ExampleWeb.EnterpriseSSOControllerTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.Repo
  alias Sigra.Error.OAuthError

  @moduletag :example_app

  defmodule MockEnterpriseOAuth do
    def authorize_url(_config, :oidc, opts) do
      {:ok, "https://idp.example.com/authorize", %{state: "state-123", enterprise: opts[:enterprise]}}
    end

    def handle_callback(_config, :oidc, _params, _session_params) do
      key = {__MODULE__, :callback_result}
      :persistent_term.get(key)
    end
  end

  setup do
    old_module = Application.get_env(:example, :enterprise_oauth_module)
    Application.put_env(:example, :enterprise_oauth_module, MockEnterpriseOAuth)

    on_exit(fn ->
      :persistent_term.erase({MockEnterpriseOAuth, :callback_result})

      if is_nil(old_module) do
        Application.delete_env(:example, :enterprise_oauth_module)
      else
        Application.put_env(:example, :enterprise_oauth_module, old_module)
      end
    end)

    organization = create_organization(%{name: "Acme", slug: "acme"})
    connection = create_enterprise_connection(organization, ["acme.example"])

    %{organization: organization, connection: connection}
  end

  describe "GET /organizations/:org/sso" do
    test "renders the organization-scoped enterprise entry page", %{
      conn: conn,
      organization: organization
    } do
      conn = get(conn, ~p"/organizations/#{organization.slug}/sso")
      body = html_response(conn, 200)

      assert body =~ "Continue to Acme enterprise sign-in"
      assert body =~ ~s(action="/organizations/acme/sso")
      assert body =~ ~s(name="routing_source" value="explicit_org")
    end
  end

  describe "POST /organizations/:org/sso" do
    test "stores enterprise session state and redirects to the external provider", %{
      conn: conn,
      organization: organization,
      connection: connection
    } do
      conn = post(conn, ~p"/organizations/#{organization.slug}/sso", %{"routing_source" => "domain_discovery"})

      assert redirected_to(conn) == "https://idp.example.com/authorize"

      assert get_session(conn, :enterprise_auth_session) == %{
               state: "state-123",
               enterprise: %{
                 organization_id: organization.id,
                 connection_id: connection.id,
                 routing_source: :domain_discovery
               }
             }
    end
  end

  describe "GET /organizations/:org/sso/callback" do
    test "creates a session and honors an org-compatible return path", %{
      conn: conn,
      organization: organization
    } do
      user = user_fixture(%{email: "person@acme.example"})
      create_membership(user, organization)

      :persistent_term.put(
        {MockEnterpriseOAuth, :callback_result},
        {:ok, :logged_in, user,
         %{
           active_organization_id: organization.id,
           enterprise_connection_id: "conn-id",
           enterprise_routing_source: :explicit_org
         }}
      )

      conn =
        conn
        |> init_test_session(%{
          enterprise_auth_session: %{state: "state-123", enterprise_context: %{organization_id: organization.id}},
          user_return_to: "/organizations/#{organization.slug}/members"
        })
        |> put_req_header("user-agent", "ExUnit")
        |> get(~p"/organizations/#{organization.slug}/sso/callback?code=auth-code&state=state-123")

      assert redirected_to(conn) == ~p"/organizations/#{organization.slug}/members"
      assert get_session(conn, :enterprise_auth_session) == nil
      assert get_session(conn, :user_token)
    end

    test "falls back to /organizations when the stored return path is incompatible", %{
      conn: conn,
      organization: organization
    } do
      user = user_fixture(%{email: "person@acme.example"})
      create_membership(user, organization)

      :persistent_term.put(
        {MockEnterpriseOAuth, :callback_result},
        {:ok, :logged_in, user,
         %{
           active_organization_id: organization.id,
           enterprise_connection_id: "conn-id",
           enterprise_routing_source: :explicit_org,
           enterprise_reconciliation_outcome: :jit_created
         }}
      )

      conn =
        conn
        |> init_test_session(%{
          enterprise_auth_session: %{state: "state-123", enterprise_context: %{organization_id: organization.id}},
          user_return_to: "/organizations/other-org/settings"
        })
        |> get(~p"/organizations/#{organization.slug}/sso/callback?code=auth-code&state=state-123")

      assert redirected_to(conn) == ~p"/organizations"
      assert get_session(conn, :user_token)
    end

    test "maps enterprise context mismatches to a retryable flash", %{
      conn: conn,
      organization: organization
    } do
      :persistent_term.put(
        {MockEnterpriseOAuth, :callback_result},
        {:error, %OAuthError{provider: :oidc, error_code: :enterprise_context_mismatch}}
      )

      conn =
        conn
        |> init_test_session(%{enterprise_auth_session: %{state: "state-123"}})
        |> get(~p"/organizations/#{organization.slug}/sso/callback?code=auth-code&state=state-123")

      assert redirected_to(conn) == ~p"/organizations/#{organization.slug}/sso"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "session expired"
    end

    test "unsafe enterprise outcomes stay on the recovery route without a normal session", %{
      conn: conn,
      organization: organization
    } do
      :persistent_term.put(
        {MockEnterpriseOAuth, :callback_result},
        {:error, %OAuthError{provider: :oidc, error_code: :ambiguous_email_match}}
      )

      conn =
        conn
        |> init_test_session(%{enterprise_auth_session: %{state: "state-123"}})
        |> get(~p"/organizations/#{organization.slug}/sso/callback?code=auth-code&state=state-123")

      assert redirected_to(conn) == ~p"/organizations/#{organization.slug}/sso"
      assert get_session(conn, :user_token) == nil
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
    |> Repo.insert!()
  end
end
