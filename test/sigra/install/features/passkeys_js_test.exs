defmodule Sigra.Install.Features.PasskeysJsTest do
  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture

  @moduletag timeout: 180_000

  @passkey_import ~s(import { PasskeyHooks } from "./passkey_hooks")
  @passkey_hooks_line ~s(hooks: { ...colocatedHooks, ...PasskeyHooks })
  @passkey_start_marker "// Sigra passkeys:start"
  @passkey_end_marker "// Sigra passkeys:end"
  @standard_app_js """
  import "phoenix_html"
  import { Socket } from "phoenix"
  import { LiveSocket } from "phoenix_live_view"
  import topbar from "../vendor/topbar"
  import { hooks as colocatedHooks } from "phoenix-colocated/my_app"

  const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
  const liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken },
    hooks: { ...colocatedHooks },
  })

  topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
  window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
  window.addEventListener("phx:page-loading-stop", _info => topbar.hide())
  liveSocket.connect()
  window.liveSocket = liveSocket
  """

  describe "mix sigra.install --passkeys app.js wiring" do
    test "injects a marker-wrapped merged hooks block into the standard Phoenix app.js shape" do
      %{app_dir: app_dir} = setup_tmp_app_with_standard_app_js!()

      assert {:ok, _stdout} = InstallFixture.run_sigra_install(app_dir, ["--passkeys"])

      app_js = InstallFixture.read_asset_file(app_dir, "js/app.js")

      assert app_js =~ @passkey_start_marker
      assert app_js =~ @passkey_end_marker
      assert app_js =~ @passkey_import
      assert app_js =~ @passkey_hooks_line
      assert String.contains?(app_js, @passkey_start_marker)
    end

    test "rerunning install keeps a single passkey marker block" do
      %{app_dir: app_dir} = setup_tmp_app_with_standard_app_js!()

      assert {:ok, _stdout} = InstallFixture.run_sigra_install(app_dir, ["--passkeys"])
      assert {:ok, _stdout} = InstallFixture.run_sigra_install(app_dir, ["--passkeys"])

      app_js = InstallFixture.read_asset_file(app_dir, "js/app.js")

      assert count_occurrences(app_js, @passkey_start_marker) == 1
      assert count_occurrences(app_js, @passkey_end_marker) == 1
      assert count_occurrences(app_js, @passkey_import) == 1
      assert count_occurrences(app_js, @passkey_hooks_line) == 1
    end

    test "leaves non-standard app.js untouched and prints exact manual instructions" do
      %{app_dir: app_dir} = setup_tmp_app!()

      custom_app_js = """
      import "phoenix_html"
      import { Socket } from "phoenix"
      import topbar from "../vendor/topbar"

      const socket = new Socket("/socket", {})
      socket.connect()

      window.topbar = topbar
      """

      :ok = InstallFixture.write_asset_file(app_dir, "js/app.js", custom_app_js)

      assert {:ok, stdout} = InstallFixture.run_sigra_install(app_dir, ["--passkeys"])

      assert InstallFixture.read_asset_file(app_dir, "js/app.js") == custom_app_js
      assert stdout =~ @passkey_import
      assert stdout =~ @passkey_hooks_line
    end
  end

  describe "passkey hook template contract" do
    test "exports both passkey hook objects and the marker contract stays explicit" do
      template_path = "priv/templates/sigra.install/passkeys/passkey_hooks.js"
      injection_path = "priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js"

      assert File.read!(template_path) =~ "PasskeyRegister"
      assert File.read!(template_path) =~ "PasskeyAuthenticate"
      assert File.read!(injection_path) =~ @passkey_start_marker
      assert File.read!(injection_path) =~ @passkey_end_marker
    end

    test "destroyed teardown emits a single aborted event for the active ceremony" do
      if node = System.find_executable("node") do
        tmp_dir =
          Path.join(System.tmp_dir!(), "sigra_passkey_hooks_#{System.unique_integer([:positive])}")

        File.mkdir_p!(tmp_dir)
        on_exit(fn -> File.rm_rf!(tmp_dir) end)

        template_source = File.read!("priv/templates/sigra.install/passkeys/passkey_hooks.js")

        module_source =
          String.replace(
            template_source,
            ~s(from "@simplewebauthn/browser"),
            ~s(from "./browser_stub.mjs")
          )

        File.write!(Path.join(tmp_dir, "passkey_hooks_under_test.mjs"), module_source)

        File.write!(
          Path.join(tmp_dir, "browser_stub.mjs"),
          """
          export class WebAuthnError extends Error {
            constructor(message, code) {
              super(message)
              this.name = "WebAuthnError"
              this.code = code
            }
          }

          export const WebAuthnAbortService = {
            cancelCeremony() {}
          }

          function rejectedOnAbort(signal) {
            return new Promise((resolve, reject) => {
              signal.addEventListener(
                "abort",
                () => reject(new WebAuthnError("aborted", "ERROR_CEREMONY_ABORTED")),
                { once: true }
              )
            })
          }

          export function startRegistration({ signal }) {
            return rejectedOnAbort(signal)
          }

          export function startAuthentication({ signal }) {
            return rejectedOnAbort(signal)
          }
          """
        )

        File.write!(
          Path.join(tmp_dir, "runner.mjs"),
          """
          import { PasskeyRegister } from "./passkey_hooks_under_test.mjs"

          const events = []
          const hook = {
            ...PasskeyRegister,
            handleEvent(_event, callback) {
              this.startCallback = callback
            },
            pushEvent(event, payload) {
              events.push({ event, payload })
            }
          }

          hook.mounted()
          const startPromise = hook.startCallback({ options: { challenge: "abc" } })
          hook.destroyed()
          await startPromise.catch(() => {})
          await new Promise(resolve => setTimeout(resolve, 0))
          console.log(JSON.stringify(events))
          """
        )

        {stdout, 0} =
          System.cmd(node, [Path.join(tmp_dir, "runner.mjs")], stderr_to_stdout: true)

        events = Jason.decode!(stdout)

        assert events == [
                 %{
                   "event" => "sigra:passkey-register:aborted",
                   "payload" => %{"reason" => "destroyed"}
                 }
               ]
      else
        flunk("node executable is required for passkey hook runtime coverage")
      end
    end
  end

  defp setup_tmp_app! do
    {:ok, fixture} = InstallFixture.setup_tmp_app_without_install(app_name: unique_app_name())
    fixture
  end

  defp setup_tmp_app_with_standard_app_js! do
    fixture = setup_tmp_app!()
    :ok = InstallFixture.write_asset_file(fixture.app_dir, "js/app.js", @standard_app_js)
    fixture
  end

  defp unique_app_name do
    "sigra_passkeys_#{System.unique_integer([:positive])}"
  end

  defp count_occurrences(contents, needle) do
    contents
    |> String.split(needle)
    |> length()
    |> Kernel.-(1)
  end
end
