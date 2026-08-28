defmodule ExampleWeb.NativeProofController do
  use ExampleWeb, :controller

  alias Example.Accounts.Auth.AppSessions
  alias Example.Accounts.CrosswakeNativeBridge

  def return(conn, params) do
    with {:ok, access_token} <- bearer(conn),
         {:allow, result} <-
           CrosswakeNativeBridge.evaluate_app_session_return(
             access_token,
             DateTime.utc_now(),
             atomize_posture(params)
           ) do
      json(conn, %{status: "allow", session_version: result.session_version})
    else
      _ -> conn |> put_status(:forbidden) |> json(%{status: "deny"})
    end
  end

  def bootstrap(conn, params), do: ExampleWeb.LearningTwinController.bootstrap(conn, params)
  def media(conn, params), do: ExampleWeb.LearningTwinController.media(conn, params)
  def replay(conn, params), do: ExampleWeb.LearningTwinController.replay(conn, params)

  def logout(conn, %{} = params) do
    auth = conn.private[:sigra_auth]
    user = conn.assigns.current_scope.user

    with [] <- Map.keys(params),
         %{credential_kind: :app_session, family_id: family_id} <- auth,
         {:ok, _family} <- AppSessions.revoke_family(user, family_id) do
      json(conn, %{ok: true})
    else
      _ -> conn |> put_status(:unprocessable_entity) |> json(%{error: "logout_failed"})
    end
  end

  defp bearer(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when byte_size(token) > 0 -> {:ok, token}
      _ -> :error
    end
  end

  defp atomize_posture(params) do
    for key <- ~w(platform transport link_verification callback_binding replay native_assertion_ref),
        into: %{} do
      atom_key = String.to_existing_atom(key)
      value = Map.get(params, key)
      {atom_key, posture_value(atom_key, value)}
    end
  end

  defp posture_value(:native_assertion_ref, value), do: value
  defp posture_value(_, value) when is_binary(value), do: String.to_existing_atom(value)
  defp posture_value(_, value), do: value
end
