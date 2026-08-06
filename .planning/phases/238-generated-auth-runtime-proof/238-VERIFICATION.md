---
phase: 238-generated-auth-runtime-proof
verified: 2026-08-06T00:03:59Z
status: passed
score: 3/3 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: passed
  previous_score: 3/3
  gaps_closed:
    - "Reset submission revalidates the signed token after LiveView mount and fails closed when consumed, invalid, or expired."
    - "Magic-link and reset delivery use the same canonical normalized email for lookup and token issuance."
    - "Generated browser logout revokes the active persisted session and is proven by authenticated-route denial."
  gaps_remaining: []
  regressions: []
---

# Phase 238: Generated Auth Runtime Proof Verification Report

**Phase Goal:** Establish deterministic browser and accessibility proof for the generated B2C email and Google authentication journeys without provider credentials.
**Verified:** 2026-08-06T00:03:59Z
**Status:** passed
**Re-verification:** Yes — final verification after Plan 238-07 review closure

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Browser coverage proves registration, confirmation, password sign-in/logout, magic-link request/verification, and password-reset completion in a generated B2C host. | ✓ VERIFIED | `generated-auth.spec.ts` executes the complete serial journey using generated routes/forms and mailbox links. It includes the two-page stale-reset race, case-varied magic/reset requests selected by canonical recipient, and current-session revocation followed by `/users/settings` denial. Receipt job `92479701884` ran the full `--all` proof on the exact correction SHA and concluded `success`. |
| 2 | A deterministic provider double proves Google OAuth start, callback, and account-link collision behavior without CI credentials. | ✓ VERIFIED | The retained harness builds a fresh host with a loopback OIDC discovery/authorize/token double, dummy values, HS256 ID tokens, and S256 PKCE; both specs begin at generated `/auth/google` and assert the existing-account collision. The successful exact-SHA job requires the authorize and token server-log markers. |
| 3 | Every rendered B2C auth state passes Axe plus stable label/control and duplicate-ID checks. | ✓ VERIFIED | `assertAuthState` scopes Axe and DOM invariant assertions to `main.sigra-auth` at every named state, including stale-token denial; focused source contracts and the successful full Chromium job cover the dedicated `generated-auth` project with one worker and zero retries. |

**Score:** 3/3 truths verified (0 present, behavior-unverified)

### Review-Closure Truths

