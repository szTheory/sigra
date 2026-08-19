# Phase 248: Crosswake Native Proof - Pattern Map

**Mapped:** 2026-08-19  
**Files analyzed:** 18 planned new/modified artifacts  
**Analogs found:** 14 / 18

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `test/example/lib/example/accounts/crosswake_session_adapter.ex` | service | request-response | same file | exact |
| `test/example/test/example/accounts/crosswake_session_adapter_test.exs` | test | request-response | same file | exact |
| `test/example/lib/example/learning_twin.ex` | service/controller | CRUD | same file | exact |
| `test/example/test/example/learning_twin/learning_twin_test.exs` | test | CRUD | same file | exact |
| `test/example/native/ios/SigraNativeProof/SigraNativeProofApp.swift` | component | request-response | no native analog | none |
| `test/example/native/ios/SigraNativeProof/SecureRefreshStore.swift` | service | file-I/O | no native analog | none |
| `test/example/native/ios/SigraNativeProofTests/SigraNativeProofUITests.swift` | test | event-driven | `test/example/priv/playwright/tests/twin-offline.spec.ts` | flow-match |
| `test/example/native/android/app/src/main/java/.../NativeProofActivity.kt` | component | request-response | no native analog | none |
| `test/example/native/android/app/src/main/java/.../SecureRefreshStore.kt` | service | file-I/O | no native analog | none |
| `test/example/native/android/app/src/androidTest/java/.../NativeProofInstrumentedTest.kt` | test | event-driven | `test/example/priv/playwright/tests/twin-offline.spec.ts` | flow-match |
| `test/example/native/android/gradle/libs.versions.toml` | config | batch | `test/example/mix.lock` | partial |
| `test/example/priv/native-fixtures/native-proof-status.json` | config | request-response | `test/example/priv/static/learning-twin-offline.html` + `learning_twin.js` | partial |
| `scripts/ci/lib/native-proof-receipt.mjs` | utility | transform | `scripts/ci/lib/exact-sha-worktree.sh` | flow-match |
| `scripts/ci/lib/native-proof-receipt.test.mjs` | test | transform | `scripts/ci/prohibitions/p14-crosswake-authority-secrets.test.mjs` | role-match |
| `scripts/ci/crosswake-native-ios-proof.sh` | utility | batch | `scripts/ci/hosted-session-interop-proof.sh` | exact |
| `scripts/ci/crosswake-native-android-proof.sh` | utility | batch | `scripts/ci/hosted-session-interop-proof.sh` | exact |
| `scripts/ci/prohibitions/p17-crosswake-native-boundary.test.mjs` | test | transform | `scripts/ci/prohibitions/p14-crosswake-authority-secrets.test.mjs` | exact |
| `.planning/phases/248-crosswake-native-proof/248-{IOS,ANDROID}-EVIDENCE.json` | config/evidence | batch | phase 240.3 host evidence written by `hosted-session-interop-proof.sh` | role-match |

The native project paths are intentionally host-owned examples, not an SDK. Keep the exact Swift/Kotlin package and Xcode project filenames within these directories at implementation time; no existing native source pattern exists to copy.

## Pattern Assignments

### `test/example/lib/example/accounts/crosswake_session_adapter.ex` (service, request-response)

**Analog:** same file, `Example.Accounts.CrosswakeSessionAdapter`.

**Imports and boundary declaration** (lines 1-15):

```elixir
@moduledoc """
Host-owned projection boundary between a current SIGRA session cookie and the
released Crosswake evaluator.

The raw cookie is used only for canonical host lookup. Crosswake receives
newly derived, keyed opaque references and server-owned session facts.
"""

alias Crosswake.Companions.Sigra.Contracts
alias Crosswake.Companions.Sigra.Evaluator
alias Crosswake.Companions.Sigra.AuthReturn
alias Example.Accounts
```

**Core authority pattern** (lines 89-105): resolve the host token afresh, compare an opaque binding, construct Crosswake facts only after that, and deny before evaluator invocation.

```elixir
with {user, session} <- Accounts.get_user_and_session_by_token(raw_token),
     :ok <- validate_current_session(session, as_of),
     current_binding <- binding(user, session),
     :ok <- match_binding(expected_binding, current_binding),
     {:ok, lane} <- new_lane(current_binding, session, as_of),
     {:ok, context} <- Contracts.new_auth_context(%{session_authority_lane: lane}),
     evaluator_result <- evaluator(opts).(route, context,
       expected_session_version: current_binding.session_version
     ) do
  format_evaluator_result(evaluator_result, current_binding)
else
  nil -> deny(:session_unavailable)
  {:error, :session_unavailable} -> deny(:session_unavailable)
  {:error, :binding_mismatch} -> deny(:binding_mismatch)
  {:error, _contract_error} -> deny(:projection_failed)
end
```

