---
phase: 246-hosted-and-direct-login-ceremonies
verified: 2026-08-16T21:15:10Z
status: passed
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 3/4
  gaps_closed:
    - "The generated MFA controller now establishes a current-user-bound :mfa_pending session before either TOTP or backup-code verification."
    - "Hosted cancellation now persists an atomically terminal nonce decision, rejecting copied and concurrent approval attempts."
  gaps_remaining: []
  regressions: []
---

# Phase 246: Hosted and Direct Login Ceremonies Verification Report

**Phase Goal:** An adopter can independently opt into first-party app sessions and let apps securely obtain them through hosted browser or policy-gated direct login.
**Verified:** 2026-08-16T21:15:10Z
**Status:** passed
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A fresh host can independently choose `--app-sessions` and `--app-password-login`; generating `--api`, `--jwt`, or one app feature never silently enables another. | ✓ VERIFIED | `test/sigra/install/app_sessions_generator_test.exs` passed all 10 focused selection/inventory tests, including the complete API/JWT/app-session option matrix and the direct-login dependency. |
| 2 | A registered first-party app can complete hosted system-browser login with PKCE S256, state, an exact callback allowlist, explicit continuation, and a single-use code that expires within 60 seconds. | ✓ VERIFIED | Existing hosted protocol/state-machine code validates exact input and S256 (`lib/sigra/app_login.ex:161-208`), while current named behavioral tests prove the repaired controller authority/rotation (`…mfa_session_upgrade_test.exs:33`, `:79`), copied-continuation cancellation (`…app_login_test.exs:175`), and approve/cancel serialization (`…concurrency_test.exs:224`). |
| 3 | A host that opts into direct password login receives uniform login failures and an opaque MFA challenge that expires within five minutes. | ✓ VERIFIED | Current direct state machine returns only `:invalid_credentials` outside the policy exception and creates `@mfa_challenge_ttl` challenges; named tests for opaque five-minute challenge (`app_login_direct_test.exs:83`) and uniform/pre-auth policy failure (`app_login_direct_fault_test.exs:24`) passed. |
| 4 | Successful hosted or direct login creates the same app-session contract, while a host policy requiring browser login returns `browser_required`. | ✓ VERIFIED | Hosted/direct issue through `Sigra.AppSession` and generated protected-route evidence remains validated by the retained fail-closed receipt contract; direct policy named test proves `browser_required` before password verification. |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/mix/tasks/sigra.install.ex` + `lib/sigra/install/features/app_sessions.ex` | Independent feature selection | ✓ VERIFIED | Generator option-matrix behavior passed; no phase artifact path is missing. |
| `lib/sigra/app_login.ex` + `lib/sigra/app_login/attempt.ex` | Hosted/direct state machines and locked issuance | ✓ VERIFIED | `approve_hosted/5` persists both `:approve` and `:cancel` via one transaction; `approval_digest` has the named unique constraint. |
| `priv/templates/sigra.install/core/mfa_challenge_controller.ex` + `test/sigra/install/app_sessions_mfa_session_upgrade_test.exs` | Pre-verifier MFA-pending authority gate | ✓ VERIFIED | The controller’s `current_mfa_session/1` gate executes before `verify_mfa_factor/4`; rendered-controller behavioral tests count verifier, completion, and token-rotation calls. |
| `priv/templates/sigra.install/app_sessions/app_login_controller.ex` + `user_app_login_attempt.ex` | Generated hosted/direct routes and durable cancellation schema | ✓ VERIFIED | Cancel awaits `approve_hosted(..., :cancel)` before `AppLoginContinuation.take/1`; generated enum includes `:hosted_cancel`. |
| `scripts/ci/generated-app-login-runtime-proof.sh` + retained receipt/provenance | Source-bound generated-host proof | ✓ VERIFIED | The offline evidence contract passed all 37 tests, including the canonical retained receipt/provenance fail-closed parser. The receipt correctly scopes itself to immutable SHA `62d2241981dad891868beacaf7b0ba5db108dad2`; newer gap-closure behavior is independently covered by the current named tests above. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Installer CLI | AppSessions feature | independent bindings and additive feature runner | ✓ WIRED | 10-test generator suite proves selection boundaries. |
| MFA controller request | persisted session authority then factor verifier | `current_mfa_session/1` before `verify_mfa_factor/4` | ✓ WIRED | Manual source trace confirms the multiline relationship that the narrow key-link regex cannot express; named standard-session test proves no verifier call, and pending-session test proves each selected verifier plus exact-row rotation. |
| MFA completion | `Auth.complete_mfa_verification/3` | trusted pending row → completion → `UserAuth.put_user_session_token/2` | ✓ WIRED | Current named pending-session test verifies completion and rotation counters and the hosted-continuation redirect. |
| Hosted cancellation/approval | shared persisted decision | nonce hash → `approval_digest` unique index → transaction | ✓ WIRED | Both decision branches write identical arbitration digest; copied and barrier-concurrent behavioral tests passed. |
| Generated cancellation controller | terminal service decision | service success before local continuation removal | ✓ WIRED | `cancel/2` ordering is explicit and generated route test pins it. |
| Hosted/direct credentials | `Sigra.Plug.FetchAppSession` | both ceremony credentials authenticate protected generated route | ✓ WIRED | Retained source-bound CI receipt is accepted by its fail-closed parser and records `fetch_app_session_equivalent: true`. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Hosted approval/cancellation | signed nonce → `approval_digest` attempt → code/cancel result | signed continuation → `AppLogin.approve_hosted/5` transaction | Yes | ✓ FLOWING |
| Generated MFA controller | authenticated persisted session → selected verifier → rotated session | `UserAuth.fetch_current_scope/2` obtains stored session into `conn.private[:sigra_session]`; controller checks its type/user binding | Yes | ✓ FLOWING |
| Direct MFA | opaque challenge → locked challenge row → app-session credentials | direct password callback → digest-only attempt → `AppSession.issue` | Yes | ✓ FLOWING |
| Generated proof receipt | causal booleans and source digests | disposable generated hosts → receipt-last JSON → offline parser | Yes, for its recorded immutable SHA | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Ordinary browser session cannot consume a TOTP factor | `MIX_ENV=test mix test test/sigra/install/app_sessions_mfa_session_upgrade_test.exs:33 --trace` | 1 test, 0 failures; factor/complete/rotate counters remain zero | ✓ PASS |
| Pending browser session invokes selected verifier and rotates exact row | `MIX_ENV=test mix test test/sigra/install/app_sessions_mfa_session_upgrade_test.exs:79 --trace` | 1 test, 0 failures; TOTP and backup paths both exercised | ✓ PASS |
| Copied continuation remains unusable after cancellation | `MIX_ENV=test mix test test/sigra/app_login_test.exs:175 --trace` | 1 test, 0 failures | ✓ PASS |
| Concurrent approval and cancellation produce one terminal decision | `MIX_ENV=test mix test test/sigra/app_login/concurrency_test.exs:224 --trace` | 1 test, 0 failures | ✓ PASS |
| Feature independence | `MIX_ENV=test mix test test/sigra/install/app_sessions_generator_test.exs --trace` | 10 tests, 0 failures | ✓ PASS |
| Direct opaque MFA and uniform/policy responses | Named direct tests at `:83` and fault test `:24` | 2 tests, 0 failures | ✓ PASS |
| Retained CI proof contract | `MIX_ENV=test mix test test/sigra/planning/phase_246_generated_app_login_runtime_test.exs test/sigra/planning/phase_246_runtime_evidence_contract_test.exs --trace` | 37 tests, 0 failures; shell and workflow parse checks passed | ✓ PASS |

### Probe Execution

| Probe | Command | Result | Status |
| --- | --- | --- | --- |
| Generated app-login runtime proof | Retained CI run `31961276529`: `bash scripts/ci/generated-app-login-runtime-proof.sh --all` | Successful receipt/provenance for immutable SHA `62d2241981dad891868beacaf7b0ba5db108dad2`; current offline contract passed. | PASS |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| APP-01 | 06, 07, 10, 16, 17, 19 | Independently opt into app sessions and separately gated password login, without API/JWT implication | ✓ SATISFIED | Current generator matrix passed; selection code and generated inventory remain independent. |
| APP-02 | 01–03, 07–11, 13–19 | Secure hosted browser ceremony | ✓ SATISFIED | Current authority-before-factor, rotation, cancellation, replay, and terminal-decision tests pass; PKCE, callback, state, expiry, and exchange logic are substantive and wired. |
| APP-03 | 01, 04–05, 07–10, 12–13, 17 | Policy-gated direct login with uniform failure, opaque MFA, and same app session | ✓ SATISFIED | Current direct named behavior tests pass; retained generated-host contract verifies real backup-code, replay, FetchAppSession parity, and browser policy. |

All plan-declared IDs (`APP-01`, `APP-02`, `APP-03`) occur in `REQUIREMENTS.md` and are accounted for above. `REQUIREMENTS.md` maps no additional requirement to Phase 246, so there are no orphaned requirements.

### Anti-Patterns Found

No blocker or warning anti-pattern was found in the Phase 246 gap-closure files. In particular, no unreferenced `TBD`, `FIXME`, or `XXX` marker is present, and no empty handler or hardcoded-empty data path feeds the ceremony output.

### Prohibition Verification

The plan-declared prohibitions were checked with deterministic evidence rather than silently accepted: generated hosted routes require completed browser assurance; the direct factor decoder maps only literal `totp` and `backup_code`; the source-bound receipt parser rejects unsupported success claims; and the proof surface adds no OAuth/OIDC authority, dynamic registration, request-selected scopes, or client-selected identity.

### Gaps Summary

None. The two prior APP-02 blockers are closed. No later roadmap phase is needed to defer an unmet Phase 246 truth.

---

_Verified: 2026-08-16T21:15:10Z_
_Verifier: the agent (gsd-verifier)_
