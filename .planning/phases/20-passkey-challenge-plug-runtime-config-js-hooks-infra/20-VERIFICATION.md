---
phase: 20-passkey-challenge-plug-runtime-config-js-hooks-infra
verified: 2026-04-15T18:22:29Z
status: human_needed
score: 12/12 must-haves verified
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 10/12
  gaps_closed:
    - "PK-06 replay/tamper regression coverage runs reliably and proves invalid challenge tokens are rejected before callback execution."
    - "GEN-06 installer integration coverage passes under normal repo test settings."
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Run a real browser WebAuthn ceremony in a generated Phoenix app with `--passkeys` enabled."
    expected: "The generated `PasskeyRegister` / `PasskeyAuthenticate` hooks complete real browser ceremonies and surface success, error, and aborted outcomes correctly."
    why_human: "Automated coverage uses ExUnit and a Node stub; it does not exercise an actual browser WebAuthn stack or authenticator device."
  - test: "Use a non-standard asset entrypoint, apply the printed manual fallback instructions, and verify the app boots with passkey hooks wired."
    expected: "Sigra leaves the custom asset file untouched, the printed import and merged hook lines are sufficient, and the host app builds successfully after manual wiring."
    why_human: "Automated checks verify the exact fallback text, but not developer usability across real custom bundler layouts."
---

# Phase 20: Passkey Challenge Plug + Runtime Config + JS Hooks Infra Verification Report

