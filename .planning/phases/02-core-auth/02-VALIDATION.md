---
phase: 2
slug: core-auth
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-06
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in) |
| **Config file** | `test/test_helper.exs` (exists) |
| **Quick run command** | `mix test --only unit` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test --only unit`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 1 | AUTH-02 | T-02-01 | Argon2id hash stored, never plaintext | unit | `mix test test/sigra/crypto_test.exs -x` | Exists (extend) | ⬜ pending |
| 02-01-02 | 01 | 1 | AUTH-03 | T-02-02 | Bcrypt detected, verified, re-hashed to Argon2id | unit | `mix test test/sigra/crypto_test.exs --only upgrade -x` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 1 | AUTH-07 | — | NIST defaults: min 8, no composition, common check | unit | `mix test test/sigra/password_policy_test.exs -x` | ❌ W0 | ⬜ pending |
| 02-03-01 | 03 | 2 | AUTH-01 | T-02-03 | Register with email/password, session created | unit + integration | `mix test test/sigra/auth_test.exs --only register -x` | ❌ W0 | ⬜ pending |
| 02-03-02 | 03 | 2 | AUTH-04 | T-02-04 | Login returns session, timing-safe for non-existent emails | unit + integration | `mix test test/sigra/auth_test.exs --only authenticate -x` | ❌ W0 | ⬜ pending |
| 02-03-03 | 03 | 2 | AUTH-05 | — | Logout invalidates current session only | integration | `mix test test/sigra/auth_test.exs --only logout -x` | ❌ W0 | ⬜ pending |
| 02-03-04 | 03 | 2 | AUTH-06 | T-02-05 | Magic link single-use, 10min TTL, rate limited | unit | `mix test test/sigra/auth_test.exs --only magic_link -x` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/auth_test.exs` — stubs for AUTH-01, AUTH-04, AUTH-05, AUTH-06
- [ ] `test/sigra/password_policy_test.exs` — stubs for AUTH-07
- [ ] `test/sigra/email_test.exs` — stubs for email normalization
- [ ] `test/sigra/crypto_test.exs` — extend existing with verify_with_upgrade tests (AUTH-02, AUTH-03)
- [ ] `priv/data/common_passwords.txt` — top 10k common passwords file

*Existing infrastructure covers ExUnit framework. Wave 0 adds test files and data.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Real-time password strength in LiveView | AUTH-07 | Requires browser interaction | Open registration page, type password, verify strength meter updates via phx-change |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
