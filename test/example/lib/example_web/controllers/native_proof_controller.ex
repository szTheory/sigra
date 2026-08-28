defmodule ExampleWeb.NativeProofController do
  use ExampleWeb, :controller

  alias Example.Accounts.Auth.AppSessions
  alias Example.Accounts.CrosswakeNativeBridge

  def return(conn, params) do
    with {:ok, access_token} <- bearer(conn),
         {:ok, posture} <- atomize_posture(params),
         {:allow, result} <-
           CrosswakeNativeBridge.evaluate_app_session_return(
             access_token,
             DateTime.utc_now(),
             posture
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

  @posture_keys ~w(platform transport link_verification callback_binding replay native_assertion_ref)

  defp atomize_posture(params) when is_map(params) do
    with true <- Enum.sort(Map.keys(params)) == Enum.sort(@posture_keys),
         {:ok, platform} <- member(params["platform"], %{"ios" => :ios, "android" => :android}),
         {:ok, transport} <- member(params["transport"], %{
           "verified_https_link" => :verified_https_link,
           "custom_scheme" => :custom_scheme
         }),
         {:ok, link_verification} <- member(params["link_verification"], %{
           "verified" => :verified,
           "not_applicable" => :not_applicable
         }),
         {:ok, callback_binding} <- member(params["callback_binding"], %{"matched" => :matched}),
         {:ok, replay} <- member(params["replay"], %{"not_seen" => :not_seen}),
         assertion_ref when is_binary(assertion_ref) and byte_size(assertion_ref) in 1..128 <-
           params["native_assertion_ref"] do
      {:ok,
       %{
         platform: platform,
         transport: transport,
         link_verification: link_verification,
         callback_binding: callback_binding,
         replay: replay,
         native_assertion_ref: assertion_ref
       }}
    else
      _ -> {:error, :invalid_posture}
    end
  end

  defp atomize_posture(_), do: {:error, :invalid_posture}
  defp member(value, allowlist), do: Map.fetch(allowlist, value)
end
