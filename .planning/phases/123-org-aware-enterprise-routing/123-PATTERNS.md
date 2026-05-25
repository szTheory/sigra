# Phase 123: Org-Aware Enterprise Routing - Pattern Map

**Mapped:** 2026-05-25
**Files analyzed:** 11
**Analogs found:** 11 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/enterprise_routing.ex` | service | request-response | `lib/sigra/enterprise_connections.ex` | role-match |
| `lib/sigra/oauth.ex` | service | request-response | `lib/sigra/oauth.ex` | exact |
| `lib/sigra/oauth/callback.ex` | service | request-response | `lib/sigra/oauth/callback.ex` | exact |
| `test/example/lib/example_web/controllers/enterprise_sso_controller.ex` | controller | request-response | `test/example/lib/example_web/controllers/session_controller.ex` | role-match |
| `test/example/lib/example_web/controllers/session_html.ex` | component | request-response | `test/example/lib/example_web/controllers/session_html.ex` | exact |
| `test/example/lib/example_web/router.ex` | route | request-response | `test/example/lib/example_web/router.ex` | exact |
| `test/sigra/enterprise_routing_test.exs` | test | request-response | `test/sigra/enterprise_connections/context_test.exs` | role-match |
| `test/sigra/oauth/callback_test.exs` | test | request-response | `test/sigra/oauth/callback_test.exs` | exact |
| `test/sigra/oauth/oauth_test.exs` | test | request-response | `test/sigra/oauth/oauth_test.exs` | exact |
| `test/example/test/example_web/controllers/enterprise_sso_controller_test.exs` | test | request-response | `test/example/test/example_web/controllers/session_controller_test.exs` | role-match |
| `test/example/test/example_web/controllers/session_controller_test.exs` | test | request-response | `test/example/test/example_web/controllers/session_controller_test.exs` | exact |

## Pattern Assignments

### `lib/sigra/enterprise_routing.ex` (service, request-response)

**Primary analog:** `lib/sigra/enterprise_connections.ex`

**Related references:** `lib/sigra/plug/load_organization_from_slug.ex`, `lib/sigra/auth.ex`

**Imports/config pattern** (`lib/sigra/enterprise_connections.ex:7-16`):
```elixir
alias Sigra.EnterpriseConnections.Validation

@type config :: %{
        required(:repo) => module(),
        required(:schemas) => %{required(:enterprise_connection) => module()},
        optional(:http_client) => function()
      }
```

**Org-bound core pattern** (`lib/sigra/enterprise_connections.ex:18-39`):
```elixir
def get_connection(config, scope) do
  with {:ok, org_id} <- active_organization_id(scope) do
    config.repo.get_by(connection_schema(config), organization_id: org_id)
  else
    _ -> nil
  end
end

def save_connection(config, scope, attrs) do
  connection = get_connection(config, scope) || struct(connection_schema(config))

  connection
  |> connection_schema(config).changeset(draft_attrs(scope, attrs))
  |> persist(config)
end
```

**Normalization pattern to copy for discovery input** (`lib/sigra/auth.ex:73-79`):
```elixir
def normalize_email(email) when is_binary(email) do
  email |> String.trim() |> String.downcase()
end
```

**Fail-closed routing/error pattern** (`lib/sigra/plug/load_organization_from_slug.ex:47-76`):
```elixir
cond do
  is_nil(scope) or is_nil(scope.user) ->
    halt_not_found(conn, error_handler, opts)

  is_nil(slug) ->
    halt_not_found(conn, error_handler, opts)

  true ->
    case resolve(config, scope, slug) do
      {:ok, org, membership} ->
        conn
        |> assign_scope(org, membership, opts)
        |> maybe_refresh_session_pointer(scope, org, opts)

      {:redirect, new_slug} ->
        conn
        |> redirect_to_canonical(slug, new_slug)
        |> Plug.Conn.halt()

      :not_found ->
        halt_not_found(conn, error_handler, opts)
    end
