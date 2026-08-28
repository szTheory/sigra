---
phase: 248-crosswake-native-proof
plan: "05"
subsystem: android-native-proof-shell
tags: [android, kotlin, keystore, custom-tabs, espresso, uiautomator]
requires:
  - phase: 248-08
    provides: Checksum-pinned Gradle wrapper, Android toolchain lock, and declared Chrome fallback capability
  - phase: 248-09
    provides: Exact Android callback profile and fresh-authority native host routes
provides:
  - Application-only Android 36 shell with exact custom-scheme return handling
  - Locked Chrome Custom Tabs fallback with Auth Tab capability-gated code path
  - Keystore-bound refresh ciphertext store with memory-only access posture
  - Marker-last verified media, strict lease, partition isolation, and host-terminal replay contracts
  - Synchronized JVM and instrumentation contracts ready for Plan 248-06 emulator orchestration
affects: [248-06, NAT-02, android-emulator-proof]
actuals:
  tokens: 15720
  tasks: 2
  commits: 7
tech-stack:
  added: [AGP 8.13.2, Kotlin 2.2.10, AndroidX Browser 1.9.0, AndroidX Activity 1.9.0, Espresso 3.7.0, UI Automator 2.4.0]
  patterns: [application-only native shell, capability-gated hosted browser, encrypted-record-only persistence, marker-last activation, external-orchestration status hooks]
key-files:
  created:
    - test/example/native/android/settings.gradle.kts
    - test/example/native/android/gradle/libs.versions.toml
    - test/example/native/android/app/build.gradle.kts
    - test/example/native/android/app/src/main/java/dev/sigra/proof/HostedAuthSession.kt
    - test/example/native/android/app/src/main/java/dev/sigra/proof/SecureRefreshStore.kt
    - test/example/native/android/app/src/main/java/dev/sigra/proof/NativeLessonStore.kt
    - test/example/native/android/app/src/test/java/dev/sigra/proof/NativeProofContractTest.kt
  modified:
    - .github/workflows/terminal-ratification-evidence.yml
key-decisions:
  - "Execute the committed custom_tab_fallback lock even when the provider advertises Auth Tab; Auth Tab is reachable only when both the immutable lock and runtime capability agree."
  - "Permit emulator-host cleartext only in the debug variant for exact host 10.0.2.2; release remains explicitly cleartext-denied."
  - "Keep force-stop, cold-start, transport-disablement, and terminal NAT-02 claims pending external Plan 248-06 orchestration."
patterns-established:
  - "Storage posture exposes exactly seven allowlisted fields and never persists access material."
  - "Media bytes and markers are durable before the partition activation marker; exact microsecond expiry fails closed."
requirements-completed: [XW-01]
coverage:
  - id: D1
    description: Pinned application-only Android shell with exact callback and declared browser fallback
    requirement: XW-01
    verification:
      - kind: integration
        ref: "GitHub Actions run 33202645131 job 98955682528: dependencies assembleDebug assembleDebugAndroidTest testDebugUnitTest"
        status: pass
    human_judgment: false
  - id: D2
    description: Keystore posture and bounded offline lesson/replay contracts
    requirement: NAT-02
    verification:
      - kind: unit
        ref: "NativeProofContractTest.kt: 8 JVM tests, 0 failures/errors/skips"
        status: pass
      - kind: integration
        ref: "NativeProofInstrumentedTest.kt compiled into app-debug-androidTest.apk in run 33202645131"
        status: pass
    human_judgment: false
duration: 22min
completed: 2026-08-28
status: complete
---

# Phase 248 Plan 05: Android Native Proof Shell Summary

**A pinned Android application now compiles substantive hosted-auth, Keystore, verified-media, lease, isolation, and host-terminal replay contracts without overstating emulator runtime evidence.**

## Performance

- **Duration:** 22 minutes
- **Started:** 2026-08-28T18:53:19Z
- **Completed:** 2026-08-28T19:15:23Z
- **Tasks:** 2
- **Files modified:** 15

## Accomplishments

- Built an application-only Android 36 shell with the exact registered `sigra-native-proof://auth/android` callback in both initial-intent and `onNewIntent` paths.
- Pinned Browser 1.9.0 and the test toolchain, executing only the committed `custom_tab_fallback` lock while retaining a capability-gated Auth Tab path.
- Added AndroidKeyStore AES-GCM refresh storage that persists only `{nonce,ciphertext,keyAlias,version}`, keeps access in memory, and distinguishes missing, corrupt, and unavailable-key reads.
- Added byte-length/SHA-256 media verification, marker-last activation, strict microsecond lease expiry, partition clearing, credential-free journaling, and exactly-once host terminal outcomes.
- Compiled synchronized Espresso/UI Automator instrumentation and passed eight substantive JVM contracts on hosted JDK 17.

