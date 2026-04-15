# Phase 21: Passkey LiveViews + POST-Auth Controller - Pattern Map

**Mapped:** 2026-04-15
**Files analyzed:** 12 new/modified files
**Analogs found:** 11 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `priv/templates/sigra.install/core/mfa_settings_live.ex` | LiveView/component | event-driven + CRUD | `priv/templates/sigra.install/core/mfa_settings_live.ex` + `priv/templates/sigra.gen.oauth/oauth_settings_live.ex` | exact |
| `priv/templates/sigra.install/core/mfa_challenge_live.ex` | LiveView/component | event-driven + request-response handoff | `priv/templates/sigra.install/core/mfa_challenge_live.ex` | exact |
| `priv/templates/sigra.install/core/session_controller.ex` | controller | request-response | `priv/templates/sigra.install/core/session_controller.ex` | exact |
| `priv/templates/sigra.install/core/login_html.ex` | controller template/component | request-response | `priv/templates/sigra.install/core/login_html.ex` | exact |
| `priv/templates/sigra.install/core/auth.ex` | service/context | CRUD + request-response | `priv/templates/sigra.install/core/auth.ex` + `lib/sigra/passkeys.ex` | exact |
| `priv/templates/sigra.install/core/emails.ex` | utility/template | transform | `priv/templates/sigra.install/core/emails.ex` | exact |
| `lib/sigra/install/features/core.ex` | generator/config | file-I/O + request-response route injection | `lib/sigra/install/features/core.ex` | exact |
| `priv/templates/sigra.install/passkeys/passkey_hooks.js` | client hook | event-driven | `priv/templates/sigra.install/passkeys/passkey_hooks.js` | exact |
| `priv/templates/sigra.install/passkeys/passkey_browser.js` | client utility | event-driven transform | `priv/templates/sigra.install/passkeys/passkey_browser.js` | exact |
| `priv/templates/sigra.install/passkeys/aaguids.json` or equivalent generated helper | config/data utility | transform | `lib/sigra/install/features/passkeys.ex` | no exact analog |
| `test/sigra/install/generator_mfa_test.exs` | test | batch/assertion | `test/sigra/install/generator_mfa_test.exs` | exact |
| `test/sigra/install/features/passkeys_js_test.exs` | test | batch + event-driven JS | `test/sigra/install/features/passkeys_js_test.exs` | exact |

## Pattern Assignments

### `priv/templates/sigra.install/core/mfa_settings_live.ex` (LiveView/component, event-driven + CRUD)

**Analogs:** `priv/templates/sigra.install/core/mfa_settings_live.ex`, `priv/templates/sigra.gen.oauth/oauth_settings_live.ex`

**Imports pattern** (`priv/templates/sigra.install/core/mfa_settings_live.ex` lines 16-18):
```elixir
use <%= web_module %>, :live_view

alias <%= context_module %>, as: Auth
```

**Initial state pattern** (`priv/templates/sigra.install/core/mfa_settings_live.ex` lines 25-45):
```elixir
def mount(_params, _session, socket) do
  user = socket.assigns.current_scope.user
  mfa_status = Auth.mfa_status(user)

  {:ok,
   assign(socket,
     mfa_enabled: mfa_status.enabled,
     enrollment_step: nil,
     backup_remaining: mfa_status.backup_codes_remaining,
     page_title: "MFA Settings"
   )}
end
```

**Management card/list pattern** (`priv/templates/sigra.gen.oauth/oauth_settings_live.ex` lines 57-100):
```elixir
<div class="mt-8 space-y-4">
  <%= if @identities == [] do %>
    <div class="text-center py-8">
      <p class="text-sm font-semibold text-gray-900">No connected accounts</p>
      <p class="mt-1 text-sm text-gray-500">Link a sign-in provider for faster access.</p>
    </div>
  <% else %>
    <%= for identity <- @identities do %>
      <div class="flex items-start justify-between p-4 bg-gray-50 rounded-lg border border-gray-200">
        <div>
          <div class="flex items-center gap-2">
            <span class="font-semibold text-sm">{oauth_provider_name(safe_provider_atom(identity.provider))}</span>
            <span class="text-sm text-gray-500">{identity.provider_email}</span>
          </div>
          <div class="mt-1 text-sm text-gray-500">
            Linked {relative_time(identity.inserted_at)}
            <%= if identity.last_used_at do %>
              &middot; Last used {relative_time(identity.last_used_at)}
            <% end %>
          </div>
        </div>
      </div>
    <% end %>
  <% end %>
</div>
```

