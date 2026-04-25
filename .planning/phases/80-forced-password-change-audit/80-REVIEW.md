---
status: clean
phase: 80
depth: quick
reviewed_at: "2026-04-24"
---

# Phase 80 — Code review (orchestrator quick pass)

## Scope

- `lib/sigra/account.ex` — **`clear_password_change_requirement/3`** mirrors **`change_password` / `set_password`** **`Multi` + `log_multi_safe`** + **`finish_audit_multi`**; **`@deprecated`** on **`audit_forced_password_change/2`** with explicit duplicate-audit warning.
- `test/sigra/account_audit_atomicity_test.exs` — happy path, constraint rollback, audit-disabled path; constraint name unique; **`try`/`after`** cleanup.

## Findings

None blocking. Deprecation preserves backward compatibility; hosts should migrate to the orchestrated API when `:audit_schema` is set.

## Notes

Postgres tests require a reachable server; **`SIGRA_TEST_PG_USERNAME`** may need to differ from **`postgres`** on macOS Homebrew installs.
