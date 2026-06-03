defmodule ExampleWeb.EnterpriseSSOReconciliationFlowTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.Repo
  alias Sigra.Error.OAuthError

  @moduletag :example_app

  defmodule MockEnterpriseOAuth do
    def handle_callback(_config, :oidc, _params, _session_params) do
      :persistent_term.get({__MODULE__, :callback_result})
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
    create_enterprise_connection(organization, ["acme.example"])

    %{organization: organization}
  end

  test "safe reconciliation honors a compatible return path and falls back to /organizations when needed", %{
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
         enterprise_reconciliation_outcome: :existing_membership
       }}
    )

    compatible_conn =
      conn
      |> init_test_session(%{
        enterprise_auth_session: %{state: "state-123"},
        user_return_to: "/organizations/#{organization.slug}/members"
      })
      |> get(~p"/organizations/#{organization.slug}/sso/callback?code=auth-code&state=state-123")

    assert redirected_to(compatible_conn) == ~p"/organizations/#{organization.slug}/members"
    assert get_session(compatible_conn, :user_token)

    fallback_conn =
      conn
      |> recycle()
      |> init_test_session(%{
        enterprise_auth_session: %{state: "state-123"},
        user_return_to: "https://evil.example/phish"
      })
      |> get(~p"/organizations/#{organization.slug}/sso/callback?code=auth-code&state=state-123")

    assert redirected_to(fallback_conn) == ~p"/organizations"
    assert get_session(fallback_conn, :user_token)
  end

  test "unsafe reconciliation returns to the enterprise recovery route without creating a session", %{
    conn: conn,
    organization: organization
  } do
    :persistent_term.put(
      {MockEnterpriseOAuth, :callback_result},
      {:error, %OAuthError{provider: :oidc, error_code: :provider_subject_conflict}}
    )

    conn =
      conn
      |> init_test_session(%{enterprise_auth_session: %{state: "state-123"}})
      |> get(~p"/organizations/#{organization.slug}/sso/callback?code=auth-code&state=state-123")

    assert redirected_to(conn) == ~p"/organizations/#{organization.slug}/sso"
    assert get_session(conn, :user_token) == nil
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
