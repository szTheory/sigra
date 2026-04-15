# Phase 20: Passkey Challenge Plug + Runtime Config + JS Hooks Infra - Research

**Researched:** 2026-04-15
**Domain:** Phoenix/Plug WebAuthn edge integration, runtime config validation, and LiveView JS hook wiring
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Challenge contract

- **D-01 (session storage shape):** Use **explicit ceremony-specific session slots**, not one polymorphic challenge envelope and not a generic challenge-store abstraction. The Plug layer owns two namespaced session keys:
  - registration challenge slot
  - authentication challenge slot
  Each slot stores a small common envelope with only the fields needed to verify and invalidate the ceremony.

- **D-02 (generation and verification contract):** `Sigra.Plug.PasskeyChallenge` generates the challenge with `Sigra.Token.generate/4`, purpose `"sigra-passkey-challenge"`, `max_age: 60`, stores it in the appropriate Plug session slot, verifies against the stored value on response, and never trusts `clientDataJSON` as the challenge source.

- **D-03 (deletion semantics):** Challenge records are **single-use**. On successful verify, the plug deletes the corresponding session slot immediately. Failed verification does not mint or trust a replacement value. Replay protection is part of the plug boundary, not delegated to the LiveView/controller caller.

- **D-04 (Plug/library boundary):** The Phase 19 split remains load-bearing:
  - `Sigra.Passkeys.Registration` and `Sigra.Passkeys.Authentication` stay `Plug.Conn`-free and explicit-challenge
  - `Sigra.Plug.PasskeyChallenge` is the Phoenix/Plug edge adapter that fetches, issues, verifies, and invalidates session-held challenges
  This preserves clean library isolation while keeping session concerns at the web edge.

- **D-05 (no generic store yet):** Do **not** introduce a behavior-backed challenge store abstraction in Phase 20. The roadmap explicitly locks storage to Plug session, and adding an abstraction now would add indirection without solving a current project problem.

### Runtime config posture

- **D-06 (config loading posture):** Use a **mixed runtime contract**:
  - strict validation for security-critical identity/config invariants
  - safe defaults for operator tunables
  - no `Application.get_env` lookups in ceremony hot paths
  Runtime config is resolved once, validated, normalized into `%Sigra.Config{}` / `config.passkeys`, then passed explicitly downstream.

- **D-07 (required runtime keys):** `rp_id` and `origin` are required and validated at boot or config-build time. Invalid or missing values fail loudly with precise remediation text. Sigra should not defer RP identity mistakes to ceremony runtime.

- **D-08 (validated enums and bounded tunables):**
  - `attestation` remains explicit and validated; default `:none`
  - `user_verification` remains explicit and validated against supported values
  - `timeout_ms` is bounded and normalized
  - ceremony initiation rate limit defaults to **5/min per user** and validates override shape

- **D-09 (dev/prod ergonomics):** Developer ergonomics come from **clear startup errors and documented defaults**, not from permissive silent coercion. The system should be easy to configure correctly, but misconfigured RP identity must fail fast.

- **D-10 (configuration ownership):** Runtime config loading belongs to Sigra's existing `%Sigra.Config{}` pattern, not to the hook layer, not to ad hoc endpoint config reads in controllers, and not to generator-only docs. Phase 20 should extend the established config-first posture rather than invent a passkey-specific exception.

### Hook API shape

- **D-11 (public JS seam):** `passkey_hooks.js` exports **generated rich Phoenix hook objects**, not only thin helper functions. Phase 21 templates should be able to mount a stable, batteries-included hook boundary without host apps rewriting ceremony lifecycle logic.

- **D-12 (hook set):** Generate explicit hook objects for the two ceremony roles:
  - registration hook
  - authentication hook
  Shared helpers may live behind them, but the public seam should be hook-oriented because Phoenix LiveView already treats browser integration through `phx-hook`.

- **D-13 (event contract):** Hooks must always return explicit outcomes to the server side:
  - success
  - error
  - aborted
  No silent failures, swallowed browser exceptions, or host-app-specific ad hoc event naming as the default path.

- **D-14 (lifecycle cleanup):** Hook teardown must cancel in-flight ceremonies on `destroyed` and `disconnected`, using the browser/library abort mechanism rather than leaving stale browser state alive across LiveView navigation or reconnect churn.

- **D-15 (data flow posture):** Hooks consume server-provided ceremony options, invoke the browser WebAuthn API, and push normalized results back to LiveView/controller endpoints. The host app should not have to assemble raw browser payload plumbing itself on the blessed path.

### Generator asset wiring

- **D-16 (standard-path injection posture):** Use **strict marker-based injection** into `assets/js/app.js` for the standard Phoenix asset layout. This matches Sigra's existing generator architecture: deterministic, idempotent, and easy to test.

- **D-17 (custom layout fallback):** If the marker comment is absent, Sigra still writes `passkey_hooks.js` but **does not attempt heuristic rewrites** of custom Vite/Webpack/esbuild entrypoints. Instead it prints exact manual instructions with the precise import and hook-registration lines to add. No silent partial success.

