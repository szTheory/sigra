defmodule ExampleWeb.ReactivationLive do
  @moduledoc """
  Stub account-reactivation LiveView for the example app.

  The generated Sigra templates reference `/users/reactivation` for
  account-deletion undo flows but do not currently generate a Reactivation
  LiveView. This stub exists so the example app compiles clean. A production
  app should replace this with a real reactivation/undo-deletion page.
  """
  use ExampleWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="reactivation">
      <h1>Reactivate your account</h1>
      <p>Stub page — replace with real reactivation flow.</p>
    </div>
    """
  end
end
