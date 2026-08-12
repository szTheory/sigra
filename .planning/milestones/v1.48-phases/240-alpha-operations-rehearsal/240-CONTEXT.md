# Phase 240: Alpha Operations Rehearsal - Context

**Gathered:** 2026-08-10 (assumptions mode, expanded architecture and ecosystem research)
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver a provider-neutral, no-secrets launch-readiness contract for the canonical personal-account B2C profile. It must give adopters an exact, usable host pre-deploy and staging rehearsal path for origin/session, Google redirect, Cloak, rate limits, and transactional email; it must mechanically preserve the distinction between credential-free library CI and host-owned real Google, email, and iPhone proof. It does not add a hosted control plane, real-provider CI, native/deep-link authority, or general UI work.
</domain>

<decisions>
## Implementation Decisions

### Evidence model and recipe UX
- **D-01:** Make `guides/recipes/b2c-alpha.md` the single, provider-neutral B2C launch checklist. Organize it into three explicitly labeled evidence tiers: **Library CI proof**, **Host pre-deploy**, and **Staging launch gate**. Each item must state its owner, an observable expected result, and must-not-claim boundary.
- **D-02:** Retain Google as the concrete selected adapter only where required by this profile: runtime `GOOGLE_CLIENT_ID`/`GOOGLE_CLIENT_SECRET` wiring and exact `https://<canonical-host>/auth/google/callback` registration. Do not turn the recipe into a provider-specific integration guide or claim provider acceptance from local proof.
- **D-03:** Treat real Google authorization, controlled-recipient delivery of confirmation/reset/magic-link mail, and HTTPS hosted-browser return on a physical iPhone as mandatory adopter staging launch gates. A documented, redacted host receipt is evidence of those checks; repository CI may ensure the gate is required and unclaimed, but cannot mark it passed.

### Canonical origin and session posture
- **D-04:** Default the canonical B2C profile to one public HTTPS origin, `Endpoint.url` and trusted TLS/proxy settings aligned to it, and a host-only Phoenix session cookie with `Secure`, `HttpOnly`, and `SameSite=Lax`. Shared cookie domains or `SameSite=None` require an explicit host architecture rationale and are not defaults.
- **D-05:** The operator checklist records one literal configuration tuple—public origin, `Endpoint.url`, proxy forwarded-scheme/client-IP policy, cookie domain, and SameSite posture—and rehearses clean-browser session behavior. It must not expose internal implementation detail to end users; user-visible recovery remains generic and safe.

### Runtime secrets, Cloak, and transactional email
- **D-06:** Split the operational checks into a wiring/boot gate and a delivery gate. The wiring gate verifies runtime-only, non-committed `SECRET_KEY_BASE`, `CLOAK_KEY`, OAuth, and mailer configuration, Vault/application boot, and `mix sigra.doctor --quiet`; the delivery gate proves controlled-recipient confirmation, reset, and magic-link consumption in a clean browser.
- **D-07:** Describe `mix sigra.doctor --quiet` truthfully as configuration/dependency wiring evidence only. It does not establish external credential acceptance, provider availability, public TLS/proxy correctness, key validity/rotation readiness, transactional delivery, or device behavior. Never place secret values, token-bearing URLs, mail bodies, or provider payloads in CI logs or launch receipts.

### Generated-host rate-limit enforcement
- **D-08:** Close the current gap rather than merely documenting it: generated B2C hosts must select and wire an explicit limiter for sensitive identity/account flows and apply an IP-based limiter to high-risk POST routes. The implementation must be configurable by the host but must not silently default to ineffective production behavior.
- **D-09:** Add deterministic generated-host proof for bounded request exhaustion, independent limiter keys, generic non-enumerating throttling UX, and `429`/`Retry-After` where the route plug owns the response. Do not use waits to cross rate-limit windows; inject test configuration/clock or assert only bounded attempts. The staging checklist separately proves trusted-proxy client-IP handling and observes effective throttling.

### Credential-free CI and truthful claims
- **D-10:** Preserve two independent no-live-secret proofs: the fresh B2C generator smoke and the rendered generated-host runtime suite using the loopback OIDC double. Contract tests must assert workflow/scripts do not inject live Google, transactional-email, deployment, or GitHub-secret credentials, and that inherited Google credentials are unset.
- **D-11:** Name fixed dummy `CLOAK_KEY` and local OIDC client-secret literals as disposable fixtures, never deployment credentials. CI may claim generator shape, local state/PKCE/callback behavior, and rendered B2C auth behavior; it must not claim a real Google Console registration, provider tenant, mail provider, DNS/TLS deployment, reverse proxy, or physical device works.

### the agent's Discretion
- Use the existing recipe/deployment docs and focused ExUnit source-contract tests rather than a redundant standalone CI harness, unless a small validator is demonstrably simpler and does not pretend to execute host-only checks.
- Choose precise rate-limit module/configuration, test helper, failure-copy, and redacted receipt formats consistent with existing Phoenix/Plug/Ecto patterns. Preserve accessibility, deterministic browser readiness, and generic anti-enumeration behavior.
- Keep the generated-auth runtime job outside the legacy skip-tolerant aggregate unless its aggregate/ratification contract is deliberately updated as a separate evidence change.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Scope and established phase boundary
- `.planning/ROADMAP.md` — Phase 240 goal, OPS-01/OPS-02 criteria, and explicit deferrals.
- `.planning/REQUIREMENTS.md` — Operations acceptance requirements.
- `.planning/phases/237-canonical-b2c-generator-contract/237-CONTEXT.md` — exact canonical B2C generated-host profile.
- `.planning/phases/238-generated-auth-runtime-proof/238-CONTEXT.md` — credential-free generated-host/OIDC-double and browser-proof boundary.
- `.planning/phases/239-hosted-session-interop/239-CONTEXT.md` — personal-session authority and evidence-only hosted-return boundary.