**Phase Goal:** WebAuthn challenges are server-generated, server-stored in the signed+encrypted Plug session, and server-verified — making the OneUptime GHSA-gjjc-pcwp-c74m replay class impossible — and the JS hooks scaffolding that binds SimpleWebAuthn to LiveView ships with runtime-configured RP ID + graceful `app.js` injection.
**Verified:** 2026-04-15T18:22:29Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Challenge issuance signs `%{"c" => challenge}` with purpose `sigra-passkey-challenge`, `max_age: 60`, and stores only `%{"token" => signed_token}` in Plug session. | ✓ VERIFIED | [lib/sigra/plug/passkey_challenge.ex](/Users/jon/projects/sigra/lib/sigra/plug/passkey_challenge.ex:23) generates the token and stores only the token envelope; [test/sigra/plug/passkey_challenge_test.exs](/Users/jon/projects/sigra/test/sigra/plug/passkey_challenge_test.exs:57) verifies both ceremony issue paths. |
| 2 | Verification rebuilds a server-authoritative `Wax.Challenge` from the signed session payload and does not trust browser challenge authority. | ✓ VERIFIED | [lib/sigra/plug/passkey_challenge.ex](/Users/jon/projects/sigra/lib/sigra/plug/passkey_challenge.ex:46) verifies the signed token and rebuilds the challenge from decoded bytes; [test/sigra/plug/passkey_challenge_test.exs](/Users/jon/projects/sigra/test/sigra/plug/passkey_challenge_test.exs:96) proves server bytes win over browser-supplied bytes. |
| 3 | Registration and authentication use separate session slots and do not consume each other. | ✓ VERIFIED | Distinct slots are fixed at [lib/sigra/plug/passkey_challenge.ex](/Users/jon/projects/sigra/lib/sigra/plug/passkey_challenge.ex:13); slot separation is covered at [test/sigra/plug/passkey_challenge_test.exs](/Users/jon/projects/sigra/test/sigra/plug/passkey_challenge_test.exs:132). |
| 4 | Successful verification deletes only the matching slot; callback failure preserves the slot. | ✓ VERIFIED | Delete-on-success lives at [lib/sigra/plug/passkey_challenge.ex](/Users/jon/projects/sigra/lib/sigra/plug/passkey_challenge.ex:51); success and preserve-on-error are asserted at [test/sigra/plug/passkey_challenge_test.exs](/Users/jon/projects/sigra/test/sigra/plug/passkey_challenge_test.exs:96). |
| 5 | A tampered challenge token is deterministically rejected before `verify/5` reaches the callback. | ✓ VERIFIED | [test/sigra/plug/passkey_challenge_test.exs](/Users/jon/projects/sigra/test/sigra/plug/passkey_challenge_test.exs:162) flips a byte in the stored token, expects `:invalid`, and proves callback non-execution with `refute_received`; [lib/sigra/plug/passkey_challenge.ex](/Users/jon/projects/sigra/lib/sigra/plug/passkey_challenge.ex:77) returns token verification failures before challenge reconstruction. |
| 6 | `Sigra.Passkeys.config/0` resolves runtime config once and caches a validated `%Sigra.Config{}`. | ✓ VERIFIED | `:persistent_term` caching/reset is implemented at [lib/sigra/passkeys.ex](/Users/jon/projects/sigra/lib/sigra/passkeys.ex:36); cache and reset semantics are covered at [test/sigra/passkeys/config_test.exs](/Users/jon/projects/sigra/test/sigra/passkeys/config_test.exs:36). |
| 7 | Missing `rp_id` and `origin` fail loudly before ceremony code runs. | ✓ VERIFIED | Runtime validation enforces both fields at [lib/sigra/passkeys.ex](/Users/jon/projects/sigra/lib/sigra/passkeys.ex:253); missing-field cases are covered at [test/sigra/passkeys/config_test.exs](/Users/jon/projects/sigra/test/sigra/passkeys/config_test.exs:58). |
| 8 | Safe defaults remain in `%Sigra.Config{}` for `rp_name`, `attestation`, `user_verification`, `timeout_ms`, and `ceremony_rate_limit`. | ✓ VERIFIED | The passkey schema/defaults live at [lib/sigra/config.ex](/Users/jon/projects/sigra/lib/sigra/config.ex:448); default values are asserted at [test/sigra/passkeys/config_test.exs](/Users/jon/projects/sigra/test/sigra/passkeys/config_test.exs:41). |
| 9 | Per-user ceremony throttling uses `sigra:passkeys:<ceremony>:user:<user_id>` and denies the sixth hit in a 5/min window. | ✓ VERIFIED | Key construction and limiter dispatch are implemented at [lib/sigra/passkeys.ex](/Users/jon/projects/sigra/lib/sigra/passkeys.ex:55); exact namespace and sixth-hit denial are asserted at [test/sigra/passkeys/rate_limit_test.exs](/Users/jon/projects/sigra/test/sigra/passkeys/rate_limit_test.exs:34). |
| 10 | Standard Phoenix installs get generated `assets/js/passkey_hooks.js` plus deterministic `assets/js/app.js` marker wiring. | ✓ VERIFIED | Feature ownership and injection record are in [lib/sigra/install/features/passkeys.ex](/Users/jon/projects/sigra/lib/sigra/install/features/passkeys.ex:19); injector wiring is in [lib/sigra/install/injector.ex](/Users/jon/projects/sigra/lib/sigra/install/injector.ex:124); integration coverage is at [test/sigra/install/features/passkeys_js_test.exs](/Users/jon/projects/sigra/test/sigra/install/features/passkeys_js_test.exs:33). |
| 11 | Custom `app.js` layouts are left untouched and exact manual instructions are emitted instead of heuristic rewrites. | ✓ VERIFIED | Manual fallback is returned by [lib/sigra/install/injector.ex](/Users/jon/projects/sigra/lib/sigra/install/injector.ex:151) and surfaced through [lib/sigra/install/features/passkeys.ex](/Users/jon/projects/sigra/lib/sigra/install/features/passkeys.ex:49); the untouched-file/manual-text branch is covered at [test/sigra/install/features/passkeys_js_test.exs](/Users/jon/projects/sigra/test/sigra/install/features/passkeys_js_test.exs:62). |
| 12 | Generated JS hooks export `PasskeyRegister` / `PasskeyAuthenticate`, emit explicit success/error/aborted outcomes, and abort in-flight ceremonies on `destroyed` / `disconnected`. | ✓ VERIFIED | Hook exports and lifecycle cleanup live at [priv/templates/sigra.install/passkeys/passkey_hooks.js](/Users/jon/projects/sigra/priv/templates/sigra.install/passkeys/passkey_hooks.js:14); template/runtime coverage is at [test/sigra/install/features/passkeys_js_test.exs](/Users/jon/projects/sigra/test/sigra/install/features/passkeys_js_test.exs:86). |

