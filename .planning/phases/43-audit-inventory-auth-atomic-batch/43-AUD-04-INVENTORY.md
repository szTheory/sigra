# AUD-04 Inventory

**Module:** `Sigra.Auth` (`lib/sigra/auth.ex`)  
**Gathered:** 2026-04-20  
**Scope:** Every `Sigra.Audit.log_safe/3` (and `Audit.log_safe/3`) integration site in `auth.ex`, plus `Sigra.Audit.__log_internal__/3` Multi-anchored rows for completeness. Non-Auth `lib/sigra/*` sites are **out of scope for this file’s row table** (forward to phases **44–45** per ROADMAP); only `auth.ex` appears in the priority table below.

## Priority table

| ID | Boundary | action | mechanism | tier | AUD-05 tag | notes |
|----|------------|--------|-----------|------|------------|-------|
| AUD-04-001 | `register/3` success | `auth.register.success` | **Multi (`log_multi_safe`)** when `:audit_schema` set | 6 | **B1 — done** | Composed on `register_user_multi/2` (Phase 43 plan 02). |
| AUD-04-002 | `register/3` failure | `auth.register.failure` | `log_safe` | 6 | **B1** | Enumeration-safe failure paths; optional Multi move only where changeset context exists without regressing `{:error, :email_taken}`. |
| AUD-04-003 | `authenticate_with_config/2` | `security.lockout` | `log_safe` | 4 | **B3** | Pre-password lockout check (`Lockout.check/2` path). |
| AUD-04-004 | `authenticate_with_config/2` | `auth.login.success` | **Multi (`log_multi_safe`)** when `:audit_schema` + confirmed; else `log_safe` (unconfirmed pre-check path) | 3 | **B3 — done** | Same Repo transaction as `Lockout.reset!/2` + optional hash upgrade (Plan 04). |
| AUD-04-005 | `authenticate_with_config/2` | `auth.login.success` | **Multi (`log_multi_safe`)** when `:audit_schema` + confirmed; else `log_safe` | 1 | **B3 — done** | Same as AUD-04-004 with `metadata.hash_upgraded: true`. |
| AUD-04-006 | `authenticate_with_config/2` | `auth.login.failure` | `log_safe` | 9 | **B3** | Known user, wrong password — **intentional hybrid** until AUD-08 (D-43-02 tier 9). |
| AUD-04-007 | `authenticate_with_config/2` | `auth.login.failure` | `log_safe` | 9 | **B3** | Unknown email — **intentional hybrid** (tier 9). |
| AUD-04-008 | `request_magic_link/3` | `auth.magic_link_request` | **Multi (`log_multi_safe`)** when `:audit_schema` | 5 | **B2 — done** | Token insert + audit in one `repo.transact/1` (plan 03). |
| AUD-04-009 | `verify_magic_link/3` | `auth.magic_link_verify.success` | **Multi (`log_multi_safe`)** when `:audit_schema` | 5 | **B2 — done** | Token delete + confirm + audit (plan 03). |
| AUD-04-010 | `request_password_reset/4` | `auth.password_reset_request` | **Multi (`log_multi_safe`)** when `:audit_schema` | 7 | **B2 — done** | Token insert + audit (plan 03). |
| AUD-04-011 | `reset_password/4` | `auth.password_reset_complete` | **Multi (`__log_internal__`)** | — | **— (done)** | Template for B2 conversions (`reset_password/4`). |
| AUD-04-012 | `confirm_user/3` | `auth.confirmation_verify.success` | **Multi (`__log_internal__`)** | — | **— (done)** | `metadata.method: "link"`. |
| AUD-04-013 | `verify_confirmation_code/3` | `auth.confirmation_verify.success` | **Multi (`__log_internal__`)** | — | **— (done)** | `metadata.method: "code"`. |
| AUD-04-014 | `maybe_assign_active_organization/7` (via `create_session/4`) | `session.create` | `log_safe` | 3 | **B3 hybrid** | Emitted after SessionStore create + org selection; **SessionStore may not be plain Ecto** — see `43-RESEARCH.md` (“full single-DB-transaction wrapping entire login may be infeasible”). |
| AUD-04-015 | `delete_session/3` | `session.delete` | `log_safe` | 8 | **defer-45** | Session store boundary; batch with other session audits in a later milestone unless API allows Multi. |
| AUD-04-016 | `delete_all_sessions/3` | `session.revoke_all` | `log_safe` | 2 | **defer-45** | Bulk revoke + PubSub; not Auth AUD-05 atomic batch in v1.4. |
| AUD-04-017 | `confirm_sudo/3` | `session.sudo_enter` / `session.sudo_expire` | `log_safe` | 8 | **defer-45** | Dynamic `action` from store result; SessionStore-backed. |
| AUD-04-018 | `handle_failed_login_with_lockout/5` | `security.invalid_credentials` | `log_safe` | 9 | **B3 hybrid** | Per-attempt counter metadata; **tier 9 intentional hybrid** (D-43-02). |
| AUD-04-019 | `handle_failed_login_with_lockout/5` | `security.lockout` | `log_safe` | 4 | **B3** | Emitted when threshold reached (after `Lockout.increment!/3`). |