**Native-evidence application:** extend `evaluate_return/6` (lines 139-147), not a new authority path. Construct/validate `AuthReturn.NativeEvidence` only after the native shell’s exact callback/state checks; still call `evaluate/5` with host-derived route and binding. Do not add credentials, callback URLs, account IDs, or terminal outcomes to the Crosswake projection.

### `test/example/test/example/accounts/crosswake_session_adapter_test.exs` (test, request-response)

**Analog:** same file.

**Negative security matrix** (lines 400-424): table-test forbidden fields against the released contract, then assert rejection rather than merely checking output shape.

```elixir
for field <- [:session_ref, :subject_ref, :org_id, :authority_state,
             :access_granted, :grant_access, :access_token, :stored_digest,
             :provider_payload, :authorization_code] do
  assert {:error, errors} =
           AuthReturn.new_envelope(Map.put(valid_return_envelope(), field, "smuggled"))

  assert Enum.any?(errors, fn
           {:auth_return_envelope, {^field, rejection}}
           when rejection in [:forbidden, :unsupported_claim] -> true
           _ -> false
         end)
end
```

**Host-precedence assertion** (lines 367-397): inject a capturing evaluator, assert the expected session version, then assert only opaque facts/evidence return. Add iOS and Android native evidence cases to this same style, including revoked session and binding mismatch denial before the evaluator.

### `test/example/lib/example/learning_twin.ex` and `test/example/test/example/learning_twin/learning_twin_test.exs` (service/test, CRUD)

**Analog:** same module and test.

**Trusted-scope and strict-seven-day lease pattern** (`learning_twin.ex` lines 128-150):

```elixir
case Repo.one(from l in Lease,
       where: l.user_id == ^user_id, order_by: [desc: l.expires_at], limit: 1) do
  nil -> {:error, :unavailable}
  lease -> if(lease_valid?(lease, as_of), do: {:ok, lease}, else: {:error, :expired})
end

with {:ok, lease} <- active_lease(scope, opts),
     true <- is_binary(partition) and partition == lease.account_partition do
  {:ok, lease}
else
  false -> {:error, :partition_mismatch}
  {:error, _reason} = error -> error
end
```

**Exactly-once terminal replay pattern** (`learning_twin.ex` lines 167-175 and 197-225): normalize the complete request, reload the current lease from trusted scope, and use a transaction plus unique `[:account_partition, :idempotency_key]` conflict target. The database record, not Crosswake or a native outbox, decides the terminal result.

```elixir
with {:ok, normalized} <- normalize_replay(params),
     {:ok, lease} <- active_lease(scope),
     {:ok, receipt} <- persist_terminal_receipt(user_id, lease.account_partition, normalized) do
  {:ok, receipt}
end

Repo.insert(ReplayReceipt.changeset(%ReplayReceipt{}, attrs),
  on_conflict: :nothing,
  conflict_target: [:account_partition, :idempotency_key]
)
```

**Tests to copy:** exact-expiry is invalid (`learning_twin_test.exs` lines 43-56); sequential and concurrent duplicate replay yield one stored receipt (lines 112-150). Extend these host tests only for the released Crosswake request/outcome vocabulary mapping—retain `LearningTwin` as terminal authority.

### iOS shell, Keychain service, and XCUITest (component/service/test, request-response/file-I/O/event-driven)

**Closest analog:** `test/example/priv/static/assets/js/learning_twin.js` for bounded offline lifecycle; no Swift or XCUITest source exists.

**Behavior to port, not browser storage:** `learning_twin.js` lines 203-245 verifies every media body against manifest byte count and SHA-256, records only a partition/lease activation after all media is ready, and refuses offline rendering if lease, partition, marker, or cache verification fails. Preserve this fail-closed ordering in the native cache.

```javascript
if (bytes.byteLength !== item.byte_size || await digest(bytes) !== item.sha256.toLowerCase())
  throw new Error('media-integrity-failed');
await cachePut(cache, item, bytes);
await put('media_markers', markerKey(partition, item), { partition, url: item.url, version: item.version, ready: true });
```

