# Phase 244: PAT and Advanced JWT Truth Repair - Pattern Map

**Mapped:** 2026-08-12  
**Files analyzed:** 17 planned created/modified files  
**Analogs found:** 16 / 17

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/install/features/core.ex` | generator/config | transform | itself | exact repair |
| `priv/templates/sigra.install/core/api_token_controller.ex` | controller/template | request-response CRUD | `session_live.ex` + current template | role/data-flow split |
| `priv/templates/sigra.install/core/auth_api_token.ex` | context delegate/template | request-response CRUD | itself | exact repair |
| `priv/templates/sigra.install/core/token_controller.ex` | controller/template | request-response | itself | removal/negative contract |
| `lib/sigra/api_token.ex` | service | CRUD/transactional | itself | exact repair |
| `lib/sigra/auth.ex` | service facade | request-response | itself | exact repair |
| `lib/sigra/config.ex` | config/model | transform | itself | exact repair |
| `lib/sigra/jwt.ex` | service | request-response/transactional | itself | exact repair |
| `lib/sigra/jwt/signer.ex` | utility/service | transform | itself | exact repair |
| `lib/sigra/jwt/validator.ex` (if introduced) | utility/service | transform | `lib/sigra/jwt.ex` | role-match |
| `lib/sigra/jwt/refresh_token.ex` | service/model | CRUD/transactional | itself | exact repair |
| `test/sigra/install/features/core_test.exs` | test | transform | itself | exact repair |
| `test/sigra/install/api_token_generator_test.exs` | test | transform | itself | exact repair |
| `test/sigra/api_token_test.exs` | test | CRUD | itself | role-match |
| `test/sigra/jwt_test.exs` and `test/sigra/jwt/signer_test.exs` | test | request-response/transform | themselves | exact repair |
| `test/sigra/jwt_refresh_audit_cofate_test.exs` | test | transactional/concurrent | itself | exact repair |
| `test/sigra/planning/phase_244_generated_auth_runtime_proof_test.exs` (new, preferred) | test | generated-host/file-I/O | `phase_238_generated_auth_runtime_proof_test.exs` | role-match |

## Pattern Assignments

### `lib/sigra/install/features/core.ex` (generator/config, transform)

**Analog:** same file, especially the feature predicates and injected-router assembly.

**Feature split pattern** ([lines 57-67](../../../lib/sigra/install/features/core.ex#L57-L67)):

```elixir
live? = Keyword.get(opts, :live, true)
api? = Keyword.get(opts, :api, false) || Keyword.get(opts, :jwt, false)
jwt? = Keyword.get(opts, :jwt, false)

base_files(binding) ++
  ui_files(binding, live?) ++
  api_files(binding, api?) ++
  jwt_files(binding, jwt?)
```

Repair this exact seam: make `api?` mean only `--api`, retain an independent `jwt?`, and pass them independently into files, injections, config, and post-install instructions. Do not encode the old implication in a second helper; `api_enabled?/1` currently repeats it at [lines 1005-1008](../../../lib/sigra/install/features/core.ex#L1005-L1008).

**Host artifact group pattern** ([lines 329-352](../../../lib/sigra/install/features/core.ex#L329-L352)):

```elixir
defp api_files(_binding, false), do: []

defp api_files(binding, true) do
  [...]
  [{:eex, "core/api_token_migration.exs", ...},
   {:eex, "core/user_api_token.ex", ...},
   {:eex, "core/api_token_controller.ex", ...}]
end

defp jwt_files(_binding, false), do: []
```

Use separate artifact groups. JWT-only output must have no PAT migration/schema/controller/delegates/config injection; API-only output must have no JWT controller/config/route requirement.

**Browser sudo route pattern** ([lines 486-489](../../../lib/sigra/install/features/core.ex#L486-L489), [533-535](../../../lib/sigra/install/features/core.ex#L533-L535)):

```elixir
pipeline :require_sudo do
  plug Sigra.Plug.RequireSudo, error_handler: #{web_module}.AuthErrorHandler
end

scope "/users", #{web_module} do
  pipe_through [:browser, :require_authenticated, :require_sudo]
