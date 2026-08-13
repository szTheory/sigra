# Phase 246: Hosted and Direct Login Ceremonies - Pattern Map

**Mapped:** 2026-08-12  
**Files analyzed:** 17 likely installer, generated-host, library, and proof changes  
**Analogs found:** 15 / 17

> Phase 246 currently has no `246-CONTEXT.md` or `246-RESEARCH.md`. This map derives its file set from `ROADMAP.md:97-109` and `REQUIREMENTS.md:22-24`. Keep Lockspire/OAuth-server behavior, native SDK/PWA work, Crosswake changes, and unrelated API/JWT generation out of scope.

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/mix/tasks/sigra.install.ex` | config/CLI | transform | existing task | modify |
| `lib/sigra/install/features/core.ex` | generator/config | file-I/O | existing API/JWT option groups | exact |
| `priv/templates/sigra.install/core/user_app_session_family.ex` | model | CRUD | `core/user_api_token.ex` | role-match |
| `priv/templates/sigra.install/core/user_app_session_token.ex` | model | CRUD | `core/user_api_token.ex` | role-match |
| `priv/templates/sigra.install/core/app_session_migration.exs` | migration | batch | `core/api_token_migration.exs` | role-match |
| `priv/templates/sigra.install/core/auth_app_session.ex` | service delegate | request-response | `core/auth_jwt.ex` | role-match |
| `priv/templates/sigra.install/core/app_session_controller.ex` | controller | request-response | `core/session_controller.ex` | role-match |
| `priv/templates/sigra.install/core/app_session_html.ex` (if a distinct continuation page is required) | component/view | request-response | `core/login_html.ex` | partial |
| `lib/sigra/app_session.ex` | service/facade | transactional request-response | existing module; `Sigra.JWT` facade | modify |
| `lib/sigra/app_session/login.ex` (or the equivalent bounded additions to `app_session.ex`) | service | stateful request-response | `Example.Accounts.CrosswakeContinuations` | partial, mechanics only |
| `lib/sigra/config.ex` | config | transform | existing `:app_session` validator | modify |
| `test/sigra/install/features/core_test.exs` | test | file-I/O/matrix | existing option matrix | exact |
| `test/sigra/install/*app_session*_generator_test.exs` | generator test | file-I/O | `api_token_generator_test.exs` | exact |
| `test/sigra/app_session/*login*_test.exs` | service test | request-response | `app_session_test.exs`, `crosswake_continuations_test.exs` | partial |
| `test/example/lib/example/accounts/{user_app_session_family,user_app_session_token}.ex` | generated-host proof model | CRUD | test-local Phase 245 schemas / generated PAT schema | role-match |
| `test/example/lib/example_web/controllers/app_session_controller.ex` and router/config wiring | generated-host proof controller | request-response | `session_controller.ex`, `crosswake_controller.ex` | role-match |
| `test/example/test/example_web/controllers/app_session_controller_test.exs` plus deterministic browser/proof runner if needed | integration/browser test | request-response | `crosswake_controller_test.exs`, Phase 240.3 proof test | role-match |

## Pattern Assignments

### `lib/mix/tasks/sigra.install.ex` and `lib/sigra/install/features/core.ex` (CLI/config and generator, file-I/O)

**Analog:** independent `--api` / `--jwt` selection in `lib/mix/tasks/sigra.install.ex:50-75, 113-147` and `lib/sigra/install/features/core.ex:57-68, 329-354`.

Add `app_sessions: :boolean` and `app_password_login: :boolean` to the Mix switches and false defaults, then carry each as a separate binding and `opts` key. Do not reproduce the stale task documentation claim that JWT implies API: `Core.files/1` already treats the groups independently.

```elixir
opts = Keyword.get(binding, :opts, [])

live? = Keyword.get(opts, :live, true)
api? = Keyword.get(opts, :api, false)
jwt? = Keyword.get(opts, :jwt, false)

base_files(binding) ++
  ui_files(binding, live?) ++
  api_files(binding, api?) ++
  jwt_files(binding, jwt?)
```

Use the same separate-predicate shape for `app_sessions?` and `app_password_login?`. `--app-password-login` must fail closed or emit no direct-login endpoint unless app-session storage is also selected; neither flag may add API-token/JWT templates, dependencies, routes, or configuration. Add an explicit four-way app-feature matrix to `core_test.exs`, modeled on `:275-309`, including negative assertions for API/JWT artifacts.

Migration slots must be declared in `Core.migrations/1` before files use `migration_target/3` (`core.ex:70-100, 161-179`). This is the installer seam that gives fresh hosts deterministic, re-run-safe migration timestamps; do not hand-roll timestamps in a template.

### Generated app-session schemas and migration (models/migration, CRUD/batch)

**Analogs:** `priv/templates/sigra.install/core/user_api_token.ex:17-51` and `core/api_token_migration.exs:1-38`.

Follow the host-owned-schema pattern: Ecto schemas contain fields, association, and a deliberately thin changeset; `Sigra.AppSession` remains the sole lifecycle authority. Keep the Phase 245 family/token shape intact: family `user_id`, `client_ref`, `absolute_expires_at`, `revoked_at`; token `family_id`, typed `kind`, digest, expiry, consumption/supersession/revocation fields. The generated migration must create the digest uniqueness and family/user/lifecycle indexes needed by Phase 245's locked access/refresh queries.

```elixir
create table(:user_api_tokens, Keyword.merge(@prefix_opts, primary_key: false)) do
  add :id, :binary_id, primary_key: true
  add :user_id, references(:<%= table_name %>, Keyword.merge(@ref_opts, type: :binary_id, on_delete: :delete_all)), null: false
  add :hashed_token, :binary, null: false
  ...
end

create unique_index(:user_api_tokens, [:hashed_token], @prefix_opts)
create index(:user_api_tokens, [:user_id, :revoked_at, :expires_at], @prefix_opts)
```

Preserve the adapter branches and Postgres `@auth_prefix`/foreign-reference options from the API-token migration. Do not put raw access tokens, raw refresh tokens, PKCE verifier/state, password, MFA proof, or redirect URL into either app-session table. A short-lived one-time authorization-code/challenge record needs a separate digest-only schema/table if durable storage is chosen; no existing generated model exactly matches that record.

### `priv/templates/sigra.install/core/auth_app_session.ex` (host facade/delegate, request-response)

**Analog:** `priv/templates/sigra.install/core/auth_jwt.ex:1-45`.

Keep generated host policy separate from Sigra's lifecycle library. The template should build its one validated config by extending `Auth.sigra_config/0` with generated family/token schema modules and the static registered first-party client configuration; it should delegate issue/refresh/revoke to `Sigra.AppSession` rather than duplicate queries.

```elixir
def create_jwt_tokens(user) do
  Sigra.JWT.generate_tokens(sigra_config(), user, jwt_scopes_for(user),
    user_token_schema: <%= context_module %>.UserToken
  )
end

@doc false
def sigra_config do
  base_config = <%= context_module %>.sigra_config()
  %{base_config | jwt: jwt}
end
```

**Adaptation:** unlike JWT's server-only issuance delegate, this phase needs a narrow public-client ceremony interface. The controller must pass only a server-validated registered `client_ref`, exact allowed callback, and verified user/MFA result to the delegate. Never accept scopes, client-selected policy, a client secret, or a callback URL selected after validation.

### `lib/sigra/app_session.ex`, `lib/sigra/app_session/login.ex`, and `lib/sigra/config.ex` (ceremony service/config, transactional request-response)

**Analogs:** current opaque issuance at `lib/sigra/app_session.ex:21-56`, input/digest verification at `:382-435`, and configuration validation at `lib/sigra/config.ex:882-887, 1119-1160`.

Hosted and direct success must converge on the existing `AppSession.issue/4` contract; do not create a second access/refresh representation. Existing issuance already makes the required boundary explicit:

```elixir
{access_raw, access_digest} = Token.generate_hashed_token()
{refresh_raw, refresh_digest} = Token.generate_hashed_token()

multi =
  Multi.new()
  |> Multi.insert(:family, family)
  |> Multi.run(:tokens, fn repo, %{family: persisted_family} ->
    insert_tokens(repo, settings, persisted_family.id, access_digest, refresh_digest, now)
  end)
```

Extend the `:app_session` config validator with a strict static public-client registry and direct-login policy only if those values are library-owned. Validate client ref, exact callback list, and policy at issuance/start time; do not overload `:jwt`, browser `:session`, or PAT options. `valid_client_ref/1` is currently only syntactic (`app_session.ex:425-426`), so it cannot be treated as registration/authorization.

For a one-time code/challenge state machine, the closest *mechanical* analog is `Example.Accounts.CrosswakeContinuations` — digest all externally presented values at issue (`crosswake_continuations.ex:83-117`) and atomically claim exactly one live row on exchange (`:120-136`). Its PKCE/state comparison is also the right primitive:

```elixir
if secure_digest_match?(continuation.state_digest, digest(state)) and
     secure_digest_match?(continuation.pkce_challenge_digest, pkce_challenge(verifier)) do
  :ok
else
  {:error, :oauth_state_or_pkce_failure}
end
```

**Do not copy Crosswake ownership:** it imports Crosswake evaluator/types and creates an AuthReturn envelope. Phase 246 has no Crosswake dependency, route, return envelope, or evaluator. Adapt only digest storage, strict 60-second expiry, consume-once-before-result, scalar validation, and constant-time comparison. PKCE must be S256 (base64url SHA-256 of verifier), not the Crosswake analog's test-local raw SHA digest convention.

No exact analog exists for an opaque, five-minute direct-password MFA challenge. Model it as a single-use, digest-only pending login bound to registered client and user, with an indistinguishable public failure response. It must be consumed/expired before issuing credentials and cannot be upgraded by a browser session cookie alone.

### Generated app-session controller/routes (controller, request-response)

**Analogs:** browser login at `priv/templates/sigra.install/core/session_controller.ex:68-100`, route injection at `lib/sigra/install/features/core.ex:482-540, 575-610`, and return-input hardening at `test/example/lib/example_web/controllers/crosswake_controller.ex:28-67`.

The browser controller convention is explicit login success vs uniform local failure:

```elixir
case Auth.authenticate_user(email, password) do
  {:ok, user} ->
    conn |> put_flash(:info, info) |> UserAuth.log_in_user(user, user_params)

  _ ->
    conn
    |> put_flash(:error, "Invalid email or password")
    |> put_flash(:email, String.slice(email, 0, 160))
    |> redirect(to: ~p"/users/log_in")
end
```

Reuse the context's `authenticate_user/2` only behind the explicit direct-login feature gate and map credential, confirmation, lockout, and policy denials to one app-facing failure shape. Policy requiring hosted browser login returns only the specified `browser_required` result; it must not attempt password verification then leak a more specific outcome.

For hosted start/continue/exchange, register all route injections together with a dedicated rate-limit key (copy `rate_limit_pipelines/1` and `rate_limited_scopes/2` at `core.ex:551-610`). Browser login remains the existing `/users/log_in` controller and normal Sigra cookie session. Store only transient server-side correlation data; the callback handler must accept exactly its allowlisted scalar keys, set `Referrer-Policy: no-referrer`, consume the code once, and redirect only to the callback selected from the registered client record. The Crosswake controller's strict key check is the useful shape:

```elixir
input = Map.take(params, @allowed_return_keys)

if Map.keys(params) |> Enum.sort() == Enum.sort(@allowed_return_keys) and
     Enum.all?(input, fn {_key, value} -> is_binary(value) and value != "" end) do
  {:ok, input}
else
  {:error, :invalid_return_input}
end
```

Do not turn this into OAuth authorization-server endpoints, discovery, dynamic registration, consent, broad callback wildcard matching, or a WebView flow.

### Direct MFA handling (controller/service, request-response)

**Analogs:** MFA pending browser state in `lib/sigra/auth.ex:2024-2040`, session expiry in `lib/sigra/plug/fetch_session.ex:153-179`, and verification delegates in `core/auth.ex:737-753`.

The existing browser flow uses `:mfa_pending` only after password success and bounds it to five minutes:

```elixir
session_type = if mfa_enabled, do: :mfa_pending, else: :standard
metadata = %{type: session_type, ip: login_ip}

case create_session(config, updated_user, metadata) do
  {:ok, session} ->
    result = if mfa_enabled, do: Map.put(result, :mfa_required, true), else: result
    {:ok, updated_user, result}
end
```

```elixir
pending_timeout = Keyword.get(session_config, :mfa_pending_timeout, 300)
{nil, pending_timeout}
```

Copy its *ordering* (password first, then a bounded MFA-pending state, then TOTP/backup-code verification) but not its browser cookie/session transport. The app challenge response must be opaque: it can identify only a random challenge handle and generic allowed next action, never the user, factor enrollment, lockout cause, or credential validity. Reuse generated `Auth.mfa_verify/2` / `mfa_verify_backup/2` rather than reimplementing TOTP or backup-code consumption, and make failed/expired/replayed/mismatched challenges indistinguishable.

### Tests and generated-host proof (tests, request-response/file-I/O)

**Installer analogs:** `test/sigra/install/features/core_test.exs:253-309, 368-380` and `test/sigra/install/api_token_generator_test.exs:462-509`.

Test the complete `--app-sessions` × `--app-password-login` × `--api` × `--jwt` matrix at the pure `Core.files/1`, `Core.injections/1`, migration-slot, and rendered-template levels. Assert each unrelated feature's templates/config/router snippets are absent. Extend the golden generated-host inventory only for the new emitted files; do not alter user-owned app code or cached planning files.

**Ceremony analogs:** `test/example/test/example_web/controllers/crosswake_controller_test.exs:27-107, 187-237` and `test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs:29-47, 151-254`.

Use deterministic injected time / explicit timestamps and database claim assertions — never sleeps — to prove: exact callback rejection, missing/list/extra parameter rejection, state and S256 verifier mismatch, expiry at 60 seconds, exchange replay, code consumption on terminal failure, no raw secret in redirects/logged telemetry, uniform direct-login failures, opaque 5-minute MFA challenge expiry/replay, browser-required policy, and equal app-session results from both successful ceremonies. If Phase 246 includes a generated-host browser proof, follow the existing real-cookie-jar/role-selector pattern, but do not reuse the Crosswake browser suite or edit its routes/packages.

## Shared Patterns

### Phase 245 opaque-session authority

**Sources:** `lib/sigra/app_session.ex:21-70, 382-435`  
**Apply to:** hosted code exchange and direct password/MFA success.

```elixir
{:ok,
 %{
   access_token: access_raw,
   refresh_token: refresh_raw,
   family_id: persisted_family.id,
   expires_in: settings.access_ttl
 }}
```

Return raw credentials only after the persistence transaction succeeds. A ceremony may select a trusted registered client ref, but never client-selected scopes or a credential kind different from `:app_session`.

### Bounded credential facts and normal Scope

**Source:** `lib/sigra/plug/fetch_app_session.ex:36-48`, `credential_auth.ex:29-37`  
**Apply to:** generated app-authenticated API pipeline only after `FetchAppSession` succeeds.

```elixir
CredentialAuth.put_verified_scope(conn, scope_module, user, :app_session, %{
  id: session.token_id,
  family_id: session.family_id,
  scopes: [],
  auth_method: :app_session,
  assurance: []
})
```

Do not use browser cookies as an app bearer fallback, or export code/challenge/client callback values in `conn.private`.

### Secure browser correlation

**Source:** `test/example/lib/example_web/controllers/crosswake_controller.ex:51-130`  
**Apply to:** hosted start/continuation/callback only.

Take (delete) transient verifier transport before completing; prune expired entries; compare matching handles/state with `Plug.Crypto.secure_compare/2`; reject all malformed values with the same recovery behavior. This is a mechanics-only analog: no Crosswake evaluator, authority state, session adapter, or envelope belongs in Phase 246.

### Rate limiting and response discipline

**Sources:** `lib/sigra/install/features/core.ex:551-610`, `priv/templates/sigra.install/core/session_controller.ex:76-99`, `core/mfa_challenge_controller.ex:40-84`  
**Apply to:** direct-password start and MFA completion; optionally hosted start/exchange as abuse-sensitive public endpoints.

Create explicit generated rate-limit routes/pipelines, preserve host `AuthErrorHandler` behavior, and make every app-facing credential/MFA denial uninformative. Existing browser flash wording and HTML rendering are not the direct-app protocol response contract.

## No Analog Found

| File/Concern | Role | Data Flow | Reason / planner direction |
|---|---|---|---|
| Digest-only, app-bound authorization-code schema/service | model/service | one-time request-response | Crosswake continuation is a useful state-machine analog but is coupled to Crosswake types and not reusable. Create a small host-owned schema/service with separate code digest, client ref, callback binding, state/PKCE digest, expiry, and terminal consumption fields. |
| Opaque direct-login MFA challenge | service/model | stateful request-response | Browser MFA uses a session cookie and `:mfa_pending`; no app protocol challenge exists. Build a five-minute, single-use server-side challenge with uniform public errors; reuse only Sigra MFA factor verification. |
| Static first-party app registry and exact callback allowlist | config | transform | `AppSession.client_ref` is presently syntactic only. Add the narrowest validated generated-host configuration/registry necessary; do not implement dynamic client registration or OAuth-server features. |

## Metadata

**Analog search scope:** `lib/mix/tasks/sigra.install.ex`, `lib/sigra/{install/features/core,app_session,config,auth,mfa,plug}`, `priv/templates/sigra.install/core`, installer tests, Phase 245 artifacts, and the `test/example` browser/Crosswake proof strictly as a continuation mechanics analog.  
**Files scanned:** 31  
**Pattern extraction date:** 2026-08-12