**Score:** 12/12 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/sigra/plug/passkey_challenge.ex` | Plug-edge issue/verify adapter for WebAuthn challenges | ✓ VERIFIED | Substantive implementation, wired to token verification and ceremony builders. |
| `test/sigra/plug/passkey_challenge_test.exs` | PK-06 replay/tamper/single-use regression coverage | ✓ VERIFIED | Includes deterministic tamper rejection and callback-boundary proof. |
| `lib/sigra/config.ex` | Passkey runtime schema including `rp_name` and `ceremony_rate_limit` | ✓ VERIFIED | Schema defaults and docs include the required passkey runtime keys. |
| `lib/sigra/passkeys.ex` | Cached runtime config loader and per-user ceremony limiter | ✓ VERIFIED | Uses `:persistent_term`, runtime validation, and stable limiter key construction. |
| `test/sigra/passkeys/config_test.exs` | PK-09 runtime validation coverage | ✓ VERIFIED | Covers caching, reset, and fast-fail RP validation. |
| `test/sigra/passkeys/rate_limit_test.exs` | PK-10 per-user limiter coverage | ✓ VERIFIED | Covers exact key namespace and deny-shape mapping. |
| `priv/templates/sigra.install/passkeys/passkey_hooks.js` | Stable generated Phoenix passkey hook seam | ✓ VERIFIED | Exports both hooks and explicit browser abort/error handling. |
| `priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js` | Deterministic JS injection block | ✓ VERIFIED | Contains exact import, merged hooks line, and marker block. |
| `lib/sigra/install/injector.ex` | JS-specific `app.js` injector with manual fallback | ✓ VERIFIED | Handles idempotency, standard-shape injection, and manual fallback. |
| `test/sigra/install/features/passkeys_js_test.exs` | GEN-06 integration coverage under default verifier invocation | ✓ VERIFIED | Module-scoped timeout keeps the real rerun/idempotency path reliable under default test settings. |
| `test/support/install_fixture.ex` | Real tmp-app installer fixture path for GEN-06 coverage | ✓ VERIFIED | Still shells out through `mix sigra.install`; coverage remains integration-level, not mocked. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `lib/sigra/plug/passkey_challenge.ex` | `lib/sigra/token.ex` | `Sigra.Token.generate/4` and `Sigra.Token.verify/4` with purpose `sigra-passkey-challenge` | ✓ VERIFIED | `gsd-tools verify key-links` passed for Plan 20-01 and 20-04. |
| `lib/sigra/plug/passkey_challenge.ex` | `lib/sigra/passkeys/registration.ex` | `Registration.new_challenge/2` | ✓ VERIFIED | `gsd-tools verify key-links` passed for Plan 20-01. |
| `lib/sigra/plug/passkey_challenge.ex` | `lib/sigra/passkeys/authentication.ex` | `Authentication.new_challenge/2` | ✓ VERIFIED | `gsd-tools verify key-links` passed for Plan 20-01. |
| `lib/sigra/passkeys.ex` | `lib/sigra/config.ex` | `Sigra.Passkeys.config/0` builds cached validated config | ✓ VERIFIED | `gsd-tools verify key-links` passed for Plan 20-02. |
| `lib/sigra/passkeys.ex` | `lib/sigra/rate_limiter.ex` | `rate_limit_ceremony/3` calls configured limiter | ✓ VERIFIED | `gsd-tools verify key-links` passed for Plan 20-02. |
| `lib/sigra/install/features/passkeys.ex` | `priv/templates/sigra.install/passkeys/passkey_hooks.js` | Feature-owned generated file | ✓ VERIFIED | `gsd-tools verify key-links` passed for Plan 20-03. |
| `lib/sigra/install/features/passkeys.ex` | `lib/sigra/install/injector.ex` | Injection record + JS injector + manual fallback | ✓ VERIFIED | `gsd-tools verify key-links` passed for Plan 20-03. |
| `priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js` | `assets/js/app.js` | Merged hooks block preserves `...colocatedHooks` | ✓ VERIFIED (manual) | [priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js](/Users/jon/projects/sigra/priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js:1) contains the exact merged hooks line; the `gsd-tools` regex for this link still false-negatives on the literal `...` sequence. |
| `test/sigra/install/features/passkeys_js_test.exs` | `test/support/install_fixture.ex` | Tmp-app installer integration uses shared fixture helpers | ✓ VERIFIED | `gsd-tools verify key-links` passed for Plan 20-05. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `lib/sigra/plug/passkey_challenge.ex` | Session `"token"` and reconstructed `challenge.bytes` | `Registration.new_challenge/2` / `Authentication.new_challenge/2` -> `Sigra.Token.generate/4` -> `Sigra.Token.verify/4` | Yes | ✓ FLOWING |
| `lib/sigra/passkeys.ex` | Cached `%Sigra.Config{}` | `Application.get_env(:sigra, :otp_app)` and `Application.get_env(otp_app, :sigra_config)` -> `Sigra.Config.new!/1` -> `validate_runtime_passkeys!/1` | Yes | ✓ FLOWING |
| `lib/sigra/passkeys.ex` | Limiter key / rate-limit budget | `config.passkeys[:ceremony_rate_limit]` and `config.rate_limiting[:limiter]` | Yes | ✓ FLOWING |
| `priv/templates/sigra.install/passkeys/passkey_hooks.js` | Browser response/error/abort payloads | `handleEvent(startEvent, payload)` -> `startRegistration` / `startAuthentication` -> `pushEvent(success|error|aborted, ...)` | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Focused Phase 20 verifier subset | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/plug/passkey_challenge_test.exs test/sigra/passkeys/config_test.exs test/sigra/passkeys/rate_limit_test.exs test/sigra/install/features/passkeys_js_test.exs test/sigra/install/features/passkeys_test.exs --max-failures 1` | `23 tests, 0 failures` in 92.8s | ✓ PASS |
| Artifact verification | `gsd-tools verify artifacts` for Plans `20-01` through `20-05` | All artifact sets passed | ✓ PASS |
| Key-link verification | `gsd-tools verify key-links` for Plans `20-01`, `20-02`, `20-04`, `20-05` | All automated links passed | ✓ PASS |
| GEN-06 merged hooks literal | Manual inspection of `priv/templates/sigra.install/passkeys/app_js_passkeys_injection.js` | Exact `hooks: { ...colocatedHooks, ...PasskeyHooks }` line present | ✓ PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| `PK-06` | `20-01-PLAN.md`, `20-04-PLAN.md` | Plug-session-backed server-generated/server-verified challenge with deterministic tamper rejection before callback execution | ✓ SATISFIED | [lib/sigra/plug/passkey_challenge.ex](/Users/jon/projects/sigra/lib/sigra/plug/passkey_challenge.ex:23) and [test/sigra/plug/passkey_challenge_test.exs](/Users/jon/projects/sigra/test/sigra/plug/passkey_challenge_test.exs:162). |
| `PK-09` | `20-02-PLAN.md` | Runtime-loaded passkey RP config with fast-fail validation | ✓ SATISFIED | [lib/sigra/passkeys.ex](/Users/jon/projects/sigra/lib/sigra/passkeys.ex:36), [lib/sigra/config.ex](/Users/jon/projects/sigra/lib/sigra/config.ex:448), and [test/sigra/passkeys/config_test.exs](/Users/jon/projects/sigra/test/sigra/passkeys/config_test.exs:36). |
| `PK-10` | `20-02-PLAN.md` | Per-user ceremony-initiation rate limit | ✓ SATISFIED | [lib/sigra/passkeys.ex](/Users/jon/projects/sigra/lib/sigra/passkeys.ex:55) and [test/sigra/passkeys/rate_limit_test.exs](/Users/jon/projects/sigra/test/sigra/passkeys/rate_limit_test.exs:34). |
| `GEN-06` | `20-03-PLAN.md`, `20-05-PLAN.md` | Generated `passkey_hooks.js` plus deterministic `app.js` injection/manual fallback under reliable default verifier settings | ✓ SATISFIED | [lib/sigra/install/features/passkeys.ex](/Users/jon/projects/sigra/lib/sigra/install/features/passkeys.ex:19), [lib/sigra/install/injector.ex](/Users/jon/projects/sigra/lib/sigra/install/injector.ex:124), and [test/sigra/install/features/passkeys_js_test.exs](/Users/jon/projects/sigra/test/sigra/install/features/passkeys_js_test.exs:6). |

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| None | - | No TODO/FIXME/placeholders, empty handlers, or hollow stub paths found in the verified phase files. | ℹ️ Info | The original gaps were closed by committed code and test changes, not papered over with placeholders. |