**Mutation/error pattern** (`priv/templates/sigra.install/core/mfa_settings_live.ex` lines 475-515):
```elixir
case Auth.mfa_disable(user, code) do
  {:ok, :disabled} ->
    {:noreply,
     socket
     |> put_flash(:info, "Two-factor authentication has been disabled.")
     |> assign(mfa_enabled: false, show_disable: false)}

  {:error, :invalid_code, _remaining} ->
    {:noreply,
     socket
     |> put_flash(:error, "Invalid verification code. Please try again.")
     |> assign(disable_form: to_form(%{"code" => ""}, as: "disable"))}

  {:error, :lockout, seconds} ->
    minutes = div(seconds + 59, 60)
    {:noreply, put_flash(socket, :error, "Too many failed attempts. Try again in #{minutes} minutes.")}
end
```

**Apply to Phase 21:** Add passkey assigns (`passkeys`, `passkey_count`, rename/delete state, registration recovery state) in `mount/3`; render a prominent passkeys section inside `/users/settings/mfa`; use `Sigra.Passkeys.list_for_user/2`, `rename/5`, and `delete/4` through generated `Auth` wrappers. Keep delete row-local and sudo-gated by route/plug, not by trusting LiveView state alone.

---

### `priv/templates/sigra.install/core/mfa_challenge_live.ex` (LiveView/component, event-driven + request-response handoff)

**Analog:** `priv/templates/sigra.install/core/mfa_challenge_live.ex`

**Imports pattern** (lines 12-14):
```elixir
use <%= web_module %>, :live_view

alias <%= context_module %>, as: Auth
```

**Pending-session guard pattern** (lines 16-36):
```elixir
def mount(_params, session, socket) do
  mfa_pending = session["mfa_pending"]

  if mfa_pending != true do
    {:ok,
     socket
     |> put_flash(:error, "No MFA challenge pending.")
     |> redirect(to: ~p"/")}
  else
    user = socket.assigns.current_scope.user
    masked_email = mask_email(user.email)

    {:ok,
     assign(socket,
       active_tab: "totp",
       masked_email: masked_email,
       page_title: "Two-factor authentication"
     )}
  end
end
```

**Current fallback form pattern** (lines 87-128):
```elixir
<.form
  for={@totp_form}
  id="mfa_totp_form"
  phx-change="validate_totp"
  phx-submit="verify_totp"
>
  <input
    type="text"
    id="mfa_totp_code"
    name="mfa[code]"
    inputmode="numeric"
    pattern="[0-9]*"
    maxlength="6"
    autocomplete="one-time-code"
    required
  />
  <.button phx-disable-with="Verifying..." class="w-full">Verify</.button>
</.form>
```

**Event/error pattern** (lines 200-232):
```elixir
case Auth.mfa_verify(user, code) do
  {:ok, _} ->
    {:noreply,
     socket
     |> put_flash(:info, "Two-factor authentication verified.")
     |> redirect(to: ~p"/")}

  {:error, :invalid_code, remaining} ->
    form = to_form(%{"code" => "", "trust" => to_string(trust)}, as: "mfa")

    {:noreply,
     socket
     |> put_flash(:error, "Invalid verification code. #{remaining} attempts remaining.")
     |> assign(totp_form: form)}
end
```

**Apply to Phase 21:** Replace equal-weight tabs with passkey-first state only when `Auth.passkey_count_for_user(user) > 0`; keep visible TOTP and backup fallbacks. Hook success should collect the browser response and then submit/post to the controller completion endpoint; LiveView must not rotate or finalize the session.

---

### `priv/templates/sigra.install/core/session_controller.ex` (controller, request-response)

**Analog:** `priv/templates/sigra.install/core/session_controller.ex`

**Imports pattern** (lines 1-5):
```elixir
defmodule <%= web_module %>.SessionController do
  use <%= web_module %>, :controller

  alias <%= context_module %>, as: Auth
  alias <%= web_module %>.UserAuth
```

**Controller-rendered login pattern** (lines 7-12):
```elixir
def new(conn, _params) do
  email = Phoenix.Flash.get(conn.assigns.flash, :email) || ""
  form = Phoenix.Component.to_form(%{"email" => email}, as: "user")
  magic_link_form = Phoenix.Component.to_form(%{"email" => email}, as: "user")
  render(conn, :new, form: form, magic_link_form: magic_link_form)
end
```

