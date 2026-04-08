---
phase: 5
slug: oauth-and-social-login
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-08
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/oauth/ --no-start` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/oauth/ --no-start`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | OAUTH-01 | T-05-01 / — | Provider config validated at startup | unit | `mix test test/sigra/oauth/config_test.exs` | ❌ W0 | ⬜ pending |
| 05-01-02 | 01 | 1 | OAUTH-02 | T-05-02 / — | Assent strategy wrappers normalize responses | unit | `mix test test/sigra/oauth/strategies/` | ❌ W0 | ⬜ pending |
| 05-02-01 | 02 | 1 | OAUTH-03 | T-05-03 / — | OAuth state HMAC-signed, verified on callback | unit | `mix test test/sigra/oauth/state_test.exs` | ❌ W0 | ⬜ pending |
| 05-02-02 | 02 | 1 | OAUTH-04 | T-05-04 / — | Email-match linking requires confirmation | integration | `mix test test/sigra/oauth/callback_test.exs` | ❌ W0 | ⬜ pending |
| 05-03-01 | 03 | 2 | OAUTH-05 | T-05-05 / — | Encrypted token storage via cloak_ecto | unit | `mix test test/sigra/identity_test.exs` | ❌ W0 | ⬜ pending |
| 05-03-02 | 03 | 2 | OAUTH-06 | T-05-06 / — | Link/unlink with sudo mode enforcement | integration | `mix test test/sigra/oauth/link_test.exs` | ❌ W0 | ⬜ pending |
| 05-04-01 | 04 | 3 | OAUTH-07 | T-05-07 / — | Edge cases: no email, denied perms, CSRF mismatch | unit | `mix test test/sigra/oauth/error_test.exs` | ❌ W0 | ⬜ pending |
| 05-04-02 | 04 | 3 | OAUTH-08 | — | Generator produces idempotent OAuth files | integration | `mix test test/sigra/install/oauth_generator_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/oauth/` — directory structure for OAuth test modules
- [ ] `test/support/oauth_helpers.ex` — shared fixtures for mock Assent responses
- [ ] Test helpers for mocking Assent HTTP layer (Req/Finch adapter mock)

*Existing ExUnit infrastructure covers framework needs. OAuth-specific fixtures needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| OAuth redirect flow with real provider | OAUTH-01 | Requires real provider credentials and browser interaction | Configure test Google/GitHub app, click "Sign in with Google", verify redirect and callback |
| SVG icon rendering in login form | OAUTH-02 | Visual verification of brand-compliant icons | Load login page, verify provider icons render correctly with proper sizing |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
