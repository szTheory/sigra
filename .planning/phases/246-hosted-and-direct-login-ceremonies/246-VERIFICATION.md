---
phase: 246-hosted-and-direct-login-ceremonies
verified: 2026-08-13T04:36:14Z
status: gaps_found
score: 1/4 must-haves verified
behavior_unverified: 2
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 1/4
  gaps_closed:
    - "Hosted approval now persists kind: :hosted_code."
    - "Generated direct MFA now transports an allowlisted backup_code factor."
    - "The fresh-host harness now contains generated hosted/direct success, replay, and FetchAppSession paths."
  gaps_remaining:
    - "Hosted MFA completion does not replace the persisted :mfa_pending browser session."
    - "A stateless approval continuation can be reused to mint multiple hosted codes."
  regressions: []
gaps:
  - truth: "A registered first-party app can complete hosted system-browser login with PKCE S256, state, an exact callback allowlist, explicit continuation, and a single-use code that expires within 60 seconds."
    status: failed
    reason: "MFA-enabled browser users cannot complete the generated hosted ceremony: second-factor success only clears Plug-session flags, while the database-backed Sigra session remains :mfa_pending and approval redirects back to /users/mfa. The signed approval continuation is also not atomically consumed, so a replay can mint multiple distinct hosted codes before expiry."
    artifacts:
      - path: "priv/templates/sigra.install/core/mfa_challenge_controller.ex"
        issue: "Successful TOTP/backup verification does not call Auth.complete_mfa_verification/3 or UserAuth.put_user_session_token/2."
      - path: "priv/templates/sigra.install/core/mfa_challenge_live.ex"
        issue: "Successful LiveView TOTP/backup verification likewise redirects without upgrading the pending session."
      - path: "lib/sigra/app_login.ex"
        issue: "approve_hosted/5 verifies a stateless continuation and inserts a code, but persists no consumed continuation nonce/digest."
    missing:
      - "Upgrade and rotate the pending session after every successful controller/LiveView MFA factor, preserving the bounded continuation through UserAuth.put_user_session_token/2."
      - "Atomically consume a persisted approval-continuation nonce/digest with hosted-code creation and add generated-host MFA and continuation-replay regression tests."
behavior_unverified_items:
  - truth: "A host that opts into direct password login receives uniform login failures and an opaque MFA challenge that expires within five minutes."
    test: "Run bash scripts/ci/generated-app-login-runtime-proof.sh --direct in the PostgreSQL-backed CI lane."
    expected: "A real generated direct backup-code ceremony succeeds; malformed/unknown factor requests are uniform invalid_credentials and issue no family."
    why_human: "The local PostgreSQL endpoint configured by tmp/db.env (127.0.0.1:53988) refused connections, so neither the database-backed library test nor the generated-host runtime proof could execute. Source and static-contract tests do not exercise the transition."
  - truth: "Successful hosted or direct login creates the same app-session contract, while browser-only policy returns browser_required."
    test: "Run bash scripts/ci/generated-app-login-runtime-proof.sh --all in the PostgreSQL-backed CI lane."
    expected: "Both generated credentials authenticate the protected FetchAppSession route; both one-time inputs reject replay; browser-required direct policy returns browser_required before issuance."
    why_human: "The generated proof is wired but was not runnable locally because PostgreSQL was unavailable. Its ExUnit companion is a source-marker test, not a runtime execution test."
---

# Phase 246: Hosted and Direct Login Ceremonies Verification Report

