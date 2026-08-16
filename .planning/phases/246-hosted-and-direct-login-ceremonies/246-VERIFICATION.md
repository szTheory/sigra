---
phase: 246-hosted-and-direct-login-ceremonies
verified: 2026-08-16T18:52:42Z
status: gaps_found
score: 3/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 1/4
  gaps_closed:
    - "Successful controller and LiveView MFA now rotate the persisted :mfa_pending session before hosted approval resumes."
    - "A signed hosted approval continuation is digest-bound and atomically single-use, including concurrent approval."
    - "PostgreSQL CI runtime evidence now proves generated hosted/direct ceremonies, replays, FetchAppSession equivalence, and browser-required policy at immutable SHA 62d2241981dad891868beacaf7b0ba5db108dad2."
  gaps_remaining:
    - "The MFA controller consumes TOTP or backup-code factors before confirming the request has an :mfa_pending persisted browser session."
    - "Hosted cancellation clears only the browser-held continuation; a copied still-valid signed continuation can be approved."
  regressions: []
gaps:
  - truth: "A registered first-party app can complete hosted system-browser login with PKCE S256, state, an exact callback allowlist, explicit continuation, and a single-use code that expires within 60 seconds."
    status: failed
    reason: "The hosted ceremony retains two observable security failures from the current code review: its controller verifies and consumes MFA factors before it verifies the session is :mfa_pending, and cancellation is not terminal for a copied signed continuation. CI success does not exercise either adversarial path."
    artifacts:
      - path: "priv/templates/sigra.install/core/mfa_challenge_controller.ex"
        issue: "create/2 calls Auth.mfa_verify/2 or Auth.mfa_verify_backup/2 at lines 46-50 before complete_mfa_session/4 rejects a non-:mfa_pending session at lines 111-118."
      - path: "lib/sigra/app_login.ex"
        issue: "approve_hosted/5 returns :cancelled at line 74 without persisting terminal cancellation; the valid signed continuation remains usable until its TTL."
      - path: "priv/templates/sigra.install/app_sessions/app_login_controller.ex"
        issue: "cancel/2 only removes the continuation from the current Plug session at line 50."
    missing:
      - "Gate controller MFA actions on a valid :mfa_pending persisted session before invoking either TOTP or backup-code verifier, with generated-controller regression tests proving an ordinary session cannot consume either factor."
      - "Persist an atomically terminal cancellation/decision binding for the continuation nonce and add a copied-pre-cancel continuation regression proving subsequent approval is rejected."
---

# Phase 246: Hosted and Direct Login Ceremonies Verification Report

**Phase Goal:** An adopter can independently opt into first-party app sessions and let apps securely obtain them through hosted browser or policy-gated direct login.
**Verified:** 2026-08-16T18:52:42Z
**Status:** gaps_found
**Re-verification:** Yes — after gap closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A fresh host can independently choose `--app-sessions` and `--app-password-login`; generating `--api`, `--jwt`, or one app feature never silently enables another. | ✓ VERIFIED | `app_sessions_generator_test.exs` exercised the complete option matrix locally (18 focused tests total) and its generated inventory remains isolated. |
| 2 | A registered first-party app can complete hosted system-browser login with PKCE S256, state, an exact callback allowlist, explicit continuation, and a single-use code that expires within 60 seconds. | ✗ FAILED | PKCE/callback/state, 60-second digest-only code, atomic approval replay protection, and CI-generated happy path exist, but CR-01 permits an ordinary session to consume an MFA factor and WR-01 leaves a copied continuation valid after cancellation. |
| 3 | A host that opts into direct password login receives uniform login failures and an opaque MFA challenge that expires within five minutes. | ✓ VERIFIED | PostgreSQL-backed `app_login_direct_test.exs` and `app_login_direct_fault_test.exs` passed; immutable CI receipt records `direct_backup_code_succeeded: true` at implementation SHA `62d224…dad2`. |
| 4 | Successful hosted or direct login creates the same app-session contract, while a host policy requiring browser login returns `browser_required`. | ✓ VERIFIED | Focused PostgreSQL tests passed for locked hosted/direct issuance and browser policy; receipt records `fetch_app_session_equivalent` and `browser_required_before_authentication` true, with exact source binding. |

