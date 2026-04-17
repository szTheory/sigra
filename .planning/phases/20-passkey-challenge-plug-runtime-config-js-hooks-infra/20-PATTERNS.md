# Phase 20: Passkey Challenge Plug + Runtime Config + JS Hooks Infra - Pattern Map

**Mapped:** 2026-04-15
**Files analyzed:** 11
**Analogs found:** 10 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/plug/passkey_challenge.ex` | middleware | request-response | `priv/templates/sigra.gen.oauth/oauth_controller.ex`, `lib/sigra/passkeys/registration.ex`, `lib/sigra/passkeys/authentication.ex` | partial |
| `test/sigra/plug/passkey_challenge_test.exs` | test | request-response | `test/sigra/plug/rate_limit_test.exs`, `test/sigra/plug/fetch_session_test.exs` | role-match |
| `lib/sigra/passkeys.ex` | service | request-response | `lib/sigra/organizations.ex` | role-match |
| `lib/sigra/config.ex` | config | transform | `lib/sigra/config.ex` (extend existing `passkeys` schema) | exact |
| `test/sigra/passkeys/config_test.exs` | test | transform | `test/sigra/config_test.exs` | exact |
| `test/sigra/passkeys/rate_limit_test.exs` | test | request-response | `test/sigra/rate_limiters/hammer_test.exs`, `test/sigra/plug/rate_limit_test.exs` | role-match |
| `lib/sigra/install/features/passkeys.ex` | config | file-I/O | `lib/sigra/install/features/organizations.ex`, `lib/sigra/install/features/core.ex` | role-match |
| `lib/sigra/install/injector.ex` | utility | file-I/O | `lib/sigra/install/injector.ex` (new anchor path beside existing anchors) | exact |
| `priv/templates/sigra.install/passkeys/passkey_hooks.js` | utility | event-driven | `test/example/priv/static/assets/js/app.js`, `priv/templates/sigra.install/core/mfa_settings_live.ex` | partial |
| `priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js` | utility | file-I/O | `lib/sigra/install/features/core.ex` injection builders, `test/example/priv/static/assets/js/app.js` | partial |
| `test/sigra/install/features/passkeys_js_test.exs` | test | file-I/O | `test/sigra/install/features/organizations_test.exs`, `test/sigra/install/injector_test.exs` | role-match |

## Pattern Assignments

### `lib/sigra/plug/passkey_challenge.ex` (middleware, request-response)

**Analog:** `priv/templates/sigra.gen.oauth/oauth_controller.ex`

**Session write/delete pattern**: [priv/templates/sigra.gen.oauth/oauth_controller.ex](/Users/jon/projects/sigra/priv/templates/sigra.gen.oauth/oauth_controller.ex:22)
```elixir
case Sigra.OAuth.authorize_url(config, provider_atom) do
  {:ok, url, session_params} ->
    conn
    |> put_session(:sigra_oauth_state, session_params[:sigra_state])
    |> put_session(:sigra_oauth_code_verifier, session_params[:code_verifier])
    |> put_session(:sigra_oauth_return_to, get_session(conn, :sigra_return_to))
    |> redirect(external: url)
```

**Single-use invalidation pattern**: [priv/templates/sigra.gen.oauth/oauth_controller.ex](/Users/jon/projects/sigra/priv/templates/sigra.gen.oauth/oauth_controller.ex:59)
```elixir
session_params = %{
  sigra_state: get_session(conn, :sigra_oauth_state),
  code_verifier: get_session(conn, :sigra_oauth_code_verifier)
}

conn =
  conn
  |> delete_session(:sigra_oauth_state)
  |> delete_session(:sigra_oauth_code_verifier)
```

**Challenge reconstruction boundary**: [lib/sigra/passkeys/registration.ex](/Users/jon/projects/sigra/lib/sigra/passkeys/registration.ex:20), [lib/sigra/passkeys/authentication.ex](/Users/jon/projects/sigra/lib/sigra/passkeys/authentication.ex:23)
```elixir
def new_challenge(%Sigra.Config{} = config, opts \\ []) do
  passkeys = config.passkeys

  Wax.new_registration_challenge(
    origin: Keyword.get(passkeys, :origin),
    rp_id: Keyword.get(passkeys, :rp_id),
    user_verification: passkeys |> Keyword.get(:user_verification, :preferred) |> to_string(),
    attestation: passkeys |> Keyword.get(:attestation, :none) |> to_string(),
    timeout: Keyword.get(passkeys, :timeout_ms, 60_000),
    bytes: Keyword.get(opts, :bytes)
  )
