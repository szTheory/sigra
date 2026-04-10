---
phase: 09-audit-logging
reviewed: 2026-04-09T00:00:00Z
depth: standard
files_reviewed: 18
files_reviewed_list:
  - lib/sigra/audit.ex
  - lib/sigra/audit/changeset.ex
  - lib/sigra/audit/cursor.ex
  - lib/sigra/audit/query.ex
  - lib/sigra/auth.ex
  - lib/sigra/session.ex
  - lib/sigra/mfa.ex
  - lib/sigra/oauth.ex
  - lib/sigra/api_token.ex
  - lib/sigra/account.ex
  - lib/sigra/lockout.ex
  - lib/sigra/suspicious_login.ex
  - lib/sigra/config.ex
  - lib/sigra/application.ex
  - lib/sigra/workers/audit_cleanup.ex
  - lib/mix/tasks/sigra.install.ex
  - priv/templates/sigra.install/audit_event.ex
  - priv/templates/sigra.install/create_audit_events.exs
findings:
  critical: 1
  warning: 8
  info: 6
  total: 15
status: issues_found
---

# Phase 9: Code Review Report

**Reviewed:** 2026-04-09
**Depth:** standard
**Files Reviewed:** 18
**Status:** issues_found

## Summary

Phase 9 introduces the audit logging subsystem: `Sigra.Audit` public API, changeset validation (D-17..D-23 guardrails), cursor pagination, retention cleanup, and integration sites across Auth, Session, MFA, OAuth, APIToken, Account, Lockout, and SuspiciousLogin. The architecture is sound and the D-23 forbidden-key enforcement is well-executed.

However, several issues warrant attention:

1. One **critical** correctness bug in `Sigra.Audit.Changeset.validate_metadata_size/2` that crashes on non-map metadata instead of failing validation.
2. Multiple **warning**-level issues around inconsistent retention cleanup handling in the template migration (missing D-10 indexes), `Sigra.Audit.stream/2` falling back to `Stream.unfold` in a way that silently bypasses transaction contract, and `log_safe/3` silently returning `:ok` when `:repo` is missing (masking misconfiguration).
3. Integration sites (`Sigra.Auth`, `Sigra.MFA`, etc.) emit audit rows **after** the business transaction commits rather than inside `log_multi`, which contradicts D-28's atomic guarantee narrative.
4. `Sigra.APIToken.decode_cursor/1` uses raising `Base.url_decode64!` and `String.to_integer`, crashing on tampered cursors — not audit code itself but the integration between phases conflicts with `Sigra.Audit.Cursor.decode/1`'s safe contract.

Reserved-prefix enforcement, D-23 forbidden-key detection, HMAC state handling in OAuth, and Cloak-based encryption of sensitive fields all look correct.

## Critical Issues

### CR-01: `validate_metadata_size/2` crashes when metadata is not nil and not a map

**File:** `lib/sigra/audit/changeset.ex:89-111`
**Issue:** The `case map` expression handles only `nil` and `is_map(m)` cases. If `metadata` is cast to any other type (e.g., a list, string, integer) through Ecto `cast/3`, the case will raise `CaseClauseError` inside `validate_change`, bypassing the changeset error path and crashing the caller. Although `metadata` is typed `:map` on the schema, Ecto's `cast/3` can surface arbitrary values during casting in test fixtures or when a map literal is passed with incompatible contents, and defensive validators should never raise.

Related: `find_forbidden/1` is safe (has a default clause), but `validate_metadata_size/2` is not.

**Fix:**
```elixir
defp validate_metadata_size(cs, max_bytes) do
  validate_change(cs, :metadata, fn :metadata, map ->
    case map do
      nil ->
        []

      m when is_map(m) ->
        encoded = Jason.encode!(m)

        case byte_size(encoded) do
          n when n <= max_bytes ->
            []

          n ->
            [
              {:metadata,
               {"serialized size #{n}B exceeds cap #{max_bytes}B",
                [validation: :max_metadata_bytes]}}
            ]
        end

      _other ->
        [{:metadata, {"must be a map", [validation: :metadata_shape]}}]
    end
  end)
end
```

Additionally, consider wrapping `Jason.encode!/1` in a `try` — if metadata contains a value that Jason cannot encode (e.g., a tuple, PID, or struct without an encoder), it raises `Protocol.UndefinedError`. A defensive validator should convert that to a changeset error.

