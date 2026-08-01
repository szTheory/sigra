defmodule Sigra.Install.Features.PasskeysJsTest do
  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture

  @moduletag timeout: 180_000
  @moduletag :scaffold

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
      browser_helper = InstallFixture.read_asset_file(app_dir, "js/passkey_browser.js")

      assert app_js =~ @passkey_start_marker
      assert app_js =~ @passkey_end_marker
      assert app_js =~ @passkey_import
      assert app_js =~ @passkey_hooks_line
      assert String.contains?(app_js, @passkey_start_marker)
      assert browser_helper =~ "startRegistration"
      assert browser_helper =~ "startAuthentication"
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
    test "ships controller completion and conditional UI template contracts" do
      hook_template = File.read!("priv/templates/sigra.install/passkeys/passkey_hooks.js")
      browser_helper = File.read!("priv/templates/sigra.install/passkeys/passkey_browser.js")
      injection = File.read!("priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js")

      for expected <- [
            "optionsUrl",
            "completeUrl",
            "passkey[response]",
            "JSON.stringify",
            "x-csrf-token",
            "useBrowserAutofill",
            "browserSupportsWebAuthnAutofill",
            "ERROR_PASSKEY_UNSUPPORTED"
          ] do
        assert hook_template =~ expected or browser_helper =~ expected
      end

      for expected <- [
            "attachPasskeyLogin",
            "DOMContentLoaded",
            "silentConditionalErrors",
            "#passkey_login_form",
            "#passkey_login_button",
            "/users/log_in/passkey/options",
            "/users/log_in/passkey"
          ] do
        assert browser_helper =~ expected or injection =~ expected
      end
    end

    test "exports both passkey hook objects and ships the browser helper locally" do
      template_path = "priv/templates/sigra.install/passkeys/passkey_hooks.js"
      browser_helper_path = "priv/templates/sigra.install/passkeys/passkey_browser.js"
      injection_path = "priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js"

      assert File.read!(template_path) =~ "PasskeyRegister"
      assert File.read!(template_path) =~ "PasskeyAuthenticate"
      assert File.read!(template_path) =~ ~s(from "./passkey_browser")
      assert File.read!(browser_helper_path) =~ "startRegistration"
      assert File.read!(browser_helper_path) =~ "startAuthentication"
      assert File.read!(browser_helper_path) =~ ~s(from "@simplewebauthn/browser")
      assert File.read!(injection_path) =~ @passkey_start_marker
      assert File.read!(injection_path) =~ @passkey_end_marker
    end

    test "destroyed teardown emits a single aborted event for the active ceremony" do
      if node = System.find_executable("node") do
        tmp_dir =
          Path.join(
            System.tmp_dir!(),
            "sigra_passkey_hooks_#{System.unique_integer([:positive])}"
          )

        File.mkdir_p!(tmp_dir)
        on_exit(fn -> File.rm_rf!(tmp_dir) end)

        template_source = File.read!("priv/templates/sigra.install/passkeys/passkey_hooks.js")

        module_source =
          String.replace(
            template_source,
            ~s(from "./passkey_browser"),
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

    test "authenticate hook emits unsupported error from browser autofill" do
      if node = System.find_executable("node") do
        stdout =
          run_node_script!(node, %{
            "passkey_hooks_under_test.mjs" =>
              File.read!("priv/templates/sigra.install/passkeys/passkey_hooks.js")
              |> String.replace(
                ~s(from "./passkey_browser"),
                ~s(from "./browser_stub.mjs")
              ),
            "browser_stub.mjs" => """
            export class WebAuthnError extends Error {
              constructor(message, code) {
                super(message)
                this.name = "WebAuthnError"
                this.code = code
              }
            }

            export const WebAuthnAbortService = { cancelCeremony() {} }

            export function startRegistration() {
              throw new Error("unused")
            }

            export function startAuthentication({ useBrowserAutofill }) {
              if (useBrowserAutofill) {
                throw new WebAuthnError("unsupported", "ERROR_PASSKEY_UNSUPPORTED")
              }

              return { id: "credential-id" }
            }
            """,
            "runner.mjs" => """
            import { PasskeyAuthenticate } from "./passkey_hooks_under_test.mjs"

            const events = []
            const hook = {
              ...PasskeyAuthenticate,
              handleEvent(_event, callback) {
                this.startCallback = callback
              },
              pushEvent(event, payload) {
                events.push({ event, payload })
              }
            }

            hook.mounted()
            await hook.startCallback({
              options: { challenge: "abc" },
              useBrowserAutofill: true
            })
            console.log(JSON.stringify(events))
            """
          })

        assert Jason.decode!(stdout) == [
                 %{
                   "event" => "sigra:passkey-authenticate:error",
                   "payload" => %{
                     "code" => "ERROR_PASSKEY_UNSUPPORTED",
                     "message" => "unsupported",
                     "name" => "WebAuthnError"
                   }
                 }
               ]
      else
        flunk("node executable is required for passkey hook runtime coverage")
      end
    end

    test "controller login conditional UI fetches options without email and uses conditional mediation" do
      if node = System.find_executable("node") do
        stdout = run_browser_helper_node!(node, "conditional")
        result = Jason.decode!(stdout)

        assert result["attached"] == true

        assert result["fetches"] == [
                 %{
                   "url" => "/users/log_in/passkey/options",
                   "body" => %{"conditional" => "true"},
                   "csrf" => "csrf-token"
                 }
               ]

        assert result["credentialRequests"] == [%{"mediation" => "conditional"}]
        assert result["submittedAction"] == "/users/log_in/passkey"
        assert result["responseValue"] =~ "credential-id"
        refute result["responseValue"] =~ "user@example.com"
      else
        flunk("node executable is required for passkey browser helper coverage")
      end
    end

    test "controller login explicit click includes email and submits without conditional mediation" do
      if node = System.find_executable("node") do
        stdout = run_browser_helper_node!(node, "explicit")
        result = Jason.decode!(stdout)

        assert result["fetches"] == [
                 %{
                   "url" => "/users/log_in/passkey/options",
                   "body" => %{"user" => %{"email" => "user@example.com"}},
                   "csrf" => "csrf-token"
                 }
               ]

        assert result["credentialRequests"] == [%{"mediation" => nil}]
        assert result["submittedAction"] == "/users/log_in/passkey"
        assert result["responseValue"] =~ "credential-id"
      else
        flunk("node executable is required for passkey browser helper coverage")
      end
    end

    test "controller login keeps conditional UI startup failures silent" do
      if node = System.find_executable("node") do
        for scenario <- ["unsupported", "abort", "timeout"] do
          stdout = run_browser_helper_node!(node, scenario)
          result = Jason.decode!(stdout)

          assert result["status"] in [nil, ""]
          assert result["statusText"] == ""
          assert result["submittedAction"] == nil
          assert result["fallbackVisible"] == true
        end
      else
        flunk("node executable is required for passkey browser helper coverage")
      end
    end

    test "controller login explicit click maps unsupported abort and timeout to safe copy" do
      if node = System.find_executable("node") do
        for {scenario, status} <- [
              {"explicit_unsupported", "unsupported"},
              {"explicit_abort", "canceled"},
              {"explicit_timeout", "timeout"}
            ] do
          stdout = run_browser_helper_node!(node, scenario)
          result = Jason.decode!(stdout)

          assert result["status"] == status
          refute result["statusText"] =~ "AbortError"
          refute result["statusText"] =~ "NotAllowedError"
          refute result["statusText"] =~ "raw browser"
          assert result["fallbackVisible"] == true
        end
      else
        flunk("node executable is required for passkey browser helper coverage")
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

  defp run_node_script!(node, files) do
    tmp_dir =
      Path.join(System.tmp_dir!(), "sigra_passkey_js_#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    try do
      for {name, contents} <- files do
        File.write!(Path.join(tmp_dir, name), contents)
      end

      {stdout, 0} = System.cmd(node, [Path.join(tmp_dir, "runner.mjs")], stderr_to_stdout: true)
      stdout
    after
      File.rm_rf!(tmp_dir)
    end
  end

  defp run_browser_helper_node!(node, scenario) do
    browser_source =
      File.read!("priv/templates/sigra.install/passkeys/passkey_browser.js")
      |> String.replace(
        ~s(from "@simplewebauthn/browser"),
        ~s(from "./browser_stub.mjs")
      )

    run_node_script!(node, %{
      "passkey_browser_under_test.mjs" => browser_source,
      "browser_stub.mjs" => browser_helper_browser_stub(),
      "runner.mjs" => browser_helper_runner(scenario)
    })
  end

  defp browser_helper_browser_stub do
    """
    export class WebAuthnError extends Error {
      constructor(message, code) {
        super(message)
        this.name = "WebAuthnError"
        this.code = code
      }
    }

    export async function browserSupportsWebAuthnAutofill() {
      return globalThis.__browserAutofillAvailable ?? false
    }

    export async function startRegistration({ optionsJSON }) {
      return {
        id: "registration-credential-id",
        optionsJSON
      }
    }

    export async function startAuthentication({ optionsJSON, useBrowserAutofill }) {
      return globalThis.__browserStartAuthentication(optionsJSON, useBrowserAutofill)
    }
    """
  end

  defp browser_helper_runner(scenario) do
    """
    import { attachPasskeyLogin } from "./passkey_browser_under_test.mjs"

    const fetches = []
    const credentialRequests = []

    class FakeForm {}
    globalThis.HTMLFormElement = FakeForm
    HTMLFormElement.prototype.submit = function() {
      this.submitted = true
      this.submittedAction = this.action
    }

    function makeInput(name, value = "") {
      return {
        name,
        value,
        hidden: false,
        getAttribute(attribute) {
          return attribute === "name" ? this.name : null
        }
      }
    }

    const emailInput = makeInput("user[email]", "user@example.com")
    const responseInput = makeInput("passkey[response]", "")
    const statusElement = { dataset: {}, textContent: "" }
    const fallbackElement = { hidden: false }
    const button = {
      listeners: {},
      addEventListener(event, callback) {
        this.listeners[event] = callback
      },
      click() {
        return this.listeners.click({ preventDefault() {} })
      }
    }

    const form = new FakeForm()
    form.action = "/users/log_in/passkey"
    form.dataset = { optionsUrl: "/users/log_in/passkey/options" }
    form.listeners = {}
    form.addEventListener = function(event, callback) {
      this.listeners[event] = callback
    }
    form.querySelector = function(selector) {
      if (selector === "input[name='user[email]']") return emailInput
      if (selector === "input[name='user[email]']:not([data-passkey-email-shadow])") return emailInput
      if (selector === "input[name='passkey[response]']") return responseInput
      if (selector === "[data-passkey-login-status]") return statusElement
      if (selector === "[data-passkey-fallback]") return fallbackElement
      return null
    }

    const scenario = #{inspect(scenario)}
    const explicitScenario = scenario.startsWith("explicit_")
    const failureScenario = explicitScenario ? scenario.replace("explicit_", "") : scenario

    globalThis.__browserAutofillAvailable = failureScenario !== "unsupported"
    globalThis.__browserStartAuthentication = async (_optionsJSON, useBrowserAutofill) => {
      credentialRequests.push({ mediation: useBrowserAutofill ? "conditional" : null })

      if (failureScenario === "abort") {
        const error = new Error("raw browser abort message")
        error.name = "AbortError"
        throw error
      }

      if (failureScenario === "timeout") {
        const error = new Error("raw browser timeout message")
        error.name = "TimeoutError"
        throw error
      }

      if (failureScenario === "unsupported") {
        const error = new Error("raw browser unsupported message")
        error.name = "NotSupportedError"
        throw error
      }

      return {
        id: "credential-id",
        response: {
          clientDataJSON: "client-data"
        }
      }
    }

    globalThis.document = {
      querySelector(selector) {
        if (selector === "#passkey_login_form") return form
        if (selector === "#passkey_login_button") return button
        if (selector === "meta[name='csrf-token']") return { content: "csrf-token" }
        return null
      }
    }

    globalThis.fetch = async (url, options) => {
      fetches.push({
        url,
        body: JSON.parse(options.body),
        csrf: options.headers["x-csrf-token"]
      })

      return {
        ok: true,
        json: async () => ({
          options: {
            challenge: "AQID",
            allowCredentials: [{ id: "BAUG", type: "public-key" }]
          }
        })
      }
    }

    const result = await attachPasskeyLogin({ enableConditionalUI: !(scenario === "explicit" || explicitScenario) })

    if (scenario === "explicit" || explicitScenario) {
      await button.click()
    }

    await result.ready
    await new Promise(resolve => setTimeout(resolve, 0))

    console.log(JSON.stringify({
      attached: result.attached,
      fetches,
      credentialRequests,
      submittedAction: form.submittedAction ?? null,
      responseValue: responseInput.value,
      status: statusElement.dataset.passkeyStatus ?? null,
      statusText: statusElement.textContent,
      fallbackVisible: fallbackElement.hidden === false
    }))
    """
  end
end
