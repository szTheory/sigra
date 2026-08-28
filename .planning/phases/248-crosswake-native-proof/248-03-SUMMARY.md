---
phase: 248-crosswake-native-proof
plan: "03"
subsystem: native-ios-proof
tags: [swift, xcode, aswebauthenticationsession, keychain, xcuitest, offline]
requires:
  - phase: 248-02
    provides: Fail-closed native receipt and Crosswake authority/redaction guards
  - phase: 248-08
    provides: Read-only validated iOS proof environment lock
provides:
  - Host-owned iOS app, unit-test, and UI-test targets without a reusable SDK product
  - Exact custom-scheme hosted PKCE adapter with memory-only access and passcode-bound Keychain refresh rotation
  - Marker-last verified lesson storage, strict lease/partition gates, and host-terminal replay journal
  - Contract-only stable XCUITest surface for all NAT-01 scenarios
affects: [248-04, ios-physical-proof, crosswake-native-proof]
actuals:
  tokens: 17351
  tasks: 2
  commits: 4
tech-stack:
  added: [XcodeGen 2.46.0 build-time generator]
  patterns: [exact callback-state validation, posture-only secure storage, marker-last activation, contract-only launch fixtures]
key-files:
  created:
    - test/example/native/ios/SigraNativeProof/SigraNativeProof.xcodeproj/project.pbxproj
    - test/example/native/ios/SigraNativeProof/App/HostedAuthSession.swift
    - test/example/native/ios/SigraNativeProof/App/SecureRefreshStore.swift
    - test/example/native/ios/SigraNativeProof/App/NativeLessonStore.swift
    - test/example/native/ios/SigraNativeProof/App/NativeProofStatusView.swift
    - test/example/native/ios/SigraNativeProof/Tests/NativeContractTests.swift
    - test/example/native/ios/SigraNativeProof/UITests/NativeProofUITests.swift
  modified:
    - test/example/native/ios/SigraNativeProof/App/SigraNativeProofApp.swift
key-decisions:
  - "Keep logout local-first and treat server revocation as a host-driven refresh denial because the generated Phase 246 family-revocation route belongs to the authenticated browser owner."
  - "Label launch-environment scenarios contract_only; simulator UI evidence does not satisfy NAT-01 physical/live-host proof."
  - "Generate the project with XcodeGen but commit only the plan-owned pbxproj; signing team, device identity, and signing identity remain process-only for Plan 04."
patterns-established:
  - "Native status surfaces expose only exact booleans/enums and stable accessibility identifiers."
  - "Media bodies become usable only after length/SHA verification, atomic promotion, and a final activation marker."
requirements-completed: [XW-01]
coverage:
  - id: D1
    description: Exact ASWebAuthenticationSession callback/state/PKCE and Keychain rotation posture are implemented without persisted access material.
    requirement: XW-01
    verification:
      - kind: unit
        ref: NativeContractTests#hosted request, callback denial, Keychain posture, exact storage allowlist
        status: pass
      - kind: integration
        ref: xcodebuild generic/platform=iOS build-for-testing
        status: pass
    human_judgment: false
  - id: D2
    description: Native lesson media, strict lease, partition cleanup, relaunch, revocation, and host-terminal replay are fail-closed and durable.
    verification:
      - kind: unit
        ref: NativeContractTests#media integrity, strict expiry, partition lifecycle, exactly-once replay
        status: pass
    human_judgment: false
  - id: D3
    description: Every planned iOS scenario has a synchronized contract-only XCUITest hook with truthful controlled transport labeling.
    verification:
      - kind: automated_ui
        ref: NativeProofUITests#testContractOnlyFixtureExposesEverySynchronizedNativeScenario
        status: pass
      - kind: unit
        ref: node --test scripts/ci/prohibitions/p17-crosswake-native-boundary.test.mjs
        status: pass
    human_judgment: false
duration: 30min
completed: 2026-08-28
status: complete
---

# Phase 248 Plan 03: Host-Owned iOS Native Proof Shell Summary

**Unsigned iOS app/test targets now enforce exact hosted PKCE return validation, passcode-bound refresh rotation, verified bounded lesson storage, and synchronized contract-only scenario hooks.**

## Performance

- **Duration:** 30 min
- **Started:** 2026-08-28T18:04:00Z
- **Completed:** 2026-08-28T18:34:20Z
- **Tasks:** 2/2
- **Files modified:** 8

## Accomplishments

- Built the full app/unit/UI Xcode target graph with an exact registered `sigra-native-proof://auth/callback` scheme, unsigned generic-device build support, and no framework/library product.
- Added system-browser PKCE S256 initiation, exact callback/state checks, one-time exchange/refresh adapters, memory-only access, and `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` refresh persistence with exact posture categories.
- Added exact length/SHA media verification, marker-last activation, strict microsecond lease checks, partition-first cleanup, relaunch verification, offline audio readiness, and credential-free replay with host-only terminal outcomes.
- Added a Proof-configuration-only status view and deterministic XCUITest matrix using stable identifiers, bounded readiness predicates, and no fixed sleeps.

