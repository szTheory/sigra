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
- `rg -c '^\| AUD-04-' .planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` → **31**
- `rg -c '^\| AUD-04-' .planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md` → **12**

**45** inventory also documents **AUD-04-050** / **AUD-04-051** under *Callback mutation inventory* without duplicating them as extra `| AUD-04-050 |` pipe rows in that file. The **Phase 45** subsection below adds explicit **050** / **051** matrix rows so **050+** coverage stays row-complete.

Mechanical check on this document (after the tables are present):

- `rg -c '^\| AUD-04-[0-9]+' .planning/phases/09-audit-logging/09-VERIFICATION.md` must be **≥ 61** (inventory pipe sum). Current row count: **64** (19 + 31 + 14, where 14 = 12 + **050** + **051**).

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
| AUD-04-020 | **`Multi` + `log_multi_safe`** (`mfa.enroll.success` inside enrollment `Repo.transaction/1`) | tier 5 | T1 (**AUD-09**, phase **66**) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-021 | **`Multi` + `log_multi_safe`** (follow-up `Repo.transaction/1` for `insert_failed` / `mfa.enroll.failure`) | tier 5 | T1 (**AUD-09**, phase **66**) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-022 | **`log_safe`** (invalid TOTP; no DB writes) | tier 9 | T2 / **EX-44-02** (hybrid; unchanged phase **66**) | `test/sigra/mfa_audit_atomicity_test.exs`; `lib/sigra/mfa.ex` |
| AUD-04-023 | **`Multi` + `log_multi_safe`** (`verify/4` TOTP success — `Multi.update_all` + `mfa.verify.success` in one `repo.transaction/1`) | tier 3 | T1 (Multi-bound; phase 73) | `test/sigra/mfa_audit_atomicity_test.exs`; `lib/sigra/mfa.ex` ~291–310 |
| AUD-04-024 | **`Multi` + `log_multi_safe`** (`verify/4` wrong TOTP — `Lockout.increment` + `mfa.verify.failure`) | tier 5 | T1 (Multi-bound; phase 73) | `test/sigra/mfa_audit_atomicity_test.exs`; `lib/sigra/mfa.ex` ~325–341 |
| AUD-04-025 | **`Multi` + `log_multi_safe`** (`mfa.lockout` appended via `Multi.merge` when threshold met) | tier 4 | T1 (Multi-bound; phase 73) | `test/sigra/mfa_audit_atomicity_test.exs`; `lib/sigra/mfa.ex` ~342–360 |
| AUD-04-026 | **`Multi` + `log_multi_safe`** (`verify_backup/4` success path) | tier 3 | T1 (Multi-bound; closed in `lib/`; phase 73 verification receipts) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-027 | **`Multi` + `log_multi_safe`** (`mfa.backup_code_used` paired with **026**) | tier 3 | T1 (Multi-bound; closed in `lib/`; phase 73 verification receipts) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-067 | **`Multi` + `log_multi_safe`** | tier 5 | T1 (**AUD-01**, phase **61**; phase 73 verification receipts) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-028 | **`Multi` + `log_multi_safe`** (`cleanup_mfa/6` — `mfa.disable` on same `Multi` as deletes + trust revoke) | tier 6 | T1 (Multi-bound; phase 73) | `test/sigra/mfa_audit_atomicity_test.exs`; `lib/sigra/mfa.ex` ~1007–1033 |
| AUD-04-029 | **`Multi` + `log_multi_safe`** (`disable!/4` admin path; same pattern as **028**) | tier 6 | T1 (Multi-bound; phase 73) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-030 | **`Multi` + `log_multi_safe`** (`regenerate_backup_codes/4` success — replace + `mfa.backup_codes_regenerate` in one txn) | tier 5 | T1 (Multi-bound; phase 73) | `test/sigra/mfa_audit_atomicity_test.exs` |
| AUD-04-031 | **`Multi` + `log_multi_safe`** (`regenerate_backup_codes/4` wrong TOTP — `mfa.verify.failure`) | tier 5 | T1 (Multi-bound; phase 73) | `lib/sigra/mfa.ex` ~741–757 |
| AUD-04-032 | **`Multi` + `log_multi_safe`** (regenerate path `mfa.lockout` via `Multi.merge`) | tier 4 | T1 (Multi-bound; phase 73) | `lib/sigra/mfa.ex` ~758–776 |
| AUD-04-033 | **`Repo.transaction/1`** on **`Multi` + `log_multi_safe`** (`audit_backup_codes_regenerate/3`; dedicated `:audit_mfa_backup_codes_regenerate_adhoc` step) | tier 8 | T1 (phase **77** / **AUD-13**) | `test/sigra/mfa_audit_atomicity_test.exs`; `lib/sigra/mfa.ex` |
| AUD-04-034 | **`Repo.transaction/1`** on **`Multi` + `log_multi_safe`** (`audit_trust_browser/2`; dedicated `:audit_mfa_trust_browser_adhoc` step) | tier 8 | T1 (phase **77** / **AUD-13**) | `test/sigra/mfa_audit_atomicity_test.exs`; `lib/sigra/mfa.ex` |
| AUD-04-035 | **`Multi` + `log_multi_safe`** (`request_email_change/4` — same `Repo.transaction/1` as domain `Multi.run`) | tier 5 | T1 (phase **78** / **AUD-14**) | `test/sigra/account_audit_atomicity_test.exs`; `lib/sigra/account.ex` |
| AUD-04-036 | **`Multi` + `log_multi_safe`** (`confirm_email_change/3`) | tier 4 | T1 (phase **78** / **AUD-14**) | `test/sigra/account_audit_atomicity_test.exs`; `lib/sigra/account.ex` |
| AUD-04-037 | **`Multi` + `log_multi_safe`** (`cancel_email_change/3`) | tier 5 | T1 (phase **78** / **AUD-14**) | `test/sigra/account_audit_atomicity_test.exs`; `lib/sigra/account.ex` |
| AUD-04-038 | **`Multi` + `log_multi_safe`** (`change_password/5`) | tier 3 | T1 (phase **78** / **AUD-14**) | `test/sigra/account_audit_atomicity_test.exs`; `lib/sigra/account.ex` |
| AUD-04-039 | **`Multi` + `log_multi_safe`** (`set_password/4`) | tier 3 | T1 (phase **78** / **AUD-14**) | `test/sigra/account_audit_atomicity_test.exs`; `lib/sigra/account.ex` |
| AUD-04-040 | **`Multi` + `log_multi_safe`** (`schedule_deletion/3`) | tier 5 | T1 (phase **78** / **AUD-14**) | `lib/sigra/account.ex` |
| AUD-04-041 | **`Multi` + `log_multi_safe`** (`cancel_deletion/3`) | tier 5 | T1 (phase **78** / **AUD-14**) | `lib/sigra/account.ex` |
| AUD-04-042 | **`Multi` + `log_multi_safe`** (`execute_deletion/3` — `deletion_execute` + `deletion_executed` steps) | tier 2 | T1 (phase **78** / **AUD-14**) | `test/sigra/account_audit_atomicity_test.exs`; `lib/sigra/account.ex` |
| AUD-04-043 | **`Multi` + `log_multi_safe`** (`clear_password_change_requirement/3` — forced password-change clear + `account.password_change`) | tier 7 | T1 (**AUD-17**, phase **80**); **`audit_forced_password_change/2`** deprecated | `test/sigra/account_audit_atomicity_test.exs`; `lib/sigra/account.ex` |
| AUD-04-044 | **`Repo.transaction/1`** on audit-only **`Multi` + `log_multi_safe`** (`verify/2` invalid token) | tier 9 | T1 (phase **79** / **AUD-16**) | `test/sigra/api_token_audit_atomic_test.exs`; `lib/sigra/api_token.ex` |
| AUD-04-045 | same (`verify/2` revoked) | tier 9 | T1 (phase **79** / **AUD-16**) | same |
| AUD-04-046 | same (`verify/2` expired) | tier 9 | T1 (phase **79** / **AUD-16**) | same |
| AUD-04-047 | **`Multi` + `Audit.log_multi_safe`** (`revoke/2` — `config.repo.transaction/1`) | tier 4 | T1 (phase **78** / **AUD-14**) | `test/sigra/api_token_audit_atomic_test.exs`; `lib/sigra/api_token.ex` |
| AUD-04-048 | **`Repo.transaction/1` + `Multi` + `log_multi_safe`** (`audit_jwt_refresh/2` — audit-only txn) | tier 8 | T1 (phase **81**; audit-only **Multi**). Footnote: **AUD-08** JWT refresh-token **persistence** co-fate with audit remains **out of scope**. | `test/sigra/api_token_audit_atomic_test.exs`; `lib/sigra/api_token.ex` (**`audit_jwt_refresh/2`**, **`commit_api_token_jwt_audit/3`**) |
| AUD-04-049 | **`Repo.transaction/1` + `Multi` + `log_multi_safe`** (`audit_jwt_refresh_reuse/2` — audit-only txn) | tier 8 | T1 (phase **81**; audit-only **Multi**). **AUD-08** persistence deferral unchanged. | same file (**`audit_jwt_refresh_reuse/2`**) |

