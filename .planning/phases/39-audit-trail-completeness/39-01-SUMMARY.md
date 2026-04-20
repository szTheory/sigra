---
phase: 39
plan: 01
status: complete
---

# Plan 39-01 — AUD-01 audit assertion helpers

## Delivered

- `Sigra.Audit.Assertions` with `latest_audit_event/3` (allowed filters only,
  deterministic `order_by inserted_at, id`) and `assert_audit_fields/3` (metadata
  subset matching).
- `test/sigra/audit/audit_assertions_test.exs` — fake-repo mismatch coverage +
  Postgres integration module `Sigra.Audit.AuditAssertionsPostgresTest`.
- `guides/recipes/testing.md` — “Audit assertions and Ecto Sandbox” section with
  required guidance strings and Sandbox `allow/3` pattern.

## Verification

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/audit/audit_assertions_test.exs`

## Self-Check: PASSED
