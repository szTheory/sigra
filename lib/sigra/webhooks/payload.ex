defmodule Sigra.Webhooks.Payload do
  @moduledoc """
  Stable public webhook payload builder.
  """

  alias Sigra.Webhooks.EventCatalog

  @schema_version "2026-05-06"

  @spec build(String.t(), struct() | map(), keyword()) :: map()
  def build(event_type, object, opts \\ []) when is_binary(event_type) and is_list(opts) do
    serializer = EventCatalog.serializer_for!(event_type)
    occurred_at = Keyword.get(opts, :occurred_at, DateTime.utc_now())

    payload = %{
      "id" => Keyword.get(opts, :id, Ecto.UUID.generate()),
      "type" => event_type,
      "schema_version" => Keyword.get(opts, :schema_version, @schema_version),
      "occurred_at" => occurred_at |> normalize_datetime!() |> DateTime.to_iso8601(),
      "data" => %{"object" => serializer.serialize(object, event_type: event_type)}
    }

    payload
    |> maybe_put_changes(event_type, Keyword.get(opts, :changes, []))
    |> maybe_put_context(Keyword.get(opts, :context, %{}))
  end

  defp maybe_put_changes(payload, event_type, changes)
       when is_binary(event_type) and is_list(changes) do
    if String.ends_with?(event_type, ".updated") do
      normalized =
        changes
        |> Enum.map(&to_string/1)
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))
        |> Enum.uniq()

      if normalized == [] do
        payload
      else
        put_in(payload, ["data", "changes"], normalized)
      end
    else
      payload
    end
  end

  defp maybe_put_changes(payload, _event_type, _changes), do: payload

  defp maybe_put_context(payload, context) when is_map(context) do
    normalized =
      %{}
      |> maybe_put_actor(Map.get(context, :actor) || Map.get(context, "actor"))
      |> maybe_put_organization(Map.get(context, :organization) || Map.get(context, "organization"))
      |> maybe_put_request(Map.get(context, :request) || Map.get(context, "request"))

    if normalized == %{} do
      payload
    else
      Map.put(payload, "context", normalized)
    end
  end

  defp maybe_put_context(payload, _context), do: payload

  defp maybe_put_actor(context, nil), do: context

  defp maybe_put_actor(context, actor) do
    actor_map = %{
      "type" => Map.get(actor, :type) || Map.get(actor, "type"),
      "id" => Map.get(actor, :id) || Map.get(actor, "id")
    }

    if Enum.all?(actor_map, fn {_key, value} -> is_binary(value) and value != "" end) do
      Map.put(context, "actor", actor_map)
    else
      context
    end
  end

  defp maybe_put_organization(context, nil), do: context

  defp maybe_put_organization(context, organization) do
    organization_id = Map.get(organization, :id) || Map.get(organization, "id") || organization

    if is_binary(organization_id) and organization_id != "" do
      Map.put(context, "organization", %{"id" => organization_id})
    else
      context
    end
  end

  defp maybe_put_request(context, nil), do: context

  defp maybe_put_request(context, request) do
    request_id = Map.get(request, :id) || Map.get(request, "id")

    if is_binary(request_id) and request_id != "" do
      Map.put(context, "request", %{"id" => request_id})
    else
      context
    end
  end

  defp normalize_datetime!(%DateTime{} = datetime), do: DateTime.truncate(datetime, :second)

  defp normalize_datetime!(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> DateTime.from_naive!("Etc/UTC")
  end
end
