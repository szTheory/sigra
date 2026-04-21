# Phase 9 — Audit logging verification (C-1)

**Scope:** Claims in this document apply to **database audit row co-fate** (same `Repo.transaction` / `Ecto.Multi` as domain writes). They do **not** assert co-fate for email delivery, external IdPs, or Oban queue semantics unless explicitly stated.

Normative vocabulary: [`docs/audit-semantics.md`](../../../docs/audit-semantics.md).

## C-1

### Scope

- **In scope:** `Sigra.Audit.log_multi_safe/3`, `__log_internal__/3`, and intentional **`log_safe/3`** retention (**T2**) with **`EX-*`** IDs from **AUD-04** inventories (phases **43–45**).
- **Out of scope (honest):** Oban retry counters, session cookie issuance without a DB session row, and **`SessionStore`** implementations that do not yet expose transactional compose with the audit repo.

### Matrix (representative; full detail in inventories)

| AUD-04-id | mechanism | tier | test evidence | EX- id |
|-----------|-----------|------|----------------|--------|
| AUD-04-001–019 (Auth) | Mostly **`log_multi_safe`** post–43/44 refactors | T1 where Multi | `test/sigra/auth/**/*audit*atomicity*.exs`, `test/sigra/auth_test.exs` | See **43-AUD-04** exclusions |
| AUD-04-020–049 (MFA / Account / API) | **`log_multi_safe`** on hot paths | T1 / T2 | `test/sigra/mfa_audit_atomicity_test.exs`, `test/sigra/account_audit_atomicity_test.exs`, `test/sigra/api_token_audit_atomic_test.exs` | **EX-44-*** in **44-AUD-04** |
| AUD-04-050–051 (OAuth callback) | **`log_multi_safe`** inside **`Callback`** Multi | T1 | `test/sigra/oauth/oauth_audit_atomicity_test.exs` | — |
| AUD-04-064–065 (link/unlink) | **`log_multi_safe`** in `repo.transaction` | T1 | `test/sigra/oauth/oauth_test.exs` | — |
| AUD-04-057 (deletion executed) | **`log_multi_safe`** in **`Sigra.Account.execute_deletion/3`** | T1 | `test/sigra/account/deletion_test.exs`, `test/sigra/workers/account_deletion_test.exs` | — |
| AUD-04-066 (lockout on failed login) | **`log_multi_safe`** in **`Auth.handle_failed_login_with_lockout/5`** | T1 | `test/sigra/auth/login_and_lockout_audit_atomicity_test.exs` | — |
| AUD-04-052 (suspicious login) | **`log_safe`** | T2 | `test/sigra/suspicious_login_test.exs` | **EX-45-03** |
| AUD-04-053–054 (impersonation start/stop) | **`log_safe`** after session store | T2 | `test/sigra/impersonation_test.exs` | **EX-45-06** |
| AUD-04-058–063 (OAuth authorize / callback failure) | **`log_safe`** | T2 | `test/sigra/oauth/oauth_test.exs` | **EX-45-01**, **EX-45-02** |

Additional rows (**AUD-04-055**, **056**, JWT deferrals, etc.) remain documented in [`.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md`](../45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md) and prior inventories — extend this matrix when promoting a boundary from **T2 → T1**.

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
