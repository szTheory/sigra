---
phase: 02
slug: core-auth
status: verified
threats_open: 0
asvs_level: 1
created: 2026-04-06
---

# Phase 02 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| User input → Sigra.Auth | Registration/login forms submit email+password | Plaintext credentials (email, password) |
| Sigra.Auth → Sigra.Crypto | Password hashing and verification | Plaintext password → Argon2id hash |
| Sigra.Auth → Database (via Repo) | Token creation/deletion, user CRUD | Hashed tokens, hashed passwords, email |
| Browser → Phoenix (magic link) | Magic link URL clicked from email | Raw token in URL param |
| Sigra.Email → Database queries | Normalized email used for lookups | NFKC-normalized email |

---

## Threat Register

| Threat ID | Category | Component | Disposition | Mitigation | Status |
|-----------|----------|-----------|-------------|------------|--------|
| T-02-01 | Spoofing | Crypto | mitigate | Constant-time comparison via Argon2/bcrypt C NIFs; `no_user_verify/0` runs dummy hash for missing users (`crypto.ex:99`) | closed |
| T-02-02 | Tampering | Crypto | mitigate | Strict prefix detection: `$2b$`/`$2a$` for bcrypt, `$argon2` for Argon2 with no fallthrough (`crypto.ex:229,238`) | closed |
| T-02-03 | Information Disclosure | PasswordPolicy | mitigate | 10k common password list embedded at compile time, checked in `validate/2` (`password_policy/common_passwords.ex`) | closed |
| T-02-04 | Information Disclosure | PasswordPolicy | mitigate | NIST minimum 8 chars enforced; max 72 bytes for bcrypt compat (`password_policy.ex`) | closed |
| T-02-05 | Tampering | Email | mitigate | NFKC applied to emails ONLY via `String.normalize(:nfkc)` in `Email.normalize/1`; never applied to passwords (`email.ex:47`) | closed |
| T-02-06 | Information Disclosure | PasswordPolicy | accept | Optional HIBP k-Anonymity check via `check_breached/1` — off by default, opt-in. Acceptable for v1 ASVS L1. | closed |
| T-02-07 | Information Disclosure | Email | mitigate | Email normalized consistently via `Email.normalize/1` before all comparisons in Auth (`auth.ex:98,147`) | closed |
| T-02-08 | Information Disclosure | Auth.register | mitigate | Duplicate email returns `{:error, :email_taken}` atom; callers show generic message. No "email already registered" leak (`auth.ex:32-33,59`) | closed |
| T-02-09 | Information Disclosure | Auth.authenticate | mitigate | Generic error for all failures; `no_user_verify()` called for non-existent users to prevent timing side-channel (`auth.ex:127`, `crypto.ex:144,171,249`) | closed |
| T-02-10 | Spoofing | Token | mitigate | 32 bytes from `:crypto.strong_rand_bytes/1`; SHA-256 hashed before DB storage (`token.ex:95-96`) | closed |
| T-02-11 | Repudiation | Auth.verify_magic_link | mitigate | Single-use: token deleted from DB after verification via `repo.delete!/1` (`auth.ex:219-220`) | closed |
| T-02-12 | Denial of Service | Auth.request_magic_link | mitigate | Rate limited: max 3 requests per email per 15 min via configurable `RateLimiter` behaviour (`auth.ex:133-135,155-156,279-280`) | closed |
| T-02-13 | Information Disclosure | Auth.register | mitigate | Argon2id hashing via `Sigra.Crypto.hash_password/1` before DB insert (`auth.ex:17`, `crypto.ex`) | closed |
| T-02-14 | Denial of Service | Auth.authenticate | accept | Phase 2 increments `failed_attempts` counter but does not enforce lockout — lockout enforcement deferred to Phase 4 rate limiting. Counter tracking is in place (`auth.ex:115,271`). | closed |
| T-02-15 | Tampering | Auth (bcrypt upgrade) | accept | Best-effort, non-transactional rehash on login. Worst case is redundant rehash next login — no security impact. (`crypto.ex` verify_with_upgrade) | closed |
| T-02-16 | Elevation of Privilege | Templates (CSRF) | mitigate | Phoenix CSRF protection via `delete_csrf_token()` on logout; forms use framework's built-in `_csrf_token` (`user_auth.ex:69`) | closed |

*Status: open / closed*
*Disposition: mitigate (implementation required) / accept (documented risk) / transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-01 | T-02-06 | HIBP breach check is opt-in. Common password list provides baseline protection. ASVS L1 does not require breach DB integration. | gsd-secure-phase | 2026-04-06 |
| AR-02 | T-02-14 | Failed attempt counter is tracked but lockout not enforced until Phase 4 (rate limiting). No DoS vector because counter alone has no side effects. | gsd-secure-phase | 2026-04-06 |
| AR-03 | T-02-15 | Bcrypt-to-Argon2 rehash is best-effort. Race condition worst case is a redundant rehash — no data loss or security degradation. | gsd-secure-phase | 2026-04-06 |

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-04-06 | 16 | 16 | 0 | gsd-secure-phase (inline) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-04-06
