# AUD-04 Inventory

**Module:** `Sigra.Auth` (`lib/sigra/auth.ex`)  
**Gathered:** 2026-04-20  
**Scope:** Every `Sigra.Audit.log_safe/3` (and `Audit.log_safe/3`) integration site in `auth.ex`, plus `Sigra.Audit.__log_internal__/3` Multi-anchored rows for completeness. Non-Auth `lib/sigra/*` sites are **out of scope for this file’s row table** (forward to phases **44–45** per ROADMAP); only `auth.ex` appears in the priority table below.

## Priority table

| ID | Boundary | action | mechanism | tier | AUD-05 tag | notes |
|----|------------|--------|-----------|------|------------|-------|
| AUD-04-001 | `register/3` success | `auth.register.success` | `log_safe` (post-`repo.transact`) | 6 | **B1** | Target: compose into `register_user_multi` + `log_multi_safe` / `__log_internal__` (Phase 43 plan 02). |
| AUD-04-002 | `register/3` failure | `auth.register.failure` | `log_safe` | 6 | **B1** | Enumeration-safe failure paths; optional Multi move only where changeset context exists without regressing `{:error, :email_taken}`. |
| AUD-04-003 | `authenticate_with_config/2` | `security.lockout` | `log_safe` | 4 | **B3** | Pre-password lockout check (`Lockout.check/2` path). |
| AUD-04-004 | `authenticate_with_config/2` | `auth.login.success` | `log_safe` | 3 | **B3** | Password OK, before `handle_valid_login_with_security` / session mint. |
| AUD-04-005 | `authenticate_with_config/2` | `auth.login.success` | `log_safe` | 1 | **B3** | Same as AUD-04-004 with `metadata.hash_upgraded: true` (credential mutation narrative per D-43-02). |
| AUD-04-006 | `authenticate_with_config/2` | `auth.login.failure` | `log_safe` | 9 | **B3** | Known user, wrong password — **intentional hybrid** until AUD-08 (D-43-02 tier 9). |
| AUD-04-007 | `authenticate_with_config/2` | `auth.login.failure` | `log_safe` | 9 | **B3** | Unknown email — **intentional hybrid** (tier 9). |
| AUD-04-008 | `request_magic_link/3` | `auth.magic_link_request` | `log_safe` (after `insert!`) | 5 | **B2** | Token insert + audit not single transaction (plan 03). |
| AUD-04-009 | `verify_magic_link/3` | `auth.magic_link_verify.success` | `log_safe` | 5 | **B2** | Token delete + user update + audit (plan 03). |
| AUD-04-010 | `request_password_reset/4` | `auth.password_reset_request` | `log_safe` (after `insert!`) | 7 | **B2** | Token issuance (plan 03). |
| AUD-04-011 | `reset_password/4` | `auth.password_reset_complete` | **Multi (`__log_internal__`)** | — | **— (done)** | Template for B2 conversions (`reset_password/4`). |
| AUD-04-012 | `confirm_user/3` | `auth.confirmation_verify.success` | **Multi (`__log_internal__`)** | — | **— (done)** | `metadata.method: "link"`. |
| AUD-04-013 | `verify_confirmation_code/3` | `auth.confirmation_verify.success` | **Multi (`__log_internal__`)** | — | **— (done)** | `metadata.method: "code"`. |
| AUD-04-014 | `maybe_assign_active_organization/7` (via `create_session/4`) | `session.create` | `log_safe` | 3 | **B3 hybrid** | Emitted after SessionStore create + org selection; **SessionStore may not be plain Ecto** — see `43-RESEARCH.md` (“full single-DB-transaction wrapping entire login may be infeasible”). |
| AUD-04-015 | `delete_session/3` | `session.delete` | `log_safe` | 8 | **defer-45** | Session store boundary; batch with other session audits in a later milestone unless API allows Multi. |
| AUD-04-016 | `delete_all_sessions/3` | `session.revoke_all` | `log_safe` | 2 | **defer-45** | Bulk revoke + PubSub; not Auth AUD-05 atomic batch in v1.4. |
| AUD-04-017 | `confirm_sudo/3` | `session.sudo_enter` / `session.sudo_expire` | `log_safe` | 8 | **defer-45** | Dynamic `action` from store result; SessionStore-backed. |
| AUD-04-018 | `handle_failed_login_with_lockout/5` | `security.invalid_credentials` | `log_safe` | 9 | **B3 hybrid** | Per-attempt counter metadata; **tier 9 intentional hybrid** (D-43-02). |
| AUD-04-019 | `handle_failed_login_with_lockout/5` | `security.lockout` | `log_safe` | 4 | **B3** | Emitted when threshold reached (after `Lockout.increment!/3`). |

## Exclusions appendix

| ID | REQ / control | scope | mechanism | residual risk | compensating control | owner | reopen trigger | evidence | last reviewed |
|----|---------------|-------|-----------|---------------|----------------------|-------|------------------|----------|----------------|
| EX-43-01 | AUD-05, D-43-02 §9, C-1 | `auth.login.failure` + `security.invalid_credentials` (tier 9) | `log_safe` | Audit may commit if later Repo steps roll back | Existing auth + lockout tests; rate limits | Sigra | AUD-08 or incident class “forensic gap on failed attempts” | `test/sigra/auth_test.exs` | 2026-04-20 |

## Grep log

```text
$ rg -n "Audit\.log_safe|Sigra\.Audit\.log_safe" lib/sigra/auth.ex
148:      # D-26: audit integration. Uses Sigra.Audit.log_safe/2 (standalone, D-28)
161:          Audit.log_safe(
177:            Audit.log_safe(
190:            Audit.log_safe(
248:  #   register success    -> Sigra.Audit.log_safe("auth.register.success", nil, ...)
250:  #   register failure    -> Sigra.Audit.log_safe("auth.register.failure", nil, ...)
251:  #   login success       -> Sigra.Audit.log_safe("auth.login.success", nil, ...)
253:  #   login failure       -> Sigra.Audit.log_safe("auth.login.failure", nil, ...)
255:  #   magic_link_request  -> Sigra.Audit.log_safe("auth.magic_link_request", nil, ...)
257:  #   magic_link_verify   -> Sigra.Audit.log_safe("auth.magic_link_verify.success", nil, ...)
259:  #   password_reset_req  -> Sigra.Audit.log_safe("auth.password_reset_request", nil, ...)
375:        Audit.log_safe(
398:            Audit.log_safe(
422:            Audit.log_safe(
448:              Audit.log_safe(
466:              Audit.log_safe(
541:        Audit.log_safe(
602:            # Standalone write (Sigra.Audit.log_safe) because the delete +
608:            Audit.log_safe(
962:        Audit.log_safe(
1170:    Sigra.Audit.log_safe(
1274:    Sigra.Audit.log_safe(
1337:    Sigra.Audit.log_safe(
1415:    Sigra.Audit.log_safe(
1695:    Sigra.Audit.log_safe(
1716:      Sigra.Audit.log_safe(
```

Forward pointers: **Phase 44–45** own remaining `lib/sigra/*` `log_safe` sites (MFA, Account, OAuth, etc.) per ROADMAP — this inventory is **Auth + session helpers colocated in `auth.ex` only**.
