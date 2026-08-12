# Phase 240: Alpha Operations Rehearsal - Pattern Map

**Mapped:** 2026-08-10  
**Files analyzed:** 11 expected changes  
**Analogs found:** 10 / 11

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `guides/recipes/b2c-alpha.md` | config/documentation | request-response | `guides/recipes/deployment.md` | role-match |
| `guides/recipes/deployment.md` | config/documentation | request-response | `guides/recipes/b2c-alpha.md` | role-match |
| `lib/sigra/install/features/core.ex` | service/generator feature | transform | `lib/sigra/install/features/passkeys.ex` | exact |
| `priv/templates/sigra.install/core/rate_limit.ex` | config/template | event-driven | `lib/sigra/rate_limiters/hammer.ex` | data-flow-match |
| `priv/templates/sigra.install/core/auth.ex` | service/template | CRUD | `lib/sigra/auth.ex` | exact |
| generated `router.ex` injection in `lib/sigra/install/features/core.ex` | route | request-response | existing `router_injection/3` in same file | exact |
| generated `application.ex` injection in `lib/sigra/install/features/core.ex` | config | event-driven | `vault_injection/2` + `Injector.inject_vault_child/2` | exact |
| `test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs` | test | transform | `test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` | exact |
| `test/sigra/plug/rate_limit_test.exs` | test | request-response | same file | exact |
| `scripts/ci/passkeys-opt-out-smoke.sh` | utility/CI harness | batch | `scripts/ci/generated-auth-runtime-proof.sh` | role-match |
| disposable generated-host bounded-rate probe (path at implementation discretion) | test/CI probe | request-response | `test/sigra/plug/rate_limit_test.exs` | partial |

## Pattern Assignments

### `guides/recipes/b2c-alpha.md` (documentation, request-response)

**Analog:** `guides/recipes/deployment.md`

Use the recipe as the concise entrypoint and link to deployment mechanics. Preserve the existing generated command and profile boundary at `b2c-alpha.md:7-15`; replace its one flat rehearsal list (`:17-36`) with the three locked evidence tiers. Every checklist row needs: owner, observable result, and a “does not prove” boundary. Keep real Google, controlled-recipient mail, and physical-iPhone hosted return solely in the host staging tier.

**Runtime tuple pattern** (`guides/recipes/deployment.md:46-95`):

```elixir
config :my_app, MyAppWeb.Endpoint,
  url: [host: System.get_env("PHX_HOST"), port: 443, scheme: "https"],
  secret_key_base: secret_key_base

config :my_app, MyApp.Auth.Config,
  cookie_domain: System.get_env("COOKIE_DOMAIN"),
  oauth: [providers: [google: [
    client_id: System.get_env("GOOGLE_CLIENT_ID"),
    client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
    redirect_uri: "https://" <> System.get_env("PHX_HOST") <> "/auth/google/callback"
  ]]]
```

For the canonical profile, explicitly record a host-only cookie (no `Domain` attribute), `Secure`, `HttpOnly`, and `SameSite=Lax`; shared domains or `SameSite=None` require host rationale. Do not copy the deployment guide’s platform-specific secret commands (`deployment.md:223-241`) into an evidence receipt.

**Doctor claim boundary** (`guides/recipes/deployment.md:205-221`):

```markdown
`mix sigra.doctor --quiet` exits 0 only when configured optional features are
properly wired; it checks dependency wiring, not runtime liveness.
```

State explicitly that this is not proof of credential acceptance, provider availability, public TLS/proxy correctness, key validity/rotation, mail delivery, or device behavior.

---

### `lib/sigra/install/features/core.ex` (generator feature, transform)

**Analog:** `lib/sigra/install/features/passkeys.ex:19-55,69-96`

New generated ownership belongs in the Core feature’s `files/1` and `injections/1` outputs, never as direct filesystem writes. Use `{ :eex, template, destination }` for new host files and `%Injection{}` records with a marker and anchor for host-file edits.