**Implementation-specific new pattern:** use `ASWebAuthenticationSession` for browser continuation; validate exact callback transport and state in the app before emitting only posture fields. Keep access material in memory. `SecureRefreshStore.swift` persists the refresh credential only in Keychain with the final, compatibility-tested restrictive accessibility class; its status API and UI accessibility identifiers expose only `present`, `rotated`, `recovered`, `deleted`, read/decrypt category, and `access_persisted=false`.

**XCUITest pattern:** use stable accessibility identifiers/labels from the dedicated test-only status surface and XCTest expectations—never fixed sleeps. The iOS proof script, not the test alone, selects and rejects anything other than a physical `platform=iOS` destination.

### Android shell, Keystore service, Gradle pin, and instrumentation test (component/service/config/test, request-response/file-I/O/batch/event-driven)

**Closest analog:** browser lesson/offline lifecycle above; no Kotlin or Android project exists.

**Implementation-specific new pattern:** begin hosted authentication with `AuthTabIntent` only if the pinned browser capability is established, then use Custom Tabs only as the declared fallback. Persist exactly `{nonce, ciphertext, keyAlias, version}` in `filesDir`, encrypted with a non-exportable AndroidKeyStore AES-GCM key. Access material remains memory-only. Emit the same posture-only status surface as iOS.

**Instrumentation split:** Espresso/Compose synchronization owns in-app assertions; UI Automator owns auth browser/system windows; `crosswake-native-android-proof.sh` owns `adb shell am force-stop`, fresh launch, transport disable/verification, selected-browser version capture, cleanup, and receipt sealing. Do not represent Activity recreation as process death and do not use sleeps.

**Pinning:** the Gradle version catalog must pin AndroidX Browser (at least `1.9.0`) and every test/emulator dependency, and the Android receipt must capture resolved component/image/browser versions. This is a new config role with no same-language analog; `test/example/mix.lock` is only the project precedent for committed dependency coordinates.

### `test/example/priv/native-fixtures/native-proof-status.json` (config, request-response)

**Closest analog:** `learning_twin.js` status and deterministic failure injection lines 193-211, plus the worker’s message fixture at `learning-twin-worker.js` lines 4-8.

**Pattern:** make fixtures non-secret and explicit: controlled iPhone transport failure, native callback/link failure, browser capability unavailable, and test-account scenario controls. The test-visible result must be a fixed, allowlisted status object/enum; never fixture or retain refresh/access material, PKCE state/verifier, raw callback, account identifier, or device identifier.

### `scripts/ci/crosswake-native-{ios,android}-proof.sh` (utility, batch)

**Analog:** `scripts/ci/hosted-session-interop-proof.sh`.

**Shell safety and bounded command pattern** (lines 5-32):

```bash
set -euo pipefail

run_bounded() {
  local label="$1"
  shift
  printf '==> %s\n' "${label}"
  perl -e 'alarm shift; exec @ARGV' "${TIMEOUT_SECONDS}" "$@"
}
```

**Receipt-last and exact-source binding** (lines 245-259): bind a clean worktree SHA before commands, execute all scenario/secret-scan/cleanup checks, reassert the unchanged SHA, then write the receipt as the sole allowed worktree change.

```bash
TESTED_SIGRA_SHA="$(bind_clean_worktree_sha "${ROOT_DIR}" "${EVIDENCE_RELATIVE_PATH}")" ||
  fail "worktree must be clean before proof execution"

# run all target, scenario, source, scan, and cleanup checks here

assert_same_clean_worktree_sha "${ROOT_DIR}" "${EVIDENCE_RELATIVE_PATH}" "${TESTED_SIGRA_SHA}" ||
  fail "worktree or HEAD changed during proof execution"
write_evidence
```

Use separate scripts and receipts: iOS must reject simulator/Xcode Cloud destinations and label its fixture result `controlled_transport_failure`; Android must prove pinned emulator identity plus all transports disabled before local behavior. Both scripts need trap-based cleanup and redacted diagnostics like `redacted_server_diagnostics` (lines 52-57).

### `scripts/ci/lib/native-proof-receipt.mjs`, its tests, and phase evidence JSON (utility/test/config, transform)

**Analogs:** `scripts/ci/lib/exact-sha-worktree.sh` and the JSON writer in `hosted-session-interop-proof.sh` lines 107-226.

