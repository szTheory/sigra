# Phase 9: Audit Logging - Research

**Researched:** 2026-04-09
**Domain:** Ecto-backed append-only audit log for Elixir/Phoenix auth library
**Confidence:** HIGH (architecture locked by CONTEXT.md D-01..D-28; research focuses on HOW)

## Summary

Phase 9 adds `Sigra.Audit` — a direct-write, `Ecto.Multi`-composed audit log over a generated `audit_events` table. All 28 architectural decisions are locked in `09-CONTEXT.md`; this document captures the concrete implementation shapes the planner needs: Multi composition idiom, operation→action mapping for D-26, cursor pagination shape, changeset validators, Oban fallback pattern cloned from `TokenCleanup`, schema-module lookup pattern, telemetry passthrough placement, and the full Validation Architecture needed for VALIDATION.md generation.

**Primary recommendation:** Model `Sigra.Audit.log_multi/3` as a passthrough that appends `Multi.insert(:audit, changeset)` to the caller's Multi. Model `Sigra.Audit.log/3` as the single-row wrapper that builds a 1-step Multi and calls `repo.transaction/1`. Fire `[:sigra, :audit, :log]` telemetry from the `{:ok, _}` branch of the transaction, never from inside a Multi step.

## User Constraints (from CONTEXT.md)

### Locked Decisions (D-01..D-28)

All 28 decisions in `09-CONTEXT.md <decisions>` are authoritative. Most load-bearing for planning:

- **D-01:** Capture via direct `Ecto.Multi` writes, NOT telemetry subscribers
- **D-02:** Telemetry is observability, not audit source
- **D-04:** Table name `audit_events`
- **D-05:** Schema fields (id, occurred_at, inserted_at, action, outcome, actor_id/type, target_id/type, ip_address, user_agent, metadata; `updated_at: false`)
- **D-06:** Indexes: `(actor_id, inserted_at)`, `(action, inserted_at)`, `(inserted_at)`
- **D-07:** No PG-specific features; adapter-agnostic
- **D-09/D-10:** Retention defaults to `nil` (forever); optional `Sigra.Workers.AuditCleanup` Oban worker with inline `Sigra.Audit.cleanup/1` fallback
- **D-12:** Public API — `log/3`, `query/1`, `list/2`, `stream/2`, `count/2` (+ `log_multi/3` per D-21)
- **D-13:** Cursor pagination `Base64(inserted_at_usec|id)`, no offset
- **D-15:** Private `__log_internal__/3` bypasses reserved-prefix check
- **D-17/D-18:** Reserved prefixes `auth. session. mfa. oauth. api. account. sigra.`
- **D-19:** Action regex `^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$`
- **D-20:** Metadata cap 8KB (configurable)
- **D-23:** Forbidden metadata keys enforced in changeset
- **D-24:** Telemetry passthrough `[:sigra, :audit, :log]` on every write
- **D-26:** Mapping of Auth operations to audit actions (table in §2 below)
- **D-27:** Generated schema + migration; library owns `Sigra.Audit` module
- **D-28:** Log calls outside a Multi context run their own single-row transaction

### Claude's Discretion
Module layout (`Sigra.Audit.{Event,Changeset,Cursor,Query}`), cursor format details, telemetry metadata beyond the listed fields, error tuple shapes, count/2 estimation, migration template structure.

### Deferred (OUT OF SCOPE)
Admin LiveView, SIEM export helpers, hash chaining, PG partitioning, aggregation/reporting, full-text search, tenant_id, batch log API, event versioning.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| AUDIT-01 | Automatic capture of all auth events | §2 operation→action map drives `Sigra.Auth` integration |
| AUDIT-02 | Metadata fields (actor, target, IP, UA, outcome, timestamps) | D-05 schema + §4 changeset validators |
| AUDIT-03 | Queryable API (filter, paginate, stream, count) | §3 cursor shape + D-12 API surface |
| AUDIT-04 | Custom events with guardrails | §4 action regex + reserved-prefix validator |

## 1. Ecto.Multi Audit Composition Pattern