**Terminal session creation pattern** (lines 36-49):
```elixir
defp create(conn, %{"user" => user_params}, info) do
  %{"email" => email, "password" => password} = user_params

  if user = Auth.get_user_by_email_and_password(email, password) do
    conn
    |> put_flash(:info, info)
    |> UserAuth.log_in_user(user, user_params)
  else
    conn
    |> put_flash(:error, "Invalid email or password")
    |> put_flash(:email, String.slice(email, 0, 160))
    |> redirect(to: ~p"/users/log_in")
  end
end
```

**Magic-link fallback pattern** (lines 14-25 and 52-63):
```elixir
case Auth.request_magic_link(email, url_fun) do
  {:ok, _} -> :ok
  {:error, :rate_limited} -> :ok
end

conn
|> put_flash(:info, "If your email is registered, you will receive a magic link shortly.")
|> redirect(to: ~p"/users/log_in")
```

**Apply to Phase 21:** Add POST action(s) for passkey-primary login completion and MFA passkey completion. Both should delegate verification to `Auth` wrappers around `Sigra.Passkeys.authenticate/4`, preserve enumeration-safe error copy, and finish with `UserAuth.log_in_user/3` for login or `delete_session(:mfa_pending)` + redirect for MFA completion.

---

### `priv/templates/sigra.install/core/login_html.ex` (controller template/component, request-response)

**Analog:** `priv/templates/sigra.install/core/login_html.ex`

**Plain-controller form invariant** (lines 5-15):
```elixir
# With no LiveView process on the page, the browser performs a real HTTP POST
# to `SessionController.create/2`.
use <%= web_module %>, :html
```

**Existing fallback forms** (lines 31-66):
```elixir
<.form :let={f} for={@magic_link_form} id="magic_link_form" action={~p"/users/log_in"} method="post">
  <input type="hidden" name="_action" value="magic_link" />
  <.input field={f[:email]} type="email" label="Email" autocomplete="username" required />
  <.button class="btn btn-primary w-full">Send magic link</.button>
</.form>

<.form :let={f} for={@form} id="login_form" action={~p"/users/log_in"} method="post">
  <.input field={f[:email]} type="email" label="Email" autocomplete="username" required />
  <.input field={f[:password]} type="password" label="Password" autocomplete="current-password" required />
  <.button class="btn btn-primary w-full">Log in</.button>
</.form>
```

**Apply to Phase 21:** Keep one identifier field when `:passkey_primary_enabled` is active, with `autocomplete="username webauthn"`. Add explicit `Continue with passkey` primary action and immediate `Use password instead` / magic-link fallbacks. Do not turn login into LiveView.

---

### `priv/templates/sigra.install/core/auth.ex` (service/context, CRUD + request-response)

**Analogs:** `priv/templates/sigra.install/core/auth.ex`, `lib/sigra/passkeys.ex`

**Context imports/config pattern** (`auth.ex` lines 10-15):
```elixir
import Ecto.Query, warn: false
alias <%= repo_module %>, as: Repo
alias <%= context_module %>.<%= schema_alias %>
alias <%= context_module %>.UserToken
alias Sigra.Auth, as: SigraAuth
```

**Config wrapper pattern** (`auth.ex` lines 526-545):
```elixir
def sigra_config do
  Sigra.Config.new!(
    repo: <%= repo_module %>,
    user_schema: <%= schema_alias %>,
    session: [
      store: Sigra.SessionStores.Ecto,
      session_schema: <%= context_module %>.UserSession
    ],
    audit: [
      audit_schema: <%= context_module %>.AuditEvent
    ]
  )
end
```

**MFA wrapper pattern** (`auth.ex` lines 590-639):
```elixir
def mfa_verify(user, code, opts \\ []) do
  Sigra.MFA.verify(sigra_config(), user, code,
    Keyword.merge([mfa_credential_schema: UserMFACredential], opts))
end

def mfa_status(user) do
  Sigra.MFA.status(sigra_config(), user,
    mfa_credential_schema: <%= context_module %>.UserMFACredential,
    backup_code_schema: <%= context_module %>.UserBackupCode
  )
end
```

