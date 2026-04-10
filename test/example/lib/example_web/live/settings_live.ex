defmodule ExampleWeb.SettingsLive do
  @moduledoc """
  Stub settings LiveView for the example app.

  The generated Sigra templates reference `/users/settings` and
  `/users/settings#password` in redirects but do not currently generate a
  Settings LiveView. This stub exists so the example app compiles clean and
  the smoke-test suite for plan 10-06 can run. A production app should replace
  this with a real settings page (email change, password change, MFA management).
  """
  use ExampleWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="settings">
      <h1>Account settings</h1>
      <p>Stub page — replace with real settings UI.</p>
    </div>
    """
  end
end
