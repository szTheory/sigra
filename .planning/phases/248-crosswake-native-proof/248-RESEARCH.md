# Phase 248: Crosswake Native Proof - Research

**Researched:** 2026-08-19
**Domain:** First-party native session/offline proof through released Crosswake contracts
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Released Crosswake integration
- **D-01:** Extend the existing host-owned projection seam. Sigra freshly resolves app-session validity and revocation; the Phoenix host retains account authorization, lease issuance, media policy, and terminal replay decisions; Crosswake receives only newly derived opaque references and bounded route/offline facts.
- **D-02:** Map the Phase 247 `client_mutation_id`, idempotency key, base checkpoint, and `accepted` / `rejected` / `conflict` outcomes onto the released Crosswake journal/replay contracts. Crosswake vocabulary may structure the request and evidence, but it must not decide host authorization or persist the authoritative terminal outcome.
- **D-03:** Consume the native shell/core and `NativeEvidence` contracts released with `crosswake` 0.2.0 and `crosswake_sigra` 0.1.3. Add only host-owned example iOS/Android shells and phase evidence; do not publish a Sigra Swift/Kotlin SDK or modify Crosswake/Lockspire source.
- **D-04:** Project only allowlisted facts such as platform, return transport, link verification, callback binding, replay posture, outcome, and denial category. Credentials, authorization codes, OAuth state/nonce/verifier values, raw callbacks, account identifiers, and authentication authority never enter Crosswake or retained evidence.

### Native session and storage boundary
- **D-05:** Both native shells use the Phase 246 hosted public-client ceremony with PKCE S256, exact callback and state checks, explicit browser continuation, one-time code exchange, and the single opaque app-session lifecycle. Embedded `WKWebView` / `WebView` authentication and direct-password shortcuts are excluded from this proof.
- **D-06:** iOS uses `ASWebAuthenticationSession` as Apple's system-controlled external-user-agent component. The proof does not require or claim a handoff to standalone Safari; it does require an exact HTTPS host/path or exact custom-scheme callback plus application-level state and callback validation.
- **D-07:** Android prefers `AuthTabIntent` when the pinned browser supports it and uses Custom Tabs as the bounded fallback. The lane records the selected browser component/version and fails closed when its required callback or verification capability is unavailable.
- **D-08:** Access credentials remain memory-only. iOS persists only the rotating refresh credential in Keychain with the most restrictive accessibility class compatible with the scenarios. Android persists only randomized AES-GCM ciphertext and metadata in app-private storage, protected by a non-exportable `AndroidKeyStore` key.
- **D-09:** Credential-store tests expose only posture booleans/enums: present, rotated, recovered after relaunch, deleted after logout/revocation, decrypt/read result category, and `access_persisted: false`. Rotation comparison occurs inside the app; no credential value, raw callback, code, verifier, or stable account/device identifier is emitted.

### Evidence and truth claims
- **D-10:** NAT-01 requires XCUITest against an exact physical-iPhone destination on an attached-device macOS runner or device lab. Playwright mobile emulation, an iOS Simulator, and Xcode Cloud simulated destinations cannot substitute for the physical-device receipt.
- **D-11:** NAT-02 uses a pinned Android emulator image, browser, AndroidX Browser version, and instrumentation stack. Espresso/Compose synchronization owns in-app assertions; UI Automator owns browser/system boundaries; host orchestration owns true force-stop/relaunch and transport controls. Fixed sleeps are prohibited.
- **D-12:** Each platform has a separate bounded, redacted, source-bound receipt-last lane. Both lanes cover hosted return, credential-store posture, verified image/audio availability, strict seven-day lease edge, offline use, kill/relaunch, account switch, server revocation, and exactly-once accepted/rejected/conflict replay.
- **D-13:** Missing terminal receipt, wrong or unverifiable execution target, failed callback/link verification, unsupported browser capability, incomplete scenario set, failed cleanup, source mismatch, or failed secret scan makes the corresponding platform claim fail. Existing browser/Crosswake evidence is prerequisite and reference evidence only, never a native substitute.
- **D-14:** Android emulator offline proof disables and verifies all available transports before exercising local behavior. Because current official Apple tooling does not establish a supported deterministic radio-off API for a physical iPhone, the iPhone lane uses a controlled transport-failure fixture and labels the result `controlled_transport_failure`; it must not claim physical radio disconnection.
- **D-15:** Physical-vs-emulated target identity, toolchain/browser versions, scenario booleans, artifact hashes, cleanup status, redaction/secret-scan results, and terminal completion belong to the phase-owned evidence receipt. Only the narrower released `crosswake_sigra` native/telemetry vocabulary is projected into Crosswake.

