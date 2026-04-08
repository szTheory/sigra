---
phase: 7
slug: api-authentication
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-08
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit (Elixir built-in) |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `mix test test/sigra/api_token_test.exs test/sigra/jwt_test.exs` |
| **Full suite command** | `mix test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `mix test test/sigra/api_token_test.exs test/sigra/jwt_test.exs`
- **After every plan wave:** Run `mix test`
- **Before `/gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 7-01-01 | 01 | 1 | API-01 | T-7-01 / — | Bearer token extracted from Authorization header | unit | `mix test test/sigra/api_token_test.exs` | ❌ W0 | ⬜ pending |
| 7-01-02 | 01 | 1 | API-02 | T-7-02 / — | Raw key shown once, SHA-256 hash stored | unit | `mix test test/sigra/api_token_test.exs` | ❌ W0 | ⬜ pending |
| 7-01-03 | 01 | 1 | API-03 | T-7-03 / — | Scoped tokens enforce resource:action permissions | unit | `mix test test/sigra/api_token_test.exs` | ❌ W0 | ⬜ pending |
| 7-02-01 | 02 | 1 | API-04 | T-7-04 / — | Token listing, revocation, expiration | unit | `mix test test/sigra/api_token_test.exs` | ❌ W0 | ⬜ pending |
| 7-03-01 | 03 | 2 | API-05 | T-7-05 / — | JWT generation with correct claims | unit | `mix test test/sigra/jwt_test.exs` | ❌ W0 | ⬜ pending |
| 7-03-02 | 03 | 2 | API-06 | T-7-06 / — | Refresh token rotation with reuse detection | unit | `mix test test/sigra/jwt_test.exs` | ❌ W0 | ⬜ pending |
| 7-04-01 | 04 | 2 | API-07 | T-7-07 / — | Headless mode without LiveView dependencies | integration | `mix test test/sigra/plug/fetch_bearer_test.exs` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/api_token_test.exs` — stubs for API-01, API-02, API-03, API-04
- [ ] `test/sigra/jwt_test.exs` — stubs for API-05, API-06
- [ ] `test/sigra/plug/fetch_bearer_test.exs` — stubs for API-07
- [ ] `test/sigra/plug/require_scopes_test.exs` — scope enforcement stubs
- [ ] `test/support/api_token_fixtures.ex` — shared API token fixtures

*Existing test infrastructure (ExUnit, Ecto SQL Sandbox) covers framework needs.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Raw key displayed once in response | API-02 | Visual confirmation of response shape | Create token via API, verify raw key in response body, confirm no retrieval endpoint returns it |

*All other phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