```elixir
def files(binding) do
  # existing groups followed by the new generated-host template
  base_files(binding) ++ ui_files(binding, live?)
end

%Injection{
  target: Path.join(["config", "config.exs"]),
  marker: "# Sigra authentication",
  anchor: :elixir_config,
  content: content
}
```

**Relevant Core shapes:**

```elixir
# lib/sigra/install/features/core.ex:188-205
{:eex, "core/auth.ex", Path.join(["lib", otp_app, "#{ctx}.ex"])},
{:eex, "core/session_controller.ex",
 Path.join(["lib", web, "controllers", "session_controller.ex"])}

# :524-529 — idempotent router injection
%Injection{
  target: Path.join(["lib", "#{otp_app}_web", "router.ex"]),
  marker: "# Sigra authentication",
  anchor: :before_last_end,
  content: content
}
```

Extend the same Core-owned binding-driven architecture for: Hammer dependency injection, generated `RateLimit` module, application child, `:sigra` hammer module, generated Auth config rate-limiter choice, and distinct route/context key prefixes. Remove/update the old “Optional” post-install Hammer advice at `:771-779`; B2C output must own this configuration rather than rely on a manual follow-up.

---

### `priv/templates/sigra.install/core/rate_limit.ex` (new host template, event-driven)

**Analog:** `lib/sigra/rate_limiters/hammer.ex:1-46`

Generate the host-owned module expected by the adapter; do not reimplement counter/window logic.

```elixir
# Generated module shape from the adapter contract
defmodule MyApp.RateLimit do
  use Hammer, backend: :ets
end

# Host config consumed by Sigra.RateLimiters.Hammer
config :sigra, hammer_module: MyApp.RateLimit
```

The adapter fixes Hammer’s argument ordering and therefore must remain the sole direct Hammer caller:

```elixir
# lib/sigra/rate_limiters/hammer.ex:27-39
def check_rate(key, limit, window_ms) do
  module = hammer_module()
  try do
    module.hit(key, window_ms, limit)
  rescue
    _ ->
      Logger.warning("[Sigra] Hammer rate limiter unavailable, failing open")
      {:allow, 0}
  end
end
```

Generated B2C configuration must pass a concrete limiter (`Sigra.RateLimiters.Hammer`) rather than relying on `nil`; `Sigra.Plug.RateLimit`’s `nil` resolver intentionally falls back to Noop when Hammer is absent (`lib/sigra/plug/rate_limit.ex:84-97`).

---

### Generated route/config/application injections in `lib/sigra/install/features/core.ex` (route/config, request-response/event-driven)

**Analogs:** `core.ex:466-529`, `core.ex:550-590`, `core.ex:618-627`; `lib/sigra/install/injector.ex:456-479`

Apply `Sigra.Plug.RateLimit` to real high-risk POST controller routes using different stable `key_prefix` values. Keep LiveView mail requests separately limited in the generated Auth context: they are `handle_event/3` operations and not router POSTs (`registration_live.ex:121-165`, `reset_password_live.ex:158-168`).

```elixir
# lib/sigra/plug/rate_limit.ex:59-80
key = "#{opts.key_prefix}:ip:#{ip}"

case limiter.check_rate(key, opts.limit, opts.window) do
  {:allow, _count} -> conn
  {:deny, retry_after_ms} ->
    retry_after_s = div(retry_after_ms + 999, 1000)
    conn
    |> Plug.Conn.put_resp_header("retry-after", Integer.to_string(retry_after_s))
    |> opts.error_handler.auth_error(:rate_limited, retry_after: retry_after_s)
    |> Plug.Conn.halt()
end
```

Add the generated Hammer child using the existing child-list injection model:

```elixir
# lib/sigra/install/injector.ex:458-470
if String.contains?(file_contents, vault_module) do
  {:already_injected, file_contents}
else
  # Finds children = [ and inserts a child spec after it.
  {:ok, before <> "\n      {#{vault_module}, []}," <> rest}
end
```

