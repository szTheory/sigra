# Phase 9 — Audit logging verification (C-1)

**Scope:** Claims in this document apply to **database audit row co-fate** (same `Repo.transaction` / `Ecto.Multi` as domain writes). They do **not** assert co-fate for email delivery, external IdPs, or Oban queue semantics unless explicitly stated.

Normative vocabulary: [`docs/audit-semantics.md`](../../../docs/audit-semantics.md).

## C-1

### Scope

- **In scope:** `Sigra.Audit.log_multi_safe/3`, `__log_internal__/3`, and intentional **`log_safe/3`** retention (**T2**) with **`EX-*`** IDs from **AUD-04** inventories (phases **43–45**).
- **Out of scope (honest):** Oban retry counters, session cookie issuance without a DB session row, and **`SessionStore`** implementations that do not yet expose transactional compose with the audit repo.

### C-1 completeness preamble

Mechanical inventory totals (pipe rows whose first cell is an **AUD-04-** id):

- `rg -c '^\| AUD-04-' .planning/phases/43-audit-inventory-auth-atomic-batch/43-AUD-04-INVENTORY.md` → **19**
- `rg -c '^\| AUD-04-' .planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` → **30**
- `rg -c '^\| AUD-04-' .planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md` → **12**

**45** inventory also documents **AUD-04-050** / **AUD-04-051** under *Callback mutation inventory* without duplicating them as extra `| AUD-04-050 |` pipe rows in that file. The **Phase 45** subsection below adds explicit **050** / **051** matrix rows so **050+** coverage stays row-complete.

Mechanical check on this document (after the tables are present):

- `rg -c '^\| AUD-04-[0-9]+' .planning/phases/09-audit-logging/09-VERIFICATION.md` must be **≥ 61** (inventory pipe sum). Current row count: **63** (19 + 30 + 14, where 14 = 12 + **050** + **051**).

**Intentional delta / excluded populations:** none (empty); **EX-*** compensating controls remain authoritative in the phase inventory files.

### C-1 — Phase 43 inventory

| AUD-04-id | mechanism | tier | verdict | evidence pointer |
|-----------|-----------|------|---------|-------------------|
| AUD-04-001 | **Multi (`log_multi_safe`)** when `:audit_schema` set | tier 6 | T1 / closed (phase 43) | `test/sigra/auth/register_audit_atomicity_test.exs` |
| AUD-04-002 | `log_safe` | tier 6 | Tracked (phase 43) | `test/sigra/auth/register_audit_atomicity_test.exs` |
| AUD-04-003 | `log_safe` | tier 4 | Tracked (phase 43) | `test/sigra/auth/login_and_lockout_audit_atomicity_test.exs` |
| AUD-04-004 | **Multi (`log_multi_safe`)** when `:audit_schema` + confirmed; else `log_safe` (unconfirmed pre-check path) | tier 3 | T1 / closed (phase 43) | `test/sigra/auth/login_and_lockout_audit_atomicity_test.exs` |
| AUD-04-005 | **Multi (`log_multi_safe`)** when `:audit_schema` + confirmed; else `log_safe` | tier 1 | T1 / closed (phase 43) | `test/sigra/auth/login_and_lockout_audit_atomicity_test.exs` |
| AUD-04-006 | `log_safe` | tier 9 | Tracked (phase 43) | `test/sigra/auth/login_and_lockout_audit_atomicity_test.exs` |
| AUD-04-007 | `log_safe` | tier 9 | Tracked (phase 43) | `test/sigra/auth/login_and_lockout_audit_atomicity_test.exs` |
| AUD-04-008 | **Multi (`log_multi_safe`)** when `:audit_schema` | tier 5 | T1 / closed (phase 43) | `test/sigra/auth/magic_link_and_reset_request_audit_atomicity_test.exs` |
| AUD-04-009 | **Multi (`log_multi_safe`)** when `:audit_schema` | tier 5 | T1 / closed (phase 43) | `test/sigra/auth/magic_link_and_reset_request_audit_atomicity_test.exs` |
| AUD-04-010 | **Multi (`log_multi_safe`)** when `:audit_schema` | tier 7 | T1 / closed (phase 43) | `test/sigra/auth/magic_link_and_reset_request_audit_atomicity_test.exs` |
| AUD-04-011 | **Multi (`__log_internal__`)** | tier — | T1 / closed (phase 43) | `test/sigra/auth/magic_link_and_reset_request_audit_atomicity_test.exs` |
| AUD-04-012 | **Multi (`__log_internal__`)** | tier — | T1 / closed (phase 43) | `test/sigra/auth/magic_link_and_reset_request_audit_atomicity_test.exs` |
| AUD-04-013 | **Multi (`__log_internal__`)** | tier — | T1 / closed (phase 43) | `test/sigra/auth/magic_link_and_reset_request_audit_atomicity_test.exs` |
| AUD-04-014 | `log_safe` | tier 3 | T2 hybrid (documented) | `test/sigra/auth_test.exs` (`session.create`); `43-VERIFICATION.md` |
| AUD-04-015 | `log_safe` | tier 8 | Deferred (session store batch) | `43-VERIFICATION.md` merge gate + `test/sigra/auth_test.exs` |
| AUD-04-016 | `log_safe` | tier 2 | Deferred (session store batch) | `43-VERIFICATION.md` merge gate + `test/sigra/auth_test.exs` |
| AUD-04-017 | `log_safe` | tier 8 | Deferred (session store batch) | `43-VERIFICATION.md` merge gate + `test/sigra/auth_test.exs` |
| AUD-04-018 | `log_safe` | tier 9 | T2 hybrid (documented) | `test/sigra/auth/login_and_lockout_audit_atomicity_test.exs` |
| AUD-04-019 | `log_safe` | tier 4 | Tracked (phase 43) | `test/sigra/auth/login_and_lockout_audit_atomicity_test.exs` |

