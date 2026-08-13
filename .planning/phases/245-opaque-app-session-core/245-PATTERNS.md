# Phase 245: Opaque App-Session Core - Pattern Map

**Mapped:** 2026-08-12  
**Files analyzed:** 16 likely library, installer, and test changes  
**Analogs found:** 15 / 16

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/app_session.ex` | service | CRUD / request-response | `lib/sigra/jwt.ex` | role-match |
| `lib/sigra/app_session/refresh_token.ex` | service | transactional rotation | `lib/sigra/jwt/refresh_token.ex` | exact |
| `lib/sigra/plug/fetch_app_session.ex` | middleware | request-response | `lib/sigra/plug/fetch_api_token.ex` | exact |
| `lib/sigra/plug/credential_auth.ex` | utility | transform | existing module | modify |
| `lib/sigra/auth.ex` | service/facade | event-driven revocation | existing module | modify |
| `lib/sigra/account/deletion.ex` | service | transactional event-driven | existing module | modify |
| `lib/sigra/config.ex` | config | transform | existing module | modify |
| `priv/templates/sigra.install/core/user_app_session.ex` | model | CRUD | `core/user_api_token.ex` | role-match |
| `priv/templates/sigra.install/core/app_session_migration.exs` | migration | batch | `core/api_token_migration.exs` | role-match |
| `lib/sigra/install/features/core.ex` | generator/config | file-I/O | existing module | modify |
| `priv/templates/sigra.install/core/auth_app_session.ex` | service delegate | request-response | `core/auth_jwt.ex` | role-match |
| `test/sigra/app_session_test.exs` | test | CRUD/rotation | `test/sigra/jwt_test.exs` | role-match |
| `test/sigra/app_session/refresh_token_test.exs` | test | transactional rotation | `test/sigra/jwt/refresh_token_test.exs` | exact |
| `test/sigra/app_session_audit_cofate_test.exs` | integration test | transaction/concurrency | `test/sigra/jwt_refresh_audit_cofate_test.exs` | exact |
| `test/sigra/plug/fetch_app_session_test.exs` | plug test | request-response | existing file plus `fetch_api_token_test.exs` | modify |
| `test/sigra/install/app_session_generator_test.exs` | generator test | file-I/O | `test/sigra/install/api_token_generator_test.exs` | exact |

Phase 245 is the persistence and library contract only. `--app-sessions` CLI selection, hosted PKCE, and direct password login are explicitly Phase 246; do not make Core’s public option imply them prematurely.

## Pattern Assignments

### `lib/sigra/app_session.ex` and `lib/sigra/app_session/refresh_token.ex`

**Analog:** `lib/sigra/jwt.ex` and `lib/sigra/jwt/refresh_token.ex`.

Copy the split between a public facade and storage-specific lifecycle module. The JWT facade starts one transaction, locks/classifies first, merges the appropriate mutation, appends audit only when configured, emits telemetry after commit, and only then returns a replacement credential (`jwt.ex:219-262`).

```elixir
multi =
  Multi.new()
  |> RefreshToken.build_locked_classify_multi(config, raw_refresh_token, opts)
  |> Multi.merge(fn %{jwt_refresh_classification: {action, token_record, metadata}} ->
    action
    |> build_refresh_mutation_multi(config, token_record, metadata, opts)
    |> append_refresh_audit(config, token_record.user_id, action)
  end)

case config.repo.transaction(multi) do
  {:ok, %{jwt_refresh_classification: {:rotate, _, _}} = changes} -> ...
  {:ok, %{jwt_refresh_classification: {:reuse, token_record, metadata}} = changes} -> ...