```

Place PAT list/create/revoke routes under this browser scope. `:browser` preserves CSRF and `fetch_current_scope`; do not retain the bearer-management route block.

**Explicit credential pipeline pattern** ([lines 749-756](../../../lib/sigra/install/features/core.ex#L749-L756)):

```elixir
pipeline :api_authenticated do
  plug Sigra.Plug.FetchBearer
  plug Sigra.Plug.RequireAuthenticated,
    error_handler: #{web_module}.AuthErrorHandler
end
```

This is the source to replace for fresh API hosts: use Phase 243's `FetchAPIToken` (and a distinct `FetchJWT` pipeline where JWT-protected resource routes are emitted), preserving the `RequireAuthenticated` error-handler option. Do not copy `FetchBearer` into new output.

### `priv/templates/sigra.install/core/api_token_controller.ex` (controller/template, request-response CRUD)

**Analogs:** current controller for JSON/error/raw-secret conventions; `priv/templates/sigra.install/core/session_live.ex` for owner-derived browser-session mutation.

**Scope-derived owner pattern** ([current controller lines 25-56](../../../priv/templates/sigra.install/core/api_token_controller.ex#L25-L56)):

```elixir
scope = conn.assigns.current_scope
user = scope_user(scope)

case Auth.create_api_token(user, attrs, scope: scope) do
  {:ok, raw_key, token} ->
    conn
    |> put_status(:created)
    |> json(%{data: Map.merge(token_json(token), %{raw_key: raw_key})})
```

Keep the owner derived from `current_scope` and raw token returned only on successful creation. Change revoke to pass that same owner explicitly; never read an owner ID from params. The current ID-only call at [line 79](../../../priv/templates/sigra.install/core/api_token_controller.ex#L79) is the vulnerability to remove.

**Browser-session mutation analog** ([`session_live.ex` lines 103-108](../../../priv/templates/sigra.install/core/session_live.ex#L103-L108)):

```elixir
def handle_event("revoke", %{"token" => encoded_token}, socket) do
  hashed_token = Base.url_decode64!(encoded_token)
  user = socket.assigns.current_scope.user
  Auth.revoke_session(user, hashed_token)
end
```

Whether controller or LiveView is selected, follow this ownership direction: Scope -> user -> context call. The controller choice remains discretionary; there is no exact existing browser PAT UI analog.

**Error/response shape pattern** ([lines 56-88](../../../priv/templates/sigra.install/core/api_token_controller.ex#L56-L88)) uses `{:error, changeset}` for validation and a non-disclosing `:not_found` response for an absent/foreign record. Preserve the existing `changeset_errors/1` helper at [lines 141-149](../../../priv/templates/sigra.install/core/api_token_controller.ex#L141-L149) if JSON remains the presentation.

### `priv/templates/sigra.install/core/auth_api_token.ex` (context delegate/template, request-response CRUD)

**Analog:** same template ([lines 1-47](../../../priv/templates/sigra.install/core/auth_api_token.ex#L1-L47)).

```elixir
def create_api_token(user, attrs, opts \\ []) do
  with :ok <- forbid_api_token_operation(user, "api_token.create", opts) do
    Sigra.Auth.create_api_token(sigra_config(), user, attrs)
  end
end

def revoke_api_token(token_id, opts \\ []) do
  with :ok <- forbid_api_token_operation(nil, "api_token.revoke", opts) do
    Sigra.Auth.revoke_api_token(sigra_config(), token_id)
  end
end
```

Keep host-owned delegates thin and preserve the impersonation guard at [lines 48-78](../../../priv/templates/sigra.install/core/auth_api_token.ex#L48-L78). Change the revoke delegate signature to require the Scope-derived owner and call the new constrained Sigra facade. Render this template for API hosts only; split any JWT host issuance seam from this PAT template.

### `priv/templates/sigra.install/core/token_controller.ex` (controller/template, request-response)

**Analog:** same file is a removal target, not a copy target.

The password grant and request-selected authority are currently explicit at [lines 25-49](../../../priv/templates/sigra.install/core/token_controller.ex#L25-L49):

```elixir
def create(conn, %{"email" => email, "password" => password} = params) do
  scopes = params["scopes"] || []
  case Auth.get_user_by_email_and_password(email, password) do
    ... -> issue_jwt_tokens(conn, user, scopes)
  end
