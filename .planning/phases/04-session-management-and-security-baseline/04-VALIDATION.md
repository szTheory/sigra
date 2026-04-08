---
phase: 4
slug: session-management-and-security-baseline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-07
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (built-in) + Mox 1.1 |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test --only phase4` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test --only phase4`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | SESS-01 | T-4-01 | Session tokens hashed with SHA-256, opaque to client | unit | `mix test test/sigra/session_test.exs` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 1 | SESS-02 | — | Remember-me creates separate long-lived cookie + DB record | unit | `mix test test/sigra/session_test.exs` | ❌ W0 | ⬜ pending |
| 04-01-03 | 01 | 1 | SESS-03 | — | Password change invalidates all sessions except current | unit | `mix test test/sigra/auth_test.exs` | ✅ partial | ⬜ pending |
| 04-01-04 | 01 | 1 | SESS-04 | — | Log out everywhere deletes all + broadcasts PubSub | unit | `mix test test/sigra/session_test.exs` | ❌ W0 | ⬜ pending |
| 04-01-05 | 01 | 1 | SESS-05 | — | Session tracks IP, UA, last_active_at | unit | `mix test test/sigra/session_test.exs` | ❌ W0 | ⬜ pending |
| 04-01-06 | 01 | 1 | SESS-06 | — | Session listing returns all active sessions for user | unit | `mix test test/sigra/session_test.exs` | ❌ W0 | ⬜ pending |
| 04-01-07 | 01 | 1 | SESS-07 | T-4-02 | Idle + absolute timeout correctly expires sessions | unit | `mix test test/sigra/session_test.exs` | ❌ W0 | ⬜ pending |
| 04-01-08 | 01 | 1 | SESS-08 | T-4-03 | Cookie options: HttpOnly, SameSite=Lax, Secure | unit | `mix test test/sigra/plug/fetch_session_test.exs` | ✅ partial | ⬜ pending |
| 04-02-01 | 02 | 2 | SESS-09 | T-4-04 | Sudo mode checks sudo_at within configurable window | unit | `mix test test/sigra/plug/require_sudo_test.exs` | ✅ partial | ⬜ pending |
| 04-03-01 | 03 | 2 | SEC-01 | T-4-05 | Account locks after 5 failed attempts for 15 min | unit | `mix test test/sigra/lockout_test.exs` | ❌ W0 | ⬜ pending |
| 04-03-02 | 03 | 2 | SEC-02 | T-4-06 | IP rate limiting returns 429 with Retry-After header | unit | `mix test test/sigra/plug/rate_limit_test.exs` | ❌ W0 | ⬜ pending |
| 04-03-03 | 03 | 2 | SEC-03 | T-4-07 | Failed attempts counter increments on wrong password | unit | `mix test test/sigra/auth_test.exs` | ✅ partial | ⬜ pending |
| 04-03-04 | 03 | 2 | SEC-04 | T-4-08 | Lockout message is enumeration-safe (generic) | unit | `mix test test/sigra/error_test.exs` | ✅ partial | ⬜ pending |
| 04-03-05 | 03 | 2 | SEC-05 | — | CSRF documented, cookie SameSite=Lax defaults | unit | `mix test test/sigra/plug/fetch_session_test.exs` | ✅ partial | ⬜ pending |
| 04-03-06 | 03 | 2 | SEC-06 | — | HMAC tokens for lockout + suspicious login emails | unit | existing | ✅ | ⬜ pending |
| 04-04-01 | 04 | 3 | SEC-07 | T-4-09 | Suspicious login detected on new IP, email sent | unit | `mix test test/sigra/suspicious_login_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/session_test.exs` — stubs for SESS-01 through SESS-07
- [ ] `test/sigra/lockout_test.exs` — stubs for SEC-01, SEC-03
- [ ] `test/sigra/plug/rate_limit_test.exs` — stubs for SEC-02
- [ ] `test/sigra/suspicious_login_test.exs` — stubs for SEC-07
- [ ] `test/sigra/ua_parser_test.exs` — stubs for SESS-05 (UA parsing)
- [ ] `test/sigra/rate_limiters/hammer_test.exs` — stubs for Hammer wrapper
- [ ] Add `Mox.defmock(Sigra.MockSessionStore, for: Sigra.SessionStore)` to test_helper.exs
- [ ] Add `Mox.defmock(Sigra.MockGeoIP, for: Sigra.GeoIP)` to test_helper.exs

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Cookie flags in real browser | SESS-08 | Browser DevTools needed to verify actual cookie headers | Open app in browser, login, check Application > Cookies for HttpOnly/SameSite/Secure flags |
| PubSub disconnect in LiveView | SESS-04 | Requires live WebSocket connection | Open two browser sessions, "log out everywhere" from one, verify other disconnects |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