### the agent's Discretion
- Exact placement and internal structure of the host-owned iOS and Android example shells, provided released Crosswake package coordinates are pinned and no reusable Sigra SDK surface is published.
- Exact attached-device runner or device-lab provider for the physical-iPhone lane, provided the receipt mechanically proves the physical destination and the lane remains fully automated.
- Exact test-only status UI, fixture IdP presentation, evidence schema field names, and helper/module names, provided selectors are stable, diagnostics are allowlisted, and all hard-fail and secret-denial boundaries above remain mechanically enforced.
- Whether iOS uses an exact associated-domain HTTPS callback or an exact registered custom scheme, and whether Android uses verified App Links or the bounded custom-scheme fallback, provided the selected transport and verification posture are recorded truthfully.

### Deferred Ideas (OUT OF SCOPE)
- Published Swift and Kotlin SDKs or UI kits — future SDK requirements after adopter evidence.
- Generic offline sync, background sync, reusable media-cache adapters, and additional offline islands — future work only after repeated host need.
- Electron runtime/package implementation — Phase 249 defines contract coverage without packaging an application.
- Physical Android hardware and iOS radio-level network-disconnection claims — not required by Phase 248 and not implied by the selected evidence lanes.
</user_constraints>

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM design system and Rail Accent assets if any admin UI is touched; support Light, Dark, and System modes. No admin work is required by this phase. [VERIFIED: AGENTS.md]
- Native/browser evidence must use deterministic selectors/readiness and no fixed sleeps. [VERIFIED: AGENTS.md]
- Replace UAT with deterministic automation and machine-readable evidence; do not mark a missing proof as passed. [VERIFIED: AGENTS.md]
- CI watchers are single-owner and use the prescribed 60-second GitHub polling interval. [VERIFIED: AGENTS.md]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| XW-01 | Consume released `crosswake` and `crosswake_sigra` packages without granting Crosswake authentication authority. | Existing lockfile, `CrosswakeSessionAdapter`, `NativeEvidence`, telemetry filters, and journal/replay contracts provide the exact integration seam. [VERIFIED: repository source] |
| NAT-01 | Automated physical-iPhone proof covers hosted auth, Keychain refresh storage, verified offline lesson/media/audio, seven-day boundary, relaunch, isolation, revocation, and replay. | XCUITest + an attached-device runner, system web auth, Keychain posture surface, controlled transport fixture, and receipt validator are required. [CITED: developer.apple.com/documentation/authenticationservices/aswebauthenticationsession] |
| NAT-02 | Automated Android-emulator proof covers the equivalent Keystore-backed and offline/replay outcomes. | AuthTab/Custom Tabs, Keystore-AES-GCM app-private storage, instrumentation/UI Automator, emulator transport control, and receipt validator are required. [CITED: developer.android.com/reference/androidx/browser/auth/AuthTabIntent] |
</phase_requirements>

## Summary

Build this as a host-owned native proof substrate, not a client SDK. `test/example` already consumes released `crosswake` 0.2.0 and `crosswake_sigra` 0.1.3, and its adapter freshly resolves host session state before giving Crosswake only derived opaque facts. The installed companion contract’s native evidence is deliberately limited to platform, transport, link verification, callback binding, replay posture, and opaque reference; it rejects credential and authority smuggling. [VERIFIED: Hex.pm registry and repository source]

The plan should add two small, separately executable native shells plus a phase-owned receipt validator and orchestration scripts. iOS must run against a receipt-proven attached physical iPhone; Android must run against a pinned emulator and browser. Both shells call the already-host-owned hosted PKCE ceremony and lesson/replay APIs. They may mirror Crosswake journal/replay fields, but the Phoenix host remains the sole authority for authorization, seven-day lease, current partition, and terminal replay outcome. [VERIFIED: repository source]

