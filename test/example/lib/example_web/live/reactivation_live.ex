defmodule ExampleWeb.ReactivationLive do
  @moduledoc """
  ⚠️  STUB — NOT FOR PRODUCTION ⚠️

  This is a scaffolding placeholder created during Phase 10 plan 10-06 to
  unblock compilation of the Sigra-generated router. It does NOT implement
  account-reactivation functionality.

  DO NOT COPY THIS FILE INTO A REAL APPLICATION.

  The real reactivation LiveView template ships with `mix sigra.install` and
  lives at `priv/templates/sigra.install/reactivation_live.ex`. That template
  implements the account-deletion undo flow (token verification, restore
  confirmation, and user feedback). A fresh `mix sigra.install` run will emit
  the real LiveView, not this stub.

  This stub exists ONLY so that `test/example/` can compile and smoke-test
  the happy-path register/login/logout flows without wiring the full
  reactivation UI.
  """
  use ExampleWeb, :live_view
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    maybe_warn_stub()
    {:ok, assign(socket, page_title: "Reactivation (stub)")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="stub-warning">
      <h1>Reactivate your account (stub)</h1>
      <p>
        <strong>STUB — NOT FOR PRODUCTION.</strong>
        This is a test/example scaffold placeholder. See the module docs.
      </p>
    </div>
    """
  end

  defp maybe_warn_stub do
    if env() != :test do
      Logger.warning("""
      ExampleWeb.ReactivationLive is a STUB and was rendered outside :test env.
      This module is test/example scaffolding and must NOT be used in
      production. Replace with the real Sigra reactivation LiveView from
      priv/templates/sigra.install/reactivation_live.ex.
      """)
    end
  end

  # Release-safe env detection (mirrors Sigra.Env.current/0 from plan 10.1-04)
  defp env do
    if function_exported?(Mix, :env, 0), do: Mix.env(), else: :prod
  end
end
