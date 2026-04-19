# Audit write semantics

Sigra exposes two families of audit APIs with different transactional and
telemetry contracts.

## `Sigra.Audit.log_safe/3` (standalone)

- **Semantics:** best-effort insert in a separate database transaction from the
  caller’s business logic (when one exists). Returns `:ok` in all cases so host
  call sites never change their public return shape on audit failure.
- **Telemetry:** failures are observable via
  `[:sigra, :audit, :log_safe_error]` (metadata is sanitized — key names only).

## `Ecto.Multi` + `log_multi_safe/3` / `__log_internal__/3`

- **Semantics:** audit rows are appended as steps on the same `Ecto.Multi` the
  host passes to `repo.transaction/1`, so the business row and audit row commit
  or roll back together.
- **Telemetry:** `[:sigra, :audit, :log]` is **not** fired from inside
  `log_multi_safe/3`. Callers must invoke
  `Sigra.Audit.emit_telemetry_from_changes/1` from the `{:ok, changes}` branch
  of their transaction so telemetry never implies success after a rollback.

## Non-goals

Universal conversion of every historical `log_safe/3` integration site to
`Ecto.Multi` is not required for each release; Phase 39 intentionally scoped
`api.token_create` plus test and documentation support. Further sites remain
eligible for the same pattern when touched.