end
```

**Token primitive to reuse for session envelope**: [lib/sigra/token.ex](/Users/jon/projects/sigra/lib/sigra/token.ex:42)
```elixir
@spec generate(String.t(), String.t(), term(), keyword()) :: binary()
def generate(secret_key_base, purpose, data, opts \\ [])
    when is_binary(secret_key_base) and is_binary(purpose) do
  Plug.Crypto.sign(secret_key_base, purpose, data, opts)
end
```

**Use for Phase 20:** keep the module as a narrow adapter with explicit `issue/verify/delete` functions; mirror the OAuth session lifecycle, but reconstruct `Wax.Challenge` from the server-stored token instead of trusting browser challenge fields.

---

### `test/sigra/plug/passkey_challenge_test.exs` (test, request-response)

**Analog:** `test/sigra/plug/rate_limit_test.exs`

**Conn test style**: [test/sigra/plug/rate_limit_test.exs](/Users/jon/projects/sigra/test/sigra/plug/rate_limit_test.exs:1)
```elixir
defmodule Sigra.Plug.RateLimitTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Mox
```

**Call/assert pattern**: [test/sigra/plug/rate_limit_test.exs](/Users/jon/projects/sigra/test/sigra/plug/rate_limit_test.exs:118)
```elixir
test_conn =
  conn(:post, "/login")
  |> RateLimit.call(opts)

assert test_conn.halted
assert test_conn.status == 429
```

**Session bootstrap pattern**: [test/sigra/plug/fetch_session_test.exs](/Users/jon/projects/sigra/test/sigra/plug/fetch_session_test.exs:75)
```elixir
conn =
  conn(:get, "/")
  |> init_test_session(%{user_token: "valid-hashed-token"})
  |> FetchSession.call(opts)
```

**Use for Phase 20:** follow the flat AAA ExUnit style, initialize Plug session with `init_test_session/2`, and assert replay/delete semantics directly on the session-backed conn.

---

### `lib/sigra/passkeys.ex` (service, request-response)

**Analog:** `lib/sigra/organizations.ex`

**First-use validation helper pattern**: [lib/sigra/organizations.ex](/Users/jon/projects/sigra/lib/sigra/organizations.ex:232)
```elixir
@spec __validate_config__!(keyword()) :: map()
def __validate_config__!(opts) do
  validated = NimbleOptions.validate!(opts, @org_config_schema)

  validated
  |> Map.new()
  |> Map.update!(:schemas, &Map.new/1)
end
```

**Thin config-driven delegator pattern**: [lib/sigra/organizations.ex](/Users/jon/projects/sigra/lib/sigra/organizations.ex:277)
```elixir
def __sigra_org_config__, do: @sigra_org_config

def create_invitation(attrs),
  do: Sigra.Organizations.Invitations.create(@sigra_org_config, attrs)
```

**Current passkeys option validation pattern**: [lib/sigra/passkeys.ex](/Users/jon/projects/sigra/lib/sigra/passkeys.ex:39)
```elixir
def register(%Sigra.Config{} = config, user, attestation_params, opts \\ []) do
  validated = NimbleOptions.validate!(opts, @register_opts_schema)
  schema = resolve_user_passkey_schema!(config, validated)
