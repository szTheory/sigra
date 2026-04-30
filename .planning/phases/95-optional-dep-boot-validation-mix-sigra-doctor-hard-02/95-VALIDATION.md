---
phase: 95
slug: optional-dep-boot-validation-mix-sigra-doctor-hard-02
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-30
---

# Phase 95 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `MIX_ENV=test mix test test/sigra/optional_deps_test.exs test/sigra/jwt/signer_test.exs test/sigra/delivery_test.exs test/sigra/workers/optional_deps_test.exs test/sigra/crypto_test.exs test/sigra/mfa_test.exs test/mix/tasks/sigra.doctor_test.exs test/sigra/application_optional_deps_test.exs test/example/test/example_web/smoke/install_compile_test.exs` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run that task's plan-local quick loop from the table below rather than the full Phase 95 quick set.
- **After wave 1 (`95-01`):** Run `MIX_ENV=test mix test test/sigra/optional_deps_test.exs test/sigra/jwt/signer_test.exs`
- **After wave 2 (`95-02` + `95-03`):** Run `MIX_ENV=test mix test test/sigra/delivery_test.exs test/sigra/crypto_test.exs test/sigra/mfa_test.exs test/mix/tasks/sigra.doctor_test.exs test/sigra/application_optional_deps_test.exs test/example/test/example_web/smoke/install_compile_test.exs && MIX_ENV=test mix compile --warnings-as-errors`
- **After wave 3 (`95-04`) / before close:** Run `MIX_ENV=test mix test test/sigra/workers/optional_deps_test.exs`, `rg -n "oban|bcrypt|eqrcode|sigra.doctor|delivery_test|crypto_test|mfa_test" .github/workflows/ci.yml`, and `rg -n "mix sigra.doctor|optional deps|async|warnings-as-errors|95-VERIFICATION" README.md MAINTAINING.md guides/introduction/troubleshooting-install.md guides/recipes/deployment.md .planning/phases/95-optional-dep-boot-validation-mix-sigra-doctor-hard-02/95-VALIDATION.md .planning/phases/95-optional-dep-boot-validation-mix-sigra-doctor-hard-02/95-VERIFICATION.md`.
- **Final wave gate:** Run the wave-2 command, `MIX_ENV=test mix test test/sigra/workers/optional_deps_test.exs`, `MIX_ENV=test mix sigra.doctor --delivery-mode=async`, `MIX_ENV=test mix compile --warnings-as-errors`, and confirm `.github/workflows/ci.yml` contains the three dep-off stories for Oban, bcrypt, and EQRCode.
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 95-01-01 | 01 | 1 | HARD-02 | T-95-01 / T-95-02 | Registry defines enforced vs advisory optional-dep policy and tagged exception copy from one source of truth | unit | `MIX_ENV=test mix test test/sigra/optional_deps_test.exs` | ✅ | ✅ green |
| 95-01-02 | 01 | 1 | HARD-02 | T-95-03 | Joken uses the registry-backed missing-dependency contract without a bespoke inline guard | unit | `MIX_ENV=test mix test test/sigra/optional_deps_test.exs test/sigra/jwt/signer_test.exs` | ✅ | ✅ green |
| 95-02-01 | 02 | 2 | HARD-02 | T-95-04 | Explicit async email raises on missing Oban while `:auto` may stay synchronous when async is not explicitly enabled | unit | `MIX_ENV=test mix test test/sigra/delivery_test.exs` | ✅ | ✅ green |
| 95-02-02 | 02 | 2 | HARD-02 | T-95-05 / T-95-06 | Real bcrypt verification and TOTP QR rendering fail loudly at first use while the no-user timing fallback remains allowed | unit | `MIX_ENV=test mix test test/sigra/crypto_test.exs test/sigra/mfa_test.exs` | ✅ | ✅ green |
| 95-03-01 | 03 | 2 | HARD-02 | T-95-07 | `mix sigra.doctor` reports contextual enforced/advisory rows and exits non-zero only for an actually invalid host | unit | `MIX_ENV=test mix test test/mix/tasks/sigra.doctor_test.exs` | ✅ | ✅ green |
| 95-03-02 | 03 | 2 | HARD-02 | T-95-08 / T-95-09 | Warning-clean compile survives without a blanket optional-dep suppression block, and the generated-host JWT/API path emits a compile-time warning when Joken is provably required and missing | unit/integration | `MIX_ENV=test mix test test/sigra/application_optional_deps_test.exs test/example/test/example_web/smoke/install_compile_test.exs && MIX_ENV=test mix compile --warnings-as-errors` | ✅ | ✅ green |
| 95-04-01 | 04 | 3 | HARD-02 | T-95-04 | Remaining lifecycle Oban workers compile as real modules and raise tagged missing-dep errors instead of disappearing | unit | `MIX_ENV=test mix test test/sigra/workers/optional_deps_test.exs` | ✅ | ✅ green |
| 95-04-02 | 04 | 3 | HARD-02 | T-95-10 | CI contains the three targeted dep-off lanes for Oban, bcrypt, and EQRCode without promoting Joken into the required matrix | config/grep | `rg -n "oban|bcrypt|eqrcode|sigra.doctor|delivery_test|crypto_test|mfa_test" .github/workflows/ci.yml` | ✅ | ✅ green |
| 95-04-03 | 04 | 3 | HARD-02 | T-95-11 / T-95-12 | Docs plus validation and verification surfaces point to `mix sigra.doctor`, preserve the “optional until enabled” rule, and capture roadmap criterion 5 evidence | docs/grep | `rg -n "mix sigra.doctor|optional deps|async|warnings-as-errors|95-VERIFICATION" README.md MAINTAINING.md guides/introduction/troubleshooting-install.md guides/recipes/deployment.md .planning/phases/95-optional-dep-boot-validation-mix-sigra-doctor-hard-02/95-VALIDATION.md .planning/phases/95-optional-dep-boot-validation-mix-sigra-doctor-hard-02/95-VERIFICATION.md` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure is sufficient for Phase 95 once the planned files above are created.

- No Wave 0 scaffolding plan is required.
- New tests introduced by `95-02` and `95-03` are phase-owned artifacts, not preconditions.
- The dep-off CI stories are verified through targeted lane commands, not by excluding missing deps from coverage.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| None required | HARD-02 | D-95-18 explicitly forbids a human decision loop for phase verification | N/A |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter
- [x] Wave 3 closes with CI dep-off proof plus warning-clean compile and doctor coverage

**Approval:** complete
