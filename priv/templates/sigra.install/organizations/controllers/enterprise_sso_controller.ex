defmodule <%= web_module %>.EnterpriseSSOController do
  @moduledoc """
  Canonical organization-scoped enterprise sign-in controller.

  The generated host owns the route, copy, and retry UX. Sigra owns the
  security-critical routing, signed OAuth state, callback revalidation, and
  session metadata truth.
  """

  use <%= web_module %>, :controller

  alias Sigra.Error.OAuthError
  alias <%= app_module %>.Organizations
  alias <%= context_module %>, as: Auth
  alias <%= web_module %>.UserAuth

  @enterprise_session_key :enterprise_auth_session

  def new(conn, %{"org" => org_slug} = params) do
    case Organizations.get_routable_enterprise_connection(org_slug) do
      {:ok, routing} ->
        html(conn, enterprise_entry_html(routing, routing_source(params)))

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Enterprise sign-in is not available for this organization right now.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def create(conn, %{"org" => org_slug} = params) do
    with {:ok, routing} <- Organizations.get_routable_enterprise_connection(org_slug),
         {:ok, authorize_url, session_params} <-
           Sigra.OAuth.authorize_url(Auth.sigra_config(), :oidc,
             enterprise: %{
               organization_id: routing.organization_id,
               connection_id: routing.connection_id,
               routing_source: routing_source(params)
             }
           ) do
      conn
      |> put_session(@enterprise_session_key, session_params)
      |> redirect(external: authorize_url)
    else
      {:error, %OAuthError{} = error} ->
        conn
        |> put_flash(:error, oauth_error_message(error))
        |> redirect(to: ~p"/organizations/#{org_slug}/sso")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Enterprise sign-in is not available for this organization right now.")
        |> redirect(to: ~p"/organizations/#{org_slug}/sso")
    end
  end

  def callback(conn, %{"org" => org_slug} = params) do
    session_params = get_session(conn, @enterprise_session_key) || %{}

    case Sigra.OAuth.handle_callback(Auth.sigra_config(), :oidc, params, session_params) do
      {:ok, _result, user, session_metadata} ->
        metadata =
          session_metadata
          |> Map.put(:ip, client_ip(conn))
          |> Map.put(:user_agent, client_user_agent(conn))

        case Sigra.Auth.create_session(Auth.sigra_config(), user, metadata, []) do
          {:ok, session} ->
            conn
            |> delete_session(@enterprise_session_key)
            |> put_flash(:info, "Welcome!")
            |> UserAuth.put_user_session_token(session.token)
            |> redirect(to: ~p"/organizations/#{org_slug}/settings")

          {:error, _reason} ->
            conn
            |> delete_session(@enterprise_session_key)
            |> put_flash(:error, "We couldn't finish enterprise sign-in. Please try again.")
            |> redirect(to: ~p"/organizations/#{org_slug}/sso")
        end

      {:link_confirmation_required, _info} ->
        conn
        |> delete_session(@enterprise_session_key)
        |> put_flash(:error, "Finish sign-in with your existing account before linking enterprise access.")
        |> redirect(to: ~p"/organizations/#{org_slug}/sso")

      {:error, %OAuthError{} = error} ->
        conn
        |> delete_session(@enterprise_session_key)
        |> put_flash(:error, oauth_error_message(error))
        |> redirect(to: ~p"/organizations/#{org_slug}/sso")
    end
  end

  defp enterprise_entry_html(routing, routing_source) do
    org_name = routing.organization_name || routing.organization_slug || "your organization"
    escaped_org_name = org_name |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
    action = "/organizations/#{routing.organization_slug}/sso"
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    """
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>#{escaped_org_name} enterprise sign-in</title>
      </head>
      <body>
        <main style="max-width: 32rem; margin: 4rem auto; padding: 0 1rem; font-family: system-ui, sans-serif;">
          <div style="border: 1px solid #d6d3d1; border-radius: 1.25rem; padding: 2rem; box-shadow: 0 12px 32px rgba(15, 23, 42, 0.08);">
            <p style="margin: 0 0 0.75rem; font-size: 0.85rem; letter-spacing: 0.08em; text-transform: uppercase; color: #78716c;">
              Enterprise sign-in
            </p>
            <h1 style="margin: 0 0 0.75rem; font-size: 1.75rem; line-height: 1.2;">
              Continue to #{escaped_org_name} enterprise sign-in
            </h1>
            <p style="margin: 0 0 1.5rem; color: #57534e;">
              Sigra resolved this sign-in to #{escaped_org_name}. Continue to start the organization-scoped enterprise flow.
            </p>
            <form method="post" action="#{action}">
              <input type="hidden" name="_csrf_token" value="#{csrf_token}" />
              <input type="hidden" name="routing_source" value="#{routing_source}" />
              <button type="submit" style="width: 100%; border: 0; border-radius: 999px; padding: 0.85rem 1rem; background: #0f766e; color: white; font-size: 1rem; font-weight: 600; cursor: pointer;">
                Continue with enterprise SSO
              </button>
            </form>
            <p style="margin: 1rem 0 0; font-size: 0.9rem; color: #78716c;">
              Need a different organization? Return to the login page and try a different work email or explicit organization path.
            </p>
          </div>
        </main>
      </body>
    </html>
    """
  end

  defp routing_source(%{"routing_source" => "domain_discovery"}), do: :domain_discovery
  defp routing_source(_params), do: :explicit_org

  defp oauth_error_message(%OAuthError{error_code: :enterprise_context_mismatch}),
    do: "Your enterprise sign-in session expired. Please try again."

  defp oauth_error_message(%OAuthError{error_code: :org_connection_unavailable}),
    do: "Enterprise sign-in is not available for this organization right now."

  defp oauth_error_message(_error),
    do: "We couldn't finish enterprise sign-in. Please try again."

  defp client_ip(conn) do
    conn.remote_ip && to_string(:inet.ntoa(conn.remote_ip))
  end

  defp client_user_agent(conn) do
    conn |> get_req_header("user-agent") |> List.first() || ""
  end
end
