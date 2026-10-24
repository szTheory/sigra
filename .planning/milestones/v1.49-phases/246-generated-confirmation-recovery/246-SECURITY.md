---
phase: "246"
slug: "generated-confirmation-recovery"
status: verified
threats_open: 0
asvs_level: 1
created: "2026-10-07"
---

# Phase 246 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| Browser -> generated ConfirmationLive | Public routes accept untrusted query tokens and form events; server scope is assigned by the authenticated session. | Confirmation token, six-digit code, event parameters, current account scope |
| ConfirmationLive -> Sigra.Auth -> Repo | The context verifies credentials and binds code verification to the server-selected account before persisted mutation. | Verified token/code result, account id, confirmation state, consumed credentials |
| Mail delivery -> browser | The account owner receives a one-time link or short code and chooses whether to confirm. | Signed confirmation link or six-digit code |
| CI runner -> evidence receipt | The receipt must bind conclusions to the workflow run and exact tested source SHA. | Commit SHA, job conclusions, run and job URLs |

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-246-01 | Tampering | `ConfirmationLive.handle_params/3` | high | mitigate | GET stores display state only; the fresh-host probe checks persisted state remains unconfirmed until explicit submit. | closed |
| T-246-02 | Spoofing | `ConfirmationLive.confirm_link/3` | high | mitigate | HMAC token selects its owner; link confirmation does not create a login or session, and the probe checks owner state and visitor session. | closed |
| T-246-03 | Denial of service | Anonymous code/resend events | medium | mitigate | Missing current scope follows localized sign-in guidance without dereference or delivery attempt. | closed |
| T-246-04 | Elevation of privilege | `Sigra.Auth.verify_confirmation_code/3` | high | mitigate | Account-scoped lookup binds the credential before mutation; the A-code/B-account regression checks no state changes. | closed |
| T-246-05 | Tampering | Confirmation code submission | high | mitigate | Server accepts only six ASCII digits and narrowly normalizes U+0020 spaces; client account identifiers are ignored. | closed |
| T-246-06 | Denial of service | Confirmation code rate limiter | medium | mitigate | Existing per-account limiter key and denial handling remain covered by focused auth tests. | closed |
| T-246-07 | Repudiation | Generated confirmation feedback | medium | mitigate | Localized success and validation outcomes use status/alert semantics; retry state is covered by generated-host probes and template contracts. | closed |
| T-246-08 | Tampering | Generated-host browser code input | high | mitigate | Chromium submits the literal email code with spaces, observes invalid feedback, retries, and observes success. | closed |
| T-246-09 | Repudiation | Required CI result | medium | mitigate | Static job-edge contract plus run [37676348766](https://github.com/szTheory/sigra/actions/runs/37676348766) bind required conclusions to exact source `90ec16f72a71d33224c0816ad77762e2e7262c76`; missing results remain failures. | closed |
| T-246-SC | Tampering | Third-party installation | high | mitigate | The phase adds no package-manager installation step and reuses the repository's pinned dependencies and existing CI setup. | closed |

*Status: `closed` means the planned mitigation was verified or the residual risk is documented as accepted.*

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| R-246-01 | D-06 (anonymous confirmation) | Explicit submit prevents a scanner GET from confirming an address, but an email owner can still confirm a pre-stuffed account. Preventing pre-hijacking would change the locked anonymous-confirmation contract and requires a separate product/security decision. | Phase 246 context decision, carried by maintainers | 2026-10-06 |

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-10-07 | 10 | 10 | 0 | Codex orchestration (ASVS L1 plan-register verification) |

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-10-07

## Security Audit 2026-10-07

| Metric | Count |
|---|---|
| Threats found | 10 |
| Closed | 10 |
| Open | 0 |