| Truth | Status | Evidence |
| --- | --- | --- |
| A mounted reset form cannot reset after its signed token is consumed, invalidated, or expired. | ✓ VERIFIED | Generated reset event passes `socket.assigns.token` to the signed-token clause; explicit `:token_invalid`/`:token_expired` branches render the expired-link state. The browser test mounts the same link in two pages, consumes it in one, and proves stale submission is denied. |
| Magic-link and reset delivery resolve the same normalized account as token issuance. | ✓ VERIFIED | Both wrappers compute `Sigra.Email.normalize(email)` once, pass that value to issuance, and use it for lookup while delivering to canonical `user.email`; the browser requests case-varied addresses and extracts mail for the canonical address. |
| Logout invalidates the active server session rather than merely rendering a public page. | ✓ VERIFIED | The browser invokes role-addressable `Log out this device` on generated `/users/sessions`. The generated LiveView hashes the browser session token, revokes that persisted session, then the test navigates to protected `/users/settings` and asserts login redirect plus the `Sign in` heading. The fresh-host job executed this path successfully. |

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `scripts/ci/generated-auth-runtime-proof.sh` | Fresh-host, credential-free runtime harness | ✓ VERIFIED | Substantive scaffold/install/generate/migrate/boot lifecycle, local OIDC double, retained `${CI_DIR}` source check after `cd`, and `--all` allowlist. |
| `test/example/priv/playwright/tests/generated-auth.spec.ts` | Serial email/auth/a11y journey and review regressions | ✓ VERIFIED | Substantive browser interactions, emitted mailbox links, stale-token race, protected-route logout assertion, and scoped state checks. |
| `test/example/priv/playwright/tests/generated-auth-oauth-probe.spec.ts` | Focused Google start/callback/collision proof | ✓ VERIFIED | Starts from generated `/auth/google`, asserts signed state/S256 PKCE, and verifies collision UI. |
| `test/example/priv/playwright/fixtures/mailbox.ts` | Bounded no-sleep mail-link extraction | ✓ VERIFIED | `expect.poll` selects fresh emitted messages by recipient and route; no browser timing sleep. |
| `priv/templates/sigra.install/core/reset_password_live.ex` | Fail-closed signed reset submission | ✓ VERIFIED | Saved signed token is submitted; invalid/expired errors clear the form into the existing expired state. |
| `priv/templates/sigra.install/core/auth.ex` | Normalized delivery boundary | ✓ VERIFIED | Magic and reset wrappers share the normalized input for lookup and issuance; delivery uses the resolved canonical email. |
| `priv/templates/sigra.install/core/session_live.ex` and `lib/sigra/install/features/core.ex` | Generated persisted-session revocation and authenticated LiveView wiring | ✓ VERIFIED | Current-session control invokes `Auth.revoke_session`; generated sessions/settings routes live inside `UserAuth`'s authenticated `live_session`, supplying `current_scope`. |
| `.github/workflows/generated-auth-runtime-proof.yml` | Isolated PostgreSQL/Chromium direct job | ✓ VERIFIED | Dispatch-only evidence-ref guard executes `GITHUB_WORKSPACE="$PWD" scripts/ci/generated-auth-runtime-proof.sh --all`; no provider credentials injected. |
| `.planning/phases/238-generated-auth-runtime-proof/238-EVIDENCE.json` | Exact-SHA immutable receipt | ✓ VERIFIED | Locally validated status/schema, workflow ID `328072752`, run `31058020315`, direct job `92479701884`, exact SHA `f485afb81560c9aa28fbf438ea68bdf36386dacd`, and retained failed/superseded lineage. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| Reset LiveView | Generated auth context | saved signed token → binary `reset_user_password/2` | ✓ WIRED | The former production user-struct overload call is absent from the reset event; error-state rendering is explicit. |
| Generated auth context | `Sigra.Email.normalize/1` / `Sigra.Auth` | one normalized value for lookup and issuance | ✓ WIRED | Manual source trace confirms normalization before both wrapper calls and canonical `user.email` delivery. |
| Browser journey | Session LiveView / authenticated router | current-session revocation → protected-route denial | ✓ WIRED | Role click at `/users/sessions`, persisted-session revoke, then `/users/settings` redirects to login in the browser spec. |
| Harness | Fresh generated host | scaffold/install/OIDC/Playwright `--all` | ✓ WIRED | Harness invokes canonical B2C flags, generated OAuth, migration/boot, and precisely the two allowlisted specs. |
| Evidence receipt | Direct workflow/job | matching exact SHA, workflow-dispatch run, stable direct job | ✓ WIRED | JSON predicate and git ancestry/diff allowlist passed locally; no GitHub query was made during this verification by instruction. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| Email journey | confirmation/magic/reset URLs | Fresh host `/dev/mailbox/json` | Recipient-, route-, and newest-message-selected emitted mail | ✓ FLOWING |
| OAuth journey | state, PKCE challenge/verifier, ID token, collision outcome | Generated `/auth/google` and loopback OIDC double | Runtime double validates state/PKCE and emits signed HS256 token | ✓ FLOWING |
| Logout journey | current hashed session token | Browser session → generated SessionLive → session store | Current token is matched and deleted; protected LiveView rejects the retained browser cookie | ✓ FLOWING |
| Accessibility checks | rendered auth root and diagnostics | Actual Chromium DOM after LiveView readiness | Axe and DOM diagnostics are asserted per named rendered state | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command / evidence | Result | Status |
| --- | --- | --- | --- |
| Review-boundary source regressions | `MIX_ENV=test mix test test/sigra/install/generator_reset_test.exs test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` | 37 tests, 0 failures | ✓ PASS |
| Retained harness syntax | `bash -n scripts/ci/generated-auth-runtime-proof.sh` | Exit 0 | ✓ PASS |
| Proof-spec isolation | `npx playwright test tests/generated-auth.spec.ts tests/generated-auth-oauth-probe.spec.ts --project=generated-auth --retries=0 --list` | Exactly 2 tests, each in `generated-auth` | ✓ PASS |
| Exact-SHA receipt integrity | Local `jq` predicate plus commit existence, ancestry, and post-SHA allowlist | Exit 0; only receipt/summary/tracking artifacts follow tested SHA | ✓ PASS |
| Fresh-host browser proof | Existing metadata-only receipt, run `31058020315`, job `92479701884`, SHA `f485afb81560c9aa28fbf438ea68bdf36386dacd` | Workflow and direct job recorded `success` | ✓ PASS |

