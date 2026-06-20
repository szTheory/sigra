---
created: 2026-06-20T00:00:00.000Z
status: pending
title: mix sigra.migrate_schema helper to relocate existing tables between Postgres schemas
area: installer
files:
  - lib/mix/tasks/
  - priv/templates/sigra.install/core/migration.exs
source: 2026-06-20 discussion (Phase 197 discuss-phase tail) — PG-schema isolation already shipped in v1.1.0; this is the additive migration-helper follow-on
---

## What

Sigra defaults Postgres installs to a dedicated `auth` schema (v1.1.0). But existing
apps that installed before that default — or that used `--auth-prefix public` — have
their Sigra tables in `public` (or some other schema). There is no first-class path to
**move an existing install** from one Postgres schema to another.

This todo: provide a generator/Mix task, e.g.

```
mix sigra.migrate_schema <from_schema> <to_schema>
```

that emits a migration (or runs one) which:
- `CREATE SCHEMA IF NOT EXISTS <to_schema>`
- `ALTER TABLE <from>.<each_sigra_table> SET SCHEMA <to_schema>` for every Sigra-owned
  table (users, user_tokens, user_sessions, user_mfa_credentials, user_backup_codes,
  user_passkeys, user_identities, user_api_tokens, audit_events, organization_*,
  enterprise_connections, sigra_brand_profiles).
- Leaves the host app's own `public` tables untouched.
- Reminds the operator to also update the generated `@schema_prefix` attributes (or
  pairs with the runtime-override todo so they don't have to).

## Why

Completes the namespace-hygiene story: lets pre-v1.1.0 adopters (and anyone who chose
`public`) clean up their `public` schema without hand-writing `ALTER TABLE ... SET
SCHEMA` for ~17 tables. Better operator DX, lower migration risk (the task knows the
exact table set + dependency order).

## Caveats / open questions

- Must enumerate exactly the Sigra-owned tables and handle conditional ones
  (passkeys/oauth/organizations/api only exist if those features were generated) —
  introspect rather than assume.
- Foreign keys / indexes move with the table on `SET SCHEMA`, but verify references
  across the set don't break ordering.
- `citext` extension is database-global — not affected by the move.
- Pairs with `2026-06-20-runtime-auth-prefix-override.md`: this moves the tables, that
  points runtime queries at them. Decide whether the task also rewrites generated
  `@schema_prefix` attributes or defers that to the runtime override.
- MySQL/SQLite are out of scope (no equivalent schema semantics — same boundary the
  installer already draws).
