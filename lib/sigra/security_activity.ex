defmodule Sigra.SecurityActivity do
  @moduledoc """
  Library-owned recent security activity seam.

  The returned rows are intentionally bounded to persisted audit truth plus
  already-owned session metadata so generated and admin surfaces can render
  aligned activity without querying raw audit rows directly.
  """

  import Ecto.Query

  alias Sigra.Admin.Audit.{Presenter, Query}

  @default_limit 10
  @query_multiplier 3
  @activity_actions ~w(
    auth.logout
    auth.mfa_verified
    security.suspicious_login
    session.create
    session.delete
    session.revoke_all
    session.revoke_others
    session.sudo_enter
    session.sudo_expire
  )

  @type activity_row :: %{
          id: term(),
          action: String.t(),
          action_label: String.t(),
          occurred_at: DateTime.t() | nil,
          outcome: String.t(),
          kind: atom(),
          ip_address: String.t() | nil,
          geo_city: String.t() | nil,
          geo_country_code: String.t() | nil,
          session_id: term() | nil,
          session_type: atom() | String.t() | nil
        }

  @spec list_recent_activity(Sigra.Config.t(), binary(), keyword()) :: [activity_row()]
  def list_recent_activity(%Sigra.Config{} = config, user_id, opts \\ []) when is_binary(user_id) do
    case audit_schema(config) do
      nil ->
        []

      audit_schema ->
        limit = Keyword.get(opts, :limit, @default_limit)

        audit_schema
        |> Query.build(subject_user_id: user_id)
        |> where([event], event.action in ^@activity_actions)
        |> order_by([event], desc: event.inserted_at, desc: event.id)
        |> limit(^max(limit * @query_multiplier, limit))
        |> config.repo.all()
        |> present_recent_activity(config)
        |> Enum.take(limit)
    end
  end

  defp present_recent_activity(events, config) do
    sessions_by_id = load_sessions_by_id(config, events)

    mfa_session_ids =
      events
      |> Enum.filter(&(Map.get(&1, :action) == "auth.mfa_verified"))
      |> Enum.map(&metadata_value(Map.get(&1, :metadata) || %{}, :session_id))
      |> Enum.reject(&is_nil/1)
      |> MapSet.new()

    events
    |> Enum.reduce([], fn event, rows ->
      case present_event(event, sessions_by_id, mfa_session_ids) do
        nil -> rows
        row -> [row | rows]
      end
    end)
    |> Enum.reverse()
  end

  defp present_event(%{action: "session.create", metadata: metadata} = event, sessions_by_id, mfa_session_ids) do
    type = metadata_value(metadata || %{}, :type)
    session_id = metadata_value(metadata || %{}, :session_id)

    cond do
      type in [:mfa_pending, "mfa_pending"] -> nil
      MapSet.member?(mfa_session_ids, session_id) -> nil
      true -> build_row(event, sessions_by_id, mfa_session_ids)
    end
  end

  defp present_event(event, sessions_by_id, mfa_session_ids) do
    build_row(event, sessions_by_id, mfa_session_ids)
  end

  defp build_row(event, sessions_by_id, _mfa_session_ids) do
    metadata = Map.get(event, :metadata) || %{}
    session_id = metadata_value(metadata, :session_id)
    session = session_id && Map.get(sessions_by_id, session_id)

    %{
      id: Map.get(event, :id),
      action: Map.get(event, :action),
      action_label: Presenter.action_label(Map.get(event, :action), metadata),
      occurred_at: Map.get(event, :inserted_at),
      outcome: Map.get(event, :outcome) || "success",
      kind: activity_kind(Map.get(event, :action)),
      ip_address: Map.get(event, :ip_address) || Map.get(session || %{}, :ip),
      geo_city: geo_city(event, session),
      geo_country_code: geo_country_code(event, session),
      session_id: session_id,
      session_type: metadata_value(metadata, :type) || Map.get(session || %{}, :type)
    }
  end

  defp load_sessions_by_id(config, events) do
    session_ids =
      events
      |> Enum.map(&(Map.get(&1, :metadata) || %{}))
      |> Enum.map(&metadata_value(&1, :session_id))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    case {session_schema(config), session_ids} do
      {nil, _ids} ->
        %{}

      {_session_schema, []} ->
        %{}

      {session_schema, ids} ->
        from(session in session_schema, where: session.id in ^ids)
        |> config.repo.all()
        |> Map.new(&{Map.get(&1, :id), &1})
    end
  end

  defp geo_city(event, session) do
    metadata = Map.get(event, :metadata) || %{}
    metadata_value(metadata, :geo_city) || Map.get(session || %{}, :geo_city)
  end

  defp geo_country_code(event, session) do
    metadata = Map.get(event, :metadata) || %{}
    metadata_value(metadata, :geo_country_code) || Map.get(session || %{}, :geo_country_code)
  end

  defp activity_kind("auth.logout"), do: :logout
  defp activity_kind("auth.mfa_verified"), do: :mfa_verified
  defp activity_kind("security.suspicious_login"), do: :suspicious_login
  defp activity_kind("session.create"), do: :sign_in
  defp activity_kind("session.delete"), do: :session_revoked
  defp activity_kind("session.revoke_all"), do: :revoke_all
  defp activity_kind("session.revoke_others"), do: :revoke_others
  defp activity_kind("session.sudo_enter"), do: :sudo_enter
  defp activity_kind("session.sudo_expire"), do: :sudo_expire
  defp activity_kind(_action), do: :unknown

  defp metadata_value(metadata, key) when is_map(metadata) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp audit_schema(%Sigra.Config{audit: audit}), do: Keyword.get(audit || [], :audit_schema)

  defp session_schema(%Sigra.Config{session: session}) do
    Keyword.get(session || [], :session_schema)
  end
end