**Primary recommendation:** Plan XW-01 first as a pure host/Crosswake projection-and-prohibition contract, then deliver iOS and Android shells with their own deterministic receipt-last lanes; make the physical device/lab and Android SDK provisioning explicit Wave 0 blockers.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Hosted PKCE start, state/code exchange, app-session issuance/revocation | API / Backend (Sigra + Phoenix) | Native shell | The shell initiates and validates its local return, while Sigra is authoritative for the single opaque session lifecycle. [VERIFIED: repository source] |
| System-browser interaction and callback dispatch | iOS/Android client | API / Backend | Platform API owns browser UI/callback delivery; host validates exact callback, state, and one-time exchange. [CITED: developer.apple.com/documentation/authenticationservices/aswebauthenticationsession] |
| Refresh persistence | iOS/Android client | OS secure storage | Only rotating refresh material may persist; access stays memory-only. [CITED: developer.apple.com/documentation/security/restricting-keychain-item-accessibility] |
| Lesson/media, lease and replay authorization | API / Backend | Native local store | Host issues manifest/lease and decides replay; native cache can only enable bounded local use. [VERIFIED: repository source] |
| Crosswake route/replay projection | API / Backend | Native shell | The existing adapter derives opaque facts after fresh host lookup, and Crosswake structures facts rather than authenticating. [VERIFIED: repository source] |
| Platform-specific proof and evidence | CI/orchestrator | Native test harness | Target identity and full receipt are phase-owned; only narrow allowlisted telemetry crosses to Crosswake. [VERIFIED: repository source] |

## Standard Stack

### Core

| Library / component | Version | Purpose | Why Standard |
|---------------------|---------|---------|--------------|
| `crosswake` | `0.2.0`, released 2026-07-03 | Released host-side native shell/core and offline vocabulary | Already locked by the example; its shell is thin and manifest-first, rather than a generic native runtime. [VERIFIED: Hex.pm registry and repository source] |
| `crosswake_sigra` | `0.1.3`, released 2026-08-09 | Released Sigra companion `NativeEvidence`, evaluator, and telemetry contracts | Already locked and directly exposes the fact-only boundary required by XW-01. [VERIFIED: Hex.pm registry and repository source] |
| iOS `ASWebAuthenticationSession` + Keychain Services + XCUITest | Xcode SDK / Xcode 26.6 available locally | Hosted browser auth, refresh storage, physical-device UI proof | Apple provides callback delivery to the calling auth session and configurable Keychain accessibility. [CITED: developer.apple.com/documentation/authenticationservices/aswebauthenticationsession] |
| Android `androidx.browser:browser` | `1.9.0` minimum for `AuthTabIntent`; pin exact resolved version | Auth Tab-first hosted auth with Custom Tabs fallback | The official API states AuthTab supports exact custom-scheme or HTTPS host/path returns and was added in 1.9.0. [CITED: developer.android.com/reference/androidx/browser/auth/AuthTabIntent] |
| Android Keystore + AES-GCM + internal app-specific storage | Platform APIs | Refresh ciphertext at rest | Android documents non-exportable Keystore keys and inaccessible-to-other-apps internal storage. [CITED: developer.android.com/privacy-and-security/keystore] |

### Supporting

| Library / component | Version | Purpose | When to Use |
|---------------------|---------|---------|-------------|
| XCTest/XCUITest | Xcode-managed | iOS status-surface assertions and lifecycle driving | Only against a resolved physical iPhone destination for NAT-01. [VERIFIED: CONTEXT.md] |
| AndroidX Test / Espresso or Compose test APIs | Pin with Android project | In-process idling-aware assertions | Use for native app state, not browser/system windows. [VERIFIED: CONTEXT.md] |
| Android UI Automator | Pin with Android project | Cross-app browser/system interaction | Use for Auth Tab/Custom Tab and system boundaries; Android documents it as cross-app instrumentation. [CITED: developer.android.com/training/testing/other-components/ui-automator] |
| Android emulator console / `adb` | Pin SDK image and command-line tools | Transport disable/verification and force-stop/relaunch | The official console supports emulated network characteristics; orchestration must verify all transports are disabled before the offline scenario. [CITED: developer.android.com/studio/run/emulator-console] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `ASWebAuthenticationSession` | `WKWebView` | Excluded: embedded authentication violates D-05’s system-browser boundary. [VERIFIED: CONTEXT.md] |
| `AuthTabIntent` first | Custom Tabs only | Custom Tabs is the required bounded fallback, not the preferred lane. [VERIFIED: CONTEXT.md] |
| Attached physical iPhone | iOS Simulator / Playwright emulation | Excluded: cannot satisfy NAT-01’s required execution class. [VERIFIED: CONTEXT.md] |
| Host-owned receipt | Crosswake telemetry alone | Excluded: Crosswake telemetry lacks target identity, artifact completeness, and terminal proof ownership. [VERIFIED: CONTEXT.md] |

