defmodule Sigra.Admin.Audit.CSVExport do
  @moduledoc """
  Stable CSV encoding for admin audit evidence exports.
  """

  @header [
    "occurred_at",
    "event_id",
    "action",
    "outcome",
    "actor_id",
    "actor_label",
    "effective_user_id",
    "effective_user_label",
    "target_id",
    "target_type",
    "organization_id",
    "organization_label",
    "impersonation_state"
  ]

  @dangerous_prefixes ["=", "+", "-", "@", "\t", "\r"]

  @spec header() :: [String.t()]
  def header, do: @header

  @spec dump([map()]) :: String.t()
  def dump(rows) when is_list(rows) do
    ([encode_row(@header)] ++ Enum.map(rows, &encode_row(row_values(&1))))
    |> Enum.join("\r\n")
    |> Kernel.<>("\r\n")
  end

  @spec row(struct(), map(), map(), keyword()) :: map()
  def row(event, users_by_id, orgs_by_id, opts \\ []) do
    actor = Map.get(users_by_id, event.actor_id)
    effective_user = Map.get(users_by_id, event.effective_user_id)
    scope_org = Keyword.get(opts, :scope_organization)

    organization =
      if is_binary(event.organization_id) do
        Map.get(orgs_by_id, event.organization_id)
      else
        if is_map(scope_org), do: scope_org, else: nil
      end

    organization_id_cell =
      if is_binary(event.organization_id) do
        event.organization_id
      else
        case organization do
          %{id: id} when is_binary(id) -> id
          _ -> ""
        end
      end

    %{
      "occurred_at" => iso8601(event.occurred_at || event.inserted_at),
      "event_id" => event.id,
      "action" => event.action,
      "outcome" => event.outcome || "success",
      "actor_id" => event.actor_id,
      "actor_label" => user_label(actor, event.actor_id),
      "effective_user_id" => event.effective_user_id,
      "effective_user_label" => user_label(effective_user, event.effective_user_id),
      "target_id" => event.target_id,
      "target_type" => event.target_type,
      "organization_id" => organization_id_cell,
      "organization_label" => organization_label(organization, event.organization_id),
      "impersonation_state" => impersonation_state(event)
    }
  end

  defp row_values(row) do
    Enum.map(@header, &Map.get(row, &1, ""))
  end

  defp encode_row(values) do
    values
    |> Enum.map(&encode_cell/1)
    |> Enum.join(",")
  end

  defp encode_cell(value) do
    value =
      value
      |> normalize_value()
      |> protect_spreadsheet_formula()

    escaped = String.replace(value, "\"", "\"\"")

    if String.contains?(escaped, [",", "\"", "\n", "\r"]) do
      ~s("#{escaped}")
    else
      escaped
    end
  end

  defp normalize_value(nil), do: ""
  defp normalize_value(value) when is_binary(value), do: value
  defp normalize_value(value), do: to_string(value)

  defp protect_spreadsheet_formula(""), do: ""

  defp protect_spreadsheet_formula(value) do
    if Enum.any?(@dangerous_prefixes, &String.starts_with?(value, &1)) do
      "'" <> value
    else
      value
    end
  end

  defp iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp iso8601(_value), do: ""

  defp user_label(%{display_name: name}, _fallback) when is_binary(name) and name != "", do: name
  defp user_label(%{email: email}, _fallback) when is_binary(email) and email != "", do: email
  defp user_label(%{id: id}, _fallback) when is_binary(id), do: id
  defp user_label(_user, fallback) when is_binary(fallback), do: fallback
  defp user_label(_user, _fallback), do: ""

  defp organization_label(%{name: name}, _fallback) when is_binary(name) and name != "", do: name
  defp organization_label(%{slug: slug}, _fallback) when is_binary(slug) and slug != "", do: slug
  defp organization_label(%{id: id}, _fallback) when is_binary(id), do: id
  defp organization_label(_organization, fallback) when is_binary(fallback), do: fallback
  defp organization_label(_organization, _fallback), do: ""

  defp impersonation_state(event) do
    if String.starts_with?(event.action, "admin.impersonation.") or
         (is_binary(event.actor_id) and is_binary(event.effective_user_id) and
            event.actor_id != event.effective_user_id) do
      "impersonating"
    else
      "direct"
    end
  end
end
