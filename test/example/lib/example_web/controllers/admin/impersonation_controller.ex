defmodule ExampleWeb.Admin.ImpersonationController do
  @moduledoc """
  Controller-owned impersonation start and stop endpoints.
  """

  use ExampleWeb, :controller

  import Plug.Conn

  alias Example.Accounts
  alias ExampleWeb.AuthErrorHandler
  alias ExampleWeb.UserAuth
  @sudo_window 300

  def create(conn, %{"id" => user_id} = params) do
    admin_scope = conn.assigns.admin_scope
    admin_session = conn.private[:sigra_session]
    admin_token = get_session(conn, :user_token)
    target_user = impersonation_target(user_id)

    if sudo_fresh?(admin_session) do
      case Sigra.Impersonation.start(
             impersonation_config(),
             admin_scope,
             admin_session,
             target_user,
             admin_token: admin_token,
             ip_address: client_ip(conn),
             user_agent: client_user_agent(conn)
           ) do
        {:ok, %{session: session}} ->
          conn
          |> UserAuth.begin_impersonation(session.token, admin_token,
            return_to: safe_return_to(Map.get(params, "return_to"))
          )
          |> put_flash(:info, "Impersonation started.")
          |> redirect(to: ~p"/")

        {:error, :not_allowed} ->
          conn
          |> AuthErrorHandler.auth_error(:not_found, [])
          |> halt()

        {:error, :already_impersonating} ->
          conn
          |> put_flash(
            :error,
            "End the current impersonation session before starting another one."
          )
          |> redirect(to: ~p"/")

        {:error, _reason} ->
          conn
          |> put_flash(:error, "We couldn't start impersonation.")
          |> redirect(to: ~p"/")
      end
    else
      conn
      |> put_flash(:error, "Please re-enter your password to continue.")
      |> redirect(to: sudo_path(conn, params))
    end
  end

  def delete(conn, params) do
    current_scope = conn.assigns.current_scope
    current_session = conn.private[:sigra_session]
    admin_token = get_session(conn, :impersonator_user_token)

    case {current_scope, current_session, admin_token} do
      {%{impersonating_from: %_{}} = scope, %Sigra.Session{} = session, admin_token}
      when is_binary(admin_token) ->
        {:ok, _result} =
          Sigra.Impersonation.stop(
            impersonation_config(),
            scope,
            session,
            admin_token: admin_token,
            ip_address: client_ip(conn),
            user_agent: client_user_agent(conn)
          )

        conn
        |> UserAuth.restore_impersonation()
        |> put_flash(:info, "Impersonation ended.")
        |> redirect(to: stop_return_to(conn, Map.get(params, "return_to")))

      _ ->
        conn
        |> put_flash(:error, "No impersonation session is active.")
        |> redirect(to: ~p"/")
    end
  end

  defp impersonation_target(user_id) do
    user = Accounts.get_user!(user_id)

    organization_ids =
      user
      |> Example.Organizations.list_organizations_for_user()
      |> Enum.map(fn {organization, _role} -> organization.id end)

    Map.put(user, :organization_ids, organization_ids)
  end

  defp stop_return_to(conn, requested_return_to) do
    case safe_return_to(requested_return_to) do
      nil -> UserAuth.impersonation_return_to(conn) || ~p"/"
      path -> path
    end
  end

  defp safe_return_to(path) when is_binary(path) do
    if String.starts_with?(path, "/") and not String.starts_with?(path, "//") do
      path
    end
  end

  defp safe_return_to(_path), do: nil

  defp client_ip(conn) do
    conn.remote_ip && to_string(:inet.ntoa(conn.remote_ip))
  end

  defp client_user_agent(conn) do
    conn |> get_req_header("user-agent") |> List.first() || ""
  end

  defp impersonation_config do
    %{Accounts.sigra_config() | scope_module: Example.Accounts.Scope}
  end

  defp sudo_fresh?(%Sigra.Session{sudo_at: %DateTime{} = sudo_at}) do
    DateTime.diff(DateTime.utc_now(), sudo_at, :second) <= @sudo_window
  end

  defp sudo_fresh?(_session), do: false

  defp sudo_path(conn, params) do
    return_to = current_path(conn, Map.take(params, ["return_to"]))
    "/users/sudo?return_to=#{URI.encode_www_form(return_to)}"
  end
end
