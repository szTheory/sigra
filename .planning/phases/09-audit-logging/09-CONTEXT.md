# Phase 9: Audit Logging - Context

**Gathered:** 2026-04-09
**Status:** Ready for planning

<domain>
## Phase Boundary

All security-relevant auth events are automatically captured in a queryable audit log with structured metadata. The library writes audit rows atomically alongside business operations via `Ecto.Multi`, exposes a composable query API for developers and admin UIs, and allows developers to emit their own custom audit events through the same table and API with guardrails against forgery and abuse.

**In scope:**
- `audit_events` table (generated into host app per D-27)
- `Sigra.Audit` module with log/query/list/stream/count functions
- Integration into existing `Sigra.Auth` functions via `Ecto.Multi`
- Custom event API (AUDIT-04) with namespace guardrails
- Library-side telemetry passthrough `[:sigra, :audit, :log]`

**Out of scope:**
- Admin LiveView for browsing audit logs (future phase / host-app concern)
- SIEM export format helpers (CSV, JSONL)
- Full-text search on metadata
- Hash-chained tamper-evident audit
- PostgreSQL table partitioning (documented as scaling guide only)
- Aggregation / reporting / BI functions
- Multi-tenancy / `tenant_id` column (orgs deferred to v2 per PROJECT.md)

</domain>

<decisions>
## Implementation Decisions

### Capture Mechanism

- **D-01:** Audit events are captured via **direct `Ecto.Multi` writes** in the same transaction as the business operation. Each `Sigra.Auth` function that produces an auditable event adds a `Multi.insert(:audit, ...)` step before committing. Atomicity is guaranteed: operation and audit row succeed or fail together.

- **D-02:** **Telemetry is NOT the audit capture mechanism.** Existing `[:sigra, :auth, :*]`, `[:sigra, :session, :*]`, etc. telemetry events continue to fire for observability, metrics, and Logger integration — but the audit log does not subscribe to them. Rationale: telemetry handlers auto-detach on crash (confirmed in telemetry v1.4.1 docs and Elixir Forum thread 56069), silently creating audit gaps. Disqualifying for security-grade logging.

- **D-03:** This matches the architectural precedent of Rodauth (the gold standard cited in PROJECT.md), PaperTrail, Better Auth, and the Elixir Forum community consensus. Event/observer patterns are used by libraries that *delegate* audit to the app; libraries that *own* the audit write directly.

### Storage and Schema

