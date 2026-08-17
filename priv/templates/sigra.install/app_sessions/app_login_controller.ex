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

        case browser_assurance(conn) do
          :completed -> render(conn, :approve, profile_name: profile_id)
          :mfa_pending -> redirect(conn, to: ~p"/users/mfa")
          :unauthenticated -> redirect(conn, to: ~p"/users/log_in")
          :invalid -> invalid_request(conn)
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

  def refresh(conn, %{"refresh_token" => token} = params) do
    with ["refresh_token"] <- Map.keys(params),
         true <- is_binary(token),
         {:ok, credentials} <- AppSessions.refresh(token) do
      json(conn, credentials)
    else
      _ -> json(conn |> put_status(:unauthorized), %{error: "invalid_refresh"})
    end
  end

  def refresh(conn, _params), do: json(conn |> put_status(:bad_request), %{error: "invalid_request"})

  def revoke_family(conn, %{"family_id" => family_id} = params) do
    with ["family_id"] <- Map.keys(params),
         true <- is_binary(family_id) do
      owner = conn.assigns.current_scope.user

      case AppSessions.revoke_family(owner, family_id) do
        {:ok, _family} -> json(conn, %{ok: true})
        {:error, :not_found} -> json(conn |> put_status(:not_found), %{error: "not_found"})
        _ -> json(conn |> put_status(:unprocessable_entity), %{error: "revocation_failed"})
      end
    else
      _ -> json(conn |> put_status(:unprocessable_entity), %{error: "revocation_failed"})
    end
  end

  def revoke_family(conn, _params),
    do: json(conn |> put_status(:unprocessable_entity), %{error: "revocation_failed"})

  def revoke_all(conn, %{} = params) do
    with [] <- Map.keys(params) do
      owner = conn.assigns.current_scope.user

      case AppSessions.revoke_all(owner) do
        {:ok, _count} -> json(conn, %{ok: true})
        _ -> json(conn |> put_status(:unprocessable_entity), %{error: "revocation_failed"})
      end
    else
      _ -> json(conn |> put_status(:unprocessable_entity), %{error: "revocation_failed"})
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

  def complete_direct_mfa(conn, %{"challenge" => challenge, "code" => code, "factor" => factor} = params) do
    with ["challenge", "code", "factor"] <- Enum.sort(Map.keys(params)),
         true <- Enum.all?([challenge, code, factor], &is_binary/1),
         {:ok, trusted_factor} <- direct_mfa_factor(factor),
         {:ok, result} <- AppSessions.complete_direct_mfa(challenge, code, trusted_factor) do
      json(conn, result)
    else
      _ -> json(conn |> put_status(:unauthorized), %{error: "invalid_credentials"})
    end
  end

  def complete_direct_mfa(conn, _params), do: json(conn |> put_status(:unauthorized), %{error: "invalid_credentials"})

  defp direct_mfa_factor("totp"), do: {:ok, :totp}
  defp direct_mfa_factor("backup_code"), do: {:ok, :backup_code}
  defp direct_mfa_factor(_), do: :error
<% end %>
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
      {%{id: id}, %{type: type}} when not is_nil(id) and type in [:standard, :remember_me] -> :completed
      {%{id: id}, %{type: :mfa_pending}} when not is_nil(id) -> :mfa_pending
      {nil, _} -> :unauthenticated
      _ -> :invalid
    end
  end

  defp current_user(%{assigns: %{current_scope: %{user: user}}}), do: user
  defp current_user(_), do: nil
  defp callback_with_code(callback, code, state) do
    separator = if String.contains?(callback, "?"), do: "&", else: "?"
    callback <> separator <> URI.encode_query(%{"code" => code, "state" => state})
  end

  defp invalid_request(conn), do: conn |> put_status(:bad_request) |> text("Invalid app login request.")
end
