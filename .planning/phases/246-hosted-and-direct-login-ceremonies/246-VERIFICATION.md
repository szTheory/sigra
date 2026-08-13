---
phase: 246-hosted-and-direct-login-ceremonies
verified: 2026-08-13T02:58:54Z
status: gaps_found
score: 1/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "A registered first-party app can complete hosted system-browser login with PKCE S256, state, an exact callback allowlist, explicit continuation, and a single-use code that expires within 60 seconds."
    status: failed
    reason: "Generated hosted approval inserts a UserAppLoginAttempt without the required :kind discriminator, so a real generated host rejects approval and creates no authorization code."
    artifacts:
      - path: "lib/sigra/app_login.ex"
        issue: "approve_hosted/5 constructs the generated attempt without kind: :hosted_code."
      - path: "priv/templates/sigra.install/app_sessions/app_sessions_migration.exs"
        issue: "user_app_login_attempts.kind is NOT NULL."
    missing:
      - "Persist kind: :hosted_code and add a generated-host successful start → approval → exchange regression test."
  - truth: "Hosted browser approval requires a fully authenticated browser session and never mints an app session from an MFA-pending session."
    status: failed
    reason: "The generated browser guard accepts any current_scope.user and never rejects conn.private[:sigra_session] type :mfa_pending; the app-login routes omit the normal MFA pipeline."
    artifacts:
      - path: "priv/templates/sigra.install/app_sessions/app_login_controller.ex"
        issue: "require_authenticated_browser/2 checks only current_user(conn)."
      - path: "priv/templates/sigra.install/app_sessions/router_injection.ex"
        issue: "Routes use [:browser, :app_login_public], not a completed-MFA enforcement pipeline."
    missing:
      - "Reject or redirect MFA-pending sessions while retaining only the signed continuation handle; cover the bypass with a generated-host regression test."
  - truth: "A direct-login host supports its advertised MFA factors while retaining uniform failures and an opaque five-minute challenge."
    status: failed
    reason: "The generated direct MFA endpoint accepts only challenge and code, and the facade cannot transport factor: :backup_code to Sigra.AppLogin; backup codes therefore always use the default TOTP verifier."
    artifacts:
      - path: "priv/templates/sigra.install/app_sessions/app_login_controller.ex"
        issue: "complete_direct_mfa/2 exact-key guard permits no factor field."
      - path: "priv/templates/sigra.install/app_sessions/auth_app_sessions.ex"
        issue: "complete_direct_mfa/2 forwards no factor option."
    missing:
      - "Accept one validated factor selector, map it to a trusted atom, and prove generated direct-MFA backup-code success."
  - truth: "Fresh LiveView and controller hosts install/rerun/migrate/compile/boot and prove both ceremonies through real generated routes."
    status: failed
    reason: "The generated-host harness makes only malformed HTTP requests and then runs repository-library tests against handwritten schemas; it never proves a successful generated ceremony, persistence of hosted kind, replay, or FetchAppSession authentication."
    artifacts:
      - path: "scripts/ci/generated-app-login-runtime-proof.sh"
        issue: "Lines 109-116 contain malformed-request curls and repository tests, not a generated-host happy path."
    missing:
      - "Drive and assert a real generated hosted and direct success path, including one-use replay and protected-route authentication."
---

# Phase 246: Hosted and Direct Login Ceremonies Verification Report

**Phase Goal:** An adopter can independently opt into first-party app sessions and let apps securely obtain them through hosted browser or policy-gated direct login.
**Verified:** 2026-08-13T02:58:54Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | A fresh host can independently choose `--app-sessions` and `--app-password-login`; API/JWT/app options do not imply one another. | ✓ VERIFIED | `sigra.install` has independent defaults and rejects password login without app sessions; the 35-test deterministic generator suite passed, including its complete option matrix. |
| 2 | A registered app can complete hosted browser login with S256/state/exact callback/explicit approval/a 60-second one-use code. | ✗ FAILED | `AppLogin.approve_hosted/5` omits `kind: :hosted_code` while generated storage requires non-null `kind`; generated approval cannot create the code. |
| 3 | A direct-password host has uniform failures and an opaque five-minute MFA challenge. | ✗ FAILED | Library logic has the five-minute constant and uniform endpoint errors, but the generated endpoint cannot select the advertised backup-code factor. The complete generated direct ceremony is not delivered. |
| 4 | Successful hosted or direct login creates the same app-session contract, while browser-only policy returns `browser_required`. | ✗ FAILED | `start_direct/5` returns `browser_required` before authentication, but hosted success is impossible on a generated host and the proof never authenticates either generated credential through `FetchAppSession`. |