end
```

Do not adapt this into a new public exchange endpoint. Remove it from generated JWT output (and routes) and use a documented host-callable context function with host-selected user/scopes. Preserve its negative source-contract assertions in generator tests.

### `lib/sigra/api_token.ex` and `lib/sigra/auth.ex` (services, CRUD/transactional)

**Analogs:** `APIToken.create/3` for server-side scope validation and audit co-fate; `APIToken.revoke/2` for revoke Multi; the Auth facade delegates at [lines 2207-2247](../../../lib/sigra/auth.ex#L2207-L2247).

**Validation-before-write pattern** ([`api_token.ex` lines 83-92](../../../lib/sigra/api_token.ex#L83-L92)):

```elixir
with :ok <- validate_prefix(prefix),
     :ok <- validate_name(attrs),
     :ok <- ScopeRegistry.validate_scopes(config, Map.get(attrs, :scopes, [])),
     :ok <- validate_expiry(api_token_opts, attrs) do
  Telemetry.span([:sigra, :api_token, :create], %{user_id: user.id}, fn ->
    do_create(config, user, attrs, prefix)
  end)
end
```

Scope checking must stay in this library boundary. `ScopeRegistry.validate_scopes/2` accepts only valid, registered strings at [lines 105-120](../../../lib/sigra/api_token/scope_registry.ex#L105-L120); Phase 244 should make the configured allowlist the authority, not controller request filtering.

**Transactional mutation pattern** ([`api_token.ex` lines 494-518](../../../lib/sigra/api_token.ex#L494-L518)):

```elixir
multi =
  Multi.new()
  |> Multi.update(:token, changeset)
  |> Audit.log_multi_safe("api.token_revoke", audit_opts)

case config.repo.transaction(multi) do
  {:ok, %{token: updated} = changes} ->
    Audit.emit_telemetry_from_changes(changes)
    {:ok, updated}
  {:error, :token, %Ecto.Changeset{} = cs, _} -> {:error, cs}
end
```

Add a public owner-constrained `revoke_for_user(config, token_id, owner)` (and matching `Sigra.Auth` delegate) by replacing `repo.get(schema, token_id)` at [lines 474-480](../../../lib/sigra/api_token.ex#L474-L480) with one query constrained on both ID and `user_id`. Keep the audit/update/telemetry branch intact and return `{:error, :not_found}` for foreign IDs.

### `lib/sigra/config.ex`, `lib/sigra/jwt.ex`, `lib/sigra/jwt/signer.ex`, and optional `lib/sigra/jwt/validator.ex` (config/services, transform/request-response)

**Analogs:** Config's nested NimbleOptions schema at [lines 820-870](../../../lib/sigra/config.ex#L820-L870); `JWT.generate_tokens/4`, `JWT.verify_access/2`, and `Signer.create_signer/1`.

**Config extension pattern**:

```elixir
jwt: [
  type: :keyword_list,
  default: [],
  keys: [
    algorithm: [type: {:in, ["HS256", "RS256", "ES256"]}, default: "HS256"],
    issuer: [type: {:or, [:string, nil]}, default: nil]
  ]
]
```

Extend this single schema with a non-empty accepted audience list and a configured protected-header `typ`; validate malformed values before serving. Do not add validation only at controllers.

**Configured signer boundary** ([`signer.ex` lines 48-66](../../../lib/sigra/jwt/signer.ex#L48-L66)):

```elixir
algorithm = Keyword.get(jwt_config, :algorithm, "HS256")

case algorithm do
  "HS256" -> Joken.Signer.create("HS256", key)
  "RS256" -> Joken.Signer.create("RS256", %{"pem" => pem})
  "ES256" -> Joken.Signer.create("ES256", %{"pem" => pem})
end
```

Keep signer selection entirely config-owned. Verification must pass the configured signer first; protected header inspection cannot select a signer.

**Issue/verify placement pattern** ([`jwt.ex` lines 77-107](../../../lib/sigra/jwt.ex#L77-L107), [127-149](../../../lib/sigra/jwt.ex#L127-L149)):

```elixir
claims = build_claims(config, user, scopes, now, access_ttl)
{:ok, jwt, _full_claims} = Joken.generate_and_sign(%{}, claims, signer)

