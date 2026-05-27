defmodule Sigra.Audit.Forwarder do
  @moduledoc """
  Behaviour for audit-event forwarders.

  A forwarder subscribes (in `attach/1`) to the `[:sigra, :audit, :log]`
  telemetry event and ships committed audit rows to a downstream sink —
  Threadline, Datadog, Honeycomb, OpenTelemetry, an in-house pipeline.
  Sigra's `audit_events` table remains the source of truth: forwarders
  are post-commit projections, never destination swaps. A downstream
  sink that drops events does not compromise the Sigra audit row (Phase
  131 boundary doctrine — D-21).

  Sigra ships two in-tree implementations:

  - `Sigra.Audit.Forwarders.Threadline` — telemetry-tap impl, loaded
    only when the `:threadline` dep is present.
  - `Sigra.Audit.Forwarders.Noop` — fail-open fallback used when a
    forwarder is configured but its dep is not loaded. A one-shot
    `Logger.warning` is emitted upstream from `Sigra.Application.start/2`
    in that case.

  Host applications can implement their own forwarder by adopting this
  behaviour and registering it in their `sigra_config/0` under
  `audit: [forwarders: [...]]`. Custom impls (Datadog, Honeycomb, OTel,
  in-house) get the same `:auto`/`:async`/`:sync` dispatch semantics for
  free — the behaviour does not constrain payload shape (D-33).

  ## Options Documented on `attach/1`

  The keyword list passed to `attach/1` carries the following keys
  (documented here, **not** validated by the behaviour — each impl
  validates its own keys at attach time):

  - `:id` — atom, handler-id uniqueness; defaults to `:default`. Lets
    the same impl attach multiple times with different ids (e.g. two
    Threadline endpoints).
  - `:dispatch` — `:auto | :async | :sync`; defaults to `:auto`.
    Per-forwarder dispatch policy, mirroring `email[:delivery_mode]`.
  - `:audit_schema` — module; needed by the worker on the `:async`
    path to reload audit rows.
  - `:repo` — module; needed by the worker to load rows.
  - `:oban` — module override for tests; defaults to `Oban`.
  - Plus arbitrary impl-specific keys. Threadline carries `:endpoint`
    and `:api_key`; other forwarders carry their own.

  ## Mox Usage

      Mox.defmock(MyForwarder, for: Sigra.Audit.Forwarder)
  """

  @doc "Attaches the forwarder. Called once from `Sigra.Application.start/2`."
  @doc since: "0.4.0"
  @callback attach(opts :: keyword()) :: :ok | {:error, term()}
end