### C-1 — Phase 44 inventory

| AUD-04-id | mechanism | tier | verdict | evidence pointer |
|-----------|-----------|------|---------|-------------------|
| AUD-04-020 | `log_safe` (post `Repo.transaction`) | tier 6 | T2 / target Multi (phase 44 closure) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-021 | `log_safe` (after failed credential insert) | tier 7 | T2 / target Multi (phase 44 closure) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-022 | `log_safe` (invalid TOTP before DB) | tier 9 | T2 / target Multi (phase 44 closure) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-023 | `log_safe` (after `update_all` + lockout reset) | tier 3 | T2 / target Multi (phase 44 closure) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-024 | `log_safe` (after `Lockout.increment`) | tier 5 | T2 / target Multi (phase 44 closure) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-025 | `log_safe` (threshold reached) | tier 4 | T2 / target Multi (phase 44 closure) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-026 | `log_safe` | tier 3 | T2 / target Multi (phase 44 closure) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-027 | `log_safe` | tier 3 | T2 / target Multi (phase 44 closure) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-028 | `log_safe` (after `cleanup_mfa/5`) | tier 6 | T2 / target Multi (phase 44 closure) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-029 | `log_safe` (after `cleanup_mfa/5`) | tier 6 | T2 / target Multi (phase 44 closure) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-030 | **Multi (`log_multi_safe`)** | tier 5 | T1 (Multi-bound) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-031 | `log_safe` | tier 5 | T2 / target Multi (phase 44 closure) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-032 | `log_safe` | tier 4 | T2 / target Multi (phase 44 closure) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-033 | `log_safe` | tier 8 | T2 / target Multi (phase 44 closure) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-034 | `log_safe` | tier 8 | T2 / target Multi (phase 44 closure) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-035 | `log_safe` (after `{:ok, _}`) | tier 5 | T2 / target Multi (phase 44 closure) | `test/sigra/account_audit_atomicity_test.exs` |
| AUD-04-036 | `log_safe` (after `{:ok, _}`) | tier 4 | T2 / target Multi (phase 44 closure) | `test/sigra/account_audit_atomicity_test.exs` |
| AUD-04-037 | `log_safe` (after `{:ok, _}`) | tier 5 | T2 / target Multi (phase 44 closure) | `test/sigra/account_audit_atomicity_test.exs` |
| AUD-04-038 | `log_safe` (after `{:ok, _}`) | tier 3 | T2 / target Multi (phase 44 closure) | `test/sigra/account_audit_atomicity_test.exs` |
| AUD-04-039 | `log_safe` (after `{:ok, _}`) | tier 3 | T2 / target Multi (phase 44 closure) | `test/sigra/account_audit_atomicity_test.exs` |
| AUD-04-040 | `log_safe` (after `{:ok, _}`) | tier 5 | T2 / target Multi (phase 44 closure) | `test/sigra/account_audit_atomicity_test.exs` |
| AUD-04-041 | `log_safe` (after `{:ok, _}`) | tier 5 | T2 / target Multi (phase 44 closure) | `test/sigra/account_audit_atomicity_test.exs` |
| AUD-04-042 | `log_safe` (**before** `Deletion.execute`) | tier 2 | T2 / target Multi (phase 44 closure) | `test/sigra/account_audit_atomicity_test.exs` |
| AUD-04-043 | `log_safe` | tier 7 | T2 / target Multi (phase 44 closure) | `test/sigra/account_audit_atomicity_test.exs` |
| AUD-04-044 | `log_safe` | tier 9 | T2 / target Multi (phase 44 closure) | `test/sigra/api_token_audit_atomic_test.exs` |
| AUD-04-045 | `log_safe` | tier 9 | T2 / target Multi (phase 44 closure) | `test/sigra/api_token_audit_atomic_test.exs` |
| AUD-04-046 | `log_safe` | tier 9 | T2 / target Multi (phase 44 closure) | `test/sigra/api_token_audit_atomic_test.exs` |
| AUD-04-047 | `log_safe` (after `repo.update`) | tier 4 | T2 / target Multi (phase 44 closure) | `test/sigra/api_token_audit_atomic_test.exs` |
| AUD-04-048 | `log_safe` | tier 8 | Deferred to phase 45 / AUD-08 | `45-AUD-04-INVENTORY.md` rows **AUD-04-048**/**049** + `44-VERIFICATION.md` |
| AUD-04-049 | `log_safe` | tier 8 | Deferred to phase 45 / AUD-08 | `45-AUD-04-INVENTORY.md` rows **AUD-04-048**/**049** + `44-VERIFICATION.md` |

