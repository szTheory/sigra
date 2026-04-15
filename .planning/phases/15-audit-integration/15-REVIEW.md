---
phase: 15-audit-integration
reviewed: 2026-04-12T00:00:00Z
depth: standard
files_reviewed: 35
files_reviewed_list:
  - .credo.exs
  - CHANGELOG.md
  - lib/sigra/account.ex
  - lib/sigra/api_token.ex
  - lib/sigra/audit.ex
  - lib/sigra/audit/changeset.ex
  - lib/sigra/audit/query.ex
  - lib/sigra/auth.ex
  - lib/sigra/credo/no_log_safe2_in_lib.ex
  - lib/sigra/install/features/core.ex
  - lib/sigra/lockout.ex
  - lib/sigra/mfa.ex
  - lib/sigra/oauth.ex
  - lib/sigra/plug/load_active_organization.ex
  - lib/sigra/scope.ex
  - lib/sigra/suspicious_login.ex
  - lib/sigra/workers.ex
  - lib/sigra/workers/account_deletion.ex
  - lib/sigra/testing.ex
  - mix.exs
  - priv/templates/sigra.install/core/alter_audit_events_add_org_columns.exs
  - priv/templates/sigra.install/core/audit_event.ex
  - test/example/lib/example/accounts/audit_event.ex
  - test/example/priv/repo/migrations/20260410125246_alter_audit_events_add_org_columns.exs
  - test/sigra/audit/log_safe_scope_test.exs
  - test/sigra/audit/query_filters_test.exs
  - test/sigra/audit/query_index_test.exs
  - test/sigra/credo/no_log_safe2_in_lib_test.exs
  - test/sigra/install/features/core_test.exs
  - test/sigra/scope/build_test.exs
  - test/sigra/testing/assert_audit_logged_test.exs
  - test/sigra/workers/behaviour_test.exs
  - test/sigra/workers/account_deletion_test.exs
  - test/support/audit_test_event.ex
  - test/support/postgres_test_repo.ex
  - test/test_helper.exs
findings:
  critical: 0
  warning: 3
  info: 6
  total: 9
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-04-12
**Depth:** standard
**Files Reviewed:** 35
**Status:** issues_found

## Summary

Phase 15 wires organization-aware scope into the audit pipeline. The core design is sound: `Sigra.Audit.log_safe/3` cleanly duck-types `%Scope{}`, the `Keyword.merge(scope_opts, opts)` caller-wins merge is well-tested, the new `Query` filters are strictly whitelisted (with a good breaking-change fail-loud-on-unknown-key), and the Postgres-only EXPLAIN test is a strong safety net for the composite index. The `Sigra.Workers` behaviour is well thought out — fail-fast arg validation in both `new/3` and `fetch_arg!/2` belt-and-suspenders, and the worker scope's "audit-only, never authorization" warning is documented in three places.

No critical security issues. The issues found are:

- **Three warnings**: one scope-consistency gap in `suspicious_login.ex` where a resolved `user_id` is dropped into a `nil` scope (producing audit rows that miss `effective_user_id` for exactly the events where you most want attribution); one Credo check false-positive surface on aliased `Audit` (non-Sigra) calls; one dead/no-op statement in `Sigra.Lockout.reset!/2` left behind from a partially-ported audit stub.
- **Six info items**: minor dead aliases, misleading comments, duplicate-error-path code in `Query.apply_filter`, and a few naming/clarity smells.

---

## Warnings

### WR-01: `suspicious_login.ex` drops resolved user_id instead of building a scope

**File:** `lib/sigra/suspicious_login.ex:90`
**Issue:** `Sigra.Audit.log_safe("security.suspicious_login", nil, ...)` is called with a hard-coded `nil` scope even though `config` and `user_id` are both in scope at that point. Every other library call site that has a resolved user but no `%Scope{}` uses `Sigra.Scope.from_config(config, %{id: user_id})` so the audit row picks up `effective_user_id`. As-is, suspicious-login audit rows will have `effective_user_id = NULL` and `organization_id = NULL`, which defeats the v1.2 impersonation anchor precisely on a high-signal security event where attribution matters most.