**Installation / verification:** Do not add a new Hex dependency: the example already pins both released packages. The Android shell adds only the official exact AndroidX coordinates listed under “Resolved for planning.” Plan 248-08 validates their Google Maven metadata and locks resolved hashes before build; this satisfies the project’s automation-first rule while preserving the fact that the npm/PyPI/crates legitimacy seam does not cover Maven. [VERIFIED: repository source and AGENTS.md]

## Package Legitimacy Audit

| Package | Registry | Publish date | Source Repo | Verdict | Disposition |
|---------|----------|--------------|-------------|---------|-------------|
| `crosswake` 0.2.0 | Hex.pm | 2026-07-03 | Installed locked dependency | Existing released package | Reuse; no install task. [VERIFIED: Hex.pm registry] |
| `crosswake_sigra` 0.1.3 | Hex.pm | 2026-08-09 | Installed locked dependency | Existing released package | Reuse; no install task. [VERIFIED: Hex.pm registry] |
| `androidx.browser:browser` 1.9.0 and exact AndroidX Test coordinates | Google Maven | Pinned in Plan 248-08 | AndroidX official artifacts | Official docs identify these exact stable artifacts; the configured npm/PyPI/crates seam is inapplicable. | Validate official Google Maven metadata and lock resolved hashes before use. [CITED: developer.android.com/reference/androidx/browser/auth/AuthTabIntent] |

**Packages removed due to `[SLOP]` verdict:** none — the configured legitimacy seam only accepts npm/PyPI/crates, so it is inapplicable to existing Hex and potential Maven dependencies. [VERIFIED: package-legitimacy seam]

## Architecture Patterns

### System Architecture Diagram

```text
  iOS physical iPhone                         Android pinned emulator
  ASWebAuthenticationSession                  AuthTabIntent -> Custom Tabs fallback
          | exact callback/state                       | exact callback/state
          +-------------------+------------------------+
                              v
                  Phoenix hosted PKCE / code exchange
                              |
                              v
                 Sigra opaque app-session authority
                 (fresh validity + revocation lookup)
                              |
         +--------------------+---------------------+
         v                                          v
  CrosswakeSessionAdapter                    LearningTwin host APIs
  derives opaque bounded facts                manifest, seven-day lease,
  -> Crosswake evaluator                      partition, terminal replay
         |                                          |
         v                                          v
  NativeEvidence / telemetry               Native encrypted refresh +
  (allowlisted facts only)                  verified media/cache + outbox
         \____________________  ____________________/
                              v
                 platform-specific receipt validator
                 target identity + scenario booleans +
                 artifact hashes + secret scan + cleanup
```

### Recommended Project Structure

```text
test/example/
├── lib/example/accounts/                 # extend fact-only Crosswake projection only
├── native/ios/SigraNativeProof/          # host-owned Swift shell + XCUITest target
├── native/android/                       # host-owned Kotlin shell + instrumentation
├── priv/native-fixtures/                 # test-only non-secret status/transport fixtures
└── test/                                 # ExUnit host/projection tests
scripts/ci/
├── crosswake-native-ios-proof.sh         # attached-device receipt-last orchestration
├── crosswake-native-android-proof.sh     # emulator lifecycle/transport orchestration
└── lib/native-proof-receipt.*             # common schema, SHA, redaction, secret scan
.planning/phases/248-crosswake-native-proof/
└── 248-*-EVIDENCE.json                   # separate iOS/Android terminal receipts
```

### Pattern 1: Fresh host authority, then fact-only Crosswake projection