**Phase 80 (2026-04-24):** **AUD-17** — **`Sigra.Account.clear_password_change_requirement/3`** co-fates clearing **`must_change_password`** with **`account.password_change`** (`metadata: %{forced: true}`) via **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`**; **AUD-04-043** **T1**; **EX-44-05** satisfied; **`audit_forced_password_change/2`** **`@deprecated`**.

**Phase 81 (2026-04-24):** **AUD-18** — **`Sigra.APIToken.audit_jwt_refresh/2`** / **`audit_jwt_refresh_reuse/2`** (matrix rows **048** / **049**) use **`Repo.transaction/1`** + **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** when `:audit_schema` is set; **T1** for audit-row durability inside the audit transaction only — **AUD-08** (JWT refresh-token persistence co-fate) remains **deferred**. Evidence: **`test/sigra/api_token_audit_atomic_test.exs`**.

**Phase 79 (2026-04-24):** **AUD-16** — **`Sigra.APIToken.verify/2`** **`api.token_verify.failure`** for invalid / revoked / expired branches uses **`Repo.transaction/1`** + **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** when `:audit_schema` is set; **044–046** **T1**; **EX-44-01** verify-failure slice retired (appendix row retained for history).

**Phase 78 (2026-04-24):** **AUD-14** — **AUD-04-035..042** (`Sigra.Account` email/password/deletion) and **047** (`Sigra.APIToken.revoke/2`) aligned to **`Multi` + `log_multi_safe`** in **`lib/`**; **44** inventory + this matrix updated from legacy “target **Multi**” language. **044–046** were **`log_safe`** (**EX-44-01**) until **phase 79**. **043** was still **`log_safe`** at the **phase 78** documentation cut (**EX-44-05** open); **phase 80** closed the paired-write path (**AUD-17**).

**Phase 61 (2026-04-23):** **`verify_backup/4`** wrong-code / invalid-backup attempts emit **`mfa.verify.failure`** via **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** (and **`mfa.lockout`** in the same transaction when the lockout threshold is reached), matching **`verify/4`** failure semantics. Matrix row **`AUD-04-067`**; tests in **`test/sigra/mfa_audit_atomicity_test.exs`**.

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
