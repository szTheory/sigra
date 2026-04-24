# AUD-04 Inventory — Phase 45 (OAuth, ops & workers)

Continuation of the **AUD-04** audit-site inventory for OAuth orchestration, lockout / suspicious-login helpers, impersonation, and the account-deletion Oban worker. Parent slice: [`../44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md`](../44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md) (**AUD-04-001–049**). This file owns **AUD-04-050+** for **AUD-08** (hybrid **T1** / **T2** batch).

## Grep log

Path-scoped `rg` (verbatim):

```text
$ rg -n "Sigra\\.Audit\\.(log_safe|log_multi_safe|__log_internal__)|Audit\\.log_safe|Audit\\.log_multi_safe|Audit\\.__log_internal__" lib/sigra/oauth.ex lib/sigra/oauth/callback.ex lib/sigra/lockout.ex lib/sigra/suspicious_login.ex lib/sigra/impersonation.ex lib/sigra/workers/account_deletion.ex
lib/sigra/suspicious_login.ex:86:        # Uses Sigra.Audit.log_safe which no-ops when audit_schema not
lib/sigra/suspicious_login.ex:90:        Sigra.Audit.log_safe(
lib/sigra/oauth/callback.ex:155:      |> Audit.log_multi_safe(
lib/sigra/oauth/callback.ex:163:      |> Audit.log_multi_safe(
lib/sigra/oauth/callback.ex:252:      |> Audit.log_multi_safe(
lib/sigra/oauth/callback.ex:260:      |> Audit.log_multi_safe(
lib/sigra/impersonation.ex:49:            Audit.log_safe(
lib/sigra/impersonation.ex:82:    Audit.log_safe(
lib/sigra/impersonation.ex:101:      Audit.log_safe(
lib/sigra/impersonation.ex:183:    Audit.log_safe(
lib/sigra/lockout.ex:124:  manually. Uses Sigra.Audit.log_safe which skips when audit_schema
lib/sigra/lockout.ex:130:    Sigra.Audit.log_safe(
lib/sigra/oauth.ex:91:        Sigra.Audit.log_safe(
lib/sigra/oauth.ex:174:        Sigra.Audit.log_safe(
lib/sigra/oauth.ex:293:        |> Audit.log_multi_safe(
lib/sigra/oauth.ex:382:            |> Audit.log_multi_safe(
```

## Callback mutation inventory (Phase **45-02** — closed)

**AUD-04-050** (`register_oauth_user/6`) and **AUD-04-051** (`do_login_with_identity_update/7` → identity update) now append **`Audit.log_multi_safe/3`** steps to the same **`Ecto.Multi`** that performs user/identity inserts or identity updates. **`Sigra.OAuth.handle_callback/4`** no longer emits duplicate **`log_safe`** rows for **`{:ok, :registered, …}`** / **`{:ok, :logged_in, …}`** — those audits are co-fated inside **`Sigra.OAuth.Callback`**.

## Main inventory (grep sites + worker path)

| ID | Boundary (module.function) | action string | mechanism today | tier (T1/T2/T3) | REQ batch (AUD-08) | Phase | notes |
|----|------------------------------|----------------|-------------------|-----------------|-------------------|-------|-------|
| AUD-04-052 | `Sigra.SuspiciousLogin` (notify path) | `security.suspicious_login` | `log_safe` | T2 (see **EX-45-03**) | AUD-08 | 45 | No paired durable DB row in-library |
| AUD-04-053 | `Sigra.Impersonation.start/5` | `admin.impersonation.start` | `log_safe` after `Auth.create_session` | T2 | AUD-08 | 45 | **EX-45-06** — `SessionStore` boundary |
| AUD-04-054 | `Sigra.Impersonation.stop/4` | `admin.impersonation.stop` | `log_safe` after `Auth.delete_session` | T2 | AUD-08 | 45 | **EX-45-06** |
| AUD-04-055 | `Sigra.Impersonation.evaluate_timeout/4` | `admin.impersonation.timeout_expire` | `log_safe` (no DB write in-module) | T2 | AUD-08 | 45 | **EX-45-04** |
| AUD-04-056 | `Sigra.Impersonation` (`log_denied/5`) | `admin.impersonation.denied` | `log_safe` | T2 | AUD-08 | 45 | **EX-45-05** |
| AUD-04-057 | `Sigra.Account.execute_deletion/3` (+ worker caller) | `account.deletion_executed` | **`log_multi_safe`** inside same `repo.transaction` as **`Deletion.execute`** | T1 | AUD-08 | 45 | **45-04** — worker calls **`Account.execute_deletion`** only |
| AUD-04-058 | `Sigra.OAuth.authorize_url/4` | `oauth.authorize` | `log_safe` | T2 | AUD-08 | 45 | **EX-45-01** |
| AUD-04-059 | `Sigra.OAuth.Callback` + `handle_callback/4` | `oauth.callback.success` / `oauth.register_via_oauth` / `oauth.login_via_oauth` (registered + logged-in) | **`log_multi_safe`** in **`Callback`** Multi; orchestrator branch is `:ok` only | T1 | AUD-08 | 45 | **45-02** |
| AUD-04-063 | `Sigra.OAuth.handle_callback/4` | `oauth.callback.failure` | `log_safe` | T2 | AUD-08 | 45 | **EX-45-02** |
| AUD-04-064 | `Sigra.OAuth.do_link_provider/3` | `oauth.link` | **`log_multi_safe`** in `repo.transaction` after insert | T1 | AUD-08 | 45 | **45-02** |
| AUD-04-065 | `Sigra.OAuth.do_unlink_provider/3` | `oauth.unlink` | **`log_multi_safe`** in `repo.transaction` after delete | T1 | AUD-08 | 45 | **45-02** |
| AUD-04-066 | `Sigra.Auth.handle_failed_login_with_lockout/5` | `security.lockout` / `security.invalid_credentials` | **`log_multi_safe`** in `repo.transaction` when `:audit_schema` set | T1 | AUD-08 | 45 | **45-03** — `Lockout.audit_lockout/1` remains optional **`log_safe`** helper |

