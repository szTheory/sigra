# Phase 248: Crosswake Native Proof - Context

**Gathered:** 2026-08-19 (assumptions mode)
**Status:** Ready for planning

<domain>
## Phase Boundary

Demonstrate the Phase 246 first-party app-session ceremony and the Phase 247 bounded offline lesson through released `crosswake` and `crosswake_sigra` contracts, one automated physical-iPhone lane, and one automated Android-emulator lane. The proof must keep Sigra and the Phoenix host authoritative, preserve Keychain/Keystore credential boundaries, and distinguish each execution target honestly. This phase does not publish native SDKs or UI kits, mutate sibling repositories, generalize offline behavior, implement an Electron application, or add OAuth/OIDC authorization-server behavior.

</domain>

<decisions>
## Implementation Decisions

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

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope and ownership
- `.planning/ROADMAP.md` § Phase 248 — fixed goal and physical-iPhone / Android-emulator success criteria.
- `.planning/REQUIREMENTS.md` § Crosswake and Platform Proof — XW-01, NAT-01, NAT-02, future SDK requirements, and milestone exclusions.
- `.planning/PROJECT.md` § Current Milestone: v1.49 FIRST-PARTY-CLIENT-READINESS — product intent and evidence-class constraints.
- `.planning/METHODOLOGY.md` — decisive-defaulting, escalation, research-depth, UX, and proof-truth lenses.
- `.planning/phases/243-credential-boundary-and-pipeline-foundation/243-CONTEXT.md` — normative Sigra/Lockspire/Crosswake/host ownership split.
- `.planning/phases/245-opaque-app-session-core/245-CONTEXT.md` — opaque credential lifetime, rotation, reuse, and revocation contract.
- `.planning/phases/246-hosted-and-direct-login-ceremonies/246-CONTEXT.md` — hosted system-browser PKCE ceremony and first-party public-client boundary.
- `.planning/phases/247-language-learning-digital-twin/247-CONTEXT.md` — verified media, lease, partition, replay, and deterministic proof decisions inherited by the native lanes.

### Repository architecture and prior art
- `.planning/research/ARCHITECTURE.md` — native/Crosswake ownership and bounded digital-twin flow.
- `.planning/research/STACK.md` — iOS/Android browser-link-storage recommendations and dependency posture.
- `.planning/research/PITFALLS.md` — cached-authority, account-isolation, credential, and evidence-overclaim failure modes.
- `test/example/mix.exs` and `test/example/mix.lock` — released `crosswake_sigra` 0.1.3 / `crosswake` 0.2.0 coordinates currently consumed by the example.
- `test/example/lib/example/accounts/crosswake_session_adapter.ex` — existing fresh host lookup and fact-only Crosswake projection seam.
- `test/example/lib/example/learning_twin.ex` — host-owned seven-day lease and exactly-once terminal replay authority.
- `test/example/priv/static/assets/js/learning_twin.js` and `test/example/priv/static/learning-twin-worker.js` — Phase 247 verified-media, partition, lease, and local-outbox behavior to reproduce through native shells.
- `scripts/ci/hosted-session-interop-proof.sh` and `test/example/priv/playwright/tests/twin-offline.spec.ts` — bounded receipt-last and deterministic offline proof patterns.

### Released Crosswake contracts
- `https://crosswake.hexdocs.pm/install.html` — Crosswake 0.2.0 released installation and native-core boundary.
- `https://crosswake.hexdocs.pm/native_shell.html` — scaffold-once host-owned native shell contract and evidence limitations.
- `https://crosswake-sigra.hexdocs.pm/0.1.3/Crosswake.Companions.Sigra.AuthReturn.html` — `NativeEvidence` and evidence-not-authority contract.
- `https://crosswake-sigra.hexdocs.pm/0.1.3/Crosswake.Companions.Sigra.Telemetry.html` — allowlisted native outcome telemetry and forbidden sensitive metadata.
- `https://hex.pm/api/packages/crosswake/releases/0.2.0` and `https://hex.pm/api/packages/crosswake_sigra/releases/0.1.3` — published release metadata to pin and validate.

