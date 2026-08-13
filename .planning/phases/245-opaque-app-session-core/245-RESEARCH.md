# Phase 245: Opaque App-Session Core - Research

**Researched:** 2026-08-12
**Domain:** First-party opaque access/refresh session lifecycle on Phoenix/Ecto/PostgreSQL
**Confidence:** HIGH

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM system, Rail Accent assets, and Light/Dark/System modes for any admin UI work. [VERIFIED: `AGENTS.md`]
- Keep Playwright/admin UI tests deterministic with role selectors, stable hooks, LiveView readiness, and no sleeps. [VERIFIED: `AGENTS.md`]
- Replace human verification/UAT with deterministic automated evidence within authorized scope; do not claim missing evidence as passed. [VERIFIED: `AGENTS.md`]
- Do not introduce concurrent GitHub CI watchers or poll faster than the specified 60-second interval. [VERIFIED: `AGENTS.md`]

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| APP-04 | A first-party app receives opaque digest-only credentials with 15-minute access, 30-day refresh-idle, and 90-day absolute defaults; refresh is atomic, rotates every use, and revokes the session family on consumed-token reuse. | Use a family row plus digest-only access/refresh-token rows; lock the presented refresh row in one transaction before classification, rotation, optional audit, and response construction. [VERIFIED: requirements and Phase 244 locked lifecycle] |
| APP-05 | A user or security event can revoke one app session or all applicable sessions, and password reset, account deletion, sign-out-all, explicit device revocation, and refresh reuse take effect on subsequent authentication. | Make every access authentication join/check the family revocation state; expose one-family and user-wide revocation APIs and compose them into existing lifecycle multis. [VERIFIED: requirements and current lifecycle call sites] |

## Summary

Phase 245 is a bounded, library-owned session core, not a native-login feature. The existing public `Sigra.Plug.FetchAppSession` deliberately fails closed until this phase supplies a verifier; Phase 243 has already locked its responsibilities: load the live user, build the host's normal Scope, and put only bounded credential facts in `conn.private[:sigra_auth]`. [VERIFIED: `lib/sigra/plug/fetch_app_session.ex`; `243-CONTEXT.md`]

