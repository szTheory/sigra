defmodule Sigra.Audit.Forwarders.Noop do
  @moduledoc """
  No-op audit forwarder.

  > #### Warning {: .warning}
  >
  > This forwarder silently drops all audit events — **no audit forwarding
  > happens** when it is attached. It is provided for explicit use in test
  > environments or when you want to satisfy the `Sigra.Audit.Forwarder`
  > behaviour contract without wiring a real backend.

  ## Degraded-dep behaviour (D-22, D-23)

  When a configured forwarder module (e.g. `Sigra.Audit.Forwarders.Threadline`)
  is **not loaded** at boot time, `Sigra.Application.attach_forwarders/0`
  **skips** the attach call entirely — it does NOT substitute Noop. A
  `Logger.warning` is emitted by
  `Sigra.Application.maybe_warn_missing_forwarder_deps/0` to alert
  operators, but zero forwarding happens (silent degrade, not Noop degrade).

  Noop is only active when it is **explicitly listed** in your
  `sigra_config/0` `audit: [forwarders: []]` block. To enable real
  forwarding, add the corresponding dep (e.g.
  `{:threadline, "~> 0.5", optional: true}`) to `mix.exs`, or remove
  the forwarder entry from the config block.

  This module does NOT subscribe to telemetry and does NOT emit log
  output. `attach/1` returns `:ok` immediately (D-22).
  """

  @behaviour Sigra.Audit.Forwarder

  @impl Sigra.Audit.Forwarder
  def attach(_opts), do: :ok
end
