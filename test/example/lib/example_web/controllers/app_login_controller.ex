defmodule ExampleWeb.AppLoginController do
  use ExampleWeb, :controller

  alias Example.Accounts.Auth.AppSessions
  alias ExampleWeb.AppLoginContinuation

  plug :require_authenticated_browser when action in [:continue, :approve, :cancel]

  def start(conn, params) do
    case AppSessions.start_hosted(params) do
      {:ok, %{continuation: continuation}} ->
        profile_id = params["profile_id"]
        conn = AppLoginContinuation.put(conn, continuation, profile_id)

        case browser_assurance(conn) do
          :completed -> render(conn, :approve, profile_name: profile_id)
          :mfa_pending -> redirect(conn, to: ~p"/users/mfa")
          :unauthenticated -> redirect(conn, to: ~p"/users/log_in")
          :invalid -> invalid_request(conn)
        end

      _ ->
        invalid_request(conn)
    end
  end

  def continue(conn, _params) do
    case AppLoginContinuation.fetch(conn) do
      {:ok, _continuation, profile_id} -> render(conn, :approve, profile_name: profile_id)
      _ -> invalid_request(conn)
    end
  end

  def approve(conn, %{} = params) do
    with [] <- Map.keys(params) -- ["_csrf_token"],
         {:ok, continuation, _profile_id} <- AppLoginContinuation.fetch(conn),
         {:ok, %{code: code, callback: callback, state: state}} <-
           AppSessions.approve_hosted(continuation, current_user(conn), :approve) do
      {conn, _} = AppLoginContinuation.take(conn)

      conn
      |> put_resp_header("referrer-policy", "no-referrer")
      |> redirect(external: callback_with_code(callback, code, state))
    else
      _ -> invalid_request(conn)
    end
  end

  def cancel(conn, %{} = params) do
    with [] <- Map.keys(params) -- ["_csrf_token"],
         {:ok, continuation, _profile_id} <- AppLoginContinuation.fetch(conn),
         {:ok, :cancelled} <-
           AppSessions.approve_hosted(continuation, current_user(conn), :cancel) do
      {conn, _} = AppLoginContinuation.take(conn)
      conn |> put_resp_header("referrer-policy", "no-referrer") |> redirect(to: ~p"/users/log_in")
    else
      _ -> invalid_request(conn)
    end
  end

  def exchange(conn, params) do
    with %{
           "code" => code,
           "code_verifier" => verifier,
           "profile_id" => profile,
           "callback" => callback
         } <- params,
         ["callback", "code", "code_verifier", "profile_id"] <- Enum.sort(Map.keys(params)),
         true <- Enum.all?([code, verifier, profile, callback], &is_binary/1),
         {:ok, credentials} <- AppSessions.exchange_hosted(code, verifier, profile, callback) do
      json(conn, credentials)
    else
      _ -> conn |> put_status(:bad_request) |> json(%{error: "invalid_request"})
    end
  end

  def refresh(conn, %{"refresh_token" => token} = params) do
    with ["refresh_token"] <- Map.keys(params),
         true <- is_binary(token),
         {:ok, credentials} <- AppSessions.refresh(token) do
      json(conn, credentials)
    else
      _ -> conn |> put_status(:unauthorized) |> json(%{error: "invalid_refresh"})
    end
  end

  def refresh(conn, _params),
    do: conn |> put_status(:bad_request) |> json(%{error: "invalid_request"})

  def revoke_family(conn, %{"family_id" => family_id} = params) do
    with ["family_id"] <- Map.keys(params),
         true <- is_binary(family_id),
         {:ok, _family} <- AppSessions.revoke_family(current_user(conn), family_id) do
      json(conn, %{ok: true})
    else
      {:error, :not_found} -> conn |> put_status(:not_found) |> json(%{error: "not_found"})
      _ -> conn |> put_status(:unprocessable_entity) |> json(%{error: "revocation_failed"})
    end
  end

  def revoke_family(conn, _),
    do: conn |> put_status(:unprocessable_entity) |> json(%{error: "revocation_failed"})

  def revoke_all(conn, %{} = params) do
    with [] <- Map.keys(params), {:ok, _count} <- AppSessions.revoke_all(current_user(conn)) do
      json(conn, %{ok: true})
    else
      _ -> conn |> put_status(:unprocessable_entity) |> json(%{error: "revocation_failed"})
    end
  end

  defp require_authenticated_browser(conn, _opts) do
    case browser_assurance(conn) do
      :completed -> conn
      :mfa_pending -> conn |> redirect(to: ~p"/users/mfa") |> halt()
      :unauthenticated -> conn |> redirect(to: ~p"/users/log_in") |> halt()
      :invalid -> conn |> invalid_request() |> halt()
    end
  end

  defp browser_assurance(conn) do
    case {current_user(conn), conn.private[:sigra_session]} do
      {%{id: id}, %{type: type}} when not is_nil(id) and type in [:standard, :remember_me] ->
        :completed

      {%{id: id}, %{type: :mfa_pending}} when not is_nil(id) ->
        :mfa_pending

      {nil, _} ->
        :unauthenticated

      _ ->
        :invalid
    end
  end

  defp current_user(%{assigns: %{current_scope: %{user: user}}}), do: user
  defp current_user(_), do: nil

  defp callback_with_code(callback, code, state) do
    separator = if String.contains?(callback, "?"), do: "&", else: "?"
    callback <> separator <> URI.encode_query(%{"code" => code, "state" => state})
  end

  defp invalid_request(conn),
    do: conn |> put_status(:bad_request) |> text("Invalid app login request.")
end