Note: `actor_id: user_id` is still passed in opts and wins over the nil-scope default, so that column is correct — but `effective_user_id` is never set because `scope_fields(nil)` returns `effective_user_id: nil` and the caller does not override it.

**Fix:**
```elixir
Sigra.Audit.log_safe(
  "security.suspicious_login",
  Sigra.Scope.from_config(config, %{id: user_id}),
  repo: config.repo,
  audit_schema: Keyword.get(audit_config, :audit_schema),
  actor_id: user_id,
  outcome: "failure",
  ip_address: login_ip,
  metadata: %{geo_city: geo[:city], geo_country_code: geo[:country_code]}
)
```

---

### WR-02: Credo check `NoLogSafe2InLib` false-positives on unrelated aliased `Audit` modules

**File:** `lib/sigra/credo/no_log_safe2_in_lib.ex:63`
**Issue:** The walker matches alias_parts against `[[:Sigra, :Audit], [:Audit]]`. If a host app module under `lib/sigra/` ever writes `alias MyApp.SomethingElse.Audit` and then calls `Audit.log_safe(arg1, arg2)` (arity 2), the check will wrongly flag it as a Sigra shim call. Today there is nothing in `lib/sigra/**` that aliases a non-Sigra `Audit` module, so this is latent — but it will bite any future refactor that introduces a second `.Audit` suffix.

The safer resolution is to cross-reference the alias declarations in the source file before flagging, or to only match the fully-qualified `[:Sigra, :Audit]` form and require the shim exemption to be documented for `Audit.log_safe/2` callers. Alternatively, accept the false-positive risk and document it in the check's `@moduledoc` as a known-limitation so operators have a path to silence it (Credo disable comments).

**Fix:** Document the limitation in `@moduledoc` and suggest `# credo:disable-for-next-line Sigra.Credo.NoLogSafe2InLib` as the escape hatch, OR resolve aliases before matching:
```elixir
# In walk/2, look up the alias resolution from the source file's
# AST header before concluding the call targets Sigra.Audit. A
# minimal fix: also detect that no non-Sigra `alias _.Audit` lines
# appear in the file before flagging the bare [:Audit] form.
```

---

### WR-03: `Sigra.Lockout.reset!/2` contains dead `_ = user` / `result` statements

**File:** `lib/sigra/lockout.ex:113-127`
**Issue:** The function assigns `result`, then does `_ = user` (no-op), then returns `result`. The comment block above says audit emission "must happen at the caller of reset!/2", which is fine — but the leftover `_ = user` line is not load-bearing and reads as half-ported code. It survives compilation without warning only because of the underscore prefix. A reviewer will wonder what was intended; cleanup is cheap.

**Fix:**
```elixir
def reset!(repo, user) do
  user
  |> Ecto.Changeset.change(%{failed_login_attempts: 0, locked_at: nil})
  |> repo.update!()
end
```

And delete the dangling comment block that refers to the un-threaded `:audit` key — it describes behavior that does not exist in this function.

---

## Info

### IN-01: `Sigra.Audit.Query.apply_filter/2` has unreachable fallback clause

**File:** `lib/sigra/audit/query.ex:96-100`
**Issue:** `build/2` already validates every filter key via `Enum.each(filters, ...)` at the top and raises `ArgumentError` on unknown keys before `Enum.reduce` ever dispatches to `apply_filter/2`. The trailing `defp apply_filter({key, _value}, _q)` catch-all that re-raises `ArgumentError` is therefore unreachable. Either delete it (trust the up-front validation) or delete the up-front validation and keep only the per-clause fallback. Two places to maintain the allowed-filter list is a minor drift hazard.

**Fix:** Delete the `apply_filter` catch-all clause and rely on `build/2`'s `Enum.each` prelude as the single source of truth.

---

### IN-02: `Sigra.Audit.log_safe/3` scope_fields/1 emits `actor_id: nil` as a default that can surprise callers

**File:** `lib/sigra/audit.ex:142-143`
**Issue:** `scope_fields(nil)` returns `[organization_id: nil, effective_user_id: nil, actor_id: nil]`. This is then `Keyword.merge`'d with caller opts, so caller-supplied `actor_id` always wins — good. But callers who inspect the post-merge keyword list (e.g. a test helper) will see an `actor_id: nil` that was never explicitly passed by anyone. The `nil` is harmless here because `build_attrs` uses `Keyword.get/2`, but it is a readability hazard: a grep for `actor_id:` in `log_safe` plumbing now returns hits inside library internals that no caller wrote.