Use a dedicated marker/module check for the limiter so repeated generation is idempotent. Put it before Endpoint when child ordering matters. Preserve `conn.remote_ip` as the plug key source; the recipe, not the library, owns trusted proxy normalization (`rate_limit.ex:25-29`).

**Generic non-enumerating denial response** (`priv/templates/sigra.install/core/error_handler.ex:38-43`):

```elixir
def auth_error(conn, :rate_limited, _opts) do
  conn
  |> put_resp_content_type("text/plain")
  |> send_resp(429, "Too many requests. Please try again later.")
end
```

---

### `priv/templates/sigra.install/core/auth.ex` (service template, CRUD)

**Analog:** `lib/sigra/auth.ex:618-684,1075-1151`

Thread the explicit generated limiter and stable, distinct keys into context calls that send mail. Preserve the existing normalized-email, generic-result, and delivery shape; only add the limiter/options seam.

```elixir
# Existing generated wrapper: auth.ex:137-142
def request_magic_link(email, url_fun) when is_binary(email) and is_function(url_fun, 1) do
  SigraAuth.request_magic_link(Repo, email,
    user_schema: User,
    user_token_schema: UserToken,
    url_fun: url_fun
  )
end

# Existing generic response: auth.ex:150-174
case request_magic_link(normalized_email, magic_link_url_fun) do
  {:ok, {_raw_token, url}} ->
    # deliver only when a matching user exists
    {:ok, :sent}
  result -> result
end
```

Library behavior to preserve:

```elixir
# lib/sigra/auth.ex:629-636
cond do
  is_nil(user) -> {:ok, :sent}
  rate_limiter &&
      rate_limited?(rate_limiter, "magic_link:#{normalized_email}", max_requests, window_ms) ->
    {:error, :rate_limited}
  true ->
    # transaction and delivery-token creation
end
```

For reset, copy the equivalent call seam at template `auth.ex:466-498` and library `lib/sigra/auth.ex:1084-1095`. LiveView callers must continue to show generic success (`reset_password_live.ex:158-167`); do not convert a context `:rate_limited` into user/account-existence information. The exact host-side key composition should be chosen deliberately and tested for independence; never reuse the router’s IP key as a replacement for the context email-key limit.

---

### `test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs` (source-contract test, transform)

**Analog:** `test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs:1-43,74-180`

Use an `async: true` ExUnit contract test that owns simple path module attributes, a local `read!/1`, and an assertion helper. Assert positive evidence markers and negative prohibited claims/credential injection independently.

```elixir
defmodule Sigra.Planning.Phase238GeneratedAuthRuntimeProofTest do
  use ExUnit.Case, async: true

  @harness "scripts/ci/generated-auth-runtime-proof.sh"
  @workflow ".github/workflows/generated-auth-runtime-proof.yml"

  defp read!(path), do: File.read!(path)
  defp assert_contains!(source, marker, context) do
    assert String.contains?(source, marker), "#{context} is missing #{inspect(marker)}"
  end
end
```

Follow the existing no-sleep/browser-negative pattern when inspecting Playwright sources (`phase_238...:165-179`): reject `waitForTimeout`, timer APIs, cookie/storage mutation, and assertions that would elevate local OIDC proof to real-provider proof. The Phase 240 contract should also reject `${{ secrets.* }}`, provider/mail/deployment credential injection, token-bearing receipt fields, and absence of the `unset GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET` boundary. Treat fixed `CLOAK_KEY` and OIDC values as explicitly disposable fixtures, not secrets.

---

### `test/sigra/plug/rate_limit_test.exs` and generated-host bounded probe (tests, request-response)

**Analog:** `test/sigra/plug/rate_limit_test.exs:1-31,79-204`

Retain the existing fast, async Mox plug unit tests and extend only for any plug API changes. It provides the exact deterministic request pattern and assertions for IP keys, `429`, rounded `Retry-After`, generic text, and telemetry.

```elixir
expect(Sigra.MockRateLimiter, :check_rate, fn key, limit, window ->
  assert key == "sigra:ip:127.0.0.1"
  assert limit == 10
  assert window == 60_000
  {:allow, 1}
end)

test_conn = conn(:post, "/login") |> RateLimit.call(opts)
refute test_conn.halted
```