**What:** Reuse `Example.Accounts.CrosswakeSessionAdapter`: resolve the raw host credential only inside the host, construct a fresh binding, evaluate with Crosswake facts, and deny unavailable/mismatched/stale state. [VERIFIED: repository source]

**When to use:** Every native route/replay request and callback completion; never permit a native assertion or local cached fact to select the account or route. [VERIFIED: CONTEXT.md]

```elixir
# Source: test/example/lib/example/accounts/crosswake_session_adapter.ex
with {:ok, binding} <- CrosswakeSessionAdapter.expected_binding(host_token, now),
     {:allow, facts} <- CrosswakeSessionAdapter.evaluate(host_token, now, route, binding) do
  # Pass only `facts` into Crosswake; host retains credentials and authority.
end
```

### Pattern 2: Native evidence after local validation, never as authority

**What:** Build `NativeEvidence` only after the shell has checked its callback/state locally; the host independently validates its PKCE attempt and one-time code before issuing a session. The contract admits posture fields, not secret values. [VERIFIED: repository source]

```elixir
# Source: test/example/deps/crosswake_sigra/lib/crosswake/companions/sigra/auth_return.ex
{:ok, evidence} = AuthReturn.new_native_evidence(
  transport: :verified_https_link,
  platform: :ios,
  link_verification: :verified,
  callback_binding: :matched,
  replay: :not_seen
)
```

### Pattern 3: Status-surface proof, not credential extraction

**What:** The shell exposes a test-only, stable accessibility/status surface containing only approved enums/booleans. Tests assert a store transition (`present -> rotated -> recovered -> deleted`) and `access_persisted: false`; comparison of rotating values happens internally. [VERIFIED: CONTEXT.md]

### Anti-Patterns to Avoid

