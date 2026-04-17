---
phase: 20
slug: passkey-challenge-plug-runtime-config-js-hooks-infra
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-15
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Mox |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/plug/passkey_challenge_test.exs test/sigra/passkeys/config_test.exs test/sigra/passkeys/rate_limit_test.exs test/sigra/install/features/passkeys_js_test.exs -x` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test` |
| **Estimated runtime** | ~90 seconds |

---

## Sampling Rate

- **After every task commit:** Run that task's single-file or plan-local `<automated>` command from the active PLAN.md
- **After every plan wave:** Run `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test`
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 90 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 20-01-01 | 01 | 1 | PK-06 | T-20-01 | Plug tests specify registration/authentication slot separation, replay rejection, and delete-on-success semantics | unit + plug | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/plug/passkey_challenge_test.exs -x` | ❌ W0 | ⬜ pending |
| 20-01-02 | 01 | 1 | PK-06 | T-20-01 | `Sigra.Plug.PasskeyChallenge` issues signed-token session slots and verifies only server-owned challenges | unit + plug | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/plug/passkey_challenge_test.exs -x` | ❌ W0 | ⬜ pending |
| 20-02-01 | 02 | 1 | PK-09, PK-10 | T-20-02 / T-20-03 | Config and limiter tests lock strict RP validation, defaults, and per-user ceremony key shape | unit | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/passkeys/config_test.exs test/sigra/passkeys/rate_limit_test.exs -x` | ❌ W0 | ⬜ pending |
| 20-02-02 | 02 | 1 | PK-09, PK-10 | T-20-02 / T-20-03 | `Sigra.Passkeys.config/0` caches validated runtime config and `rate_limit_ceremony/3` denies the sixth hit per user/window | unit | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/passkeys/config_test.exs test/sigra/passkeys/rate_limit_test.exs -x` | ❌ W0 | ⬜ pending |
| 20-03-01 | 03 | 2 | GEN-06 | T-20-04 | Installer tests lock marker-detection path, idempotency, merged hooks, and manual fallback behavior | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/features/passkeys_js_test.exs -x` | ❌ W0 | ⬜ pending |
| 20-03-02 | 03 | 2 | GEN-06 | T-20-04 | Generated JS hooks and `app.js` wiring preserve `...colocatedHooks`, use explicit marker comments, and emit exact fallback instructions | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/install/features/passkeys_js_test.exs -x` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/sigra/plug/passkey_challenge_test.exs` — PK-06 replay, delete-on-success, slot separation, no `clientDataJSON` trust
- [ ] `test/sigra/passkeys/config_test.exs` — PK-09 runtime validation, defaults, and cache/first-use behavior
- [ ] `test/sigra/passkeys/rate_limit_test.exs` — PK-10 user key shape and sixth-hit deny path
- [ ] `test/sigra/install/features/passkeys_js_test.exs` — GEN-06 marker injection and manual fallback coverage
- [ ] `test/support/install_fixture.ex` asset capture extension or dedicated fixture helper

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Fresh Phoenix app marker placement is ergonomically clear for developers | GEN-06 | Requires reading emitted instructions and generated asset layout in a host app fixture | Install into a fresh Phoenix 1.8 app, inspect `assets/js/app.js`, and confirm the Sigra marker and manual fallback text are obvious and copy-pasteable |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency stays within the chosen task-level command budget
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