## Task Commits

1. **RED native behavior contracts** — `e30064ca`
2. **Task 1: pinned Android proof application** — `8419cb2f`
3. **Task 2: secure storage and lesson lifecycle** — `0e097fcb`
4. **Scoped hosted compile evidence lane** — `36c2f1b0`
5. **AndroidX runtime correction** — `75852f60`
6. **Build-type cleartext isolation** — `1e3ec775`
7. **Lifecycle-aware Auth Tab launcher correction** — `bf9fdea0`

## Verification Evidence

- Successful hosted run: `33202645131`; job: `98955682528`; exact implementation SHA: `bf9fdea085d8ad86cac9a610e04e498ae0410d83`.
- Real commands passed: `dependencies`, `assembleDebug`, `assembleDebugAndroidTest`, and `testDebugUnitTest` under Temurin JDK 17.
- Independently downloaded artifact summary: 8 JVM tests, 0 failures, 0 errors, 0 skips; app APK, test APK, and dependency-output SHA-256 values all matched the sealed summary.
- Local immutable wrapper/toolchain validation, receipt tests, P17 native boundary tests, XML/YAML syntax checks, no-sleeps scan, and application-only publication scan passed.
- The successful run artifact retains both APKs, dependency output, JUnit XML, and a machine-readable exact-SHA summary for seven days.

## Decisions Made

- Browser selection is a two-key decision: immutable lock plus verified provider capability. The committed fallback lock cannot execute Auth Tab even when Chrome later advertises it.
- Debug host injection is a non-secret Gradle property with a bounded `10.0.2.2` default; only the debug manifest relaxes cleartext for that exact destination.
- Status values remain `pending_external_orchestration` until Plan 248-06 proves the corresponding emulator/process/network event.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Enabled the AndroidX runtime explicitly.**
- **Found during:** Hosted Task 1 compile
- **Issue:** AGP rejected Browser 1.9.0 because the fresh project omitted `android.useAndroidX=true`.
- **Fix:** Added a bounded `gradle.properties` contract.
- **Verification:** The next run passed AAR metadata validation.
- **Committed in:** `75852f60`

**2. [Rule 1 - Bug] Isolated cleartext policy by build type.**
- **Found during:** Hosted manifest merge
- **Issue:** Main and debug manifests declared conflicting cleartext values.
- **Fix:** Kept the base manifest neutral, made debug permit only its exact network-security domain, and made release explicitly deny cleartext.
- **Verification:** Run `33202425386` passed manifest processing and reached Kotlin compilation.
- **Committed in:** `1e3ec775`

**3. [Rule 3 - Blocking] Added the explicit lifecycle compile surface required by Auth Tab.**
- **Found during:** Hosted Kotlin compilation
- **Issue:** Browser 1.9.0 references Activity Result APIs that were not exposed to the application compile classpath, and a plain `Activity` cannot register the launcher.
- **Fix:** Pinned the already-resolved AndroidX Activity 1.9.0 coordinate and used `ComponentActivity`.
- **Verification:** Run `33202645131` compiled both APKs and passed all JVM tests.
- **Committed in:** `bf9fdea0`

**Total deviations:** 3 auto-fixed (1 bug, 2 blocking issues). All were correctness fixes within the planned Android shell/toolchain surface.

## Threat Flags

| Flag | File | Description |
|---|---|---|
| threat_flag: debug-network-policy | `app/src/debug/res/xml/native_proof_network_security.xml` | Debug-only cleartext is allowlisted to exact emulator gateway `10.0.2.2`; base and release do not relax transport policy. |

## Known Stubs

None. `pending_external_orchestration` is the intentional fail-closed selector value consumed by Plan 248-06, not a completed scenario fixture.

## Requirement Status

- `XW-01` remains complete and the Android shell preserves its released Crosswake/host-authority boundary.
- `NAT-02` remains pending Plan 248-06. This plan proves buildable contracts and does not claim force-stop, cold-start, transport disablement, hosted return, or completed emulator scenarios.

## Next Phase Readiness

Plan 248-06 can consume the exact wrapper/lock, debug APK, instrumentation APK, stable hooks, and synchronized test contract. There is no human UAT step; the emulator runner must supply the remaining runtime evidence and seal the source-bound receipt.

## Self-Check: PASSED

- All 15 Plan 248-05 files exist.
- All seven plan commits exist in repository history.
- Hosted evidence is bound to `bf9fdea085d8ad86cac9a610e04e498ae0410d83` and contains nonzero passing JVM tests.
- NAT-02 is not marked complete.