**Phase Goal:** An adopter can independently opt into first-party app sessions and let apps securely obtain them through hosted browser or policy-gated direct login.
**Verified:** 2026-08-13T04:36:14Z
**Status:** gaps_found
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A fresh host can independently choose `--app-sessions` and `--app-password-login`; API/JWT/app options do not imply one another. | ✓ VERIFIED | `app_sessions_generator_test.exs` option matrix passed; feature selection is independent and password login reuses the app-session group only when selected. |
| 2 | A registered app can complete hosted system-browser login with S256/state/exact callback/explicit approval/a 60-second one-use code. | ✗ FAILED | Kind persistence is repaired (`app_login.ex:83`) and the normal generated happy-path script exists, but MFA completion leaves the persisted session `:mfa_pending`, causing `/app-login/continue` to redirect back to `/users/mfa`; the approval continuation is reusable. |
| 3 | A direct-password host has uniform failures and an opaque five-minute MFA challenge. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Fixed HTTP allowlist (`totp`/`backup_code`), facade factor forwarding, and a real direct harness path exist; PostgreSQL was unavailable, so no behavioral test ran. |
| 4 | Successful hosted or direct login creates the same app-session contract, while browser-only policy returns `browser_required`. | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Both library flows compose the same issuance multi and `start_direct/5` returns `browser_required` before authentication. The generated protected-route/replay harness is present but could not run without PostgreSQL. |

