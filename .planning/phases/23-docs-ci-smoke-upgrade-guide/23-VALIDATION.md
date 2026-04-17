---
phase: 23
slug: docs-ci-smoke-upgrade-guide
status: planned
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-16
---

# Phase 23 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + Playwright |
| **Config file** | `test/test_helper.exs`, `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `mix test test/upgrade_test.exs test/sigra/guides_dx02_test.exs` |
| **Full suite command** | `mix test && (cd test/example/priv/playwright && npx playwright test)` |
| **Estimated runtime** | ~30 seconds for narrow ExUnit/static checks, ~180 seconds for browser-inclusive wave checks |

---

## Sampling Rate

- **After every task commit:** Run the task's narrow ExUnit or static pre-check command from the active PLAN.md
- **After every plan wave:** Run `mix test`; for browser-smoke waves also run `cd test/example/priv/playwright && npx playwright test`
- **Before `$gsd-verify-work`:** `mix test`, `mix docs --warnings-as-errors`, and Playwright smoke must all be green
- **Max feedback latency:** 30 seconds for static/targeted checks, 180 seconds for browser-inclusive wave/full checks (explicitly accepted for DX-07 because real WebAuthn/mailbox/browser coverage is the release-gate signal)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 23-01-01 | 01 | 1 | DX-03, DX-04, DX-05, DX-06, DX-08 | T-23-01 | Docs and HexDocs wiring stay aligned with shipped org/passkey posture and upgrade steps | docs + unit | `mix test test/sigra/guides_dx02_test.exs test/upgrade_test.exs && mix docs --warnings-as-errors` | ✅ partial | ⬜ pending |
| 23-02-01 | 02 | 1 | DX-01, DX-02 | T-23-02 | Generated fixtures and `Sigra.Testing` helpers stay narrow, explicit, mirror the generated contract, and keep the install-golden fixture lock visible | unit + integration | `mix test test/sigra/auth_fixtures_scenario_test.exs test/sigra/testing_test.exs test/sigra/testing/assert_audit_logged_test.exs --max-failures 1` | ✅ | ⬜ pending |
| 23-03-01 | 03 | 2 | DX-07 | T-23-03 | Task-level pre-checks keep browser-spec posture honest before the slower wave-level smoke run | static | `bash -lc 'set -euo pipefail; rg -n "switcher|Invite member|accept|extractConfirmationLink|mailbox|invitation" test/example/priv/playwright/tests/organizations.spec.ts; ! rg -n "page\\.route\\(|route\\.fulfill\\(" test/example/priv/playwright/tests/organizations.spec.ts'` | ✅ | ⬜ pending |
| 23-03-02 | 03 | 2 | DX-07 | T-23-03 | Task-level pre-checks keep passkey specs and CI wiring aligned; the full Playwright/browser smoke still runs at wave verification | static | `bash -lc 'set -euo pipefail; rg -n "addVirtualAuthenticator|/users/settings/mfa/passkeys/options|/users/log_in/passkey/options" test/example/priv/playwright/tests/passkey-login.spec.ts test/example/priv/playwright/tests/passkey-options.spec.ts; ! rg -n "page\\.route\\(|route\\.fulfill\\(|storageState\\(|addCookies\\(|document\\.cookie|localStorage\\.|sessionStorage\\." test/example/priv/playwright/tests/passkey-login.spec.ts test/example/priv/playwright/tests/passkey-options.spec.ts; rg -n "playwright|passkey-login\\.spec\\.ts|passkey-options\\.spec\\.ts|install_matrix" .github/workflows/ci.yml'` | ✅ | ⬜ pending |
| 23-04-01 | 04 | 2 | DX-09 | T-23-04 | Tenant-scope enforcement outcome is explicit: either scoped Credo check ships or documented fallback lands with automated proof | spike + docs/unit | `bash -lc 'if test -f lib/sigra/credo/no_unscoped_org_query_in_lib.ex; then mix test test/sigra/credo/no_unscoped_org_query_in_lib_test.exs --max-failures 1; else rg -n "DX-09 outcome|conventions plus integration enforcement|for_org/2" CONVENTIONS.md; fi'` | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing plans satisfy Wave 0 readiness by assigning every missing proof to a concrete task with an automated command:

- [x] `23-01` Task 2 covers guide regression and upgrade-runbook drift (`test/sigra/guides_dx02_test.exs`, `test/upgrade_test.exs`)
- [x] `23-02` Task 1 covers generated fixture contract locks, including the `auth_fixtures` scenario test and the install-golden artifact alignment for DX-01
- [x] `23-02` Task 2 covers the new `Sigra.Testing` org-aware assertions
- [x] `23-04` Tasks 1-2 cover the DX-09 spike-or-fallback branch with automated proof

Wave 0 is therefore complete at planning time: no validation dependency is left unassigned or unspecified before execution begins.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Docs remain readable as an end-to-end operator walkthrough | DX-03, DX-04, DX-05, DX-06 | Automated tests can enforce structure and commands, but not whether the narrative stays concise and runnable | Generate docs locally, read the new/updated guides in sequence, and confirm the getting-started continuation still feels like a single happy path |
| Browser smoke covers the intended journeys without over-expanding the suite | DX-07 | Human review is needed to keep the suite focused on the five load-bearing paths rather than growing a large permutation matrix | Review the final Playwright file set and confirm it covers org switcher, invite accept (new + existing user), passkey registration, and passkey auth only |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all missing helper and guide regression references
- [ ] No watch-mode flags
- [ ] Feedback latency stays within the chosen command budget
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