end
```

The closest exact persistence construction is `refresh_token.ex:148-207`: decode+digest inside `Multi.run`, `FOR UPDATE` lookup, classify while locked, update consumed credential, then insert the replacement. Keep raw access/refresh values out of records and generate/return the raw replacement only after a successful transaction (`refresh_token.ex:195-206`; `jwt.ex:321-335`).

```elixir
from(t in schema,
  where: t.token == ^hashed and t.context == "api_refresh",
  lock: "FOR UPDATE"
)
```

**Adaptation required:** app sessions need *two digest-only opaque credentials* and independent expiry semantics: 15-minute access, refresh idle expiry of 30 days, and absolute family/session expiry of 90 days. Do not reuse `user_tokens.sent_to` JSON or JWT `context: "api_refresh"`; create an indexed app-session schema with explicit `access_digest`, `refresh_digest`, family/session ID, `superseded_at`/`revoked_at`, `last_refreshed_at`, and absolute expiry fields. A partial/active lookup must bind the credential type and reject revoked/expired/superseded state before scope construction.

**Critical risk:** `JWT.RefreshToken.revoke_family/3` uses a `LIKE` match over JSON text (`refresh_token.ex:211-242`). Do not copy that storage shortcut: app sessions require an indexed family ID column and a single update/all operation under the same lock/transaction. Reuse must revoke the whole family, including the currently active access credential, before returning `:reuse_detected`.

### `lib/sigra/plug/fetch_app_session.ex` and `lib/sigra/plug/credential_auth.ex`

**Analog:** `lib/sigra/plug/fetch_api_token.ex:23-54`, shared `credential_auth.ex:4-26`, and `fetch_jwt.ex:31-69`.

Maintain the explicit pipeline shape: skip only when a Scope already exists; otherwise extract the one selected transport, verify through `Sigra.AppSession`, reload `config.user_schema`, build the host’s real scope, and write bounded verifier facts into `conn.private[:sigra_auth]`.

```elixir
with {:ok, raw_token} <- extract_bearer_token(conn),
     {:ok, credential} <- Sigra.APIToken.verify(config, raw_token),
     user when not is_nil(user) <- config.repo.get(config.user_schema, credential.user_id) do
  CredentialAuth.put_verified_scope(conn, scope_module, user, :personal_access_token, %{...})
else
  _ -> Plug.Conn.assign(conn, :current_scope, nil)
end
```

The present app plug is intentionally a no-parser fail-closed placeholder (`fetch_app_session.ex:3-27`); replace it rather than introducing a second plug. Extend `CredentialAuth.put_verified_scope/5` only if needed for an app-session `session_id`/`family_id` fact—never raw token, digest, device identifier, or client-provided scopes. Existing facts are an allowlist at `credential_auth.ex:7-17`.

**Critical risk:** `FetchAPIToken` accepts any Bearer token. The finished app plug must not quietly autodetect JWT/PAT/cookies. Use the explicit configured app-session transport/credential kind and ensure malformed, stale, revoked, and user-missing credentials all result in nil Scope with no secret in assigns/private/logs.

### `lib/sigra/auth.ex`, `lib/sigra/account/deletion.ex`, and audit co-fate

**Analog:** browser session revocation at `auth.ex:1533-1677`, reset security event at `auth.ex:1203-1288`, account deletion composition at `auth.ex:2493-2517`, and `account/deletion.ex:174-220`.

Copy the facade ownership: generated code calls `Sigra.Auth`, which derives config/schema options and delegates security-sensitive work. Single-session revoke has an owner constraint and indistinguishable no-op foreign/missing path (`auth.ex:1543-1563`); all-session revoke reports count, emits telemetry, and logs audit (`auth.ex:1602-1650`). App session APIs must provide equivalent owner-bound revoke-one and revoke-all-for-user/family behavior.

For password reset, add app-session invalidation as another `Ecto.Multi` step beside `:delete_all_tokens` and browser `:delete_all_sessions` (`auth.ex:1213-1248`), before its audit operation. For account-deletion scheduling, add the app-session cleanup to the same deactivation lifecycle; current deletion removes tokens in its Multi but browser-session revocation runs after commit (`account/deletion.ex:197-207`). Do not claim co-fate if app-session revocation is placed after commit—Phase 245’s durable revocation requirement needs the database mutation in the security-event transaction wherever an audit/domain transaction already exists.

Use `Sigra.Audit.log_multi_safe/3` after persistence mutation exactly as `APIToken.revoke_all/2` does (`api_token.ex:598-619`) and call `Audit.emit_telemetry_from_changes/2` only after commit (`jwt.ex:231-241`). Add action names under the existing reserved `session.` / `api.` prefixes (`config.ex:43-45`); do not introduce audit-only writes that can succeed when revocation rolled back.

### `lib/sigra/config.ex`

**Analog:** session option schema at `config.ex:420-456`, JWT defaults at `config.ex:820-...`, and struct/type fields at `config.ex:990-1048`.

Add a standalone `:app_session` keyword section to the top-level NimbleOptions schema, `%Sigra.Config{}` type, and `defstruct`. Follow the positive seconds validation/default documentation convention:

```elixir
access_ttl: [type: :pos_integer, default: 900],
refresh_idle_ttl: [type: :pos_integer, default: 30 * 24 * 60 * 60],
absolute_ttl: [type: :pos_integer, default: 90 * 24 * 60 * 60],
app_session_schema: [type: {:or, [:atom, nil]}, default: nil]
```

Configuration must fail closed when the app-session verifier is used but its schema or required TTL/order constraints are absent. Do not overload `:jwt`, `:session`, or `:api_token`: their persisted formats and credential authority differ.

### Generator schemas, migration, config, and delegates

**Analogs:** `priv/templates/sigra.install/core/user_api_token.ex:17-51`, `core/api_token_migration.exs:9-38`, `core/auth_jwt.ex:10-25`, and `lib/sigra/install/features/core.ex:58-67, 108-133, 751-900`.

When Phase 245 needs a fresh-host persistence contract, follow API-token’s dedicated schema+migration pair: host-owned Ecto schema with fields and changeset only; library owns validation and lifecycle. The migration has adapter-specific blocks, `@auth_prefix`/reference options for Postgres, cascade user FK, unique digest indexes, and targeted lifecycle indexes (`api_token_migration.exs:9-25`). Include exact indexes for access digest, refresh digest, `user_id`, family ID, and active/revocation/expiry queries.

`Features.Core` currently keeps `api?` and `jwt?` independent (`core.ex:58-67`) and adds files/injections only through the corresponding predicates (`core.ex:108-133`). Copy that pattern for a future `app_sessions?` predicate; it must neither imply nor be implied by `--api`, `--jwt`, or `--app-password-login` (Phase 246). The generated delegate mirrors `auth_jwt.ex`: no HTTP password endpoint and no request-selected authority. Keep Phase 245’s generator scope narrowly to schema/config/delegation only if the roadmap plan elects fresh-host coverage.

### Tests

**Analogs:** `test/sigra/plug/fetch_app_session_test.exs:15-46`, `test/sigra/jwt/refresh_token_test.exs`, `test/sigra/jwt_refresh_audit_cofate_test.exs:176-230`, and `test/sigra/install/api_token_generator_test.exs`.

Retain the existing app-plug tests as the forward-compatible baseline, then replace its fail-closed assertions with explicit valid/invalid access-token cases and assertions that `private[:sigra_auth]` is bounded. Copy the Postgres co-fate fixture strategy: isolated schemas/tables, audit-on and audit-off configs, raw token issued once, count/assert all rows, and constraint fault injection proving no partial rotation (`jwt_refresh_audit_cofate_test.exs:176-230`). Add deterministic two-process/barrier reuse tests; do not use sleeps.

## Shared Patterns

### Opaque digest storage

**Sources:** `session.ex:20-25`, `session_stores/ecto.ex:22-60`, `jwt/refresh_token.ex:358-383`.

```elixir
{raw_token, hashed_token} = Sigra.Token.generate_hashed_token()
...
case repo.get_by(schema, hashed_token: hashed_token) do
  nil -> {:error, :not_found}
  record -> {:ok, to_session(record)}
