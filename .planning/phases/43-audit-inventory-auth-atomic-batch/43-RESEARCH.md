# Phase 43 — Technical research

**Question:** What do we need to know to plan AUD-04 (inventory) and AUD-05 (`Sigra.Auth` hybrid → `Ecto.Multi` audit) well?

**Sources:** `43-CONTEXT.md`, `REQUIREMENTS.md` AUD-04/AUD-05, `lib/sigra/audit.ex`, `lib/sigra/auth.ex`, Phase 39 patterns (`test/sigra/api_token_audit_atomic_test.exs`, `reset_password/4` Multi + `__log_internal__`).

---

## Audit API contracts (library)

- **`Sigra.Audit.log_safe/3`** — standalone `repo.insert` in a separate transaction from caller’s business writes. Returns `:ok` always on integration sites; must not change caller `{:ok, _}` / `{:error, _}` shapes (D-28 / Phase 39).
- **`Sigra.Audit.__log_internal__/3`** — appends `:audit` step to `Ecto.Multi`; reserved-prefix safe for library-owned `auth.*` / `session.*` events.
- **`Sigra.Audit.log_multi_safe/3`** — same as internal append when `audit_schema` set; no-op multi when disabled.
- **`Sigra.Audit.emit_telemetry_from_changes/1`** — must run only in `{:ok, changes}` after `repo.transaction/1` / `repo.transact/1` for Multi paths (never on rollback).

## Established atomic template in-repo

- **`reset_password/4`** (`lib/sigra/auth.ex` ~990–1059) — `Multi.new()` → password update → `delete_all` tokens → conditional `__log_internal__` for `auth.password_reset_complete` → single `repo.transaction` → `emit_telemetry_from_changes`. **Use as mechanical template** for other token + user mutation paths (`verify_magic_link`, `request_magic_link` token insert, etc.).

## Registration path

- **`register/3`** already uses **`register_user_multi/2` |> repo.transact()`**. Success/failure audits are **`log_safe` after** transact — **AUD-05 target:** append `log_multi_safe` / `__log_internal__` for `auth.register.success` (and optionally failure rows where changeset context exists) onto the same Multi **before** transact, then emit telemetry from changes on `{:ok, %{user: u}}` only.

## Login / lockout / session cluster (highest complexity)

- **`authenticate_with_config/2`** performs: lockout check → optional `auth.login.success` `log_safe` → **`handle_valid_login_with_security`** → `Lockout.reset!` / hash upgrade updates → **`create_session`** → **`maybe_assign_active_organization`** → **`log_safe("session.create", ...)`**.
- **Session store** (`session_store.create`, `update_active_organization`) may not be plain Ecto — **full single-DB-transaction wrapping entire login** may be infeasible without SessionStore API changes. **Research conclusion:** inventory must classify (a) **pure Ecto** sites eligible for same-Repo `Multi`, (b) **session / external store** sites that stay hybrid until a later milestone or need explicit “audit after store commit” documentation with compensating tests (e.g. assert `session.create` only after session row exists).
- **Partial win:** Co-locate **`auth.login.success`** audit with **`Lockout.reset!` + user field updates** in one `Ecto.Multi` where those steps are already Repo-backed (aligns with D-43-02 tiers 1–3 narrative).

## `log_safe` inventory scope (AUD-04)

- **AUD-04** requires **all remaining `log_safe` integration sites** grouped by module (Auth, MFA, Account, …) with **priority** and **exclusions**. For Phase 43 execution, **Auth + cross-cutting `session.*` inside `auth.ex`** are in scope for AUD-05; **other modules** (Mfa, Account, OAuth, …) are **inventory rows forwarded to phases 44–45** per ROADMAP.
- **Stable row IDs:** `AUD-04-NNN` per `43-CONTEXT.md` D-43-01.

## Testing strategy

- Reuse **`Sigra.Test.PostgresRepo`** + minimal DDL patterns from **`test/sigra/api_token_audit_atomic_test.exs`**.
- Assertions: **`Sigra.Audit.Assertions`** where applicable; else `Repo.all` on `audit_events` with **`order_by: [asc: id]`** (or `inserted_at` + id tiebreak); **rollback tests** prove no audit row on aborted transaction.
- **Do not** mock `Repo` for atomicity proofs (D-43-04).

## Risk: return-shape and telemetry

- Moving `log_safe` into Multi must preserve **existing return tuples** and **telemetry event ordering** documented in `@doc` for public functions — add regression tests when touching `authenticate`, `register`, `request_magic_link`, etc.

---

## Validation Architecture

> Nyquist Dimension 8 — execution agents must prove audit rows participate in the same transaction as the authoritative state change where the plan claims atomicity.

### Dimensions covered

| Dim | Topic | How verified |
|-----|-------|----------------|
| 1 | Correctness | `mix test` targeted modules + full `mix test` CI |
| 2 | Regression | Existing auth / audit tests unchanged or updated with same assertions |
| 8 | Atomicity | Dedicated `*_audit_atomicity_test.exs` with rollback + `Repo` queries; no `Repo` mocks |
| Security | Forensic integrity | Plans include `<threat_model>`; tests assert `action`, `actor_id` / `target_id` per D-39 |

### Validation artifacts

- Per-plan `<verify>` runs **after** task commits: at minimum `mix compile` and scoped `mix test path`.
- **Wave A (plan 01):** documentation + grep-based acceptance (no DB atomicity tests required).
- **Wave B (plans 02+):** each conversion plan includes at least one **rollback** or **no-row-on-failure** assertion for the audited operation.

### Instrumentation

- Use existing **`[:sigra, :audit, :log]`** and **`[:sigra, :audit, :log_safe_error]`** only where plans explicitly add telemetry assertions; default is DB row proofs.

---

## RESEARCH COMPLETE

Ready for planning: inventory structure locked in CONTEXT; implementation templates identified (`reset_password`, `register_user_multi`); login/session cluster flagged for tiered conversion / honest hybrid classification in AUD-04.
