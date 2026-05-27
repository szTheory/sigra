if Code.ensure_loaded?(Threadline) do
  defmodule Sigra.Audit.Forwarders.Threadline do
    @moduledoc """
    Audit forwarder that ships committed Sigra audit rows to Threadline
    via `Threadline.record_action/2`.

    Subscribes (in `attach/1`) to the `[:sigra, :audit, :log]` telemetry
    event that fires only after a successful `Repo.transaction/1` commit.
    Sigra's `audit_events` table remains the authoritative source of truth —
    Threadline is a post-commit projection, not a destination swap (Phase 131
    boundary doctrine — D-21).

    ## Dep-Off Safety (D-18, TL-04)

    The entire `defmodule` is wrapped in `if Code.ensure_loaded?(Threadline) do`.
    When `:threadline` is absent from `mix.lock`, this file compiles to a no-op
    and the module simply does not exist. `Sigra.Application.attach_forwarders/0`
    falls through to Noop (D-23 split) and emits one `Logger.warning`.

    ## Idempotency (RESEARCH.md §4 path 1, §7.2)

    Each audit row's UUID is sent to Threadline as `:correlation_id`. Sigra UUIDs
    are v4 random — collision probability is negligible — so the UUID alone
    serves as the dedupe key. Recipe `guides/recipes/companion-libs/threadline.md`
    documents the optional unique index on Threadline's `audit_actions` table
    for strict Oban-retry idempotency.

    ## Dispatch (D-10, D-11)

    `handle_event/4` reads the `:dispatch` option and routes accordingly:

    - `:sync` (or `:auto` when Oban is not running) — calls
      `Threadline.record_action/2` inline in the calling process.
    - `:async` (or `:auto` when Oban is running) — enqueues a
      `Sigra.Workers.AuditForward` Oban job via the shared dispatcher.
      The worker reloads the audit row by UUID and calls `handle_event/4`
      with `:dispatch: :sync` (forcing inline execution from the worker process).

    The shared dispatcher (`Sigra.Audit.Forwarders.dispatch/3`) is used for
    the `:async` path only — calling it for `:sync` would recurse because the
    dispatcher's sync path calls `handle_event/4`. The inline Threadline call
    is the correct sync implementation.

    ## Attach Options (D-32)

    Beyond the canonical keys (`:id`, `:dispatch`, `:audit_schema`, `:repo`,
    `:oban`), this impl accepts:

    - `:actor_type` — atom identifying the default actor type passed to
      `Threadline.Semantics.ActorRef.new/2` when `actor_id` is present in
      metadata. Defaults to `:user`.
    - `:threadline_module` — module override for tests; defaults to `Threadline`.

    ## Auto-Detach Landmine (D-20 — CRITICAL)

    `handle_event/4` wraps its entire body in `try / rescue / catch :exit / catch :throw`.
    Every code path returns `:ok` to `:telemetry` — never `:stop`, never raises.
    A handler that raises is auto-detached by `:telemetry` for the rest of BEAM
    uptime (permanent silence). This is the worst failure mode in Phase 131.

    ## Failure Events (D-29)

    On any caught failure, emits `[:sigra, :audit, :forward, :error]` with
    `metadata.kind ∈ {:error, :exit, :throw}` so operators can trace failures.
    The originating audit transaction is already committed — forwarder failures
    cannot roll it back (Pitfall 2, boundary doctrine D-21).
    """

    @behaviour Sigra.Audit.Forwarder

    require Logger

    @forward_ok_event [:sigra, :audit, :forward, :ok]
    @forward_error_event [:sigra, :audit, :forward, :error]
    @audit_log_event [:sigra, :audit, :log]

    # D-03: handler id derived from {__MODULE__, opts[:id] || :default}
    # Supports multiple attach calls with different ids (two Threadline endpoints).
    @impl Sigra.Audit.Forwarder
    def attach(opts) do
      handler_id = {__MODULE__, Keyword.get(opts, :id, :default)}

      :telemetry.attach(
        handler_id,
        @audit_log_event,
        &__MODULE__.handle_event/4,
        opts
      )
    end

    # NOT an @impl — handle_event/4 is a convention, not a behaviour callback (D-33).
    # Wired to :telemetry by attach/1. Also called by Sigra.Workers.AuditForward.perform/1
    # on the async path (with dispatch: :sync to force inline execution in the job process).
    #
    # INVARIANT (D-20): EVERY code path returns :ok to :telemetry.
    # NEVER :stop. NEVER raises. This is the auto-detach landmine.
    def handle_event(_event, _measurements, metadata, opts) do
      started_at = System.monotonic_time(:millisecond)

      try do
        dispatch_mode = resolve_dispatch_mode(opts)

        result =
          case dispatch_mode do
            :sync ->
              # Inline path: call Threadline.record_action/2 directly.
              # Avoids recursive dispatch (dispatch_sync calls handle_event/4).
              call_threadline(metadata, opts)

            :async ->
              # Async path: enqueue via the shared dispatcher (dispatch_async
              # enqueues a worker job; does NOT call handle_event/4 recursively).
              Sigra.Audit.Forwarders.dispatch(__MODULE__, metadata, opts)
          end

        duration_ms = System.monotonic_time(:millisecond) - started_at

        case result do
          :ok ->
            :telemetry.execute(
              @forward_ok_event,
              %{count: 1, duration_ms: duration_ms},
              %{
                forwarder: :threadline,
                audit_event_id: metadata[:id],
                action: metadata[:action],
                dispatch: dispatch_mode
              }
            )

          {:ok, _job} ->
            :telemetry.execute(
              @forward_ok_event,
              %{count: 1, duration_ms: duration_ms},
              %{
                forwarder: :threadline,
                audit_event_id: metadata[:id],
                action: metadata[:action],
                dispatch: :async
              }
            )

          {:error, reason} ->
            :telemetry.execute(
              @forward_error_event,
              %{count: 1},
              %{
                forwarder: :threadline,
                audit_event_id: metadata[:id],
                action: metadata[:action],
                reason: reason,
                kind: :error,
                attempt: nil
              }
            )
        end

        :ok
      rescue
        exception ->
          :telemetry.execute(
            @forward_error_event,
            %{count: 1},
            %{
              forwarder: :threadline,
              audit_event_id: metadata[:id],
              action: metadata[:action],
              reason: exception,
              kind: :error,
              attempt: nil
            }
          )

          Logger.warning(
            "[Sigra.Audit.Forwarders.Threadline] Rescued #{inspect(exception.__struct__)}: #{Exception.message(exception)}"
          )

          :ok
      catch
        :exit, reason ->
          :telemetry.execute(
            @forward_error_event,
            %{count: 1},
            %{
              forwarder: :threadline,
              audit_event_id: metadata[:id],
              action: metadata[:action],
              reason: reason,
              kind: :exit,
              attempt: nil
            }
          )

          Logger.warning(
            "[Sigra.Audit.Forwarders.Threadline] Caught exit: #{inspect(reason)}"
          )

          :ok

        :throw, value ->
          :telemetry.execute(
            @forward_error_event,
            %{count: 1},
            %{
              forwarder: :threadline,
              audit_event_id: metadata[:id],
              action: metadata[:action],
              reason: value,
              kind: :throw,
              attempt: nil
            }
          )

          Logger.warning(
            "[Sigra.Audit.Forwarders.Threadline] Caught throw: #{inspect(value)}"
          )

          :ok
      end
    end

    # Private: resolve the effective dispatch mode, collapsing :auto to :sync/:async.
    # Mirrors Sigra.Audit.Forwarders.dispatch_mode/1 but private to this module
    # so we know the actual mode for :ok telemetry metadata (D-28).
    defp resolve_dispatch_mode(opts) do
      case Keyword.get(opts, :dispatch, :auto) do
        :auto -> if Sigra.Audit.Forwarders.oban_running?(opts), do: :async, else: :sync
        mode -> mode
      end
    end

    # Private: inline Threadline call for the :sync path.
    # Builds ActorRef from metadata.actor_id, constructs call opts,
    # sends correlation_id (audit row UUID) as the idempotency key
    # (RESEARCH.md §4 path 1, §7.2).
    defp call_threadline(metadata, opts) do
      threadline = Keyword.get(opts, :threadline_module, Threadline)
      actor_type = Keyword.get(opts, :actor_type, :user)
      repo = Keyword.get(opts, :repo)

      # Build ActorRef from metadata.actor_id (D-32: :repo + :actor_type).
      actor_ref = build_actor_ref(metadata[:actor_id], actor_type)

      # Map metadata.outcome to Threadline :status.
      # From Threadline.record_action/2 source: :status is :ok or :error.
      status =
        case metadata[:outcome] do
          :success -> :ok
          "success" -> :ok
          :failure -> :error
          "failure" -> :error
          :error -> :error
          _ -> :ok
        end

      # Action name: Threadline.record_action/2 requires an atom (when is_atom(name)).
      name =
        case metadata[:action] do
          a when is_atom(a) -> a
          s when is_binary(s) -> String.to_atom(s)
        end

      # Build Threadline call opts.
      call_opts =
        [
          repo: repo,
          status: status,
          # Audit row UUID as idempotency key (RESEARCH.md §4 path 1, §7.2)
          correlation_id: metadata[:id]
        ]
        |> add_actor_opt(actor_ref)

      case threadline.record_action(name, call_opts) do
        {:ok, _action} -> :ok
        {:error, %Ecto.Changeset{}} -> {:error, :schema_mismatch}
        {:error, :missing_actor} -> {:error, :missing_actor}
        {:error, :invalid_actor_ref} -> {:error, :invalid_actor_ref}
        {:error, :missing_repo} -> {:error, :missing_repo}
        {:error, reason} -> {:error, reason}
      end
    end

    # Private: construct a Threadline.Semantics.ActorRef from a string actor_id.
    # Falls back to :anonymous when actor_id is nil or construction fails.
    defp build_actor_ref(nil, _actor_type) do
      case Threadline.Semantics.ActorRef.new(:anonymous) do
        {:ok, ref} -> ref
        _ -> nil
      end
    end

    defp build_actor_ref(actor_id, actor_type) when is_binary(actor_id) do
      case Threadline.Semantics.ActorRef.new(actor_type, actor_id) do
        {:ok, ref} -> ref
        _ -> nil
      end
    end

    defp build_actor_ref(_, _), do: nil

    # Private: add :actor key to call_opts if actor_ref is available.
    defp add_actor_opt(call_opts, nil), do: call_opts
    defp add_actor_opt(call_opts, actor_ref), do: Keyword.put(call_opts, :actor, actor_ref)
  end
end