**Score:** 3/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/mix/tasks/sigra.install.ex` + `lib/sigra/install/features/app_sessions.ex` | Independent generator feature selection | ✓ VERIFIED | Parsed bindings invoke the additive AppSessions feature independently; generated option-matrix test passed. |
| `lib/sigra/app_login.ex` + `lib/sigra/app_login/attempt.ex` | Hosted/direct locked issuance primitives | ⚠️ PARTIAL | Exchange/direct-MFA locking and approval-digest uniqueness are substantive and tested, but `:cancel` is stateless and not terminal. |
| `priv/templates/sigra.install/app_sessions/app_login_controller.ex` + `auth_app_sessions.ex` | Generated hosted/direct protocol routes | ⚠️ PARTIAL | Direct fixed factor allowlist and completed-browser gate are wired; cancellation clears only the current Plug-session handle. |
| `priv/templates/sigra.install/core/mfa_challenge_controller.ex` + `mfa_challenge_live.ex` | MFA completion and continuation handoff | ✗ BLOCKER | Valid factor verification precedes the controller's persisted-session-type check. LiveView deliberately posts through that controller seam. |
| `priv/templates/sigra.install/app_sessions/user_app_login_attempt.ex` + migration | Digest-only single-use ceremony storage | ✓ VERIFIED | Approval digest field/index, code/challenge digests, FKs, and lock indexes are present; race tests passed. |
| `scripts/ci/generated-app-login-runtime-proof.sh` + workflow | Fresh-host causal runtime proof | ✓ VERIFIED | Retained receipt/provenance passed the offline fail-closed parser and binds all listed implementation sources to CI run `31961276529`. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Installer CLI | AppSessions feature | independent bindings and additive feature runner | ✓ WIRED | Generated matrix proves API/JWT/app/direct selection boundaries. |
| Hosted continuation | hosted-code row | nonce hash → unique `approval_digest` in one transaction | ✓ WIRED | `approve_hosted/5` writes `approval_digest`; sequential and ready/go concurrent tests passed. |
| Hosted/direct credentials | `Sigra.Plug.FetchAppSession` | Bearer token to generated protected route | ✓ WIRED | Immutable runtime receipt proves equivalent bounded facts for both variants. |
| Direct MFA HTTP input | trusted host verifier | literal `totp`/`backup_code` decoder → explicit factor keyword | ✓ WIRED | Controller rejects all other selectors; source test and direct PostgreSQL tests passed. |
| Controller MFA submission | persisted-session rotation | session-type gate → factor verifier → `complete_mfa_verification` → `put_user_session_token` | ✗ NOT_WIRED SAFELY | Rotation exists but the required gate runs after factor consumption. |
| Hosted cancellation | terminal continuation state | cancellation decision → persisted consumed/cancelled nonce | ✗ NOT_WIRED | No terminal cancellation write exists; `AppLoginContinuation.take/1` affects only one browser session. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Generated option matrix | selected feature files and migrations | CLI bindings → AppSessions feature | Yes | ✓ FLOWING |
| Hosted approval/exchange | signed nonce → digest-only attempt → app-session credentials | signed continuation → `approve_hosted/5` transaction → locked exchange → `AppSession.issue` | Yes, but cancellation terminality is absent | ⚠️ HOLLOW ON CANCEL PATH |
| Direct MFA | opaque challenge/factor → app-session credentials | strict HTTP selector → host facade → locked challenge transaction | Yes | ✓ FLOWING |
| Generated proof receipt | causal behavior booleans/source digests | disposable hosts → receipt-last JSON → workflow parser/artifact | Yes; receipt SHA and implementation source hashes validate | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Core hosted/direct state machines, fault rollback, and concurrency | `source tmp/db.env && MIX_ENV=test mix test test/sigra/planning/phase_246_runtime_evidence_contract_test.exs test/sigra/app_login_test.exs test/sigra/app_login/concurrency_test.exs test/sigra/app_login_direct_test.exs test/sigra/app_login_direct_fault_test.exs --trace` | 23 tests, 0 failures | ✓ PASS |
| Generator independence and rendered route/MFA contracts | `source tmp/db.env && MIX_ENV=test mix test test/sigra/install/app_sessions_generator_test.exs test/sigra/install/app_sessions_routes_test.exs test/sigra/install/app_sessions_mfa_session_upgrade_test.exs --trace` | 18 tests, 0 failures | ✓ PASS — rendered-template checks; not a substitute for the missing adversarial controller tests. |
| Generated PostgreSQL ceremony proof | CI run `31961276529`: `bash scripts/ci/generated-app-login-runtime-proof.sh --all` | Passed for immutable SHA `62d2241981dad891868beacaf7b0ba5db108dad2`; retained receipt/provenance parser passed locally | ✓ PASS |

### Probe Execution

| Probe | Command | Result | Status |
| --- | --- | --- | --- |
| Generated app-login runtime proof | CI run `31961276529`: `bash scripts/ci/generated-app-login-runtime-proof.sh --all` | Successful retained v3 receipt; all eight required booleans true | PASS |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| APP-01 | 06, 07, 10, 16, 17 | Independently opt into app sessions and separately gated password login, without API/JWT implication | ✓ SATISFIED | Independent option matrix and generated inventories passed; retained CI evidence preserves feature independence. |
| APP-02 | 01–03, 07–11, 13–17 | Secure hosted browser ceremony | ✗ BLOCKED | Main happy/replay/MFA-completion flows run, but MFA factors can be consumed outside `:mfa_pending` and cancellation is not terminal for a copied continuation. |
| APP-03 | 01, 04–05, 07–10, 12–13, 17 | Policy-gated direct login with uniform failure, opaque MFA, and same app session | ✓ SATISFIED | Direct PostgreSQL tests and source-bound CI proof cover uniform failure, backup code, replay, equivalence, and `browser_required`. |

All plan-declared IDs (`APP-01`, `APP-02`, `APP-03`) occur in `REQUIREMENTS.md` and are accounted for above. No phase-mapped requirement is orphaned.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `priv/templates/sigra.install/core/mfa_challenge_controller.ex` | 38–54, 111–118 | TOTP/backup verifier executes before `:mfa_pending` state is checked | 🛑 BLOCKER | A standard authenticated session can burn a one-time backup code or advance TOTP replay state, then fail session upgrade. |
| `lib/sigra/app_login.ex` | 72–75 | Cancellation returns success without consuming/cancelling continuation nonce | 🛑 BLOCKER | A copied valid continuation can still be approved before its 5-minute TTL. |
| `test/sigra/install/app_sessions_mfa_session_upgrade_test.exs` | 25–63 | Rendered-string assertions only | ⚠️ Warning | Passing test confirms symbols/templates, not the invalid-session factor-consumption ordering. |

No unreferenced `TBD`, `FIXME`, or `XXX` marker was found in the inspected Phase 246 implementation files. The literal form `placeholder` and `mktemp` template text are not stubs.

### Prohibition Verification

The four plan-declared safety/transparency prohibitions were not silently accepted. Static and runtime evidence verifies the fixed direct-factor allowlist, absence of new client/scope/identity authority, and source-bound receipt behavior. The two blocker paths above remain independent security failures and prevent APP-02 from being accepted.

### Gaps Summary

This re-verification confirms that the former hosted-MFA rotation and approval-replay gaps are closed, and that the retained CI receipt is valid runtime evidence for its immutable implementation head. It nevertheless fails the phase goal: the generated MFA controller can consume a valid factor before establishing MFA-pending session authority, and cancelling a hosted login only clears one browser cookie rather than making the signed continuation terminal. Neither defect is assigned to a later roadmap phase (247–249), so both are actionable Phase 246 blockers.

---

_Verified: 2026-08-16T18:52:42Z_
_Verifier: the agent (gsd-verifier)_