## Task Commits

1. **Task 1 RED: hosted auth and storage contracts** — `333f041a`
2. **Task 1 GREEN: hosted session and secure refresh boundary** — `68d9dcb0`
3. **Task 2 RED: lesson and synchronized UI contracts** — `789b1580`
4. **Task 2 GREEN: bounded lesson store and proof surface** — `026c8f40`

## Verification Evidence

- `scripts/ci/native-proof-provision.sh --validate-ios-lock` — passed read-only validation.
- `xcodebuild ... -destination 'generic/platform=iOS' build-for-testing` — passed unsigned app/unit/UI target build.
- `xcodebuild ... -only-testing:SigraNativeProofTests test` — 8 tests passed.
- `xcodebuild ... -only-testing:SigraNativeProofUITests test` — 1 synchronized scenario-matrix test passed.
- Release generic-device app build — passed with `NATIVE_PROOF` excluded.
- Native receipt and P17 Node matrix — 7 tests passed.
- Source scans found no persisted development team, signing identity, UDID, provisioning profile, fixed sleep, embedded browser, direct-password path, or framework/library product.

## Decisions Made

- The Swift HTTP adapter mirrors only the existing Phase 246 `/users/app-login`, `/api/app-login/exchange`, and `/api/app-login/refresh` contracts. It does not invent a native revocation authority.
- Local logout clears access and Keychain refresh before any further use. Host-driven family revocation is observed as refresh denial and clears the same local material.
- Simulator and launch-fixture evidence is explicitly `contract_only`; the status surface reports `controlled_transport_failure` and never claims radio disconnection.
- NAT-01 remains pending because physical-device, live-host, receipt-last execution belongs to Plan 04.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Bounded obsolete media after successful promotion.**
- **Found during:** Task 2 final threat scan
- **Issue:** Per-file size limits alone allowed obsolete verified versions to accumulate in a partition.
- **Fix:** Remove stale `.media` files after new verified bodies promote and before the final activation marker is written.
- **Files modified:** `NativeLessonStore.swift`
- **Verification:** Unit and UI suites plus P17 passed after the change.
- **Committed in:** `026c8f40`

**2. [Rule 3 - Build Scaffold] Generated the plan-owned project from a temporary XcodeGen specification.**
- **Found during:** Task 1 scaffold
- **Issue:** The repository had no prior Swift/Xcode project, while executor guidance requires XcodeGen and the plan owns only `project.pbxproj`.
- **Fix:** Installed the official Homebrew `xcodegen` 2.46.0 formula, generated all targets/configurations, removed generator-only files, and verified auto-created scheme discovery through `xcodebuild`.
- **Files modified:** `project.pbxproj`
- **Verification:** Generic iOS build-for-testing, simulator unit/UI tests, and Release build passed.
- **Committed in:** `333f041a`, `789b1580`, `026c8f40`

**Total deviations:** 2 auto-fixed (Rule 2: 1, Rule 3: 1). No product scope or authority boundary expanded.

## Issues Encountered

- Plan 02's original P17 reader attempted to read the native directory as a file once Swift sources existed. Prerequisite commit `a5e9c7fc` fixed deterministic recursive source scanning before final verification.
- The shared receipt validator and retained fixture disagreed on Git-SHA length. Prerequisite commits `1248c79a` and `6722ec39` aligned the 40-hex implementation binding while retaining 64-hex artifact digests.
- The example host does not yet install Phase 246 app-session routes/profile policy. Plan 03 therefore proves the exact client contract without claiming a live hosted exchange; the backend prerequisite and device-reachable orchestration remain upstream of Plan 04.

## Known Stubs

None. The `contract_complete` launch fixture is an intentionally labeled deterministic contract surface, not physical/live-host evidence.

## User Setup Required

None for Plan 03. Physical signing/team/device inputs remain process-only prerequisites for Plan 04.

## Next Phase Readiness

Plan 04 can consume the unsigned app/test bundles and stable hooks through `build-for-testing` / `test-without-building`, then bind physical target identity and redacted xcresult attachment diagnostics into a receipt-last lane. It must first supply the host app-session/profile route prerequisite and must not promote this plan's simulator/fixture results to NAT-01.

## Self-Check: PASSED

- All plan-owned source, project, test, and summary files exist.
- All four task commits are present in repository history.
- Automated unit, UI, release-boundary, receipt, and P17 verification evidence is recorded above.

---
*Phase: 248-crosswake-native-proof*
*Completed: 2026-08-28*