**Passkey management API pattern** (`lib/sigra/passkeys.ex` lines 119-136 and 156-217):
```elixir
def list_for_user(%Sigra.Config{} = config, user, opts \\ []) do
  validated = NimbleOptions.validate!(opts, @schema_opts)
  schema = resolve_user_passkey_schema!(config, validated)

  from(p in schema, where: p.user_id == ^user.id, order_by: [desc: p.inserted_at])
  |> config.repo.all()
  |> Enum.map(&Credential.from_schema/1)
end

def rename(%Sigra.Config{} = config, user, credential_id, new_nickname, opts \\ []) do
  validated = NimbleOptions.validate!(opts, @rename_opts_schema)
  schema = resolve_user_passkey_schema!(config, validated)

  case get_owned_passkey(config.repo, schema, user.id, credential_id) do
    nil -> {:error, :not_found}
    row -> normalize_mutation_result(config.repo.transact(multi))
  end
end
```

**Passkey authentication pattern** (`lib/sigra/passkeys.ex` lines 138-154):
```elixir
def authenticate(%Sigra.Config{} = config, user, assertion, opts \\ []) do
  validated = NimbleOptions.validate!(opts, @authenticate_opts_schema)
  schema = resolve_user_passkey_schema!(config, validated)

  Sigra.Telemetry.span([:sigra, :passkeys, :authenticate], %{user_id: user.id}, fn ->
    with {:ok, row, auth_data} <-
           Authentication.verify(config, user, assertion, user_passkey_schema: schema) do
      persist_authentication_result(config, row, auth_data, policy)
    end
  end)
end
```

**Apply to Phase 21:** Add generated context wrappers like `passkeys_for_user/1`, `passkey_count_for_user/1`, `rename_passkey/3`, `delete_passkey/2`, `register_passkey/2`, and `authenticate_passkey/2`. Wrappers should pass `user_passkey_schema: <%= context_module %>.UserPasskey` and keep library calls security-critical.

---

### `priv/templates/sigra.install/core/emails.ex` (utility/template, transform)

**Analog:** `priv/templates/sigra.install/core/emails.ex`

**Email builder imports/style pattern** (lines 1-17):
```elixir
defmodule <%= context_module %>.Emails do
  import Swoosh.Email
  use Gettext, backend: <%= web_module %>.Gettext

  @from_address {"<%= app_name %>", "<%= from_email %>"}
  @font_family ~s(-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif)
```

**Security notification shape** (lines 151-221):
```elixir
@doc "Builds a suspicious login notification email."
def suspicious_login_email(user, details) do
  ip = details |> Map.get(:ip, "Unknown") |> html_escape_string()
  device = details |> Map.get(:device, "Unknown device") |> html_escape_string()

  html_content = """
  <p style="margin: 0 0 16px 0; font-size: 20px; font-weight: 600; color: #18181b; line-height: 1.2; font-family: #{@font_family};">
    #{dgettext("sigra", "New Sign-In Detected")}
  </p>
  ...
  """

  base_email(user.email)
  |> subject(dgettext("sigra", "New sign-in to your account"))
  |> html_body(base_layout(html_content))
  |> text_body(text_body)
end
```

**Delivery wrapper pattern** (`priv/templates/sigra.install/core/auth.ex` lines 352-364):
```elixir
email = <%= context_module %>.Emails.confirmation_email(user, url, code)

Sigra.Delivery.deliver(:confirmation, %{
  user_id: user.id,
  to: user.email,
  subject: email.subject,
  body: %{html: email.html_body, text: email.text_body}
}, delivery_opts())
```

**Apply to Phase 21:** Add a passkey-registration notification email using the suspicious-login layout density and security footer posture. Deliver after successful registration through the generated context, with event key and payload following existing `Sigra.Delivery.deliver/3` usage.

---

### `lib/sigra/install/features/core.ex` (generator/config, file-I/O + route injection)

**Analog:** `lib/sigra/install/features/core.ex`

**Template emission pattern** (lines 260-283):
```elixir
defp ui_files(binding, true) do
  otp_app = otp_app_str(binding)
  web = "#{otp_app}_web"

  [
    {:eex, "core/login_html.ex", Path.join(["lib", web, "controllers", "session_html.ex"])},
    {:eex, "core/mfa_challenge_live.ex", Path.join(["lib", web, "live", "mfa_challenge_live.ex"])},
    {:eex, "core/mfa_settings_live.ex", Path.join(["lib", web, "live", "mfa_settings_live.ex"])},
    {:eex, "core/settings_live.ex", Path.join(["lib", web, "live", "settings_live.ex"])}
  ]
end
```

