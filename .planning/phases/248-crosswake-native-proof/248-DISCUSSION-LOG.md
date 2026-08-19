# Phase 248: Crosswake Native Proof - Discussion Log (Assumptions Mode)

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in `248-CONTEXT.md`; this log preserves the analysis.

**Date:** 2026-08-19
**Phase:** 248-crosswake-native-proof
**Mode:** assumptions
**Areas analyzed:** Released Crosswake integration, native session and storage boundary, evidence and truth claims

## Assumptions Presented

### Released Crosswake integration

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Extend the existing released-package integration as a host-owned projection seam: Sigra resolves authoritative session state and Crosswake receives only opaque references and bounded facts. | Confident | `test/example/lib/example/accounts/crosswake_session_adapter.ex`; `test/example/mix.exs`; `test/example/mix.lock` |
| Map the Phase 247 replay vocabulary to released Crosswake journal/replay contracts while Phoenix retains lease, authorization, and terminal persistence. | Confident | `test/example/lib/example/learning_twin.ex`; `test/example/deps/crosswake/lib/crosswake/offline/journal.ex`; `test/example/deps/crosswake/lib/crosswake/offline/replay.ex`; `247-CONTEXT.md` |
| Consume released Crosswake native shell/core and `crosswake_sigra` `NativeEvidence` contracts rather than creating new SDKs or treating the packages as BEAM-only. | Confident after research | Crosswake 0.2.0 native shell guide; `crosswake_sigra` 0.1.3 `AuthReturn`; `.planning/REQUIREMENTS.md` |

### Native session and storage boundary

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Use Phase 246 hosted PKCE through `ASWebAuthenticationSession` on iOS and Auth Tab/Custom Tabs on Android; no embedded WebView or direct-password shortcut. | Likely | `.planning/phases/246-hosted-and-direct-login-ceremonies/246-CONTEXT.md`; Apple AuthenticationServices; AndroidX Browser documentation |
| Persist only rotating refresh authority: Keychain on iOS and app-private AES-GCM ciphertext protected by an Android Keystore key; keep access authority memory-only. | Confident | `.planning/research/STACK.md`; Apple Keychain Services; Android Keystore and app-private storage documentation |

### Evidence and truth claims

| Assumption | Confidence | Evidence |
|------------|------------|----------|
| Run XCUITest against an exact physical iPhone on an attached-device runner/device lab and instrumentation against a pinned Android emulator; browser emulation and simulators are not substitutes. | Likely | `guides/recipes/b2c-alpha.md`; Apple physical-device/XCUITest documentation; Android UI Automator documentation |
| Produce separate redacted receipt-last lanes that cover hosted return, secure storage, verified media, lease edge, kill/relaunch, account switch, revocation, and exactly-once replay. | Confident | `scripts/ci/hosted-session-interop-proof.sh`; `test/example/priv/playwright/tests/twin-offline.spec.ts`; `.planning/ROADMAP.md` |
| Android may prove disabled emulator transports; iPhone must use and label a controlled transport-failure fixture because official tooling does not establish deterministic physical-radio control. | Confident after research | Apple XCUITest/device tooling; Android emulator and AOSP connectivity tooling |

## Corrections Made

No corrections — all assumptions were confirmed.

## External Research

- **Apple hosted return:** `ASWebAuthenticationSession` supports exact HTTPS host/path or custom-scheme callbacks as a system-controlled browser component; PKCE, state, and callback binding remain application/host checks. Sources: `https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession`, `https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app`.
- **Physical-iPhone automation:** XCUITest can run on an exact physical destination and automate application lifecycle/cross-app UI; `.xcresult` and allowlisted attachments provide evidence mechanics. A true physical lane needs an attached-device runner/device lab. Sources: `https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices`, `https://developer.apple.com/documentation/xcuiautomation/xcuiapplication`.
- **iOS secure storage:** Keychain supports add/query/update/delete of small secrets; tests should report only posture booleans/enums. Source: `https://developer.apple.com/documentation/security/keychain-services`.
- **Physical-iPhone offline limit:** No current official supported XCUITest/device command was established for deterministic full network disconnection. The selected evidence is a controlled transport failure, explicitly not a radio-off claim.
- **Android browser automation:** `AuthTabIntent` offers exact HTTPS or custom-scheme return handling where supported; Custom Tabs remains the bounded browser-backed fallback. UI Automator covers cross-app boundaries. Sources: `https://developer.android.com/reference/androidx/browser/auth/AuthTabIntent`, `https://developer.android.com/training/testing/other-components/ui-automator-legacy`.
- **Android secure storage and relaunch:** Use a non-exportable Keystore AES key over app-private ciphertext and host-orchestrated `force-stop` plus a second instrumentation phase for process-death proof. Sources: `https://developer.android.com/privacy-and-security/keystore`, `https://developer.android.com/tools/adb`.
- **Android emulator offline:** Pinned emulator transport state can be controlled and verified, with capability checks and cleanup; this does not imply physical-device proof. Source: `https://developer.android.com/studio/run/emulator-console`.
- **Released package contract:** Hex currently publishes `crosswake` 0.2.0 and `crosswake_sigra` 0.1.3. Crosswake includes host-owned native shell/core contracts, and `crosswake_sigra` includes `NativeEvidence` plus secret-denying telemetry; neither artifact by itself proves a physical device or emulator run. Sources: `https://hex.pm/api/packages/crosswake/releases/0.2.0`, `https://hex.pm/api/packages/crosswake_sigra/releases/0.1.3`, `https://crosswake.hexdocs.pm/native_shell.html`, `https://crosswake-sigra.hexdocs.pm/0.1.3/Crosswake.Companions.Sigra.AuthReturn.html`.

## Methodology Applied

- Decisive Defaulting selected repo-consistent authority, storage, and proof patterns without reopening internal implementation menus.
- Escalation Threshold retained the iOS browser-component interpretation and attached physical-device lane as visible contract/evidence assumptions.
- Research Depth Calibration required current official Apple/Android documentation and published Crosswake package contracts before confirmation.
- Proof-truth and UX lenses require deterministic failure, exact evidence-class labels, and no credential-bearing diagnostics.
