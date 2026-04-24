# Phase 81 — Technical research: JWT refresh / reuse audit atomicity

**Question:** What do we need to know to plan implementation of **AUD-18-01..04** well?

## Current state (`lib/sigra/api_token.ex`)

- **`audit_jwt_refresh/2`** and **`audit_jwt_refresh_reuse/2`** (since 0.9.0) call **`Sigra.Audit.log_safe/3`** with **`api.jwt_refresh`** / **`api.jwt_refresh_reuse`**, scope from **`Sigra.Scope.from_config(config, %{id: user_id})`**, and **`api_token_audit_opts(config)`** plus **`actor_id` / `target_id` / `metadata`**. Reuse adds **`outcome: "failure"`** and **`metadata: %{reason: "refresh_token_reuse_detected"}`**.
- **`log_safe`** performs a **standalone `repo.insert`** when `:audit_schema` is set — **not** wrapped in **`Repo.transaction/1`**. On insert failure it emits **`[:sigra, :audit, :log_safe_error]`** and returns **`:ok`** (never **`{:error, _}`** for integration ergonomics).
- **Reference implementation** for audit-only **Multi** + transaction in the same module: **`commit_api_token_verify_failure_audit/2`** (~200–237): **`Multi.new()` → `Audit.log_multi_safe("api.token_verify.failure", opts with :audit_multi_step)` → `config.repo.transaction/1` → success branch **`Audit.emit_telemetry_from_changes(changes, [:audit_api_token_verify_failure])`**; invalid changeset branch **`verify_failure_audit_emit_invalid_changeset/1`**; unexpected Multi failure **raises**; **`rescue`** maps constraint-class DB errors to **`log_safe_error`** with **`reason: :constraint_violation`** and **`action: "api.token_verify.failure"`**.

## Target architecture (from **81-CONTEXT.md** D-81-01..03)

1. **Single private orchestrator** (e.g. **`commit_api_token_jwt_audit/3`**) owning **Multi → `log_multi_safe` → `transaction` → telemetry / error paths**, analogous to **`commit_api_token_verify_failure_audit/2`** but parameterized by **action string** and **`:audit_multi_step`** atom so **refresh** and **reuse** stay DRY without sharing wrong telemetry metadata.
2. **Public wrappers** stay thin: build **scope** + **merged opts** (reuse keeps **failure outcome** + metadata), call orchestrator.
3. **Caller-visible behavior (D-81-02):** unchanged **`:ok`** return; **`:ok` does not guarantee audit row persisted** — document in **`@doc`**. On audit insert failure: same telemetry posture as verify-failure (**`log_safe_error`** with correct **`action`** key per event); **raise** only on unexpected Multi / transaction wiring.
4. **Audit off:** when **`Keyword.get(api_token_audit_opts(config), :audit_schema)`** is **`nil`**, early **`:ok`** without starting a transaction (match **`commit_api_token_verify_failure_audit`** first clause).

## `Audit.log_multi_safe/3` constraints

- **`log_multi_safe(multi, action, opts)`** no-ops on the **multi** when `:audit_schema` is absent (returns **multi** unchanged). Callers still need the **nil-schema early return** on **JWT** paths to avoid an empty transaction if we follow verify-failure style **before** building Multi — **same pattern as today’s `commit_api_token_verify_failure_audit`**.
- **`:audit_multi_step`** must be **unique per insert** in a Multi; one insert per JWT call, so one atom per action (e.g. **`:audit_api_token_jwt_refresh`** / **`:audit_api_token_jwt_refresh_reuse`**).
- **`emit_telemetry_from_changes/2`** must receive the **same step atom(s)** passed to **`log_multi_safe`**.

## Testing patterns (`test/sigra/api_token_audit_atomic_test.exs`)

- **PostgresRepo**, **`async: false`**, **`setup`** creates **`user_api_tokens`** + **`audit_events`**, **TRUNCATE**, CHECK guard **`audit_atomic_name_guard`** on token name for unrelated tests.
- **Verify failure fault injection:** temporary **`CHECK (action <> 'api.token_verify.failure')`** on **`audit_events`**, **`:telemetry.attach`** on **`[:sigra, :audit, :log_safe_error]`**, assert **`{:error, :invalid_token}`** still returned, **zero** failure audit rows, **`assert_receive`** with **`reason: :constraint_violation`**, **`action: "api.token_verify.failure"`**.
- **Phase 81** should add **parallel structure** for **`api.jwt_refresh`** and **`api.jwt_refresh_reuse`** with **distinct CHECK constraints** and **unique telemetry handler ids** (do not reuse **`:verify_failure_guard`** attach tuple).

## Documentation touchpoints (AUD-18-04)

- **44-AUD-04-INVENTORY.md** rows **048–049**, **45-AUD-04-INVENTORY.md** + **EX-45-JWT-*** appendix, **09-VERIFICATION.md** C-1 **048–049**, **09-03-SUMMARY.md**, **`CHANGELOG.md` [Unreleased]** — surgical updates per **D-81-04**: mechanism = **`Repo.transaction/1` + Multi + `log_multi_safe`**, footnote **T1** scoped to **audit-row durability for `api.jwt_refresh*`**; **AUD-08** still deferred.
- **`81-VERIFICATION.md`** — record merge gate / human sign-off table for this phase.

## Risks / pitfalls

- **Hard-coded action strings** in **`verify_failure_audit_emit_invalid_changeset`** / rescue metadata — JWT orchestrator must pass **dynamic `action`** into any shared invalid-changeset / rescue telemetry helper (small private **`jwt_audit_emit_log_safe_error(action, reason, extra_metadata)`** or per-action calls).
- **Scope merge order:** **`api_token_scope_fields(scope)`** + **`api_token_audit_opts`** + explicit **`actor_id`/`target_id`** — mirror **`verify_failure_audit_opts`** “caller wins” semantics; **`Scope.from_config(config, %{id: user_id})`** supplies org / effective_user / actor when impersonation matters.

## RESEARCH COMPLETE

---

## Validation Architecture

**Dimension 8 (Nyquist) — automated feedback for this phase**

| Dimension | How phase 81 is validated |
|-----------|---------------------------|
| **Unit / integration** | **`test/sigra/api_token_audit_atomic_test.exs`** — happy paths, audit-off, CHECK fault injection per action, telemetry assertions. |
| **Regression** | Full **`mix test`** before merge; minimally **`PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/api_token_audit_atomic_test.exs`**. |
| **Planning truth** | Grep-verifiable strings in **44** / **45** / **09** / **CHANGELOG** per plan 03 acceptance criteria. |

**Sampling policy**

- After **every task** that touches **Elixir** under **`lib/`** or **`test/`**: run **`mix test test/sigra/api_token_audit_atomic_test.exs`** (fast slice).
- After **all code tasks**: full **`mix test`** (or CI-equivalent).
- **Doc-only tasks**: `grep` acceptance criteria; no DB unless reverifying inventories.

**Wave 0:** Not required — **ExUnit** + **PostgresRepo** already exist from phase 79-era file.
