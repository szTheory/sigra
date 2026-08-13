defmodule <%= web_module %>.AppLoginController do
  use <%= web_module %>, :controller

  alias <%= context_module %>.Auth.AppSessions
  alias <%= web_module %>.AppLoginContinuation

  plug :require_authenticated_browser when action in [:continue, :approve, :cancel]

  def start(conn, params) do
    case AppSessions.start_hosted(params) do
      {:ok, %{continuation: continuation}} ->
        profile_id = params["profile_id"]
        conn = AppLoginContinuation.put(conn, continuation, profile_id)

        if current_user(conn) do
          render(conn, :approve, profile_name: profile_id)
        else
          redirect(conn, to: ~p"/users/log_in")
        end

      _ -> invalid_request(conn)
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
      redirect(conn, external: callback_with_code(callback, code, state))
      |> put_resp_header("referrer-policy", "no-referrer")
    else
      _ -> invalid_request(conn)
    end
  end

  def cancel(conn, %{} = params) do
    with [] <- Map.keys(params) -- ["_csrf_token"],
         {:ok, continuation, _profile_id} <- AppLoginContinuation.fetch(conn),
         {:ok, :cancelled} <- AppSessions.approve_hosted(continuation, current_user(conn), :cancel) do
      {conn, _} = AppLoginContinuation.take(conn)
      redirect(conn, to: ~p"/users/log_in") |> put_resp_header("referrer-policy", "no-referrer")
    else
      _ -> invalid_request(conn)
    end
  end

  def exchange(conn, params) do
    with %{"code" => code, "code_verifier" => verifier, "profile_id" => profile, "callback" => callback} <- params,
         ["callback", "code", "code_verifier", "profile_id"] <- Enum.sort(Map.keys(params)),
         true <- Enum.all?([code, verifier, profile, callback], &is_binary/1),
         {:ok, credentials} <- AppSessions.exchange_hosted(code, verifier, profile, callback) do
      json(conn, credentials)
    else
      _ -> json(conn |> put_status(:bad_request), %{error: "invalid_request"})
    end
  end

<%= if Keyword.get(Keyword.get(binding(), :opts, []), :app_password_login, false) do %>  def direct(conn, %{"profile_id" => profile, "email" => email, "password" => password} = params) do
    with ["email", "password", "profile_id"] <- Enum.sort(Map.keys(params)),
         {:ok, result} <- AppSessions.start_direct(profile, email, password) do
      json(conn, result)
    else
      {:error, :browser_required} -> json(conn |> put_status(:forbidden), %{error: "browser_required"})
      _ -> json(conn |> put_status(:unauthorized), %{error: "invalid_credentials"})
    end
  end

  def direct(conn, _params), do: json(conn |> put_status(:unauthorized), %{error: "invalid_credentials"})

  def complete_direct_mfa(conn, %{"challenge" => challenge, "code" => code} = params) do
    with ["challenge", "code"] <- Enum.sort(Map.keys(params)),
         {:ok, result} <- AppSessions.complete_direct_mfa(challenge, code) do
      json(conn, result)
    else
      _ -> json(conn |> put_status(:unauthorized), %{error: "invalid_credentials"})
    end
  end

  def complete_direct_mfa(conn, _params), do: json(conn |> put_status(:unauthorized), %{error: "invalid_credentials"})
<% end %>
  defp require_authenticated_browser(conn, _opts) do
    if current_user(conn), do: conn, else: conn |> redirect(to: ~p"/users/log_in") |> halt()
  end

  defp current_user(conn), do: get_in(conn.assigns, [:current_scope, :user])
  defp callback_with_code(callback, code, state) do
    separator = if String.contains?(callback, "?"), do: "&", else: "?"
    callback <> separator <> URI.encode_query(%{"code" => code, "state" => state})
  end

  defp invalid_request(conn), do: conn |> put_status(:bad_request) |> text("Invalid app login request.")
end