```

**Use for Phase 20:** add `Sigra.Passkeys.config/0` and rate-limit helpers as explicit, validated entry points; keep downstream registration/authentication calls config-first and avoid `Application.get_env/2` in ceremony hot paths after the config is built.

---

### `lib/sigra/config.ex` (config, transform)

**Analog:** existing `passkeys` schema in `lib/sigra/config.ex`

**Nested schema style**: [lib/sigra/config.ex](/Users/jon/projects/sigra/lib/sigra/config.ex:448)
```elixir
passkeys: [
  type: :keyword_list,
  default: [],
  doc: "Passkey (WebAuthn) options.",
  keys: [
    enabled: [type: :boolean, default: true],
    sign_count_policy: [type: {:in, [:warn, :require_reauth, :revoke]}, default: :warn],
    max_per_user: [type: :pos_integer, default: 10],
    rp_id: [type: {:or, [:string, nil]}, default: nil],
    origin: [type: {:or, [:string, nil]}, default: nil]
  ]
]
```

**Validation entry point**: [lib/sigra/config.ex](/Users/jon/projects/sigra/lib/sigra/config.ex:1460)
```elixir
@spec new!(keyword()) :: t()
def new!(opts) when is_list(opts) do
  validated = NimbleOptions.validate!(opts, @schema)
  struct!(__MODULE__, validated)
end
```

**Use for Phase 20:** extend the existing `passkeys` subtree instead of inventing a second schema; keep required/enum/bounded values in NimbleOptions and let `Sigra.Passkeys.config/0` normalize any runtime-only convenience layer on top.

---

### `test/sigra/passkeys/config_test.exs` (test, transform)

**Analog:** `test/sigra/config_test.exs`

**Default assertions**: [test/sigra/config_test.exs](/Users/jon/projects/sigra/test/sigra/config_test.exs:71)
```elixir
test "provides correct rate_limiting defaults" do
  config = Config.new!(repo: MyApp.Repo, user_schema: MyApp.User)

  assert config.rate_limiting[:limiter] == nil
  assert config.rate_limiting[:ip_limit] == 10
  assert config.rate_limiting[:ip_window_ms] == 60_000
end
```

**Validation failure style**: [test/sigra/config_test.exs](/Users/jon/projects/sigra/test/sigra/config_test.exs:15)
```elixir
assert_raise NimbleOptions.ValidationError, ~r/:repo/, fn ->
  Config.new!(user_schema: MyApp.User)
end
```

**Use for Phase 20:** keep config tests table-driven and direct: one test for defaults, one per invalid enum/shape, and explicit assertion on error copy for `rp_id`/`origin` fast-fail paths.

---

### `test/sigra/passkeys/rate_limit_test.exs` (test, request-response)

**Analog:** `test/sigra/rate_limiters/hammer_test.exs`

**Key-shape assertion pattern**: [test/sigra/rate_limiters/hammer_test.exs](/Users/jon/projects/sigra/test/sigra/rate_limiters/hammer_test.exs:19)
```elixir
assert {:allow, 1} = Hammer.check_rate("test:key", 10, 60_000)
assert_received {:hammer_hit, "test:key", 60_000, 10}
```

**Deny-path assertion pattern**: [test/sigra/plug/rate_limit_test.exs](/Users/jon/projects/sigra/test/sigra/plug/rate_limit_test.exs:126)
```elixir
expect(Sigra.MockRateLimiter, :check_rate, fn _key, _limit, _window ->
  {:deny, 30_500}
end)

[retry_after] = Plug.Conn.get_resp_header(test_conn, "retry-after")
assert retry_after == "31"
```

**Use for Phase 20:** assert the exact passkey user namespace key, verify the sixth hit denies within the configured window, and keep Hammer mocked at the wrapper boundary instead of building ETS-specific tests.

---

### `lib/sigra/install/features/passkeys.ex` (config, file-I/O)

**Analog:** `lib/sigra/install/features/organizations.ex`

**Feature-owned injections pattern**: [lib/sigra/install/features/organizations.ex](/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex:161)
```elixir
[
  router_injection(otp_app, binding)
]
```

**Injection record builder pattern**: [lib/sigra/install/features/organizations.ex](/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex:225)
```elixir
%Injection{
  target: Path.join(["lib", "#{otp_app}_web", "router.ex"]),
  marker: "# Sigra organizations",
  anchor: :before_last_end,
  content: content
}
```

**Manual instructions pattern**: [lib/sigra/install/features/organizations.ex](/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex:178)
```elixir
def post_instructions(_binding, _report) do
  [
    """
    Sigra organizations installed!
    ...
    """
  ]
