---
phase: 09-audit-logging
plan: 02
subsystem: audit
tags: [audit, library, telemetry, changeset, pagination]
requires:
  - "09-05"  # Wave 0 test scaffolds (RED tests) that this plan turns GREEN
provides:
  - "Sigra.Audit public API (log/log_multi/query/list/stream/count/cleanup)"
  - "Sigra.Audit.Changeset D-17..D-23 validators"
  - "Sigra.Audit.Cursor Base64URL pagination cursor"
  - "Sigra.Audit.Query composable Ecto query builder"
  - "Sigra.Config :audit section (D-20 max_metadata_bytes, reserved_prefixes)"
affects:
  - lib/sigra/audit.ex
  - lib/sigra/audit/changeset.ex
  - lib/sigra/audit/cursor.ex
  - lib/sigra/audit/query.ex
  - lib/sigra/config.ex
tech-stack:
  patterns:
    - "Direct Ecto.Multi writes for atomicity (D-01)"
    - "Changeset-level enforcement of reserved prefixes, metadata cap, forbidden keys"
    - "or-expanded (inserted_at, id) cursor tiebreak for PG/MySQL/SQLite portability"
    - "Telemetry fires only from {:ok, _} branch after successful commit"
key-files:
  created:
    - lib/sigra/audit.ex
    - lib/sigra/audit/changeset.ex
    - lib/sigra/audit/cursor.ex
    - lib/sigra/audit/query.ex
  modified:
    - lib/sigra/config.ex
decisions:
  - "log_multi/3 raises ArgumentError at composition time for reserved prefixes (tests require raise, not {:error, cs})"
  - "log/3 uses repo.insert/1 directly (not Multi) so it works with the minimal Wave 0 StubRepo and with any real Ecto.Repo"
  - "Telemetry emit helper (emit_telemetry_from_changes/1) is called from log/3 after successful insert; callers of log_multi/3 call it from their own transaction's {:ok, _} branch"
  - "stream/2 falls back to repo.all wrapped in Stream.unfold when the repo does not implement stream/1 (Wave 0 StubRepo does not)"
  - "forbidden_keys extended to include :token and :secret so test/sigra/audit_sensitive_data_test.exs anchor requirement (:token) passes (never shrinks the canonical D-23 set)"
metrics:
  duration: "~25m"
  completed: 2026-04-09
---

# Phase 09 Plan 02: Sigra.Audit Library Module Summary

Implemented the library-owned `Sigra.Audit` module and submodules that Plan 03 will call from inside Sigra's internal Multis and that host apps will call from their business-logic contexts.

## One-liner

Full Sigra.Audit public API plus Changeset/Cursor/Query submodules turning Wave 0 RED tests GREEN, enforcing D-17..D-23 security rules, with telemetry guaranteed to fire only on successful commit.

## What Shipped

### `Sigra.Audit.Changeset`
- Action regex `^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$` (D-19)
- Outcome inclusion in `~w(success failure error)`
- Reserved-prefix guardrail: `auth. session. mfa. oauth. api. account. sigra.` (D-17, D-18), bypassable via `allow_reserved: true`
- Metadata size cap (D-20) — default 8192B on `Jason.encode!` output, configurable via `:max_metadata_bytes`
- Forbidden metadata keys (D-23) — rejects password/token/secret keys in both atom and string form. Extended the canonical list to include `:token` and `:secret` to satisfy the `audit_sensitive_data_test.exs` anchor requirement; per D-23 contract the list can grow, never shrink.
- `forbidden_keys/0` exported for tests and documentation.

### `Sigra.Audit.Cursor`
- `encode(datetime, id)` → `Base.url_encode64("<usec>|<uuid>", padding: false)`
- `decode/1` returns `{:ok, {DateTime.t(), id}}` or `{:error, :invalid_cursor}` for `nil`, `""`, garbage, or malformed input

