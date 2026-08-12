# Phase 243: Credential Boundary and Pipeline Foundation - Pattern Map

**Mapped:** 2026-08-12  
**Files analyzed:** 18 planned new/modified files  
**Analogs found:** 17 / 18

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/plug/credential_auth.ex` | utility (private helper) | request-response | `lib/sigra/scope.ex` | data-flow match |
| `lib/sigra/plug/fetch_api_token.ex` | middleware | request-response | `lib/sigra/plug/fetch_bearer.ex` | role-match |
| `lib/sigra/plug/fetch_jwt.ex` | middleware | request-response | `lib/sigra/plug/fetch_bearer.ex` | role-match |
| `lib/sigra/plug/fetch_app_session.ex` | middleware | request-response | `lib/sigra/plug/fetch_session.ex` | role-match |
| `lib/sigra/plug/fetch_bearer.ex` | middleware | request-response | `lib/sigra/plug/fetch_bearer.ex` | exact |
| `lib/sigra/plug/fetch_session.ex` | middleware | request-response | `lib/sigra/plug/fetch_session.ex` | exact |
| `lib/sigra/plug/require_scopes.ex` | middleware | request-response | `lib/sigra/plug/require_scopes.ex` | exact |
| `test/sigra/plug/fetch_api_token_test.exs` | test | request-response | `test/sigra/plug/fetch_bearer_test.exs` | role-match |
| `test/sigra/plug/fetch_jwt_test.exs` | test | request-response | `test/sigra/plug/fetch_bearer_test.exs` | role-match |
| `test/sigra/plug/fetch_app_session_test.exs` | test | request-response | `test/sigra/plug/fetch_session_test.exs` | role-match |
| `test/sigra/plug/fetch_bearer_test.exs` | test | request-response | `test/sigra/plug/fetch_bearer_test.exs` | exact |
| `test/sigra/plug/fetch_session_test.exs` | test | request-response | `test/sigra/plug/fetch_session_test.exs` | exact |
| `test/sigra/plug/require_scopes_test.exs` | test | request-response | `test/sigra/plug/require_scopes_test.exs` | exact |
| `test/sigra/credential_boundary_docs_test.exs` | test | transform | `test/sigra/recipes/companion_lib_contract_test.exs` | role-match |
| `guides/introduction/contract.md` | documentation | transform | `guides/recipes/companion-libs/lockspire.md` | data-flow match |
| `guides/flows/api-authentication.md` | documentation | request-response | `guides/flows/api-authentication.md` | exact |
| `guides/recipes/companion-libs/lockspire.md` | documentation | request-response | `guides/recipes/companion-libs/lockspire.md` | exact |
| `test/sigra/scope/build_test.exs` | test | transform | `test/sigra/scope/build_test.exs` | exact |

## Pattern Assignments

### `lib/sigra/plug/credential_auth.ex` (private utility, request-response)

**Analog:** `lib/sigra/scope.ex`

Use this as a private library seam for the common **verified credential -> live user -> normal Scope -> allowlisted private facts** transition. Keep the module undocumented/private: it must not become a new host extension API.

**Normal Scope construction** (`lib/sigra/scope.ex:16-25`):

```elixir
@spec build(scope_module :: module(), user :: struct() | map() | nil, opts :: keyword()) ::
        struct()
def build(scope_module, user, opts \\ []) when is_atom(scope_module) and is_list(opts) do
  struct(scope_module,
    user: user,
    active_organization: Keyword.get(opts, :active_organization),
    membership: Keyword.get(opts, :membership),
    impersonating_from: Keyword.get(opts, :impersonating_from)
  )
end
```

**Live-user lookup precedent** (`lib/sigra/jwt.ex:401-417`):

```elixir
user_id = claims["sub"]

case config.repo.get(config.user_schema, user_id) do
  nil ->
    {:error, :invalid_token}

  user ->
    user_epoch = Map.get(user, :token_epoch, 0)
    claim_epoch = claims["epoch"] || 0

    if user_epoch == claim_epoch do
      {:ok, claims}
    else
      {:error, :epoch_mismatch}
    end
