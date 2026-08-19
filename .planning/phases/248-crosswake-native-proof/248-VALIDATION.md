---
phase: 248
slug: crosswake-native-proof
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-08-19
---

# Phase 248 — Validation Strategy

> Per-phase validation contract for deterministic Crosswake, physical-iPhone, and Android-emulator proof.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit; XCTest/XCUITest; Android instrumentation with Espresso/Compose and UI Automator; Node receipt-schema/prohibition tests |
| **Config file** | `test/example/mix.exs`; native project files are Wave 0 deliverables |
| **Quick run command** | `cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs` |
| **Full suite command** | `scripts/ci/crosswake-native-ios-proof.sh && scripts/ci/crosswake-native-android-proof.sh` |
| **Estimated runtime** | Target < 20 minutes, excluding runner/device provisioning |

---

## Sampling Rate

- **After every task commit:** Run the focused ExUnit or receipt-schema test plus the affected platform build/test command.
- **After every plan wave:** Run both platform receipt validators and the host Crosswake/LearningTwin regression suites.
- **Before `$gsd-verify-work`:** Both receipt-last platform proof lanes and the full host regression suite must be green.
- **Max feedback latency:** 20 minutes after platform tooling and targets are provisioned.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 248-01 | TBD | 0 | XW-01 | T-248-01 | Crosswake receives only host-issued posture facts; credentials and authority fields are rejected | ExUnit + Node prohibition | `cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs` | Partial / ❌ W0 native fixtures | ⬜ pending |
| 248-02 | TBD | 0+ | NAT-01 | T-248-02 | Refresh material remains Keychain-protected and physical-iPhone evidence is receipt-last and secret-free | XCUITest + receipt validator | `scripts/ci/crosswake-native-ios-proof.sh` | ❌ W0 | ⬜ pending |
| 248-03 | TBD | 0+ | NAT-02 | T-248-03 | Refresh material remains Keystore-protected and emulator evidence is receipt-last and secret-free | Android instrumentation + receipt validator | `scripts/ci/crosswake-native-android-proof.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/example/native/ios/` — app and XCUITest targets, physical-destination selector, and test-only status surface.
- [ ] `test/example/native/android/` — Gradle wrapper/project, pinned SDK image/browser/dependencies, instrumentation target, and test-only status surface.
- [ ] `scripts/ci/crosswake-native-ios-proof.sh` — no-sleep, physical-target-only, receipt-last iPhone proof.
- [ ] `scripts/ci/crosswake-native-android-proof.sh` — no-sleep, pinned-emulator, receipt-last Android proof.
- [ ] Shared receipt schema/validator with bad and clean fixtures for secret leakage, wrong target, incomplete scenarios, and source mismatch.

---

## Manual-Only Verifications

All phase behaviors require automated verification. Runner/device-lab provisioning may require operator credentials, but proof collection and acceptance remain deterministic and machine-readable.

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags or fixed sleeps
- [ ] Feedback latency < 20 minutes after provisioning
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
