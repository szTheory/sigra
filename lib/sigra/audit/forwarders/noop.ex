defmodule Sigra.Audit.Forwarders.Noop do
  @moduledoc """
  No-op audit forwarder.

  > #### Warning {: .warning}
  >
  > This is a fallback used when an audit forwarder is configured
  > (e.g. Threadline) but its dep is not loaded. It silently drops
  > events — **no audit forwarding happens**. The upstream
  > one-shot warning advising the missing dep is emitted from
  > `Sigra.Application.maybe_warn_missing_forwarder_deps/0`, not from
  > here — this module does not subscribe to telemetry and does not
  > emit log output.

  Used automatically when a configured forwarder module is not
  loaded at boot time. To enable real forwarding, add the
  corresponding dep (e.g. `{:threadline, "~> 0.5", optional: true}`)
  to `mix.exs`, or remove the forwarder entry from your
  `sigra_config/0` `audit: [forwarders: [...]]` block.
  """

  @behaviour Sigra.Audit.Forwarder

  @impl Sigra.Audit.Forwarder
  def attach(_opts), do: :ok
end
