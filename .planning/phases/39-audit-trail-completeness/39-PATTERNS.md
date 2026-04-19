# Phase 39 — Pattern map

**Phase:** 39 — Audit trail completeness  
**Sources:** `39-CONTEXT.md`, `39-RESEARCH.md`, codebase scan

---

## Files to add (planned)

| Planned file | Role | Closest analog |
|--------------|------|----------------|
| `lib/sigra/audit/assertions.ex` | Plain-function audit helpers (must be **`lib/`** for `test/example` subproject) | `test/sigra/audit/log_safe_scope_test.exs` — `CaptureRepo`, `captured_changes!/0` |
| `test/sigra/api_token_audit_atomic_test.exs` (name adjustable) | Postgres + atomicity | `test/sigra/admin/audit/query_test.exs` — `Sigra.Test.PostgresRepo`, `setup_all` DDL, `TRUNCATE` in `setup` |
| Optional `docs/audit-semantics.md` | Public two-primitive narrative | `lib/sigra/audit.ex` moduledoc (keep consistent, link out) |

---

## Files to modify

| File | Role | Pattern to mirror |
|------|------|-------------------|
| `lib/sigra/api_token.ex` | AUD-02 | `lib/sigra/auth.ex` ~710–737 — `Multi`, conditional `__log_internal__` **or** prefer **`Sigra.Audit.log_multi_safe/3`** after `Multi.insert` (see `audit.ex` ~220–227) |
| `lib/sigra/audit.ex` | Docs only if needed | Already documents `emit_telemetry_from_changes/1` |
| `.planning/REQUIREMENTS.md` | AUD checkboxes + deferral | Phase 38 style — explicit shall/shall-not |
| `CHANGELOG.md` | Guarantees shifted | Prior audit / API token entries |
| `.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md` | Resolution pointer | Cross-link to Phase 39 summaries when closing |

---

## Code excerpts (executor read_first)

**Atomic Multi + telemetry (`auth.ex`):**

```elixir
multi =
  if Keyword.get(audit_opts, :audit_schema) do
    Sigra.Audit.__log_internal__(multi, "auth.confirmation_verify.success", ...)
  else
    multi
  end

case repo.transaction(multi) do
  {:ok, %{confirm_user: user} = changes} ->
    Audit.emit_telemetry_from_changes(changes)
```

**APIToken non-atomic audit today (`api_token.ex`):**

```elixir
case config.repo.insert(changeset) do
  {:ok, token_record} ->
    Sigra.Audit.log_safe("api.token_create", scope, api_token_audit_opts(config) ++ [...])
    {:ok, raw_key, token_record}
```

**`log_multi_safe` gate (`audit.ex`):**

```elixir
def log_multi_safe(%Ecto.Multi{} = multi, action, opts) do
  case Keyword.get(opts, :audit_schema) do
    nil -> multi
    _ -> do_log_multi(multi, action, opts, true)
  end
end
```

---

## PATTERN MAPPING COMPLETE
