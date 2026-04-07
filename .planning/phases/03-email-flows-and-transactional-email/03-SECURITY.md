---
phase: 03
slug: email-flows-and-transactional-email
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-07
---

# Phase 03 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| App -> Oban Jobs Table | Email delivery args stored in DB | user_id, email_type, token (no email body) |
| App -> SMTP/Mailer | Email content sent to delivery provider | User email address, confirmation URLs, tokens |
| Browser -> App | Confirmation/reset form submissions | CSRF tokens, confirmation codes, passwords |
| App -> DB | Token storage and lookup | HMAC-signed tokens, SHA-256 hashes |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-3-01 | Tampering | Confirmation token | mitigate | Token deleted in Multi with confirmation. Single-use enforced. | closed |
| T-3-02 | Spoofing | Confirmation link | mitigate | HMAC-signed via Plug.Crypto.sign + SHA-256 hash DB lookup. | closed |
| T-3-03 | Tampering | Reset token | mitigate | Token + all sessions deleted in same Ecto.Multi transaction. | closed |
| T-3-04 | Info Disclosure | Reset/confirm timing | mitigate | Dummy Argon2 hash for non-existent emails. Generic response always. | closed |
| T-3-05 | DoS | Confirmation code | mitigate | Rate limited: 5 attempts/15min per user via RateLimiter. | closed |
| T-3-06 | DoS | Confirmation resend | accept | Resend path has no rate limit. Accepted: emails are idempotent, low impact. | closed |
| T-3-INFRA-01 | Info Disclosure | Oban job args | mitigate | Only email_type + user_id + token in args. Email reconstructed at delivery time. | closed |
| T-3-INFRA-02 | Tampering | Token cleanup | mitigate | Cleanup deletes only tokens where inserted_at < (now - max_ttl). | closed |
| T-3-INFRA-03 | Availability | Delivery fallback | mitigate | Sync fallback returns {:error, reason}. Telemetry emitted on failure. | closed |
| T-3-TMPL-01 | XSS | Email templates | accept | Raw interpolation in HTML emails. All values are system-generated (URLs, codes, atom names). No user-controlled HTML injection vector. | closed |
| T-3-TMPL-02 | CSRF | Form submissions | mitigate | Phoenix form component auto-injects CSRF token on all POST forms. | closed |
| T-3-TMPL-03 | DoS | Code brute force | mitigate | Server-side rate limit: 5 attempts/15min. 6-digit = 1M combinations. | closed |
| T-3-RESET-01 | Tampering | Reset token reuse | mitigate | Same as T-3-03: Multi transaction deletes token + all sessions. | closed |
| T-3-RESET-02 | CSRF | Reset forms | mitigate | Phoenix CSRF on all POST/PUT forms. | closed |
| T-3-RESET-03 | Elevation | Password policy bypass | mitigate | Same password_changeset/validation as registration. | closed |
| T-3-RESET-04 | Elevation | Unconfirmed bypass | mitigate | user_auth plug checks confirmed_at on every request in :block mode. | closed |
| T-3-WIRE-01 | Availability | Email delivery failure | mitigate | Registration independent of email. Oban retries 3x async. | closed |
| T-3-WIRE-02 | Tampering | Config overwrite | mitigate | Generator detects existing config and skips. | closed |
| T-3-WIRE-03 | Info Disclosure | Token cross-user | mitigate | All token queries scoped by user_id FK. | closed |

*Status: open / closed*
*Disposition: mitigate (implementation required) / accept (documented risk) / transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-03-01 | T-3-06 | Confirmation resend has no rate limit. Emails are idempotent and low-cost. No user data exposed. Can add rate limiting in a future phase if abuse is observed. | User (accepted) | 2026-04-07 |
| AR-03-02 | T-3-TMPL-01 | Email templates use raw string interpolation without html_escape. All interpolated values are system-generated (URLs, numeric codes, atom-derived names). No user-controlled input reaches HTML context. | User (accepted) | 2026-04-07 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-07 | 19 | 19 | 0 | gsd-secure-phase |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-07