### Human Verification Required

### 1. Real Browser WebAuthn Flow

**Test:** Generate or use a Phoenix app with `--passkeys`, mount the passkey UI, and run one real registration plus one real authentication in a supported browser with an authenticator available.
**Expected:** The browser ceremony completes, the LiveView/controller receives the expected success or aborted/error event, and the user can recover cleanly from cancellation.
**Why human:** The current automated coverage proves the hook contract and abort semantics with a Node stub, not a live browser WebAuthn implementation.

### 2. Manual Fallback UX On Custom Asset Layout

**Test:** Run `mix sigra.install --passkeys` in an app whose asset entrypoint is not the standard Phoenix `assets/js/app.js` layout, then apply the printed manual instructions.
**Expected:** Sigra leaves the custom asset file untouched, the printed import + merged hooks lines are sufficient, and the host app boots with passkey hooks wired.
**Why human:** The code and tests verify that exact manual instructions are emitted, but not that they are understandable and sufficient in a real custom bundler setup.

### Gaps Summary

The two prior re-verification blockers are closed in the final codebase state. PK-06 now has deterministic tampered-token regression coverage that proves callback non-execution, and GEN-06 now carries a module-scoped timeout so the real installer integration path passes under the normal focused verifier invocation.

Automated verification is clean: all 12 must-haves are verified, all declared phase requirements are satisfied, artifact and key-link checks passed, and the focused Phase 20 suite finished with `23 tests, 0 failures`. The only remaining work is human UAT for real browser WebAuthn behavior and manual-fallback usability, so the phase is `human_needed`, not `passed`.

---

_Verified: 2026-04-15T18:22:29Z_
_Verifier: Claude (gsd-verifier)_
