---
phase: 248-crosswake-native-proof
plan: "08"
subsystem: native-proof-provisioning
tags: [android, ios, gradle, hosted-proof]
status: complete
---

# Phase 248 Plan 08: Native proof environment locks Summary

Hosted Android provisioning produced and verified an exact, checksum-pinned toolchain lock and Gradle 8.13 wrapper receipt for the fresh Play Store emulator image.

## Delivered

- Installed the five byte-validated Android receipt artifacts under `test/example/native/android/`.
- Kept physical-iPhone and Android provisioning fail-closed, with read-only iOS lock validation.
- Added deterministic hosted-proof hardening for fresh AVDs, ADB keys, Chrome readiness/capability, split APK hashing, wrapper generation, and artifact validation.

## Verification Evidence

- Hosted workflow run `33197745294`, job `98939111138`, head `19a8b141bd3f86b51fea03377e22bb57e924eada` succeeded.
- The downloaded archive was independently validated with exact five payload files, lock mode `0600`, executable `gradlew` mode `0755`, and `0644` wrapper files.
- Artifact validator and `--validate-android-lock` both passed against the extracted receipt.
- Local `bash -n`, provisioning tests, and the same tests under `umask 077` passed.
- Local `gradlew --version` was not run because this macOS host lacks Java; the successful hosted JDK 17 receipt executed the generated Gradle 8.13 wrapper.

## Decisions Made

- Treat fresh private AVD provenance, pinned image revision, wipe/no-snapshot launch, package identity, and APK-content hashes as the Chrome evidence chain; do not infer provenance from the mutable `/data/app` path.
- Keep receipt acceptance archive-first: validate members, bytes, modes, lock schema, and wrapper digest before installation.
- Require predicate-based consecutive readiness samples rather than fixed post-boot sleeps.

## Automation Lessons

- Hosted Android emulator proof needs private ADB keys and post-boot package-manager readiness, not merely `sys.boot_completed`.
- Package-manager component enumeration must request component-only output and fail closed on metadata or foreign components.

## Deviations from Plan

None - the hosted environment required iterative fail-closed hardening to satisfy the planned proof boundary.

## Self-Check: PASSED

- Receipt artifacts exist and their committed lock validates locally.
- Task receipt commit: `6273a1de`.
