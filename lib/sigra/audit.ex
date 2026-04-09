defmodule Sigra.Audit do
  @moduledoc """
  Structured audit logging for Sigra.

  See `.planning/phases/09-audit-logging/09-CONTEXT.md` for the 28 decisions
  that shape this module. Summary:

  - Direct `Ecto.Multi` writes (D-01) — **not** telemetry subscribers (D-02)
  - Public API enforces reserved prefixes (D-17..D-18); internal
    `__log_internal__/3` bypasses this check for library-owned events
  - Metadata size cap 8KB default (D-20); forbidden keys rejected (D-23)
  - Cursor pagination, no offset, or-expanded tiebreak (D-13)
  - Telemetry passthrough `[:sigra, :audit, :log]` on successful commit (D-24)

  ## Telemetry responsibility for `log_multi/3`

  Standalone `log/3` fires telemetry automatically from its `{:ok, _}` branch.

  Callers of `log_multi/3` own their own `repo.transaction/1` call and are
  responsible for invoking `Sigra.Audit.emit_telemetry_from_changes/1` inside
  their `{:ok, changes}` branch. This guarantees telemetry NEVER fires when
  the enclosing transaction rolls back. See Plan 03 integration sites for
  examples.
  """

  alias Sigra.Audit.{Changeset, Cursor, Query}

  @type opts :: keyword()

  @telemetry_event [:sigra, :audit, :log]

  @default_reserved ~w(auth. session. mfa. oauth. api. account. sigra.)
  @default_limit 50
  @max_limit 500

  # -- Public API --

  @doc """
  Writes a single audit event in its own transaction/insert.

  Returns `{:ok, event}` on success, `{:error, changeset}` on validation
  failure. Fires `[:sigra, :audit, :log]` telemetry exactly once on success,
  never on failure.
  """
  @spec log(String.t(), opts()) :: {:ok, struct()} | {:error, Ecto.Changeset.t()}
  def log(action, opts) when is_binary(action) and is_list(opts) do
    repo = Keyword.fetch!(opts, :repo)
    audit_schema = Keyword.fetch!(opts, :audit_schema)

    cs_opts = changeset_opts(opts, false)
    attrs = build_attrs(action, opts, nil, %{})
    changeset = Changeset.changeset(struct(audit_schema), attrs, cs_opts)

    case repo.insert(changeset) do
      {:ok, event} ->
        emit_telemetry(event)
        {:ok, event}

      {:error, %Ecto.Changeset{} = cs} ->
        {:error, cs}
    end
  end

  @doc """
  Appends an `:audit` step to an existing `Ecto.Multi`.

  Raises `ArgumentError` at composition time if `action` uses a reserved
  Sigra prefix — developers must not log library-owned events. Internal
  callers must use `__log_internal__/3` instead.

  Callers own the enclosing `repo.transaction/1` call. To emit telemetry on
  successful commit, invoke `emit_telemetry_from_changes/1` in the
  `{:ok, changes}` branch after the transaction returns. Telemetry MUST NOT
  fire when the enclosing transaction rolls back.
  """
  @spec log_multi(Ecto.Multi.t(), String.t(), opts()) :: Ecto.Multi.t()
  def log_multi(%Ecto.Multi{} = multi, action, opts)
      when is_binary(action) and is_list(opts) do
    reserved = Keyword.get(opts, :reserved_prefixes, @default_reserved)

    if reserved_prefix?(action, reserved) do
      raise ArgumentError,
            "Sigra.Audit.log_multi/3 rejected action #{inspect(action)}: " <>
              "uses a reserved Sigra prefix. Developer-owned action names must not start with " <>
              "any of #{inspect(reserved)}. For library-internal callers, use __log_internal__/3."
    end

    do_log_multi(multi, action, opts, false)
  end

  @doc false
  @spec __log_internal__(Ecto.Multi.t(), String.t(), opts()) :: Ecto.Multi.t()
  def __log_internal__(%Ecto.Multi{} = multi, action, opts)
      when is_binary(action) and is_list(opts) do
    do_log_multi(multi, action, opts, true)
  end

  @doc """
  Safe standalone log for library-internal integration sites.

  No-ops (returns `:ok`) when `:audit_schema` is nil or absent. This lets
  integration call sites (Plan 03) add audit writes without breaking host
  apps that have not configured an audit schema. Always bypasses the
  reserved-prefix check (library-owned events).

  Returns `:ok` in all cases (successful insert, disabled, or insert error)
  because integration call sites must not change their return shape on
  audit failure. Errors are logged via telemetry metadata on the separate
  `[:sigra, :audit, :log_safe_error]` event for observability.
  """
  @spec log_safe(String.t(), opts()) :: :ok
  def log_safe(action, opts) when is_binary(action) and is_list(opts) do
    case Keyword.get(opts, :audit_schema) do
      nil ->
        :ok

      _schema ->
        opts = Keyword.put(opts, :allow_reserved, true)
        cs_opts = changeset_opts(opts, true)
        audit_schema = Keyword.fetch!(opts, :audit_schema)
        attrs = build_attrs(action, opts, nil, %{})
        changeset = Changeset.changeset(struct(audit_schema), attrs, cs_opts)

        case Keyword.get(opts, :repo) do
          nil ->
            :telemetry.execute(
              [:sigra, :audit, :log_safe_error],
              %{count: 1},
              %{action: action, reason: :missing_repo}
            )

            :ok

          repo ->
            if changeset.valid? do
              case repo.insert(changeset) do
                {:ok, event} ->
                  emit_telemetry(event)
                  :ok

                {:error, %Ecto.Changeset{} = cs} ->
                  emit_log_safe_error(action, cs)
                  :ok
              end
            else
              emit_log_safe_error(action, changeset)
              :ok
            end
        end
    end
  end

  # Emits log_safe_error telemetry with sanitized error metadata.
  # CRITICAL: only key names (not values) are included, because changeset
  # error context may echo the offending metadata value — and D-23 forbidden
  # values must never leave the insert attempt.
  defp emit_log_safe_error(action, %Ecto.Changeset{} = cs) do
    error_fields = cs.errors |> Enum.map(fn {field, _} -> field end) |> Enum.uniq()

    :telemetry.execute(
      [:sigra, :audit, :log_safe_error],
      %{count: 1},
      %{action: action, reason: :invalid_changeset, error_fields: error_fields}
    )
  end

  @doc """
  Safe Multi-append for library-internal integration sites.

  Returns the multi unchanged when `:audit_schema` is nil or absent.
  Otherwise appends an `:audit` step via `__log_internal__/3`.
  """
  @spec log_multi_safe(Ecto.Multi.t(), String.t(), opts()) :: Ecto.Multi.t()
  def log_multi_safe(%Ecto.Multi{} = multi, action, opts)
      when is_binary(action) and is_list(opts) do
    case Keyword.get(opts, :audit_schema) do
      nil -> multi
      _ -> do_log_multi(multi, action, opts, true)
    end
  end

  defp do_log_multi(multi, action, opts, allow_reserved?) do
    audit_schema = Keyword.fetch!(opts, :audit_schema)
    resolver = Keyword.get(opts, :actor_resolver)
    cs_opts = changeset_opts(opts, allow_reserved?)

    Ecto.Multi.insert(multi, :audit, fn changes ->
      attrs = build_attrs(action, opts, resolver, changes)
      Changeset.changeset(struct(audit_schema), attrs, cs_opts)
    end)
  end

  @doc """
  Emits `[:sigra, :audit, :log]` telemetry for the `:audit` step of an
  `Ecto.Multi` changes map.

  Callers of `log_multi/3` must invoke this from the `{:ok, changes}` branch
  of their own `repo.transaction/1` call, so telemetry is guaranteed to fire
  only after a successful commit.
  """
  @spec emit_telemetry_from_changes(map()) :: :ok
  def emit_telemetry_from_changes(%{audit: %_{} = event}) do
    emit_telemetry(event)
    :ok
  end

  def emit_telemetry_from_changes(_), do: :ok

  defp emit_telemetry(event) do
    :telemetry.execute(
      @telemetry_event,
      %{count: 1},
      %{action: event.action, actor_id: event.actor_id, outcome: event.outcome}
    )
  end

  # -- Query API --

  @doc """
  Returns a composable `Ecto.Query` filtered by the given keyword filters.

  Required key: `:audit_schema`. Supported filters are listed in
  `Sigra.Audit.Query`.
  """
  @spec query(keyword()) :: Ecto.Query.t()
  def query(filters) when is_list(filters) do
    audit_schema = Keyword.fetch!(filters, :audit_schema)
    Query.build(audit_schema, Keyword.delete(filters, :audit_schema))
  end

  @doc """
  Returns a cursor-paginated result map.

  Options:
    * `:repo` (required)
    * `:limit` — default 50, capped at 500
    * `:cursor` — opaque Base64URL cursor from a previous result
  """
  @spec list(keyword(), keyword()) :: %{entries: [struct()], next_cursor: String.t() | nil}
  def list(filters, opts) when is_list(filters) and is_list(opts) do
    repo = Keyword.fetch!(opts, :repo)
    limit = opts |> Keyword.get(:limit, @default_limit) |> min(@max_limit)

    cursor_decoded =
      case Keyword.get(opts, :cursor) do
        nil ->
          nil

        c ->
          case Cursor.decode(c) do
            {:ok, tup} -> tup
            _ -> nil
          end
      end

    rows =
      filters
      |> query()
      |> Query.paginate(cursor_decoded, limit)
      |> repo.all()

    {entries, next_cursor} =
      if length(rows) > limit do
        kept = Enum.take(rows, limit)
        last = List.last(kept)
        {kept, Cursor.encode(last.inserted_at, last.id)}
      else
        {rows, nil}
      end

    %{entries: entries, next_cursor: next_cursor}
  end

  @doc """
  Returns an `Enumerable.t()` suitable for use inside the caller's
  `repo.transaction/1` block.

  The repo must implement `stream/1`. Raises `ArgumentError` otherwise so
  that large audit tables can never be loaded entirely into memory via a
  silent `repo.all/1` fallback. Callers without a streaming repo should use
  `list/2` (cursor-paginated) instead.
  """
  @spec stream(keyword(), keyword()) :: Enumerable.t()
  def stream(filters, opts) when is_list(filters) and is_list(opts) do
    repo = Keyword.fetch!(opts, :repo)
    q = query(filters)

    if function_exported?(repo, :stream, 1) do
      repo.stream(q)
    else
      raise ArgumentError,
            "Sigra.Audit.stream/2 requires #{inspect(repo)} to implement stream/1. " <>
              "Use Sigra.Audit.list/2 for cursor pagination on repos without streaming support."
    end
  end

  @doc """
  Returns the number of rows matching the given filters.
  """
  @spec count(keyword(), keyword()) :: non_neg_integer()
  def count(filters, opts) when is_list(filters) and is_list(opts) do
    repo = Keyword.fetch!(opts, :repo)
    filters |> query() |> repo.aggregate(:count, :id)
  end

  # -- Retention cleanup (D-10) --

  @doc """
  Deletes audit events older than the configured retention window.
  """
  @spec cleanup(keyword()) :: :ok
  def cleanup(opts) when is_list(opts) do
    repo = Keyword.fetch!(opts, :repo)
    audit_schema = Keyword.fetch!(opts, :audit_schema)
    retention_days = Keyword.get(opts, :retention_days)
    do_cleanup(repo, audit_schema, retention_days)
  end

  @doc false
  def do_cleanup(_repo, _schema, nil), do: :ok

  def do_cleanup(repo, audit_schema, days) when is_integer(days) and days > 0 do
    import Ecto.Query

    cutoff = DateTime.add(DateTime.utc_now(), -days * 86_400, :second)

    from(e in audit_schema, where: e.inserted_at < ^cutoff)
    |> repo.delete_all()

    :ok
  end

  # -- Helpers --

  defp changeset_opts(opts, allow_reserved?) do
    runtime = configured_audit_opts()

    base_opts =
      runtime
      |> Keyword.merge(Keyword.take(opts, [:max_metadata_bytes, :reserved_prefixes]))

    Keyword.put(base_opts, :allow_reserved, allow_reserved?)
  end

  defp configured_audit_opts do
    case Application.get_env(:sigra, :audit, []) do
      opts when is_list(opts) -> Keyword.take(opts, [:max_metadata_bytes, :reserved_prefixes])
      _ -> []
    end
  end

  defp reserved_prefix?(action, reserved) do
    Enum.any?(reserved, &String.starts_with?(action, &1))
  end

  defp build_attrs(action, opts, resolver, changes) do
    actor_id =
      if is_function(resolver, 1) do
        resolver.(changes)
      else
        Keyword.get(opts, :actor_id)
      end

    %{
      action: action,
      outcome: Keyword.get(opts, :outcome, "success"),
      actor_id: actor_id,
      actor_type: Keyword.get(opts, :actor_type, "user"),
      target_id: Keyword.get(opts, :target_id),
      target_type: Keyword.get(opts, :target_type),
      ip_address: Keyword.get(opts, :ip_address),
      user_agent: Keyword.get(opts, :user_agent),
      metadata: Keyword.get(opts, :metadata, %{}),
      occurred_at: Keyword.get(opts, :occurred_at, DateTime.utc_now())
    }
  end
end
