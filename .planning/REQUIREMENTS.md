# Requirements: Sigra — v1.19 JWT persistence + audit co-fate & MFA enrollment failure

**Defined:** 2026-04-24  
**Milestone:** v1.19 — bounded **SEED-002** (**AUD-19** + **AUD-20**)

## v1.19 Requirements

### JWT refresh — persistence + audit co-fate (closes v1.18 “AUD-08 persistence” footnote)

- [ ] **AUD-19-01** — On successful JWT refresh, **`Sigra.JWT.RefreshToken.rotate/3`** persistence work (supersede old **`user_tokens`** row + insert new refresh token) and **`api.jwt_refresh`** emission occur in **one** `Repo.transaction` (or equivalent documented single boundary) when `:audit_schema` is set, so the host never observes persisted rotation without a matching audit row, and audit failure rolls back rotation.
- [ ] **AUD-19-02** — On **`:reuse_detected`**, family-wide revocation persistence and **`api.jwt_refresh_reuse`** audit share the same transactional discipline when audit is on (aligned to **AUD-19-01** semantics).
- [ ] **AUD-19-03** — Automated tests prove co-fate: happy path, audit-off, and fault injection (audit insert failure → no partial persistence / consistent `{:error, _}` or documented contract). Prefer extending **`test/sigra/api_token_audit_atomic_test.exs`** and/or focused JWT integration tests.
- [ ] **AUD-19-04** — Planning truth: **`.planning/phases/09-audit-logging/09-VERIFICATION.md`** rows **048–049** footnotes, **`.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md`**, **`.planning/phases/45-oauth-ops-c1-signoff/45-AUD-04-INVENTORY.md`** (JWT appendix as needed), **`.planning/phases/09-audit-logging/09-03-SUMMARY.md`**, **`CHANGELOG.md` [Unreleased]**; **`.planning/phases/82-jwt-refresh-persistence-audit-cofate/82-VERIFICATION.md`** records merge gate.

### MFA — AUD-04-022 / EX-44-02

- [ ] **AUD-20-01** — **`Sigra.MFA.confirm_enrollment/5`** invalid-TOTP (**pre-persistence**) path upgraded from standalone **`log_safe/3`** to **`Repo.transaction/1` + `Multi` + `log_multi_safe`** **or** explicit milestone waiver with updated **EX-44-02** rationale (must be captured in **83** discuss/plan if waived).
- [ ] **AUD-20-02** — **`test/sigra/mfa_audit_atomicity_test.exs`** covers the **022** mechanism + rollback / audit-off parity with prior MFA atomicity phases.
- [ ] **AUD-20-03** — **44** inventory row **022**, **09-VERIFICATION** C-1 **022**, **09-03-SUMMARY**, **`CHANGELOG` [Unreleased]**; **`.planning/phases/83-mfa-confirm-enrollment-022/83-VERIFICATION.md`** merge gate.

## Future requirements

- **Phase 45 T2** promotions (**052–056**, **058**, **063**) — only if a later milestone selects them with owner + reopen trigger (**EX-45-***).
- **SEED-001** human GA matrix — launch lane milestone, not **v1.19**.

## Out of scope

- Re-auditing **Phase 45** merge gate **`mix ci.audit_45`** beyond regression needed for **JWT** path edits.
- **`sigra_lockspire`** / ADR **001** glue package.
- **999.x** Nyquist archaeology.

## Traceability

| REQ-ID    | Phase |
|-----------|-------|
| AUD-19-01 | 82    |
| AUD-19-02 | 82    |
| AUD-19-03 | 82    |
| AUD-19-04 | 82    |
| AUD-20-01 | 83    |
| AUD-20-02 | 83    |
| AUD-20-03 | 83    |