---

## Warnings

### WR-01: `log_safe/3` silently succeeds when `:repo` is missing

**File:** `lib/sigra/audit.ex:124-126`
**Issue:** When `audit_schema` is present but `repo` is `nil`, `log_safe/3` returns `:ok` with no telemetry, no log, no observability. This masks host-app misconfiguration (integration sites must provide both keys together). The error is silent and the audit row is never written — the exact failure mode D-28 is supposed to prevent.

**Fix:** Emit a one-shot Logger warning or telemetry event so misconfigured hosts discover the problem. Example:
```elixir
case Keyword.get(opts, :repo) do
  nil ->
    :telemetry.execute(
      [:sigra, :audit, :log_safe_error],
      %{count: 1},
      %{action: action, reason: :missing_repo}
    )
    :ok

  repo ->
    ...
end
```

---

### WR-02: `Sigra.Audit.stream/2` fallback bypasses transaction contract

**File:** `lib/sigra/audit.ex:263-275`
**Issue:** The docstring says "suitable for use inside the caller's `repo.transaction/1` block" but the fallback branch (`function_exported?(repo, :stream, 1) == false`) calls `repo.all(q)` which loads the entire result set into memory. This silently defeats both the streaming contract (unbounded memory on large audit tables) and the transaction-isolation promise. A retention sweep over millions of rows could OOM the beam.

**Fix:** Either (a) raise explicitly when `stream/1` is not exported so the caller knows to use `list/2`, or (b) document the fallback loudly and gate it behind an opt-in flag.
```elixir
if function_exported?(repo, :stream, 1) do
  repo.stream(q)
else
  raise ArgumentError,
        "Sigra.Audit.stream/2 requires repo.stream/1. " <>
          "Use Sigra.Audit.list/2 for repos without streaming support."
end
```

---

### WR-03: D-28 atomic-audit guarantee is violated at most integration sites

**File:** `lib/sigra/mfa.ex:177-193`, `lib/sigra/oauth.ex:146-190`, `lib/sigra/api_token.ex:99-107`, `lib/sigra/auth.ex:64-100`
**Issue:** The module docs and D-26 dispatch comments claim audit writes are "atomic" with the business op via `Ecto.Multi`, but the actual integration sites call `Sigra.Audit.log_safe/3` **after** `repo.transaction/1` returns `{:ok, ...}`. If the audit insert fails (schema validation error, forbidden key, size cap) the business transaction has already committed and the audit row is lost. This contradicts the phase-9 promise and the module docstring in `Sigra.Audit` (lines 11-16) that says `log_multi/3` is the atomic path.

Only `confirm_user/3`, `verify_confirmation_code/3`, and `reset_password/4` (in `lib/sigra/auth.ex`) correctly use `__log_internal__/3` inside the enclosing Multi.

**Fix:** Convert at least the following security-critical sites to `Multi` + `__log_internal__/3`:
- `Sigra.Auth.register/3` (noted as TODO at line 57-60)
- `Sigra.MFA.confirm_enrollment/5` (has a Multi already at line 166)
- `Sigra.OAuth.do_link_provider/3` (line 287)

For operations that genuinely cannot be transactional (e.g., `session.create` because the session store may be ETS/Redis), update the module docstring and D-28 text to state explicitly that these are best-effort post-commit writes.

---

### WR-04: `Sigra.Audit.log/2` does not fire telemetry on failure but `log_safe/3` fires a different event

**File:** `lib/sigra/audit.ex:55-61`, `lib/sigra/audit.ex:134-141`
**Issue:** The two error paths are inconsistent:
- `log/2` returns `{:error, changeset}` silently — no telemetry at all on failure.
- `log_safe/3` returns `:ok` but emits `[:sigra, :audit, :log_safe_error]`.

Downstream observability consumers watching for audit failures must subscribe to both. More importantly, `log/2` (the developer-facing API) has zero observability on failure, which means a host app calling `Sigra.Audit.log("billing.charge", ...)` and hitting a D-23 forbidden key will get a silent changeset error the caller may or may not handle.

**Fix:** Emit the same `[:sigra, :audit, :log_error]` telemetry (or a unified `[:sigra, :audit, :log]` event with `outcome: "error"` measurement) from both paths. Document the failure telemetry in the moduledoc.

---

### WR-05: Migration is missing retention-cleanup index on `inserted_at` alone