**Codebase baseline (verified):** `lib/sigra/auth.ex` uses `Multi.new() |> Multi.run(...) |> repo.transaction()` — NOT `Repo.transact/2`. Example lines 373–402 (confirm_email). Sigra targets Ecto ~> 3.12 but the existing Auth code has not migrated to `Repo.transact/2`. Plan SHOULD match the existing convention (`repo.transaction(multi)`) to avoid a mixed style in Phase 9. A later phase can do a codebase-wide `transaction → transact` migration.

**Shape of `log_multi/3` (appends to caller's Multi):**

```elixir
@spec log_multi(Ecto.Multi.t(), String.t(), keyword()) :: Ecto.Multi.t()
def log_multi(%Ecto.Multi{} = multi, action, opts \\ []) do
  Ecto.Multi.insert(multi, :audit, fn changes ->
    opts
    |> Keyword.put(:action, action)
    |> maybe_resolve_actor(changes)   # pull actor_id from earlier Multi steps
    |> build_changeset()
  end)
end
```

**Shape of `log/3` (standalone, D-28):**

```elixir
def log(action, opts \\ []) do
  repo = Keyword.fetch!(opts, :repo)
  audit_schema = Keyword.fetch!(opts, :audit_schema)  # see §6

  multi = Ecto.Multi.new() |> log_multi(action, Keyword.put(opts, :audit_schema, audit_schema))

  case repo.transaction(multi) do
    {:ok, %{audit: event}} -> emit_telemetry(event); {:ok, event}
    {:error, :audit, changeset, _} -> {:error, changeset}
  end
end
```

**Caller-site usage in Sigra.Auth (register example):**

```elixir
Multi.new()
|> Multi.insert(:user, user_changeset)
|> Sigra.Audit.__log_internal__("auth.register.success",
     actor_resolver: & &1.user.id, metadata: %{method: "password"})
|> repo.transaction()
```

The `actor_resolver` function runs inside the `Multi.insert` factory so the just-inserted user's ID flows into the audit row.

**Confirmation:** Use `repo.transaction(multi)` consistent with existing codebase. Do NOT introduce `Repo.transact/2` in Phase 9.

## 2. Operation → Audit Action Mapping (from telemetry.ex, per D-26)

Derived from `lib/sigra/telemetry.ex` event catalog. Each row is one integration point in `Sigra.Auth` (or subsystem module) where a `Multi.insert(:audit, ...)` step gets appended.

| Current telemetry event | Audit action | Outcome handling |
|-------------------------|--------------|------------------|
| `[:sigra, :auth, :register, :stop]` | `auth.register.success` / `auth.register.failure` | split by `result` metadata |
| `[:sigra, :auth, :login, :stop]` | `auth.login.success` / `auth.login.failure` | split; failure includes `reason` |
| `[:sigra, :auth, :logout, :stop]` | `auth.logout.success` | always success |
| `[:sigra, :reset, :requested]` | `auth.magic_link_request` or `auth.password_reset_request` | always success (enumeration-safe) |
| `[:sigra, :reset, :completed]` | `auth.password_reset_complete` | success only |
| `[:sigra, :session, :create, :stop]` | `session.create` | success only (failures = exception path) |
| `[:sigra, :session, :delete, :stop]` | `session.delete` | success only |
| `[:sigra, :session, :revoke_all, :stop]` | `session.revoke_all` | success only |
| `[:sigra, :session, :sudo, :stop]` | `session.sudo_enter` / `session.sudo_expire` | split by outcome |
| `[:sigra, :security, :lockout]` | `security.lockout` | failure |
| `[:sigra, :security, :rate_limited]` | `security.rate_limited` | failure |
| `[:sigra, :security, :suspicious_login]` | `security.suspicious_login` | failure |
| `[:sigra, :security, :invalid_credentials]` | `security.invalid_credentials` | failure |
| `[:sigra, :mfa, :enroll, :stop]` | `mfa.enroll.success` / `mfa.enroll.failure` | split by `result` |
| `[:sigra, :mfa, :verify, :stop]` | `mfa.verify.success` / `mfa.verify.failure` | split; includes `method` |
| `[:sigra, :mfa, :disable, :stop]` | `mfa.disable` | success |
| `[:sigra, :mfa, :backup_codes, :regenerate, :stop]` | `mfa.backup_codes_regenerate` | success |
| `[:sigra, :mfa, :backup_code_used]` (add if missing) | `mfa.backup_code_used` | success |
| `[:sigra, :mfa, :trust, :granted]` | `mfa.trust_browser` | success |
| `[:sigra, :mfa, :lockout]` | `mfa.lockout` | failure |
| `[:sigra, :oauth, :authorize, :stop]` | `oauth.authorize` | success |
| `[:sigra, :oauth, :callback, :stop]` | `oauth.callback.success` / `oauth.callback.failure` | split |
| `[:sigra, :oauth, :link, :stop]` | `oauth.link` | success |
| `[:sigra, :oauth, :unlink, :stop]` | `oauth.unlink` | success |
| `[:sigra, :oauth, :register, :stop]` | `oauth.register_via_oauth` | success |
| `[:sigra, :oauth, :login, :stop]` | `oauth.login_via_oauth` | success |
| `[:sigra, :api_token, :create, :stop]` | `api.token_create` | success |
| `[:sigra, :api_token, :verify, :stop]` (FAILURE ONLY per D-27) | `api.token_verify.failure` | failure only — skip success |
| `[:sigra, :api_token, :revoke, :stop]` | `api.token_revoke` | success |
| `[:sigra, :jwt, :refresh, :stop]` | `api.jwt_refresh` | success |
| `[:sigra, :jwt, :refresh_reuse_detected]` | `api.jwt_refresh_reuse` | failure |
| `[:sigra, :email_change, :request, :stop]` | `account.email_change_request` | success |
| `[:sigra, :email_change, :confirm, :stop]` | `account.email_change_confirm` | success |
| `[:sigra, :email_change, :cancel, :stop]` | `account.email_change_cancel` | success |
| `[:sigra, :password, :change, :stop]` | `account.password_change` | success |
| `[:sigra, :password, :force_change_completed, :stop]` | `account.password_change` | success (same action, `metadata.forced: true`) |
| `[:sigra, :account, :deletion_scheduled]` | `account.deletion_schedule` | success |
| `[:sigra, :account, :deletion_cancelled]` | `account.deletion_cancel` | success |
| `[:sigra, :account, :deleted]` | `account.deletion_execute` | success |

**Planner note:** This table IS the integration checklist — one task per row (or one task per subsystem: auth, session, mfa, oauth, api, account, security — seven tasks total is more Wave-friendly).

## 3. Cursor Pagination Pattern for Append-Only Tables

**Cursor format:** `Base.url_encode64("#{inserted_at_usec}|#{id}", padding: false)` where `inserted_at_usec` is `DateTime.to_unix(dt, :microsecond)` and `id` is the UUID string. Base64URL (no padding) so it's safe in query strings.

**Decode:**
```elixir
def decode(cursor) do
  with {:ok, raw} <- Base.url_decode64(cursor, padding: false),
       [ts_str, id] <- String.split(raw, "|", parts: 2),
       {ts_int, ""} <- Integer.parse(ts_str),
       {:ok, dt} <- DateTime.from_unix(ts_int, :microsecond) do
    {:ok, {dt, id}}
  else
    _ -> {:error, :invalid_cursor}
  end
end
```

**Query shape with tiebreak on id** (Ecto 3.x does NOT support row-constructor `(a,b) > (c,d)` portably across PG/MySQL/SQLite — use explicit boolean expansion, NO `fragment`):

```elixir
# Descending (most recent first) — forward = older rows
from e in audit_schema,
  where: e.inserted_at < ^cursor_ts or
         (e.inserted_at == ^cursor_ts and e.id < ^cursor_id),
  order_by: [desc: e.inserted_at, desc: e.id],
  limit: ^(limit + 1)  # +1 to detect has_next
```

`limit + 1` then drop the tail to compute `next_cursor` from the last kept row. This avoids `COUNT(*)` per page and works identically on PG/MySQL/SQLite. The `(actor_id, inserted_at)` and `(inserted_at)` indexes from D-06 cover the hot filter paths.

## 4. Changeset Validators

```elixir
defmodule Sigra.Audit.Changeset do
  import Ecto.Changeset

  @action_regex ~r/^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/
  @forbidden_keys ~w(password password_hash password_confirmation
                     totp_code totp_secret backup_code
                     session_token bearer_token api_key
                     access_token refresh_token oauth_secret
                     client_secret)a

  def forbidden_keys, do: @forbidden_keys

  def changeset(event, attrs, opts \\ []) do
    max_bytes = Keyword.get(opts, :max_metadata_bytes, 8_192)
    reserved = Keyword.get(opts, :reserved_prefixes,
                 ~w(auth. session. mfa. oauth. api. account. sigra.))
    allow_reserved? = Keyword.get(opts, :allow_reserved, false)

    event
    |> cast(attrs, [:action, :outcome, :actor_id, :actor_type, :target_id,
                    :target_type, :ip_address, :user_agent, :metadata, :occurred_at])
    |> validate_required([:action, :outcome, :occurred_at])
    |> validate_format(:action, @action_regex, message: "must be namespaced snake_case")
    |> validate_inclusion(:outcome, ~w(success failure error))
    |> validate_reserved_prefix(reserved, allow_reserved?)
    |> validate_metadata_size(max_bytes)
    |> validate_metadata_keys()
  end

  defp validate_reserved_prefix(cs, _reserved, true), do: cs
  defp validate_reserved_prefix(cs, reserved, false) do
    validate_change(cs, :action, fn :action, action ->
      if Enum.any?(reserved, &String.starts_with?(action, &1)),
        do: [action: {"uses reserved Sigra prefix", [validation: :reserved_prefix]}],
        else: []
    end)
  end

  defp validate_metadata_size(cs, max_bytes) do
    validate_change(cs, :metadata, fn :metadata, map ->
      case map && byte_size(Jason.encode!(map)) do
        nil -> []
        n when n <= max_bytes -> []
        n -> [metadata: {"serialized size #{n}B exceeds cap #{max_bytes}B", []}]
      end
    end)
  end

  defp validate_metadata_keys(cs) do
    validate_change(cs, :metadata, fn :metadata, map ->
      case map && find_forbidden(map) do
        nil -> []
        [] -> []
        keys -> [metadata: {"contains forbidden keys: #{inspect(keys)}", []}]
      end
    end)
  end

  defp find_forbidden(map) when is_map(map) do
    Enum.filter(@forbidden_keys, fn fk ->
      Map.has_key?(map, fk) or Map.has_key?(map, Atom.to_string(fk))
    end)
  end
end
```

The private `__log_internal__/3` path passes `allow_reserved: true` into this changeset; public `log/3` does not.

## 5. Optional Oban Worker Pattern (cloned from TokenCleanup)

From `lib/sigra/workers/token_cleanup.ex` lines 20–22 (verified):

```elixir
use Oban.Worker,
  queue: :sigra_mailer,
  max_attempts: 1
```

**For `Sigra.Workers.AuditCleanup`** — clone the same signature (queue can be `:sigra_audit` if host app wants isolation, but defaulting to `:sigra_mailer` keeps it in the same pool TokenCleanup uses):

```elixir
defmodule Sigra.Workers.AuditCleanup do
  use Oban.Worker,
    queue: :sigra_mailer,
    max_attempts: 1

  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    repo = String.to_existing_atom(args["repo"])
    audit_schema = String.to_existing_atom(args["audit_schema"])
    retention_days = args["retention_days"]
    cleanup(repo, audit_schema, retention_days)
    {:ok, :cleaned}
  end

  @spec cleanup(module(), module(), pos_integer() | nil) :: :ok
  def cleanup(_repo, _schema, nil), do: :ok  # D-09 forever default
  def cleanup(repo, audit_schema, retention_days) do
    cutoff = DateTime.add(DateTime.utc_now(), -retention_days * 86_400, :second)
    from(e in audit_schema, where: e.inserted_at < ^cutoff)
    |> repo.delete_all()
    :ok
  end
end
```

**Inline fallback (D-10, Phase 1 D-36 fail-open pattern):** `Sigra.Audit.cleanup/1` delegates to `Sigra.Workers.AuditCleanup.cleanup/3`. Host apps without Oban call `Sigra.Audit.cleanup(config)` from their own scheduler. On `application start`, if `retention_days` is set AND Oban is absent, log a `:warning` advising the fallback path. Matches the Hammer/Oban absent pattern cited in Phase 1 D-36.

**Verified — no `unique` constraint** in `TokenCleanup.use Oban.Worker`. AuditCleanup does not need one either (daily cron; accidental double-run is idempotent since it's a `delete_all` of already-expired rows).

## 6. Generated Schema vs Library Code Split

**Verified pattern from `lib/sigra/session_stores/ecto.ex`, `lib/sigra/api_token.ex`, `lib/sigra/auth.ex`:**

- Generated schema module (e.g., `MyApp.Accounts.UserToken`) lives in host app
- Library functions accept schema via **keyword opts**: `Keyword.fetch!(opts, :user_token_schema)` (auth.ex line 245) or via **Config struct** field: `Keyword.fetch!(config.api_token, :api_token_schema)` (api_token.ex line 85)
- NO `Application.get_env` lookup — config flows through `%Sigra.Config{}` or per-call opts
- Schema is referenced as a bare module atom in Ecto queries: `from(t in token_schema, where: ...)`

**For `Sigra.Audit`:** Add `audit: [audit_schema: MyApp.Accounts.AuditEvent, retention_days: nil, max_metadata_bytes: 8_192, reserved_prefixes: [...]]` to `%Sigra.Config{}`. Public API accepts `:audit_schema` and `:repo` as explicit opts or pulls them from `%Sigra.Config{}` when given a config struct. Matches `api_token` precedent.

The generated `AuditEvent` schema module (in host app) defines `@primary_key {:id, :binary_id, autogenerate: true}`, the field list from D-05, and a `changeset/2` that delegates to `Sigra.Audit.Changeset.changeset/3`. This keeps validation logic library-owned (updatable via `mix deps.update`) while the schema file itself is owned by the host app (D-27).

## 7. Telemetry Passthrough on Successful Commit

**Placement rule:** `[:sigra, :audit, :log]` fires from the `{:ok, _}` branch AFTER `repo.transaction/1` returns, NEVER from inside `Multi.insert`'s factory function. A Multi that rolls back must not emit audit telemetry — otherwise an observer would see events that never persisted.

```elixir
case repo.transaction(multi) do
  {:ok, %{audit: event} = changes} ->
    :telemetry.execute(
      [:sigra, :audit, :log],
      %{count: 1},
      %{action: event.action, actor_id: event.actor_id, outcome: event.outcome}
    )
    {:ok, changes}

  {:error, _step, _reason, _changes} = err ->
    err  # no telemetry fired
end
```

**For `log_multi/3` caller-owned transactions:** the caller runs `repo.transaction`. `Sigra.Audit` cannot wrap it. Solution: expose `Sigra.Audit.emit_telemetry_from_changes/1` helper that inspects `changes[:audit]` and fires the event. Callers invoke it in the `{:ok, changes}` branch. Alternative: use Ecto's `after_commit: true` hook in the changeset — cleaner, no caller burden. **Recommend the `after_commit` hook** since Ecto 3.x supports it via `Ecto.Changeset.prepare_changes/2` + `Ecto.Repo` callbacks. Planner should verify `prepare_changes` vs a `Multi.run(:audit_telemetry, ...)` step and pick one consistent approach.

## Runtime State Inventory

Not applicable — Phase 9 is greenfield (new table, new module, new worker). No rename/refactor.

## Environment Availability

Not applicable — no new external dependencies. Phase 9 uses existing deps: Ecto, Jason (already transitive via Phoenix/Plug), optional Oban (already optional across Sigra).

## 8. Validation Architecture

**Test framework:** ExUnit (Elixir stdlib). Config: `test/test_helper.exs` (existing). Quick run: `mix test test/sigra/audit_test.exs -x`. Full suite: `mix test`. Property tests via `stream_data` (already in `mix.exs` as test-only dep — verify in Wave 0; if absent, add `{:stream_data, "~> 1.1", only: [:dev, :test]}`).

### Unit tests
- `Sigra.Audit.Changeset` — action regex (valid: `auth.login.success`, `billing.charge_failed.retry`; invalid: `Auth.Login`, `foo`, `foo.`, `.foo`, `foo..bar`, empty string)
- Outcome inclusion validator — rejects anything outside `success|failure|error`
- Reserved prefix validator — `auth.foo` rejected in public mode, accepted when `allow_reserved: true`
- Metadata size cap — exactly-at-cap accepted, cap+1 rejected; configurable cap honored
- Forbidden key detector — both atom and string keys (`"password"` and `:password`); nested maps (decide: flat-only or deep scan — recommend flat-only for Phase 9, deep in a later hardening phase)
- `Sigra.Audit.Cursor.encode/1` + `decode/1` roundtrip for a known `{DateTime, UUID}` pair
- `Sigra.Audit.Query` — each filter from D-12 composes into correct Ecto.Query AST (use `inspect/1` or `Ecto.Adapters.SQL.to_sql/3` for assertion)

### Integration tests
- `log/3` single-transaction happy path: row inserted, telemetry fires, returns `{:ok, event}`
- `log/3` with changeset failure (bad action): returns `{:error, changeset}`, NO row inserted, NO telemetry
- `log_multi/3` composed with business op (user insert): both rows committed
- `log_multi/3` business op fails: audit row rolled back (verify with `Repo.aggregate(:count)` before/after)
- `list/2` forward pagination across 3 pages of 50 rows each (inject 125 rows, walk cursors, assert last cursor nil)
- `list/2` with identical `inserted_at_usec` on tiebreak — rows ordered by `id desc` deterministically
- `stream/2` inside `Repo.transaction` — streams 10k rows without OOM, each row an `AuditEvent` struct
- `count/2` matches `list/2 |> length()` for bounded fixture set
- `query/1` output composes with extra `where` — e.g., `Audit.query(actor_id: u.id) |> where(...) |> Repo.all`

### Property tests (`stream_data`)
- Cursor monotonicity — for any sorted list of `{DateTime, UUID}` pairs, decoded cursors yield the same ordering
- Forbidden keys — for any map containing at least one forbidden key (drawn from `forbidden_keys/0`), changeset is invalid
- Action regex — generator of valid action strings always passes; generator of invalid strings (uppercase, leading digit, trailing dot, <2 segments) always fails
- Action prefix filter — `action_prefix: "auth."` matches EXACTLY the subset of actions starting with `auth.` in a random sample of mixed-prefix rows

### Cross-database tests
- Migration runs clean on PG, MySQL, SQLite (use the existing matrix CI job if present; else flag Wave 0 gap)
- `:map` field read/write parity: insert `%{"foo" => 1, "bar" => [1,2,3]}`, read back, assert equality on all three adapters
- Public query API contains zero `fragment/2` calls (assert via `File.read!/1` + `String.contains?/2` on `lib/sigra/audit/query.ex` — simple grep test)

### Observability tests
- `[:sigra, :audit, :log]` fires exactly once per successful `log/3` (use `:telemetry_test.attach_event_handlers/2`)
- Does NOT fire when `log_multi/3`'s enclosing transaction rolls back
- Metadata contains `:action`, `:actor_id`, `:outcome` keys

### Sensitive data tests
- Parameterized test over `Sigra.Audit.Changeset.forbidden_keys/0`: each key as metadata triggers changeset error
- Integration: drive each `Sigra.Auth` entry point mapped in §2 with fixture inputs, capture inserted audit rows, assert `metadata` contains NO forbidden key. This is the regression net for D-23.

### Performance tests (smoke-level, not load test)
- `log/3` median latency < 1 ms on SQLite in-memory test repo; p99 < 5 ms (relaxed SLO for test env; production p99 overhead on login < 2 ms documented as target, not test-enforced)
- Cursor pagination over 10k rows: `list/2` with `limit: 50` executes in < 20 ms. Verify via `:timer.tc/1`
- On PostgreSQL (if CI has a PG service), `EXPLAIN` on the `actor_id + inserted_at` query plan uses the `(actor_id, inserted_at)` index (use `Repo.query!("EXPLAIN ...")` and assert on output)

### Security tests
- `Sigra.Audit.log/3` returns `{:error, changeset}` with `:reserved_prefix` validation error for EACH reserved prefix in D-17 list (one assertion per prefix)
- `__log_internal__/3` is NOT in `Sigra.Audit`'s public docs — grep `@spec __log_internal__` returns a result but `@doc false` precedes it
- `log_multi/3` with `allow_reserved: false` (default) on `auth.*` rejects via changeset; same call with `allow_reserved: true` (internal path) succeeds
- Metadata cap cannot be bypassed via nested structures larger than cap when JSON-encoded

### Wave 0 gaps
- [ ] `test/sigra/audit_test.exs` — top-level API tests
- [ ] `test/sigra/audit/changeset_test.exs` — unit tests for validators
- [ ] `test/sigra/audit/cursor_test.exs` — encode/decode roundtrip + property tests
- [ ] `test/sigra/audit/query_test.exs` — query composition
- [ ] `test/sigra/workers/audit_cleanup_test.exs` — worker + inline fallback
- [ ] `test/support/audit_fixtures.ex` — `audit_event_fixture/1`, `assert_audit_event/2` helpers (flagged for Phase 10 per CONTEXT §Established Patterns)
- [ ] Verify `stream_data` dep presence; if missing, add in Wave 0

## Security Domain

### Applicable ASVS Categories

| ASVS | Applies | Standard Control |
|------|---------|------------------|
| V5 Input Validation | yes | Ecto.Changeset with regex, size cap, forbidden-key scanner (§4) |
| V6 Cryptography | no | No crypto in audit path; UUIDs from Ecto, no signing on cursors (D-13 intentional) |
| V7 Error Handling & Logging | **yes (primary)** | This entire phase IS the V7 control — structured audit logging with integrity via transactional atomicity (D-01) |
| V8 Data Protection | yes | D-23 forbidden metadata keys prevent sensitive data at rest in audit rows |
| V10 Malicious Code | no | N/A |
| V13 API | yes | Reserved-prefix guardrail (D-17) prevents forgery of internal audit actions by application code paths |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Audit log tampering by app code | Tampering | Immutability by convention (D-08); no update/delete API except retention cleanup |
| Forged internal events (app code writes `auth.login.success`) | Spoofing | Reserved-prefix validator (D-17/D-18) enforced in public `log/3` |
| Missing audit trail on crash (telemetry handler detach) | Repudiation | D-01/D-02 — direct Multi writes, NOT telemetry subscribers |
| Sensitive data leaked into audit rows | Information Disclosure | D-23 forbidden-key validator (§4) |
| Audit table DoS via giant metadata blobs | DoS | D-20 metadata size cap (§4) |
| Audit log query enumeration via offset | Information Disclosure | D-13 cursor pagination — no offset |
| Cursor tampering to leak row contents | Tampering | Low impact — cursors only carry `(timestamp, id)`; decoded cursor feeds a `WHERE` filter, worst case is different pagination window. Not signing is intentional (D-13 discretion). |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `stream_data` is already a test dep | §8 Wave 0 | LOW — add to `mix.exs` in Wave 0 if absent |
| A2 | Using `repo.transaction(multi)` (not `Repo.transact/2`) is preferred to match existing Auth code style | §1 | LOW — cosmetic; both work; planner can override |
| A3 | Row-constructor comparison `(a,b) > (c,d)` is not portable across PG/MySQL/SQLite in Ecto 3.13 without `fragment` | §3 | MEDIUM — if wrong, query is uglier than needed but still correct. Ecto supports explicit `or` expansion on all three. [ASSUMED based on Ecto 3.13 source behavior; verify with a smoke test in Wave 0] |
| A4 | Ecto `prepare_changes` can schedule an `after_insert` callback that fires telemetry only on commit | §7 | MEDIUM — alternative is `Multi.run(:audit_telemetry, ...)` step wrapped around the insert. Planner should verify and pick one. |
| A5 | Forbidden-key scan is flat-only (not deep) for Phase 9 | §8 | LOW — deep scan deferred; document the limit. A malicious developer could hide a forbidden key under a nested map; telemetry-based detection catches this in downstream SIEM. |
| A6 | All D-26 operations listed in §2 have a matching `Telemetry.span` or one-shot event already — no net-new telemetry needed | §2 | LOW — grep confirms all listed prefixes exist; `mfa.backup_code_used` is the one potential gap (not seen in telemetry.ex) — flagged below |

## 9. Open Questions for the Planner (RESOLVED)

1. **`mfa.backup_code_used` audit action has no matching telemetry event today** — `lib/sigra/telemetry.ex` does not emit `[:sigra, :mfa, :backup_code_used]` (only `mfa.verify` with `method: :backup_code` metadata). Options: (a) split audit action from telemetry, emit `mfa.backup_code_used` audit row alongside `mfa.verify.success` telemetry; (b) add the telemetry event in this phase. **Recommendation: (a)** — audit source is direct writes, not telemetry (D-01), so the lack of a parallel telemetry event is not a blocker.

   **RESOLVED:** Direct-write audit row with no new telemetry event. Plan 03 Task 2 writes the audit row inside the backup-code verify Multi (alongside the `mfa.verify.success` row). Source of truth is the audit row, not telemetry.

2. **`session.sudo_enter` vs `session.sudo_expire`** — current telemetry is a single `[:sigra, :session, :sudo, :stop]` span. The audit split by outcome requires either inspecting the span's result metadata at call sites or adding a second telemetry event. **Recommendation:** Inspect result in the Multi step factory; no new telemetry.

   **RESOLVED:** Plan 03 Task 1 branches on the result tuple at the `Sigra.Session` call site and writes the appropriate action string (`session.sudo_enter` on entry, `session.sudo_expire` on expiry). No new telemetry event is added.

3. **`after_commit` telemetry vs explicit `Multi.run` step (§7)** — planner should verify the cleaner path by testing both during implementation. Both are correct; one is more ergonomic for custom callers of `log_multi/3`.

   **RESOLVED:** Override research recommendation. Telemetry fires from the `{:ok, _}` return branch of standalone `Sigra.Audit.log/3`. For `Sigra.Audit.log_multi/3`, callers manually invoke `Sigra.Audit.emit_telemetry_from_changes/1` in their own `{:ok, changes}` branch. Rationale: avoids `prepare_changes`/`after_commit` hooks (Ecto-version fragile) and guarantees telemetry never fires when the outer transaction rolls back. Documented in Plan 02 Task 2 and in the `Sigra.Audit` moduledoc.

All other planning questions are resolved by CONTEXT.md.

## Sources

### Primary (HIGH confidence — verified in this session)
- `.planning/phases/09-audit-logging/09-CONTEXT.md` — 28 locked decisions
- `lib/sigra/telemetry.ex` — event catalog (lines 1–367)
- `lib/sigra/workers/token_cleanup.ex` — Oban worker pattern (lines 20–22, 56–70)
- `lib/sigra/auth.ex` — Multi composition (lines 370–413), schema-via-opts pattern (lines 245, 302, 356)
- `lib/sigra/session_stores/ecto.ex`, `lib/sigra/api_token.ex` — config-struct schema lookup pattern

### Secondary (not consulted — locked by CONTEXT.md)
- WorkOS audit log guide, Rodauth audit_logging plugin, Better Auth audit logs — referenced in CONTEXT as design inputs; not re-researched per 15-min time budget

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all deps already in Sigra, no new libraries
- Architecture: HIGH — 28 locked decisions + verified codebase patterns
- Pitfalls: HIGH — Multi rollback / telemetry ordering is the one real trap, documented in §7
- Mapping (§2): MEDIUM — derived from telemetry.ex + D-26 wording; one gap flagged (A6, Q1)

**Research date:** 2026-04-09
**Valid until:** 2026-05-09 (30 days; Ecto and Phoenix stable)

## RESEARCH COMPLETE
