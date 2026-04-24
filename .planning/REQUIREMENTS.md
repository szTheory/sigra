# Requirements — Milestone v1.17

**Milestone:** v1.17 — Forced password change audit atomicity (bounded **SEED-002** / **AUD-04-043**)

**Seed context:** [`.planning/seeds/SEED-002-phase-9-log-safe-atomicity-followup.md`](seeds/SEED-002-phase-9-log-safe-atomicity-followup.md) — subsystem test conversion + **`log_safe`** → **`Multi` + `log_multi_safe`** where **C-1** demands **T1**.

**Inventory:** [`.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md`](phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md) — row **AUD-04-043** (`Sigra.Account.audit_forced_password_change/2`, `account.password_change`, **`log_safe`**). Appendix **EX-44-05** reopens when forced-change flow gains paired **`Ecto`** writes in-library — satisfied by **`PasswordChange.clear_force_change/2`**.

---

## Audit atomicity — Account / forced password change

- [ ] **AUD-17-01** — When audit is enabled, clearing **`must_change_password`** via the in-library **`Sigra.Account.PasswordChange.clear_force_change/2`** path co-fates the **`users`** (or host user schema) update with an **`account.password_change`** audit row carrying **`metadata: %{forced: true}`**, using **`Repo.transaction/1`** + **`Ecto.Multi`** + **`Sigra.Audit.log_multi_safe/3`** (same rollback semantics as other **Phase 78** account **`Multi`** paths).
- [ ] **AUD-17-02** — **`Sigra.Account.audit_forced_password_change/2`** no longer performs a standalone post-commit **`log_safe/3`** for the forced completion outcome covered by **AUD-17-01** (remove, shim to the **`Multi`** path only, or hard-deprecate with compile-time or runtime guard consistent with semver policy).
- [ ] **AUD-17-03** — **`test/sigra/account_audit_atomicity_test.exs`** covers the forced-clear happy path and at least one audit **`CHECK`** / fault-injection rollback case proving the audit row does not outlive a rolled-back user update (pattern parity with existing **`change_password`** coverage).
- [ ] **AUD-17-04** — Planning truth: update **44-AUD-04-INVENTORY** (**AUD-04-043** mechanism + phase column), **09-VERIFICATION.md** C-1 row **043** (**T1** + evidence pointer), **09-03-SUMMARY.md** (phase **80** / **AUD-17** note), and **`CHANGELOG.md` [Unreleased]** per maintainer cadence.

---

## Future requirements (deferred)

- **AUD-04-048** / **AUD-04-049** — JWT refresh / reuse audits (**EX-45-JWT-01** / **02**) — remain deferred until JWT persistence work is scheduled.
- Further **SEED-002** rows in **45-AUD-04-INVENTORY** marked **T2** with **EX-45-*** compensating controls — promote only when triggers in **SEED-002** fire.

---

## Out of scope

- **SEED-001** human UAT matrix — launch-adjacent; not part of **v1.17**.
- **`sigra_lockspire`** / **ADR 001** glue package — unchanged deferral from **PROJECT.md**.
- OAuth authorize / callback failure / impersonation **T2** families — not in **v1.17** unless explicitly pulled in (they remain **45** inventory scope for a later milestone).

---

## Traceability

| REQ-ID    | Phase |
|-----------|-------|
| AUD-17-01 | 80    |
| AUD-17-02 | 80    |
| AUD-17-03 | 80    |
| AUD-17-04 | 80    |
