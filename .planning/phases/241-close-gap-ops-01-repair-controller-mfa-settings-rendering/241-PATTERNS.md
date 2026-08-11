# Phase 241: OPS-01 Controller MFA Settings Rendering - Pattern Map

**Mapped:** 2026-08-11  
**Files analyzed:** 3  
**Analogs found:** 3 / 3

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `priv/templates/sigra.install/core/settings_controller.ex` | controller | request-response | `priv/templates/sigra.install/organizations/controllers/organization_switch_controller.ex` | role-match |
| `scripts/ci/passkeys-opt-out-smoke.sh` | config / generated-host test harness | request-response | its existing `install_generated_rate_limit_probe` function | exact |
| `test/sigra/install/generated_rate_limit_contract_test.exs` | test / source contract | transform | its existing controller-lane contract | exact |

The existing `priv/templates/sigra.install/core/mfa_settings_html.ex` is a consumed renderer, not a modification target: its `mfa_settings/1` assign API remains unchanged (lines 14-26).

## Pattern Assignments

### `priv/templates/sigra.install/core/settings_controller.ex` (controller, request-response)

**Analog:** `priv/templates/sigra.install/organizations/controllers/organization_switch_controller.ex`

**Explicit HTML owner pattern** (lines 43-47):

```elixir
conn
|> put_status(:not_found)
|> put_view(html: <%= web_module %>.ErrorHTML)
|> render(:"404")
|> halt()
```

Apply the same `put_view(html: ...)` keyword form directly in `mfa/2`, selecting `<%= web_module %>.MFASettingsHTML` before its existing render. Preserve the existing status lookup and all seven assigns in `settings_controller.ex` lines 17-28:

```elixir
status = Auth.mfa_status(conn.assigns.current_scope.user)

conn
|> put_view(html: <%= web_module %>.MFASettingsHTML)
|> render(:mfa_settings,
  mfa_enabled: status.enabled,
  backup_remaining: status.backup_codes_remaining,
  enrollment_step: nil,
  svg: nil,
  base32_secret: nil,
  backup_codes: [],
  show_disable: false
)
```

**Scope boundary:** retain `unavailable/1` unchanged at lines 31-41; mutations are explicitly deferred.

### `scripts/ci/passkeys-opt-out-smoke.sh` (generated-host test harness, request-response)

**Analog:** `scripts/ci/passkeys-opt-out-smoke.sh` — `install_generated_rate_limit_probe/0` (lines 203-258) and B2C-alpha lifecycle (lines 371-376).

**Probe injection pattern** (lines 203-210, 251-258):

```bash
install_generated_rate_limit_probe() {
  # This probe lives only in the disposable B2C host.
  cat > "test/generated_rate_limit_probe_test.exs" <<'EOF'
defmodule SigraB2cAlpha.GeneratedRateLimitProbeTest do
  use SigraB2cAlphaWeb.ConnCase, async: false
```

```bash
  MIX_ENV=test mix ecto.drop || true
  MIX_ENV=test mix ecto.create
  MIX_ENV=test mix ecto.migrate
  MIX_ENV=test mix test test/generated_rate_limit_probe_test.exs
}
```

Follow this lifecycle but bind the new probe to the `sigra_b2c_controller` leg, after generation/dependency resolution and after test database migration. Do not introduce a server/browser lane or a sleep.

**Exact request-session sudo pattern** from `test/example/test/example_web/live/passkey_settings_live_test.exs` lines 237-248:

```elixir
conn = log_in_user(conn, user)
token = Plug.Conn.get_session(conn, :user_token)
{^user, session} = Accounts.get_user_and_session_by_token(token)

UserSession
|> Repo.get_by!(hashed_token: session.hashed_token)
|> Ecto.Changeset.change(sudo_at: DateTime.utc_now())
|> Repo.update!()

conn
```

The generated probe should then dispatch the routed GET and demand both 200 HTML and stable existing MFA copy:

```elixir
html = conn |> get(~p"/users/settings/mfa") |> html_response(200)
assert html =~ "Two-Factor Authentication"
```

This is necessary because `Sigra.Plug.RequireSudo` reads `conn.private[:sigra_session]` and validates `session.sudo_at` (lines 57-84), while `sudo_session_fixture/2` creates a separate session (`auth_fixtures.ex` lines 223-228).

### `test/sigra/install/generated_rate_limit_contract_test.exs` (test / source contract, transform)

**Analog:** same file — controller-router compile-lane contract (lines 65-91).

**Source-contract style:**

```elixir
test "generated-host compile lanes cover both LiveView and controller router output" do
  core = read!(@core_feature)
  smoke = read!(@smoke)
  runtime = read!("scripts/ci/generated-auth-runtime-proof.sh")

  assert_contains!(
    smoke,
    "run_leg \"--no-admin --no-organizations --no-passkeys --no-live\" \"sigra_b2c_controller\"",
    "controller-router generated-host compile lane"
  )
  assert_contains!(smoke, "mix compile --warnings-as-errors", "controller-router compilation")
  refute String.contains?(runtime, "--no-live"),
         "LiveView compile lane must retain LiveView output"
end
```

Extend this file only with narrow marker/order assertions that protect: (1) explicit `MFASettingsHTML` ownership, (2) the controller-host route probe command, and (3) preservation of the separate canonical LiveView lane. Retain its local `read!/1` and `assert_contains!/3` helpers (lines 4-12); do not create a parallel contract test.

## Shared Patterns

### Generated no-live ownership and route protection

**Source:** `lib/sigra/install/features/core.ex` lines 309-323 and 435-535

```elixir
{:eex, "core/mfa_settings_html.ex",
 Path.join(["lib", web, "controllers", "mfa_settings_html.ex"])},
{:eex, "core/settings_controller.ex",
 Path.join(["lib", web, "controllers", "settings_controller.ex"])}
```

```elixir
scope "/users", #{web_module} do
  pipe_through [:browser, :require_authenticated, :require_sudo]
  #{mfa_settings_routes}
end
```

Apply to the controller repair and generated-host probe. The emitted `MFASettingsHTML` module is deliberately separate from inferred `SettingsHTML`; protect rather than rename that ownership boundary.

### Authentication and sudo persistence

**Source:** `priv/templates/sigra.install/core/user_auth.ex` lines 60-74, 164-170, and 471-475

```elixir
conn
|> renew_session()
|> put_token_in_session(token)
|> maybe_write_remember_me_cookie(token, params)
```

```elixir
defp put_token_in_session(conn, token) do
  conn
  |> put_session(:user_token, token)
  |> put_session(:live_socket_id, "users_sessions:#{Base.url_encode64(Sigra.Token.hash_token(token))}")
end
```

Use `:user_token` from the post-login test connection to find and update precisely the session loaded by the protected request.

### Deterministic generated-host lifecycle

**Source:** `scripts/ci/passkeys-opt-out-smoke.sh` lines 379-404

```bash
MIX_ENV=dev mix compile --warnings-as-errors
MIX_ENV=dev mix assets.deploy
MIX_ENV=dev mix ecto.drop || true
MIX_ENV=dev mix ecto.create
MIX_ENV=dev mix ecto.migrate
```

The new focused test runs through ExUnit before this existing compile/boot readiness proof. Keep the current four-leg run list unchanged (lines 409-412), adding behavior only to the controller leg.

## No Analog Found

None. The change combines established explicit-view, generated-probe, and source-contract patterns.

## Metadata

**Analog search scope:** `priv/templates/sigra.install`, `lib/sigra/install`, `lib/sigra/plug`, `scripts/ci`, `test/sigra/install`, and `test/example`  
**Files scanned:** 12  
**Pattern extraction date:** 2026-08-11