**Route injection pattern** (lines 401-483):
```elixir
mfa_challenge_routes =
  if live? do
    """

        live "/mfa", MFAChallengeLive
    """
  else
    """

        get "/mfa", MFAChallengeController, :new
        post "/mfa", MFAChallengeController, :create
    """
  end

content = """
  scope "/users", #{web_module} do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/log_in", SessionController, :new
    post "/log_in", SessionController, :create
  end
"""
```

**Apply to Phase 21:** Add any new passkey completion POST route(s) to the same router injection, preserving controller-owned login routes. Avoid adding `Features.Passkeys` references to Core unless the existing isolation tests are intentionally updated, because Core currently documents a zero-reference invariant.

---

### `priv/templates/sigra.install/passkeys/passkey_hooks.js` (client hook, event-driven)

**Analog:** `priv/templates/sigra.install/passkeys/passkey_hooks.js`

**Imports pattern** (lines 1-6):
```javascript
import {
  WebAuthnAbortService,
  WebAuthnError,
  startAuthentication,
  startRegistration,
} from "./passkey_browser"
```

**Hook lifecycle/event contract** (lines 28-66):
```javascript
this.handleEvent(startEvent, async (payload = {}) => {
  this.cancelPasskeyCeremony("superseded", false)

  const operationId = this.__sigraPasskeyOperationId + 1
  const abortController = new AbortController()

  try {
    const response = await startCeremony(payload.options, abortController.signal)

    if (!this.isLatestPasskeyOperation(operationId) || abortController.signal.aborted) {
      return
    }

    this.pushEvent(successEvent, { response: toPlainObject(response) })
  } catch (error) {
    if (abortController.signal.aborted || isCeremonyAbort(error)) {
      this.pushEvent(abortedEvent, { reason: "aborted" })
    } else {
      this.pushEvent(errorEvent, normalizeError(error))
    }
  }
})
```

**Teardown pattern** (lines 69-92):
```javascript
destroyed() {
  this.cancelPasskeyCeremony("destroyed")
},

disconnected() {
  this.cancelPasskeyCeremony("disconnected")
},
```

**Apply to Phase 21:** Reuse event names exactly: `sigra:passkey-register:*` and `sigra:passkey-authenticate:*`. LiveView should push the start event on explicit CTA click, not on mount. Map `aborted` to neutral copy.

---

### `priv/templates/sigra.install/passkeys/passkey_browser.js` (client utility, event-driven transform)

**Analog:** `priv/templates/sigra.install/passkeys/passkey_browser.js`

**Serialization pattern** (lines 52-77):
```javascript
function serializeCredential(credential) {
  const response = credential.response

  return {
    id: credential.id,
    rawId: base64UrlEncode(new Uint8Array(credential.rawId)),
    type: credential.type,
    authenticatorAttachment: credential.authenticatorAttachment || null,
    response: {
      clientDataJSON: base64UrlEncode(new Uint8Array(response.clientDataJSON)),
      authenticatorData: response.authenticatorData
        ? base64UrlEncode(new Uint8Array(response.authenticatorData))
        : null,
      signature: response.signature
        ? base64UrlEncode(new Uint8Array(response.signature))
        : null
    },
    clientExtensionResults: credential.getClientExtensionResults(),
  }
}
```

**Browser ceremony pattern** (lines 87-124):
```javascript
export async function startRegistration({ optionsJSON, signal }) {
  try {
    const credential = await navigator.credentials.create({
      publicKey: {
        ...optionsJSON,
        challenge: toUint8Array(optionsJSON.challenge),
        user: { ...optionsJSON.user, id: toUint8Array(optionsJSON.user.id) },
      },
      signal,
    })

    return serializeCredential(credential)
  } catch (error) {
    throw normalizeAbort(error)
  }
}
```

**Apply to Phase 21:** If conditional UI/autofill support is added, extend this helper rather than duplicating raw `navigator.credentials.get()` logic in templates. Preserve normalized errors so UI never displays raw `NotAllowedError` / `AbortError`.

---

### `priv/templates/sigra.install/passkeys/aaguids.json` or equivalent generated helper (config/data utility, transform)

**Analog:** no direct data-registry analog. Partial analog: `lib/sigra/install/features/passkeys.ex`

