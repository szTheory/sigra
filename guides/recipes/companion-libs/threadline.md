<!-- validated_against: threadline ~> 0.5 -->
<!-- last_validated: 2026-05-27 -->
# Recipe: Sigra + Threadline (audit forwarding)

Validated against: `threadline ~> 0.5` as of 2026-05-27

> **Sigra works fully standalone.** Threadline is an optional integration; Sigra ships without it, and removing the entry below returns Sigra to standalone operation with no further changes.

## What this is

| Role | Library | Responsibility |
|------|---------|----------------|
| Audit DB row (source-of-truth) | **Sigra** | Writes `AuditEvent` rows inside the originating transaction; owns retention, schema, and idempotency |
| Audit projection / queryable timeline | **Threadline** | Receives forwarded events and builds queryable timelines, dashboards, and trigger definitions |

Sigra forwards a copy of each audit event to Threadline after the originating transaction commits.
Sigra's `AuditEvent` row is always written first; if Threadline is unreachable or misconfigured,
the audit DB row is unaffected. Threadline is a projection — not a replacement for the Sigra audit
record.

## Prerequisites

Before wiring Threadline forwarding, confirm:

- **Sigra audit is green** — `AuditEvent` rows are writing correctly in your application (local
  `dev` and `test` environments) before you add the forwarder entry. The forwarder augments a
  working audit pipeline; it does not establish one.
- **Threadline 0.5 is installed in your host app.** Add it to `mix.exs` and run Threadline's
  bootstrap generators:

  ```
  mix threadline.install
  mix ecto.migrate
  ```

  See the [Threadline 0.5.0 README](https://hex.pm/packages/threadline) for full bootstrap
  instructions, including Repo configuration and migration options.
- **Environment variables are set.** The forwarder reads `THREADLINE_ENDPOINT` and
  `THREADLINE_API_KEY` via `System.get_env/1`. Operator owns secret management — do not
  hard-code these values in config files committed to source control.

## `mix.exs` snippet

```elixir
defp deps do
  [
    {:sigra, "~> 1.29"},
    {:threadline, "~> 0.5"},
    # ... your other deps
  ]
end
```

## Sigra-side config block

Add the `forwarders:` key to your Sigra `:audit` config in `config/runtime.exs`:

```elixir
audit: [
  audit_schema: MyApp.Accounts.AuditEvent,
  retention_days: 90,
  forwarders: [
    [
      module: Sigra.Audit.Forwarders.Threadline,
      dispatch: :auto,
      id: :default,
      endpoint: System.get_env("THREADLINE_ENDPOINT"),
      api_key: System.get_env("THREADLINE_API_KEY")
    ]
  ]
]
```

Sigra invokes `Threadline.record_action/2` per `lib/sigra/audit/forwarders/threadline.ex:290-307`,
verified against Threadline 0.5.0.

**Dispatch modes.** The `:dispatch` key controls delivery timing. `:auto` detects Oban at
runtime: when an Oban supervisor is running, forwarding is enqueued via
`Sigra.Workers.AuditForward`; otherwise it runs inline in the calling process. Use `dispatch: :sync`
to always forward inline, or `dispatch: :async` to require Oban (raises at boot if Oban is absent
— see Failure modes below). Full dispatch semantics are in the `Sigra.Audit.Forwarders` moduledoc.

**Idempotency.** The forwarder passes `correlation_id: metadata[:id]` to Threadline, where `:id`
is the UUID Sigra stamps on each `AuditEvent` row (Phase 131 D-31). Threadline uses this for
idempotent upsert on retry; duplicate delivery from Oban retries does not create duplicate
Threadline rows.

## Failure modes

### 1. Threadline dep missing at boot

If `{:threadline, "~> 0.5"}` is absent from compiled deps,
`Sigra.Application.maybe_warn_missing_forwarder_deps/0` emits a one-shot `Logger.warning` at
application startup and skips forwarder attachment. Forwarding is silently disabled; audit DB
rows continue writing normally. No other parts of Sigra are affected.

Observable signal: a single `Logger.warning` line at boot naming the missing module.

### 2. `:async` dispatch with Oban absent

If a forwarder entry sets `dispatch: :async` and Oban is not supervised in the application,
`Sigra.Application.attach_forwarders/0` raises at boot with a descriptive message. This is
intentional — silent degradation to `:sync` would mask a real misconfiguration (Phase 131 D-26).
If you want Oban-when-present behaviour with a `:sync` fallback, use `dispatch: :auto`.

### 3. Threadline returns schema mismatch

If Threadline returns `{:error, %Ecto.Changeset{}}`, the dispatcher emits a
`[:sigra, :audit, :forward, :error]` telemetry event with `reason: :schema_mismatch`.

Observable signal: telemetry event with `reason: :schema_mismatch`. This is non-retryable —
Threadline shipped a breaking schema change that the forwarder cannot satisfy. Pin or upgrade
Threadline to a version compatible with the event shape Sigra produces.

### 4. Network or transient failure on `:async` path

Transient failures (network errors, HTTP timeouts) on the async path are retried by
`Sigra.Workers.AuditForward` with `max_attempts: 5` and exponential backoff. After exhausting
retries, the Oban job moves to `discarded` and a `[:sigra, :audit, :forward, :error]` telemetry
event is emitted. The originating auth operation is not rolled back and the Sigra `AuditEvent`
row is not deleted.

### 5. Operator caution: telemetry handler raises

Telemetry handlers attached to `[:sigra, :audit, :forward, :error]` (or any `[:sigra, :audit, ...]`
event) **must never raise**. The `:telemetry` library auto-detaches any handler that raises,
silently disabling all subsequent events from that handler for the lifetime of the node (Phase 131
D-20 auto-detach landmine). Wrap handler bodies in `try/rescue` or use a supervised GenServer to
isolate failures from the telemetry dispatch path.

## Non-goals

- Threadline does **not** replace the Sigra audit DB. Sigra's `AuditEvent` row is the
  source-of-truth (Phase 131 D-21). Rolled-back transactions are never forwarded — Threadline
  only receives events from committed transactions.
- There is **no `--with-threadline` install flag** in `mix sigra.install`. No precedent exists
  for companion-lib install flags, and the wiring above requires no generator support
  (Phase 131 D-25, D-27).
- This recipe does **not** cover Threadline-side custom queries, dashboards, trigger definitions,
  or `mix threadline.gen.triggers`. Those belong in [Threadline's own documentation](https://hex.pm/packages/threadline).
- Forwarder delivery carries **no SLA**. Forwarder failures never roll back the originating auth
  operation, and Threadline downtime never blocks login.

## See also

- [Audit logging flow](../flows/audit-logging.html) — how Sigra writes `AuditEvent` rows,
  emits `[:sigra, :audit, :log]` telemetry, and handles retention
- [Mailglass recipe](./mailglass.html) — wiring Mailglass behind `Sigra.Mailer` for transactional
  auth email

### Custom forwarders

Need to forward audit events to a destination Sigra does not ship? Implement the
`Sigra.Audit.Forwarder` behaviour (`lib/sigra/audit/forwarder.ex`) — it has a single
`@callback attach(keyword) :: :ok | {:error, term()}` callback and can be registered alongside
`Sigra.Audit.Forwarders.Threadline` or as a standalone replacement. In tests, mock the contract
with `Mox.defmock(MyForwarder, for: Sigra.Audit.Forwarder)`.