### Platform automation and secure storage
- `https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession` — system-controlled browser authentication session and callback handling.
- `https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices` and `https://developer.apple.com/documentation/xcuiautomation/xcuiapplication` — physical destination and XCUITest lifecycle automation.
- `https://developer.apple.com/documentation/security/keychain-services` — Keychain secret persistence boundary.
- `https://developer.android.com/reference/androidx/browser/auth/AuthTabIntent` and `https://developer.android.com/develop/ui/views/layout/webapps/overview-of-android-custom-tabs` — Android system-browser components and callback handling.
- `https://developer.android.com/training/testing/other-components/ui-automator-legacy` and `https://developer.android.com/studio/test/command-line` — cross-app and command-line instrumentation mechanics.
- `https://developer.android.com/privacy-and-security/keystore` and `https://developer.android.com/training/data-storage/app-specific` — non-exportable key and app-private ciphertext boundary.
- `https://developer.android.com/studio/run/emulator-console` — emulator transport control used only for NAT-02.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Example.Accounts.CrosswakeSessionAdapter` already performs fresh authoritative session lookup, derives keyed opaque references, validates released return evidence separately, and denies binding mismatch or stale sessions.
- `Example.LearningTwin` and its controller/storage assets already implement strict lease expiry, versioned image/audio manifests, account partitioning, and durable exactly-once terminal receipts.
- Released dependency sources under `test/example/deps/crosswake/` and `test/example/deps/crosswake_sigra/` expose the exact journal/replay, native evidence, telemetry, and native-shell contracts to consume rather than recreate.
- The Phase 247 Playwright suite and hosted-session proof runner provide stable readiness, failure injection, prohibition checks, and receipt-last source binding patterns.

### Established Patterns
- Security-sensitive authority is library/host-owned; generated or companion runtimes consume bounded facts and fail closed.
- Test ownership follows the evidence class: browser proof cannot satisfy native, simulator cannot satisfy physical-device, and emulator cannot imply hardware-backed key storage.
- Long-running proof is bounded, deterministic, credential-free in retained output, and finalized only after source, scenario, cleanup, and redaction validation.
- Account ownership is derived from the current authenticated authority; request data, local cache state, or native callback evidence cannot select the owner.

### Integration Points
- Extend the example's released Crosswake projection and Phase 247 lesson/replay endpoints for app-session-authenticated native calls without moving host decisions into Crosswake.
- Add host-owned native shell fixtures adjacent to the example proof substrate, pinned to the released Crosswake native core coordinates discovered during research/planning.
- Add one macOS attached-device orchestration lane and one pinned Android-emulator orchestration lane, each producing a separate validated receipt and bounded diagnostics.
- Reuse `crosswake_sigra` `NativeEvidence` / telemetry only after platform callback facts are validated; keep exact target identity and artifact completeness in the phase-owned receipt.

</code_context>

<specifics>
## Specific Ideas

- Treat `ASWebAuthenticationSession` as the accepted iOS system-browser component while documenting that it is not a claim that standalone Safari launches.
- Use an app-private, test-only status surface that returns booleans/enums and never secret values so XCUITest/UI Automator can prove storage rotation, relaunch recovery, and deletion safely.
- Split Android force-stop/relaunch into two host-orchestrated instrumentation phases; Activity recreation alone is not process-death evidence.
- Preserve Crosswake's released proof vocabulary but add exact `physical_iphone` / `android_emulator` identity, hashes, and receipt ordering in the phase-owned evidence schema.

</specifics>

<deferred>
## Deferred Ideas

- Published Swift and Kotlin SDKs or UI kits — future SDK requirements after adopter evidence.
- Generic offline sync, background sync, reusable media-cache adapters, and additional offline islands — future work only after repeated host need.
- Electron runtime/package implementation — Phase 249 defines contract coverage without packaging an application.
- Physical Android hardware and iOS radio-level network-disconnection claims — not required by Phase 248 and not implied by the selected evidence lanes.

### Reviewed Todos (not folded)

None — no phase-matching todos were found.

</deferred>

---

*Phase: 248-crosswake-native-proof*
*Context gathered: 2026-08-19*