**File:** `priv/templates/sigra.install/create_audit_events.exs:21-23`
**Issue:** The migration creates `index(:audit_events, [:actor_id, :inserted_at])`, `[:action, :inserted_at]`, and `[:inserted_at]`. The third index supports retention cleanup but the ordering inside `do_cleanup/3` uses `where: e.inserted_at < ^cutoff` on a full table scan when the query planner chooses a different index. On PostgreSQL this is usually fine, but on SQLite with large tables the delete can lock the table for minutes.

More importantly, the `occurred_at` column is indexed nowhere, yet the query API accepts `:from` / `:to` filters on **`inserted_at`** (see `lib/sigra/audit/query.ex:35-39`). This is correct but confusing: the schema has both `occurred_at` and `inserted_at`, and the filter name suggests occurrence time. Either remove `occurred_at` (not needed since `inserted_at` is also `utc_datetime_usec`) or filter on `occurred_at` and index it.

**Fix:** Rename the filter keys for clarity and decide which timestamp is the "source of truth" for queries. Add an index on `occurred_at` if it becomes the query column. Current state creates two parallel timestamp columns with only one indexed.

---

### WR-06: `cleanup/1` ignores `retention_days` from configured app env

**File:** `lib/sigra/audit.ex:291-311`
**Issue:** `cleanup/1` reads `retention_days` only from the passed `opts`. The `configured_audit_opts/0` helper (line 325-330) exists but is called only from `changeset_opts/2`, not from `cleanup/1`. Host apps who set `config :sigra, :audit, retention_days: 90` in `config/runtime.exs` must still pass `retention_days: 90` explicitly to `Sigra.Audit.cleanup/1` — the configured value is not honored. `Sigra.Application.maybe_warn_audit_cleanup_fallback/0` reads `Application.get_env(:sigra, :audit, [])[:retention_days]`, so there is already a convention, but the cleanup function doesn't follow it.

**Fix:**
```elixir
def cleanup(opts) when is_list(opts) do
  repo = Keyword.fetch!(opts, :repo)
  audit_schema = Keyword.fetch!(opts, :audit_schema)

  retention_days =
    Keyword.get(opts, :retention_days) ||
      Application.get_env(:sigra, :audit, [])[:retention_days]

  do_cleanup(repo, audit_schema, retention_days)
end
```

---

### WR-07: `do_cleanup/3` has no batching — single `delete_all` on huge tables will time out

**File:** `lib/sigra/audit.ex:302-311`
**Issue:** `repo.delete_all(from e in schema, where: e.inserted_at < ^cutoff)` on a table with tens of millions of rows will hold a long transaction, bloat WAL, and on PostgreSQL can trigger autovacuum pressure or `statement_timeout`. The Oban worker has `max_attempts: 1` (by design for D-36 fail-open), so a timeout fails immediately with no retry.

**Fix:** Batch the delete using a subquery with `limit`. Example:
```elixir
def do_cleanup(repo, audit_schema, days) when is_integer(days) and days > 0 do
  import Ecto.Query
  cutoff = DateTime.add(DateTime.utc_now(), -days * 86_400, :second)
  batch_size = 10_000

  Stream.repeatedly(fn ->
    subquery =
      from(e in audit_schema,
        where: e.inserted_at < ^cutoff,
        select: e.id,
        limit: ^batch_size
      )

    {count, _} =
      from(e in audit_schema, where: e.id in subquery(subquery))
      |> repo.delete_all()

    count
  end)
  |> Enum.take_while(&(&1 > 0))
  |> Enum.sum()

  :ok
end
```

---

### WR-08: `log_safe/3` inserts changeset even when changeset is invalid (wastes DB roundtrip)

