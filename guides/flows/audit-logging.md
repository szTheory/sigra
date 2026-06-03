# Audit Logging

Sigra writes a structured row to `audit_events` for every security-relevant operation: logins, failed logins, password resets, MFA challenges, token revocations, account deletions, and more. This guide covers the schema, the query API, writing custom events, and testing audit-aware code.

## What Sigra gives you

- **`Sigra.Audit.log`** — the core write function. Inserts a row in `audit_events` via `Ecto.Multi` so it stays atomic with the business op.
- **`Sigra.Audit.log_safe`** — no-op friendly version: if the host app has not configured `audit_schema`, it silently skips. Used inside library code that cannot assume audit is enabled.
- **`Sigra.Audit.query`** — filter by actor, target, action prefix, time range, outcome. Returns an `Ecto.Query` you can further refine or stream.
- **`Sigra.Audit.stream`** — cursor-based pagination for SIEM export.
- **Generated `AuditEvent` schema** — the event row: `action`, `outcome`, `actor_id`, `actor_type`, `target_id`, `target_type`, `metadata` (JSONB), `ip_address`, `user_agent`, `occurred_at`.
- **`Sigra.Testing.audit_event_fixture/1`** — insert an audit row directly in tests (bypasses `Ecto.Multi`).
- **`Sigra.Testing.assert_audit_event/2`** — assert the most recent event matches an expected map. Supports `position:` and subset-matching metadata.

## Event schema

Every audit row has:

| Column | Type | Description |
|--------|------|-------------|
| `action` | `string` | Dotted action name: `"auth.login.success"`, `"mfa.enrollment.complete"`, `"api_token.revoke"` |
| `outcome` | `string` | `"success"` \| `"failure"` |
| `actor_id` | `uuid \| nil` | The user or system principal that took the action |
| `actor_type` | `string` | `"user"` \| `"system"` \| `"admin"` |
| `target_id` | `uuid \| nil` | The resource the action affected (may equal `actor_id`) |
| `target_type` | `string` | `"user"` \| `"session"` \| `"api_token"` \| custom |
| `metadata` | `jsonb` | Arbitrary key/value context (method, reason, scopes, ip\_change) |
| `ip_address` | `string` | Source IP (from the conn's `remote_ip`) |
| `user_agent` | `string` | User agent header |
| `occurred_at` | `utc_datetime_usec` | Set by the library at write time |

## Built-in events

Sigra writes these automatically (this list is not exhaustive — check `lib/sigra/auth.ex` and sibling modules for the full dispatch table):

- `auth.register.success` / `auth.register.failure`
- `auth.login.success` / `auth.login.failure`
- `auth.logout`
- `auth.password_reset_request`
- `auth.password_reset.success` / `auth.password_reset.failure`
- `auth.magic_link_request`
- `auth.magic_link_verify.success` / `auth.magic_link_verify.failure`
- `auth.confirmation.success` / `auth.confirmation.failure`
- `mfa.enrollment.start` / `mfa.enrollment.complete` / `mfa.enrollment.cancel`
- `mfa.challenge.success` / `mfa.challenge.failure`
- `mfa.backup_code.used`
- `api_token.create` / `api_token.revoke`
- `oauth.link.success` / `oauth.unlink.success`
- `account.email_change_request` / `account.email_change_confirm`
- `account.password_change`
- `account.deletion_schedule` / `account.deletion_cancel` / `account.deletion_execute`

## Configuring audit

Enable audit logging by pointing at your generated schema:

    config :my_app, MyApp.Auth.Config,
      audit: [
        audit_schema: MyApp.AuditEvent,
        enabled: true
      ]

Without `audit_schema`, `log_safe/3` no-ops — so you can disable audit without code changes.

## Querying events

On an admin dashboard, show the last N login failures for a user:

    import Ecto.Query

    def recent_login_failures(user, limit \\ 20) do
      Sigra.Audit.query(MyApp.Auth.sigra_config(),
        actor_id: user.id,
        action: "auth.login.failure",
        limit: limit,
        order: :desc
      )
      |> Repo.all()
    end

Filter by time range:

    Sigra.Audit.query(config,
      action_prefix: "mfa.",
      since: ~U[2026-01-01 00:00:00Z],
      until: ~U[2026-02-01 00:00:00Z]
    )

## Writing custom events

Your own code can write domain-specific events. Prefix them to avoid colliding with `auth.`, `mfa.`, `api_token.`, `oauth.`, `account.`:

    Sigra.Audit.log("billing.subscription.upgraded",
      actor_id: user.id,
      actor_type: "user",
      target_id: subscription.id,
      target_type: "subscription",
      metadata: %{
        from_plan: "hobby",
        to_plan: "pro",
        amount_cents: 2900
      }
    )

Reserved prefixes (`auth.`, `mfa.`, `account.`, `api_token.`, `oauth.`) are rejected from the public `log/2` path to protect the invariants of built-in events. Use your own namespace.

## Integrating with Ecto.Multi

For atomicity, write the audit row inside the same transaction as the business op:

    Ecto.Multi.new()
    |> Ecto.Multi.update(:subscription, Subscription.upgrade_changeset(sub, "pro"))
    |> Sigra.Audit.multi(config(), "billing.subscription.upgraded",
      actor_id: user.id,
      target_id: sub.id,
      metadata: %{to_plan: "pro"}
    )
    |> Repo.transact()

`Sigra.Audit.log_multi` adds a `{:audit, ...}` step to your multi. If the business op fails, the audit row rolls back with it.

## Auth/account data export boundary

Use `Sigra.DataExport.export_auth_data/3` when you need Sigra-owned auth/account data for a user. The export is versioned and bounded to Sigra-owned sections such as account lifecycle fields, sessions, identities, audit rows, MFA credentials, passkeys, backup-code summary, and organization memberships when those generated schemas are configured.

The export is not host-owned domain data. Host applications remain responsible for their own domain export, retention policy, and legal interpretation.

The returned `omissions` list is part of the contract. When optional Sigra-owned schemas are absent, Sigra returns explicit omission notes for those sections instead of silently implying the export is complete.

## Cursor pagination and streaming for SIEM export

Use `Sigra.Audit.list/2` for stable cursor-based pagination when you need
checkpointed export batches. Use `Sigra.Audit.stream/2` for database-backed
streaming inside a transaction when you want to process a large slice in one run.

Cursor pagination:

    {:ok, %{entries: entries, next_cursor: cursor}} =
      Sigra.Audit.list(config(), audit_schema: MyApp.AuditEvent, limit: 1_000)

Streaming:

    Sigra.Audit.stream(config(), since: last_export_cursor)
    |> Stream.map(&encode_for_siem/1)
    |> Stream.chunk_every(1_000)
    |> Enum.each(&SIEM.Client.push_batch/1)

## Retention

Audit rows accumulate forever unless you prune. Configure a retention period:

    config :my_app, MyApp.Auth.Config,
      audit: [
        audit_schema: MyApp.AuditEvent,
        retention_days: 365
      ]

The `Sigra.Workers.AuditCleanup` Oban worker runs nightly and deletes rows older than `retention_days`. For regulatory compliance, export to cold storage before deletion.

## Testing

    test "login failure is audited" do
      user = Sigra.Testing.user_fixture()

      _ = Accounts.get_user_by_email_and_password(user.email, "wrongpassword")

      Sigra.Testing.assert_audit_event(%{
        action: "auth.login.failure",
        outcome: "failure",
        actor_id: user.id,
        metadata: %{reason: "invalid_credentials"}
      })
    end

    test "custom event via audit_event_fixture" do
      user = Sigra.Testing.user_fixture()

      Sigra.Testing.audit_event_fixture(
        repo: Repo,
        audit_schema: MyApp.AuditEvent,
        action: "billing.subscription.upgraded",
        actor_id: user.id,
        metadata: %{from_plan: "hobby", to_plan: "pro"}
      )

      Sigra.Testing.assert_audit_event(%{action: "billing.subscription.upgraded"})
    end

## Related

- [Getting Started](getting-started.html) — register/login already produce audit events.
- [Testing Auth Flows](testing.html) — more audit fixture patterns.
- `Sigra.Audit` — log, log_safe, query, stream, log_multi
- `Sigra.Testing.audit_event_fixture/1` and `assert_audit_event/2`
