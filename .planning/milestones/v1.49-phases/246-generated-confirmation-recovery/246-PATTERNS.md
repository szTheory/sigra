# Phase 246: Generated Confirmation Recovery - Pattern Map

**Mapped:** 2026-10-06  
**Files analyzed:** 16 planned/new or modified files  
**Analogs found:** 16 / 16 (several are closest infrastructure analogs, not feature-identical)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/sigra/install/features/core.ex` | route | request-response | `lib/sigra/install/features/core.ex` route injection | exact |
| `lib/sigra/auth.ex` | service | CRUD | `priv/templates/sigra.install/core/user_token.ex` scoped query + current verifier | role-match; current lookup is defective |
| `priv/templates/sigra.install/core/confirmation_live.ex` | component | request-response | same generated LiveView | exact; current lifecycle needs correction |
| `priv/templates/sigra.install/core/auth.ex` | service | CRUD | same generated context wrapper | exact |
| `priv/templates/sigra.install/core/user_token.ex` | model | CRUD | same confirmation-code query | exact; already scoped |
| `priv/templates/sigra.install/core/user_auth.ex` | middleware | request-response | same optional-scope mount callback | exact; reuse as-is |
| `priv/templates/sigra.install/core/sigra_auth_components.ex` | component | transform | same `sigra_auth_page` component | exact |
| `priv/templates/sigra.install/core/sigra_auth.css` | config | transform | existing success/danger status classes in same stylesheet | exact |
| `priv/templates/sigra.install/core/emails.ex` | service | request-response | same confirmation email builder | exact; displayed spacing is its contract |
| `scripts/ci/generated-confirmation-probe.exs` | test | request-response | `scripts/ci/install-smoke.sh` generated-host probe plus `test/sigra/install/features/core_test.exs` | role-match |
| `test/sigra/auth_test.exs` | test | CRUD | same library auth test module | exact |
| `test/sigra/install/auth_ui_contract_test.exs` | test | transform | `test/sigra/install/generator_email_test.exs` template assertions | role-match |
| `test/sigra/install/generated_confirmation_ci_contract_test.exs` | test | batch | existing generated-admin CI route in `.github/workflows/ci.yml` | role-match |
| generated host `test/generated_confirmation_probe_test.exs` | test | CRUD | `scripts/ci/install-smoke.sh` generated-host test probe | role-match |
| `test/example/priv/playwright/tests/generated-confirmation.spec.ts` | test | request-response | `test/example/priv/playwright/tests/passkey-login.spec.ts` | role-match |
| `scripts/ci/admin-acceptance-smoke.sh` / `.github/workflows/ci.yml` | config | batch | existing generated-admin fresh-host browser job and required ci-gate edge | exact |

## Pattern Assignments

### `lib/sigra/install/features/core.ex` (route, request-response)

**Analog:** `lib/sigra/install/features/core.ex`

The confirmation route strings are built separately from the router scope that inserts them. Keep that feature-generation structure, but place the LiveView routes in a scope using the browser pipeline and optional current scope, outside the signed-in redirect hook.

**Route generation** (lines 370-384):
```elixir
confirmation_routes =
  if live? do
    """

        live "/confirm", ConfirmationLive
        live "/confirm/:token", ConfirmationLive, :confirm
    """
  else
    """

        get "/confirm", ConfirmationController, :new
        post "/confirm", ConfirmationController, :create
        get "/confirm/:token", ConfirmationController, :confirm
        post "/confirm/resend", ConfirmationController, :resend
    """
  end
```

**Scope placement to change** (lines 500-510):
```elixir
scope "/users", #{web_module} do
  pipe_through [:browser, :redirect_if_user_is_authenticated]

  get "/log_in", SessionController, :new
  #{live_routes}
  post "/log_in", SessionController, :create
  get "/log_in/:token", SessionController, :magic_link
  #{confirmation_routes}
end
```

Move only the LiveView confirmation route insertion to the optional-scope scope. The current grouping is why signed-in link visitors are redirected; keep the non-LiveView route decision bounded to explicit requirements.

---

### `priv/templates/sigra.install/core/confirmation_live.ex` (component, request-response)

**Analog:** `priv/templates/sigra.install/core/confirmation_live.ex`

This file is the direct behavior and markup seam. Preserve the generated `sigra_auth_page`, localized Gettext labels, `to_form` shape, and explicit submit affordance. Do not preserve the existing GET mutation, hard dereference of optional scope, six-character browser limit, or six-digit auto-submit behavior.

**Imports and shared form markup** (lines 11-16, 31-53):
```elixir
use <%= web_module %>, :live_view
import <%= web_module %>.SigraAuthComponents
use Gettext, backend: <%= web_module %>.Gettext
alias <%= context_module %>, as: Auth
```
```heex
<.form for={@form} id="confirmation_form" phx-change="validate" phx-submit="confirm">
  <.input field={@form[:code]} type="text"
    label={dgettext("sigra", "Confirmation code")}
    inputmode="numeric" autocomplete="one-time-code"
    aria-label={dgettext("sigra", "Confirmation code")} required />
  <.sigra_auth_button phx-disable-with={dgettext("sigra", "Confirming...")}>
    {dgettext("sigra", "Confirm email")}
  </.sigra_auth_button>