- **D-18 (no heuristics):** Do **not** scan likely files like `main.js`, `app.ts`, or bundler-specific entrypoints and guess where to inject. That would trade small DX gains for brittle edits and reduced user trust in generator output.

- **D-19 (phase-21 readiness):** The generated import/registration contract must be stable enough that Phase 21 can assume a standard hook name and registration shape in generated templates, while still offering manual instructions when a host app is off the blessed asset path.

### Cross-cutting architecture

- **D-20 (single architectural stance across all four areas):** Phase 20 should be **opinionated at the edges, explicit in contracts, and conservative about hidden magic**:
  - explicit session slots instead of generic abstraction
  - explicit runtime config validation instead of permissive lazy reads
  - explicit hook objects instead of app-owned ceremony glue
  - explicit marker-based generator wiring instead of heuristics
  This is the most coherent path with Sigra's project goals: secure-by-default, generator-trustworthy, Phoenix-native, and ready for additive Phase 21 UX work.

### Claude's Discretion

- Exact internal module names for session helper utilities and hook helper functions
- Exact session envelope field names, so long as they remain ceremony-specific and minimal
- Exact client event names and payload keys, so long as success/error/aborted are all represented explicitly and documented
- Exact marker-comment wording in `assets/js/app.js`, so long as injection remains deterministic and idempotent
- Exact timeout bounds and error-message phrasing, so long as config validation remains strict for identity fields and clear for tunables

### Deferred Ideas (OUT OF SCOPE)

