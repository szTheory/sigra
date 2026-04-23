# GA-03 — Waiver / intermediate-branch rules (**D-42-02**)

A **waiver** for skipping fresh live Google smoke on an **intermediate** branch is permitted only if **all** of the following are recorded:

1. **Link** the **last pinned live run** (date, owner, transcript pointer, build SHA).
2. **Diff since** that run: list OAuth-related dependency or code changes; if none material, state explicitly.
3. **Residual risk:** consent UX, refresh/token edge cases not covered by **`Sigra.OAuthTest`**.

**No GA tag** on a release line without fresh live smoke **or** a formal **Waived** row with vendor/policy infeasibility and compensating evidence.

For the **waiver** form fields, mirror GA-02: reason, compensating controls, residual risk, expiry_or_next_trigger, owner, date.

---

## Formal waiver table (matrix)

| **reason** | Live Google OAuth (register → login → linking / email-match) was not exercised with a real Google Cloud test client in the Phase 46 execution environment; env vars referenced by **name** only per **D-38-P04**. |
| **compensating controls** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/oauth/oauth_test.exs test/sigra/oauth/oauth_ceremony_audit_test.exs` exit 0 at SHA `3e9e58ff2ff6cbb3a2fa88a06a114fdd78bd8341` for **`Sigra.OAuthTest`** (authorize/callback contract, not live Google) and **`Sigra.OAuthCeremonyAuditTest`** in **`test/sigra/oauth/oauth_ceremony_audit_test.exs`** (**OA-01** persisted `audit_events` on successful registration + authorize paths), per **`docs/uat-ci-coverage.md`**. |
| **residual risk** | Production consent UX, refresh-token edge cases, and provider-specific failures are not exercised by mocks. |
| **expiry_or_next_trigger** | Next material OAuth integration change or before a promoted release tag if policy requires fresh live smoke. |
| **owner** | Sigra |
| **date** | 2026-04-21 |