**Score:** 1/4 truths verified (2 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/mix/tasks/sigra.install.ex` + `lib/sigra/install/features/app_sessions.ex` | Independent feature selection | ✓ VERIFIED | All 13 plan artifact checks passed; the targeted 21-test source/template suite passed. |
| `lib/sigra/app_login.ex` + `lib/sigra/app_login/attempt.ex` | Locked hosted/direct issuance primitives | ⚠️ PARTIAL | Hosted kind is now persisted and exchange/direct rows are locked, but approval continuation consumption is absent. |
| `priv/templates/sigra.install/app_sessions/app_login_controller.ex` + `auth_app_sessions.ex` | Generated hosted/direct protocol routes | ⚠️ PARTIAL | MFA-pending requests are correctly rejected and direct factor transport is now wired; successful MFA completion never upgrades the persisted browser session. |
| `priv/templates/sigra.install/core/mfa_challenge_controller.ex` + `mfa_challenge_live.ex` | Browser-MFA continuation completion | ✗ FAILED | Both factor-success branches skip the established `complete_mfa_verification` → `put_user_session_token` session-rotation path used by passkey MFA. |
| `scripts/ci/generated-app-login-runtime-proof.sh` + workflow | Generated-host causal proof | ⚠️ PRESENT, NOT EXECUTED | The script creates fresh hosts, exchanges real credentials, checks replay and `FetchAppSession`, and writes a receipt last; local PostgreSQL refused connections, so it supplied no runtime evidence. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `AppLogin.approve_hosted/5` | generated `UserAppLoginAttempt` | `kind: :hosted_code` insert | ✓ WIRED | The required discriminator is present at `app_login.ex:83`; this closes the prior generated-schema mismatch. |
| Direct MFA controller | `Auth.AppSessions.complete_direct_mfa/3` | fixed selector → trusted atom → `factor:` option | ✓ WIRED | Only `totp` and `backup_code` are decoded at controller lines 93–95 and forwarded at facade lines 53–58. |
| MFA controller/LiveView success | completed browser session | `complete_mfa_verification` then `put_user_session_token` | ✗ NOT_WIRED | The required functions exist and are used by passkey MFA, but neither TOTP nor backup success path calls them. |
| Approval continuation | one hosted code | atomic continuation consumption with code insert | ✗ NOT_WIRED | `approve_hosted/5` only verifies the signed token then inserts; there is no continuation persistence/lock/consumed state. |
| Generated credential response | `Sigra.Plug.FetchAppSession` | Bearer token against generated proof route | ⚠️ WIRED, NOT EXECUTED | `install_proof_route` installs the plug and both ceremony functions call `prove_fetch_app_session`; runtime execution is unavailable locally. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Hosted approval | code attempt `kind` | signed continuation → `approve_hosted/5` → generated attempt row | Yes for a password-only browser; no for an MFA-completing browser because its persisted session remains pending | ✗ BLOCKED |
| Direct MFA | trusted factor / challenge / credentials | HTTP factor → fixed decoder → facade → locked `Sigra.AppLogin` multi | Source flow is real and bounded, but was not executed against PostgreSQL | ⚠️ PRESENT |
| Runtime receipt | transition booleans | real-route assertion functions → last atomic receipt write | Script wiring is substantive; no current receipt was generated | ⚠️ PRESENT |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Template/generator and proof-source contract | `bash -n ... && MIX_ENV=test mix test ...app_sessions_generator... ...app_sessions_routes... ...auth_continuation... ...phase_246_generated... --trace` | 21 tests, 0 failures | ✓ PASS — source/template coverage only. |
| Fresh generated hosted/direct proof | `bash scripts/ci/generated-app-login-runtime-proof.sh --all` | Not run: `pg_isready` to the configured local endpoint `127.0.0.1:53988` returned no response; no service was started by verification. | ? SKIP — durable automated evidence still required. |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| APP-01 | 06, 07, 10, 13 | Independent app-session/password-login opt-in; no API/JWT implication | ✓ SATISFIED | Independent option-matrix test passed; all related artifacts remain present and selected only by their own flags. |
| APP-02 | 01, 02, 03, 07–11, 13 | Secure hosted browser ceremony | ✗ BLOCKED | Core PKCE/callback/code pieces and kind persistence exist, but TOTP/backup MFA cannot advance a generated browser session to approval, and approval continuation reuse remains unprotected. |
| APP-03 | 01, 04, 05, 07–10, 12–13 | Policy-gated direct login with uniform failure/opaque MFA/same app session | ? AUTOMATED EVIDENCE NEEDED | Direct selector transport and generated proof are wired, but neither database-backed behavior nor the generated host could run in this environment. |

All plan-declared IDs (`APP-01`, `APP-02`, `APP-03`) occur in `REQUIREMENTS.md` and are accounted for above. The phase mapping has no orphaned requirements.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `priv/templates/sigra.install/core/mfa_challenge_controller.ex` | 49–62 | Factor success deletes browser flags without rotating the database session | 🛑 Blocker | Hosted MFA continuation loops and cannot reach explicit approval. |
| `priv/templates/sigra.install/core/mfa_challenge_live.ex` | 379–429 | LiveView factor success redirects without rotating the database session | 🛑 Blocker | The LiveView host has the same failure. |
| `lib/sigra/app_login.ex` | 73–96 | Stateless approval continuation is not consumed | 🛑 Blocker | One approval decision can mint multiple authorization codes under replay/concurrency. |
| `test/sigra/planning/phase_246_generated_app_login_runtime_test.exs` | 9–110 | Marker-only assertions | ⚠️ Warning | Its passing tests prove strings exist in the script, not that any generated ceremony ran. |

No unreferenced `TBD`, `FIXME`, or `XXX` marker was found in the Phase 246 implementation files inspected.

### Prohibition Verification

Plans 246-12 and 246-13 retain four `status: planned` prohibitions. They are not silently passed: the receipt-transparency and runtime-authority prohibitions lack an executed PostgreSQL proof in this environment. Static inspection finds a fixed profile registry and fixed factor decoder, not dynamic client/scopes/identity selection; execution evidence is still required for the receipt claim.

### Gaps Summary

This re-verification closes the earlier missing-discriminator and direct-factor transport gaps at the source/wiring level. It still fails the phase goal: an adopter with an MFA-enabled hosted-browser account cannot complete the ceremony, and one signed approval decision can be replayed to create multiple hosted codes. These are Phase 246 responsibilities and are not explicitly deferred by later roadmap phases 247–249. The direct and shared-session paths also need the already-wired PostgreSQL runtime lane to execute before they can be claimed as behaviorally verified.

---

_Verified: 2026-08-13T04:36:14Z_
_Verifier: the agent (gsd-verifier)_