**Score:** 1/4 truths verified (0 present, behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `lib/mix/tasks/sigra.install.ex` + `lib/sigra/install/features/app_sessions.ex` | Independent feature selection | ✓ VERIFIED | Parsed independent options are consumed by the additive feature runner; negative-inventory option-matrix tests passed. |
| `lib/sigra/app_login.ex` + `lib/sigra/app_login/attempt.ex` | Locked hosted/direct issuance primitives | ⚠️ PARTIAL | Substantive locked `Ecto.Multi` implementation exists, but hosted approval cannot persist the generated schema's discriminator. |
| `priv/templates/sigra.install/app_sessions/app_login_controller.ex` | Generated hosted/direct protocol routes | ✗ FAILED | Browser assurance and direct backup-factor transport are incomplete. The exchange exact-key contradiction reported as CR-01 does **not** reproduce: line 58 includes `callback`. |
| `priv/templates/sigra.install/app_sessions/app_sessions_migration.exs` | Generated lifecycle storage | ✓ VERIFIED | Migration declares `kind` non-null and schema declares `Ecto.Enum [:hosted_code, :direct_mfa]`; that correct contract exposes the missing approval write. |
| `scripts/ci/generated-app-login-runtime-proof.sh` | Fresh-host, real-route ceremony proof | ✗ STUB | It creates a host but only sends malformed HTTP inputs; its receipt claims transitions it does not execute. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `Sigra.AppLogin.exchange_hosted/5` | `Sigra.AppSession.build_issue_multi/4` | Locked attempt then issuance in one Multi | ✓ WIRED | `attempt.ex:35-59` locks `FOR UPDATE`, consumes, and merges issuance. This is library wiring, not generated-host proof. |
| Generated approval controller | generated `UserAppLoginAttempt` | `AppSessions.approve_hosted/3` | ✗ NOT_WIRED | Controller reaches the facade, but the facade inserts a struct missing the generated table's required `kind`. |
| Generated app-login controller | completed MFA assurance | `require_authenticated_browser/2` | ✗ NOT_WIRED | The guard sees a user but does not distinguish an MFA-pending session. |
| Generated direct MFA endpoint | backup-code verifier | exact factor transport | ✗ NOT_WIRED | `complete_direct_mfa/2` has no accepted/forwarded factor; the core defaults to TOTP. |
| Generated runtime proof | `FetchAppSession` protected route | generated credentials | ✗ NOT_WIRED | The shell script only greps/mentions `FetchAppSession` and runs repo tests after stopping the generated host. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Generated hosted approval | `code` / attempt row | `AppLogin.approve_hosted/5` → generated attempt schema | No — Ecto insertion is invalid because `kind` is absent | ✗ DISCONNECTED |
| Generated direct MFA | selected factor callback | HTTP params → facade → `verify_direct_factor/3` | No — HTTP accepts no factor and facade supplies no option | ✗ DISCONNECTED |
| Runtime proof receipt | claimed ceremony proof | malformed `curl` responses + repo tests | No successful generated-host credentials are obtained or used | ✗ STATIC |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Installer option isolation and rendered route contracts | `MIX_ENV=test mix test test/mix/tasks/sigra.install_test.exs test/sigra/install/app_sessions_generator_test.exs test/sigra/install/app_sessions_routes_test.exs test/sigra/planning/phase_246_generated_app_login_runtime_test.exs --trace` | 35 tests, 0 failures | ✓ PASS — but source-contract coverage misses the generated-host defects. |
| Continuation preservation and ownership docs | `MIX_ENV=test mix test test/sigra/install/app_sessions_auth_continuation_test.exs test/sigra/credential_boundary_docs_test.exs --trace` | 10 tests, 0 failures | ✓ PASS — template/doc coverage only. |
| Review finding reproduction | static exact-key/kind/MFA/factor/proof checks | Exact keys now pass; hosted kind, MFA guard, factor transport, and successful proof each fail | ✗ FAIL |

The local test runtime logs PostgreSQL connection refusals for `127.0.0.1:53988`; the selected template/source tests complete successfully, but no PostgreSQL-backed library behavior was used as evidence for the generated host.

### Probe Execution

| Probe | Command | Result | Status |
| --- | --- | --- | --- |
| Generated runtime harness | `bash scripts/ci/generated-app-login-runtime-proof.sh --all` | Not run: it needs a fresh Phoenix host and PostgreSQL; static inspection deterministically shows it lacks a successful-ceremony command. | ✗ FAILED AS EVIDENCE |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| APP-01 | 06, 07, 10 | Independent app-session/password-login opt-in; no API/JWT implication | ✓ SATISFIED | Parsed options, additive feature gating, and matrix test are present and the targeted suite passed. |
| APP-02 | 01, 02, 03, 07, 08, 09, 10 | Secure hosted browser ceremony | ✗ BLOCKED | Generated approval cannot insert its mandatory discriminator; MFA-pending sessions may approve; no generated happy-path proof exists. |
| APP-03 | 01, 04, 05, 07, 08, 09, 10 | Policy-gated direct login with uniform failure/opaque MFA/same session | ✗ BLOCKED | Backup-code factor is wired in the library facade but cannot be selected over the generated HTTP transport; successful generated direct proof is absent. |

All requirement IDs declared by every plan (`APP-01`, `APP-02`, `APP-03`) appear in `REQUIREMENTS.md` and are accounted for above. No phase-246 requirement is orphaned.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `lib/sigra/app_login.ex` | 82-90 | Incomplete schema construction | 🛑 Blocker | Real hosted approval returns `:invalid_continuation` on generated hosts. |
| `priv/templates/sigra.install/app_sessions/app_login_controller.ex` | 90-94 | Authentication guard accepts MFA-pending identity | 🛑 Blocker | Password-only browser sessions can approve an app credential. |
| `priv/templates/sigra.install/app_sessions/app_login_controller.ex` | 79-81 | HTTP factor selector absent | 🛑 Blocker | Advertised backup-code direct MFA cannot work. |
| `scripts/ci/generated-app-login-runtime-proof.sh` | 109-116 | Misleading proof coverage | 🛑 Blocker | CI can pass without any successful generated ceremony. |

No unreferenced `TBD`, `FIXME`, or `XXX` marker was found in Phase 246 implementation files.

### Review Finding Reproduction

| Review finding | Current result | Evidence |
| --- | --- | --- |
| CR-01 exchange exact keys | ✓ RESOLVED | Controller line 58 requires `['callback', 'code', 'code_verifier', 'profile_id']`; `callback` is included. |
| CR-02 hosted attempt kind | ✗ REPRODUCED | `approve_hosted/5` has no `kind`; generated migration line 39 requires it and generated schema line 16 defines it. |
| CR-03 MFA-pending approval | ✗ REPRODUCED | The generated route does not use the normal MFA pipeline and the controller guard checks only `current_user`. |
| WR-01 backup-code transport | ✗ REPRODUCED | Core supports `factor: :backup_code`; generated HTTP/facade signatures cannot carry it. |
| WR-02 generated-host proof | ✗ REPRODUCED | HTTP calls are intentionally malformed; receipt claims successful transition coverage without performing it. |

### Gaps Summary

The phase does deliver independent installer opt-in. It does not deliver its central adopter outcome: a generated host cannot complete hosted login, can mint an app credential from an MFA-pending browser session, cannot complete direct MFA through backup codes, and has no CI proof capable of detecting those failures. These are not deferred to phases 247–249; those phases concern PWA/native/desktop clients, not host ceremony implementation.

---

_Verified: 2026-08-13T02:58:54Z_
_Verifier: the agent (gsd-verifier)_
