# Phase 248 Multi-Source Coverage Audit

## Deterministic planner probes

- API coverage detector: **detected**. `COVERAGE.md` enumerates the released Crosswake capability surface with explicit decisions and reasons.
- Assumption delta: **not detected** (`assumption-delta scan 248 --json` returned `detected: false`), so no `<assumption_delta_decision>` is required.
- Schema push detection: **not detected**. ROADMAP, CONTEXT, RESEARCH, and plan scope contain no Payload, Prisma, Drizzle, Supabase, or TypeORM schema path; no schema-push task is emitted.
- Spec-less edge report: XW-01, NAT-01, and NAT-02 remain explicit unresolved/flagged assumptions in plan frontmatter.
- Prohibition recall: the three kept product-specific authority/evidence-truth prohibitions are descriptor-less, flagged, and unverified. Canon security concerns are handled by each plan's STRIDE model rather than minted as fallback prohibitions.

## Coverage

| Source | ID | Item | Plan | Status | Notes |
|---|---|---|---|---|---|
| GOAL | — | Same first-party session/offline contract through Crosswake, physical iPhone, Android emulator without companion auth authority | 01–07 | COVERED | Tracer, two platform implementations, separate receipts, convergence gate. |
| REQ | XW-01 | Released Crosswake/Crosswake Sigra, fact-only route/replay projection | 01, 02, 03, 05, 07 | COVERED | Exact locked packages and coverage matrix. |
| REQ | NAT-01 | Automated physical-iPhone full scenario proof | 03, 04, 07 | COVERED | Shell → physical receipt → convergence. |
| REQ | NAT-02 | Automated Android-emulator equivalent proof | 05, 06, 07 | COVERED | Pinned shell → emulator receipt → convergence. |
| ROADMAP | SC-1 | Released packages and no Crosswake authentication authority | 01, 02, 07 | COVERED | Fresh host lookup, typed evidence, prohibition guard. |
| ROADMAP | SC-2 | Physical iPhone covers hosted login, Keychain, media/audio, lease, relaunch, isolation, revocation, replay | 03, 04 | COVERED | All scenarios required in receipt schema. |
| ROADMAP | SC-3 | Android emulator covers hosted login, Keystore, media/offline/relaunch, isolation, revocation, replay | 05, 06 | COVERED | Pinned toolchain and transport/process controls. |
| CONTEXT | D-01 | Extend fresh host-owned projection seam | 01 | COVERED | `CrosswakeNativeBridge` delegates after fresh lookup. |
| CONTEXT | D-02 | Map Phase 247 identity/outcomes to released journal/replay while host decides | 01, 03, 05 | COVERED | Bridge and both local journals. |
| CONTEXT | D-03 | Consume crosswake 0.2.0/crosswake_sigra 0.1.3; host shells only | 01, 03, 05 | COVERED | Exact Hex lock; no library products. |
| CONTEXT | D-04 | Allowlisted facts only | 01, 02, 03, 05, 07 | COVERED | Typed NativeEvidence, telemetry/status/receipt allowlists. |
| CONTEXT | D-05 | Hosted PKCE only; no embedded/direct password | 03, 05 | COVERED | ASWebAuthenticationSession and Auth Tab/Custom Tabs only. |
| CONTEXT | D-06 | iOS ASWebAuthenticationSession and exact callback | 03 | COVERED | Exact custom scheme and state validation. |
| CONTEXT | D-07 | Android Auth Tab preferred, bounded Custom Tabs fallback | 05, 06 | COVERED | Capability/version receipt. |
| CONTEXT | D-08 | Memory-only access; Keychain/Keystore refresh | 03, 05 | COVERED | Platform stores and tests. |
| CONTEXT | D-09 | Posture-only credential evidence | 02, 03, 05 | COVERED | Shared status schema and secret guard. |
| CONTEXT | D-10 | Exact physical-iPhone XCUITest | 04, 07 | COVERED | Physical destination hard gate. |
| CONTEXT | D-11 | Pinned emulator; synchronized test ownership; no sleeps | 05, 06 | COVERED | Espresso/UI Automator/host split. |
| CONTEXT | D-12 | Separate complete receipt-last lanes | 02, 04, 06 | COVERED | Shared schema plus separate receipts. |
| CONTEXT | D-13 | Every missing/wrong/incomplete condition fails claim | 02, 04, 06, 07 | COVERED | Negative fixtures and convergence. |
| CONTEXT | D-14 | Android all-transports-off; iPhone controlled fixture label | 02, 04, 06 | COVERED | Target-specific receipt validation. |
| CONTEXT | D-15 | Target/toolchain/scenario/hash/cleanup data phase-owned | 02, 04, 06, 07 | COVERED | Narrow Crosswake telemetry; broad phase receipts. |
| RESEARCH | Primary recommendation | XW-01 first, then separate native shells/lanes | 01–06 | COVERED | Wave ordering follows recommendation. |
| RESEARCH | Package legitimacy | Reuse exact Hex packages; pin official Maven coordinates | 01, 05, 06 | COVERED | No npm/pip/cargo installs; version catalog/toolchain lock. |
| RESEARCH | Host authority pattern | Fresh lookup before fact projection | 01 | COVERED | Tracer tests denial precedence. |
| RESEARCH | Native evidence pattern | Validate locally before NativeEvidence | 01, 03, 05 | COVERED | Platform callback tests plus bridge. |
| RESEARCH | Status posture pattern | Internal comparisons; enums/booleans only | 02, 03, 05 | COVERED | Shared fixture/validator. |
| RESEARCH | Evidence pattern | Bounded receipt-last exact-source proof | 02, 04, 06, 07 | COVERED | Shared writer and per-lane scripts. |
| RESEARCH | Open Q1 | Physical runner/device destination | 04 | COVERED | Explicit user_setup/precondition; simulator rejected. |
| RESEARCH | Open Q2 | Callback transport | 03, 05 | COVERED | Planner discretion chooses exact custom schemes and records posture. |
| RESEARCH | Open Q3 | Android toolchain/browser versions | 05, 06 | COVERED | Exact catalog and toolchain lock before execution. |
| VALIDATION | W0-1 | iOS app/XCUITest/status surface | 03 | COVERED | Exact project/source/test paths. |
| VALIDATION | W0-2 | Android Gradle/instrumentation/status surface | 05 | COVERED | Exact project/source/test paths. |
| VALIDATION | W0-3 | Separate no-sleep proof scripts | 04, 06 | COVERED | Hermetic script tests and real lanes. |
| VALIDATION | W0-4 | Shared receipt schema with bad/clean fixtures | 02 | COVERED | Node schema and prohibition guards. |
| PATTERN | Fresh host authority | Adapter resolves raw credential before evaluator | 01 | COVERED | Existing adapter is preserved. |
| PATTERN | Lease/partition/media/replay fail closed | Port Phase 247 behavior, not browser storage | 01, 03, 05 | COVERED | Native stores mirror contract. |
| PATTERN | Script safety/source binding | `set -euo pipefail`, bounded commands, exact SHA, receipt last | 04, 06, 07 | COVERED | Separate scripts and convergence. |
| PATTERN | No native analog | Use host-owned platform projects, not SDKs | 03, 05 | COVERED | New app-only roots. |

## Exclusions (not gaps)

- Published Swift/Kotlin SDKs or UI kits: deferred by CONTEXT and REQUIREMENTS.
- Generic offline/background sync/media framework: deferred by CONTEXT and REQUIREMENTS.
- Electron implementation: Phase 249.
- Physical Android hardware and physical-iPhone radio-off claim: explicitly out of Phase 248.
- Sibling Crosswake/Lockspire source changes and OAuth/OIDC authorization-server behavior: milestone exclusions.

All required sources are covered; no unplanned item remains.

