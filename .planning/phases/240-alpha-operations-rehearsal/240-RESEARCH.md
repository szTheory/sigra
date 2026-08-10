# Phase 240: Alpha Operations Rehearsal - Research

**Researched:** 2026-08-10  
**Domain:** Provider-neutral B2C launch-readiness contract, generated-host rate limiting, and credential-free CI  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Make `guides/recipes/b2c-alpha.md` the single, provider-neutral B2C launch checklist. Organize it into three explicitly labeled evidence tiers: **Library CI proof**, **Host pre-deploy**, and **Staging launch gate**. Each item must state its owner, an observable expected result, and must-not-claim boundary.
- **D-02:** Retain Google as the concrete selected adapter only where required by this profile: runtime `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` wiring and exact `https://<canonical-host>/auth/google/callback` registration. Do not turn the recipe into a provider-specific integration guide or claim provider acceptance from local proof.
- **D-03:** Treat real Google authorization, controlled-recipient delivery of confirmation/reset/magic-link mail, and HTTPS hosted-browser return on a physical iPhone as mandatory adopter staging launch gates. A documented, redacted host receipt is evidence of those checks; repository CI may ensure the gate is required and unclaimed, but cannot mark it passed.
- **D-04:** Default the canonical B2C profile to one public HTTPS origin, `Endpoint.url` and trusted TLS/proxy settings aligned to it, and a host-only Phoenix session cookie with `Secure`, `HttpOnly`, and `SameSite=Lax`. Shared cookie domains or `SameSite=None` require an explicit host architecture rationale and are not defaults.
- **D-05:** The operator checklist records one literal configuration tuple—public origin, `Endpoint.url`, proxy forwarded-scheme/client-IP policy, cookie domain, and SameSite posture—and rehearses clean-browser session behavior. It must not expose internal implementation detail to end users; user-visible recovery remains generic and safe.
- **D-06:** Split the operational checks into a wiring/boot gate and a delivery gate. The wiring gate verifies runtime-only, non-committed `SECRET_KEY_BASE`, `CLOAK_KEY`, OAuth, and mailer configuration, Vault/application boot, and `mix sigra.doctor --quiet`; the delivery gate proves controlled-recipient confirmation, reset, and magic-link consumption in a clean browser.
- **D-07:** Describe `mix sigra.doctor --quiet` truthfully as configuration/dependency wiring evidence only. It does not establish external credential acceptance, provider availability, public TLS/proxy correctness, key validity/rotation readiness, transactional delivery, or device behavior. Never place secret values, token-bearing URLs, mail bodies, or provider payloads in CI logs or launch receipts.
- **D-08:** Close the current gap rather than merely documenting it: generated B2C hosts must select and wire an explicit limiter for sensitive identity/account flows and apply an IP-based limiter to high-risk POST routes. The implementation must be configurable by the host but must not silently default to ineffective production behavior.
- **D-09:** Add deterministic generated-host proof for bounded request exhaustion, independent limiter keys, generic non-enumerating throttling UX, and `429`/`Retry-After` where the route plug owns the response. Do not use waits to cross rate-limit windows; inject test configuration/clock or assert only bounded attempts. The staging checklist separately proves trusted-proxy client-IP handling and observes effective throttling.
- **D-10:** Preserve two independent no-live-secret proofs: the fresh B2C generator smoke and the rendered generated-host runtime suite using the loopback OIDC double. Contract tests must assert workflow/scripts do not inject live Google, transactional-email, deployment, or GitHub-secret credentials, and that inherited Google credentials are unset.
- **D-11:** Name fixed dummy `CLOAK_KEY` and local OIDC client-secret literals as disposable fixtures, never deployment credentials. CI may claim generator shape, local state/PKCE/callback behavior, and rendered B2C auth behavior; it must not claim a real Google Console registration, provider tenant, mail provider, DNS/TLS deployment, reverse proxy, or physical device works.

### the agent's Discretion
- Use the existing recipe/deployment docs and focused ExUnit source-contract tests rather than a redundant standalone CI harness, unless a small validator is demonstrably simpler and does not pretend to execute host-only checks.
- Choose precise rate-limit module/configuration, test helper, failure-copy, and redacted receipt formats consistent with existing Phoenix/Plug/Ecto patterns. Preserve accessibility, deterministic browser readiness, and generic anti-enumeration behavior.
- Keep the generated-auth runtime job outside the legacy skip-tolerant aggregate unless its aggregate/ratification contract is deliberately updated as a separate evidence change.