**Schema pattern:** construct a small allowlisted object containing schema version, source SHA, target class (exactly `physical_iphone` or `android_emulator`), redacted target identity, toolchain/browser versions, declared callback/transport posture, scenario booleans, artifact SHA-256 values, cleanup status, secret-scan result, and terminal completion. Validate all required keys and fail closed for missing/incorrect target, missing scenario, source mismatch, secret scan failure, or cleanup failure. Write `.planning/.../248-IOS-EVIDENCE.json` and `248-ANDROID-EVIDENCE.json` only after validation.

**Test pattern:** mirror the injected-fact adapter in `p14-crosswake-authority-secrets.test.mjs` lines 13-59: define required fields/types, run the same validator over a known-bad fixture and a known-clean fixture, and make empty/invalid parsed facts a test error rather than a pass.

### `scripts/ci/prohibitions/p17-crosswake-native-boundary.test.mjs` (test, transform)

**Analog:** `scripts/ci/prohibitions/p14-crosswake-authority-secrets.test.mjs`.

**Repository fact derivation** (lines 62-79): read named source artifacts, strip comments, derive a compact boolean/count fact shape, and enforce marker floors. Extend this approach to prove that native shells do not contain `WKWebView`/`WebView` authentication, raw credential/status leakage, or direct-password shortcuts; native receipts do not allow forbidden keys; and host code is still the source of terminal outcome.

## Shared Patterns

### Fresh host authority and Crosswake facts

**Sources:** `test/example/lib/example/accounts/crosswake_session_adapter.ex` lines 89-105 and 195-223.  
**Apply to:** native callback completion and every app-session native route/replay request.

Resolve the raw credential only in Sigra/Phoenix, derive opaque references with the host secret, compare the expected current binding in constant time, and project the allowlisted lane into Crosswake. A native claim must not choose the account, route, authorization, lease, or outcome.

### Evidence and telemetry allowlist

**Sources:** `test/example/deps/crosswake_sigra/lib/crosswake/companions/sigra/auth_return.ex` lines 47-58, 336-341, and 432-444; `telemetry.ex` lines 27-68 and 150-166.  
**Apply to:** both shells, adapter tests, telemetry, secret scanner, and receipts.

`NativeEvidence` is limited to transport, platform, link verification, callback binding, replay posture, and optional opaque assertion ref. Telemetry drops forbidden metadata including access/refresh tokens, authorization codes, device/account IDs, PKCE verifier, session refs, and raw return data.

### Lease, partition, media, and replay fail-closed behavior

**Sources:** `test/example/lib/example/learning_twin.ex` lines 123-175 and 197-280; `learning_twin.js` lines 203-245 and 254-292.  
**Apply to:** native media cache, offline launch, account switch/logout/revocation behavior, and replay bridge.

Treat exact lease expiry as invalid; bind all local state to the current partition; validate byte size plus SHA before activation; clear state on account change; preserve client mutation ID/idempotency key/base checkpoint; let the host emit the one terminal `accepted`, `rejected`, or `conflict` result.

### Deterministic receipt-last proof

**Sources:** `scripts/ci/hosted-session-interop-proof.sh` lines 27-57 and 245-260; `scripts/ci/lib/exact-sha-worktree.sh` lines 10-71.  
**Apply to:** iOS lane, Android lane, receipt validator, and test fixtures.

Use bounded commands and deterministic readiness; redact diagnostics; require a clean/source-bound worktree; run target/scenario/cleanup/scanning validations before writing a receipt; reject invalid target identity rather than downgrading the claim.

## No Analog Found

| File/group | Role | Data Flow | Reason |
|---|---|---|---|
| iOS Swift shell, Keychain wrapper, Xcode project, XCUITest target | component/service/test/config | request-response, file-I/O, event-driven | Repository has no Swift/Xcode source. Use the locked Apple APIs and status-surface contract; do not invent an SDK. |
| Android Kotlin shell, Keystore wrapper, Gradle project, instrumentation target | component/service/test/config | request-response, file-I/O, event-driven | Repository has no Kotlin/Gradle source. Use pinned official Android APIs and the host script lifecycle split. |
| Native receipt schema/validator | utility/config | transform | Existing scripts establish receipt-last and source binding but no target-aware native schema. |

## Metadata

**Analog search scope:** `test/example/lib`, `test/example/test`, `test/example/priv`, `scripts/ci`, installed `crosswake` and `crosswake_sigra` dependency sources.  
**Files scanned:** 15 source/test/script files plus both phase inputs.  
**Pattern extraction date:** 2026-08-19
