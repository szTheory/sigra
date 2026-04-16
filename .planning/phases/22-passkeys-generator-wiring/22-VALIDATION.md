---
phase: 22
slug: passkeys-generator-wiring
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-16
---

# Phase 22 - Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit for installer/generator coverage, shell smoke harnesses for generated-app omission checks, GitHub Actions install matrix for four-way compile and boot proof |
| **Config file** | `test/test_helper.exs`, `mix.exs`, `.github/workflows/ci.yml` |
| **Quick run command** | `mix test test/sigra/install/features/passkeys_test.exs test/sigra/install/features/passkeys_js_test.exs test/sigra/install/generator_passkeys_foundation_test.exs test/sigra/install/generator_passkey_management_test.exs --max-failures 1` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~180 seconds for focused generator checks; full suite and CI matrix longer |

---

## Sampling Rate

- **After every task commit:** Run the task-local verification command from its PLAN.md. Default quick feedback should stay on focused ExUnit or omission-smoke checks.
- **After every plan wave:** Run the quick run command above plus any new omission harness introduced in that wave.
- **Before `$gsd-verify-work`:** Run the full suite command and confirm the four-way install matrix is green in CI.
- **Max feedback latency:** 180 seconds for local task and wave checks; CI matrix is phase-gate only.

---

## Per-Plan Verification Map

| Plan | Wave | Requirements | Threat Refs | Secure Behavior | Test Type | Automated Command | Status |
|------|------|--------------|-------------|-----------------|-----------|-------------------|--------|
| 22-01 | 1 | PK-02 | T-22-01-01, T-22-01-02 | Installer defaults passkeys on, `--no-passkeys` disables cleanly, and `Features.Passkeys` remains a manifest-owned feature without runner special cases | unit + focused generator | `mix test test/sigra/install/features/passkeys_test.exs test/sigra/install/features/coverage_test.exs --max-failures 1` | ⬜ pending |
| 22-02 | 2 | PK-02 | T-22-02-01, T-22-02-02, T-22-02-03 | Passkey-only files, injections, routes, helpers, and shared-template regions are emitted only when `passkeys?` is true; disabled installs have no residual passkey strings, routes, or assets | generator omission + compile | `mix test test/sigra/install/generator_passkeys_opt_out_test.exs test/sigra/install/generator_passkeys_foundation_test.exs test/sigra/install/generator_passkey_management_test.exs --max-failures 1` | ⬜ pending |
| 22-03 | 3 | PK-02 | T-22-03-01, T-22-03-02 | Four-way organizations x passkeys install matrix compiles and boots, and assets-enabled no-passkeys smoke proves `assets/package.json` and `assets/js/*` omission on the disabled path | shell smoke + CI | `bash scripts/ci/passkeys-opt-out-smoke.sh` | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠ flaky*

---

## Nyquist Coverage

Wave 0 scaffolding is part of this phase and should land before broad rewiring:

- `test/sigra/install/generator_passkeys_opt_out_test.exs` must prove omission of passkey routes, files, helper functions, migrations, config blocks, and dependency strings under `--no-passkeys`.
- `scripts/ci/passkeys-opt-out-smoke.sh` must exercise an assets-enabled generated app so omission of `@simplewebauthn/browser`, `passkey_hooks.js`, and `passkey_browser.js` is tested outside the existing `--no-assets` CI harness.
- `.github/workflows/ci.yml` must expand install-matrix coverage to `""`, `--no-passkeys`, `--no-organizations`, and `--no-organizations --no-passkeys`.

Every implementation task should carry an automated verification step. No separate standalone Wave 0 plan is required as long as the first execution wave creates the missing omission harness before relying on it.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Installer report wording for the passkey default and opt-out path | PK-02 | Product wording and clarity are better judged by a human than by string presence alone | Run `mix sigra.install` and `mix sigra.install --no-passkeys` on a throwaway Phoenix app and confirm the summary explicitly states `Passkeys: enabled (default)` or `Passkeys: disabled via --no-passkeys` |

---

## Validation Sign-Off

- [x] All planned work has an automated verification target or Wave 0 harness
- [x] Sampling continuity is defined across task, wave, and phase gates
- [x] Wave 0 coverage for missing omission harnesses is called out explicitly
- [x] No watch-mode flags
- [x] Feedback latency target documented
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** ready for execution
