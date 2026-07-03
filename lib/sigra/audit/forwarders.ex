defmodule Sigra.Audit.Forwarders do
  @moduledoc """
  Shared audit forwarder dispatcher.

  Provides `:auto`/`:async`/`:sync` dispatch routing for audit forwarders
  (Phase 131, v1.29 SUITE-INTEGRATION — D-10, D-11). The routing semantics
  mirror `Sigra.Delivery` exactly; the per-forwarder `:dispatch` option key
  (NOT top-level `:delivery_mode`) is read from each forwarder's opts (D-07).

  ## Dispatch Modes

  - `:auto` — detects Oban presence via `oban_running?/1`; routes to
    `:async` when supervised, `:sync` when not.
  - `:async` — enqueues a `Sigra.Workers.AuditForward` Oban job. Returns
    `{:error, :async_worker_not_compiled}` if the worker module is not
    compiled (Oban not in deps) — callers observe the degradation rather
    than receiving a silent `:ok`.
  - `:sync` — calls `forwarder_module.handle_event/4` inline in the
    calling process.

  ## Custom Forwarders

  Host-defined custom forwarders that always run `:sync` can call this
  dispatcher directly from their own `handle_event/4` implementation:

      def handle_event(_event, _measurements, metadata, opts) do
        Sigra.Audit.Forwarders.dispatch(__MODULE__, metadata, opts)
      end

  ## Placement (D-11)

  The dispatcher is a standalone module (not a private fn on the worker) so
  custom always-`:sync` forwarders can reuse it without depending on the
  Oban worker being compiled. See RESEARCH.md §7.1 for the rationale.

  ## Boot-Time Safety

  The boot-time `:async`-without-Oban raise (D-26) does NOT live here — it
  lives in `Sigra.Application.attach_forwarders/0`. This dispatcher only
  routes already-validated `:auto`/`:async`/`:sync` values.
  """

  @telemetry_event [:sigra, :audit, :log]

  @doc """
  Dispatches a forwarder call using the configured `:dispatch` mode.

  ## Arguments

  - `forwarder_module` — module implementing `Sigra.Audit.Forwarder`
  - `metadata` — the `[:sigra, :audit, :log]` metadata map (includes `:id`
    and `:occurred_at` per D-31 from Plan 02)
  - `opts` — per-forwarder keyword list from `sigra_config/0`
    `audit[:forwarders]`. Canonical keys: `:dispatch`, `:id`, `:oban`.
    Impl-specific keys (`:endpoint`, `:api_key`, etc.) are passed through.

  ## Returns

  - `:ok` — inline call succeeded or async enqueue completed
  - `{:ok, job}` — Oban job inserted (async path)
  - `{:error, reason}` — inline call or enqueue failed
  """
  @spec dispatch(module(), map(), keyword()) :: :ok | {:ok, term()} | {:error, term()}
  def dispatch(forwarder_module, metadata, opts) do
    case dispatch_mode(opts) do
      :sync -> dispatch_sync(forwarder_module, metadata, opts)
      :async -> dispatch_async(forwarder_module, metadata, opts)
    end
  end

  @doc false
  # PUBLIC — Plan 05's Sigra.Application.attach_forwarders/0 calls this
  # cross-module to check whether Oban is supervised before deciding whether
  # to raise on a :async + no-Oban misconfiguration (D-12, BLOCKER 2).
  #
  # Mirrors lib/sigra/delivery.ex:113-115 exactly (byte-for-byte) except:
  # - takes opts keyword list to allow :oban override (D-32 — used in tests
  #   to pass a mock process atom rather than the real Oban supervisor)
  # - reads `Keyword.get(opts, :oban, Oban)` mirroring delivery.ex:47
  #
  # :auto must only route to :async when Oban is actually supervised in the
  # host app — not merely compiled/loadable. Apps that add `{:oban, ...}` to
  # mix.exs without wiring the supervisor would otherwise crash on insert.
  #
  # When :oban is overridden (test mode), the Code.ensure_loaded? check is
  # skipped — we only check Process.whereis because the override atom is a
  # named process, not a compiled module. The ensure_loaded? guard is only
  # meaningful for the real Oban module default.
  @spec oban_running?(keyword()) :: boolean()
  def oban_running?(opts) do
    case Keyword.fetch(opts, :oban) do
      {:ok, oban_override} ->
        # Test override: skip Code.ensure_loaded? (override is a named process, not a module)
        Process.whereis(oban_override) != nil

      :error ->
        # Production path: delegate to SOT (Sigra.OptionalDeps.oban_running?/0)
        Sigra.OptionalDeps.oban_running?()
    end
  end

  # Private: picks the concrete dispatch mode, resolving :auto.
  # Reads :dispatch (per-forwarder, D-07) — NOT :delivery_mode (top-level).
  defp dispatch_mode(opts) do
    case Keyword.get(opts, :dispatch, :auto) do
      :auto -> if oban_running?(opts), do: :async, else: :sync
      mode -> mode
    end
  end

  # Private: inline (synchronous) dispatch.
  # Calls forwarder_module.handle_event/4 in the calling process.
  # handle_event/4 is NOT a behaviour callback (D-33) but is the convention
  # used by Sigra's own impls (Threadline, Noop). Custom impls that don't
  # define handle_event/4 should call this dispatcher from their own handler.
  defp dispatch_sync(forwarder_module, metadata, opts) do
    if function_exported?(forwarder_module, :handle_event, 4) do
      forwarder_module.handle_event(@telemetry_event, %{}, metadata, opts)
    else
      :ok
    end
  end

  # Private: asynchronous dispatch via Oban worker.
  #
  # Returns {:error, :async_worker_not_compiled} if Sigra.Workers.AuditForward is
  # not compiled (Oban absent from deps). The D-26 boot-time raise in
  # attach_forwarders/0 prevents :async dispatch from being configured without Oban
  # supervised, but this guard protects against runtime calls (e.g. hot deploys that
  # removed Oban) and provides an observable error rather than a silent :ok.
  #
  # Uses apply/3 to avoid a compile-time undefined-module warning when
  # Sigra.Workers.AuditForward is conditionally compiled (wrapped in
  # Code.ensure_loaded?(Oban.Worker)). mix.exs no_warn_undefined carries
  # Sigra.Workers.AuditForward to suppress the dialyzer warning.
  @worker_module Sigra.Workers.AuditForward
  defp dispatch_async(forwarder_module, metadata, opts) do
    if Code.ensure_loaded?(@worker_module) do
      oban = Keyword.get(opts, :oban, Oban)

      job_args = %{
        "forwarder" => Atom.to_string(forwarder_module),
        "audit_event_id" => metadata[:id],
        "occurred_at" => format_occurred_at(metadata[:occurred_at])
      }

      changeset = apply(@worker_module, :new, [job_args])

      case oban.insert(changeset) do
        {:ok, job} -> {:ok, job}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, :async_worker_not_compiled}
    end
  end

  defp format_occurred_at(nil), do: nil
  defp format_occurred_at(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_occurred_at(other), do: other
end