end
```

**What to copy:** keep the public API explicit and org/connection-centric. Discovery may accept email, but returned tuples should already contain the resolved organization and connection ids, never a domain-only intermediate contract.

---

### `lib/sigra/oauth.ex` (service, request-response)

**Analog:** `lib/sigra/oauth.ex`

**Authorize/state pattern** (`lib/sigra/oauth.ex:63-97`, `430-449`):
```elixir
def authorize_url(config, provider, opts \\ []) do
  provider_config = get_provider_config(config, provider)

  case Strategies.resolve(provider, provider_config || []) do
    {:error, :unknown_provider} ->
      {:error, :unknown_provider}

    strategy_module ->
      Telemetry.span([:sigra, :oauth, :authorize], %{provider: provider}, fn ->
        do_authorize_url(config, strategy_module, provider, provider_config, opts)
      end)
  end
end

defp do_authorize_url(config, strategy_module, provider, provider_config, _opts) do
  case strategy_module.authorize_url(provider_config) do
    {:ok, %{url: url, session_params: assent_session}} ->
      state = generate_state(config.secret_key_base, provider)
      new_url = replace_url_state(url, state)

      session_params =
        %{sigra_state: state}
        |> maybe_put(:code_verifier, Map.get(assent_session, :code_verifier))

      {:ok, new_url, session_params}
```

**Callback verification pattern** (`lib/sigra/oauth.ex:136-156`, `471-487`):
```elixir
with :ok <- verify_state(params, session_params, config.secret_key_base) do
  provider_config = get_provider_config(config, provider) || []

  case Strategies.resolve(provider, provider_config) do
    {:error, :unknown_provider} ->
      {:error, %OAuthError{provider: provider, error_code: :provider_error}}

    strategy_module ->
      assent_session = extract_assent_session(session_params)
      strategy_module.callback(provider_config, params, assent_session)
  end
end

defp verify_state(params, session_params, secret_key_base) do
  state = params["state"] || params[:state]
  stored_state = session_params[:sigra_state] || session_params["sigra_state"]
```

**Audit failure pattern** (`lib/sigra/oauth.ex:161-181`):
```elixir
{:error, %OAuthError{} = err} ->
  Sigra.Audit.log_safe(
    "oauth.callback.failure",
    nil,
    Keyword.merge(audit_opts,
      actor_id: nil,
      target_id: nil,
      outcome: "failure",
      metadata: %{provider: to_string(provider), reason: Atom.to_string(err.error_code)}
    )
  )
```

**What to copy:** extend the signed state payload instead of inventing a second enterprise session contract. Enterprise metadata should travel in the same ceremony as `sigra_state`, PKCE, and callback verification.

---

### `lib/sigra/oauth/callback.ex` (service, request-response)

**Analog:** `lib/sigra/oauth/callback.ex`

**Entry classification pattern** (`lib/sigra/oauth/callback.ex:53-76`):
```elixir
def process_callback(config, provider, user_info, token) do
  email = user_info["email"]

  if is_nil(email) or email == "" do
    Logger.error("OAuth callback for #{provider}: provider returned no email")
    {:error, %OAuthError{provider: provider, error_code: :no_email}}
  else
    provider_str = to_string(provider) |> String.downcase()
    provider_uid = to_string(user_info["sub"])

    do_process(config, provider, provider_str, provider_uid, user_info, token)
  end
end
```

**Branching pattern** (`lib/sigra/oauth/callback.ex:76-99`):
```elixir
identity = repo.get_by(identity_schema, provider: provider_str, provider_uid: provider_uid)

cond do
  identity != nil ->
    handle_existing_identity(config, repo, identity, user_info, token, provider)

  true ->
    email = user_info["email"]
    existing_user = repo.get_by(user_schema, email: email)

    if existing_user do
      {:link_confirmation_required,
       %{provider: provider, provider_uid: user_info["sub"], email: email}}
    else
      register_oauth_user(config, provider, provider_str, user_info, token)
    end
end
```

**Transactional success pattern** (`lib/sigra/oauth/callback.ex:139-181`, `192-278`):
```elixir
multi =
  Multi.new()
  |> Multi.update(:identity, changeset)
  |> Audit.log_multi_safe(...)
  |> Audit.log_multi_safe(...)

case repo.transaction(multi) do
  {:ok, changes} ->
    Audit.emit_telemetry_from_changes(changes, [...])
    session_metadata = build_session_metadata(config, provider)
    {:ok, :logged_in, user, session_metadata}