### Deferred Ideas (OUT OF SCOPE)
- Secret-backed Google/email CI, managed staging infrastructure, provider uptime monitoring, and automated physical-device validation — violate the provider-neutral no-secrets library boundary and remain adopter-host operations.
- Generic OAuth provider discovery/support guarantees, a hosted configuration/control plane, secret-manager/KMS integration, mail deliverability scoring, key-rotation automation, WAF/CAPTCHA/adaptive bot detection, and distributed/global quota services — separate capabilities.
- Shared-subdomain auth, native/deep-link authority, and other device/product-host features — explicitly outside this B2C library milestone.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| OPS-01 | A provider-neutral alpha recipe specifies host origin, secure session, Google redirect, Cloak, rate-limit, and transactional-email rehearsal requirements. | Three-tier recipe, literal host configuration tuple, honest Doctor scope, and generated limiter design. |
| OPS-02 | A no-secrets CI gate protects the canonical profile and its contract tests; real Google/email/iPhone proof is named as a host launch gate, not claimed by library CI. | Existing independent generator/runtime lanes, targeted source contract test extension, and explicit negative credential assertions. |
</phase_requirements>

## Summary

Phase 240 should refine—not duplicate—the existing `b2c-alpha.md` and `deployment.md` material into one B2C checklist with three evidence tiers: repository proof, host pre-deploy evidence, and non-automatable staging launch evidence. The present recipe already names the correct operator concerns, while the deployment guide holds the detailed runtime configuration and Doctor semantics. [VERIFIED: codebase `guides/recipes/b2c-alpha.md`, `guides/recipes/deployment.md`]

The code change is not documentation-only. `Sigra.Plug.RateLimit` already produces an IP-keyed `429` and rounded `Retry-After`, but it falls back to a fail-open Noop limiter when not explicitly configured; the generated core routes and generated auth context currently do not wire an explicit limiter. Use the existing Hammer adapter, but generate the host dependency, supervised limiter module, explicit Sigra config, and route-scoped plugs so the canonical B2C output cannot silently omit rate limiting. [VERIFIED: codebase `lib/sigra/plug/rate_limit.ex`, `lib/sigra/rate_limiters/{hammer,noop}.ex`, `lib/sigra/install/features/core.ex`]