For the new generated-host proof, create/configure an explicitly low fresh limiter and perform only bounded attempts: allow through the chosen count, then assert a 429 and `Retry-After`; issue an equivalent request through a different prefix and prove it remains independent. Do not wait for a window to expire and do not add a Playwright test unless browser-visible behavior changes. The source-contract test plus generated request probe should establish generated module/dependency/child/config/route/context ownership.

---

### `scripts/ci/passkeys-opt-out-smoke.sh` and `scripts/ci/generated-auth-runtime-proof.sh` (CI utilities, batch)

**Analogs:** `passkeys-opt-out-smoke.sh:119-140,213-268`; `generated-auth-runtime-proof.sh:23-29,210-235`

Keep fresh generation and rendered runtime as independent lanes. Extend the B2C-only branch with source-shape/request proof in the same `assert_match`/bounded-failure style; do not merge it into an unrelated skip-tolerant aggregate.

```bash
# passkeys-opt-out-smoke.sh:119-139
assert_match() {
  local pattern="$1"
  local path="$2"
  if ! find_matches "${pattern}" "${path}" >/dev/null 2>&1; then
    echo "FAIL: expected match for pattern ${pattern} in ${path}"
    exit 1
  fi
}

# generated-auth-runtime-proof.sh:26-29
export CLOAK_KEY="${CLOAK_KEY:-MDEy...=}"
# Proof inputs are constants below. Inherited provider credentials must never
# become a substitute for the local OIDC double.
unset GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET
```

Do not emit secret values, token URLs, mail bodies, or provider payloads. Preserve the runtime harness’s loopback-only constants and inherited-Google unsetting. Its browser lane already uses deterministic polling/readiness; no new sleep-based rate-limit window crossing is permitted.

## Shared Patterns

### Generator idempotency

**Sources:** `lib/sigra/install/features/core.ex:524-529`, `lib/sigra/install/injector.ex:456-479`  
**Apply to:** Core feature, all router/config/application modifications.

Generate files through `files/1`; represent host modifications as `%Injection{target, marker, anchor, content}`. The injector must report already-present state on a repeated install rather than duplicate a limiter child or route.

### Rate-limit response and keys

**Sources:** `lib/sigra/plug/rate_limit.ex:59-80`, `priv/templates/sigra.install/core/error_handler.ex:38-43`  
**Apply to:** high-risk generated controller POST routes.

Use IP-scoped `key_prefix:ip:<remote_ip>` values, a concrete limiter, 429 plus rounded `Retry-After`, and neutral response copy. Prefixes must differ by flow. Proxy client-IP normalization is a host staging prerequisite.

### Enumeration-safe email flows

**Sources:** `lib/sigra/auth.ex:629-636,1087-1095`; `priv/templates/sigra.install/core/session_controller.ex:37-49`; `priv/templates/sigra.install/core/reset_password_live.ex:158-167`  
**Apply to:** magic-link and reset LiveView/context paths.

Preserve normalized input, generic outcomes, and context-level limiter errors handled without user differentiation. Route plugs alone cannot cover LiveView events.

### Credential-free deterministic evidence

**Sources:** `scripts/ci/generated-auth-runtime-proof.sh:23-29`; `test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs:165-179`  
**Apply to:** both independent CI lanes and Phase 240 source contracts.

Use disposable fixed fixtures, explicitly unset inherited Google credentials, no live secret injection, no timer sleeps, and negative source assertions that CI does not claim host-owned provider/mail/deployment/device gates.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| disposable generated-host bounded-rate probe | test/CI probe | request-response | No existing fresh-host ExUnit rate-limiter probe; combine the repository plug unit pattern with the B2C smoke harness. |

## Metadata

**Analog search scope:** `guides/recipes`, `lib/sigra`, installer templates/features, `test/sigra`, `scripts/ci`, and `.github/workflows`  
**Files scanned:** 18  
**Pattern extraction date:** 2026-08-10