end
```

**Use for Phase 20:** grow `Features.Passkeys` from “files+migration only” into a feature that owns the JS template, the `assets/js/app.js` injection descriptor, and exact fallback instructions when the JS marker is absent.

---

### `lib/sigra/install/injector.ex` (utility, file-I/O)

**Analog:** existing anchor dispatch in `lib/sigra/install/injector.ex`

**Apply/idempotency pattern**: [lib/sigra/install/injector.ex](/Users/jon/projects/sigra/lib/sigra/install/injector.ex:432)
```elixir
case File.read(injection.target) do
  {:ok, content} ->
    if String.contains?(content, injection.marker) do
      {:ok, :already_present}
    else
      do_inject(injection, content, opts)
    end
```

**Anchor extension pattern**: [lib/sigra/install/injector.ex](/Users/jon/projects/sigra/lib/sigra/install/injector.ex:455)
```elixir
defp apply_anchor(:before_last_end, content, payload) do
  case find_last_end(content) do
    {:ok, position} ->
      {before, rest} = String.split_at(content, position)
      before <> "\n" <> payload <> "\n" <> rest
```

**Unsupported-anchor fail-fast**: [lib/sigra/install/injector.ex](/Users/jon/projects/sigra/lib/sigra/install/injector.ex:514)
```elixir
defp apply_anchor(other, _content, _payload),
  do: raise(ArgumentError, "unsupported injection anchor: #{inspect(other)}")
```

**Use for Phase 20:** add a JS-specific anchor/helper beside the existing anchor dispatch, not a one-off mutation path in the feature. Preserve marker-first idempotency and return an error/manual-action when the blessed `app.js` marker is missing.

---

### `priv/templates/sigra.install/passkeys/passkey_hooks.js` (utility, event-driven)

**Analog:** `test/example/priv/static/assets/js/app.js` for LiveSocket hook registration, plus `priv/templates/sigra.install/core/mfa_settings_live.ex` for hook consumption.

**LiveSocket hook map shape**: [test/example/priv/static/assets/js/app.js](/Users/jon/projects/sigra/test/example/priv/static/assets/js/app.js:109)
```javascript
var csrfMeta = document.querySelector("meta[name='csrf-token']");
var csrfToken = csrfMeta ? csrfMeta.getAttribute("content") : null;
var liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken }
});
```

**Server template hook usage**: [priv/templates/sigra.install/core/mfa_settings_live.ex](/Users/jon/projects/sigra/priv/templates/sigra.install/core/mfa_settings_live.ex:359)
```heex
<button
  type="button"
  phx-hook="CopyBackupCodes"
  id="copy-backup-codes"
  data-codes={Enum.join(@backup_codes, "\n")}
>
```

**Use for Phase 20:** export hook objects keyed for LiveView `phx-hook`, and shape the file so it can be merged into an existing `hooks` map. There is no first-party JS hook module in the repo yet, so this is a new seam; copy the registration posture, not the nonexistent implementation.

---

### `priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js` (utility, file-I/O)

**Analog:** `lib/sigra/install/features/core.ex` injection builders + `test/example/priv/static/assets/js/app.js`

**Injection content builder style**: [lib/sigra/install/features/core.ex](/Users/jon/projects/sigra/lib/sigra/install/features/core.ex:494)
```elixir
content = """

# Sigra authentication
config :#{otp_app}, :sigra,
  repo: #{repo_module},
  user_schema: #{context_module}.#{schema_alias}
"""
```

**Target file live socket block to mutate**: [test/example/priv/static/assets/js/app.js](/Users/jon/projects/sigra/test/example/priv/static/assets/js/app.js:111)
```javascript
var liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken }
});
```

**Use for Phase 20:** keep the injected JS as a template-owned block, not inline string soup in the feature module. The injected block should merge passkey hooks into the existing hook map instead of replacing it.

---

### `test/sigra/install/features/passkeys_js_test.exs` (test, file-I/O)

**Analog:** `test/sigra/install/features/organizations_test.exs`

**Injection content inspection style**: [test/sigra/install/features/organizations_test.exs](/Users/jon/projects/sigra/test/sigra/install/features/organizations_test.exs:563)
```elixir
injections = Organizations.injections(@injections_binding)