**Primary recommendation:** Extend the core generated-host feature with a host-owned Hammer limiter and explicit per-flow configuration; protect its rendered output and the three-tier recipe with focused ExUnit source-contract tests while retaining the two existing credential-free CI jobs. [VERIFIED: codebase `lib/sigra/install/features/core.ex`, `scripts/ci/passkeys-opt-out-smoke.sh`, `scripts/ci/generated-auth-runtime-proof.sh`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Launch checklist and redacted receipt | Host operations | Repository documentation | External credentials, DNS/TLS, mail delivery, and a physical iPhone are host-owned; the library owns an accurate contract only. [VERIFIED: codebase `240-CONTEXT.md`] |
| Canonical origin, proxy posture, cookie configuration | Frontend server (SSR) | Host operations | Phoenix endpoint/session configuration generates URLs and cookie behavior, but the reverse proxy supplies trusted forwarded request facts. [CITED: https://phoenix.hexdocs.pm/Phoenix.Endpoint.html] [CITED: https://plug.hexdocs.pm/Plug.Session.html] |
| IP-based limiter for controller POSTs | Frontend server (SSR) | Host operations | The router plug observes `conn.remote_ip`; host proxy normalization determines whether that address is a client IP. [VERIFIED: codebase `lib/sigra/plug/rate_limit.ex`] |
| Mail-request and other LiveView-event throttling | API / backend | Frontend server (SSR) | LiveView events are not independent router POST routes; generated context calls must receive the configured limiter while the router protects real controller POSTs. [VERIFIED: codebase `priv/templates/sigra.install/core/{registration_live,reset_password_live,session_controller,auth}.ex`] |
| Credential-free contract enforcement | CI | Generated-host runtime | Source contracts inspect workflow/script wiring, while the fresh host and loopback OIDC double prove generated output without a live provider. [VERIFIED: codebase `test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs`, `scripts/ci/generated-auth-runtime-proof.sh`] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `hammer` | `~> 7.4` / locked `7.4.0` | Generated host’s explicit limiter implementation and supervised ETS backend. | Hammer documents a `use Hammer, backend: :ets` module and `hit(key, scale, limit)` allow/deny API, matching Sigra’s existing adapter exactly. [CITED: https://hammer.hexdocs.pm/Hammer.html] [VERIFIED: Hex registry `mix hex.info hammer`] |
| `Sigra.Plug.RateLimit` | repository implementation | IP-keyed controller-route enforcement. | It already handles non-safe methods, delegates generic error rendering, emits `Retry-After`, and halts on denial. [VERIFIED: codebase `lib/sigra/plug/rate_limit.ex`] |
| `Sigra.RateLimiters.Hammer` | repository implementation | Adapter from Sigra’s behavior to Hammer 7.x. | It owns the correct `hit(key, window_ms, limit)` argument order and host module lookup. [VERIFIED: codebase `lib/sigra/rate_limiters/hammer.ex`] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phoenix Endpoint | `1.8.10` documented | Canonical URL generation and TLS-termination alignment. | Configure `:url` at runtime for the public host/scheme/port; its scheme supports reverse-proxy TLS termination. [CITED: https://phoenix.hexdocs.pm/Phoenix.Endpoint.html] |
| Plug.Session | `1.20.3` documented | Host-only secure browser session cookie configuration. | Set cookie `secure`, `http_only`, and `same_site` in the endpoint/session options; leave `domain` absent for the default host-only posture. [CITED: https://plug.hexdocs.pm/Plug.Session.html] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Explicit Hammer-generated limiter | Existing nil limiter / Noop fallback | Rejected: the repository implementation intentionally permits a fail-open fallback, contradicting D-08 for generated B2C production output. [VERIFIED: codebase `lib/sigra/plug/rate_limit.ex`, `lib/sigra/rate_limiters/noop.ex`] |
| Route plus context enforcement | Router plug only | Rejected: login/magic-link controller requests are POSTs, but registration/reset request handlers are LiveView events and do not become distinct router POST routes. [VERIFIED: codebase `priv/templates/sigra.install/core/{session_controller,registration_live,reset_password_live}.ex`] |

**Installation:**

```elixir
# Generated host mix.exs — injected by the installer, not a manual recipe step.
{:hammer, "~> 7.4"}
```

**Version verification:** `mix hex.info hammer` reported locked/current `7.4.0`, released 2026-05-19. [VERIFIED: Hex registry `mix hex.info hammer`]

## Package Legitimacy Audit

The legitimacy seam currently accepts npm, PyPI, and crates only, not Hex; therefore this audit uses the official Hammer HexDocs plus `mix hex.info hammer` rather than falsely reporting a seam verdict. [VERIFIED: local command `gsd-tools package-legitimacy check --ecosystem hex hammer`; VERIFIED: Hex registry `mix hex.info hammer`]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| `hammer` | Hex | released 2026-05-19 | 51,990 / 7d | `github.com/ExHammer/hammer` | Official documentation and Hex registry verified | Approved [CITED: https://hammer.hexdocs.pm/Hammer.html] [VERIFIED: Hex registry `mix hex.info hammer`] |

**Packages removed due to [SLOP] verdict:** none.  
**Packages flagged as suspicious [SUS]:** none.

## Architecture Patterns

### System Architecture Diagram

```text
Library source + CI
  ├─ fresh B2C generator smoke ──> generated host shape / compile / boot
  ├─ loopback OIDC runtime suite ─> rendered email + OAuth behavior
  └─ source-contract test ────────> no credential injection + required host gates
                                      │
                                      ▼
Canonical B2C generated host
  public HTTPS request ─> trusted proxy normalization ─> Phoenix `conn.remote_ip`
                                                    ├─> route limiter ─> 429 + Retry-After
                                                    └─> controller / LiveView auth flow
                                                             │
                                                             ▼
Host pre-deploy tuple ─> runtime secrets + Vault boot + `sigra.doctor --quiet`
                                                             │
                                                             ▼
Staging launch gate ─> real Google + controlled mail + clean browser + physical iPhone
                         (redacted host receipt; never CI-passable)
```

### Recommended Project Structure

```text
guides/recipes/b2c-alpha.md                       # single three-tier operator contract
guides/recipes/deployment.md                       # detailed reusable deployment mechanics
lib/sigra/install/features/core.ex                 # generated-host files/injections/config/route contract
priv/templates/sigra.install/core/rate_limit.ex    # generated host Hammer module
test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs
                                                    # source-contract and no-secrets guard
scripts/ci/passkeys-opt-out-smoke.sh               # fresh B2C generator proof
scripts/ci/generated-auth-runtime-proof.sh         # separate rendered host/OIDC-double proof
```

### Pattern 1: Explicit generated limiter ownership

**What:** Generate a host-owned Hammer module, start it under the host application supervisor, inject the Hex dependency, and configure Sigra to use `Sigra.RateLimiters.Hammer` plus distinct route prefixes. [VERIFIED: codebase `lib/sigra/install/features/{core,passkeys}.ex`, `lib/sigra/install/injector.ex`, `lib/sigra/rate_limiters/hammer.ex`]

**When to use:** Use this for the canonical B2C install profile; allow hosts to change bounds/backend/module after generation, but never let generated production paths resolve a nil/Noop limiter. [VERIFIED: codebase `240-CONTEXT.md`, `lib/sigra/plug/rate_limit.ex`]

**Example:**

```elixir
# Source pattern: Hammer 7.4 docs + existing Sigra adapter.
defmodule MyApp.RateLimit do
  use Hammer, backend: :ets
end

# application.ex children (before Endpoint)
{MyApp.RateLimit, clean_period: :timer.minutes(1)}

# config/config.exs
config :sigra, hammer_module: MyApp.RateLimit
config :my_app, :sigra_config,
  rate_limiting: [limiter: Sigra.RateLimiters.Hammer]
```

### Pattern 2: Separate route and context limiter keys

**What:** Assign a distinct, stable `key_prefix` to each route-level sensitive POST flow and pass the configured limiter into generated context functions that handle LiveView email-request events. [VERIFIED: codebase `lib/sigra/plug/rate_limit.ex`, `lib/sigra/auth.ex`, `priv/templates/sigra.install/core/auth.ex`]

**When to use:** The router plug owns an actual HTTP `429` response for controller POSTs; the generated mail functions preserve their existing generic success response on their own `:rate_limited` result to avoid account enumeration. [VERIFIED: codebase `priv/templates/sigra.install/core/{error_handler,session_controller,auth}.ex`]

### Pattern 3: Evidence tiers with honest negative claims

**What:** Give every checklist row an owner, expected observable outcome, and explicit claim boundary; add a redacted receipt template only for host/staging checks. [VERIFIED: codebase `240-CONTEXT.md`]

**When to use:** Always for operations evidence that repository CI cannot execute, especially credentials, provider tenancy, mail delivery, public TLS/proxy behavior, and physical device proof. [VERIFIED: codebase `240-CONTEXT.md`, `scripts/ci/generated-auth-runtime-proof.sh`]

### Anti-Patterns to Avoid

- **Calling `mix sigra.doctor --quiet` an external health check:** it reports configured optional-dependency wiring; it does not contact Google, a mail provider, DNS, TLS proxy, or a device. [VERIFIED: codebase `lib/sigra/doctor.ex`, `lib/mix/tasks/sigra.doctor.ex`]
- **Adding secrets to CI to prove a provider:** this violates the locked no-secrets boundary and changes the library contract into an adopter infrastructure test. [VERIFIED: codebase `240-CONTEXT.md`]
- **Using a sleep to cross a limiter window:** assert a bounded number of requests with an injected low test configuration instead. [VERIFIED: codebase `240-CONTEXT.md`]
- **Advertising router limiting as complete LiveView-event protection:** LiveView mail requests need context-level limiter wiring as well. [VERIFIED: codebase `priv/templates/sigra.install/core/{registration_live,reset_password_live,session_controller}.ex`]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Counter storage/window accounting | Custom ETS counter and cleanup process | Hammer ETS backend through existing `Sigra.RateLimiters.Hammer` | Hammer supplies the `hit` decision and cleanup lifecycle; the Sigra wrapper already normalizes its result. [CITED: https://hammer.hexdocs.pm/Hammer.html] [VERIFIED: codebase `lib/sigra/rate_limiters/hammer.ex`] |
| 429 header rounding and auth response | Per-controller throttling response code | `Sigra.Plug.RateLimit` plus generated `AuthErrorHandler` | Existing code rounds retry seconds, adds `Retry-After`, delegates generic response rendering, and halts. [VERIFIED: codebase `lib/sigra/plug/rate_limit.ex`, `priv/templates/sigra.install/core/error_handler.ex`] |
| Provider/mail/device verification in CI | Secret-injected integration harness | Required host staging receipt | CI cannot establish external tenant configuration or physical-device behavior without violating D-03/D-10. [VERIFIED: codebase `240-CONTEXT.md`] |

**Key insight:** The reusable primitive already exists; Phase 240’s risk is failing to generate and configure it at the boundary where the host actually needs it. [VERIFIED: codebase `lib/sigra/plug/rate_limit.ex`, `lib/sigra/install/features/core.ex`]

## Common Pitfalls

### Pitfall 1: Fail-open limiter accidentally becomes generated production default

**What goes wrong:** `Sigra.Plug.RateLimit` resolves a nil limiter to Hammer only when available and otherwise uses Noop, so a generated host can compile and appear functional with no effective limiter. [VERIFIED: codebase `lib/sigra/plug/rate_limit.ex`, `lib/sigra/rate_limiters/noop.ex`]

**How to avoid:** Generate Hammer dependency/module/supervision/config and pass the concrete adapter to both route plugs and context calls; test rendered output for all four ownership points. [VERIFIED: codebase `lib/sigra/install/features/passkeys.ex`, `lib/sigra/install/injector.ex`]

**Warning signs:** A generated host has no `{:hammer, ...}` dependency, no application child, no `:hammer_module`, or a route plug with `limiter: nil`. [VERIFIED: codebase `lib/sigra/rate_limiters/hammer.ex`, `lib/sigra/plug/rate_limit.ex`]

### Pitfall 2: One router pipeline is claimed to protect LiveView actions

**What goes wrong:** Registration and reset request forms use `phx-submit`; their application work occurs in `handle_event/3`, while login/magic-link uses a controller POST. [VERIFIED: codebase `priv/templates/sigra.install/core/{registration_live,reset_password_live,session_controller}.ex`]

**How to avoid:** Deliberately test the controller route plug and separately inject the configured limiter into generated context operations that service email requests. [VERIFIED: codebase `lib/sigra/auth.ex`, `priv/templates/sigra.install/core/auth.ex`]

**Warning signs:** A test proves only `POST /users/log_in`, or no generated `request_magic_link`/`request_password_reset` call receives limiter options. [VERIFIED: codebase `priv/templates/sigra.install/core/auth.ex`]

### Pitfall 3: CI logs or receipt prove too much

**What goes wrong:** A dummy `CLOAK_KEY` or OIDC double secret is mistaken for deployment evidence, or a receipt contains a token-bearing link/mail body/provider payload. [VERIFIED: codebase `scripts/ci/generated-auth-runtime-proof.sh`, `240-CONTEXT.md`]

**How to avoid:** Label fixtures disposable; assert inherited Google variables are unset; make receipt fields outcome-only (timestamp, environment label, config fingerprint, pass/fail), never values or URLs. [VERIFIED: codebase `scripts/ci/generated-auth-runtime-proof.sh`, `240-CONTEXT.md`]

**Warning signs:** Workflow YAML references `secrets.`, Google client values, mail-provider credentials, deployment tokens, or a receipt requests raw output. [VERIFIED: codebase `.github/workflows/generated-auth-runtime-proof.yml`, `test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs`]

## Code Examples

Verified patterns from repository and official sources:

### Route-owned generic throttle response

```elixir
# Existing generated handler pattern; route plug supplies status + Retry-After.
def auth_error(conn, :rate_limited, _opts) do
  conn
  |> Plug.Conn.put_resp_content_type("text/plain")
  |> Plug.Conn.send_resp(429, "Too many requests. Please try again later.")
end
```

Source: [VERIFIED: codebase `priv/templates/sigra.install/core/error_handler.ex`, `lib/sigra/plug/rate_limit.ex`]

### Host pre-deploy tuple to record (values redacted)

```text
public origin: https://app.example.test
Endpoint.url:  https://app.example.test:443
proxy policy:  forwarded scheme and client IP accepted only from trusted proxy
cookie domain: host-only (no Domain attribute)
SameSite:      Lax; Secure; HttpOnly
```

Source: [CITED: https://phoenix.hexdocs.pm/Phoenix.Endpoint.html] [CITED: https://plug.hexdocs.pm/Plug.Session.html] [VERIFIED: codebase `240-CONTEXT.md`]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Optional manual Hammer setup in generated install instructions | Explicit generated limiter ownership for canonical B2C output | Phase 240 planned change | Installation becomes mechanically protected rather than relying on adopter recall. [VERIFIED: codebase `lib/sigra/install/features/core.ex`, `240-CONTEXT.md`] |
| Source-only proof of generated OAuth shape | Separate fresh-host generator smoke plus loopback OIDC rendered-runtime proof | Phases 237–238 | Preserve both lanes; they prove different drift risks and neither uses live provider credentials. [VERIFIED: codebase `scripts/ci/{passkeys-opt-out-smoke,generated-auth-runtime-proof}.sh`] |

**Deprecated/outdated:** The optional “Set up rate limiting with Hammer” post-install instruction is insufficient for D-08 because it leaves the generated production path unprotected if ignored. [VERIFIED: codebase `lib/sigra/install/features/core.ex`, `240-CONTEXT.md`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | No exact production rate-limit bounds are locked; choose conservative explicit generated defaults and document host override. | Architecture Patterns | Bounds may not fit a particular host’s traffic or abuse model. |

## Open Questions (RESOLVED)

1. **Which generated flows receive route-only vs. context-level limits? — RESOLVED**
   - Selected mapping: Plan 01's tracer protects the canonical `POST /users/log_in` controller boundary with an IP-derived route key and proves its generic `429`/`Retry-After` response. Plan 02 expands route limiting to each mutating controller route emitted by Core—login and sudo in the default LiveView output, plus the registration, confirmation/resend, password-reset, and MFA controller variants when `--no-live` emits them—using stable action-specific prefixes so one route cannot consume another route's allowance. Safe GET/HEAD token-consumption and form-render routes remain outside the plug. [VERIFIED: codebase `lib/sigra/install/features/core.ex`, `lib/sigra/plug/rate_limit.ex`]
   - Selected context mapping: repeatable anonymous mail requests that do not have their own controller boundary remain context-owned. Generated `request_magic_link/2` and `deliver_user_reset_password_instructions/2` pass `Sigra.RateLimiters.Hammer` plus explicit integer max/window options to the existing normalized-email keys `magic_link:<email>` and `sigra:reset:<email>`. The magic-link submit therefore receives both the route-IP defense and an independent email-context defense; the reset-request LiveView receives the email-context defense. Existing confirmation-code and MFA attempt controls remain their owning mechanisms rather than being relabeled as route-plug proof. [VERIFIED: codebase `lib/sigra/auth.ex`, `priv/templates/sigra.install/core/{auth,session_controller,reset_password_live,confirmation_live,mfa_challenge_live}.ex`]
   - Default bounds remain host-overridable and are selected in Plans 01-02 under the agent's discretion; the contracts pin the chosen integers at N-1/N/N+1 and prove cross-prefix/key independence. This resolution is the exact flow map implemented by Plans 01-02.

2. **How should the generated-host proof configure low deterministic limits? — RESOLVED**
   - Selected design: Wave 0 Plan 05 creates focused library-side source/render contracts plus a short generated-host ExUnit request probe that `scripts/ci/passkeys-opt-out-smoke.sh` copies or renders into the disposable `sigra_b2c_alpha` host. The probe overrides the generated integer limit/window in test configuration before the endpoint starts, sends a bounded synchronous sequence to the protected POST route, and asserts allow through N followed immediately by N+1 `429` and integer `Retry-After`. [VERIFIED: codebase `test/sigra/plug/rate_limit_test.exs`, `scripts/ci/passkeys-opt-out-smoke.sh`]
   - The proof never advances a clock, waits for expiry, calls `sleep`, or uses Playwright. It proves a single window by exhausting it; independent prefixes/keys are exercised in the focused ExUnit context contract. The rendered-runtime Playwright lane remains unchanged because Phase 240 adds enforcement and evidence contracts, not browser interaction behavior. This is the no-sleep proof consumed by Plans 01-02 and protected by Plan 04's source contract.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir/Mix | Source contracts and library tests | ✓ | OTP 28 / Mix available | — |
| Node/npm | Existing rendered generated-host suite | ✓ | Node 22.14.0 / npm 11.1.0 | — |
| PostgreSQL | Full suite and disposable generated-host runtime lanes | ✗ | local port refused | CI service or project DB helper |
| Hex package registry | Hammer version audit | ✓ | Hammer 7.4.0 reported | — |

**Missing dependencies with no fallback:** none for planning; a running PostgreSQL service is required to execute the full generated-host lane locally. [VERIFIED: local `pg_isready`, `mix hex.info hammer`]

**Missing dependencies with fallback:** PostgreSQL has the repository CI service/fresh-host workflow as the deterministic fallback. [VERIFIED: codebase `.github/workflows/ci.yml`, `.github/workflows/generated-auth-runtime-proof.yml`]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with Mox; generated-host browser proof uses Playwright. [VERIFIED: codebase `test/test_helper.exs`, `test/example/priv/playwright/playwright.config.ts`] |
| Config file | `test/test_helper.exs` [VERIFIED: codebase `test/test_helper.exs`] |
| Quick run command | `mix test test/sigra/plug/rate_limit_test.exs test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs` |
| Full suite command | `mix test` (requires the documented local PostgreSQL prerequisite). [VERIFIED: codebase `test/test_helper.exs`] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| OPS-01 | Recipe has all three tiers, tuple, wiring/delivery gates, no claim inflation; generated core renders explicit limiter ownership. | source contract + generated-host request | `mix test test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs` | ❌ Wave 0 |
| OPS-01 | Bounded request exhaustion, independent keys, generic `429`, and `Retry-After` on route plug. | generated-host integration + plug unit | `mix test test/sigra/plug/rate_limit_test.exs` plus fresh-host proof target | Existing plug unit ✅; generated-host proof ❌ Wave 0 |
| OPS-02 | Fresh generator and rendered runtime lanes remain separate, unset inherited Google variables, and inject no live credentials/secrets. | source contract | `mix test test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` | Phase 238 partial ✅; Phase 240 extension ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** targeted ExUnit command above; run the bounded fresh-host proof when generated templates/scripts change. [VERIFIED: codebase `test/test_helper.exs`, `scripts/ci/passkeys-opt-out-smoke.sh`]
- **Per wave merge:** `mix test` with PostgreSQL available. [VERIFIED: codebase `test/test_helper.exs`]
- **Phase gate:** Full suite green plus both independent no-secrets lanes before `$gsd-verify-work`. [VERIFIED: codebase `240-CONTEXT.md`]

### Wave 0 Gaps

Wave 0 Plan `240-05` owns all four artifacts before implementation begins:

- [ ] `test/sigra/install/generated_rate_limit_contract_test.exs` — generated ownership, threshold, Retry-After precision, idempotency, and the bounded disposable-host tracer contract.
- [ ] `test/sigra/install/generated_rate_limit_context_test.exs` — resolved route/context flow map, distinct prefixes/keys, and generic context outcomes.
- [ ] `test/sigra/planning/phase_240_alpha_operations_rehearsal_test.exs` — recipe tiers, literal tuple, host-only gates, redaction, and Doctor claim boundary.
- [ ] `test/sigra/planning/phase_240_no_secrets_ci_test.exs` — separate lane topology, disposable Cloak/OIDC fixture classification, inherited-Google unsetting, negative credential/claim assertions, and the local-only `COVERAGE.md` declaration.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Generated auth flows retain generic failures and host-owned real-provider rehearsal. [VERIFIED: codebase `priv/templates/sigra.install/core/session_controller.ex`, `240-CONTEXT.md`] |
| V3 Session Management | yes | One canonical HTTPS origin, host-only secure/HttpOnly/Lax session posture, and clean-browser rehearsal. [VERIFIED: codebase `240-CONTEXT.md`] |
| V4 Access Control | no | No new authorization surface; phase does not add hosted control-plane authority. [VERIFIED: codebase `240-CONTEXT.md`] |
| V5 Input Validation | yes | Route plug keys only normalized `conn.remote_ip`; host must configure trusted proxy client-IP normalization. [VERIFIED: codebase `lib/sigra/plug/rate_limit.ex`] |
| V6 Cryptography | yes | Runtime-only `SECRET_KEY_BASE`/`CLOAK_KEY`, Vault boot check, and no secret/token logging. [VERIFIED: codebase `240-CONTEXT.md`, `priv/templates/sigra.gen.oauth/vault.ex`] |

### Known Threat Patterns for Phoenix/Sigra B2C

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Credential stuffing or mail-request flooding | Denial of service | Explicit IP route limiters plus context limiters, distinct keys, bounded automated denial proof, and staging proxy check. [VERIFIED: codebase `lib/sigra/plug/rate_limit.ex`, `240-CONTEXT.md`] |
| Account enumeration through throttle copy | Information disclosure | Keep controller/mail responses generic; use `429` only where route plug owns the response. [VERIFIED: codebase `priv/templates/sigra.install/core/{session_controller,error_handler}.ex`, `240-CONTEXT.md`] |
| Spoofed client IP behind a proxy | Spoofing | Trust and normalize forwarded client-IP headers only in host proxy configuration; rehearse this in staging. [VERIFIED: codebase `lib/sigra/plug/rate_limit.ex`, `240-CONTEXT.md`] |
| Credentials/tokens leaked into build evidence | Information disclosure | No live-secret CI; redact values, URLs, mail bodies, and provider payloads from receipts/logs. [VERIFIED: codebase `240-CONTEXT.md`, `scripts/ci/generated-auth-runtime-proof.sh`] |

## Sources

### Primary (HIGH confidence)

- Repository sources: `guides/recipes/{b2c-alpha,deployment}.md`, `lib/sigra/{doctor,plug/rate_limit,rate_limiters/hammer,rate_limiters/noop,auth}.ex`, installer templates/features, CI scripts/workflows, and Phase 237–239 contexts — current implementation and locked scope.
- [Hammer 7.4.0 HexDocs](https://hammer.hexdocs.pm/Hammer.html) — ETS backend and `hit/3` contract.
- [Phoenix Endpoint 1.8.10 HexDocs](https://phoenix.hexdocs.pm/Phoenix.Endpoint.html) — runtime `:url`, proxy TLS scheme, and origin behavior.
- [Plug Session 1.20.3 HexDocs](https://plug.hexdocs.pm/Plug.Session.html) — cookie option contract.

### Secondary (MEDIUM confidence)

- Research-plan Context7-routed official documentation digest, cached 2026-08-10 for Phoenix Endpoint, Plug.Session, and Hammer.

### Tertiary (LOW confidence)

- None beyond the two explicitly logged implementation choices in the Assumptions Log.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — existing repository seam plus current official Hammer/Hex verification.
- Architecture: HIGH — derived from locked phase decisions and exact generated route/event sources.
- Pitfalls: HIGH — directly demonstrated by Noop fallback, controller/LiveView split, and existing no-secrets harness.

**Project Constraints (from AGENTS.md)**

- Preserve the `sg-*` cascade-layer/BEM design system and Rail Accent assets only if admin UI work is introduced; this phase explicitly excludes admin/UI redesign. [VERIFIED: project `AGENTS.md`, `240-CONTEXT.md`]
- Preserve Light, Dark, and System modes if UI changes become necessary; none are planned here. [VERIFIED: project `AGENTS.md`, `240-CONTEXT.md`]
- Any Playwright work must use deterministic role selectors/stable hooks/LiveView readiness and no sleeps. [VERIFIED: project `AGENTS.md`, `240-CONTEXT.md`]
- Use deterministic automated evidence rather than manual UAT; retry one transient failure and retain durable diagnostics rather than waiving unproven requirements. [VERIFIED: project `AGENTS.md`]
- No GitHub CI polling is required for research; if implementation dispatches CI, use one watcher with a 60-second interval and respect API rate limits. [VERIFIED: project `AGENTS.md`]

**Research date:** 2026-08-10  
**Valid until:** 2026-09-09 (repository patterns stable; recheck Hammer/Phoenix docs before dependency changes).