## Scope cut (Plan 04)

**Converted in code (B3 / Plan 04):** `auth.login.success` on the **confirmed** `authenticate_with_config/2` path is **`Ecto.Multi` + `Audit.log_multi_safe/3`** together with **`Lockout.reset!/2`** and optional **password hash upgrade** `repo.update/2`, then `emit_telemetry_from_changes/1`. **Unconfirmed** users (`require_confirmation` + `confirmed_at` nil) still use standalone **`Audit.log_safe/3`** before `handle_valid_login_with_security/6` returns `{:error, :unconfirmed}` — preserving the pre-existing ordering where a success audit could emit even when login is ultimately rejected.

**Explicit hybrid / defer (not converted in Plan 04):**

- **`session.create`** and the rest of the **session helper cluster** (`session.delete`, `session.revoke_all`, `session.sudo_*`) — **SessionStore is not guaranteed to be plain Ecto** per `43-RESEARCH.md`; remain **`log_safe`** with **defer-45** or **B3 hybrid** as already marked in the table.
- **`auth.login.failure`**, **`security.invalid_credentials`** — **tier 9 intentional hybrid** (EX-43-01); no `Lockout.increment!` promotion in this phase.
- **`security.lockout`** rows (pre-auth + threshold) — remain **`log_safe`**; threshold path shares fate with `increment!` but email side-effects and telemetry stay outside a single DB transaction by design.

## Exclusions appendix

| ID | REQ / control | scope | mechanism | residual risk | compensating control | owner | reopen trigger | evidence | last reviewed |
|----|---------------|-------|-----------|---------------|----------------------|-------|------------------|----------|----------------|
| EX-43-01 | AUD-05, D-43-02 §9, C-1 | `auth.login.failure` + `security.invalid_credentials` (tier 9) | `log_safe` | Audit may commit if later Repo steps roll back | Existing auth + lockout tests; rate limits | Sigra | AUD-08 or incident class “forensic gap on failed attempts” | `test/sigra/auth_test.exs` | 2026-04-20 |

## Grep log

```text
$ rg -n "Audit\.log_safe|Sigra\.Audit\.log_safe" lib/sigra/auth.ex
167:            Audit.log_safe(
180:            Audit.log_safe(
260:  #   register failure    -> Sigra.Audit.log_safe("auth.register.failure", nil, ...)
261:  #   login success       -> Sigra.Audit.log_safe("auth.login.success", nil, ...)
263:  #   login failure       -> Sigra.Audit.log_safe("auth.login.failure", nil, ...)
421:        Audit.log_safe(
502:        Audit.log_safe(
553:              Audit.log_safe(
571:              Audit.log_safe(
1332:    Sigra.Audit.log_safe(
1436:    Sigra.Audit.log_safe(
1499:    Sigra.Audit.log_safe(
1577:    Sigra.Audit.log_safe(
1872:    Sigra.Audit.log_safe(
1893:      Sigra.Audit.log_safe(
```

Forward pointers: **Phase 44–45** own remaining `lib/sigra/*` `log_safe` sites (MFA, Account, OAuth, etc.) per ROADMAP — this inventory is **Auth + session helpers colocated in `auth.ex` only**.

MFA, `Sigra.Account`, and `Sigra.APIToken` audit rows continue in **`.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md`** starting at **AUD-04-020** (same **AUD-04** program; REQ batches **AUD-06** / **AUD-07**).