case Joken.verify(jwt_string, signer) do
  {:ok, claims} -> ...
  {:error, _reason} -> {:error, :invalid_token}
end
```

Repair `verify_access/2` to use Joken's verify-and-validate/required-claims configuration, then check `typ` after verification succeeds. Require `iss`, `aud`, `sub`, `iat`, `exp`, `jti`; validate optional `nbf`; accept scalar `aud` or a non-empty all-string array with exact intersection against configured audiences. In `build_claims/5`, reserve server claims: the current `Map.merge(base_claims, extra)` at [lines 371-391](../../../lib/sigra/jwt.ex#L371-L391) lets custom claims overwrite security fields. Merge extra first then server-owned claims, or reject reserved keys.

If the validator becomes nontrivial, introduce `Sigra.JWT.Validator` as a narrow pure helper and copy `JWT`'s error normalization (`{:error, :invalid_token}`) rather than creating a new public error vocabulary. No exact dedicated validator exists.

### `lib/sigra/jwt/refresh_token.ex` and `lib/sigra/jwt.ex` (services, transactional)

**Analog:** audited co-fate in `JWT.refresh/3`, plus `RefreshToken.build_rotate_persist_multi/5`.

**Existing co-fate Multi** ([`jwt.ex` lines 303-335](../../../lib/sigra/jwt.ex#L303-L335)):

```elixir
multi =
  Multi.new()
  |> RefreshToken.build_rotate_persist_multi(token_record, metadata, config, opts)
  |> APIToken.append_api_token_jwt_audit_to_multi("api.jwt_refresh", refresh_audit_opts)

case config.repo.transaction(multi) do
  {:ok, changes} ->
    {new_raw, new_record, scopes} = changes.jwt_refresh_new_token
    finalize_refresh_response(config, new_record, scopes, new_raw)
  {:error, _step, _reason, _changes} -> {:error, :jwt_refresh_aborted}
end
```

Make this one transaction shape authoritative for audit-on *and* audit-off. Do not call `rotate_with_reuse_meta/3` from the non-audited branch because it classifies, `update!`s, and inserts outside one transaction ([`refresh_token.ex` lines 78-106](../../../lib/sigra/jwt/refresh_token.ex#L78-L106)). Return raw replacement and access credentials only after `Repo.transaction/1` succeeds; the existing `finalize_refresh_response/4` already signs after commit at [lines 354-368](../../../lib/sigra/jwt.ex#L354-L368).

**Locked classify/mutate pattern to add:** query the digest-addressed refresh record inside the transaction with `lock: "FOR UPDATE"`, then classify its `sent_to` metadata while locked. Preserve opaque digest storage from [`refresh_token_insert_tuple/4` lines 323-341](../../../lib/sigra/jwt/refresh_token.ex#L323-L341). Reuse must call the family-revoke Multi before returning `:reuse_detected`; rotate must supersede and insert in the same Multi. Audit remains only an appended Multi step, not a transaction-mode switch.

### Test files (tests; generator transform, JWT verification, and transactional concurrency)

**Generator matrix analog:** [`core_test.exs` lines 253-272](../../../test/sigra/install/features/core_test.exs#L253-L272) currently asserts the old `--jwt implies --api` behavior. Replace it with the four combinations and both positive and negative artifact assertions. Follow the injection-marker test style at [lines 502-520](../../../test/sigra/install/features/core_test.exs#L502-L520).

**Template contract analog:** [`api_token_generator_test.exs` lines 164-201](../../../test/sigra/install/api_token_generator_test.exs#L164-L201) renders templates and asserts named actions/delegates/raw-key-once. Extend it with browser/sudo route, Scope-owner delegate, and absent JWT password grant assertions; retain source contracts as fast checks.

**JWT unit-test analog:** [`jwt_test.exs` lines 56-84](../../../test/sigra/jwt_test.exs#L56-L84) verifies generated claims, and [lines 136-184](../../../test/sigra/jwt_test.exs#L136-L184) exercises verification/error normalization. Add individual deterministic cases for algorithm mismatch, header `typ`, each required claim, `iss`, scalar/array/malformed `aud`, optional `nbf`, and reserved custom claims.

**Postgres atomicity analog:** [`jwt_refresh_audit_cofate_test.exs` lines 168-231](../../../test/sigra/jwt_refresh_audit_cofate_test.exs#L168-L231) proves audit-on success and rollback; [lines 241-255](../../../test/sigra/jwt_refresh_audit_cofate_test.exs#L241-L255) proves reuse after rotation. Extend this file for audit-off rollback and two concurrent calls using explicit process `send`/`receive` barriers—no sleeps. Assert one rotate response and one post-commit reuse response, plus exact final family/audit rows.

**Fresh-host proof analog:** [`phase_238_generated_auth_runtime_proof_test.exs` lines 39-43](../../../test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs#L39-L43) uses local file contracts, and [lines 173-179](../../../test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs#L173-L179) prohibits sleeps/timers. Add a phase-specific proof preferred over expanding Phase 238: two disposable hosts (`--api`, `--jwt`), install/migrate/compile/runtime smoke each, and assert each other's artifacts are absent.

## Shared Patterns

### Browser authentication, CSRF, and recent auth

**Sources:** [`core.ex` lines 486-489](../../../lib/sigra/install/features/core.ex#L486-L489); [`require_sudo.ex` lines 54-75](../../../lib/sigra/plug/require_sudo.ex#L54-L75).

```elixir
cond do
  is_nil(conn.assigns[:current_scope]) ->
    conn |> error_handler.auth_error(:unauthenticated, opts) |> Plug.Conn.halt()
  sudo_fresh?(conn, sudo_window) -> conn
  true -> conn |> error_handler.auth_error(:stale_sudo, opts) |> Plug.Conn.halt()