## Exclusions appendix

| ID | scope | rationale | compensating control | owner | reopen trigger |
|----|-------|-----------|----------------------|-------|----------------|
| EX-45-01 | `oauth.authorize` (**AUD-04-058**) | No domain persistence on authorize URL generation — read-only / telemetry boundary | Rate limits + telemetry on authorize | Sigra | Product requires durable audit before any callback |
| EX-45-02 | `oauth.callback.failure` + token exchange failures (**AUD-04-063**, pre-user resolution) | Failure before persisted user — classic **T2** hybrid | Logging + generic errors (enumeration-safe) | Sigra | REQ mandates co-fated failure row with future DB writes |
| EX-45-03 | `security.suspicious_login` (**AUD-04-052**) | May remain **T2** if SMTP / enqueue boundary prevents same-txn notify row | Rate limits + telemetry | Sigra | Notify decision persisted in DB without co-audit |
| EX-45-04 | `admin.impersonation.timeout_expire` (**AUD-04-055**) | Read-only timeout evaluation path | Session store + `Auth` session lifecycle tests | Sigra | Timeout path gains paired DB mutation in-library |
| EX-45-05 | `admin.impersonation.denied` (**AUD-04-056**) | Denied attempts — no impersonation session created | Admin audit + authorization tests | Sigra | Denial must be co-fated with security-sensitive DB row |
| EX-45-06 | `admin.impersonation.start` / `stop` (**AUD-04-053**, **AUD-04-054**) | Session persistence goes through **`SessionStore`** (`create` / `delete`); no shared **`Ecto.Multi`** hook today | Integration tests + honest **T2** until store supports txn-scoped audit | Sigra | `SessionStore` exposes transactional compose with host repo |
| EX-45-JWT-01 | JWT refresh audit (**AUD-04-048**) | **2026-04-24** — **phase 81** / **AUD-18**: audit-only **`Repo.transaction/1` + `Multi` + `log_multi_safe`** for standalone **`audit_jwt_refresh/2`**. **Phase 82** / **AUD-19**: **`Sigra.JWT.refresh/3`** co-fates **`user_tokens`** rotation + **`api.jwt_refresh`** when `:audit_schema` set (**AUD-08** closure for guided path). | **44** row **AUD-04-048**; **`test/sigra/api_token_audit_atomic_test.exs`**; **`test/sigra/jwt_refresh_audit_cofate_test.exs`** | Sigra | **82** closes **AUD-08** for **`JWT.refresh`** |
| EX-45-JWT-02 | JWT reuse audit (**AUD-04-049**) | Same progression as **EX-45-JWT-01** for **`api.jwt_refresh_reuse`** — **81** audit-only helpers; **82** co-fate on **`JWT.refresh`** reuse branch. | **44** row **AUD-04-049**; **`jwt_refresh_audit_cofate_test.exs`** | Sigra | **82** co-fate for reuse + audit |

## Priority table (phase 45 waves)

| Wave | Plan | Delivers |
|------|------|----------|
| 1 | **45-01** | **AUD-04** inventory slice (this file) + link from **44** + **CHANGELOG**. |
| 2 | **45-02** | **D-45-02** — OAuth **`log_multi_safe`/`__log_internal__`** inside **`Callback`** / **`OAuth`** transactions; remove duplicate post-txn logs. |
| 3 | **45-03** | **D-45-03** — **`Lockout`**, **`SuspiciousLogin`**, **`Impersonation`** tier alignment with **`Auth`**. |
| 4 | **45-04** | **D-45-04** — Account deletion worker + **`Account`** shared **`Repo.transact`** for **`account.deletion_executed`**. |
| 5 | **45-05** | **D-45-05** — Phase **09** C-1 docs (**09-03-SUMMARY**, **09-VERIFICATION**) + **`docs/audit-semantics.md`** cross-link. |
| 6 | **45-06** | **AUD-08** closure — atomicity tests + **`45-VALIDATION.md`** + full **`mix test`**. |