- Generic behavior-backed challenge store (ETS/Redis/distributed adapters) — out of scope unless a later phase introduces a real non-session requirement.
- Heuristics-based bundler entrypoint rewriting beyond `assets/js/app.js` marker detection — explicitly rejected for this phase.
- Fully app-owned custom hook contract as the default path — leave as an escape hatch, not the blessed Sigra architecture.
- Full passkey UX flows, templates, emails, and route/controller/liveview surfaces — Phase 21.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| PK-06 | Plug-session-backed server-generated/server-verified challenge with no `clientDataJSON` trust | Session-slot plug pattern, token envelope shape, replay-deletion semantics, and plug test strategy [VERIFIED: 20-CONTEXT.md] [VERIFIED: lib/sigra/passkeys/registration.ex] [VERIFIED: lib/sigra/passkeys/authentication.ex] |
| PK-09 | Runtime-loaded passkey RP config with NimbleOptions fast-fail | `Sigra.Passkeys.config/0` first-use validator/cacher extending current `Sigra.Config` schema and `runtime.exs` guidance [VERIFIED: lib/sigra/config.ex] [VERIFIED: priv/templates/sigra.install/core/auth.ex] [CITED: https://hexdocs.pm/elixir/main/config-and-releases.html] |
| PK-10 | Per-user Hammer ceremony-initiation limit | Reuse `Sigra.RateLimiter` behaviour and `Sigra.RateLimiters.Hammer` wrapper with a passkey-user key namespace proven by unit tests [VERIFIED: lib/sigra/rate_limiter.ex] [VERIFIED: lib/sigra/rate_limiters/hammer.ex] [VERIFIED: lib/sigra/plug/rate_limit.ex] |
| GEN-06 | `passkey_hooks.js` generation plus deterministic `assets/js/app.js` injection/manual fallback | Fresh Phoenix 1.8 `app.js` shape probe, installer gap analysis, and new JS-specific injector/report requirements [VERIFIED: mix phx.new probe 2026-04-15] [VERIFIED: lib/sigra/install/injector.ex] [VERIFIED: lib/sigra/install/report.ex] |
</phase_requirements>

## Summary

Phase 20 should be planned as an edge-integration phase, not a new WebAuthn-core phase. The Phase 19 primitives already expect explicit `Wax.Challenge` values and stay `Plug.Conn`-free, so the correct design is a narrow `Sigra.Plug.PasskeyChallenge` adapter that issues a signed token, stores only a minimal ceremony-specific envelope in the Plug session, reconstructs the expected `Wax.Challenge` for verification, and deletes the slot on success. [VERIFIED: lib/sigra/passkeys/registration.ex] [VERIFIED: lib/sigra/passkeys/authentication.ex] [VERIFIED: .planning/phases/20-passkey-challenge-plug-runtime-config-js-hooks-infra/20-CONTEXT.md]

The kickoff spike came back clean: storing two session slots, each containing only a signed passkey token, produced a 620-byte encrypted cookie in a real `Plug.Session.COOKIE` probe, leaving substantial headroom below the 4 KB browser ceiling. The risky part of the phase is not cookie size; it is contract discipline. The current codebase has no `Sigra.Passkeys.config/0`, the current installer has no JS-file anchor support, and a fresh Phoenix 1.8 `assets/js/app.js` already merges `colocatedHooks`, so passkey hook registration must merge into existing hooks instead of replacing them. [VERIFIED: mix run Plug.Session.COOKIE probe 2026-04-15] [VERIFIED: lib/sigra/config.ex] [VERIFIED: lib/sigra/install/injector.ex] [VERIFIED: mix phx.new probe 2026-04-15]

**Primary recommendation:** Plan Phase 20 around four concrete deliverables: a Plug-session challenge adapter, a first-use runtime passkey config loader/cacher, a per-user Hammer ceremony throttle, and a JS asset path that merges passkey hooks into Phoenix 1.8’s existing `LiveSocket` hook map or emits exact manual instructions when the Sigra marker is absent. [VERIFIED: 20-CONTEXT.md] [VERIFIED: lib/sigra/rate_limiters/hammer.ex] [CITED: https://hexdocs.pm/phoenix_live_view/js-interop.html]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Challenge issuance, storage, verification, invalidation | Frontend Server (Plug/Phoenix) | Browser | The browser only echoes ceremony payloads; server-side session ownership is the replay defense boundary. [VERIFIED: 20-CONTEXT.md] [CITED: https://simplewebauthn.dev/docs/advanced/server/custom-challenges] [CITED: https://www.w3.org/TR/webauthn-3/] |
| RP ID / origin / timeout runtime validation | API / Backend | Frontend Server | These are security-critical relying-party invariants and must be validated before ceremony code runs. [VERIFIED: 20-CONTEXT.md] [VERIFIED: lib/sigra/config.ex] [CITED: https://hexdocs.pm/elixir/main/config-and-releases.html] |
| Browser WebAuthn ceremony invocation | Browser / Client | Frontend Server | `@simplewebauthn/browser` runs in the browser, but its inputs and outputs are owned by Phoenix hooks. [CITED: https://simplewebauthn.dev/docs/packages/browser/] [CITED: https://hexdocs.pm/phoenix_live_view/js-interop.html] |
| Hook lifecycle cleanup and abort handling | Browser / Client | Frontend Server | `destroyed` and `disconnected` are client hook lifecycle events; they must terminate in-flight browser work. [CITED: https://hexdocs.pm/phoenix_live_view/js-interop.html] |
| Ceremony-initiation rate limiting | API / Backend | Frontend Server | Rate limits should key off authenticated user identity, not browser-local state. [VERIFIED: lib/sigra/rate_limiter.ex] [VERIFIED: lib/sigra/rate_limiters/hammer.ex] |
| `assets/js/app.js` mutation and fallback instructions | Frontend Server tooling | Browser / Client | The generator owns file mutation; browser behavior depends on the injected import and hook registration. [VERIFIED: lib/sigra/install/injector.ex] [VERIFIED: lib/sigra/install/report.ex] |

## Project Constraints (from CLAUDE.md)

- Phoenix 1.8+ / Ecto 3.x is the blessed path; Plug compatibility is allowed only where DX is not compromised. [VERIFIED: CLAUDE.md]
- PostgreSQL is the primary local/CI database; local `mix test` expects a live Postgres at `localhost:5432` with `postgres/postgres`. [VERIFIED: CLAUDE.md] [VERIFIED: pg_isready localhost:5432 probe 2026-04-15]
- Security-sensitive code belongs in the library, while generators should emit app-owned seams. [VERIFIED: CLAUDE.md]
- Testing must cover happy path, main error cases, and boundary conditions using flat, self-contained AAA tests. [VERIFIED: CLAUDE.md]
- Do not recommend ambient `Application.get_env` reads as the primary library config model; Sigra’s existing architecture prefers explicit validated config. [VERIFIED: CLAUDE.md] [VERIFIED: lib/sigra/config.ex]

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `plug` | `1.19.1` (updated Dec 09, 2025) | Session fetch/put/delete and cookie-backed session storage | Phase 20’s replay defense lives at the Plug session boundary. [VERIFIED: mix.lock] [CITED: https://hex.pm/packages/plug] [CITED: https://hexdocs.pm/plug/Plug.Conn.html] |
| `wax_` | `0.7.0` (updated May 18, 2025) | Server-side WebAuthn challenge and assertion verification | Already adopted in Phase 19; keep crypto verification in the library, not JS. [VERIFIED: mix.lock] [CITED: https://hex.pm/packages/wax_] [VERIFIED: lib/sigra/passkeys/registration.ex] [VERIFIED: lib/sigra/passkeys/authentication.ex] |
| `nimble_options` | `1.1.1` | First-use validation of passkey runtime config | Sigra already uses it for config surfaces; Phase 20 should extend, not bypass, that pattern. [VERIFIED: mix.lock] [VERIFIED: lib/sigra/config.ex] [VERIFIED: mix hex.info nimble_options] |
| `hammer` | `7.3.0` | Per-user ceremony-initiation throttling | Sigra already wraps Hammer behind `Sigra.RateLimiter`, so Phase 20 can reuse the same abstraction. [VERIFIED: mix.lock] [VERIFIED: mix hex.info hammer] [VERIFIED: lib/sigra/rate_limiters/hammer.ex] |
| `phoenix_live_view` | `1.1.28` (updated Mar 27, 2026) | Hook lifecycle and `LiveSocket` hook registration model | Hook lifecycle and hook-map merge behavior are defined here. [CITED: https://hex.pm/packages/phoenix_live_view] [CITED: https://hexdocs.pm/phoenix_live_view/js-interop.html] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `@simplewebauthn/browser` | `13.3.0` (published Mar 10, 2026) | Browser-side `startRegistration()` / `startAuthentication()` helpers | Use in generated `passkey_hooks.js`; do not hand-roll browser payload plumbing. [VERIFIED: npm view @simplewebauthn/browser version time] [CITED: https://simplewebauthn.dev/docs/packages/browser/] |
| `Plug.Test` / `Phoenix.ConnTest` | repo-local test tooling | Plug session and installer regression tests | Use for challenge plug/session tests and generated-app install assertions. [VERIFIED: test/sigra/plug/fetch_session_test.exs] [VERIFIED: test/sigra/plug/put_active_organization_test.exs] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Plug session challenge slots | Generic challenge store abstraction | Adds indirection now without solving a real requirement; explicitly rejected in context. [VERIFIED: 20-CONTEXT.md] |
| Hook object exports | Thin browser helper functions | Forces Phase 21 templates to own ceremony lifecycle/error plumbing again. [VERIFIED: 20-CONTEXT.md] |
| Marker/manual fallback | Heuristic bundler rewriting | Violates the repo’s deterministic generator posture and is more brittle than honest manual instructions. [VERIFIED: 20-CONTEXT.md] [VERIFIED: lib/sigra/install/injector.ex] |

**Installation:**
```bash
npm install @simplewebauthn/browser
mix deps.get
```

**Version verification:** `@simplewebauthn/browser` is `13.3.0` as of March 10, 2026 via `npm view`; the repo lockfile currently pins `plug 1.19.1`, `wax_ 0.7.0`, `hammer 7.3.0`, and `nimble_options 1.1.1`. [VERIFIED: npm view @simplewebauthn/browser version time] [VERIFIED: mix.lock] [VERIFIED: mix hex.info wax_] [VERIFIED: mix hex.info hammer] [VERIFIED: mix hex.info nimble_options] [VERIFIED: mix hex.info plug]

## Architecture Patterns

### System Architecture Diagram

```text
LiveView/controller request
  -> Sigra.Plug.PasskeyChallenge.issue(conn, ceremony_kind, config)
  -> Sigra.Token.generate(secret_key_base, "sigra-passkey-challenge", payload, max_age: 60)
  -> Plug session slot write (registration or authentication)
  -> Browser hook receives options + token-backed challenge
  -> @simplewebauthn/browser startRegistration/startAuthentication
  -> Hook pushes result payload back to LiveView/controller
  -> Sigra.Plug.PasskeyChallenge.verify(conn, ceremony_kind, response, config)
  -> verify stored signed token + rebuild expected Wax.Challenge
  -> Sigra.Passkeys.Registration.verify / Authentication.verify
  -> success: delete session slot immediately
  -> failure: keep slot unchanged, return explicit error/aborted outcome
```

### Recommended Project Structure
```text
lib/
├── sigra/plug/passkey_challenge.ex   # issue/verify/delete challenge slots at Plug edge
├── sigra/passkeys.ex                 # first-use runtime config loader + rate-limit helpers
├── sigra/install/features/passkeys.ex# passkey asset files, injections, manual instructions
└── sigra/install/injector.ex         # new JS-specific app.js anchor support

priv/templates/sigra.install/passkeys/
├── passkey_hooks.js                  # generated browser hook module
└── app_js_passkeys_injection.js      # injected block containing import + hook merge marker

test/sigra/
├── plug/passkey_challenge_test.exs   # replay, delete-on-success, session slot shape
├── passkeys/config_test.exs          # first-use runtime validation
├── passkeys/rate_limit_test.exs      # per-user key shape and 6th-hit reject
└── install/features/passkeys_js_test.exs # app.js inject/manual fallback coverage
```

### Pattern 1: Plug edge adapter around explicit-challenge primitives
**What:** `Sigra.Plug.PasskeyChallenge` should own issuance, session storage, verification, and invalidation, while passing reconstructed `Wax.Challenge` structs into the existing Phase 19 primitives. [VERIFIED: lib/sigra/passkeys/registration.ex] [VERIFIED: lib/sigra/passkeys/authentication.ex]
**When to use:** Every WebAuthn registration/authentication boundary that has a `Plug.Conn`. [VERIFIED: 20-CONTEXT.md]
**Example:**
```elixir
# Source: repo pattern + official Plug session API
conn
|> Plug.Conn.fetch_session()
|> Plug.Conn.put_session("sigra_passkey_registration_challenge", %{"token" => signed_token})

# Later, after successful verification:
conn
|> Plug.Conn.fetch_session()
|> Plug.Conn.delete_session("sigra_passkey_registration_challenge")
```
[CITED: https://hexdocs.pm/plug/Plug.Conn.html]

### Pattern 2: First-use validated runtime config, then explicit downstream passing
**What:** Add `Sigra.Passkeys.config/0` as a first-use validator/cacher that reads host runtime config once, validates `rp_id`, `rp_name`, `origin`, `attestation`, `user_verification`, `timeout_ms`, and rate-limit shape, then returns normalized passkey config for downstream call sites. [VERIFIED: lib/sigra/config.ex] [VERIFIED: priv/templates/sigra.install/core/auth.ex]
**When to use:** Passkey ceremony entrypoints and generator-rendered host code. [VERIFIED: 20-CONTEXT.md]
**Example:**
```elixir
# Source: existing Sigra config posture
def config do
  case :persistent_term.get({__MODULE__, :config}, :missing) do
    :missing ->
      validated = build_and_validate_runtime_config!()
      :persistent_term.put({__MODULE__, :config}, validated)
      validated

    cached ->
      cached
  end
end
```
[VERIFIED: lib/sigra/config.ex] [CITED: https://hexdocs.pm/elixir/main/config-and-releases.html]

### Pattern 3: Merge passkey hooks into the existing `LiveSocket` hooks map
**What:** Inject a Sigra-owned import plus a merged hook map, not a replacement `hooks:` object. Fresh Phoenix 1.8 apps already include `hooks: {...colocatedHooks}`. [VERIFIED: mix phx.new probe 2026-04-15]
**When to use:** Standard Phoenix `assets/js/app.js` with the Sigra marker present. [VERIFIED: 20-CONTEXT.md]
**Example:**
```javascript
// Source: fresh Phoenix 1.8 app.js shape + LiveView hook docs
import { PasskeyHooks } from "./passkey_hooks"

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: { ...colocatedHooks, ...PasskeyHooks },
})
```
[VERIFIED: mix phx.new probe 2026-04-15] [CITED: https://hexdocs.pm/phoenix_live_view/js-interop.html]

### Anti-Patterns to Avoid
- **Parsing `clientDataJSON` as the source of truth for challenge verification:** Treat it only as signed browser output; the authoritative challenge comes from the server-owned session slot. [CITED: https://simplewebauthn.dev/docs/advanced/server/custom-challenges] [CITED: https://www.w3.org/TR/webauthn-3/]
- **Storing full `Wax.Challenge` structs in the session:** Store the minimal signed-token envelope instead; this keeps the cookie budget small and avoids serializer coupling. [VERIFIED: mix run Plug.Session.COOKIE probe 2026-04-15]
- **Replacing the LiveView `hooks` map:** Fresh Phoenix 1.8 apps already spread `colocatedHooks`, so replacement would break existing hooks. [VERIFIED: mix phx.new probe 2026-04-15]
- **Using the current injector as-is for `app.js`:** Today it only supports Elixir-file anchors, so Phase 20 needs a JS-specific anchor path or dedicated helper. [VERIFIED: lib/sigra/install/injector.ex]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Browser ceremony plumbing | Custom base64url/browser WebAuthn wrappers | `@simplewebauthn/browser` | The package already covers registration/authentication flows and conditional UI guidance. [CITED: https://simplewebauthn.dev/docs/packages/browser/] |
| WebAuthn cryptographic verification | Manual `clientDataJSON` / authenticator parsing | `wax_` via existing `Sigra.Passkeys.{Registration,Authentication}` | Phase 19 already established the server verification path. [VERIFIED: lib/sigra/passkeys/registration.ex] [VERIFIED: lib/sigra/passkeys/authentication.ex] |
| Rate limiter state machine | Ad hoc ETS counters inside Phase 20 | `Sigra.RateLimiter` + `Sigra.RateLimiters.Hammer` | Reuses existing abstraction and keeps test doubles cheap. [VERIFIED: lib/sigra/rate_limiter.ex] [VERIFIED: lib/sigra/rate_limiters/hammer.ex] |
| Heuristic JS entrypoint discovery | File guessing across `main.js`, `app.ts`, Vite, Webpack | Marker detection + manual instructions | This is an explicit locked decision and matches existing generator trust posture. [VERIFIED: 20-CONTEXT.md] |

**Key insight:** Phase 20 is mostly glue code, but each glue seam already has a standard owner in this repo. Hand-rolling new abstractions here would make the plan larger and less reliable, not more flexible. [VERIFIED: 20-CONTEXT.md] [VERIFIED: lib/sigra/install/injector.ex]

## Common Pitfalls

### Pitfall 1: Replay-safe token issuance but replay-unsafe verification
**What goes wrong:** The server mints a challenge correctly, then later trusts the browser-submitted challenge instead of the session-held value. [CITED: https://simplewebauthn.dev/docs/advanced/server/custom-challenges]
**Why it happens:** `clientDataJSON.challenge` is easy to reach, and teams conflate “signed by authenticator” with “server-authoritative”. [CITED: https://www.w3.org/TR/webauthn-3/]
**How to avoid:** Verify the session-stored signed token first, rebuild the expected `Wax.Challenge` from that value, and delete the slot only after successful verification. [VERIFIED: 20-CONTEXT.md]
**Warning signs:** Any code path that decodes challenge from `clientDataJSON` before looking up the session slot. [VERIFIED: 20-CONTEXT.md]

### Pitfall 2: Silent RP config drift or nil defaults
**What goes wrong:** `rp_id` / `origin` remain nil or malformed until a ceremony fails deep inside WebAuthn code. [VERIFIED: lib/sigra/config.ex]
**Why it happens:** The current shared config schema allows `rp_id` and `origin` to default to nil. [VERIFIED: lib/sigra/config.ex]
**How to avoid:** Add a passkeys-specific first-use validator that upgrades those fields from “schema-valid” to “runtime-required”. [VERIFIED: 20-CONTEXT.md]
**Warning signs:** `config.passkeys[:rp_id] == nil` or `origin` values assembled ad hoc in controllers/LiveViews. [VERIFIED: lib/sigra/config.ex]

### Pitfall 3: Breaking existing LiveView hooks during `app.js` injection
**What goes wrong:** The generated block overwrites `hooks: {...colocatedHooks}` or injects into the wrong file shape. [VERIFIED: mix phx.new probe 2026-04-15]
**Why it happens:** Fresh Phoenix 1.8 apps already use colocated hooks, and Sigra’s current injector has no JS-specific anchor support. [VERIFIED: mix phx.new probe 2026-04-15] [VERIFIED: lib/sigra/install/injector.ex]
**How to avoid:** Merge hook namespaces and add a dedicated JS injection helper or anchor, with manual instructions when the Sigra marker is absent. [VERIFIED: 20-CONTEXT.md]
**Warning signs:** Any injected `hooks:` block lacking `...colocatedHooks`, or any passkeys feature test that never inspects `assets/js/app.js`. [VERIFIED: mix phx.new probe 2026-04-15] [VERIFIED: test/support/install_fixture.ex]

### Pitfall 4: Cookie-budget folklore replacing a real measurement
**What goes wrong:** The plan spends time building unnecessary persistence just to avoid a cookie-size problem that is not actually present for the minimal envelope. [VERIFIED: mix run Plug.Session.COOKIE probe 2026-04-15]
**Why it happens:** Teams estimate raw challenge size but ignore the actual encrypted cookie overhead. [VERIFIED: mix run Plug.Session.COOKIE probe 2026-04-15]
**How to avoid:** Keep the session payload to the signed token envelope and regression-test that the serialized cookie stays comfortably under 4 KB. [VERIFIED: mix run Plug.Session.COOKIE probe 2026-04-15]
**Warning signs:** Storing full challenge structs or multiple redundant payload copies in session. [VERIFIED: 20-CONTEXT.md]

## Code Examples

Verified patterns from official sources:

### LiveView hook lifecycle contract
```javascript
// Source: https://hexdocs.pm/phoenix_live_view/js-interop.html
let Hooks = {}

Hooks.PasskeyAuthenticate = {
  mounted() {
    // start browser ceremony
  },
  destroyed() {
    // tear down in-flight work
  },
  disconnected() {
    // handle socket disconnect safely
  },
}
```
[CITED: https://hexdocs.pm/phoenix_live_view/js-interop.html]

### Server-owned challenge verification pattern
```typescript
// Source: https://simplewebauthn.dev/docs/advanced/server/custom-challenges
const expectedChallenge = getCurrentChallenge(sessionID);
const verification = await verifyAuthenticationResponse({
  // ...
  expectedChallenge: (challenge: string) => {
    const parsedChallenge = JSON.parse(base64url.decode(challenge));
    return parsedChallenge.actualChallenge === expectedChallenge;
  },
});
```
[CITED: https://simplewebauthn.dev/docs/advanced/server/custom-challenges]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Browser/client challenge as the main comparison value | Server-owned expected challenge with explicit verification callback | Present in current SimpleWebAuthn advanced docs | Matches Phase 20’s replay-safe boundary. [CITED: https://simplewebauthn.dev/docs/advanced/server/custom-challenges] |
| Single custom hook namespace in `app.js` | Phoenix 1.8 `phx.new` app.js already merges `colocatedHooks` into `hooks` | Verified in fresh Phoenix 1.8.5 app on 2026-04-15 | Sigra must merge passkey hooks, not replace them. [VERIFIED: mix phx.new probe 2026-04-15] |
| Build-time-only config for deployment identity values | `config/runtime.exs` for runtime environment values | Current Elixir release docs | RP ID/origin belong in runtime config, not compile-time literals. [CITED: https://hexdocs.pm/elixir/main/config-and-releases.html] |

**Deprecated/outdated:**
- Trusting `clientDataJSON.challenge` as the authoritative replay check is outdated and unsafe for this phase’s threat model. [CITED: https://simplewebauthn.dev/docs/advanced/server/custom-challenges] [CITED: https://www.w3.org/TR/webauthn-3/]
- Replacing `hooks:` wholesale in Phoenix 1.8 `app.js` is outdated because fresh apps already include colocated hooks. [VERIFIED: mix phx.new probe 2026-04-15]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A new JS-specific injector helper or anchor should be added instead of overloading existing Elixir-only anchors. | Architecture Patterns | Low: if another clean path already exists, the implementation plan can swap it in without changing user-visible behavior. [ASSUMED] |

## Open Questions

1. **Where should the Sigra-owned `app.js` marker live for first install?**
   - What we know: fresh Phoenix 1.8.5 `assets/js/app.js` contains no Sigra marker and already includes `hooks: {...colocatedHooks}`. [VERIFIED: mix phx.new probe 2026-04-15]
   - What's unclear: whether the first install should anchor off the current Phoenix line shape and insert a marker-owned block, or whether another Sigra phase already intends to own `app.js`. [VERIFIED: lib/sigra/install/injector.ex]
   - Recommendation: plan an explicit Wave 0 decision and lock the exact marker string before implementation starts. [VERIFIED: 20-CONTEXT.md]

2. **Should passkey runtime config return a keyword list or a dedicated struct?**
   - What we know: current Sigra config surfaces mostly expose validated keyword lists inside `%Sigra.Config{}`. [VERIFIED: lib/sigra/config.ex]
   - What's unclear: whether Phase 20 wants only `Sigra.Passkeys.config/0` convenience or a broader runtime-config refactor.
   - Recommendation: keep Phase 20 narrow and return normalized keyword config compatible with existing `config.passkeys` call sites. [VERIFIED: 20-CONTEXT.md]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | config/session probe, library tests | ✓ | `1.19.5` | — |
| Mix | library tests and generator tests | ✓ | `1.19.5` | — |
| Node.js | `@simplewebauthn/browser` install and asset smoke tests | ✓ | `v22.14.0` | — |
| npm | browser package install verification | ✓ | `11.1.0` | — |
| Docker | optional local Postgres bootstrap per CLAUDE.md | ✓ | `29.3.1` | use existing local Postgres |
| PostgreSQL | root `mix test` prereq | ✓ | accepting on `localhost:5432` | — |

**Missing dependencies with no fallback:**
- None. [VERIFIED: local environment probes 2026-04-15]

**Missing dependencies with fallback:**
- None. [VERIFIED: local environment probes 2026-04-15]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit + Mox with repo-level `mix test` [VERIFIED: test/test_helper.exs] |
| Config file | `test/test_helper.exs` [VERIFIED: test/test_helper.exs] |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/plug/passkey_challenge_test.exs test/sigra/passkeys/config_test.exs test/sigra/passkeys/rate_limit_test.exs test/sigra/install/features/passkeys_js_test.exs -x` |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test` [VERIFIED: CLAUDE.md] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PK-06 | session-stored challenge, replay reject, delete-on-success, no `clientDataJSON` trust | unit + plug | `mix test test/sigra/plug/passkey_challenge_test.exs -x` | ❌ Wave 0 |
| PK-09 | first-use runtime config fast-fail and defaults | unit | `mix test test/sigra/passkeys/config_test.exs -x` | ❌ Wave 0 |
| PK-10 | per-user Hammer key shape and 6th-hit reject | unit | `mix test test/sigra/passkeys/rate_limit_test.exs -x` | ❌ Wave 0 |
| GEN-06 | marker-path injects, custom-path skips and prints manual instructions | integration-ish ExUnit fixture test | `mix test test/sigra/install/features/passkeys_js_test.exs -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/sigra/plug/passkey_challenge_test.exs test/sigra/passkeys/config_test.exs test/sigra/passkeys/rate_limit_test.exs test/sigra/install/features/passkeys_js_test.exs -x`
- **Per wave merge:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/sigra/plug/passkey_challenge_test.exs` — covers PK-06 replay, delete-on-success, slot separation
- [ ] `test/sigra/passkeys/config_test.exs` — covers PK-09 runtime validation and defaults
- [ ] `test/sigra/passkeys/rate_limit_test.exs` — covers PK-10 key shape and 6th-hit deny
- [ ] `test/sigra/install/features/passkeys_js_test.exs` — covers GEN-06 asset injection/manual fallback
- [ ] `test/support/install_fixture.ex` asset capture extension or dedicated fixture helper — current tracked dirs omit `assets/`, so JS injection assertions need new support [VERIFIED: test/support/install_fixture.ex]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Server-owned WebAuthn challenge issuance/verification via `Sigra.Plug.PasskeyChallenge` + `wax_` [VERIFIED: 20-CONTEXT.md] [VERIFIED: lib/sigra/passkeys/authentication.ex] |
| V3 Session Management | yes | Plug session slot storage with delete-on-success semantics [VERIFIED: 20-CONTEXT.md] [CITED: https://hexdocs.pm/plug/Plug.Conn.html] |
| V4 Access Control | no | Phase 20 does not introduce authorization boundaries beyond authenticated-user ceremony throttling. [VERIFIED: 20-CONTEXT.md] |
| V5 Input Validation | yes | `NimbleOptions` validation for runtime passkey config and rate-limit shape [VERIFIED: lib/sigra/config.ex] [VERIFIED: mix hex.info nimble_options] |
| V6 Cryptography | yes | `Sigra.Token` for signed challenge tokens; `wax_` for WebAuthn verification; never hand-roll crypto. [VERIFIED: lib/sigra/token.ex] [VERIFIED: lib/sigra/passkeys/registration.ex] [VERIFIED: lib/sigra/passkeys/authentication.ex] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Challenge replay by reusing browser-supplied challenge | Replay / Tampering | Verify only against the session-stored server token and invalidate after success. [VERIFIED: 20-CONTEXT.md] |
| RP ID rotation mismatch causing silent credential failures | Tampering / Availability | Persist `rp_id` on credentials, validate current runtime RP config, and log drift warnings. [VERIFIED: lib/sigra/passkeys/authentication.ex] [VERIFIED: 20-CONTEXT.md] |
| Ceremony-flood DoS | Denial of Service | Per-user Hammer limiter with explicit key namespace and clear error path. [VERIFIED: lib/sigra/rate_limiters/hammer.ex] [VERIFIED: 20-CONTEXT.md] |
| LiveView reconnect leaving stale browser ceremony running | Availability / Integrity | Hook `destroyed` and `disconnected` teardown with explicit aborted outcome. [CITED: https://hexdocs.pm/phoenix_live_view/js-interop.html] |

## Sources

### Primary (HIGH confidence)
- [`.planning/phases/20-passkey-challenge-plug-runtime-config-js-hooks-infra/20-CONTEXT.md`](./20-CONTEXT.md) - locked design decisions and scope
- [`.planning/REQUIREMENTS.md`](/Users/jon/projects/sigra/.planning/REQUIREMENTS.md) - PK-06, PK-09, PK-10, GEN-06 requirements
- [`lib/sigra/token.ex`](/Users/jon/projects/sigra/lib/sigra/token.ex) - signed-token primitive used for challenge issuance
- [`lib/sigra/config.ex`](/Users/jon/projects/sigra/lib/sigra/config.ex) - current passkeys config schema and defaults
- [`lib/sigra/passkeys/registration.ex`](/Users/jon/projects/sigra/lib/sigra/passkeys/registration.ex) - explicit challenge registration primitive
- [`lib/sigra/passkeys/authentication.ex`](/Users/jon/projects/sigra/lib/sigra/passkeys/authentication.ex) - explicit challenge authentication primitive and RP drift warning
- [`lib/sigra/rate_limiter.ex`](/Users/jon/projects/sigra/lib/sigra/rate_limiter.ex) and [`lib/sigra/rate_limiters/hammer.ex`](/Users/jon/projects/sigra/lib/sigra/rate_limiters/hammer.ex) - existing rate-limit abstraction
- [`lib/sigra/install/injector.ex`](/Users/jon/projects/sigra/lib/sigra/install/injector.ex) and [`lib/sigra/install/report.ex`](/Users/jon/projects/sigra/lib/sigra/install/report.ex) - current installer mutation/reporting capabilities
- `mix phx.new` probe on 2026-04-15 - fresh Phoenix 1.8.5 `assets/js/app.js` shape with existing `colocatedHooks` merge
- `mix run` Plug session cookie probe on 2026-04-15 - real encrypted cookie size for two challenge slots
- `npm view @simplewebauthn/browser version time` on 2026-04-15 - latest browser package version/date
- `mix hex.info wax_`, `hammer`, `nimble_options`, `plug`, `phoenix_live_view` on 2026-04-15 - installed/current Hex package versions

### Secondary (MEDIUM confidence)
- https://hexdocs.pm/plug/Plug.Conn.html - session API usage
- https://hexdocs.pm/elixir/main/config-and-releases.html - runtime config guidance
- https://hexdocs.pm/phoenix_live_view/js-interop.html - hook lifecycle and hook-map registration model
- https://simplewebauthn.dev/docs/packages/browser/ - browser package usage and conditional UI guidance
- https://simplewebauthn.dev/docs/advanced/server/custom-challenges - authoritative expected-challenge verification pattern
- https://hex.pm/packages/plug - current Plug package version/date
- https://hex.pm/packages/wax_ - current wax_ package version/date
- https://hex.pm/packages/phoenix_live_view - current LiveView package version/date

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - current versions verified from lockfile/registry plus official docs
- Architecture: HIGH - repo seams are explicit and the phase boundary is heavily constrained by context
- Pitfalls: HIGH - each major pitfall is grounded in either current code gaps, official docs, or the kickoff probes

**Research date:** 2026-04-15
**Valid until:** 2026-05-15
