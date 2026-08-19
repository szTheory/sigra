# Phase 248 External Package/API Coverage

The deterministic API coverage detector fired for the released Crosswake package integration. The phase integrates the complete capability surface needed by XW-01 and explicitly excludes unrelated released capabilities.

| capability | decision | reason |
|---|---|---|
| `crosswake` 0.2.0 native shell/core contract | INTEGRATE | D-03 requires the released native-shell boundary for both host-owned example shells. |
| `Crosswake.Offline.Journal` entry vocabulary | INTEGRATE | D-02 maps the native outbox identity onto the released journal fields. |
| `Crosswake.Offline.Replay` request vocabulary | INTEGRATE | D-02 requires released request construction for replay correlation. |
| `Crosswake.Offline.Replay` accepted/rejected/conflict outcomes | INTEGRATE | D-02 requires exact mapping while the Phoenix host remains terminal authority. |
| `Crosswake.Companions.Sigra.AuthReturn.NativeEvidence` | INTEGRATE | D-03/D-04 require typed fact-only native return evidence after local validation. |
| `Crosswake.Companions.Sigra.AuthReturn.Envelope` | INTEGRATE | The existing host adapter validates the released return envelope before evaluation. |
| `Crosswake.Companions.Sigra.Evaluator` route decision | INTEGRATE | D-01 extends the existing fresh-host projection seam without moving authority. |
| `Crosswake.Companions.Sigra.Telemetry` allowlist/filter | INTEGRATE | D-04/D-15 require bounded native outcome telemetry and forbidden-field filtering. |
| Crosswake auth handoff contracts | OPT-OUT | Phase 246 hosted PKCE and one-time code exchange remain the sole native login ceremony. |
| Crosswake passkey return contracts | OPT-OUT | Phase 248 proves hosted public-client login, not a passkey ceremony. |
| Crosswake step-up contracts | OPT-OUT | Step-up issuance and consumption are outside XW-01/NAT-01/NAT-02. |
| Crosswake OAuth evidence contracts | OPT-OUT | OAuth/OIDC delegation belongs to Lockspire and is outside the first-party session proof. |
| Crosswake route registry generation | OPT-OUT | The example extends an existing host-owned route projection and does not publish a registry or SDK. |
| Crosswake reusable native SDK/UI surface | OPT-OUT | D-03 and milestone exclusions permit only host-owned example shells and phase evidence. |

## Multi-Source Coverage Audit

| SOURCE | ID | Feature / requirement | Plan | Status | Notes |
|---|---|---|---|---|---|
| GOAL | — | Demonstrate one first-party session/offline contract through released Crosswake, a physical iPhone, and an Android emulator without companion authority | 01-08 | COVERED | Host contract, exact provisioning, separate platform lanes, and convergence are all executable. |
| REQ | XW-01 | Released Crosswake projection without credentials or authentication authority | 01, 02, 07 | COVERED | Fresh host lookup, released vocabulary, prohibition guard, and final gate. |
| REQ | NAT-01 | Complete automated physical-iPhone behavior/evidence matrix | 08, 03, 04, 07 | COVERED | Selected runner is locked before shell build; physical receipt remains mandatory. |
| REQ | NAT-02 | Complete automated Android-emulator behavior/evidence matrix | 08, 05, 06, 07 | COVERED | Exact toolchain/browser/wrapper lock precedes build and proof. |
| CONTEXT | D-01 | Fresh Sigra/host authority and bounded Crosswake facts | 01, 03, 05 | COVERED | Native and replay paths preserve host ownership. |
| CONTEXT | D-02 | Released journal/replay identity and accepted/rejected/conflict mapping | 01, 03, 05 | COVERED | Host remains terminal store/decision authority. |
| CONTEXT | D-03 | Exact released package versions; host-owned shells only | 01, 02, 03, 05, 07 | COVERED | No SDK/publication surface. |
| CONTEXT | D-04 | Exact fact allowlist; no credentials/authority/stable identity | 01, 02, 03, 05, 07 | COVERED | Recursive validator and P17 red/green fixtures enforce it. |
| CONTEXT | D-05 | Hosted public-client PKCE; no embedded/direct login | 03, 05 | COVERED | Exact callback/state and system-browser components. |
| CONTEXT | D-06 | ASWebAuthenticationSession and truthful callback posture | 08, 03, 04 | COVERED | Exact custom scheme selected and locked. |
| CONTEXT | D-07 | Auth Tab-first Android with bounded Custom Tabs fallback | 08, 05, 06 | COVERED | Browser package/version/SHA/capability is locked before build. |
| CONTEXT | D-08 | Memory-only access and OS-protected rotating refresh | 03, 05 | COVERED | Exact Keychain class and Keystore AES-GCM boundary. |
| CONTEXT | D-09 | Full posture-only storage fields/enums, no secret/stable identity | 02, 03, 04, 05, 06, 07 | COVERED | Exact seven-field object and four read categories are named across schema, shells, receipts, and convergence. |
| CONTEXT | D-10 | Exact automated physical-iPhone destination | 08, 04 | COVERED | Selected self-hosted runner contract fails closed on simulator/unavailable device. |
| CONTEXT | D-11 | Pinned Android image/browser/test stack and true host controls | 08, 05, 06 | COVERED | Exact versions, wrapper hashes, transport disablement, and force-stop/cold-start. |
| CONTEXT | D-12 | Complete separate platform scenario matrices | 02, 03, 04, 05, 06 | COVERED | All eleven scenario booleans are explicit. |
| CONTEXT | D-13 | Wrong/missing/incomplete/stale evidence fails | 02, 04, 06, 07 | COVERED | Receipt validators and final convergence hard-fail. |
| CONTEXT | D-14 | Android transport-off; iPhone controlled failure only | 02, 04, 06, 07 | COVERED | Target-specific transport enums/booleans prevent overclaim. |
| CONTEXT | D-15 | Target/toolchain/hash/cleanup/scan truth stays phase-owned | 02, 04, 06, 07 | COVERED | Exact shared and target receipt allowlists are final-gated. |
| RESEARCH | — | Pre-build physical-runner and Android coordinate provisioning | 08 | COVERED | Research open questions are resolved to a fail-closed prerequisite; absent local resources are not fabricated. |
| RESEARCH | — | Checksum-pinned Gradle wrapper exists before any `./gradlew` call | 08, 05 | COVERED | Distribution and wrapper-JAR hashes validate first. |
| RESEARCH | — | System browser, secure storage, verified media/lease/partition/replay patterns | 01, 03, 05 | COVERED | Platform shells use official APIs and existing host behavior. |
| RESEARCH | — | Deterministic synchronization, bounded commands, receipt-last evidence, no sleeps | 02, 04, 06, 07, 08 | COVERED | Hermetic negative tests and terminal receipts cover all lanes. |
| RESEARCH | — | Exact shared/platform receipt contracts and prohibition enforcement | 02, 03, 04, 05, 06, 07 | COVERED | Unknown, secret-shaped, stable-identity, or target-incompatible fields reject. |

Deferred native SDKs/UI kits, generic offline/background sync, Electron implementation, physical Android hardware, and iPhone radio-off claims are explicit exclusions and are not audit gaps.