```

**What to copy:** handle enterprise callback revalidation as another explicit pre-session branch before user/session attribution. Keep the return tuples narrow and composable so the controller can render retry UI without owning security logic.

---

### `test/example/lib/example_web/controllers/enterprise_sso_controller.ex` (controller, request-response)

**Primary analog:** `test/example/lib/example_web/controllers/session_controller.ex`

**Related references:** `test/example/lib/example_web/controllers/organization_switch_controller.ex`

**Imports/alias pattern** (`test/example/lib/example_web/controllers/session_controller.ex:1-5`):
```elixir
defmodule ExampleWeb.SessionController do
  use ExampleWeb, :controller

  alias Example.Accounts, as: Auth
  alias ExampleWeb.UserAuth
```

**Form-entry render pattern** (`test/example/lib/example_web/controllers/session_controller.ex:26-35`):
```elixir
def new(conn, _params) do
  email = Phoenix.Flash.get(conn.assigns.flash, :email) || ""
  form = Phoenix.Component.to_form(%{"email" => email}, as: "user")

  render(conn, :new,
    form: form,
    magic_link_form: magic_link_form,
    passkey_primary_enabled: Auth.passkey_primary_enabled?()
  )
end
```

**POST action + tuple branch pattern** (`test/example/lib/example_web/controllers/organization_switch_controller.ex:24-52`):
```elixir
def update(conn, %{"organization_id" => org_id} = params) do
  scope = conn.assigns.current_scope
  return_to = safe_return_to(Map.get(params, "return_to"))

  case fetch_member_org(scope, org_id) do
    {:ok, org} ->
      ...

    :error ->
      conn
      |> put_status(:not_found)
      |> put_view(html: ExampleWeb.ErrorHTML)
      |> render(:"404")
      |> halt()
  end