</.form>
```

**Current GET mutation and event dispatch (diagnostic only)** (lines 99-120, 127-145):
```elixir
def handle_params(%{"token" => token}, _uri, socket) do
  _user = socket.assigns.current_scope.user
  case Auth.confirm_user(token) do
    {:ok, _user} -> {:noreply, socket |> put_flash(:info, ...) |> redirect(to: ~p"/")}
    {:error, :already_confirmed} -> {:noreply, assign(socket, live_action: :already_confirmed)}
    {:error, :token_expired} -> {:noreply, assign(socket, live_action: :expired)}
    {:error, :token_invalid} -> {:noreply, socket |> put_flash(:error, ...) |> assign(live_action: :new)}
  end
end
```
Implement parameter handling as display-only state assignment; make a separate submit event call `Auth.confirm_user/1`. For code and resend events, pattern-match or safely inspect optional scope and return localized sign-in guidance when absent. Derive `user` exclusively from `socket.assigns.current_scope`.

**Existing code handling (diagnostic only)** (lines 162-179):
```elixir
defp do_confirm(socket, code) do
  user = socket.assigns.current_scope.user
  case Auth.confirm_user_by_code(user, code) do
    {:ok, _user} -> {:noreply, socket |> put_flash(:info, ...) |> redirect(to: ~p"/")}
    {:error, :invalid_code} ->
      form = to_form(%{"code" => ""}, as: "confirmation")
      {:noreply, socket |> put_flash(:error, ...) |> assign(form: form)}
  end
end
```
Retain the localized result vocabulary and retryable form update while replacing event-only flash feedback with rendered shared feedback. Normalize exactly the permitted email separator before strict ASCII validation and before calling the verifier.

---

### `priv/templates/sigra.install/core/user_auth.ex` (middleware, request-response)

**Analog:** `priv/templates/sigra.install/core/user_auth.ex`

**Optional scope hook** (lines 317-320):
```elixir
def on_mount(:mount_current_scope, _params, session, socket) do
  {:cont, mount_current_scope(socket, session)}
end
```
Use this hook for the public confirmation LiveView so anonymous mounts receive a nil scope and signed-in mounts preserve their current identity. Add explicit guards at code/resend event time; do not use `:ensure_authenticated` for the link route.

**Required scope behavior to avoid here** (lines 321-344) is the existing authentication and signed-in redirect hooks. Those hooks halt or redirect based on the current scope, which conflicts with a link that must work for either session state.

---

### `priv/templates/sigra.install/core/auth.ex` + `lib/sigra/auth.ex` (service, CRUD)

**Analog:** `priv/templates/sigra.install/core/auth.ex`; related query in `priv/templates/sigra.install/core/user_token.ex`

**Generated wrapper** (`auth.ex`, lines 408-417):
```elixir
def confirm_user_by_code(%<%= schema_alias %>{} = user, code) when is_binary(code) do
  Sigra.Auth.verify_confirmation_code(Repo, code,
    user_id: user.id,
    user_schema: <%= schema_alias %>,
    user_token_schema: UserToken
  )
end
```

Keep passing the account ID from the server-side user argument, not request parameters. In `lib/sigra/auth.ex`, preserve the existing per-user rate-limit key (`lib/sigra/auth.ex:971-984`) and atomic confirmed-at/token cleanup transaction (`:992-1005` onward). The current token fetch at lines 985-990 uses only token hash and context; replace it with the generated schema's account-scoped query below and preserve invalid-code behavior on no result.

**Scoped query already generated** (`user_token.ex`, lines 156-168):
```elixir
def verify_confirmation_code_query(code, user_id) do
  hashed_code = Sigra.Token.hash_token(code)
  query =
    from token in __MODULE__,
      join: user in assoc(token, :user),
      where: token.token == ^hashed_code,
      where: token.context == "confirm_code",
      where: token.user_id == ^user_id,
      where: token.inserted_at > ago(@confirm_validity_in_days, "day"),
      select: user
  {:ok, query}
end
```

This is the strongest implementation pattern for CONF-02: lookup and account binding must happen before the existing transaction mutates user state. The `user_token.ex` query itself is already correct; it may need no source change.

---

### `priv/templates/sigra.install/core/sigra_auth_components.ex` + `sigra_auth.css` (component/config, transform)

**Analog:** `priv/templates/sigra.install/core/sigra_auth_components.ex`

**Shared page insertion point** (lines 27-50):
```heex
<main class={["sigra-auth", @class]} data-theme={@theme} style={@style} {@rest}>
  <section class="sigra-auth__viewport">
    <div class="sigra-auth__panel">
      <div class="sigra-auth__brand">...</div>
      {render_slot(@inner_block)}
      <footer :if={@branding.support_url || @branding.privacy_url || @branding.terms_url}>
        ...
      </footer>
    </div>
  </section>