end
```

**Required helper contract:** accept only verifier-derived IDs and a freshly built allowlist of facts; on missing user assign `:current_scope` to `nil` and never store facts. On success, call `Sigra.Scope.build(scope_module, user, [])` (the explicit `/3` form) and `Plug.Conn.put_private(conn, :sigra_auth, facts)`. Facts may include `credential_kind`, credential identifier, selected scopes, session/family reference, `auth_method`, and assurance; they must exclude raw tokens, secrets, device identifiers, and arbitrary claims/input.

---

### `lib/sigra/plug/fetch_api_token.ex` and `lib/sigra/plug/fetch_jwt.ex` (middleware, request-response)

**Analog:** `lib/sigra/plug/fetch_bearer.ex`

Retain the existing Plug shell and skip rule, but split verifier selection by module instead of copying `detect_and_verify/2`.

**Plug interface and authenticated-scope short circuit** (`lib/sigra/plug/fetch_bearer.ex:25-47`):

```elixir
@behaviour Plug

@impl Plug
def init(opts), do: opts

@impl Plug
def call(conn, opts) do
  if conn.assigns[:current_scope] do
    conn
  else
    do_fetch(conn, opts)
  end
end
```

**Established option extraction and bearer parsing** (`lib/sigra/plug/fetch_bearer.ex:50-55,124-128`):

```elixir
config = Keyword.fetch!(opts, :config)
scope_module = Keyword.fetch!(opts, :scope_module)

case Plug.Conn.get_req_header(conn, "authorization") do
  ["Bearer " <> token] -> {:ok, String.trim(token)}
  _ -> :error
