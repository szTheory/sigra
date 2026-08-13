# Phase 246: Hosted and Direct Login Ceremonies - Research

**Researched:** 2026-08-12
**Domain:** Phoenix installer-generated first-party application authentication ceremonies
**Confidence:** HIGH

## Summary

Phase 246 is an installer and ceremony phase built on Phase 245's already-proven opaque app-session lifecycle. It must add two independent installer flags, static host-owned public first-party app profiles, generated schemas/migrations/routes/controllers, and a small library-owned ceremony core. It must not make Sigra an OAuth/OIDC authorization server: Lockspire remains the owner of registered external-client delegation, consent, discovery, JWKS, and OAuth token exchange. [VERIFIED: codebase grep] [CITED: https://www.rfc-editor.org/rfc/rfc9700.html]

Hosted login is the default and must use the system browser. The app creates one high-entropy PKCE verifier and `state` per attempt, sends only an S256 challenge, and later exchanges the returned 60-second one-time code with the original verifier. The host must look up a static profile, exact-match its registered callback, bind the browser continuation to the same profile/state/challenge/user agent, require explicit approval after browser authentication, and atomically consume the code while issuing through `Sigra.AppSession.issue/4`. [CITED: https://www.rfc-editor.org/rfc/rfc7636.html] [CITED: https://www.rfc-editor.org/rfc/rfc9700.html] [CITED: https://www.rfc-editor.org/rfc/rfc8252.html]

Direct password login is a deliberately narrower, separately enabled first-party host endpoint—not OAuth Resource Owner Password Credentials. It must use the existing host password and MFA verification primitives, return a uniform public failure for unknown user, bad password, disabled direct-login policy, invalid/expired/consumed MFA challenge, and deny the request with `browser_required` when the static app/host policy requires the hosted ceremony. Its five-minute opaque MFA challenge stores only a random digest plus bounded server-selected pending facts, is consumed atomically on successful MFA, and issues the identical Phase 245 app session. [VERIFIED: codebase grep] [CITED: https://www.rfc-editor.org/rfc/rfc9700.html]

**Primary recommendation:** Implement a dedicated `AppLogin` ceremony service with digest-backed authorization-code and MFA-challenge rows, then generate only static first-party profile configuration plus thin controllers/routes behind independently parsed flags.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|---|---|---|---|
| Installer flags and static first-party profiles | API / Backend | Database / Storage | Generated host code selects the surface; profiles are trusted host configuration, never client-submitted registration. |
| Hosted authorization start/continuation | Frontend Server (SSR) | API / Backend | Browser cookie/session authenticates the user while the library validates protocol input and creates bounded pending state. |
| PKCE code exchange | API / Backend | Database / Storage | Secret verifier proof, profile binding, one-time use, and app-session issuance need authoritative server state and a transaction. |
| Direct password/MFA login | API / Backend | Database / Storage | Password/MFA checks and uniform public errors must be server-owned; challenge state must survive requests without exposing the user. |
| Opaque access/refresh issuance | API / Backend | Database / Storage | Reuse existing Phase 245 digest-only family/token lifecycle, with no browser/client authority over the family. |
| Native callback delivery | Browser / Client | API / Backend | The app opens the system browser and receives a callback; it never receives browser credentials or a user cookie. |

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM design system, Rail Accent brand assets, and Light/Dark/System modes for any admin UI work. [VERIFIED: AGENTS.md]
- Keep Playwright/admin UI tests deterministic: role selectors, stable hooks, LiveView readiness, and no sleeps. [VERIFIED: AGENTS.md]
- Replace human verification/UAT with deterministic tests, browser automation, CI polling, and committed machine-readable evidence within scope; do not waive missing evidence. [VERIFIED: AGENTS.md]
- Respect the single-CI-watcher and GitHub rate-limit rules if CI polling is needed. [VERIFIED: AGENTS.md]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| APP-01 | Independently opt into `--app-sessions` and separately gated `--app-password-login`; `--api`, `--jwt`, and app-session generation do not imply one another. | Extend `Mix.Tasks.Sigra.Install` switches/defaults/binding and a dedicated feature or isolated Core subfeature; prove all flag combinations through generated-host source/runtime tests. |
| APP-02 | Registered first-party app hosted login uses PKCE S256, state, exact callbacks, explicit continuation, a 60-second one-time code, and single-use exchange. | Use static generated profile allowlist and a digest-backed `AppLogin` code state machine; atomically consume-and-issue. |
| APP-03 | Opt-in direct password login has uniform failures and opaque five-minute MFA challenge, yielding the same app session or `browser_required`. | Use a distinct direct-login service/endpoint and existing password/MFA primitives; every success calls the same app-session issuer. |
</phase_requirements>

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---|---|---|---|
| Sigra.AppSession | in-repository | Issue the existing digest-only access/refresh family | Phase 245 already proves 15-minute access, rotating refresh, revocation, and `FOR UPDATE` concurrency semantics. [VERIFIED: codebase grep] |
| Ecto.Multi + PostgreSQL row locks | existing project stack | Atomic issue/consume/audit operations | Matches Phase 245's transaction and no-sleep concurrent-caller proof pattern. [VERIFIED: codebase grep] |
| Plug.Crypto / Sigra.Token | existing project stack | Signed bounded browser continuation and SHA-256 digest helpers | Existing project primitives for signed payloads and opaque digest storage; do not invent crypto. [VERIFIED: codebase grep] |
| Sigra.MFA | existing project stack | TOTP/backup-code verification and lockout | Existing MFA verification has replay/lockout semantics; direct flow needs an opaque adapter around it, not another MFA verifier. [VERIFIED: codebase grep] |

### Supporting

| Library | Version | Purpose | When to Use |
|---|---|---|---|
| `:crypto` | OTP 28 installed | SHA-256 for PKCE S256 and random opaque values through existing helpers | Inside the private ceremony core only; validate protocol syntax before hashing. [VERIFIED: local environment] |
| Phoenix controller/session APIs | existing project stack | Hosted browser start, authenticated continuation, and redirect | Generated host controllers only; keep raw protocol values out of flash/logs. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Sigra first-party ceremony core | Lockspire OAuth/OIDC server | Incorrect boundary: external-client registration/delegation remains Lockspire's responsibility. [VERIFIED: Phase 243 CONTEXT.md] |
| Hosted system-browser default | Embedded WebView | Contradicts native-app BCP and exposes browser credential/cookie surface to the app. [CITED: https://www.rfc-editor.org/rfc/rfc8252.html] |
| Direct endpoint with opaque MFA challenge | OAuth password grant | RFC 9700 says the password grant must not be used and it does not fit multi-step MFA. [CITED: https://www.rfc-editor.org/rfc/rfc9700.html] |

**Installation:** No external packages. Do not add a dependency for PKCE, OAuth-server behavior, or MFA; the required primitives already exist. [VERIFIED: codebase grep]

## Package Legitimacy Audit

No external packages are installed in this phase; package legitimacy verification is not applicable.

## Architecture Patterns

### System Architecture Diagram

```text
Native/PWA first-party app
  | start(profile_id, callback_uri, state, S256 challenge)
  v
Generated host start endpoint
  | static profile lookup + exact callback allowlist + protocol validation
  v
Signed browser continuation / pending transaction
  | system browser -> existing Sigra browser login + MFA
  v
Explicit approval page (authenticated user accepts or cancels)
  | atomically persist 60s code digest bound to profile/callback/state/challenge/user
  v
Exact registered callback: ?code=<opaque>&state=<original>
  |
  v
Generated host exchange endpoint -- verifier --> AppLogin service
  | lock code row; validate expiry, bindings and S256; consume; issue same app session
  v
Phase 245 Sigra.AppSession.issue/4 -> digest-only access + refresh response

Optional direct endpoint
  | static profile policy -> browser_required OR password verification
  +--> uniform failure
  +--> MFA needed: persist opaque 5m challenge digest + pending trusted facts
  +--> MFA success: lock/consume challenge -> same AppSession.issue/4
```

### Recommended Project Structure

```text
lib/sigra/
├── app_login.ex                 # library-owned profile validation, ceremonies, bounded result types
├── app_login/code.ex            # code/MFA challenge digest, lock, consume, and issue Multi builders
└── install/features/app_sessions.ex # opt-in generator ownership (or equivalent isolated feature)
priv/templates/sigra.install/app_sessions/
├── first_party_app.ex           # static profile source owned by host
├── app_login_code.ex            # code and MFA-challenge schemas
├── app_login_migration.exs      # rows/indexes/unique constraints
└── app_login_controller.ex      # thin generated endpoints
test/sigra/
├── app_login_test.exs           # PostgreSQL state-transition and fault tests
├── app_login/concurrency_test.exs
└── install/app_sessions_generator_test.exs
```

### Pattern 1: Static public first-party profiles
**What:** Generated configuration declares a finite list of public profile IDs, exact callback URI strings, client reference, and a host-selected `direct_login` policy (`:browser_required` or `:password_allowed`). No runtime profile registration, wildcard origin, prefix matching, client secret, or caller-selected client reference exists.

**When to use:** At hosted start and direct-password entry before any password lookup, authorization state creation, or redirect.

**Example:**
```elixir
# Source: RFC 9700 redirect matching + Phase 243 host ownership
with {:ok, profile} <- Profiles.fetch(config, profile_id),
     true <- callback_uri in profile.callback_uris do
  {:ok, profile}
else
  _ -> {:error, :invalid_request}
end
```

### Pattern 2: Bind-before-redirect hosted ceremony
**What:** Store `profile_id`, exact callback URI, caller-provided state, S256 challenge, and a signed/expiring server continuation before entering existing browser authentication. After normal login/MFA, show an explicit continue/deny screen; never redirect directly from a password result.

**When to use:** Every hosted start, including an already-authenticated browser user.

**Example:**
```elixir
# Source: RFC 7636 §§4.3–4.6; RFC 9700 §2.1
assert challenge_method == "S256"
assert valid_pkce_challenge?(challenge)
continuation = %{profile_id: profile.id, callback_uri: callback, state: state, challenge: challenge}
# signed to the browser session; approval then creates the one-time DB code
```

### Pattern 3: locked consume-and-issue
**What:** Query one digest-addressed authorization-code or MFA-challenge row `FOR UPDATE`, reject consumed/expired/binding-mismatched rows, mark it consumed, and issue the app family in one `Ecto.Multi`. Emit any audit/telemetry only after commit. If issue/audit fails, no code/challenge becomes consumed and no raw app credential escapes.

**When to use:** Hosted exchange and direct MFA completion.

**Example:**
```elixir
# Source: Phase 245 locked refresh pattern
Ecto.Multi.new()
|> AppLoginCode.lock_and_validate(raw_code, verifier, profile, callback)
|> Ecto.Multi.update(:consume_code, consume_changeset)
|> Ecto.Multi.run(:app_session, fn _repo, %{code: code} ->
  Sigra.AppSession.issue(config, code.user, code.client_ref)
end)
|> repo.transaction()
```

### Pattern 4: opaque direct-MFA challenge
**What:** On a valid direct password that needs MFA, generate a random one-time challenge; persist only its digest, exact static profile/client reference, user ID, expiry at now + 300 seconds, and terminal timestamps. Return the raw challenge alone. On MFA completion, lock the digest row, call existing `Sigra.MFA.verify/4` or backup-code primitive, consume only after success, and issue the app session in the same transaction.

**When to use:** Only profiles explicitly allowed to accept direct passwords.

### Anti-Patterns to Avoid

- **Using Lockspire or claiming OAuth/OIDC conformance:** Phase 246 is first-party authentication, not an authorization server. Keep discovery/JWKS/consent/external client registration out. [VERIFIED: Phase 243 CONTEXT.md]
- **Dynamic registration or wildcard callbacks:** Never accept a callback/origin from a request unless it exact-matches a static profile field. [CITED: https://www.rfc-editor.org/rfc/rfc9700.html]
- **`plain` PKCE or stored verifier:** Require `S256`; retain only the challenge server-side and verify it against supplied verifier at exchange. [CITED: https://www.rfc-editor.org/rfc/rfc7636.html]
- **Redirecting immediately after browser password/MFA:** Explicit approval is required even for an existing browser session; avoid silent session-to-app credential transfer. [VERIFIED: phase scope]
- **Putting raw code/challenge/verifier/password in browser session, audit, logs, telemetry, or exceptions:** Persist hash/digest only and return secrets only after commit. [VERIFIED: Phase 245 patterns]
- **Separate consume and issue transactions:** A retry after an issue failure must not lose a valid code/challenge; use one lock/consume/issue transaction.
- **Credential enumeration through direct login:** Unknown profile/user, bad password, invalid MFA challenge/code, expired/consumed challenge, and disabled direct path receive the same public invalid-credentials body/status. `browser_required` is reserved for a valid static policy branch and contains no user fact.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Opaque app access/refresh lifecycle | a new token table or direct response generator | `Sigra.AppSession.issue/4` | Phase 245 provides digest-only credentials, TTLs, revocation, and refresh-reuse handling. [VERIFIED: codebase grep] |
| Password hashing/verification | a direct hash comparison | generated host `Auth.authenticate_user/2` / existing Sigra auth pipeline | Reuses host policy and avoids divergent enumeration/hasher behavior. [VERIFIED: codebase grep] |
| TOTP/backup verification | a ceremony-specific TOTP parser | `Sigra.MFA` and existing schemas | Existing lockout, replay, encrypted-secret, and backup-code behavior. [VERIFIED: codebase grep] |
| PKCE transform | plaintext or custom encoding | SHA-256 + unpadded base64url S256 implementation | RFC-defined formula and strict verifier/challenge syntax. [CITED: https://www.rfc-editor.org/rfc/rfc7636.html] |
| Browser session authentication | app-posted credentials in hosted endpoint | existing generated browser login/MFA routes | System browser retains user cookie/credential boundary. [CITED: https://www.rfc-editor.org/rfc/rfc8252.html] |

**Key insight:** The only new credential lifecycle state is the short-lived ceremony evidence. It authorizes exactly one call to the Phase 245 issuer, never a new credential model.

## Common Pitfalls

### Pitfall 1: flags become implied through shared Core options
**What goes wrong:** `--jwt`/`--api` or `--app-password-login` causes session schemas/routes to appear unexpectedly.
**Why it happens:** `Mix.Tasks.Sigra.Install` currently owns related switches in one Core feature and `jwt` already implies API behavior.
**How to avoid:** Add both switches with defaults `false`; define `app_password_login? = app_sessions? and opt`, reject or fail closed when password-login is selected without sessions, and make every file/migration/injection branch test all independent combinations.
**Warning signs:** Feature lists use `api? || jwt? || app_sessions?`, or generated config contains app-session schema fields after `--api` only. [VERIFIED: codebase grep]

### Pitfall 2: code exchange replay race
**What goes wrong:** Two exchanges both issue a session, or a failed transaction burns the code.
**Why it happens:** A preflight read and later update leave an unlocked window, or consumption commits before issuance.
**How to avoid:** Digest-indexed `FOR UPDATE` lookup, terminal/expiry/binding checks under lock, then consume and `AppSession.issue/4` inside one Multi. Use the existing ready/go barrier with real PostgreSQL transactions and no sleep/retry test. [VERIFIED: Phase 245 concurrency proof]
**Warning signs:** `repo.get_by` before `transaction`, code `used_at` written in a separate call, or raw session response created before commit.

### Pitfall 3: callback matching that is URL-normalized or prefix-based
**What goes wrong:** A hostile callback receives the authorization code.
**Why it happens:** URI parsing/reconstruction silently normalizes encoding, hosts, ports, or paths; prefix matching accepts lookalikes.
**How to avoid:** Compare the request callback URI to one static registered string exactly; allow only the documented localhost native port exception if the phase explicitly supports it, otherwise reject it. [CITED: https://www.rfc-editor.org/rfc/rfc9700.html]
**Warning signs:** `String.starts_with?`, wildcard configuration, request-supplied scheme/host, or a generic `return_to` redirect.

### Pitfall 4: MFA challenge becomes a bearer session
**What goes wrong:** Possession of an unexpired challenge alone lets another profile/user finish login, or retry consumes it before valid MFA.
**Why it happens:** The challenge has no profile binding or is marked consumed before MFA verification.
**How to avoid:** Persist digest + user ID + profile/client ref + 5-minute expiry and lock it; bind completion to the static profile and only consume on successful MFA in the same issue transaction. Normalize all invalid/expired/consumed outcomes.
**Warning signs:** challenge payload contains raw user claims, code paths call MFA before profile lookup, or success has two commits.

### Pitfall 5: direct login drifts into a password grant
**What goes wrong:** The public API is documented as OAuth, receives arbitrary `client_id`/scopes, or sends password to a generic token endpoint.
**Why it happens:** Similar parameter names and an urge to generalize client support.
**How to avoid:** Give direct login an explicitly first-party, static-profile route and types; omit OAuth discovery, scopes, consent, client secret, and dynamic registration. Keep Lockspire boundary docs/tests machine-checked. [VERIFIED: Phase 243 CONTEXT.md] [CITED: https://www.rfc-editor.org/rfc/rfc9700.html]

## Code Examples

### PKCE S256 validation
```elixir
# Source: RFC 7636 §4.2 / §4.6
def s256(verifier) when byte_size(verifier) in 43..128 do
  verifier
  |> then(&:crypto.hash(:sha256, &1))
  |> Base.url_encode64(padding: false)
end

def valid_verifier?(value), do: value =~ ~r/\A[A-Za-z0-9\-._~]{43,128}\z/
```

### One-time code exchange shape
```elixir
# Source: Phase 245 AppSession locked state-machine pattern
def exchange(config, raw_code, verifier, profile, callback_uri) do
  Ecto.Multi.new()
  |> Code.lock_validate_and_mark_consumed(raw_code, verifier, profile, callback_uri)
  |> Ecto.Multi.run(:session, fn _repo, %{code: %{user: user, client_ref: ref}} ->
    Sigra.AppSession.issue(config, user, ref)
  end)
  |> config.repo.transaction()
end
```

### Direct policy branch
```elixir
# Source: Phase scope; do not represent this as OAuth grant handling
case profile.direct_login do
  :browser_required -> {:error, :browser_required}
  :password_allowed -> direct_password_or_mfa(config, profile, email, password)
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| OAuth password grant for native credentials | System-browser authorization plus PKCE; direct first-party password path only as a separate host policy | RFC 9700 | Do not label direct password login OAuth or reuse OAuth token endpoints. [CITED: https://www.rfc-editor.org/rfc/rfc9700.html] |
| Embedded native WebView login | External user-agent/system browser | RFC 8252 | Browser cookie/credential isolation remains with the system browser. [CITED: https://www.rfc-editor.org/rfc/rfc8252.html] |
| Unprotected authorization-code exchange | PKCE S256 and one-time code consumption | RFC 7636 / RFC 9700 | Intercepted callback code cannot be exchanged without verifier; concurrent replay must serialize. [CITED: https://www.rfc-editor.org/rfc/rfc7636.html] |

**Deprecated/outdated:**
- OAuth Resource Owner Password Credentials grant: do not use it; RFC 9700 prohibits it and explains it does not support multi-step MFA. [CITED: https://www.rfc-editor.org/rfc/rfc9700.html]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|---|---|---|
| A1 | Phase 246 can add a dedicated installer feature rather than extending `Core`; the exact location is implementation discretion. | Recommended Project Structure | Medium—planner must first confirm existing feature-runner additive semantics and preserve golden output for no-flag installs. [ASSUMED] |
| A2 | The generated first-party profile is suitable as a static Elixir module/configuration rather than database administration UI. | Architecture Patterns | Medium—must be decided by the planner from generator conventions; dynamic registration is out of scope regardless. [ASSUMED] |

## Open Questions

1. **Which static callback forms are supported in this first release?**
   - What we know: exact callback matching is locked; RFC 8252 discusses claimed HTTPS, private-use schemes, and loopback forms.
   - What's unclear: whether Phase 246 should emit only claimed HTTPS/custom scheme profiles or also implement localhost port exception.
   - Recommendation: default to literal exact strings only; treat localhost variable-port support as an explicit later decision/test set, not silent URI normalization.

2. **How does a hosted browser continuation resume after existing browser MFA?**
   - What we know: the generated host has browser session and `mfa_pending` flows, and the requirement mandates explicit continuation.
   - What's unclear: exact LiveView/controller handling for carrying signed continuation through every login/MFA branch.
   - Recommendation: centralize a bounded signed continuation and add controller-mode + LiveView tests proving login, MFA, cancel, expiry, and re-entry preserve or reject it deterministically.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Elixir/Mix | library, generator, ExUnit | ✓ | OTP 28 / Mix available | — |
| PostgreSQL client | lock/replay integration proof | ✓ | 14.17 | existing `tmp/db.env` test database pattern |
| Docker | optional fresh-host/container proof | ✓ | 29.5.2 | local Mix/PostgreSQL proof |
| Node/npm | generated browser proof if needed | ✓ | Node 22.14.0 / npm 11.1.0 | controller and ExUnit integration proof |

**Missing dependencies with no fallback:** None found.

**Missing dependencies with fallback:** None found.

## Validation Architecture

### Test Framework
| Property | Value |
|---|---|
| Framework | ExUnit with real PostgreSQL integration helpers |
| Config file | `test/test_helper.exs` |
| Quick run command | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_test.exs test/sigra/app_login/concurrency_test.exs --trace` |
| Full suite command | `source tmp/db.env && MIX_ENV=test mix ci` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| APP-01 | Both flags are false by default and each flag combination generates exactly its intended files/config/routes; API/JWT do not imply either flag. | generator + fresh-host runtime | `MIX_ENV=test mix test test/sigra/install/app_sessions_generator_test.exs --trace` | ❌ Wave 0 |
| APP-02 | Start validates static profile/callback/S256/state; browser continuation requires approval; exchange consumes once and issues Phase 245 session. | PostgreSQL integration + controller/LiveView | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_test.exs --trace` | ❌ Wave 0 |
| APP-02 | Two same-code exchanges serialize to one issuance; rollback leaves code usable and leaks no credentials. | PostgreSQL concurrency/fault injection | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login/concurrency_test.exs --trace` | ❌ Wave 0 |
| APP-03 | Password failures are observationally uniform; direct policy returns `browser_required`; 5m MFA challenge is opaque, profile-bound, single-use, and issues same session. | PostgreSQL integration + generated endpoint | `source tmp/db.env && MIX_ENV=test mix test test/sigra/app_login_test.exs --trace` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** focused generator or app-login test command plus exact-path `mix format --check-formatted`.
- **Per wave merge:** all Phase 246 focused tests and `git diff --check`.
- **Phase gate:** `source tmp/db.env && MIX_ENV=test mix ci`; if unrelated baseline failures persist, record them as failing diagnostics and do not call them passing evidence.

### Wave 0 Gaps
- [ ] `test/sigra/install/app_sessions_generator_test.exs` — APP-01 flag matrix, isolation, generated-source assertions, and fresh-host proof.
- [ ] `test/sigra/app_login_test.exs` — APP-02/APP-03 end-to-end state-machine, uniform-error, policy, expiry, and same-issuer assertions.
- [ ] `test/sigra/app_login/concurrency_test.exs` — barrier-released code/challenge replay and rollback proof without sleeps.
- [ ] Deterministic browser continuation test appropriate to existing LiveView/controller modes — explicit approval/cancel and MFA resume.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | yes | System-browser hosted authentication; host password verification; existing MFA verifier; no OAuth password grant. |
| V3 Session Management | yes | Phase 245 digest-only opaque family/token lifecycle and atomic issuance. |
| V4 Access Control | yes | Static server-selected profile/client reference, exact callbacks, direct-login host policy. |
| V5 Input Validation | yes | Strict profile ID, exact callback, PKCE state/challenge/verifier syntax, and bounded strings before persistence. |
| V6 Cryptography | yes | `:crypto` SHA-256 S256 and existing `Sigra.Token` random/digest helpers; never hand-roll primitives. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Callback/code interception | Spoofing / Information Disclosure | System browser, PKCE S256, exact callback, transaction-specific `state`, 60-second one-time code. |
| Code or MFA replay/race | Elevation of Privilege | Digest-indexed row, `FOR UPDATE`, terminal transition + issue in one Multi, barrier concurrency proof. |
| Open redirect | Information Disclosure | Static exact callback allowlist; no query-string redirect target. |
| Account/profile enumeration | Information Disclosure | Uniform direct-password/MFA public response; no user/profile facts in error/audit output. |
| MFA challenge swapping | Elevation of Privilege | Bind challenge to user/profile/client ref and atomically consume after valid MFA. |
| Partial failure secret leak | Information Disclosure / Repudiation | Return raw access/refresh only from committed Multi; audit in same transaction, telemetry post-commit. |
| Scope/delegation confusion | Elevation of Privilege | App sessions establish identity/assurance only; Lockspire retains delegated OAuth authority. [VERIFIED: Phase 243 CONTEXT.md] |

## Sources

### Primary (HIGH confidence)
- Repository code and tests — `lib/sigra/app_session.ex`, `lib/sigra/mfa.ex`, `lib/sigra/token.ex`, installer Core/task, generated session/MFA templates, and Phase 245 PostgreSQL concurrency/audit patterns. [VERIFIED: codebase grep]
- Phase 243 ownership contract — Sigra first-party auth boundary versus Lockspire/Crosswake/host responsibilities. [VERIFIED: `.planning/phases/243-credential-boundary-and-pipeline-foundation/243-CONTEXT.md`]
- [RFC 7636](https://www.rfc-editor.org/rfc/rfc7636.html) — PKCE verifier syntax, S256 transform, challenge binding, verifier exchange. [CITED: https://www.rfc-editor.org/rfc/rfc7636.html]
- [RFC 9700](https://www.rfc-editor.org/rfc/rfc9700.html) — exact redirect matching, state binding, PKCE transaction binding, one-time code invalidation, no password grant. [CITED: https://www.rfc-editor.org/rfc/rfc9700.html]
- [RFC 8252](https://www.rfc-editor.org/rfc/rfc8252.html) — external/system browser and PKCE for public native clients. [CITED: https://www.rfc-editor.org/rfc/rfc8252.html]

### Secondary (MEDIUM confidence)
- [NIST SP 800-63B](https://pages.nist.gov/800-63-4/sp800-63b.html) — protected verifier channels and verifier-name/channel binding principles. [CITED: https://pages.nist.gov/800-63-4/sp800-63b.html]

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — existing Phase 245 APIs and installer/MFA code directly establish reuse points.
- Architecture: HIGH — locked Phase 243 ownership plus current IETF PKCE/native/security BCP guidance.
- Pitfalls: HIGH — Phase 245 has concrete transaction/concurrency proofs and standards identify redirect/code hazards.

**Research date:** 2026-08-12
**Valid until:** 2026-09-11 (stable internal stack and published standards; recheck current project state before execution)