### Probe Execution

| Probe | Command | Result | Status |
| --- | --- | --- | --- |
| Generated auth runtime proof | `GITHUB_WORKSPACE="$PWD" scripts/ci/generated-auth-runtime-proof.sh --all` in isolated PostgreSQL/Chromium workflow | Exact-SHA run `31058020315`, direct job `92479701884`, recorded `success` | PASS |

### Requirements Coverage

| Requirement | Source Plans | Description | Status | Evidence |
| --- | --- | --- | --- |
| AUTH-01 | 238-02, 238-04, 238-06, 238-07 | Generated-host registration, confirmation, password sign-in/logout, magic-link, and reset completion | ✓ SATISFIED | Full serial browser flow, review closure regressions, and exact-SHA green direct job. |
| AUTH-02 | 238-01, 238-03, 238-04, 238-06, 238-07 | Local deterministic Google start/callback/collision proof without credentials | ✓ SATISFIED | Loopback double, focused/full `/auth/google` browser paths, and exact-SHA green direct job. |
| AUTH-03 | 238-03, 238-04, 238-06, 238-07 | Per-rendered-state Axe, label/control, and duplicate-ID checks | ✓ SATISFIED | Scoped `assertAuthState`, dedicated project, source contract, and exact-SHA green direct job. |

### Anti-Patterns Found

No blocker or warning anti-patterns found in the Phase 238 implementation and proof files. The only `placeholder` wording found is an unrelated deterministic fallback comment in generator infrastructure; it does not flow to this auth proof. No unreferenced `TBD`, `FIXME`, or `XXX` debt markers were found.

### Verification Notes

- The Plan 02 artifact checker reports its literal `contains: "password reset"` string absent. This is a wording-only false positive: the executable spec exercises reset URL extraction, the reset form, successful replacement, stale-token denial, old-password failure, and replacement-password sign-in.
- The Plan 06 key-link checker misses `${CI_DIR}/generated-auth-runtime-proof.sh` because its regex expects a different interpolation form. Manual inspection and the focused source contract verify the retained-harness lookup after the working-directory change.
- Direct `mix format --check-formatted` cannot parse EEx templates as standalone Elixir (`<%= web_module %>` is deliberately template syntax). Generated output is instead compiled with warnings as errors by the exact-SHA fresh-host runtime job; this is not a formatting or runtime defect.

### Disconfirmation Pass

- **Partial-requirement check:** reset coverage is not source-only: the stale page mounts while valid, another page consumes the credential, and the stale submit is asserted to render expiry rather than change the password.
- **Misleading-test check:** fast ExUnit source contracts do not establish generated-host behavior. The verdict additionally requires the distinct PostgreSQL/Chromium receipt on the correction SHA.
- **Uncovered error-path check:** invalid and expired signed-token outcomes are both explicitly mapped to fail-closed rendering; logout additionally proves protected-route denial after revocation, not an opaque redirect.

## Gaps Summary

None. The Phase 238 goal and AUTH-01 through AUTH-03 are achieved by wired generated-host code and an exact-SHA successful direct runtime receipt. No human verification is required because the phase contract is automated and its behavior-dependent paths are exercised by the recorded deterministic Chromium job.

_Verified: 2026-08-06T00:03:59Z_
_Verifier: the agent (gsd-verifier)_