end
```

**What to copy:** keep this controller thin. It should fetch org/connection context from library code, render lightweight org-truth copy, persist session params, and redirect. Any domain matching, availability checks, or callback binding belongs in `lib/sigra/*`.

---

### `test/example/lib/example_web/controllers/session_html.ex` (component, request-response)

**Analog:** `test/example/lib/example_web/controllers/session_html.ex`

**Template structure pattern** (`test/example/lib/example_web/controllers/session_html.ex:17-46`, `124-166`):
```elixir
def new(assigns) do
  ~H"""
  <div class="mx-auto max-w-sm">
    <.header>
      Log in
      <:subtitle>
        Don't have an account?
        <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
          Sign up
        </.link>
      </:subtitle>
    </.header>
```

**Separate form-assign pattern** (`test/example/lib/example_web/controllers/session_html.ex:11-16`, `69-82`, `124-136`):
```elixir
Two separate form assigns (`@form` and `@magic_link_form`) isolate
validation/flash state so an error on one form does not corrupt the
other.
```

**What to copy:** add the enterprise discovery form as a sibling path on the existing login page, not a replacement. Keep the enterprise CTA visually separate from password and magic-link flows so failure stays in the same mode.

---

### `test/example/lib/example_web/router.ex` (route, request-response)

**Analog:** `test/example/lib/example_web/router.ex`

**Scope/pipeline pattern for login entry** (`test/example/lib/example_web/router.ex:99-121`):
```elixir
scope "/users", ExampleWeb do
  pipe_through [:browser, :redirect_if_user_is_authenticated]

  get "/log_in", SessionController, :new
  post "/log_in", SessionController, :create
  post "/log_in/passkey", SessionController, :complete_passkey
  get "/log_in/:token", SessionController, :magic_link
end
```

**Org-scoped route pattern** (`test/example/lib/example_web/router.ex:209-220`):
```elixir
scope "/organizations/:org", ExampleWeb do
  pipe_through [:browser, :require_authenticated, :org_scoped]

  live_session :organization_scoped,
    on_mount: [
      {ExampleWeb.UserAuth, :ensure_authenticated},
      {ExampleWeb.UserAuth, :assign_user_organizations},
      {Sigra.LiveView.OrganizationScope,
```

**What to copy:** keep the canonical enterprise entry under `/organizations/:org/...` and place any generic discovery POST in the existing `/users` unauthenticated scope. Reuse existing pipelines instead of adding a special auth stack.

---

### `test/sigra/enterprise_routing_test.exs` (test, request-response)

**Primary analog:** `test/sigra/enterprise_connections/context_test.exs`

**Related references:** `test/sigra/plug/load_organization_from_slug_test.exs`

**Inline schema/config test harness pattern** (`test/sigra/enterprise_connections/context_test.exs:1-33`, `64-92`):
```elixir
defmodule TestScope do
  defstruct [:user, :active_organization, :membership]
end

defp config do
  %{
    repo: Sigra.MockRepo,
    schemas: %{enterprise_connection: TestConnection},
    http_client: fn _opts -> {:ok, %{status: 200, body: %{...}}} end
  }
end
```

**AAA + Mox expectation pattern** (`test/sigra/enterprise_connections/context_test.exs:94-128`):
```elixir
Sigra.MockRepo
|> expect(:get_by, fn TestConnection, [organization_id: ^org_id] -> nil end)
|> expect(:insert, fn changeset ->
  assert Ecto.Changeset.get_change(changeset, :organization_id) == org_id
  {:ok, Ecto.Changeset.apply_changes(changeset)}
end)
```

**Fail-closed plug-style test pattern** (`test/sigra/plug/load_organization_from_slug_test.exs:146-198`):
```elixir
result = LoadOrganizationFromSlug.call(conn, opts)

assert result.halted
assert result.status == 404
```

**What to copy:** test exact-one-match, zero-match, duplicate-domain, disabled connection, and stale callback context with explicit tuple assertions. Keep these tests pure library tests, not controller smoke tests.

---

### `test/sigra/oauth/callback_test.exs` (test, request-response)

**Analog:** `test/sigra/oauth/callback_test.exs`

**Describe-block coverage pattern** (`test/sigra/oauth/callback_test.exs:9-123`):
```elixir
describe "process_callback/4 - existing identity" do
  test "logs in user and updates identity fields when identity found" do
    ...
  end

  test "returns email_mismatch when identity user differs from email user" do
    ...
  end
end
```

**Tuple assertion pattern** (`test/sigra/oauth/callback_test.exs:64-71`, `84-113`):
```elixir
assert {:link_confirmation_required, info} =
         Callback.process_callback(config, :google, mock_user_info(), mock_token())

assert {:ok, :registered, user, _session} =
         Callback.process_callback(config, :google, mock_user_info(), mock_token())
```

**What to copy:** extend this file for enterprise-specific callback rejection cases. Keep provider payloads mocked and assert on the exact tuple shape and `error_code`.

---

### `test/sigra/oauth/oauth_test.exs` (test, request-response)

**Analog:** `test/sigra/oauth/oauth_test.exs`

**State ceremony test pattern** (`test/sigra/oauth/oauth_test.exs:44-82`, `105-149`):
```elixir
assert {:ok, url, session_params} = OAuth.authorize_url(config, :mock, [])
assert Map.has_key?(session_params, :sigra_state)

uri = URI.parse(url)
query = URI.decode_query(uri.query)
assert query["state"] == session_params.sigra_state
```

**Callback mismatch assertion pattern** (`test/sigra/oauth/oauth_test.exs:105-120`):
```elixir
params = %{"state" => "invalid_state", "code" => "auth_code"}
session_params = %{sigra_state: "different_state"}

assert {:error, %OAuthError{error_code: :state_mismatch}} =
         OAuth.handle_callback(config, :mock, params, session_params)
```

**What to copy:** add assertions that enterprise state carries org/connection/routing metadata and that callback rejects tampered or missing enterprise context before session creation.

---

### `test/example/test/example_web/controllers/enterprise_sso_controller_test.exs` (test, request-response)

**Primary analog:** `test/example/test/example_web/controllers/session_controller_test.exs`

**Related references:** `test/example/test/example_web/smoke/session_active_org_round_trip_test.exs`

**ConnCase structure pattern** (`test/example/test/example_web/controllers/session_controller_test.exs:18-29`):
```elixir
use ExampleWeb.ConnCase, async: true
import Example.AccountsFixtures

setup do
  attrs = valid_user_attributes()
  {:ok, user} = Accounts.register_user(attrs)
  %{user: user, password: attrs.password}
end
```

**HTML/redirect assertion pattern** (`test/example/test/example_web/controllers/session_controller_test.exs:31-89`):
```elixir
conn = get(conn, ~p"/users/log_in")
body = html_response(conn, 200)
assert body =~ ~s(id="magic_link_form")

conn = post(conn, ~p"/users/log_in", %{"user" => %{...}})
assert redirected_to(conn) == ~p"/users/log_in"
```

**Session truth smoke pattern** (`test/example/test/example_web/smoke/session_active_org_round_trip_test.exs:28-63`):
```elixir
{:ok, reloaded} =
  EctoStore.fetch(hashed_token, repo: Example.Repo, session_schema: UserSession)

assert reloaded.active_organization_id == org_id
```

**What to copy:** test both the org-scoped entry and the generic discovery POST. Assert redirect-to-canonical-org before OIDC starts, then assert callback/session truth stays tied to the initiating organization.

---

### `test/example/test/example_web/controllers/session_controller_test.exs` (test, request-response)

**Analog:** `test/example/test/example_web/controllers/session_controller_test.exs`

**Dead-render login page pattern** (`test/example/test/example_web/controllers/session_controller_test.exs:31-51`):
```elixir
body = conn |> get(~p"/users/log_in") |> html_response(200)

refute body =~ "phx-submit"
refute body =~ "data-phx-session"
```

**Enumeration-safe POST pattern** (`test/example/test/example_web/controllers/session_controller_test.exs:53-89`):
```elixir
conn =
  post(conn, ~p"/users/log_in", %{
    "_action" => "magic_link",
    "user" => %{"email" => user.email}
  })

assert redirected_to(conn) == ~p"/users/log_in"
assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "magic link"
```

**What to copy:** extend the login-page test file rather than inventing a separate generic-discovery test suite. The new enterprise branch belongs on the same surface and should inherit the same dead-render, POST-driven assertions.

## Shared Patterns

### Org-Scoped Routing
**Sources:** `test/example/lib/example_web/router.ex:99-121`, `test/example/lib/example_web/router.ex:209-220`

**Apply to:** `router.ex`, `enterprise_sso_controller.ex`

```elixir
scope "/users", ExampleWeb do
  pipe_through [:browser, :redirect_if_user_is_authenticated]

  get "/log_in", SessionController, :new
  post "/log_in", SessionController, :create
end

scope "/organizations/:org", ExampleWeb do
  pipe_through [:browser, :require_authenticated, :org_scoped]
end
```

### Signed OAuth State
**Source:** `lib/sigra/oauth.ex:430-487`

**Apply to:** `lib/sigra/oauth.ex`, `lib/sigra/oauth/callback.ex`

```elixir
state = generate_state(config.secret_key_base, provider)
new_url = replace_url_state(url, state)

session_params =
  %{sigra_state: state}
  |> maybe_put(:code_verifier, Map.get(assent_session, :code_verifier))
```

### Fail-Closed Controller Responses
**Sources:** `test/example/lib/example_web/controllers/organization_switch_controller.ex:24-52`, `lib/sigra/plug/load_organization_from_slug.ex:47-76`

**Apply to:** `enterprise_sso_controller.ex`, generic discovery failure handling

```elixir
conn
|> put_status(:not_found)
|> put_view(html: ExampleWeb.ErrorHTML)
|> render(:"404")
|> halt()
```

### Lightweight Org Truth UI
**Sources:** `test/example/lib/example_web/components/org_switcher.ex:37-75`, `test/example/lib/example_web/live/organization_settings_live.ex:161-188`

**Apply to:** `session_html.ex`, `enterprise_sso_controller.ex`

```elixir
{@current_scope.active_organization.name}

<h2 class="text-lg font-semibold">Enterprise SSO</h2>
<.input field={@enterprise_form[:login_hint_domains]} label="Login hint domains" />
```

### Test Style
**Sources:** `test/sigra/oauth/callback_test.exs:9-123`, `test/example/test/example_web/controllers/session_controller_test.exs:31-89`

**Apply to:** all new enterprise routing tests

```elixir
assert {:error, %OAuthError{error_code: :state_mismatch}} = ...
assert redirected_to(conn) == ~p"/users/log_in"
```

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/sigra/enterprise_routing.ex` | service | request-response | No existing library module performs bounded email-domain discovery plus callback-binding for enterprise login. Use `enterprise_connections.ex` for config/ownership shape and `oauth.ex` for state discipline. |
| `test/example/lib/example_web/controllers/enterprise_sso_controller.ex` | controller | request-response | No existing generated-host controller combines org-scoped entry, external redirect ceremony, and lightweight org-truth UI in one place. Compose `SessionController` and `OrganizationSwitchController` patterns. |

## Metadata

**Analog search scope:** `lib/`, `test/sigra/`, `test/example/lib/example_web/`, `test/example/test/example_web/`
**Files scanned:** 20
**Pattern extraction date:** 2026-05-25