**Feature-owned file emission pattern** (`lib/sigra/install/features/passkeys.ex` lines 19-29):
```elixir
def files(binding) do
  otp_app = Keyword.fetch!(binding, :otp_app) |> to_string()
  context_slug = binding |> Keyword.get(:context_alias, "Accounts") |> Macro.underscore()

  [
    {:eex, "passkeys/user_passkey.ex",
     Path.join(["lib", otp_app, context_slug, "user_passkey.ex"])},
    {:eex, "passkeys/passkey_browser.js", Path.join(["assets", "js", "passkey_browser.js"])},
    {:eex, "passkeys/passkey_hooks.js", Path.join(["assets", "js", "passkey_hooks.js"])}
  ]
end
```

**Apply to Phase 21:** If the planner chooses a vendored AAGUID registry, put ownership under the passkeys feature or generated auth context, not under Core unless isolation tests are updated. Treat the registry as display-only metadata: nickname > AAGUID name > device hint > `"Passkey"`.

---

### `test/sigra/install/generator_mfa_test.exs` (test, batch/assertion)

**Analog:** `test/sigra/install/generator_mfa_test.exs`

**Template-rendering pattern** (lines 1-25 and 57-95):
```elixir
defmodule Sigra.Install.GeneratorMFATest do
  use ExUnit.Case, async: true

  @template_dir Path.join([File.cwd!(), "priv", "templates", "sigra.install", "core"])

  describe "mfa_challenge_controller.ex template" do
    test "contains create action" do
      content = render_template("mfa_challenge_controller.ex")
      assert content =~ "def create(conn, %{\"mfa\" => mfa_params})"
    end

    test "handles both TOTP and backup verification methods" do
      content = render_template("mfa_challenge_controller.ex")
      assert content =~ "Auth.mfa_verify(user, code)"
      assert content =~ "Auth.mfa_verify_backup(user, code)"
    end
  end
end
```

**Route assertion pattern** (lines 243-261):
```elixir
test "generator has MFA challenge LiveView route" do
  source = File.read!(@features_core_path)
  assert source =~ ~s(live "/mfa", MFAChallengeLive)
end

test "generator injects require_mfa into authenticated pipeline" do
  source = File.read!(@features_core_path)
  assert source =~ "plug :require_mfa"
end
```

**Apply to Phase 21:** Add assertions for passkey CTA copy, fallback copy, `phx-hook="PasskeyAuthenticate"`/`PasskeyRegister`, POST completion route, context wrappers, and no raw browser exception names in user-facing template copy.

---

### `test/sigra/install/features/passkeys_js_test.exs` (test, batch + event-driven JS)

**Analog:** `test/sigra/install/features/passkeys_js_test.exs`

**Asset wiring assertions** (lines 33-49):
```elixir
test "injects a marker-wrapped merged hooks block into the standard Phoenix app.js shape" do
  %{app_dir: app_dir} = setup_tmp_app_with_standard_app_js!()

  assert {:ok, _stdout} = InstallFixture.run_sigra_install(app_dir, ["--passkeys"])

  app_js = InstallFixture.read_asset_file(app_dir, "js/app.js")
  browser_helper = InstallFixture.read_asset_file(app_dir, "js/passkey_browser.js")

  assert app_js =~ @passkey_start_marker
  assert app_js =~ @passkey_import
  assert app_js =~ @passkey_hooks_line
  assert browser_helper =~ "startRegistration"
  assert browser_helper =~ "startAuthentication"
end
```

**Runtime hook test pattern** (lines 104-196):
```elixir
test "destroyed teardown emits a single aborted event for the active ceremony" do
  if node = System.find_executable("node") do
    tmp_dir = Path.join(System.tmp_dir!(), "sigra_passkey_hooks_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)

    template_source = File.read!("priv/templates/sigra.install/passkeys/passkey_hooks.js")
    module_source = String.replace(template_source, ~s(from "./passkey_browser"), ~s(from "./browser_stub.mjs"))

    {stdout, 0} = System.cmd(node, [Path.join(tmp_dir, "runner.mjs")], stderr_to_stdout: true)
    events = Jason.decode!(stdout)

    assert events == [
      %{"event" => "sigra:passkey-register:aborted", "payload" => %{"reason" => "destroyed"}}
    ]
  else
    flunk("node executable is required for passkey hook runtime coverage")
  end
end
```

