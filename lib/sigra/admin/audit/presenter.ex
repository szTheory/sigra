defmodule Sigra.Admin.Audit.Presenter do
  @moduledoc """
  Canonical operator-facing audit row presentation helpers.
  """

  @spec present([struct()], map()) :: [map()]
  def present(events, users_by_id) when is_list(events) and is_map(users_by_id) do
    Enum.map(events, &present_event(&1, users_by_id))
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
      action_label: action_label(event.action),
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

  defp action_label("admin.impersonation.start"), do: "Impersonation started"
  defp action_label("admin.impersonation.stop"), do: "Impersonation ended"
  defp action_label("admin.impersonation.timeout"), do: "Impersonation timed out"
  defp action_label("admin.impersonation.denied"), do: "Impersonation denied"

  defp action_label(action) when is_binary(action) do
    action
    |> String.replace(".", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp user_label(%{display_name: name}, _fallback) when is_binary(name) and name != "", do: name
  defp user_label(%{email: email}, _fallback) when is_binary(email) and email != "", do: email
  defp user_label(%{id: id}, _fallback) when is_binary(id), do: id
  defp user_label(_user, fallback) when is_binary(fallback), do: fallback
  defp user_label(_user, _fallback), do: "Unknown user"
end
