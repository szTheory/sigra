defmodule Sigra.Admin.Audit.Presenter do
  @moduledoc """
  Canonical operator-facing audit row presentation helpers.
  """

  @spec present([struct()], map()) :: [map()]
  def present(events, users_by_id) when is_list(events) and is_map(users_by_id) do
    Enum.map(events, &present_event(&1, users_by_id))
  end

  @spec action_label(String.t(), map()) :: String.t()
  def action_label(action, metadata \\ %{})

  def action_label("admin.impersonation.start", _metadata), do: "Impersonation started"
  def action_label("admin.impersonation.stop", _metadata), do: "Impersonation ended"
  def action_label("admin.impersonation.timeout", _metadata), do: "Impersonation timed out"
  def action_label("admin.impersonation.denied", _metadata), do: "Impersonation denied"
  def action_label("auth.logout", _metadata), do: "Signed out"
  def action_label("auth.mfa_verified", _metadata), do: "Completed multi-factor verification"
  def action_label("security.suspicious_login", _metadata), do: "Suspicious sign-in attempt"
  def action_label("session.create", metadata), do: session_create_label(metadata)
  def action_label("session.delete", _metadata), do: "Session revoked"
  def action_label("session.revoke_all", _metadata), do: "Signed out of all devices"
  def action_label("session.revoke_others", _metadata), do: "Signed out of other devices"
  def action_label("session.sudo_enter", _metadata), do: "Entered sudo mode"
  def action_label("session.sudo_expire", _metadata), do: "Sudo access expired"

  def action_label(action, _metadata) when is_binary(action) do
    action
    |> String.replace(".", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp present_event(event, users_by_id) do
    actor = Map.get(users_by_id, event.actor_id)
    effective_user = Map.get(users_by_id, event.effective_user_id)

    impersonation? =
      String.starts_with?(event.action, "admin.impersonation.") or
        (is_binary(event.actor_id) and is_binary(event.effective_user_id) and
           event.actor_id != event.effective_user_id)

    %{
      id: event.id,
      inserted_at: event.inserted_at,
      action: event.action,
      action_label: action_label(event.action, event.metadata || %{}),
      action_badge: if(impersonation?, do: "Impersonation", else: nil),
      actor_label: user_label(actor, event.actor_id),
      effective_user_label: user_label(effective_user, event.effective_user_id),
      actor_summary:
        if(impersonation?,
          do:
            "#{user_label(actor, event.actor_id)} acting as #{user_label(effective_user, event.effective_user_id)}",
          else: user_label(actor, event.actor_id)
        ),
      outcome: event.outcome || "success"
    }
  end

  defp session_create_label(metadata) do
    case metadata_value(metadata, :type) do
      type when type in [:remember_me, "remember_me"] -> "Remembered sign-in"
      type when type in [:mfa_pending, "mfa_pending"] -> "Sign-in started"
      _other -> "Signed in"
    end
  end

  defp metadata_value(metadata, key) when is_map(metadata) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp user_label(%{display_name: name}, _fallback) when is_binary(name) and name != "", do: name
  defp user_label(%{email: email}, _fallback) when is_binary(email) and email != "", do: email
  defp user_label(%{id: id}, _fallback) when is_binary(id), do: id
  defp user_label(_user, fallback) when is_binary(fallback), do: fallback
  defp user_label(_user, _fallback), do: "Unknown user"
end