- **D-04:** Table name: **`audit_events`** (matches D-27 reservation from Phase 1 and Sigra's telemetry naming convention — events, not logs).

- **D-05:** Schema fields:
  - `id :binary_id` (UUID primary key — matches existing schema conventions)
  - `occurred_at :utc_datetime_usec` (when the event happened; set by caller)
  - `inserted_at :utc_datetime_usec` (when the row was written; set by Ecto timestamps — late-arrival detection)
  - `action :string` (namespaced dot-separated: `auth.login.success`, `session.revoke`)
  - `outcome :string` (`success` | `failure` | `error`)
  - `actor_id :binary_id` (nullable — unknown on failed login with unknown email)
  - `actor_type :string` (default `"user"`; also `"system"`, `"api_key"`)
  - `target_id :binary_id` (what was acted upon; nullable)
  - `target_type :string` (Elixir schema name: `"User"`, `"UserSession"`, `"APIToken"`)
  - `ip_address :string` (string type for portability — avoids PG `inet` coupling)
  - `user_agent :string`
  - `metadata :map` (JSONB on PG, JSON on MySQL, TEXT on SQLite — Ecto `:map` adapter handles it)
  - `timestamps(updated_at: false)` (audit rows are append-only — no `updated_at`)

- **D-06:** Indexes:
  - `(actor_id, inserted_at)` — "what did user X do in this window?"
  - `(action, inserted_at)` — "how many failed logins in the last hour?"
  - `(inserted_at)` — chronological scan and retention cleanup
  - No `(target_id, target_type)` index by default (add only if query patterns demand it)

- **D-07:** **No PostgreSQL-specific features required.** No partitioning, no RLS, no `inet` type, no `pg_partman` dep. Works on PostgreSQL, MySQL, and SQLite identically. Partitioning is documented as a scaling guide for host apps that hit large-table scale.

- **D-08:** **Immutability is enforced in code, not DB.** `Sigra.Audit` exposes no update/delete functions except the explicit retention cleanup (D-10). Document immutability as a convention. Host apps can add DB-level `GRANT INSERT ONLY` on PostgreSQL if they want stronger enforcement.

### Retention

- **D-09:** **Default: keep forever.** `config :sigra, :audit, retention_days: nil`. Forces developers to make an explicit retention decision. No silent data loss. Safest default for compliance (SOC 2 requires 6-12 month observation; "forever" satisfies all regulators).

- **D-10:** Optional `Sigra.Workers.AuditCleanup` Oban worker runs daily (when Oban present) and deletes rows where `inserted_at < now() - retention_days`. When Oban is absent, expose `Sigra.Audit.cleanup/1` for developers to call from their own scheduler, with a logged warning at startup (per D-36 from Phase 1 — fail-open pattern).

- **D-11:** PII/GDPR handling: **audit rows are naturally pseudonymized** because `actor_id` is a UUID (no email/PII in audit row). When Phase 8 deletion runs `hard_delete` or `anonymize` strategy, audit rows keep their UUID references intact — the referenced user is gone or anonymized, but the audit trail remains. This preserves security forensics while complying with "right to erasure" (the personal data is erased; the audit trail of what that user did survives).

### Query API Surface

- **D-12:** `Sigra.Audit` public API (5 functions):
  - `log(action, opts)` — write a single audit event. Opts: `:actor_id`, `:actor_type`, `:target_id`, `:target_type`, `:outcome` (default `"success"`), `:ip_address`, `:user_agent`, `:metadata`, `:repo`, `:multi`. When `:multi` is passed, returns an `Ecto.Multi` chain; otherwise runs its own transaction.
  - `query(filters)` — returns an `Ecto.Query.t()`. Filters: `:actor_id`, `:action`, `:action_prefix`, `:outcome`, `:from`, `:to`, `:target_id`, `:target_type`. Composable — advanced users can add `where`, `order_by`, `join` before executing.
  - `list(filters, opts)` — cursor-paginated fetch. Returns `%{entries: [AuditEvent.t()], next_cursor: String.t() | nil}`. Opts: `:limit` (default 50, max 500), `:cursor`, `:repo`.
  - `stream(filters, opts)` — `Enumerable.t()` for large result sets (SIEM export, compliance archival). Caller wraps in `Repo.transaction/1`.
  - `count(filters, opts)` — separate from `list` to make the O(n) cost explicit at the API level.

- **D-13:** **Cursor pagination, not offset.** Cursor encoded as `Base64(inserted_at_usec|id)`. Scales to billions of rows. Offset pagination defeats partition pruning (when host apps add it later) and slows linearly with dataset size.

- **D-14:** **`action_prefix` filter is mandatory.** Enables tiered queries like `action_prefix: "auth."` matching `auth.login.*`, `auth.logout.*`, `auth.register.*`. Uses the action namespace hierarchy defined in D-17.

- **D-15:** Internal Sigra modules use a private `Sigra.Audit.__log_internal__/3` path that bypasses namespace guardrails (D-19). Developer code uses `Sigra.Audit.log/3` which enforces the reserved-prefix check.

### Custom Events (AUDIT-04)

- **D-16:** Custom events use the same `Sigra.Audit.log/3` entry point, same `audit_events` table, same query API. No separate module, no separate table. One surface, one mental model.

- **D-17:** Sigra reserves these action prefixes for its own internal events: `auth.`, `session.`, `mfa.`, `oauth.`, `api.`, `account.`, `sigra.`. Developer custom events must use a different namespace (`billing.`, `admin.`, `content.`, etc.).

- **D-18:** Configurable reserved list: `config :sigra, :audit, reserved_prefixes: ~w(auth. session. mfa. oauth. api. account. sigra.)`. Host apps can extend the list (e.g., add `"admin."` to prevent non-admin code paths from forging admin events).

- **D-19:** Action format validation via regex `^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$`. Forces namespaced snake_case. Rejects empty strings, trailing dots, uppercase, single-segment actions. Enforced at changeset level.

- **D-20:** Metadata size cap — configurable, default 8KB (serialized JSON). Exceeding raises a changeset error at insert time. Prevents accidental blob dumps (e.g., logging a full request body). `config :sigra, :audit, max_metadata_bytes: 8_192`.

- **D-21:** Transactional use is supported identically for custom events:
  ```elixir
  Ecto.Multi.new()
  |> Ecto.Multi.insert(:sub, subscription_changeset)
  |> Sigra.Audit.log_multi("billing.subscription.created", actor_id: user.id, metadata: %{plan: "pro"})
  |> Repo.transact()
  ```
  `log_multi/3` is a thin wrapper over `log/3` that forces `:multi` usage.

- **D-22:** **Outcome is required in the schema, defaulted in `log/3`** (`"success"` when unspecified). Forces schema validation but keeps the 80% happy path clean.

### Sensitive Data Policy

- **D-23:** Metadata follows Phase 1 D-17 policy strictly: **NEVER** include passwords, password hashes, TOTP codes, bearer tokens, raw session tokens, OAuth secrets, or refresh tokens. This is a changeset-level enforcement — `Sigra.Audit.Changeset.forbidden_keys/0` lists forbidden metadata keys and the changeset rejects any metadata map containing them. User IDs (not emails), session types, outcome booleans, and context counters are fine.

### Telemetry Integration (Observability Layer)

- **D-24:** Every write to `audit_events` (internal or custom) also fires a telemetry event: `[:sigra, :audit, :log]` with metadata `%{action: action, actor_id: actor_id, outcome: outcome}`. Lets host apps hook observability/metrics/SIEM forwarding onto the write without polling the DB. Follows D-15 from Phase 1.

- **D-25:** Existing telemetry events (`[:sigra, :auth, :login, :stop]`, etc.) continue firing unchanged — they are observability signals, not audit. The audit log is fed by direct writes inside Auth functions, not by telemetry subscribers.

### Integration into Existing Auth Functions

- **D-26:** Every operation in `Sigra.Auth` that produces an auditable event is updated to include an `Ecto.Multi.insert(:audit, ...)` step. Target operations (mapped from existing telemetry catalog):
  - **auth:** `register`, `login` (success + failure), `logout`, `magic_link_request`, `magic_link_verify`
  - **session:** `create`, `delete`, `revoke_all`, `sudo_enter`, `sudo_expire`
  - **security:** `lockout`, `unlock`, `rate_limited`, `suspicious_login`, `invalid_credentials`
  - **mfa:** `enroll`, `verify` (success + failure), `disable`, `backup_code_used`, `backup_codes_regenerate`, `trust_browser`, `lockout`
  - **oauth:** `authorize`, `callback`, `link`, `unlink`, `register_via_oauth`, `login_via_oauth`
  - **api:** `token_create`, `token_verify` (failure only — success is too noisy), `token_revoke`, `jwt_refresh`
  - **account:** `email_change_request`, `email_change_confirm`, `email_change_cancel`, `password_change`, `deletion_schedule`, `deletion_cancel`, `deletion_execute`

- **D-27:** For operations where failure is expected and noisy (e.g., `token_verify` on every API request), only failures are audited. Successes are covered by telemetry alone. Trade-off: audit table growth vs. auditability of routine reads.

- **D-28:** For operations that happen outside a Multi context (e.g., failed login with an unknown email — nothing to commit alongside), `Sigra.Audit.log/3` runs its own single-row transaction. Still atomic, still durable.

### Claude's Discretion

- Exact internal module structure (`Sigra.Audit`, `Sigra.Audit.AuditEvent`, `Sigra.Audit.Changeset`, `Sigra.Audit.Cursor`, `Sigra.Workers.AuditCleanup` — naming/splitting is planner's call)
- Cursor encoding format details (Base64 vs Base64URL vs signed format)
- Exact set of telemetry metadata emitted with `[:sigra, :audit, :log]` beyond the listed fields
- Error tuple shapes for validation failures (`{:error, :reserved_action_prefix}` vs `{:error, changeset}`)
- Whether `count/2` uses estimated counts on PG for large tables
- Migration file format and generator template structure

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Prior Phase Decisions (load-bearing)

- `.planning/phases/01-foundation/01-CONTEXT.md` §Telemetry Design — D-14 (AuditLogger behaviour deferred to Phase 9), D-15 (event naming convention `[:sigra, :subsystem, :operation]`), D-16 (`attach_default_logger` pattern), D-17 (sensitive data policy — NEVER log passwords/hashes/tokens), D-18 (telemetry span for sync ops)
- `.planning/phases/01-foundation/01-CONTEXT.md` §Data Layer — D-27 (audit_events table reserved for Phase 9)
- `.planning/phases/01-foundation/01-CONTEXT.md` §Optional Dependencies — D-36 (Oban absent = inline fallback, Hammer absent = fail-open with logged warning) — applies to AuditCleanup worker
- `.planning/phases/04-session-management-and-security-baseline/04-CONTEXT.md` §Telemetry — D-54 through D-57 (session/security telemetry metadata shape, geo fields)
- `.planning/phases/08-account-lifecycle/08-CONTEXT.md` — Account deletion strategies (soft_delete, hard_delete, anonymize) — audit rows keep UUID references regardless of strategy (D-11)

### Requirements

- `.planning/REQUIREMENTS.md` §Audit — AUDIT-01 (automatic capture), AUDIT-02 (metadata fields), AUDIT-03 (queryable API), AUDIT-04 (custom events hook)

### Project-Level

- `.planning/PROJECT.md` §Context — "Database design: Hybrid user/identity pattern ... Separate tables per concern (tokens, passkeys, MFA credentials, API keys, audit log)" — reinforces separate `audit_events` table
- `.planning/PROJECT.md` §Out of Scope — Organizations/multi-tenancy deferred to v2 — confirms no `tenant_id` column
- `CLAUDE.md` — Phoenix 1.8+ / Ecto 3.x blessed path, PostgreSQL primary with MySQL/SQLite support via conditional migrations, minimal transitive deps

### Existing Code (read before planning)

- `lib/sigra/telemetry.ex` — Existing 60+ event catalog. The D-26 mapping from operations to audit events derives from this list. Do not duplicate the catalog; reference it.
- `lib/sigra/auth.ex` — 1154-line orchestrator. Every entry point that calls `Telemetry.span/3` is a candidate for audit integration (D-26).
- `lib/sigra/workers/token_cleanup.ex` — Pattern for `AuditCleanup` worker (queue, max_attempts, cleanup_by_context)
- `lib/sigra/workers/account_deletion.ex` — Pattern for scheduled/recurring Oban worker
- `lib/sigra/hooks.ex` — Existing hook pattern. Audit is NOT routed through hooks — it's direct Multi writes. Referenced only to explain why audit is different.

### Research Artifacts (informational)

- No external spec docs. The schema design in D-05 synthesizes from WorkOS audit log guide, Rodauth audit_logging docs, and Better Auth audit logs plugin — no single doc to link.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets

- **`Sigra.Telemetry.span/3` and event catalog** (`lib/sigra/telemetry.ex`) — 60+ auth events already defined. Audit integration maps directly onto these (D-26). The catalog is the authoritative list of auditable operations.
- **`Ecto.Multi` transactional pattern** — already used throughout `Sigra.Auth` (register, login, MFA verify, account deletion). Adding an `insert(:audit, ...)` step is a 1-line change per operation.
- **Oban worker patterns** (`lib/sigra/workers/token_cleanup.ex`, `lib/sigra/workers/account_deletion.ex`) — `AuditCleanup` worker follows the same structure (queue, max_attempts, unique constraints).
- **`Sigra.Session` metadata capture** (`lib/sigra/session.ex`) — already captures `ip`, `user_agent`, `geo_city`, `geo_country_code`. These flow into audit events as metadata.
- **Hybrid user/identity pattern** — `actor_id :binary_id` matches the existing `users.id` type. No new UUID generation needed.

### Established Patterns

- **Sensitive data policy (D-17 from Phase 1)** — already enforced in telemetry metadata. Same policy applies verbatim to audit metadata. Test helpers can assert no forbidden keys.
- **Optional dep pattern** — Oban optional (inline fallback), Hammer optional (no-op fallback). `AuditCleanup` worker follows the same pattern: if Oban is present, use it; otherwise expose `Sigra.Audit.cleanup/1` for manual scheduling.
- **Generated code vs library code split** — `audit_events` migration + `AuditEvent` schema are GENERATED into the host app (matches `UserToken`, `UserSession`, `APIToken`). `Sigra.Audit` module lives in the library.
- **Nested module naming (max 3 levels)** — D-01 from Phase 1. `Sigra.Audit`, `Sigra.Audit.Cursor`, `Sigra.Audit.Changeset` — all within the limit.
- **Test fixtures pattern** — `log_in_user/2` style helpers from Phase 10 will need `audit_event_fixture/1` or `assert_audit_event/2` helpers. Flagged for Phase 10 integration.

### Integration Points

- `Sigra.Auth` — every auditable function updated with `Multi.insert(:audit, ...)` step
- `Sigra.Session.create/delete` — existing functions call `Sigra.Audit.log/3` with session metadata
- `Sigra.MFA.*`, `Sigra.OAuth.*`, `Sigra.Account.*` — same pattern across each subsystem
- `Sigra.Plug.FetchSession` / `Sigra.Plug.FetchBearer` — captured IP/UA become the audit `ip_address`/`user_agent` via `Plug.Conn` metadata propagation
- Generator (`mix sigra.install`) — adds `audit_events` migration and `AuditEvent` schema alongside existing generated files; optionally appends `AuditCleanup` worker to host app's Oban config

</code_context>

<specifics>
## Specific Ideas

- The action namespace hierarchy (`auth.*`, `session.*`, etc.) mirrors the existing telemetry event naming from D-15. Deliberate choice — lets SIEM integrations and metrics dashboards reuse the same namespace vocabulary across both observability and audit.
- The "outcome" field is a string, not a boolean. Three-value outcome (`success | failure | error`) distinguishes expected failures (wrong password) from unexpected errors (DB timeout). Boolean would conflate these.
- Cursor format `Base64(inserted_at_usec|id)` — not signed/tamper-proof on purpose. Cursors leak nothing sensitive (only timestamps) and signing adds complexity for no security benefit.
- The decision to reject internal audit via telemetry (D-02) is the most load-bearing decision in this phase. The alternative was attractive (zero code changes to Auth) but the silent-failure mode is disqualifying for security audit.

</specifics>

<deferred>
## Deferred Ideas

- **Admin LiveView for browsing audit log** — likely Phase 10 or a separate milestone. Phase 9 provides the data layer and API; UI is separate.
- **Hash-chained tamper-evident audit rows** — regulated-industry feature (HIPAA, PCI-DSS higher tiers). Can be added post-v1 via a changeset hook on `AuditEvent` without breaking the API.
- **SIEM export format helpers** (`to_csv`, `to_jsonl`) — host-app concern; not library's job.
- **Aggregation/reporting functions** (`count_by_action`, `failed_logins_per_hour`) — BI concern; use the `query/1` composable output.
- **Full-text search on metadata** — SIEM concern; use external tooling.
- **PostgreSQL native table partitioning support** — document in a scaling guide; provide a sample migration for converting `audit_events` to a partitioned table when host apps hit large-table scale.
- **Per-tenant audit isolation** (`tenant_id` column) — orgs/multi-tenancy deferred to v2 per PROJECT.md. Host apps with multi-tenancy can add it via `metadata` JSONB in the interim.
- **Batch log API** (`log_many/1`) — rejected; encourages fire-and-forget, and transactional batching already works via `Multi`.
- **Event versioning** — `metadata` is free-form JSONB; host apps handle schema evolution of their own custom events.
- **Failure-capture on internal `token_verify` successes** — D-27 excludes this intentionally (too noisy). Can be opted into via config if a host app wants full request-level audit.

</deferred>

---

*Phase: 09-audit-logging*
*Context gathered: 2026-04-09*