end
```

Apply to all PAT list/create/revoke routes through the browser + authenticated + sudo pipeline, never bearer credential management.

### Owner constraints and scope allowlists

**Sources:** [`api_token.ex` lines 83-92](../../../lib/sigra/api_token.ex#L83-L92); [`scope_registry.ex` lines 105-120](../../../lib/sigra/api_token/scope_registry.ex#L105-L120).

All library mutations derive/receive owner from Scope and must constrain DB lookup with both token ID and owner ID. Validation is a library precondition so direct host calls cannot bypass the server’s scope registry.

### Error and transaction policy

**Sources:** [`api_token.ex` lines 128-143](../../../lib/sigra/api_token.ex#L128-L143); [`jwt.ex` lines 320-350](../../../lib/sigra/jwt.ex#L320-L350).

Use `Ecto.Multi` plus `Repo.transaction` for state plus audit. Emit telemetry after committed changes; map transaction errors to the documented result and never return newly issued credentials from an aborted transaction.

### Explicit credential-kind plugs

**Sources:** [`fetch_api_token.ex` lines 27-47](../../../lib/sigra/plug/fetch_api_token.ex#L27-L47); [`fetch_jwt.ex` lines 31-60](../../../lib/sigra/plug/fetch_jwt.ex#L31-L60).

Both plugs authenticate only their credential kind, reload the live host user, construct the normal Scope, and assign nil on failure for downstream gates. Fresh generated routes must name these plugs explicitly rather than use `FetchBearer` compatibility dispatch.

## No Analog Found

| File | Role | Data Flow | Reason |
|---|---|---|---|
| `lib/sigra/jwt/validator.ex` (optional) | utility | transform | No dedicated Joken required-claims/header-contract adapter exists; keep it narrow and copy JWT error normalization. |
| `test/sigra/planning/phase_244_generated_auth_runtime_proof_test.exs` | test | generated-host/file-I/O | Phase 238 proves a related generated-auth harness, but no existing independent API/JWT fresh-host smoke has this exact contract. |

## Metadata

**Analog search scope:** `lib/sigra`, `priv/templates/sigra.install/core`, `test/sigra`  
**Files scanned:** 18 primary source/template/test files  
**Pattern extraction date:** 2026-08-12