</main>
```
Render shared flash/status content within the panel alongside the slot, using localized text and existing neutral component vocabulary. Keep the theme and brand assignments intact.

Existing status classes are `sigra-auth-status--success` and `sigra-auth-status--danger` in `priv/templates/sigra.install/core/sigra_auth.css:250-284,360-362`. Reuse these; expose success with `role="status"` and validation feedback with alert/live-region semantics, without setting focus. No new analog is needed for stylesheet structure.

---

### `priv/templates/sigra.install/core/emails.ex` (service, request-response)

**Analog:** `priv/templates/sigra.install/core/emails.ex`

The generated email is the canonical copied-code representation. Lines 19-22 format the value using `String.graphemes(code) |> Enum.join(" ")`; keep the field contract aligned with that exact ASCII-space separator. Do not change the email to make the input's old six-character constraint appear valid.

---

### Tests and generated-host proof (test, request-response / CRUD)

**ExUnit analogs:** `test/sigra/install/features/core_test.exs`, `test/sigra/install/generator_email_test.exs`, and existing `test/sigra/auth_test.exs`.

`core_test.exs` is a pure feature-generation contract test (module setup and binding at lines 1-35); `generator_email_test.exs` reads generated templates and asserts emitted markup. Use those for generator output and feedback semantics. `auth_test.exs` is the closest library integration test for scoped code lookup and persistence; extend it with A-code/B-scope rejection and stored `confirmed_at` assertions. New LiveView/integration coverage should use actual mount + event behavior and persisted state, not only generated source strings.

**Playwright analog:** `test/example/priv/playwright/tests/passkey-login.spec.ts` lines 1-8 and 24-38:
```typescript
async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector("[data-phx-session].phx-connected", { state: "attached" });
}

const confirmHref = await extractConfirmationLink(page, email);
const confirmUrl = new URL(confirmHref, page.url());
await page.goto(`${appOrigin}${confirmUrl.pathname}${confirmUrl.search}${confirmUrl.hash}`);
```
Reuse mailbox extraction and the LiveView-connected readiness signal. For this phase, prefer role/label selectors and Playwright retrying assertions; browser scenario must paste the literal spaced clipboard value and assert visible status/error then retry. Keep target origin and fresh-host lifecycle aligned with install-smoke.

**Fresh-host and CI analogs:** `scripts/ci/install-smoke.sh:43-80` generates a disposable Phoenix host, installs Sigra, and compiles it for the persisted-state probe. `scripts/ci/admin-acceptance-smoke.sh` already boots a separate freshly generated host with Playwright in the required generated-admin job; `.github/workflows/ci.yml` carries both that job and `install_smoke` into ci-gate. Add the narrow browser target to the running generated-admin host and retain diagnostics identifying its failed step.

## Shared Patterns

### Optional current scope

**Source:** `priv/templates/sigra.install/core/user_auth.ex:317-320`  
**Apply to:** confirmation route's LiveView session; code/resend handlers must branch safely when scope is nil.

### Account-bound single-use verification

**Source:** `priv/templates/sigra.install/core/user_token.ex:156-168` plus the transaction in `lib/sigra/auth.ex:992-1005` and subsequent token cleanup.  
**Apply to:** code verification; use the current-scope ID for query and rate-limit identity. Keep transaction/account/token behavior; never trust a client target ID.

### Localized visible feedback

**Source:** `priv/templates/sigra.install/core/confirmation_live.ex:166-183`, `sigra_auth_components.ex:27-50`, and `sigra_auth.css:250-284,360-362`.  
**Apply to:** confirmation success, invalid code, anonymous code/resend guidance. Render semantics in the shared auth page and keep invalid entry retryable.

### Deterministic browser readiness

**Source:** `test/example/priv/playwright/tests/passkey-login.spec.ts:4-8`.  
**Apply to:** generated-host Chromium scenario; use accessible locators and live readiness, no fixed sleeps.

## No Analog Found

No analogous generated-host confirmation Playwright spec or focused LiveView confirmation integration test exists. Use the closest listed test harnesses as scaffolding; requirements for anonymous and signed-in state, account binding, clipboard paste, and status announcements are new.

## Metadata

**Analog search scope:** `lib/sigra`, `priv/templates/sigra.install/core`, `test/sigra`, `test/example/priv/playwright`, `scripts/ci`, `.github/workflows`  
**Tracked-source gate:** all named analog paths were checked with `git ls-files`; no ignored runtime mirror paths are referenced.  
**Pattern extraction date:** 2026-10-06
