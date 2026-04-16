defmodule Sigra.Admin.Live.IndexLive do
  @moduledoc """
  Foundation global admin entry LiveView.

  Phase 27 keeps this surface intentionally thin: it consumes the resolved
  admin scope, assigns a page title, and renders placeholder content through
  the host-owned admin shell layout.
  """

  use Phoenix.LiveView

  @impl true
  def mount(_params, _session, socket) do
    {:ok, redirect(socket, to: "/admin/users")}
  end
end