### Adopter and deployment contracts
- `guides/recipes/b2c-alpha.md` — canonical alpha recipe to refine and protect.
- `guides/recipes/deployment.md` — detailed deployment, runtime-secret, mail, rate-limit, and Doctor semantics.
- `guides/flows/oauth.md` — generated OAuth state/PKCE/callback contract and host-owned credentials.
- `guides/recipes/subdomain-auth.md` — cookie-domain ownership and constraints.

### Existing executable evidence
- `scripts/ci/passkeys-opt-out-smoke.sh` — fresh canonical B2C generation/compile/assets/migration/boot proof.
- `scripts/ci/generated-auth-runtime-proof.sh` — local OIDC double, credential unsetting, and rendered generated-host proof.
- `.github/workflows/ci.yml` — CI invocation, environment boundary, and evidence job topology.
- `test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` — existing source-contract assertions for the credential-free runtime lane.

### Runtime seams to inspect
- `lib/sigra/doctor.ex` and `lib/mix/tasks/sigra.doctor.ex` — exact diagnostic scope and exit behavior.
- `lib/sigra/plug/rate_limit.ex` — request/IP limiter seam and proxy constraint.
- `lib/sigra/rate_limiters/hammer.ex` and `lib/sigra/rate_limiters/noop.ex` — availability/fail-open behavior to resolve deliberately.
- `lib/sigra/auth.ex` — current optional limiter call-site contract.
- `priv/templates/sigra.install/core/auth.ex` — generated identity-flow wiring to extend.
- `priv/templates/sigra.gen.oauth/vault.ex` and `priv/templates/sigra.gen.oauth/user_identity.ex` — OAuth encrypted-storage/Vault requirement.
</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `guides/recipes/b2c-alpha.md` already contains the canonical command, a concise staging checklist, Crosswake boundary, and automated-boundary wording; Phase 240 should sharpen rather than duplicate it.
- `guides/recipes/deployment.md` already supplies detailed production checklists, runtime-secret guidance, limiter topology, and an honest Doctor scope.
- `scripts/ci/passkeys-opt-out-smoke.sh` proves the fresh canonical B2C generator lifecycle with a disposable Cloak fixture.
- `scripts/ci/generated-auth-runtime-proof.sh` explicitly unsets Google environment variables and uses a loopback OIDC double; it supplies the runtime half of the no-secrets proof.
- Phase 238's planning test already protects part of the workflow credential boundary and can be extended rather than replaced.

### Established Patterns
- Sigra is a hybrid library/generator: security-critical mechanics and deterministic proof are library-owned; runtime credentials, domain, provider tenancy, mail delivery, and deployment remain host-owned.
- OAuth start/callback behavior is locally proven with state/PKCE and a provider double; local proof is intentionally not a claim about external provider configuration.
- `Sigra.Doctor` is a configuration wiring diagnostic, not an external-runtime health check.
- Existing limiters and the rate-limit plug expose explicit optional configuration seams; `conn.remote_ip` makes trusted proxy normalization a real host deployment requirement.

### Integration Points
- Refine the alpha recipe and deployment cross-links, then protect their evidence/claim vocabulary with a focused source-contract test.
- Extend generated-host identity-flow and route configuration so the existing limiter seam is actually enforced, then prove it through deterministic generated-host requests.
- Keep fresh generation and rendered runtime proof as separate CI jobs; together they detect generator drift and runtime/auth-flow drift without credentials.
</code_context>

<specifics>
## Specific Ideas

- Operator-facing documentation is the relevant UX surface. Use short status-oriented labels such as “Library CI proof,” “Host action,” and “Staging launch gate”; put recovery guidance next to redirect mismatch, secure-cookie loop, missing mail, Cloak boot failure, and shared-proxy throttling failure.
- End users should never see provider, queue, secret, or limiter implementation internals. Throttling/recovery copy remains generic, accessible, and enumeration-safe.
- No Rail Accent/admin design-system, Light/Dark/System, or generated-auth visual redesign work belongs here; Phase 238 already owns rendered generated-auth UI/a11y proof.
</specifics>

<deferred>
## Deferred Ideas

- Secret-backed Google/email CI, managed staging infrastructure, provider uptime monitoring, and automated physical-device validation — violate the provider-neutral no-secrets library boundary and remain adopter-host operations.
- Generic OAuth provider discovery/support guarantees, a hosted configuration/control plane, secret-manager/KMS integration, mail deliverability scoring, key-rotation automation, WAF/CAPTCHA/adaptive bot detection, and distributed/global quota services — separate capabilities.
- Shared-subdomain auth, native/deep-link authority, and other device/product-host features — explicitly outside this B2C library milestone.

### Reviewed Todos (not folded)
- All 32 automatic TODO matches were reviewed; none belongs to this narrowly scoped alpha operations rehearsal. Historical CI, admin, auth-UI, release, and installer items remain in their owning/completed phases.
</deferred>

---

*Phase: 240-alpha-operations-rehearsal*
*Context gathered: 2026-08-10*
