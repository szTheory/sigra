---
phase: 242
slug: close-gap-xw-01-xw-02-add-rendered-crosswake-start-control
status: ready
nyquist_compliant: true
wave_0_complete: true
created: 2026-08-11
---

# Phase 242 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit with Phoenix LiveView test helpers; Playwright `@playwright/test` `^1.48.0` |
| **Config file** | `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `cd test/example && mix test test/example_web/live/app_live_test.exs` |
| **Wave integration command** | `scripts/ci/hosted-session-interop-proof.sh --browser-only` |
| **Final security command** | `bash -lc 'set -euo pipefail; set -a; source tmp/db.env; set +a; cd test/example; MIX_ENV=test mix ecto.migrate --quiet; mix test test/example/accounts/crosswake_session_adapter_test.exs test/example/accounts/crosswake_continuations_test.exs test/example_web/controllers/crosswake_controller_test.exs --include example_app; cd ../..; node --test scripts/ci/prohibitions/p14-crosswake-authority-secrets.test.mjs; ! GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p14-crosswake-authority-secrets-bad.json node --test scripts/ci/prohibitions/p14-crosswake-authority-secrets.test.mjs; GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p14-crosswake-authority-secrets-clean.json node --test scripts/ci/prohibitions/p14-crosswake-authority-secrets.test.mjs'` |
| **Estimated runtime** | Task smoke commands stay focused; browser and denial-matrix commands run once at the wave/final boundary |

---

## Sampling Rate

- **After Task 1 commit:** Run `cd test/example && mix test test/example_web/live/app_live_test.exs`
- **After Task 2 commit:** Run `MIX_ENV=test mix test test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs`
- **After the plan wave:** Run `scripts/ci/hosted-session-interop-proof.sh --browser-only`, then the final security command from Test Infrastructure
- **Before `$gsd-verify-work`:** Run the full `scripts/ci/hosted-session-interop-proof.sh` from a clean exact-SHA worktree when receipt sealing is authorized
- **Max commit-time feedback latency:** One focused ExUnit file per task commit

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 242-01-01 | 01 | 1 | XW-01 | T-242-01 | Native POST form includes CSRF mechanics and no protocol-authority inputs | LiveView unit | `cd test/example && mix test test/example_web/live/app_live_test.exs` | ✅ | ⬜ pending |
| 242-01-02 | 01 | 1 | XW-01, XW-02 | T-242-02 / T-242-03 | Source contract locks the rendered edge, role click, callback/security markers, and serial browser configuration | ExUnit source contract | `MIX_ENV=test mix test test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs` | ✅ | ⬜ pending |

### Wave/Final Integration Gates

| Gate | Requirements | Secure Behavior | Automated Command | Status |
|------|--------------|-----------------|-------------------|--------|
| Role-driven browser journey | XW-01, XW-02 | Real cookie jar preserves exact callback keys, no Referer, fixed `/app`, and non-disclosure | `scripts/ci/hosted-session-interop-proof.sh --browser-only` | ⬜ pending |
| Established fail-closed matrix | XW-02 | Adapter, continuation, controller, and P14 real/bad/clean suites deny missing, expired, revoked, account-switched, replayed, and smuggled state before authority is granted | Final security command from Test Infrastructure | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. Execution extends:

- `test/example/test/example_web/live/app_live_test.exs` with route, method, accessible-name, and no-LiveView-event contract assertions.
- `test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts` by replacing only the fabricated submission with a role-based click.
- `test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs` with the rendered-boundary and role-click source contract required by Task 2.

All listed test files and runners already exist, `tmp/db.env` is present, and no Wave 0 scaffold remains to be created.

---

## Manual-Only Verifications

All phase behaviors have automated verification.

---

## Validation Sign-Off

- [x] All tasks have focused `<automated>` verification and no unresolved Wave 0 dependency
- [x] Sampling continuity: each task has a commit-time automated command
- [x] Existing test files cover all required references, including the XW-02 fail-closed owners
- [x] No watch-mode flags
- [x] Commit-time feedback is bounded by one focused ExUnit file; slower browser/security gates run once per wave/final boundary
- [x] `nyquist_compliant: true` and `wave_0_complete: true` are set truthfully in frontmatter

**Approval:** ready for execution; test results remain pending until the tasks run