- **Embedding a WebView or direct password form:** it bypasses the required hosted public-client ceremony. [VERIFIED: CONTEXT.md]
- **Treating an Activity recreation as relaunch:** Android NAT-02 requires host-orchestrated force-stop and cold relaunch. [VERIFIED: CONTEXT.md]
- **Recording callback URLs or secret values in screenshots/logs/receipts:** the installed `AuthReturn` and telemetry contracts explicitly forbid that class of data. [VERIFIED: repository source]
- **Claiming physical radio-off on iPhone:** use the controlled transport-failure fixture and name the claim precisely. [VERIFIED: CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Native browser authentication | Embedded HTML auth view or ad-hoc URL handler | `ASWebAuthenticationSession`; Android Auth Tab/Custom Tabs | Platform components manage the external browser experience and documented callback route. [CITED: developer.apple.com/documentation/authenticationservices/aswebauthenticationsession] |
| Secure refresh persistence | Raw file/preferences token store | Keychain; Android Keystore AES-GCM plus internal storage | Platform storage APIs provide the intended key protection boundary. [CITED: developer.android.com/privacy-and-security/keystore] |
| Replay protocol | New mobile sync vocabulary | Released Crosswake journal/replay fields + existing `LearningTwin` terminal store | Existing contract already fixes identity and three terminal outcomes. [VERIFIED: repository source] |
| Native target proof | Screenshots or a generic CI success flag | Receipt-last schema validator with target/toolchain identity, SHA bindings, scenario matrix, cleanup and secret scan | Browser/simulator evidence cannot prove the required device class. [VERIFIED: CONTEXT.md] |

**Key insight:** This phase is integration evidence around already-owned boundaries; a general native SDK, reusable offline framework, or Crosswake authority layer would expand scope and weaken the proof. [VERIFIED: CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Crosswake receives a credential or makes an authorization decision
**What goes wrong:** A convenience adapter passes raw callback/token/session/account data or accepts an outcome as authoritative. [VERIFIED: repository source]

**How to avoid:** Enforce a negative test against `NativeEvidence`, telemetry, and retained receipts; only project allowlisted fields after fresh Sigra/Phoenix resolution. [VERIFIED: repository source]

### Pitfall 2: Native proof overclaims its target or transport
**What goes wrong:** A simulator, emulation, unsupported browser component, or iPhone controlled failure is reported as a physical/offline proof. [VERIFIED: CONTEXT.md]

**How to avoid:** Make target class, UDID/device model (redacted/pseudonymous as needed), browser/toolchain, selected fallback, transport method and completion gate mandatory receipt fields. [VERIFIED: CONTEXT.md]

### Pitfall 3: Credential tests leak the very credential they test
**What goes wrong:** Logs, test failures, screenshots, or persisted receipt capture refresh/access/callback material. [VERIFIED: CONTEXT.md]

**How to avoid:** Return only posture fields, run a post-artifact secret scan, delete app/test artifacts at cleanup, and fail closed on a scan match. [VERIFIED: CONTEXT.md]

### Pitfall 4: Android offline/relaunch is not actually offline/process death
**What goes wrong:** Network is only throttled, or an Activity restart leaves in-memory state alive. [VERIFIED: CONTEXT.md]

**How to avoid:** Host orchestration disables/verifies all emulator transports, calls `adb shell am force-stop`, starts a fresh process, and checks the status surface after cold launch. [VERIFIED: CONTEXT.md]

## Code Examples

### Crosswake-compatible replay request

```elixir
# Source: test/example/deps/crosswake/lib/crosswake/offline/replay.ex
request = Crosswake.Offline.Replay.new_request(
  route_id: "lesson",
  sync_seam: "learning_twin",
  journal_entry_id: local_entry_id,
  client_mutation_id: mutation_id,
  idempotency_key: idempotency_key,
  base_checkpoint: checkpoint,
  payload: %{}
)

# Phoenix host reloads current Scope/lease/partition and returns exactly one
# `accepted`, `rejected`, or `conflict` outcome; it does not delegate that decision.
```

### iOS Keychain posture configuration

```swift
// Source: https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility
// The concrete accessibility constant is selected in Wave 0 after confirming
// foreground/relaunch requirements; emitted tests report only posture.
let query: [String: Any] = [
  kSecClass as String: kSecClassGenericPassword,
  kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
  kSecValueData as String: refreshCredentialData
]
```

### Android Keystore-bound ciphertext record

```kotlin
// Source: https://developer.android.com/privacy-and-security/keystore
// Persist `{nonce, ciphertext, keyAlias, version}` in filesDir; never persist access.
val cipher = Cipher.getInstance("AES/GCM/NoPadding")
cipher.init(Cipher.ENCRYPT_MODE, androidKeyStoreSecretKey)
val ciphertext = cipher.doFinal(refreshCredential.toByteArray())
```

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| Deprecated iOS callback-scheme initializer | `ASWebAuthenticationSession.Callback` supports exact custom-scheme or HTTPS host/path matching | Prefer the current callback API and still perform application-level state/callback checks. [CITED: developer.apple.com/documentation/authenticationservices/aswebauthenticationsession] |
| Custom Tabs-only Android auth | `AuthTabIntent` first (added in AndroidX Browser 1.9.0), Custom Tabs fallback | Record and gate on actual browser capability; do not assume Auth Tab support. [CITED: developer.android.com/reference/androidx/browser/auth/AuthTabIntent] |
| UI tests using fixed delays | Espresso/Compose synchronization and UI Automator condition waits | Aligns with the project’s deterministic/no-sleeps constraint. [CITED: developer.android.com/training/testing/other-components/ui-automator] |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | An exact `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` choice is compatible with all required iPhone relaunch scenarios. | Code Examples | The iOS shell would need a different most-restrictive Keychain accessibility class. |
| A2 | A pinned Android emulator/browser can exercise the selected Auth Tab capability. | Standard Stack | The fallback or a different pinned browser/transport must be used. |
| A3 | The selected attached-device runner/device lab can expose sufficient physical-target identity without retaining a stable device identifier. | Summary | NAT-01 cannot be completed until a provider and receipt-safe identity method are selected. |

## Resolved for planning

1. **Physical-iPhone runner:** NAT-01 selects a repository-managed self-hosted Apple-silicon macOS runner carrying the exact labels `self-hosted`, `macOS`, `ARM64`, and `sigra-ios-physical`, with one directly attached, paired, trusted physical iPhone. Plan 248-08 is a prerequisite provisioning gate: it requires `SIGRA_IOS_DEVICE_UDID` and `SIGRA_IOS_DEVELOPMENT_TEAM`, resolves the UDID through `xcrun xctrace list devices`, rejects simulator/unavailable destinations, and writes only a redacted device class/OS plus a digest-scoped runner binding. No such destination is currently visible locally, so execution remains fail-closed until that runner is actually provisioned. [VERIFIED: local environment and CONTEXT.md D-10]
2. **Callback transports:** both proof shells use the already selected exact registered custom schemes: iOS `sigra-native-proof://auth/callback` and Android `sigra-native-proof://auth/android`. Each shell performs exact callback and state checks and records `callback_transport: custom_scheme`, `link_verification: registered_scheme`, and `callback_binding: matched`; Android additionally records `browser_mode: auth_tab` or the allowed `custom_tab_fallback`. [VERIFIED: CONTEXT.md D-05 through D-07]
3. **Android build/test coordinates:** Plan 248-08 locks JDK 17; Gradle 8.13 with distribution SHA-256 `20f1b1176237254a6fc204d8434196fa11a4cfb387567519c61556e8710aed78`; AGP 8.13.2; Kotlin 2.2.10; compile/target SDK 36; Build Tools 35.0.0; Command-line Tools 23.0; Platform Tools 37.0.1; stable Emulator 37.1.11; `system-images;android-36;google_apis_playstore;x86_64` revision 7; AVD device `pixel_8`; AndroidX Browser 1.9.0; AndroidX Test runner/core 1.7.0; Espresso 3.7.0; and UI Automator 2.4.0. The selected browser is image-bundled `com.android.chrome`; provisioning must capture its exact installed version and APK SHA-256 into the committed lock before any Gradle build, and fail if the package, version, SHA, or Auth Tab/Custom Tabs capability is absent. This environment-derived browser identity avoids fabricating an unavailable APK while still making the downstream build consume an exact pre-build lock. [VERIFIED: official Android/Gradle release metadata; local toolchain remains unavailable]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Xcode / XCUITest tooling | iOS build/test | ✓ | Xcode 26.6 (17F113) | — [VERIFIED: local environment] |
| Attached physical iPhone | NAT-01 | ✗ | — | Provision attached macOS runner or device lab; simulator is not a fallback. [VERIFIED: CONTEXT.md] |
| Android SDK `adb`, emulator, AVD manager | NAT-02 | ✗ | — | Install pinned Android SDK/image/tooling; no local fallback. [VERIFIED: local environment] |
| Gradle | Android shell build | ✗ | — | Commit Gradle wrapper in host-owned shell. [VERIFIED: local environment] |
| Elixir/Mix + Node | Host tests/receipts | ✓ | OTP 28 / Node 22.14.0 | — [VERIFIED: local environment] |
| Docker | host test DB support | ✓ | Docker 29.5.2 | — [VERIFIED: local environment] |

**Missing dependencies with no fallback:** physical iPhone target; Android command-line toolchain/emulator.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Host contract framework | ExUnit in `test/example`; existing focused Crosswake and LearningTwin tests. [VERIFIED: repository source] |
| iOS | XCTest/XCUITest against a physical-device destination only. [VERIFIED: CONTEXT.md] |
| Android | Instrumentation with Espresso/Compose for in-app assertions and UI Automator for browser/system boundaries. [VERIFIED: CONTEXT.md] |
| Receipt validation | New deterministic script/schema test; receipt is written only after every scenario, source hash, cleanup and secret scan succeeds. [VERIFIED: CONTEXT.md] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| XW-01 | Fresh host authority / fact-only Crosswake projection, no-secret regression, replay vocabulary | ExUnit + Node prohibition | `cd test/example && mix test ...crosswake... && node --test scripts/ci/prohibitions/...` | Partial — existing adapter/prohibition precedent; native cases Wave 0. [VERIFIED: repository source] |
| NAT-01 | Entire iPhone scenario matrix and physical-target receipt | XCUITest + host script | `scripts/ci/crosswake-native-ios-proof.sh` | ❌ Wave 0 |
| NAT-02 | Entire emulator scenario matrix and emulator receipt | Gradle instrumentation + host script | `scripts/ci/crosswake-native-android-proof.sh` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** focused ExUnit/receipt-schema test plus the affected platform build/test when its toolchain is available. [VERIFIED: repository test pattern]
- **Per wave merge:** both platform receipt validators and host Crosswake/LearningTwin regression suites. [VERIFIED: CONTEXT.md]
- **Phase gate:** separately valid iOS physical and Android emulator receipts with no secret-scan findings. [VERIFIED: CONTEXT.md]

### Wave 0 Gaps

- [ ] `test/example/native/ios/...` Xcode project, app target, XCUITest target, physical-destination selector, test-only status surface.
- [ ] `test/example/native/android/...` Gradle wrapper/project, pinned emulator image/browser/dependencies, instrumentation target, status surface.
- [ ] `scripts/ci/crosswake-native-ios-proof.sh` and `scripts/ci/crosswake-native-android-proof.sh` with no sleeps and receipt-last behavior.
- [ ] Shared receipt schema/validator and bad/clean fixtures for secret scanning, wrong target, incomplete scenario, and source mismatch.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Hosted PKCE S256, exact callback/state, one-time code, Sigra-owned issuance. [VERIFIED: CONTEXT.md] |
| V3 Session Management | yes | Memory-only access, rotating refresh only, Keychain/Keystore boundary, fresh revocation lookup. [VERIFIED: CONTEXT.md] |
| V4 Access Control | yes | Host reloads current Scope/partition/lease; Crosswake/native cache cannot select authority. [VERIFIED: repository source] |
| V5 Input Validation | yes | Strict callback/link values, typed `NativeEvidence`, allowlisted receipt fields, secret scanner. [VERIFIED: repository source] |
| V6 Cryptography | yes | OS Keychain and Android Keystore AES-GCM; never custom cryptography. [CITED: developer.android.com/privacy-and-security/keystore] |

### Known Threat Patterns for Native Proof

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Callback/state substitution or replay | Spoofing/Tampering | Exact registered callback + state + PKCE + one-time host attempt; fail closed. [VERIFIED: CONTEXT.md] |
| Token extraction from storage or evidence | Information disclosure | Access memory-only; refresh OS-protected; posture-only status; receipt secret scan. [VERIFIED: CONTEXT.md] |
| Cached lesson survives account/revocation change | Elevation of privilege | Current partition/strict lease gate for local use; host reauthorizes every replay. [VERIFIED: repository source] |
| Browser/target capability downgrade | Tampering | Record component/version/capability and reject missing verification/callback support. [VERIFIED: CONTEXT.md] |

## Sources

### Primary (HIGH confidence)

- `test/example/mix.lock`, `test/example/deps/crosswake/**`, and `test/example/deps/crosswake_sigra/**` — installed released contracts, prohibited fields, native evidence and replay types. [VERIFIED: repository source]
- [Hex.pm crosswake 0.2.0 release](https://hex.pm/api/packages/crosswake/releases/0.2.0) and [crosswake_sigra 0.1.3 release](https://hex.pm/api/packages/crosswake_sigra/releases/0.1.3) — current pinned version and publish metadata. [VERIFIED: Hex.pm registry]
- `test/example/lib/example/accounts/crosswake_session_adapter.ex`, `learning_twin.ex`, and existing receipt-last proof — host authority and evidence patterns. [VERIFIED: repository source]

### Secondary (MEDIUM confidence)

- [ASWebAuthenticationSession](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession), [Keychain accessibility](https://developer.apple.com/documentation/security/restricting-keychain-item-accessibility) — iOS browser/session and storage APIs. [CITED: developer.apple.com]
- [AuthTabIntent](https://developer.android.com/reference/androidx/browser/auth/AuthTabIntent), [Android Keystore](https://developer.android.com/privacy-and-security/keystore), [app-specific storage](https://developer.android.com/training/data-storage/app-specific), [UI Automator](https://developer.android.com/training/testing/other-components/ui-automator), [emulator console](https://developer.android.com/studio/run/emulator-console) — Android auth/storage/test/transport APIs. [CITED: developer.android.com]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — released package source and registry are locally/officially verifiable; Android/iOS platform APIs are officially cited.
- Architecture: HIGH — locked phase decisions match existing adapter and LearningTwin boundaries.
- Pitfalls: HIGH — derived from locked evidence requirements and installed contracts.

**Research date:** 2026-08-19
**Valid until:** 2026-09-18 for package/platform details; recheck AndroidX and device-lab availability at implementation.