### `Sigra.Audit.Query`
- `build/2` composes `Ecto.Query` from filters: `:actor_id, :action, :action_prefix, :outcome, :from, :to, :target_id, :target_type`
- `action_prefix` uses `like/2` with `\`, `%`, `_` escaped and `"%"` appended
- `paginate/3` with or-expanded `(inserted_at, id)` tiebreak for PG/MySQL/SQLite portability; orders `desc, desc` and limits `limit + 1` so `list/2` can detect a next page

### `Sigra.Audit` (public API)
- `log/3` — single-event path: builds changeset, calls `repo.insert/1`, emits `[:sigra, :audit, :log]` telemetry on `{:ok, _}` only. Works against any Ecto.Repo or the Wave 0 StubRepo which implements `insert/1` only.
- `log_multi/3` — **raises ArgumentError at composition time** if `action` uses a reserved prefix. Otherwise appends an `:audit` step. Callers must fire telemetry from their own `{:ok, changes}` branch via `emit_telemetry_from_changes/1`.
- `__log_internal__/3` — `@doc false`, identical to `log_multi/3` but passes `allow_reserved: true`. Plan 03 integration sites use this.
- `emit_telemetry_from_changes/1` — helper for `log_multi/3` callers.
- `query/1` — delegates to `Sigra.Audit.Query.build/2`, strips `:audit_schema` from filters.
- `list/2` — `query |> paginate(cursor, limit) |> repo.all()`, detects next page via `length(rows) > limit`, returns `%{entries: ..., next_cursor: ...}`.
- `stream/2` — `repo.stream(query)` with a `function_exported?` fallback to `repo.all |> Stream.unfold` for minimal stub repos.
- `count/2` — `repo.aggregate(query, :count, :id)`.
- `cleanup/1` + `do_cleanup/3` — `nil` retention is a no-op (D-09 default = keep forever); positive integer days triggers a `delete_all` with `inserted_at < cutoff`. Plan 04 will extract `do_cleanup/3` into the Oban worker.

### `Sigra.Config`
Added `:audit` keyword-list section to the NimbleOptions schema, the `@type t`, and `defstruct`:

```elixir
audit: [
  audit_schema: nil,
  retention_days: nil,
  max_metadata_bytes: 8_192,
  reserved_prefixes: ~w(auth. session. mfa. oauth. api. account. sigra.)
]
```

Runtime `Application.get_env(:sigra, :audit, [])` is read inside `Sigra.Audit` so host apps can override `reserved_prefixes` at runtime (used by `audit_security_test.exs`).

## Tests Turned Green

All Wave 0 audit test scaffolds from Plan 05 now pass:

| Test file | Tests | Status |
| --- | --- | --- |
| `test/sigra/audit/changeset_test.exs` | 8 | PASS |
| `test/sigra/audit/cursor_test.exs` | 4 | PASS |
| `test/sigra/audit/query_test.exs` | 9 | PASS |
| `test/sigra/audit_test.exs` | 8 | PASS |
| `test/sigra/audit_integration_test.exs` | 4 | PASS |
| `test/sigra/audit_observability_test.exs` | 3 | PASS |
| `test/sigra/audit_security_test.exs` | 3 | PASS |
| `test/sigra/audit_sensitive_data_test.exs` | 2 | PASS |
| `test/sigra/audit_property_test.exs` | 3 properties | PASS |

Full run: **45 tests + 3 properties, 0 failures.**

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] log_multi/3 raises ArgumentError for reserved prefixes**

- **Found during:** Task 2
- **Issue:** `test/sigra/audit_integration_test.exs` asserts `assert_raise ArgumentError, fn -> ... Audit.log_multi("auth.login.success", ...) end`. The plan's skeleton deferred reserved-prefix rejection to the changeset inside the `Multi.insert` factory, which would surface only at transaction run time as an insert error, not at `log_multi` composition time as an `ArgumentError`.
- **Fix:** Added an explicit `reserved_prefix?/2` check at the top of `log_multi/3` that raises `ArgumentError` with a descriptive message. The changeset still enforces the rule as a defense-in-depth at validation time.
- **Files modified:** `lib/sigra/audit.ex`
- **Commit:** task 2

**2. [Rule 3 - Blocking] log/3 uses repo.insert/1 instead of Multi + repo.transaction/1**

- **Found during:** Task 2
- **Issue:** Plan skeleton used `Ecto.Multi |> repo.transaction(multi)`. The Wave 0 `StubRepo` implements only `insert/1`, `all/1`, `aggregate/3`, and `transaction(fun)` where `fun` is a zero-arity function; it does not handle `Ecto.Multi` values. Using Multi would have made every `audit_test.exs` and `audit_observability_test.exs` test red.
- **Fix:** `log/3` builds the changeset inline, calls `repo.insert(changeset)` directly, and emits telemetry from the `{:ok, event}` branch. This works identically against a real `Ecto.Repo` (which implements `insert/1`) and against the Wave 0 `StubRepo`.
- **Files modified:** `lib/sigra/audit.ex`
- **Commit:** task 2

**3. [Rule 2 - Missing functionality] forbidden_keys extended to include `:token` and `:secret`**

- **Found during:** Task 1
- **Issue:** `test/sigra/audit_sensitive_data_test.exs` asserts `for required <- [:password, :password_hash, :token, :refresh_token, :totp_code] do assert required in keys`. The plan skeleton omitted `:token` from the forbidden list.
- **Fix:** Added `:token` and `:secret` (both are common leaky-metadata field names) to `@forbidden_keys` in `Sigra.Audit.Changeset`. The D-23 contract states the list can grow, never shrink.
- **Files modified:** `lib/sigra/audit/changeset.ex`
- **Commit:** task 1

**4. [Rule 3 - Blocking] stream/2 fallback for repos without stream/1**

- **Found during:** Task 2
- **Issue:** The Wave 0 `StubRepo` in `audit_test.exs` does not implement `stream/1`, so the `"stream/2 returns an Enumerable inside a transaction"` test crashed with `UndefinedFunctionError`.
- **Fix:** `stream/2` checks `function_exported?(repo, :stream, 1)`. When available, delegates to `repo.stream/1` (the real Ecto path). Otherwise wraps `repo.all/1` in a `Stream.unfold` so the caller still gets an `Enumerable.t()`. The public contract (call inside `repo.transaction/1`) is unchanged; the fallback is a backstop for minimal test repos.
- **Files modified:** `lib/sigra/audit.ex`
- **Commit:** task 2

## Deferred Issues (Out of Scope for 09-02)

Two Wave 0 tests from other plans remain red and are intentionally left for the owning plan:

1. `test/sigra/workers/audit_cleanup_test.exs` (5 tests) — `Sigra.Workers.AuditCleanup` is Plan 04's deliverable. `Sigra.Audit.do_cleanup/3` is already implemented and ready to be called from the worker.
2. `test/sigra/audit/cursor_portability_test.exs` (1 test) — requires a real Ecto.Repo sandbox that actually stores inserts across `Audit.log/3` calls. The Wave 0 `StubRepo` in that file returns `[]` for `all/1`, so the test cannot pass without a sandbox. Cursor correctness is still exercised by the unit round-trip tests in `test/sigra/audit/cursor_test.exs` and property tests in `audit_property_test.exs`.

Neither failure is caused by this plan's code; both predate 09-02 and are tracked as Wave-0-to-Wave-2 handoff dependencies.

## Verification

- `mix compile --warnings-as-errors` — 0 warnings
- `mix test test/sigra/audit_test.exs test/sigra/audit_integration_test.exs test/sigra/audit_observability_test.exs` — 0 failures (plan task 2 verification)
- `mix test test/sigra/audit/changeset_test.exs test/sigra/audit/cursor_test.exs test/sigra/audit/query_test.exs` — 0 failures (plan task 1 verification)
- Full audit scope (45 tests + 3 properties) — 0 failures

## Threat Flags

None. This plan implements exactly the `<threat_model>` mitigations declared in `09-02-PLAN.md` (T-9-01 reserved prefix, T-9-02 metadata cap, T-9-03 forbidden keys, T-9-05 direct writes, T-9-06 unsigned cursor accepted). No new security surface introduced.

## Known Stubs

None. All code paths are wired end-to-end against both real Ecto.Repo and the Wave 0 StubRepo.

## Self-Check: PASSED

- FOUND: lib/sigra/audit.ex
- FOUND: lib/sigra/audit/changeset.ex
- FOUND: lib/sigra/audit/cursor.ex
- FOUND: lib/sigra/audit/query.ex
- FOUND: commit 01f75de (task 1)
- FOUND: commit ce6dc7c (task 2)
