# Phase 80 — Technical research

**Question:** What do we need to know to plan **forced password change audit atomicity** well?

## Authoritative code patterns

### `Sigra.Account` orchestration (template)

- **`change_password/5`** and **`set_password/4`** (`lib/sigra/account.ex` ~246–318): when **`audit_enabled?(opts)`** (`:audit_schema` present), they build **`Ecto.Multi`** → **`Multi.run(:domain, …)`** for the domain side-effect → **`Sigra.Audit.log_multi_safe("account.password_change", …)`** with **`metadata: %{forced: false}`** or **`%{forced: false, source: "oauth_set"}`** → **`finish_audit_multi/2`** (transaction + **`emit_telemetry_from_changes/1`**). Without audit, they delegate to **`PasswordChange`** only.
- **`password_change_scope_kw/2`** + **`scope_to_audit_kw/1`** supply **`actor_id`**, **`target_id`**, org / effective-user resolvers where needed. Forced clear has a full **`user`** map — same pattern as **`set_password`** (use **`Sigra.Scope.from_opts(opts, user)`** + **`scope_to_audit_kw`**).
- **`finish_audit_multi/2`** normalizes **`{:error, :domain, …}`** to surface domain errors without leaking **`Multi`** internals.

### Domain layer

- **`PasswordChange.clear_force_change/2`** (`lib/sigra/account/password_change.ex` ~124–128): single **`Ecto.Changeset.change`** + **`repo.update`**, wrapped in telemetry span **`[:sigra, :password, :force_change_completed]`**. No nested **`Repo.transaction`** — safe to call from **`Multi.run`** (same repo instance **`r`** as outer transaction).

### Legacy audit helper (retirement target)

- **`audit_forced_password_change/2`** (`lib/sigra/account.ex` ~485–505): post-hoc **`Sigra.Audit.log_safe/3`** for **`account.password_change`** with **`metadata: %{forced: true}`**. **AUD-17-01** replaces this path for the “clear flag” business outcome when audit is on; **AUD-17-02** deprecates / documents non-use for that outcome.

### Test harness

- **`test/sigra/account_audit_atomicity_test.exs`**: **`PostgresRepo`**, minimal **`audit_events`** + user table, **`base_opts/1`** with **`audit_schema: AuditTestEvent`**. **`CHECK`** constraints on **`audit_events.action`** prove rollback (see **`rolls back change_password when audit insert is rejected`** ~236–283). New tests should mirror **`try` / `after` / `DROP CONSTRAINT IF EXISTS`** cleanup.

## Requirements mapping

| REQ | Planning implication |
|-----|----------------------|
| **AUD-17-01** | New **`Sigra.Account`** public **`clear_password_change_requirement(repo, user, opts)`** (name per **80-CONTEXT D-80-01**): audit off → **`PasswordChange.clear_force_change`**; audit on → **`Multi` + `log_multi_safe`** + **`metadata: %{forced: true}`**. |
| **AUD-17-02** | **`@deprecated`** on **`audit_forced_password_change/2`** with message pointing to the new entry; keep **`log_safe`** body for one minor if needed for semver / upgrade path — **CHANGELOG** must warn against double-calling with the atomic API. |
| **AUD-17-03** | Extend **`account_audit_atomicity_test.exs`**: happy path + one **`CHECK`** rollback for forced clear. |
| **AUD-17-04** | Update **44-AUD-04-INVENTORY** row **043**, **09-VERIFICATION** C-1 **043**, **09-03-SUMMARY**, **`CHANGELOG` [Unreleased]**. |

## Pitfalls

- **Double audit:** Hosts must not call **`audit_forced_password_change/2`** after **`clear_password_change_requirement/3`** for the same completion — document in ExDoc + CHANGELOG.
- **Telemetry:** Forced clear today emits **`[:sigra, :password, :force_change_completed]`** inside **`clear_force_change`**. Wrapping in **`Multi.run`** still runs that span inside the outer **`finish_audit_multi`** transaction — acceptable; do not strip telemetry without an explicit decision.
- **`Scope.from_opts` with user_id-only:** Legacy helper builds minimal **`%{id: user_id}`** scope; new API uses full **`user`** — **`log_multi_safe`** resolvers should use **`user.id`** consistently.

## Validation Architecture

Phase verification is **automated-first** via **ExUnit** on a live **PostgreSQL** test database (project **`CLAUDE.md`** prerequisites).

| Dimension | Approach |
|-----------|----------|
| **Unit / integration** | **`mix test test/sigra/account_audit_atomicity_test.exs`** — happy + **`CHECK`** fault injection. |
| **Regression** | **`mix test test/sigra/account/password_change_test.exs`** — **`MockRepo`** contract for **`clear_force_change`** unchanged. |
| **Docs honesty** | Grep-verifiable strings in **44** inventory, **09-VERIFICATION** row **043**, **09-03-SUMMARY**, **CHANGELOG**. |

**Sampling:** After implementation plan commits, run the atomicity test file; before phase close, run both test files above.

---

## RESEARCH COMPLETE