**Apply to Phase 21:** Extend JS tests if helper changes for conditional mediation/autofill. Keep tests executable through Node stubs rather than requiring real WebAuthn hardware.

## Shared Patterns

### Controller-Owned Auth Completion
**Source:** `priv/templates/sigra.install/core/session_controller.ex` lines 36-49 and `priv/templates/sigra.install/core/user_auth.ex` lines 47-72  
**Apply to:** `session_controller.ex`, login passkey completion, MFA passkey completion
```elixir
conn
|> put_flash(:info, info)
|> UserAuth.log_in_user(user, user_params)
```

```elixir
def log_in_user(conn, user, params \\ %{}) do
  token = <%= context_module %>.generate_user_session_token(user, ip: ip, user_agent: user_agent)

  conn
  |> renew_session()
  |> put_token_in_session(token)
  |> maybe_write_remember_me_cookie(token, params)
  |> redirect(to: user_return_to || signed_in_path(conn))
end
```

### Sudo/Reverification Boundary
**Source:** `lib/sigra/plug/require_sudo.ex` lines 57-74 and `priv/templates/sigra.install/core/sudo_controller.ex` lines 24-42  
**Apply to:** passkey enrollment and delete routes/actions
```elixir
cond do
  is_nil(conn.assigns[:current_scope]) ->
    conn |> error_handler.auth_error(:unauthenticated, opts) |> Plug.Conn.halt()

  sudo_fresh?(conn, sudo_window) ->
    conn

  true ->
    conn |> error_handler.auth_error(:stale_sudo, opts) |> Plug.Conn.halt()
end
```

```elixir
case Sigra.Crypto.verify_password(password, user.hashed_password) do
  true ->
    session = conn.private[:sigra_session]
    <%= context_module %>.confirm_sudo(session.hashed_token)

    conn
    |> put_flash(:info, "Password confirmed.")
    |> redirect(to: safe_return_to)
end
```

### LiveView Recoverable State
**Source:** `priv/templates/sigra.install/core/mfa_settings_live.ex` lines 410-423, 467-472, 570-593  
**Apply to:** enrollment UI, passkey rename/delete UI, passkey recovery messages
```elixir
def handle_event("begin_enrollment", _params, socket) do
  user = socket.assigns.current_scope.user

  case Auth.mfa_enroll(account: user.email) do
    {:ok, enrollment} ->
      {:noreply,
       assign(socket,
         enrollment_step: :qr,
         svg: enrollment.svg,
         base32_secret: enrollment.secret,
         raw_secret: enrollment.raw_secret
       )}
  end
end
```

### Passkey Library Wrappers
**Source:** `lib/sigra/passkeys.ex` lines 119-217  
**Apply to:** generated `Auth` context passkey wrappers and LiveViews
```elixir
def count_for_user(%Sigra.Config{} = config, user, opts \\ []) do
  validated = NimbleOptions.validate!(opts, @schema_opts)
  schema = resolve_user_passkey_schema!(config, validated)

  from(p in schema, where: p.user_id == ^user.id)
  |> config.repo.aggregate(:count)
end
```

### Error Copy Must Be Mapped
**Source:** `priv/templates/sigra.install/passkeys/passkey_hooks.js` lines 100-110 and `priv/templates/sigra.install/passkeys/passkey_browser.js` lines 79-85  
**Apply to:** MFA challenge, login page, management enrollment
```javascript
function normalizeError(error) {
  return {
    name: error?.name || "Error",
    message: error?.message || "Passkey ceremony failed",
    code: error?.code || null,
  }
}
```

Map these normalized client errors to user-facing recovery states. Do not render `error.name`, raw exception names, or raw browser messages in HEEx.

### Generated Template Tests
**Source:** `test/sigra/install/generator_mfa_test.exs` lines 134-209  
**Apply to:** all template changes in Phase 21
```elixir
content = render_template("mfa_challenge_live.ex")
assert content =~ "phx-submit"
assert content =~ "Trust this browser for 30 days"
```

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `priv/templates/sigra.install/passkeys/aaguids.json` or equivalent generated helper | config/data utility | transform | No existing vendored display-metadata registry exists. Use `Features.Passkeys.files/1` as the generator pattern and keep data display-only. |

## Metadata

**Analog search scope:** `lib/`, `priv/templates/`, `test/`, `test/example/`  
**Files scanned:** 220+ via `rg --files lib priv test` plus targeted reads  
**Pattern extraction date:** 2026-04-15