### C-1 — Phase 45 inventory

| AUD-04-id | mechanism | tier | verdict | evidence pointer |
|-----------|-----------|------|---------|-------------------|
| AUD-04-050 | `Callback` / `register_oauth_user/6` | T1 | T1 (AUD-08) | `test/sigra/oauth/oauth_audit_atomicity_test.exs` |
| AUD-04-051 | `Callback` / `do_login_with_identity_update/7` | T1 | T1 (AUD-08) | `test/sigra/oauth/oauth_audit_atomicity_test.exs` |
| AUD-04-052 | `log_safe` | T2 (see **EX-45-03**) | T2 (EX-45-03) | `test/sigra/suspicious_login_test.exs` |
| AUD-04-053 | `log_safe` after `Auth.create_session` | T2 | T2 (EX-45-06) | `test/sigra/impersonation_test.exs` |
| AUD-04-054 | `log_safe` after `Auth.delete_session` | T2 | T2 (EX-45-06) | `test/sigra/impersonation_test.exs` |
| AUD-04-055 | `log_safe` (no DB write in-module) | T2 | T2 (EX-45-04) | `test/sigra/impersonation_test.exs` |
| AUD-04-056 | `log_safe` | T2 | T2 (EX-45-05) | `test/sigra/impersonation_test.exs` |
| AUD-04-057 | **`log_multi_safe`** inside same `repo.transaction` as **`Deletion.execute`** | T1 | T1 (AUD-08) | `test/sigra/account/deletion_test.exs` + `test/sigra/workers/account_deletion_test.exs` |
| AUD-04-058 | `log_safe` | T2 | T2 (**EX-45-01**) | `test/sigra/oauth/oauth_audit_atomicity_test.exs` / `test/sigra/oauth/oauth_test.exs` |
| AUD-04-059 | **`log_multi_safe`** in **`Callback`** Multi; orchestrator branch is `:ok` only | T1 | T1 (AUD-08) | `test/sigra/oauth/oauth_audit_atomicity_test.exs` / `test/sigra/oauth/oauth_test.exs` |
| AUD-04-063 | `log_safe` | T2 | T2 (**EX-45-02**) | `test/sigra/oauth/oauth_audit_atomicity_test.exs` / `test/sigra/oauth/oauth_test.exs` |
| AUD-04-064 | **`log_multi_safe`** in `repo.transaction` after insert | T1 | T1 (AUD-08) | `test/sigra/oauth/oauth_audit_atomicity_test.exs` / `test/sigra/oauth/oauth_test.exs` |
| AUD-04-065 | **`log_multi_safe`** in `repo.transaction` after delete | T1 | T1 (AUD-08) | `test/sigra/oauth/oauth_audit_atomicity_test.exs` / `test/sigra/oauth/oauth_test.exs` |
| AUD-04-066 | **`log_multi_safe`** in `repo.transaction` when `:audit_schema` set | T1 | T1 (AUD-08) | `test/sigra/auth/login_and_lockout_audit_atomicity_test.exs` + `test/sigra/lockout_test.exs` |

### Intentional hybrid (T1 vs T2)

- **T1:** If the audit insert throws or metadata validation fails, the **entire** transaction (including domain effects) must roll back — enforced by **`log_multi_safe`** steps on the same **`Multi`** / transaction fun.
- **T2 (`log_safe`):** Used where there is **no** paired durable domain mutation in the same SQL transaction, or where **`EX-*`** documents a deliberate boundary (e.g. **`oauth.authorize`**, impersonation **`SessionStore`** gap). Failure to write audit must **not** imply a domain rollback for these rows.

### Sign-off rule

Every remaining **`log_safe`** call site in **AUD-04** slices is either:

1. Converted to **T1** (`log_multi_safe` / `__log_internal__` in the same transaction as the domain write), or  
2. Listed as **T2** with an **`EX-*`** row (owner + reopen trigger) in the phase inventory.

### Oban / session store (non-co-fate)

- **Oban:** Job success/failure bookkeeping (`attempt`, `discarded`, etc.) is **not** the same transaction as domain **`audit_events`** inserts unless explicitly designed — do not infer forensic co-fate from job state alone.
- **Session store:** Unless the store participates in a shared **`Repo.transaction`** with audit (today: generic **`SessionStore`** behaviour), **`session.create` / `session.delete`** audits may follow store success — see **EX-45-06**.