end
```

Apply to all access and refresh secrets. Persist only fixed-size digest columns; raw credential exists only in a successful issue/rotation result.

### Locked rotation and audit durability

**Sources:** `jwt/refresh_token.ex:154-179`, `jwt.ex:219-262`, `api_token.ex:598-619`.

Every rotation/reuse path uses exactly one `Repo.transaction(Multi)`, performs `FOR UPDATE` classification within it, then persists rotate or family revoke and appends the audit step to that same Multi when audit is configured. No separate audit transaction, post-commit audit, or unlocked preflight lookup.

### Security-event revocation fanout

**Sources:** `auth.ex:1203-1288`, `auth.ex:1602-1650`, `auth.ex:2493-2517`, `account/deletion.ex:197-207`.

Password reset, deletion scheduling/execution, sign-out-all, and explicit device/app-session revocation must call the app-session service using the configured schema. Scope access must re-check durable row state every request so subsequent authentication fails immediately; do not depend on a cached token epoch alone.

### Normal Scope and trusted credential metadata

**Sources:** `fetch_api_token.ex:35-46`, `credential_auth.ex:4-26`.

Use `Sigra.Scope.build/3` through `CredentialAuth`; app sessions authenticate identity/assurance, never delegated scopes. `RequireScopes` remains fail-closed because app metadata supplies `scopes: []`.

## No Analog Found

| File/Concern | Role | Data Flow | Reason / planner direction |
|---|---|---|---|
| Separate app-session access + refresh record design | model | transactional rotation | No existing credential stores both opaque access and refresh records with 15m/30d/90d limits. Derive from JWT rotation plus Ecto session digest discipline; use explicit indexed columns rather than JSON metadata. |
| App-session client/device presentation API | controller/component | request-response | Deliberately deferred to Phase 246 hosted/direct login. Do not add controller/routes in this phase. |

## Metadata

**Analog search scope:** `lib/sigra/{session*,jwt*,api_token*,auth*,account*,plug*,config.ex,install/features}`, `priv/templates/sigra.install/core`, and focused `test/sigra` suites.  
**Files scanned:** 26  
**Pattern extraction date:** 2026-08-12