end
```

**Verifier boundaries to call, not reimplement:**

```elixir
# lib/sigra/api_token.ex:401-406
def verify(config, raw_token) when is_binary(raw_token) do
  Telemetry.span([:sigra, :api_token, :verify], %{}, fn ->
    hashed = Token.hash_token(raw_token)
    schema = Keyword.fetch!(config.api_token, :api_token_schema)
    case config.repo.get_by(schema, hashed_token: hashed) do
```

```elixir
# lib/sigra/jwt.ex:127-149
def verify_access(config, jwt_string) do
  Signer.ensure_joken!()
  Telemetry.span([:sigra, :jwt, :verify], %{}, fn ->
    signer = Signer.create_signer(config)
    case Joken.verify(jwt_string, signer) do
      {:ok, claims} ->
        cond do
          claims_expired?(claims) -> {:error, :token_expired}
          Keyword.get(config.jwt, :verify_epoch, true) -> verify_epoch(config, claims)
          true -> {:ok, claims}
        end
      {:error, _reason} -> {:error, :invalid_token}
    end
  end)
end
```

For PAT use `Sigra.APIToken.verify/2`; facts derive only from the verified token (`id`, `user_id`, server-selected `scopes`). For JWT use `Sigra.JWT.verify_access/2`; facts derive only from verified claims (`jti`, `sub`, `scopes`, assurance only if a bounded known claim is defined). Both delegate user/scope/private-facts work to `CredentialAuth`; invalid/missing credentials set only nil scope.

---

### `lib/sigra/plug/fetch_app_session.ex` (middleware, request-response)

**Analog:** `lib/sigra/plug/fetch_session.ex`

**Fail-closed foundation decision:** implement the public Plug interface and existing-scope skip only. Do not parse a raw credential, add a fallback to browser sessions, create schema/configuration, or write `:sigra_auth`; Phase 245 owns opaque app-session verification/storage. It must assign `:current_scope` to `nil` on an unauthenticated connection so `RequireAuthenticated` applies the established handler and halt.

**Existing session's nil failure convention** (`lib/sigra/plug/fetch_session.ex:78-98`):

```elixir
case fetch_and_validate_session(token, session_store, session_config, store_opts) do
  {:ok, session} ->
    # successful path assigns a scope and private session state
    ...

  :skip ->
    Plug.Conn.assign(conn, :current_scope, nil)
end
```

**Why this is fail-closed:** `RequireAuthenticated` treats nil as unauthenticated and is the current error-handler/halt boundary (`lib/sigra/plug/require_authenticated.ex:35-44`):

```elixir
if conn.assigns[:current_scope] do
  conn
else
  conn
  |> error_handler.auth_error(:unauthenticated, opts)
  |> Plug.Conn.halt()
end
```

---

### `lib/sigra/plug/fetch_bearer.ex` (middleware, request-response)

**Analog:** itself, preserving compatibility dispatch.

Keep current prefix/JWT routing deterministically for already-installed routers, but mark module/API documentation deprecated and delegate each verified branch to the explicit internal path/helper. Do not alter generated routers in this phase.

**Legacy routing that must remain deterministic** (`lib/sigra/plug/fetch_bearer.ex:86-112`):

```elixir
cond do
  prefix && String.starts_with?(raw_token, prefix) ->
    verify_opaque(config, raw_token)

  jwt_enabled && String.starts_with?(raw_token, "eyJ") ->
    case Sigra.JWT.verify_access(config, raw_token) do
      {:ok, claims} -> {:ok, :jwt, claims}
      error -> error
    end

  true ->
    verify_opaque(config, raw_token)
end
```

**Replace this incompatible construction only** (`lib/sigra/plug/fetch_bearer.ex:57-75,120-122`):

```elixir
scope = build_scope(scope_module, token.user_id, %{
  token_scopes: token.scopes,
  auth_method: :api_token,
  token_id: token.id
})

defp build_scope(scope_module, user_id, extra) do
  scope_module.new(Map.merge(%{id: user_id}, extra))
end
```

Route verified results through `CredentialAuth` instead: normal Scope in assigns and bounded credential facts in private. Keep `init/1`, `call/2`, `:config`, and `:scope_module` public options intact.

---

### `lib/sigra/plug/fetch_session.ex` (middleware, request-response)

**Analog:** itself, with a compatibility checkpoint.

**Current browser behavior to preserve** (`lib/sigra/plug/fetch_session.ex:62-98`):

```elixir
config = Keyword.fetch!(opts, :config)
scope_module = Keyword.fetch!(opts, :scope_module)
session_config = config.session
session_store = Keyword.fetch!(session_config, :store)

case fetch_and_validate_session(token, session_store, session_config, store_opts) do
  {:ok, session} ->
    maybe_update_activity(session, session_store, session_config, store_opts)
    scope = scope_module.new(%{id: session.user_id})

    conn
    |> Plug.Conn.assign(:current_scope, scope)
    |> Plug.Conn.put_private(:sigra_session, session)
  :skip -> Plug.Conn.assign(conn, :current_scope, nil)
end
```

**Do not unconditionally replace `scope_module.new/1` with `Sigra.Scope.build/3`.** Source evidence shows that the documented public contract requires a module exporting `new/1` (`fetch_session.ex:20-25`), and its focused test supplies a non-struct module that only implements `new/1` (`test/sigra/plug/fetch_session_test.exs:10-12`). `Scope.build/3` uses `struct(scope_module, ...)` (`scope.ex:18-24`), so an unconditional switch breaks source compatibility for such installed host modules.

The generated Scope is a struct and requires a full host user (`priv/templates/sigra.install/core/scope.ex:50-56`):

```elixir
def new(%<%= schema_alias %>{} = user) do
  %__MODULE__{user: user}
end

def new(nil), do: nil
```

**Planner direction:** load `config.repo.get(config.user_schema, session.user_id)` and test deleted-user -> nil Scope. Preserve the established `new/1` public construction route for browser compatibility (passing the loaded user), unless the implementation can demonstrate an explicit compatibility adapter for legacy non-struct scope modules. Do not make direct `Scope.build/3` a Phase 243 requirement; it is not source-compatible as currently implemented. Browser-session metadata remains `:sigra_session`, and it must not receive delegated scopes.

---

### `lib/sigra/plug/require_scopes.ex` (middleware, request-response)

**Analog:** itself.

Keep init validation, handler invocation, supplied/provided scope response options, and halt shape. Replace only reads from the host Scope with trusted `conn.private[:sigra_auth]`; missing facts and session/app-session facts must be insufficient scope, never bypass.

**Validation and handler convention** (`lib/sigra/plug/require_scopes.ex:43-52,82-91`):

```elixir
scopes = Keyword.fetch!(opts, :scopes)

unless is_list(scopes) and scopes != [] do
  raise ArgumentError, "RequireScopes :scopes must be a non-empty list"
end

_ = Keyword.fetch!(opts, :error_handler)
```

```elixir
error_opts =
  Keyword.merge(opts,
    required_scopes: required,
    provided_scopes: scope_token_scopes(scope)
  )

conn
|> error_handler.auth_error(:insufficient_scope, error_opts)
|> Plug.Conn.halt()
```

**Wildcard/all/any algorithm to retain, changing input only** (`lib/sigra/plug/require_scopes.ex:99-111`):

```elixir
defp scope_has_wildcard?(scope), do: "*" in scope_token_scopes(scope)

defp has_required_scopes?(scope, required, :all) do
  token_scopes = MapSet.new(scope_token_scopes(scope))
  MapSet.subset?(MapSet.new(required), token_scopes)
end

defp has_required_scopes?(scope, required, :any) do
  token_scopes = scope_token_scopes(scope)
  Enum.any?(required, &(&1 in token_scopes))
end
```

The current `auth_method == :session` pass-through at lines 71-74 is explicitly an anti-pattern for this phase. `current_scope == nil` remains `:unauthenticated`; a real Scope with absent/unscoped private facts is `:insufficient_scope` with `provided_scopes: []`.

---

### Plug tests (test, request-response)

**Analogs:** `test/sigra/plug/fetch_bearer_test.exs`, `test/sigra/plug/fetch_session_test.exs`, and `test/sigra/plug/require_scopes_test.exs`.

**Focused Mox/Plug test setup** (`test/sigra/plug/fetch_session_test.exs:1-29`):

```elixir
use ExUnit.Case, async: true
import Plug.Test
import Mox

alias Sigra.Plug.FetchSession

setup :verify_on_exit!

@default_config %Sigra.Config{
  repo: Sigra.MockRepo,
  user_schema: :unused,
  session: [store: Sigra.MockSessionStore, ...]
}
```

**Mockable full-user lookup is already supported** (`test/support/mock_repo_behaviour.ex:5-15`):

```elixir
@callback get_by(module(), keyword()) :: struct() | nil
@callback get!(module(), term()) :: struct()
@callback get(module(), term()) :: struct() | nil
```

**Existing skip test shape** (`test/sigra/plug/fetch_bearer_test.exs:43-56`):

```elixir
conn =
  conn(:get, "/api/resource")
  |> Plug.Conn.put_req_header("authorization", "Bearer some_token")
  |> Plug.Conn.assign(:current_scope, existing_scope)

result = FetchBearer.call(conn, FetchBearer.init(default_opts()))
assert result.assigns.current_scope == existing_scope
```

**Required coverage allocation:**

- New `fetch_api_token_test.exs`: verifier success -> Mox `get` full user -> normal struct Scope; allowlisted facts only; missing/invalid/deleted user -> nil; existing Scope skip.
- New `fetch_jwt_test.exs`: verified JWT with string `sub`, full-user Scope, fact allowlist/no raw JWT, missing user rejection, existing Scope skip.
- New `fetch_app_session_test.exs`: public Plug exports; no credentials, no `:sigra_auth`, nil scope; existing authenticated Scope skip. This proves the Phase 245 boundary rather than inventing storage.
- Update `fetch_bearer_test.exs`: keep legacy prefix/`eyJ` dispatch tests and skip test; replace token-map assertions/source guards with normal Scope + private facts and deprecation guidance.
- Update `fetch_session_test.exs`: add Mox `get` expectation for full user, generated-like Scope compatibility, and deleted user. Preserve timeout/activity/remember-me and `:sigra_session` assertions.
- Rewrite `require_scopes_test.exs`: private-facts matrix for all/any/wildcard, nil Scope -> unauthenticated, legitimate Scope without facts -> 403, session/app facts without scopes -> 403, and protect against Scope fields spoofing authorization.
- Extend `test/sigra/scope/build_test.exs` using its local struct (`lines 12-25`) only if the shared helper needs a regression test for the normal host Scope shape; do not change `Sigra.Scope` unless the separate compatibility decision is explicitly resolved.

## Shared Patterns

### Scope and user loading

**Sources:** `lib/sigra/scope.ex:16-25`, `lib/sigra/jwt.ex:401-417`  
**Apply to:** explicit PAT/JWT pipelines and the FetchBearer compatibility branches.

Load a current user by the verifier-derived ID, make missing users unauthenticated, then build the generated-host Scope. Never send a token-shaped map to the host Scope.

### Authentication error handling

**Source:** `lib/sigra/plug/require_authenticated.ex:35-44`, `lib/sigra/plug/error_handler.ex:53-75`  
**Apply to:** all authentication and scope failures.

The fetchers set nil Scope; gates own error responses through the required host `error_handler` and halt after callback. `RequireScopes` retains the same handler and passes `required_scopes` / bounded `provided_scopes` only.

### Trusted request metadata

**Source:** `lib/sigra/plug/fetch_session.ex:83-87`  
**Apply to:** credential facts in the new explicit pipelines.

```elixir
conn
|> Plug.Conn.assign(:current_scope, scope)
|> Plug.Conn.put_private(:sigra_session, session)
```

Follow this library-private storage pattern, adding a distinct `:sigra_auth` key rather than putting credential state in `current_scope` or user-visible assigns. Construct a new allowlisted facts map on every successful credential authentication.

### Documentation contract testing

**Source:** `test/sigra/recipes/companion_lib_contract_test.exs:10-42`  
**Apply to:** the new credential-boundary documentation guard.

Use `ExUnit.Case, async: true`, `File.read!/1`, and specific required/forbidden markers so the contract fails loudly on stale implicit-fallback claims. The test should read all three edited guides and assert normative ownership plus explicit FetchSession/FetchAppSession/FetchAPIToken/FetchJWT descriptions; it must reject documentation that presents FetchBearer autodetection as the primary integration.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/sigra/plug/fetch_app_session.ex` | middleware | request-response | No existing public app-session verifier/foundation exists; Phase 245 deliberately owns persistence and verification. Copy only the Plug interface/fail-closed result from the session/bearer analogs. |

## Evidence Resolutions

1. **FetchAppSession is public and fail closed in Phase 243.** Its public Plug interface is locked in `243-CONTEXT.md`; there is no source verifier or storage seam to call. The established fetch failure behavior is assigning `current_scope: nil` (`fetch_session.ex:96-98`), and `RequireAuthenticated` reliably turns nil into the host error-handler/halt (`require_authenticated.ex:35-44`). Planning must explicitly prohibit raw-token parsing, browser fallback, private credential facts, schema/config, and persistence until Phase 245.
2. **FetchSession must load a full user, but cannot be mandated to call `Sigra.Scope.build/3` without a compatibility adapter.** Generated Scope modules require a user struct (`scope template:52-56`), so live lookup is required. Yet the current public FetchSession contract is `scope_module.new/1` (`fetch_session.ex:20-25`), focused tests use a non-struct `new/1` module (`fetch_session_test.exs:10-12`), and `Scope.build/3` invokes `struct/2` (`scope.ex:18-24`). An unconditional `/3` replacement is a source break. Plan the full-user lookup plus `new/1` construction and a compatibility test; only use `/3` if an adapter demonstrably retains support for existing non-struct `new/1` scope modules.

## Metadata

**Analog search scope:** `lib/sigra/plug`, `lib/sigra`, `test/sigra/plug`, `test/sigra`, `test/support`, `priv/templates/sigra.install/core`, `guides/`  
**Files scanned:** 17  
**Pattern extraction date:** 2026-08-12
