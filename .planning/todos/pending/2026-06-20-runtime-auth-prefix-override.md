---
created: 2026-06-20T00:00:00.000Z
status: pending
title: runtime/boot-time auth-schema prefix override (currently baked at install time)
area: config
files:
  - lib/sigra/config.ex
  - lib/sigra/branding.ex
  - lib/mix/tasks/sigra.install.ex
source: 2026-06-20 discussion (Phase 197 discuss-phase tail) — PG-schema isolation already shipped in v1.1.0; this is the additive runtime-config follow-on
---

## What

Sigra already places auth tables in a dedicated Postgres schema (default `auth`,
opt-out `--auth-prefix public`) — see CHANGELOG v1.1.0, `migration.exs:12`
(`CREATE SCHEMA IF NOT EXISTS`), `@schema_prefix` on every generated schema, and
runtime introspection in `lib/sigra/branding.ex:220-241`
(`schema.__schema__(:prefix)`).

The schema prefix is currently **baked at install/generation time** — it lives in the
generated migration and the `@schema_prefix` attribute of each generated schema module.
There is no supported way to change which Postgres schema Sigra-owned tables live in
**at application boot** without regenerating the app.

This todo: allow an optional runtime/boot-time override, e.g.

```elixir
config :my_app, :sigra, auth_prefix: "my_auth_schema"
```

so the prefix can be environment-specific (dev vs. multi-tenant vs. staging) without
regenerating. Likely involves:
- `Sigra.Config` accepting an optional `:auth_prefix` / `:auth_schema`.
- Library queries (`Sigra.Branding`, account/session lookups, etc.) honoring a
  `:prefix` override that supersedes the schema-introspected default.
- Deciding precedence: explicit config > generated `@schema_prefix` > none.

## Why

Better operator DX: lets a deployment relocate or scope the auth schema per environment
without a regeneration cycle. Additive — does not change the shipped default behavior.

## Caveats / open questions

- Migrations are still generation-time artifacts; a runtime override only affects
  queries, not where tables were actually created. Need to define behavior when the
  configured prefix and the migrated prefix disagree (warn? fail fast? introspect?).
- Pairs naturally with the `mix sigra.migrate_schema` helper
  (see `2026-06-20-mix-sigra-migrate-schema-helper.md`) for the full story:
  one moves the tables, this points runtime at them.
- Generated-host contract: confirm this stays a library concern and doesn't force
  regenerated host code.