router_injection =
  Enum.find(injections, fn i -> String.ends_with?(i.target, "router.ex") end)

assert router_injection
assert router_injection.content =~ ~s|post "/organizations/switch"|
```

**Post-instructions assertion style**: [test/sigra/install/features/organizations_test.exs](/Users/jon/projects/sigra/test/sigra/install/features/organizations_test.exs:952)
```elixir
instructions = Organizations.post_instructions([otp_app: :my_app], report)
flat = instructions |> List.flatten() |> Enum.map_join("\n", &to_string/1)

assert flat =~ "layouts.ex"
```

**Low-level injector idempotency style**: [test/sigra/install/injector_test.exs](/Users/jon/projects/sigra/test/sigra/install/injector_test.exs:77)
```elixir
assert {:ok, injected} = Injector.inject_config(config_content, config_block)
assert String.contains?(injected, "# Sigra authentication")
```

**Use for Phase 20:** split tests into feature-level assertions on emitted files/injections/instructions and injector-level assertions on `app.js` idempotency and marker-missing fallback.

## Shared Patterns

### Authentication / Session Single-Use State
**Source:** [priv/templates/sigra.gen.oauth/oauth_controller.ex](/Users/jon/projects/sigra/priv/templates/sigra.gen.oauth/oauth_controller.ex:59)
**Apply to:** `Sigra.Plug.PasskeyChallenge`, `passkey_challenge_test.exs`
```elixir
conn =
  conn
  |> delete_session(:sigra_oauth_state)
  |> delete_session(:sigra_oauth_code_verifier)
```

### Config Validation
**Source:** [lib/sigra/config.ex](/Users/jon/projects/sigra/lib/sigra/config.ex:1460), [lib/sigra/organizations.ex](/Users/jon/projects/sigra/lib/sigra/organizations.ex:232)
**Apply to:** `lib/sigra/config.ex`, `lib/sigra/passkeys.ex`, `test/sigra/passkeys/config_test.exs`
```elixir
validated = NimbleOptions.validate!(opts, @schema)
struct!(__MODULE__, validated)
```

### Hammer Wrapper Boundary
**Source:** [lib/sigra/rate_limiters/hammer.ex](/Users/jon/projects/sigra/lib/sigra/rate_limiters/hammer.ex:27)
**Apply to:** `lib/sigra/passkeys.ex`, `test/sigra/passkeys/rate_limit_test.exs`
```elixir
def check_rate(key, limit, window_ms) do
  module = hammer_module()
  module.hit(key, window_ms, limit)
end
```

### Installer Injection Records
**Source:** [lib/sigra/install/features/core.ex](/Users/jon/projects/sigra/lib/sigra/install/features/core.ex:486), [lib/sigra/install/features/organizations.ex](/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex:228)
**Apply to:** `lib/sigra/install/features/passkeys.ex`
```elixir
%Injection{
  target: Path.join([...]),
  marker: "# Sigra ...",
  anchor: :before_last_end,
  content: content
}
```

### Installer Manual Fallback Reporting
**Source:** [lib/sigra/install/runner.ex](/Users/jon/projects/sigra/lib/sigra/install/runner.ex:108), [lib/sigra/install/report.ex](/Users/jon/projects/sigra/lib/sigra/install/report.ex:47)
**Apply to:** `lib/sigra/install/features/passkeys.ex`, `test/sigra/install/features/passkeys_js_test.exs`
```elixir
Report.record_manual_action(
  r,
  "Injection into #{injection.target} failed: #{inspect(reason)}"
)
```

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `priv/templates/sigra.install/passkeys/passkey_hooks.js` | utility | event-driven | No existing first-party JS hook module exists in the repo; only LiveSocket bootstrap and `phx-hook` call sites exist. |

## Metadata

**Analog search scope:** `lib/sigra/`, `priv/templates/`, `test/sigra/`, `test/example/`, `.planning/phases/20-*`
**Files scanned:** 24
**Pattern extraction date:** 2026-04-15
