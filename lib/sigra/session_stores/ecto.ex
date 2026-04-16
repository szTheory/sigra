defmodule Sigra.SessionStores.Ecto do
  @moduledoc """
  Ecto-backed session store implementation.

  Stores sessions in the host app's `user_sessions` table using the
  generated `UserSession` schema. All token lookups use the SHA-256
  hashed token — the raw token is never persisted.

  ## Required Options

  - `:repo` - The Ecto Repo module
  - `:session_schema` - The generated UserSession schema module

  These are typically passed through from `Sigra.Config`.
  """

  @behaviour Sigra.SessionStore

  import Ecto.Query

  @impl true
  def create(user_id, metadata, opts) do
    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :session_schema)
    {raw_token, hashed_token} = Sigra.Token.generate_hashed_token()

    now = DateTime.utc_now()

    attrs = %{
      user_id: user_id,
      hashed_token: hashed_token,
      type: to_string(Map.get(metadata, :type, :standard)),
      ip: Map.get(metadata, :ip),
      user_agent: Map.get(metadata, :user_agent),
      geo_city: Map.get(metadata, :geo_city),
      geo_country_code: Map.get(metadata, :geo_country_code),
      active_organization_id: Map.get(metadata, :active_organization_id),
      last_active_at: now,
      inserted_at: now
    }

    case repo.insert(struct(schema, attrs)) do
      {:ok, record} ->
        session = to_session(record)
        {:ok, %{session | token: raw_token}}

      {:error, _} = error ->
        error
    end
  end

  @impl true
  def fetch(hashed_token, opts) do
    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :session_schema)

    case repo.get_by(schema, hashed_token: hashed_token) do
      nil -> {:error, :not_found}
      record -> {:ok, to_session(record)}
    end
  end

  @impl true
  def delete(hashed_token, opts) do
    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :session_schema)

    case repo.get_by(schema, hashed_token: hashed_token) do
      nil -> :ok
      record -> repo.delete!(record) && :ok
    end
  end

  @impl true
  def list_by_user(user_id, opts) do
    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :session_schema)

    query =
      from(s in schema,
        where: s.user_id == ^user_id,
        order_by: [desc: s.inserted_at]
      )

    repo.all(query)
    |> Enum.map(fn record ->
      session = to_session(record)
      parsed_ua = Sigra.UAParser.parse(record.user_agent)
      %{session | parsed_ua: parsed_ua}
    end)
  end

  @impl true
  def delete_all_for_user(user_id, opts) do
    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :session_schema)
    except_token = Keyword.get(opts, :except_token)

    query = from(s in schema, where: s.user_id == ^user_id)

    query =
      if except_token do
        from(s in query, where: s.hashed_token != ^except_token)
      else
        query
      end

    repo.delete_all(query)
  end

  @impl true
  def update_activity(hashed_token, metadata, opts) do
    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :session_schema)

    now = DateTime.utc_now()

    updates = [last_active_at: now]
    updates = if ip = Map.get(metadata, :ip), do: Keyword.put(updates, :ip, ip), else: updates

    updates =
      if ua = Map.get(metadata, :user_agent),
        do: Keyword.put(updates, :user_agent, ua),
        else: updates

    query = from(s in schema, where: s.hashed_token == ^hashed_token)

    case repo.update_all(query, set: updates) do
      {0, _} -> {:error, :not_found}
      {_count, _} -> :ok
    end
  end

  @impl true
  def update_sudo(hashed_token, sudo_at, opts) do
    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :session_schema)

    query = from(s in schema, where: s.hashed_token == ^hashed_token)

    case repo.update_all(query, set: [sudo_at: sudo_at]) do
      {0, _} -> {:error, :not_found}
      {_count, _} -> :ok
    end
  end

  @impl true
  def update_active_organization(%Sigra.Session{active_organization_id: current} = session, org_id, _opts)
      when current == org_id do
    # No-op-safe short-circuit (Phase 14 D-20): when the requested org_id
    # matches the current value, skip the DB write entirely and return the
    # session unchanged. Avoids an UPDATE on every authed request.
    {:ok, session}
  end

  def update_active_organization(%Sigra.Session{hashed_token: hashed_token} = session, org_id, opts) do
    repo = Keyword.fetch!(opts, :repo)
    schema = Keyword.fetch!(opts, :session_schema)

    query = from(s in schema, where: s.hashed_token == ^hashed_token)

    case repo.update_all(query, set: [active_organization_id: org_id]) do
      {0, _} ->
        {:error, :not_found}

      {_count, _} ->
        {:ok, %{session | active_organization_id: org_id}}
    end
  end

  defp to_session(record) do
    type =
      case record.type do
        "standard" -> :standard
        "remember_me" -> :remember_me
        "mfa_pending" -> :mfa_pending
        type when is_atom(type) -> type
        _ -> :standard
      end

    %Sigra.Session{
      id: record.id,
      user_id: record.user_id,
      hashed_token: record.hashed_token,
      type: type,
      ip: Map.get(record, :ip),
      user_agent: Map.get(record, :user_agent),
      geo_city: Map.get(record, :geo_city),
      geo_country_code: Map.get(record, :geo_country_code),
      last_active_at: Map.get(record, :last_active_at),
      sudo_at: Map.get(record, :sudo_at),
      active_organization_id: Map.get(record, :active_organization_id),
      inserted_at: Map.get(record, :inserted_at)
    }
  end
end
