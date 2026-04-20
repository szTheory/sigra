# Audit semantics in Sigra

This page complements [Audit logging](../guides/flows/audit-logging.md) with implementation-level vocabulary used in library code and tests.

## Primitives

- **`Sigra.Audit.log/2`** — Inserts one row in its own transaction. Emits `[:sigra, :audit, :log]` on success only.
- **`Sigra.Audit.log_multi/3`** — Appends an audit step to an **existing** `Ecto.Multi`. The caller runs `Repo.transaction/1` and must call `Sigra.Audit.emit_telemetry_from_changes/1` in the success branch so telemetry never fires on rollback.
- **`Sigra.Audit.log_safe/3`** — Same shape as `log/2` but **no-ops** when `audit_schema` is not configured. Used inside optional code paths so hosts without audit tables do not crash.

## Atomicity (C-1 / SEED-002)

Where a business operation and its audit row must commit together, prefer **`Ecto.Multi` + `log_multi/3` + `__log_internal__/3`** (or `log_multi_safe/3` where provided) inside a single transaction.

Sigra historically shipped a **hybrid**: a few hot paths use `Ecto.Multi`, while others still call `log_safe/3` after the fact. Converting remaining sites is tracked as **SEED-002**; v1.3 proves the pattern on the API token create path in `Sigra.APIToken` with Postgres-backed tests.

## Testing

- **`Sigra.Audit.Assertions`** — Plain functions for ordering-safe assertions against a real repo (see `guides/recipes/testing.md`).
- **`Sigra.Testing.assert_audit_event/2`** — Convenience wrapper for ExUnit hosts.

## Non-goals

- This document does not list every built-in action string; search `lib/sigra/` for `Sigra.Audit` call sites.
- OAuth ceremony audit rows are not guaranteed to have dedicated example-app smoke in every milestone; check release notes when upgrading.