Implement opaque app sessions as a durable family plus token records: persist only digests for independently generated access and refresh credentials; make access tokens valid for 900 seconds, refresh idle validity 2,592,000 seconds, and a non-extendable family absolute expiry of 7,776,000 seconds by default. A refresh locks the digest-addressed refresh-token record with `FOR UPDATE`, checks family and both expirations, consumes it, inserts a replacement access/refresh pair in the same family, appends audit when configured, and returns raw values only after commit. A consumed refresh token takes the reuse branch, atomically revokes the whole family, and returns `:reuse_detected` only after that commit. [VERIFIED: `ROADMAP.md`; `REQUIREMENTS.md`; `lib/sigra/jwt.ex`; `lib/sigra/jwt/refresh_token.ex`; CITED: https://www.postgresql.org/docs/current/sql-select.html]

The Phase 244 JWT refresh lifecycle is the direct implementation tracer, but its `user_tokens.sent_to` JSON metadata is not the app-session schema. App sessions require explicit family identity, revocation, expiry, and per-token state so one-device revocation and all-session invalidation are correct and indexable. Do not add a ceremony, installer flag, router, controller, callback URI, PKCE, MFA, or direct-password endpoint here; Phase 246 owns issuance transport and generated-host opt-in. [VERIFIED: `244-06-PLAN.md`; `244-06-SUMMARY.md`; `ROADMAP.md`]

**Primary recommendation:** Add `Sigra.AppSession` as the single lifecycle authority backed by host-provided family/token schemas; activate `FetchAppSession`; compose its revocation into reset, deletion, and sign-out-all transactions; prove the real PostgreSQL race with the Phase 244 barrier pattern. [VERIFIED: APP-04/APP-05; Phase 243/244 contracts]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Access credential verification and Scope projection | API / Backend | Database / Storage | A Plug must digest the presented opaque access credential, reject expired/revoked state, reload the live user, and build the normal Scope. [VERIFIED: `fetch_app_session.ex`; `243-CONTEXT.md`] |
| App-session family/token persistence, expiry, and locks | Database / Storage | API / Backend | Durable digest rows and row locking establish one-use refresh and next-auth revocation. [VERIFIED: Phase 244 lifecycle; CITED: https://www.postgresql.org/docs/13/transaction-iso.html] |
| One-device/all-session security mutation | API / Backend | Database / Storage | Security events call the library authority; the database marks a family or all user families revoked. [VERIFIED: `lib/sigra/auth.ex`; `lib/sigra/account/deletion.ex`] |
| Hosted/direct login, PKCE, callback policy, MFA challenge | API / Backend | Browser / Client | These are explicitly Phase 246 ceremonies and must consume, not redefine, the core issuance API. [VERIFIED: `ROADMAP.md`] |
| Native secure storage and offline behavior | Browser / Client | API / Backend | Clients retain raw credentials, while Sigra retains only digests; device storage/offline policy is later-phase work. [VERIFIED: Phase 243 ownership decision; `ROADMAP.md`] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Sigra / `Sigra.Config` / `Sigra.Scope` | existing repository | Public configuration, live-user lookup, normal Scope construction | Preserves the Phase 243 explicit-pipeline contract without a second authorization model. [VERIFIED: `lib/sigra/config.ex`; `lib/sigra/scope.ex`; `243-CONTEXT.md`] |
| Ecto `Multi`, Repo transaction, and `Ecto.Query` lock | existing `ecto ~> 3.13` dependency | Atomic rotate/revoke/audit and row serialization | Phase 244 has this exact proven lifecycle pattern; `Multi.run` participates in the transaction and aborts it on error. [VERIFIED: `mix.exs`; `lib/sigra/jwt.ex`; CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] |
| PostgreSQL | available locally, client 14.17 | Row-level locking and deterministic concurrency evidence | `SELECT ... FOR UPDATE` locks selected rows against concurrent updates; the test strategy requires real database behavior. [VERIFIED: local environment probe; CITED: https://www.postgresql.org/docs/current/sql-select.html] |
| `Sigra.Token` | existing repository | CSPRNG raw generation and digest persistence | Existing session/JWT refresh code already generates raw values and stores a token hash. [VERIFIED: `lib/sigra/token.ex`; `lib/sigra/jwt/refresh_token.ex`] |
| ExUnit + `Sigra.Test.PostgresCase` | existing repository | Unit and real-Postgres lifecycle tests | Existing Phase 244 co-fate tests provide the deterministic barrier fixture. [VERIFIED: `test/sigra/jwt_refresh_audit_cofate_test.exs`] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Plug | existing `~> 1.16` dependency | Request header extraction and private auth metadata | Only in `FetchAppSession`; leave response/ceremony concerns to Phase 246. [VERIFIED: `mix.exs`; `lib/sigra/plug/fetch_app_session.ex`] |
| `Sigra.Audit` + `Sigra.Telemetry` | existing repository | Co-fated audit record and post-commit telemetry | Append the optional audit Multi step to issuance, refresh/reuse, and explicit revocation when an audit schema is configured. [VERIFIED: `lib/sigra/jwt.ex`; `lib/sigra/account.ex`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Durable opaque access-token lookup | Self-contained JWT access token | Conflicts with APP-04's opaque credential and makes next-auth family revocation dependent on another denylist/epoch model. [VERIFIED: `REQUIREMENTS.md`] |
| Dedicated app-session schema | Reuse `user_tokens.sent_to` JSON as Phase 244 does | JSON-family filtering is not a clear/indexable owner for per-device session revocation, access state, idle/absolute expiry, and family audit semantics. [VERIFIED: `lib/sigra/jwt/refresh_token.ex`; `244-06-PLAN.md`] |
| `FOR UPDATE` in one transaction | Read then update in separate operations | Allows two callers to classify the same refresh credential as current before either consumes it. [VERIFIED: `lib/sigra/jwt/refresh_token.ex`; CITED: https://www.postgresql.org/docs/13/transaction-iso.html] |

**Installation:** No external package is installed in this phase. [VERIFIED: repository dependency inventory and phase scope]

## Architecture Patterns

### System Architecture Diagram

```text
First-party app
  | Authorization: Bearer <opaque access>
  v
FetchAppSession
  | digest raw value; lookup active access token + family
  |-- missing/expired/revoked --> current_scope=nil (fail closed)
  v
live User lookup -> Sigra.Scope.build/3 -> conn.private[:sigra_auth] (bounded facts only)

First-party app -- opaque refresh --> Sigra.AppSession.refresh/...
  | digest -> SELECT refresh token FOR UPDATE
  |-- consumed ------------------> revoke family + optional audit -> reuse_detected
  |-- family/token expiry/revoked -> invalid/expired, no mutation
  `-- current -------------------> consume + issue digest-only access/refresh + optional audit
                                      | Repo transaction commits
                                      `--> reveal replacement raw credentials

password reset / account deletion / sign-out-all / device revoke
  `--> AppSession.revoke_family or revoke_all_for_user
         `--> next access authentication observes family revoked and fails
```

### Recommended Project Structure

```text
lib/sigra/
├── app_session.ex             # authoritative issue, authenticate, refresh, one/all revoke APIs
├── app_session/family.ex      # host-schema changeset/query helpers and family-state invariants
├── app_session/token.ex       # raw-to-digest conversion, access/refresh persistence helpers
├── plug/fetch_app_session.ex  # explicit bearer extraction + Scope/private-metadata projection
├── auth.ex                    # lifecycle composition points for reset/sign-out/deletion
└── config.ex                  # explicit app_session schema/default validation
test/sigra/
├── app_session_test.exs
├── app_session/concurrency_test.exs
└── plug/fetch_app_session_test.exs
```

### Pattern 1: Family row plus immutable token rows

**What:** Store an app-session family row (`user_id`, server-selected app/session reference, `absolute_expires_at`, `revoked_at`, audit-safe timestamps) and separate token rows (`family_id`, `kind`, digest, `expires_at`, `consumed_at`, `revoked_at`). Persist no raw access or refresh value. [VERIFIED: APP-04/APP-05; Phase 244 digest-family pattern]

**When to use:** For every app-session issuance, access authentication, refresh, and security-event revocation. [VERIFIED: `REQUIREMENTS.md`]

**Schema/generator boundary:** Phase 245 defines the library-facing schema contract and validates an explicit `app_session` config containing host-owned family/token schema modules and the three defaults. It uses test-local schemas for core proof. Phase 246 emits any fresh-host migration/schema/config and wires issuance only after a hosted/direct ceremony succeeds. Do not mutate installer feature gates or emit login routes in Phase 245. [VERIFIED: `PROJECT.md`; `ROADMAP.md`; Phase 244 generator ownership pattern]

### Pattern 2: One locked transaction, response last

**What:** Build one `Ecto.Multi`: digest+`FOR UPDATE` classification; then either consume/insert both replacement token records or revoke the family; append audit only when configured; call `Repo.transaction`; construct/reveal raw response values only on `{:ok, ...}`. [VERIFIED: `lib/sigra/jwt.ex`; `lib/sigra/jwt/refresh_token.ex`; CITED: https://hexdocs.pm/ecto/Ecto.Multi.html]

**When to use:** Every refresh, including audit-off mode and consumed-token reuse. Audit must be an optional step, never a different lifecycle. [VERIFIED: `244-06-PLAN.md`; `244-06-SUMMARY.md`]

```elixir
# Source: existing Sigra Phase 244 lifecycle adapted to app-session schemas
multi =
  Ecto.Multi.new()
  |> AppSession.lock_and_classify(raw_refresh, config)
  |> Ecto.Multi.merge(fn %{app_refresh_classification: classification} ->
    AppSession.persist_rotation_or_reuse_revocation(classification, config)
  end)
  |> AppSession.maybe_append_audit(config)

case config.repo.transaction(multi) do
  {:ok, %{app_refresh_response: response}} -> {:ok, response}
  {:ok, %{app_refresh_classification: %{action: :reuse}}} -> {:error, :reuse_detected}
  {:error, :app_refresh_classification, reason, _} -> {:error, reason}
  {:error, _step, _reason, _} -> {:error, :app_session_refresh_aborted}
end
```

### Pattern 3: Authentication rechecks authoritative state

**What:** `FetchAppSession` parses exactly the explicit bearer form, digests it, queries its access-token row and non-revoked family, checks `access.expires_at`, reloads the user, and builds the normal Scope. It writes allowlisted facts such as `%{kind: :app_session, credential_id: token.id, session_id: family.id, assurance: ...}`; it never writes raw tokens, raw headers, untrusted device identifiers, or request-selected scopes. [VERIFIED: `243-CONTEXT.md`; `test/sigra/plug/fetch_app_session_test.exs`]

**When to use:** On every route that intentionally opts into `Sigra.Plug.FetchAppSession`; it must leave an existing `current_scope` untouched. [VERIFIED: `fetch_app_session.ex`; Phase 243 decision]

### Lifecycle Composition Matrix

| Trigger | Existing seam | Required app-session behavior | Atomicity |
|---------|---------------|--------------------------------|-----------|
| One device/session revoke | new `AppSession.revoke_family/…` | Mark exactly selected family revoked; all its access tokens fail next authentication. | Revocation state + audit in one transaction when audit enabled. [VERIFIED: APP-05; Phase 244 pattern] |
| Sign out all | `Sigra.Auth.delete_all_sessions/3` and generated `revoke_all_sessions/2` | Revoke all active app-session families for user in addition to browser sessions; do not preserve an app-session exception token. | Same security operation must not report success until app revoke is durable. [VERIFIED: `auth.ex`; generated `auth.ex`; APP-05] |
| Password reset | `Sigra.Auth.reset_password/4` transaction | Add family-wide app-session revocation/deletion before reset transaction commits; successful reset leaves no valid app access/refresh credential. | Co-fated with password, reset-token cleanup, browser-session deletion, and optional audit. [VERIFIED: `lib/sigra/auth.ex`; APP-05] |
| Account deletion scheduled | `Sigra.Account.Deletion.do_schedule/3` | Include app-session revoke/delete in the immediate deactivation transaction, not only finalization. | Co-fated with deleted state and token cleanup; no post-commit best-effort app revoke. [VERIFIED: `lib/sigra/account/deletion.ex`; `lib/sigra/auth.ex`; APP-05] |
| Account hard delete | `build_execute_multi(:hard_delete, ...)` | Ensure FK cascade or explicit app-session deletion is present; soft/anonymize remain invalid because scheduling already revoked families. | Database referential action or the execution Multi. [VERIFIED: `account/deletion.ex`; APP-05] |
| Consumed refresh reuse | `AppSession.refresh/…` | Lock the consumed refresh row, revoke family, audit, commit, then return `:reuse_detected`. | Single locked transaction in audit-on and audit-off. [VERIFIED: APP-04; `244-06-PLAN.md`] |

### Anti-Patterns to Avoid

- **Store a raw credential, even encrypted:** APP-04 requires digest-only persistence; raw values belong only in the immediate successful issuance/refresh response. [VERIFIED: APP-04]
- **Treat refresh idle as a sliding absolute expiry:** Rotation may advance the idle deadline, never `absolute_expires_at`; each replacement inherits the original family ceiling. [VERIFIED: APP-04]
- **Reuse `FetchBearer` token-shape detection:** The explicit `FetchAppSession` pipeline is the locked public contract. [VERIFIED: `243-CONTEXT.md`]
- **Revoke by a client-supplied user/session selector:** Derive owner from authenticated Scope for self-service operations and constrain administrative target loading through existing admin action rules. [VERIFIED: `lib/sigra/admin/users/actions.ex`; Phase 244 owner-bound PAT precedent]
- **Perform app revocation after password-reset/deletion commit:** A crash in the gap leaves a valid credential after a security event. [VERIFIED: current `reset_password` and deletion transactions; APP-05]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Random credential generation/digesting | Custom entropy, encoding, or hash code | `Sigra.Token.generate_hashed_token/0` and `Sigra.Token.hash_token/1` | It is the repository's existing CSPRNG/digest convention and avoids incompatible encoding. [VERIFIED: `lib/sigra/token.ex`; `auth.ex`] |
| Transaction orchestration | Ad hoc sequential `Repo.update!` / `Repo.insert!` calls | `Ecto.Multi` + `Repo.transaction` | Gives one rollback boundary and named failure steps. [CITED: https://hexdocs.pm/ecto/Ecto.Multi.html] |
| Refresh concurrency proof | Sleeps or mocked locking | `Sigra.Test.PostgresCase`, Sandbox allow, task ready/go messages, `Task.await` | Existing Phase 244 test proves one rotation and one reuse without timing races. [VERIFIED: `test/sigra/jwt_refresh_audit_cofate_test.exs`; `AGENTS.md`] |
| Scope construction | Token-only map to host Scope | `Sigra.Scope.build/3` | Preserves host Scope shape and credential metadata separation. [VERIFIED: `243-CONTEXT.md`; `lib/sigra/scope.ex`] |

**Key insight:** The sensitive primitive is not a token string but the state transition from an active refresh row to consumed/revoked family state. Reuse the tested database transaction seam, not an in-memory lock or a client-side convention. [VERIFIED: Phase 244 lifecycle and PostgreSQL locking documentation]

## Common Pitfalls

### Pitfall 1: Locking the family after classifying the refresh token

**What goes wrong:** Two simultaneous callers can both classify the same refresh credential as active and both receive replacements. [VERIFIED: `lib/sigra/jwt/refresh_token.ex` pre-Phase-244 contrast; APP-04]

**How to avoid:** Digest and lock the exact refresh-token row inside the transaction before checking `consumed_at`; subsequent family changes occur from that locked result. [VERIFIED: Phase 244 implementation; CITED: https://www.postgresql.org/docs/13/transaction-iso.html]

**Warning signs:** A test accepts two successful refresh results or has no real Postgres lock test. [VERIFIED: `244-06-PLAN.md`]

### Pitfall 2: Returning credentials before audit/persistence commits

**What goes wrong:** A client receives usable credentials for a state transition that later rolls back or lacks mandatory audit evidence. [VERIFIED: `244-06-PLAN.md`]

**How to avoid:** Generate raw values in memory if needed, but return them only from the successful transaction result; normalize failed persistence/audit to an abort outcome. [VERIFIED: `lib/sigra/jwt.ex`; `244-06-SUMMARY.md`]

### Pitfall 3: Cleanup-only revocation

**What goes wrong:** Deleting expired rows asynchronously cannot satisfy APP-05, because a revoked credential may still authenticate before cleanup runs. [VERIFIED: APP-05]

**How to avoid:** Access authentication checks family `revoked_at` and access expiry synchronously; cleanup is only storage hygiene. [VERIFIED: APP-05; Phase 244 family semantics]

### Pitfall 4: Forgetting lifecycle fan-out

**What goes wrong:** Password reset, deletion scheduling, browser sign-out-all, or admin device revocation invalidates browser/JWT/PAT material but leaves app sessions active. [VERIFIED: `lib/sigra/auth.ex`; `lib/sigra/account/deletion.ex`; APP-05]

**How to avoid:** Centralize `revoke_all_for_user` and call it from each existing security-event Multi/facade; regression-test each call site rather than only the core module. [VERIFIED: current facade structure; APP-05]

### Pitfall 5: Expiry ambiguity

**What goes wrong:** Every refresh resets both expiry clocks, silently allowing an indefinitely refreshed session. [VERIFIED: APP-04]

**How to avoid:** Keep a family `absolute_expires_at` fixed at issuance; calculate a new refresh idle deadline as `min(now + 30d, absolute_expires_at)` and reject when either boundary is passed. [VERIFIED: APP-04]

## Code Examples

### Explicit app-session Plug projection

```elixir
# Source: Phase 243 locked pipeline contract; implement in FetchAppSession
with {:ok, access} <- Sigra.AppSession.authenticate(config, bearer),
     {:ok, user} <- fetch_live_user(config, access.user_id) do
  scope = Sigra.Scope.build(scope_module, user)

  conn
  |> Plug.Conn.assign(:current_scope, scope)
  |> Plug.Conn.put_private(:sigra_auth, %{
    kind: :app_session,
    credential_id: access.id,
    session_id: access.family_id,
    assurance: access.assurance
  })
else
  _ -> Plug.Conn.assign(conn, :current_scope, nil)
end
```

### Deterministic Postgres double-refresh proof

```elixir
# Source: test/sigra/jwt_refresh_audit_cofate_test.exs
callers =
  for _ <- 1..2 do
    Task.async(fn ->
      Ecto.Adapters.SQL.Sandbox.allow(repo, parent, self())
      send(parent, {:ready, self()})
      receive do: (:go -> Sigra.AppSession.refresh(config, raw_refresh))
    end)
  end

for _ <- callers do
  assert_receive {:ready, caller}
  send(caller, :go)
end

results = Enum.map(callers, &Task.await(&1, 5_000))
assert Enum.count(results, &match?({:ok, _}, &1)) == 1
assert Enum.count(results, &match?({:error, :reuse_detected}, &1)) == 1
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| JWT refresh had separable non-audited mutations | One `FOR UPDATE` Ecto.Multi lifecycle with optional audit | Phase 244 | Phase 245 can copy one reliable transaction shape for audit-on/off rather than create another. [VERIFIED: `244-06-SUMMARY.md`] |
| `FetchAppSession` did no authentication | Phase 245 activates it through explicit opaque verification | Phase 245 scope | New routers can choose this credential kind without bearer-shape guessing. [VERIFIED: `fetch_app_session.ex`; `243-CONTEXT.md`] |

**Deprecated/outdated:** Do not base new app-session work on `Sigra.Plug.FetchBearer`; it remains a compatibility dispatcher and is not a fresh-host primary pipeline. [VERIFIED: `243-CONTEXT.md`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Phase 245 uses the library names `Sigra.AppSession` and `app_session` with `family_schema`/`token_schema` callbacks; Phase 246 alone chooses emitted host schema/module names. [RESOLVED] | Architecture Patterns | No naming ambiguity remains in Phase 245 and no generated-host name is prematurely locked. |
| A2 | Issuance requires a non-empty, server-selected `client_ref` bounded to 255 bytes and stores it only on the family row. [RESOLVED] | Architecture Patterns | Phase 246 must select it after authentication rather than accept it as client authority. |

## Open Questions (RESOLVED)

1. **Generated host schema/module names — resolved as Phase 246-owned.**
   - Phase 245 fixes only the library-facing config callbacks `family_schema` and `token_schema` and proves them with test-local representative modules. Phase 246 chooses the emitted host module and migration names when it adds `--app-sessions`; those names are not a Phase 245 public contract. [RESOLVED: phase boundary, Phase 246 ownership]

2. **Server-selected app reference — resolved as a Phase 245 issuance choice.**
   - `Sigra.AppSession.issue/4` requires a non-empty server-selected `client_ref` string bounded to 255 bytes and stores it on the family row for lifecycle/operator context. It is never accepted as client authority and is excluded from token rows, Scope, private credential facts, audit metadata, and logs. Phase 246 decides how a completed hosted/direct ceremony selects that value. [RESOLVED: locked bounded-reference decision plus planner discretion]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir/Mix | Library and ExUnit work | ✓ | OTP 28 / installed | — [VERIFIED: local environment probe] |
| PostgreSQL client | Lock/transaction integration tests | ✓ | `psql` 14.17 | — [VERIFIED: local environment probe] |
| Reachable PostgreSQL test server | Deterministic concurrency test | ✗ | `pg_isready` reported no response at `127.0.0.1:53988` | Use the repository `tmp/db.env`/CI Postgres setup; do not substitute mocks. [VERIFIED: local probe; `test/sigra/jwt_refresh_audit_cofate_test.exs`] |

**Missing dependencies with no fallback:** A reachable PostgreSQL server is required to execute the concurrency acceptance test. [VERIFIED: Phase 244 test architecture]

**Missing dependencies with fallback:** None. [VERIFIED: local probe]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with `Sigra.Test.PostgresCase` and Ecto SQL Sandbox. [VERIFIED: `test/sigra/jwt_refresh_audit_cofate_test.exs`] |
| Config file | `test/test_helper.exs`. [VERIFIED: repository layout] |
| Quick run command | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_session_test.exs test/sigra/app_session/concurrency_test.exs test/sigra/plug/fetch_app_session_test.exs --trace` [ASSUMED: proposed new files] |
| Full suite command | `source tmp/db.env && MIX_ENV=test mix ci` (requires the full project infrastructure). [VERIFIED: Phase 244 verification] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| APP-04 | Issue only digest-backed access/refresh; default access/idle/absolute clocks are exact | unit + Postgres persistence | focused app-session suite | ❌ Wave 0 |
| APP-04 | Rotation changes both raw credentials; old refresh reuse revokes family after commit | Postgres integration, audit-on/off and fault injection | focused app-session concurrency suite | ❌ Wave 0 |
| APP-04 | Two callers produce exactly one rotate success and one reuse result, no sleeps | Postgres two-task barrier | focused app-session concurrency suite | ❌ Wave 0 |
| APP-05 | Access fails immediately after one-family revoke and user-wide revoke | plug + integration | focused plug/app-session suite | ❌ Wave 0 |
| APP-05 | Password reset, deletion schedule, sign-out-all, and explicit revoke all compose app-session invalidation | integration of existing facades | focused lifecycle suite | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** Focused touched module tests; any lifecycle task also runs the affected existing Auth/Account test file. [VERIFIED: project test layout]
- **Per wave merge:** Full app-session Postgres suite in audit-on/off modes plus plug projection tests. [VERIFIED: APP-04/APP-05]
- **Phase gate:** `MIX_ENV=test mix ci` green or durable, classified failure evidence; no manual UAT substitute. [VERIFIED: `AGENTS.md`; config Nyquist enabled]

### Wave 0 Gaps

- [ ] `test/sigra/app_session_test.exs` — defaults, digest-only persistence, access authentication, expiry, one/all revocation.
- [ ] `test/sigra/app_session/concurrency_test.exs` — audit-on/off rollback, consumed reuse, and barrier-coordinated double refresh.
- [ ] Extend `test/sigra/plug/fetch_app_session_test.exs` — valid projection, bad/expired/revoked credentials, private metadata redaction, existing Scope passthrough.
- [ ] Extend focused `Auth`/`Account.Deletion` tests — reset, deletion scheduling/finalization, generated sign-out-all/admin device paths invalidate app sessions.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Digest opaque credential lookup, explicit Plug pipeline, live-user Scope loading, strict expiry checks. [VERIFIED: APP-04; Phase 243 contract] |
| V3 Session Management | yes | 15m access, 30d sliding refresh idle bounded by 90d absolute, atomic rotation, reuse family revoke, next-auth revocation. [VERIFIED: APP-04/APP-05] |
| V4 Access Control | yes | Owner derives from Scope for self-service revoke; server selects app/client reference and no delegated scopes are inferred. [VERIFIED: Phase 243 decisions; Phase 244 PAT precedent] |
| V5 Input Validation | yes | Accept only expected bearer/opaque encoding and configuration values; malformed/missing/revoked input fails closed. [VERIFIED: `fetch_app_session.ex`; `jwt/refresh_token.ex`] |
| V6 Cryptography | yes | Repository token generator/digest, never custom randomness/hash construction; no plaintext at rest. [VERIFIED: `lib/sigra/token.ex`; APP-04] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Stolen refresh token replay | Elevation of Privilege | `FOR UPDATE` classification then committed family revocation on consumed-token reuse. [VERIFIED: APP-04; Phase 244 pattern] |
| Revoked access token still accepted | Elevation of Privilege | Query family revocation synchronously during every app-session authentication. [VERIFIED: APP-05] |
| Raw credential leak via DB/audit/logs | Information Disclosure | Persist digests only; metadata contains bounded IDs/facts, never raw values. [VERIFIED: APP-04; Phase 243 contract] |
| Password-reset/deletion revocation gap | Elevation of Privilege | Add app-session mutation into existing security-event transaction/facade rather than a post-commit job. [VERIFIED: APP-05; current code paths] |
| Cross-account device revoke | Tampering | Scope-derived owner constraint and admin target lookup before family query. [VERIFIED: `lib/sigra/admin/users/actions.ex`; Phase 244 owner-bound precedent] |
| Audit co-fate failure | Repudiation | Optional audit Multi step participates in the same state-changing transaction; failed audit yields no replacement credential. [VERIFIED: `244-06-SUMMARY.md`] |

## Sources

### Primary (HIGH confidence)

- Sigra code: `lib/sigra/plug/fetch_app_session.ex`, `lib/sigra/jwt.ex`, `lib/sigra/jwt/refresh_token.ex`, `lib/sigra/auth.ex`, `lib/sigra/account/deletion.ex`, `lib/sigra/config.ex`, and `lib/sigra/token.ex` — current public seams and lifecycle behavior.
- Phase decisions/evidence: `243-CONTEXT.md`, `244-CONTEXT.md`, `244-06-PLAN.md`, `244-06-SUMMARY.md`, and `244-VERIFICATION.md` — locked boundary and proven concurrency pattern.
- Requirements and roadmap: `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` — APP-04/APP-05 and Phase 246 exclusion.

### Secondary (MEDIUM confidence)

- [Ecto.Multi documentation](https://hexdocs.pm/ecto/Ecto.Multi.html) — transaction grouping/order/error behavior.
- [PostgreSQL SELECT locking](https://www.postgresql.org/docs/current/sql-select.html) and [transaction isolation](https://www.postgresql.org/docs/13/transaction-iso.html) — row-lock and competing transaction behavior.
- [OWASP Session Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html) — session-state security context.

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH — all production components are existing, inspected repository dependencies; no new package is proposed.
- Architecture: HIGH — APP-04/APP-05 and prior phase contracts define the boundary, and Phase 244 supplies a direct transaction tracer.
- Pitfalls: HIGH — each follows from the required revocation/rotation semantics or an inspected current lifecycle gap.

**Research date:** 2026-08-12
**Valid until:** 2026-09-11