**File:** `lib/sigra/audit.ex:129-141`
**Issue:** `repo.insert(changeset)` is called unconditionally; an invalid changeset hits the DB driver (which will short-circuit, but still consumes a checkout). More importantly, the error telemetry metadata contains `cs.errors` — changeset errors may include the **offending metadata values** (e.g., the forbidden key's value) which can themselves be sensitive. D-23 forbids forbidden keys in the payload; the error telemetry should not reintroduce them.

**Fix:** Check `changeset.valid?` before inserting, and sanitize error metadata before emitting telemetry:
```elixir
if changeset.valid? do
  case repo.insert(changeset) do
    ...
  end
else
  :telemetry.execute(
    [:sigra, :audit, :log_safe_error],
    %{count: 1},
    %{action: action, error_types: error_keys(changeset)}
  )
  :ok
end
```

where `error_keys/1` returns only the field names (`[:metadata, :action]`), not the values.

---

## Info

### IN-01: `@default_reserved` is duplicated between `Sigra.Audit` and `Sigra.Audit.Changeset`

**File:** `lib/sigra/audit.ex:32`, `lib/sigra/audit/changeset.ex:26`
**Issue:** Both modules define identical reserved-prefix lists. Future prefix changes must update both. One should be the source of truth and the other should reference it.

**Fix:** Move to `Sigra.Audit.Changeset` and delegate: `@default_reserved Sigra.Audit.Changeset.default_reserved_prefixes()`.

---

### IN-02: `Sigra.Audit.Cursor` has no protection against maliciously enormous timestamps

**File:** `lib/sigra/audit/cursor.ex:18-27`
**Issue:** A hostile client could encode `DateTime.from_unix(999_999_999_999_999, :microsecond)` and pass it as a cursor. `DateTime.from_unix/2` will accept very large values; the query will return no rows (not a correctness issue) but `ts_int` is not range-checked. Cursors are documented as unsigned, so this is low-risk. Still, an explicit sanity check is cheap.

**Fix:** Add a bounds check: `ts_int > 0 and ts_int < 253_402_300_800_000_000` (year 9999 in microseconds).

---

### IN-03: `Sigra.APIToken.decode_cursor/1` uses raising parsers, unlike `Sigra.Audit.Cursor.decode/1`

**File:** `lib/sigra/api_token.ex:446-452`
**Issue:** `decode_cursor/1` uses `Base.url_decode64!`, pattern-matches with `=`, and calls `String.to_integer` — any of these raises on malformed input. The parallel `Sigra.Audit.Cursor.decode/1` returns `{:error, :invalid_cursor}`. The inconsistency means a tampered API token cursor crashes the caller while a tampered audit cursor degrades gracefully.

**Fix:** Refactor to use `Sigra.Audit.Cursor.decode/1` or mirror its safe pattern. Note that API token cursor carries an integer id while audit cursor carries a UUID string, so a shared `Cursor` module with two variants would be cleaner.

---

### IN-04: `build_attrs/4` sets `occurred_at` default to `DateTime.utc_now()` at call time

**File:** `lib/sigra/audit.ex:354`
**Issue:** `occurred_at` defaults to `DateTime.utc_now()` evaluated at `build_attrs/4` call time, not at insert time. For `log_multi/3` the multi is composed up-front and the insert may happen seconds later inside a larger transaction; `occurred_at` will reflect the composition time, not the commit time. This is a minor semantic drift from the "when the event occurred" intent.

**Fix:** Document that `occurred_at` is captured at `log_multi/3` call time (before Multi execution), not at commit time. Alternatively, default it to `nil` and have the changeset fill it at insert time using a `put_change/3` step (though this breaks the "event occurred_at" semantic).

---

### IN-05: `Sigra.Audit.list/2` builds an unnecessary `query/1` call from decorated filters

**File:** `lib/sigra/audit.ex:236-241`
**Issue:** `filters |> query() |> Query.paginate(...)` — `query/1` calls `Keyword.fetch!(filters, :audit_schema)` but `paginate/3` doesn't need the schema. This is fine functionally, but coupling query-building logic to the `audit_schema` keyword extraction makes it harder to compose filters from callers. Minor; flagged for future clean-up.

---

### IN-06: Missing moduledoc for `Sigra.Workers.AuditCleanup.cleanup/3`

**File:** `lib/sigra/workers/audit_cleanup.ex:51-54`
**Issue:** The `cleanup/3` function has a `@doc` string and `@spec`, but the fallback path description says "called by `Sigra.Audit.cleanup/1` (which delegates here)" — but `Sigra.Audit.cleanup/1` does NOT delegate here; it calls `do_cleanup/3` directly. The docstring is misleading.

**Fix:** Either wire `Sigra.Audit.cleanup/1` to delegate to `Sigra.Workers.AuditCleanup.cleanup/3` (simpler) or fix the docstring to say "calls the same `Sigra.Audit.do_cleanup/3` entry point."

---

_Reviewed: 2026-04-09_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