Consider returning only non-nil keys from `scope_fields/1` so the post-merge keyword list reflects what was actually supplied. Alternatively, document in the `@doc` that scope_fields stamps nil defaults so the merge semantics are explicit.

**Fix:** Document in the `scope_fields` function-head `@doc` (or a module-private comment) that the nil defaults exist so the caller-wins merge is well-defined, OR drop the nil entries and let `build_attrs` fall back to `Keyword.get(opts, :actor_id)` returning nil naturally.

---

### IN-03: `Sigra.Workers.AccountDeletion.perform/1` uses named underscore-prefix variables for the validate-up-front keys

**File:** `lib/sigra/workers/account_deletion.ex:68-75`
**Issue:** Eight lines of `_organization_id_key = Sigra.Workers.fetch_arg!(args, "organization_id")`. The pattern works — it forces `KeyError` before `Module.safe_concat` — but there is a lighter, more idiomatic form: `Enum.each(~w(organization_id actor_id audit_schema ...), &Sigra.Workers.fetch_arg!(args, &1))`. Same runtime guarantee, one line, no dead bindings.

**Fix:**
```elixir
for key <- ~w(organization_id actor_id audit_schema scope_module organization_schema repo user_schema user_id) do
  Sigra.Workers.fetch_arg!(args, key)
end
```

---

### IN-04: `Sigra.Account.account_audit_opts/1` is immediately overridden at every call site

**File:** `lib/sigra/account.ex:52-57`
**Issue:** `account_audit_opts/1` returns `[repo: Keyword.get(opts, :repo), audit_schema: Keyword.get(opts, :audit_schema)]` — then every caller does `account_audit_opts(opts) |> Keyword.put(:repo, repo)` to replace the `repo:` value with the positional `repo` argument. The `Keyword.get(opts, :repo)` branch inside the helper is therefore dead in practice: it is always overwritten. Simplify by dropping the `repo:` key from the helper entirely and letting the caller supply it via `Keyword.put`.

**Fix:**
```elixir
defp account_audit_opts(opts) when is_list(opts) do
  [audit_schema: Keyword.get(opts, :audit_schema)]
end
# callers: [repo: repo] ++ account_audit_opts(opts) ++ [...]
```

---

### IN-05: `lib/sigra/install/features/core.ex` has an inconsistent audit migration filename comment

**File:** `lib/sigra/install/features/core.ex:218-222`
**Issue:** The comment says "Phase 9: audit events migration (monolith position 23)" immediately followed by "Phase 15: audit events ALTER migration adding org columns (D-11)". The audit ALTER migration is phase 15 material, yet the migrations/1 callback returns it as part of the canonical list. That is correct behavior — but the "monolith position 23" annotation is stale after phase 15 and will confuse future readers. Update the comment to reflect the new canonical order or remove the historical position-N notes.

**Fix:** Drop the "(monolith position 23)" annotation; it was load-bearing during the Wave 3 monolith-port but no longer reflects the post-phase-15 state.

---

### IN-06: `Sigra.Workers.AccountDeletion` hoists `perform/2` argument resolution that duplicates `perform/1`

**File:** `lib/sigra/workers/account_deletion.ex:106-112`
**Issue:** `perform/2` re-resolves `repo`, `user_schema`, and `audit_schema` via `Module.safe_concat([Map.fetch!(args, ...)])` even though `perform/1` already did the same resolutions a few lines up and could have passed them through. This is intentional per the comment (`perform/2` needs to work when invoked directly by a test without going through `perform/1`), but the duplication is not documented at the `perform/2` head. A reader seeing `perform/2` in isolation will wonder why it is re-resolving things that the behaviour contract implies would be provided.

**Fix:** Add a one-line comment on `perform/2` explaining that it re-resolves stringified module args so it is callable standalone from tests, and that `perform/1` does the same work up front purely for the KeyError-before-ArgumentError ordering guarantee.

---

_Reviewed: 2026-04-12_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
