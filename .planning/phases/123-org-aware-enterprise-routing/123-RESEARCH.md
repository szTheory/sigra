# Phase 123: Org-Aware Enterprise Routing - Research

**Researched:** 2026-05-25 [VERIFIED: session context]
**Domain:** Organization-scoped enterprise OIDC login entry, bounded email-domain discovery, and callback/session/audit org truth in Sigra [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `.planning/REQUIREMENTS.md`, `lib/sigra/oauth.ex`, `lib/sigra/auth.ex`]
**Confidence:** HIGH [VERIFIED: codebase review + official Phoenix/Plug/Assent docs + current Hex package metadata]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Ship both a canonical explicit org-scoped enterprise entry route and a bounded generic enterprise discovery entry. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **D-02:** The org-scoped route is the source of truth. The generic entry is convenience only and must redirect into the canonical org route before the OIDC ceremony starts. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **D-03:** Do not expose a parallel domain-only internal API. Library/runtime APIs should target explicit organization or connection identity even when UX begins from email discovery. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **D-04:** Generic enterprise discovery may auto-route only when `normalize_email(email)` yields an exact match to one active enterprise connection with a verified, uniquely owned domain. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `lib/sigra/auth.ex`]
- **D-05:** Pending, disabled, validation-failed, duplicate, wildcard, suffix, shared, or heuristic domain matches never qualify for auto-routing. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **D-06:** Discovery is a UX convenience, not a trust boundary. The resolved `organization_id`, `connection_id`, and `routing_source: :domain_discovery` must be bound into signed OAuth state and/or server session, then revalidated on callback. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **D-07:** Fail closed whenever discovery does not resolve exactly one usable active enterprise connection. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **D-08:** Recovery stays in the same mode: return the user to an explicit enterprise org-entry retry flow with bounded guidance. Do not silently downgrade into password, magic-link, or passkey login. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **D-09:** If another auth mode remains allowed by later policy, expose it only as a separate explicit choice outside the enterprise-routing flow. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **D-10:** Use bounded failure reasons internally and in audits, such as `no_org_match`, `multiple_org_matches`, and `org_connection_unavailable`. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **D-11:** Once Sigra resolves an organization, generated-host UI should show lightweight explicit org truth before redirect and on return/error states. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **D-12:** Keep this lightweight: name the organization and make the scope legible, but do not build a heavier branded enterprise handoff in Phase 123. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **D-13:** Library code remains authoritative for org resolution, callback binding, session attribution, and audit attribution. Generated-host code owns the UX copy and presentation. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **D-14:** For similar future GSD routing decisions, default to: canonical scoped route first, bounded unique verified auto-resolution second. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **D-15:** Default to fail-closed plus explicit same-mode recovery rather than silent downgrade. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **D-16:** Default to lightweight explicit tenant/org truth at auth boundaries whenever tenant resolution affects session, callback, or audit correctness. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]

### Claude's Discretion
- Exact route names and whether the enterprise entry is controller-rendered or LiveView, as long as the canonical org-scoped route stays explicit and obvious. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- Exact UI copy, layout, and button hierarchy for discovery, retry, and return states. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- Exact storage split between signed OAuth state and server session for carrying resolved org/connection identity, as long as callback verification remains strict. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]

### Deferred Ideas (OUT OF SCOPE)
- Per-organization branded enterprise login handoff or theming. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- Broader privacy-policy customization for discovery enumeration tradeoffs beyond bounded defaults. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- SSO-only enforcement and break-glass UX. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- JIT membership reconciliation and identity-link decisions after successful enterprise callback. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- SCIM, hosted admin/control-plane workflows, and broader enterprise directory lifecycle automation. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SSO-03 | Users can enter enterprise login through an org-aware entry path that resolves the correct organization connection by explicit org route or verified email-domain discovery. [VERIFIED: `.planning/REQUIREMENTS.md`] | Reuse the existing org-scoped router posture, `Sigra.Auth.normalize_email/1`, the Phase 122 `enterprise_connections` substrate, and Sigra-owned OAuth state/session plumbing so discovery resolves to one active connection before redirect and callback/session/audit truth stay org-bound. [VERIFIED: `test/example/lib/example_web/router.ex`, `lib/sigra/auth.ex`, `lib/sigra/enterprise_connections.ex`, `test/example/lib/example/accounts/enterprise_connection.ex`, `lib/sigra/oauth.ex`, `lib/sigra/auth.ex`] |
</phase_requirements>

## Summary

Phase 123 should extend Sigra's existing OAuth flow, not create a second enterprise-login stack. The repo already has the right substrate: URL-owned organization routing, DB-backed active-organization session truth, organization-bound enterprise connections with `login_hint_domains`, and HMAC-signed OAuth state around Assent-driven OIDC flows. [VERIFIED: `test/example/lib/example_web/router.ex`, `lib/sigra/session_stores/ecto.ex`, `lib/sigra/session.ex`, `test/example/lib/example/accounts/enterprise_connection.ex`, `lib/sigra/oauth.ex`]

The planning hinge is where org truth is decided. The correct boundary is: generic discovery can normalize email and select exactly one active verified connection, but it must immediately redirect into the canonical org-scoped enterprise path before calling `Sigra.OAuth.authorize_url/3`. That preserves D-02, keeps library APIs explicit, and avoids callback-time "which org did this login mean?" ambiguity. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `lib/sigra/auth.ex`, `lib/sigra/oauth.ex`, `test/example/lib/example_web/router.ex`]

The safest implementation is to bind resolved routing context twice: put the minimal org/connection/routing metadata in the server session for the browser round-trip, and include the same data inside Sigra's signed OAuth state payload so callback verification can reject tampering or stale session drift. Plug's session docs distinguish request `assigns` from cross-request `session`, and Assent's OIDC docs require session-bound `session_params` for state/PKCE/nonce, which matches Sigra's current ceremony design. [CITED: https://hexdocs.pm/plug/Plug.Conn.html] [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] [VERIFIED: `lib/sigra/oauth.ex`]

**Primary recommendation:** implement Phase 123 as one library routing/state layer plus one generated-host entry/callback surface. The library layer should add explicit enterprise-routing APIs and callback verification; the host layer should add the canonical org entry route, bounded generic discovery form, and lightweight org-truth/error UI. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `.planning/research/ARCHITECTURE.md`, `test/example/lib/example_web/controllers/session_html.ex`, `lib/sigra/oauth.ex`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Canonical enterprise entry route (`/organizations/:org/...`) | Frontend server (Phoenix router/controller or LiveView mount) | API / backend library | Route ownership belongs in generated-host Phoenix code, but the route must call library-owned connection lookup and OAuth ceremony code. [VERIFIED: `test/example/lib/example_web/router.ex`, `test/example/lib/example_web/controllers/session_html.ex`, `lib/sigra/oauth.ex`] |
| Generic email-domain discovery form | Frontend server | API / backend library | The form UX is generated-host code; the exact-match lookup and fail-closed decision belong in library/runtime code because they affect auth correctness. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `lib/sigra/auth.ex`, `lib/sigra/enterprise_connections.ex`] |
| Enterprise connection eligibility lookup | API / backend library | Database / storage | Only the library should decide whether a connection is active and domain-routable from persisted connection truth. [VERIFIED: `lib/sigra/enterprise_connections.ex`, `test/example/lib/example/accounts/enterprise_connection.ex`] |
| OAuth authorize URL generation, signed state, PKCE, callback exchange | API / backend library | Frontend server | `Sigra.OAuth` already owns the ceremony and state signing, and Assent's OIDC contract expects session-bound callback parameters. [VERIFIED: `lib/sigra/oauth.ex`] [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |
| Session active organization attribution | API / backend library | Database / storage | `Sigra.Auth.create_session/4` and `Sigra.SessionStores.Ecto` already own DB-backed session truth, including `active_organization_id`. [VERIFIED: `lib/sigra/auth.ex`, `lib/sigra/session_stores/ecto.ex`, `lib/sigra/session.ex`] |
| Org-truth pre-redirect and error copy | Frontend server | — | D-11/D-13 place presentation in generated-host code, not Sigra core. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`] |
| Callback org/connection revalidation and audit attribution | API / backend library | Database / storage | Wrong-org routing is a security problem, so callback truth and audit metadata must stay library-owned and persistence-backed. [VERIFIED: `.planning/research/PITFALLS.md`, `lib/sigra/oauth.ex`, `lib/sigra/auth.ex`] |

## Project Constraints (from CLAUDE.md)

- Phoenix `1.8+` and Ecto `3.x` are the blessed path; recommendations should preserve that baseline. [VERIFIED: `CLAUDE.md`]
- PostgreSQL is the primary database, with `citext` and `JSONB` as the preferred posture; MySQL/SQLite support is conditional. [VERIFIED: `CLAUDE.md`]
- OWASP-oriented security defaults, enumeration prevention, Argon2id, and HMAC-protected tokens are required. Phase 123 must not weaken them. [VERIFIED: `CLAUDE.md`]
- Security-critical code belongs in the library; generated-host code should own customizable routes, schemas, templates, and presentation. [VERIFIED: `CLAUDE.md`]
- Login/logout must stay HTTP POST oriented rather than moving auth-critical mutations into LiveView-only events. [VERIFIED: `CLAUDE.md`]
- Tests should cover happy path, error cases, and boundaries with flat, self-contained AAA-style structure. [VERIFIED: `CLAUDE.md`]
- Local and CI tests expect a live Postgres at `localhost:5432` with `postgres/postgres`. [VERIFIED: `CLAUDE.md`, `test/test_helper.exs`, `pg_isready -h localhost -p 5432 -U postgres`] 

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix Router / VerifiedRoutes | locked `1.8.5`, latest `1.8.7` published 2026-05-06 [VERIFIED: `mix hex.info phoenix`, https://hex.pm/packages/phoenix] | Declare the canonical org-scoped route and keep generated-host paths compile-time verified. | Phoenix scopes and `pipe_through` are the repo's established routing model and official Phoenix guidance for scoped routes. [VERIFIED: `test/example/lib/example_web/router.ex`] [CITED: https://hexdocs.pm/phoenix/Phoenix.Router.html] |
| Plug session + Sigra session store | Plug locked `1.19.1`, latest `1.19.2` published 2026-05-14 [VERIFIED: `mix hex.info plug`, https://hex.pm/packages/plug] | Persist bounded enterprise-routing context across redirects and write final `active_organization_id` into the DB-backed session row. | Plug sessions are the correct cross-request store; Sigra already uses DB-backed session rows for auth truth. [CITED: https://hexdocs.pm/plug/Plug.Conn.html] [VERIFIED: `lib/sigra/session_stores/ecto.ex`, `lib/sigra/session.ex`] |
| Assent OIDC via `Sigra.OAuth` | locked `0.3.1`, latest `0.3.1` published 2025-06-20 [VERIFIED: `mix hex.info assent`, https://hex.pm/packages/assent] | Run OIDC authorize/callback with session-bound state, PKCE, and nonce handling. | Sigra already wraps Assent for OAuth/OIDC; enterprise routing should feed the existing ceremony instead of bypassing it. [VERIFIED: `lib/sigra/oauth.ex`] [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |
| Ecto / Ecto SQL | locked `3.13.5`, latest `3.14.0` and `3.14.0` published 2026-05-19 [VERIFIED: `mix hex.info ecto`, `mix hex.info ecto_sql`, https://hex.pm/packages/ecto] | Query the enterprise connection table, persist routing/audit metadata, and keep session/org truth DB-backed. | The enterprise connection contract from Phase 122 is already modeled in Ecto and should stay the routing source of truth. [VERIFIED: `lib/sigra/enterprise_connections.ex`, `test/example/lib/example/accounts/enterprise_connection.ex`] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Sigra.EnterpriseConnections` | repo-local [VERIFIED: codebase grep] | Fetch the active org-bound enterprise connection and reuse Phase 122 lifecycle truth. | Use for every enterprise routing decision; never infer routability from raw params alone. [VERIFIED: `lib/sigra/enterprise_connections.ex`] |
| `Sigra.Auth.normalize_email/1` | repo-local [VERIFIED: codebase grep] | Normalize work-email input before extracting and matching the domain. | Use on generic discovery input before any domain lookup or ambiguity check. [VERIFIED: `lib/sigra/auth.ex`] |
| `Sigra.Scope.Hydration` + `Sigra.Plug.LoadActiveOrganization` | repo-local [VERIFIED: codebase grep] | Rehydrate org scope from `session.active_organization_id` and recover fail-closed from stale pointers. | Use after enterprise callback so the first authenticated request sees the correct org context. [VERIFIED: `lib/sigra/scope/hydration.ex`, `lib/sigra/plug/load_active_organization.ex`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Canonical org-scoped enterprise route | Generic discovery-only route | Reject. Discovery-only keeps org truth implicit and conflicts with D-02/D-03. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`] |
| Existing `Sigra.OAuth` ceremony | New enterprise-only OIDC controller stack | Reject. That would duplicate signed state, callback handling, and audit behavior already present in Sigra core. [VERIFIED: `lib/sigra/oauth.ex`, `guides/flows/oauth.md`] |
| Signed state plus minimal session metadata | Session-only routing context | Weaker. Sigra already signs OAuth state; callback revalidation is stronger if the same org/connection context is also embedded in the signed token. [VERIFIED: `lib/sigra/oauth.ex`] |

**Installation:** No new Hex dependencies are required for Phase 123 if implementation stays on the existing Phoenix/Plug/Assent/Ecto stack. [VERIFIED: `mix.exs`, `lib/sigra/oauth.ex`, `lib/sigra/enterprise_connections.ex`]

**Version verification:** Verified with `mix hex.info phoenix`, `mix hex.info phoenix_live_view`, `mix hex.info ecto`, `mix hex.info ecto_sql`, `mix hex.info assent`, and `mix hex.info plug` on 2026-05-25. [VERIFIED: local command output]

## Architecture Patterns

### System Architecture Diagram

```text
Browser
  | GET /users/log_in or explicit enterprise entry
  v
Generated-host login surface
  | explicit org path ------------------------------.
  | generic enterprise discovery form               |
  v                                                 |
Library routing service                             |
  | normalize email                                 |
  | exact verified unique domain lookup             |
  | fail closed on 0 / >1 / non-active matches      |
  '-------> redirect to /organizations/:org/... ----'
                    |
                    v
Generated-host org-scoped enterprise entry
  | fetch active enterprise connection
  | show lightweight org truth
  | call Sigra.OAuth.authorize_url with enterprise provider config
  v
Sigra.OAuth + Assent OIDC
  | signed state + PKCE + nonce
  | redirect to IdP
  v
Identity Provider
  | callback with code + state
  v
Enterprise callback handler
  | verify signed state
  | re-fetch org/connection by bound ids
  | reject mismatches/unavailable connections
  | run OIDC callback and user routing
  v
Sigra.Auth.create_session
  | write session row
  | set active_organization_id
  | emit session/audit truth
  v
Post-login request / hydrated scope
```

### Recommended Project Structure

```text
lib/
├── sigra/
│   ├── enterprise_routing.ex        # library-owned org/connection lookup + state contract
│   ├── oauth.ex                     # extend signed state payload / authorize path
│   └── oauth/callback.ex            # extend callback revalidation / session metadata
test/example/lib/example_web/
├── controllers/enterprise_sso_controller.ex  # explicit org entry + callback surface
├── controllers/session_html.ex               # generic discovery affordance
└── router.ex                                 # canonical org-scoped route + generic entry
```

The exact controller-vs-LiveView split is discretionary, but controller-first is the lower-risk fit because the current login page is already controller-rendered and Sigra's auth mutations are HTTP oriented. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `test/example/lib/example_web/controllers/session_html.ex`, `test/example/lib/example_web/controllers/session_controller.ex`]

### Pattern 1: Canonical Org-Scoped Entry

**What:** Add an explicit org-owned enterprise entry route under the existing `/organizations/:org` posture. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `test/example/lib/example_web/router.ex`]

**When to use:** For every enterprise login initiation, whether the user typed an org slug directly or arrived from bounded discovery. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]

**Example:**

```elixir
# Source: https://hexdocs.pm/phoenix/1.8.5/router.html
scope "/organizations/:org", ExampleWeb do
  pipe_through [:browser]

  get "/sso", EnterpriseSSOController, :new
  post "/sso", EnterpriseSSOController, :create
  get "/sso/callback", EnterpriseSSOController, :callback
end
```

### Pattern 2: Discovery Redirects Before OIDC Starts

**What:** Generic enterprise discovery should stop at "resolve exactly one active verified connection, then redirect to the canonical org route." It must not call OIDC directly. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]

**When to use:** On `/users/log_in` or an adjacent enterprise-only surface where a user enters a work email first. [VERIFIED: `test/example/lib/example_web/controllers/session_html.ex`, `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]

**Example:**

```elixir
# Source: repo pattern + locked decisions
case Sigra.EnterpriseRouting.discover_connection(config, email) do
  {:ok, %{organization_slug: slug}} ->
    redirect(conn, to: ~p"/organizations/#{slug}/sso")

  {:error, _reason} ->
    render(conn, :enterprise_discovery_error)
end
```

### Pattern 3: Bind Routing Context Into Signed State and Session

**What:** Extend the current `Sigra.OAuth` state payload so enterprise callbacks revalidate `{organization_id, connection_id, routing_source}` before proceeding. [VERIFIED: `lib/sigra/oauth.ex`, `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]

**When to use:** On enterprise authorize and callback only; generic social OAuth flows do not need org-bound routing metadata. [VERIFIED: `guides/flows/oauth.md`, `lib/sigra/oauth.ex`]

**Example:**

```elixir
# Source: repo pattern + official OIDC session/state contract
{:ok, url, session_params} =
  Sigra.OAuth.authorize_url(config, :oidc, enterprise:
    %{organization_id: org.id, connection_id: connection.id, routing_source: :explicit_org}
  )

conn
|> put_session(:enterprise_oauth_context, %{
  organization_id: org.id,
  connection_id: connection.id,
  routing_source: "explicit_org"
})
|> put_session(:oauth_state, session_params)
|> redirect(external: url)
```

### Anti-Patterns to Avoid

- **Starting OIDC from the generic discovery endpoint:** this violates D-02 and makes the callback path rely on email-derived inference. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **Matching domains with suffixes, wildcards, or heuristic rules:** D-05 explicitly disallows these because enterprise routing must be exact and supportable. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- **Keeping org truth only in `assigns`:** Plug docs make clear that `assigns` disappear after the request; redirect flows need session or signed state. [CITED: https://hexdocs.pm/plug/Plug.Conn.html]
- **Letting callback create a session before org/connection revalidation:** session/audit truth would then be wrong for the very first authenticated event. [VERIFIED: `lib/sigra/auth.ex`, `lib/sigra/oauth.ex`] 

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| OIDC request/callback ceremony | A parallel enterprise-only OAuth stack | `Sigra.OAuth` on top of Assent OIDC | Sigra already signs state and Assent already handles OIDC authorize/callback, PKCE, nonce, and ID token validation. [VERIFIED: `lib/sigra/oauth.ex`] [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |
| Cross-request routing state | Ad hoc query params or transient assigns | Plug session plus signed Sigra OAuth state | Redirect flows require persistent state, and signed state adds tamper resistance. [CITED: https://hexdocs.pm/plug/Plug.Conn.html] [VERIFIED: `lib/sigra/oauth.ex`] |
| Active organization hydration | A custom "set current org after login" branch | `Sigra.Auth.create_session/4`, `Sigra.SessionStores.Ecto`, and `Sigra.Scope.Hydration` | These already implement DB-backed org truth and stale-pointer recovery semantics. [VERIFIED: `lib/sigra/auth.ex`, `lib/sigra/session_stores/ecto.ex`, `lib/sigra/scope/hydration.ex`] |
| Domain normalization | Custom casing/whitespace logic in controllers | `Sigra.Auth.normalize_email/1` | The helper already defines the repo's normalization semantics. [VERIFIED: `lib/sigra/auth.ex`] |

**Key insight:** the hard part is not "looking up a domain"; it is keeping the first redirect, callback, session row, and first audit event all anchored to the same organization. The repo already has primitives for that. Phase 123 should compose them rather than inventing new ones. [VERIFIED: `lib/sigra/oauth.ex`, `lib/sigra/auth.ex`, `lib/sigra/session_stores/ecto.ex`, `.planning/research/PITFALLS.md`]

## Common Pitfalls

### Pitfall 1: Wrong-Org Routing

**What goes wrong:** a user begins enterprise login from one org surface and lands in another org or ambiguous connection. [VERIFIED: `.planning/research/PITFALLS.md`]

**Why it happens:** the callback or discovery path trusts email-derived inference more than the initiating org/connection truth. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `lib/sigra/oauth.ex`]

**How to avoid:** redirect discovery into the canonical org route before OIDC starts, then bind org/connection ids into signed state and re-fetch them on callback. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `lib/sigra/oauth.ex`]

**Warning signs:** callback code only knows `provider` and user email, or logs can show enterprise login success without an initiating org id. [VERIFIED: `lib/sigra/oauth.ex`, `lib/sigra/auth.ex`]

### Pitfall 2: Over-Broad Domain Matching

**What goes wrong:** `foo.example.com` or a shared domain routes users into the wrong organization connection. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]

**Why it happens:** planners treat discovery as convenience search instead of a strict auth-routing rule. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]

**How to avoid:** allow only exact post-normalization matches against one active connection backed by one verified uniquely owned domain; reject pending, duplicate, wildcard, suffix, and shared cases. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]

**Warning signs:** requirements or tests mention "best match", "fallback match", or wildcard domains. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]

### Pitfall 3: Session Truth Lags Behind Callback Truth

**What goes wrong:** the callback succeeds, but the session row or hydrated scope still points at `nil` or the wrong org. [VERIFIED: `lib/sigra/auth.ex`, `lib/sigra/session_stores/ecto.ex`, `lib/sigra/scope/hydration.ex`]

**Why it happens:** enterprise callback code logs the user in without passing org-aware session metadata or without updating the session store after resolution. [VERIFIED: `lib/sigra/oauth/callback.ex`, `lib/sigra/auth.ex`] 

**How to avoid:** make the enterprise callback produce session metadata that carries the resolved org and ensure `create_session/4` writes that org into the DB-backed session row before first redirect. [VERIFIED: `lib/sigra/auth.ex`, `lib/sigra/session_stores/ecto.ex`] 

**Warning signs:** browser flow works visually, but `current_scope.active_organization` is nil on the next request. [VERIFIED: `lib/sigra/scope/hydration.ex`, `test/example/test/example_web/smoke/session_active_org_round_trip_test.exs`] 

### Pitfall 4: Silent Downgrade on Discovery Failure

**What goes wrong:** enterprise discovery ambiguity quietly falls back into password or magic-link login, teaching the user the wrong mental model. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]

**Why it happens:** teams optimize for convenience instead of keeping recovery in the same auth mode. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]

**How to avoid:** keep recovery on an explicit enterprise retry surface and expose other auth modes only as separate user choices outside the enterprise-routing flow. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]

**Warning signs:** controller branches redirect generic enterprise errors back to the default login form with no org context. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `test/example/lib/example_web/controllers/session_controller.ex`]

## Code Examples

Verified patterns from official and repo sources:

### Scoped Enterprise Entry Route

```elixir
# Source: https://hexdocs.pm/phoenix/1.8.5/router.html
scope "/organizations/:org", ExampleWeb do
  pipe_through [:browser]

  get "/sso", EnterpriseSSOController, :new
  post "/sso", EnterpriseSSOController, :create
end
```

### OIDC Session Parameters Stored Across Redirect

```elixir
# Source: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html
config
|> Assent.Strategy.OIDC.authorize_url()
|> case do
  {:ok, %{url: url, session_params: session_params}} ->
    conn
    |> Plug.Conn.put_session(:oauth_state, session_params)
    |> Phoenix.Controller.redirect(external: url)
end
```

### Sigra State Replacement Pattern To Extend

```elixir
# Source: lib/sigra/oauth.ex
state = generate_state(config.secret_key_base, provider)
new_url = replace_url_state(url, state)
session_params = %{sigra_state: state} |> maybe_put(:code_verifier, Map.get(assent_session, :code_verifier))
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Provider-only OAuth entry (`/auth/:provider`) | Org-scoped enterprise entry plus bounded discovery that resolves before OIDC starts | Current enterprise milestone design, 2026-05-25 [VERIFIED: context/research] | Keeps multi-tenant enterprise auth explicit and supportable. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `.planning/threads/enterprise-sso-b2b-connections.md`] |
| Email-only tenant inference on callback | Signed-state plus session-bound org/connection verification on callback | Current best practice reflected in Sigra + OIDC docs [VERIFIED/CITED] | Prevents wrong-org login and stale callback binding. [VERIFIED: `lib/sigra/oauth.ex`] [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |
| Cookie-only auth context | DB-backed session row with `active_organization_id` | Already shipped before Phase 123 [VERIFIED: codebase] | Lets the first post-login request hydrate the correct org scope without stuffing org truth into cookies. [VERIFIED: `lib/sigra/session.ex`, `lib/sigra/session_stores/ecto.ex`, `test/example/test/example_web/smoke/session_active_org_round_trip_test.exs`] |

**Deprecated/outdated:**
- Discovery heuristics such as wildcard, suffix, or shared-domain matching are out of policy for this phase. Use exact verified unique domains only. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
- A generic social-OAuth mental model is insufficient for enterprise multi-org routing because the initiating organization becomes security-relevant state. [VERIFIED: `.planning/research/PITFALLS.md`, `lib/sigra/oauth.ex`] 

## Assumptions Log

All material claims in this research were verified in this session or cited from official documentation. [VERIFIED: this document]

## Open Questions

1. **Controller vs LiveView for the canonical enterprise entry**
   - What we know: the current login page is controller-rendered, and auth-critical Sigra flows are HTTP oriented. [VERIFIED: `test/example/lib/example_web/controllers/session_html.ex`, `test/example/lib/example_web/controllers/session_controller.ex`]
   - What's unclear: whether the org-scoped enterprise entry should be a small controller surface or a LiveView wrapper for richer retry states. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`]
   - Recommendation: plan controller-first unless UX proof requires LiveView; it minimizes auth-flow surface area and fits existing patterns. [VERIFIED: codebase routing/controller posture]

2. **Exact split between signed OAuth state and server session**
   - What we know: D-06 permits either or both, Plug session is the correct cross-request store, and Sigra already signs OAuth state. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `lib/sigra/oauth.ex`] [CITED: https://hexdocs.pm/plug/Plug.Conn.html]
   - What's unclear: whether the implementation should store all enterprise routing context in both places or keep the session minimal and the signed state authoritative. [VERIFIED: current code review]
   - Recommendation: store the full routing tuple in signed state and a minimal mirrored copy in the server session for UX/error rendering. Treat signed state as callback authority. [VERIFIED: `lib/sigra/oauth.ex`, `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`] 

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | library and example-app implementation/tests | ✓ [VERIFIED: `elixir -e 'IO.puts(System.version())'`] | `1.19.5` [VERIFIED: local command output] | — |
| Mix | dependency and test commands | ✓ [VERIFIED: `mix -v`] | `1.19.5` [VERIFIED: local command output] | — |
| PostgreSQL | root tests and example-app tests | ✓ [VERIFIED: `pg_isready -h localhost -p 5432 -U postgres`] | server accepting on `localhost:5432` [VERIFIED: local command output] | none for full test proof |
| Docker | local DB bootstrap if Postgres is restarted or missing later | ✓ [VERIFIED: `docker --version`] | `29.4.1` [VERIFIED: local command output] | existing local Postgres service |

**Missing dependencies with no fallback:** None at research time. [VERIFIED: local environment audit]

**Missing dependencies with fallback:** None at research time. [VERIFIED: local environment audit]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit in two lanes: root library tests plus the `test/example` Phoenix app test harness. [VERIFIED: `test/test_helper.exs`, `test/example/test/test_helper.exs`, `test/example/mix.exs`] |
| Config file | `test/test_helper.exs` and `test/example/test/test_helper.exs`. [VERIFIED: codebase] |
| Quick run command | `mix test test/sigra/enterprise_connections/context_test.exs test/sigra/enterprise_connections/activation_test.exs` [VERIFIED: files exist] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && (cd test/example && mix test)` [VERIFIED: `CLAUDE.md`, `test/test_helper.exs`, `test/example/test/test_helper.exs`] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SSO-03 | Explicit org-scoped enterprise entry only uses the current org's active enterprise connection and rejects unavailable/disabled/validation-failed connections. [VERIFIED: requirement + context] | controller/integration | `(cd test/example && mix test test/example_web/controllers/enterprise_sso_controller_test.exs)` | ❌ Wave 0 |
| SSO-03 | Generic discovery only auto-routes on one exact verified unique domain match and otherwise fails closed with bounded reasons. [VERIFIED: D-04 to D-10] | library unit | `mix test test/sigra/enterprise_routing/discovery_test.exs` | ❌ Wave 0 |
| SSO-03 | Callback revalidates bound `organization_id`, `connection_id`, and `routing_source` before session creation. [VERIFIED: D-06, D-11 to D-13] | library integration | `mix test test/sigra/oauth/enterprise_callback_test.exs` | ❌ Wave 0 |
| SSO-03 | Successful enterprise login preserves session org truth and shows correct org context on first authenticated request. [VERIFIED: SSO-03 + Phase success criteria] | example-app integration/smoke | `(cd test/example && mix test test/example_web/integration/enterprise_sso_routing_flow_test.exs)` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** run the smallest touched-lane command (`mix test ...` for library changes, `cd test/example && mix test ...` for generated-host changes). [VERIFIED: repo test split]
- **Per wave merge:** run both the new library routing tests and the new example-app routing/callback tests. [VERIFIED: phase spans both tiers]
- **Phase gate:** run the full root plus example-app suites green before `$gsd-verify-work 123`. [VERIFIED: `.planning/config.json`, `CLAUDE.md`]

### Wave 0 Gaps

- `test/sigra/enterprise_routing/discovery_test.exs` — exact-match, duplicate-match, disabled/pending/wildcard rejection matrix. [VERIFIED: missing by repo search]
- `test/sigra/oauth/enterprise_callback_test.exs` — signed-state + session revalidation contract before session creation. [VERIFIED: missing by repo search]
- `test/example/test/example_web/controllers/enterprise_sso_controller_test.exs` — explicit org entry and same-mode recovery UI/controller behavior. [VERIFIED: missing by repo search]
- `test/example/test/example_web/integration/enterprise_sso_routing_flow_test.exs` — end-to-end org discovery → callback → hydrated scope proof. [VERIFIED: missing by repo search]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes [VERIFIED: phase scope] | Reuse `Sigra.OAuth` + Assent OIDC for enterprise authentication ceremony and callback validation. [VERIFIED: `lib/sigra/oauth.ex`] [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |
| V3 Session Management | yes [VERIFIED: phase scope] | Use DB-backed Sigra sessions and set the resolved `active_organization_id` before first post-login redirect. [VERIFIED: `lib/sigra/auth.ex`, `lib/sigra/session_stores/ecto.ex`] |
| V4 Access Control | yes [VERIFIED: phase scope] | Keep org resolution library-owned and fail closed on ambiguity or unavailable connections. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `lib/sigra/enterprise_connections.ex`] |
| V5 Input Validation | yes [VERIFIED: phase scope] | Normalize email with `Sigra.Auth.normalize_email/1`; reject non-exact and non-verified domain matches. [VERIFIED: `lib/sigra/auth.ex`, `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`] |
| V6 Cryptography | yes [VERIFIED: phase scope] | Continue using HMAC-signed Sigra state tokens and Assent's OIDC ID token validation; never hand-roll new crypto. [VERIFIED: `lib/sigra/oauth.ex`] [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Wrong-org callback binding | Spoofing / Elevation | Bind org/connection ids into signed state and re-fetch the connection on callback before session creation. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `lib/sigra/oauth.ex`] |
| State/session tampering across redirects | Tampering | Reuse Sigra's HMAC-signed OAuth state and compare against session-held ceremony params. [VERIFIED: `lib/sigra/oauth.ex`] |
| Account takeover via email-only routing | Spoofing | Treat discovery as convenience only, require exact verified unique domain match, and preserve org truth into callback. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`, `.planning/research/PITFALLS.md`] |
| Silent auth-mode downgrade | Repudiation / UX-induced auth bypass | Keep recovery in enterprise mode and expose other login methods only as explicit separate choices. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`] |
| Discovery-based privacy leakage | Information Disclosure | Keep generic error copy on the generic discovery surface and only show specific org truth after org context is explicit. [VERIFIED: `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md`] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/123-org-aware-enterprise-routing/123-CONTEXT.md` - locked decisions, discretion, scope, canonical references.
- `.planning/REQUIREMENTS.md` - `SSO-03` contract.
- `.planning/STATE.md` - milestone sequencing and current execution boundary.
- `CLAUDE.md` - project constraints, stack, testing requirements.
- `.planning/phases/122-enterprise-connection-contract-validation/122-RESEARCH.md` - Phase 122 substrate assumptions Phase 123 builds on.
- `lib/sigra/oauth.ex` - signed state, authorize/callback ceremony, Assent integration.
- `lib/sigra/oauth/callback.ex` - current callback session metadata behavior.
- `lib/sigra/auth.ex` - email normalization and session creation ordering.
- `lib/sigra/session.ex` - `active_organization_id` session truth model.
- `lib/sigra/session_stores/ecto.ex` - DB-backed session persistence.
- `lib/sigra/scope/hydration.ex` - first-request org hydration contract.
- `lib/sigra/plug/load_active_organization.ex` - stale-pointer recovery semantics.
- `lib/sigra/enterprise_connections.ex` - organization-bound enterprise connection lifecycle API.
- `lib/sigra/enterprise_connections/validation.ex` - current validation semantics.
- `test/example/lib/example/accounts/enterprise_connection.ex` - `login_hint_domains` and connection schema shape.
- `test/example/lib/example/organizations.ex` - host wrapper seam for enterprise connections.
- `test/example/lib/example_web/router.ex` - established scoped routing posture.
- `test/example/lib/example_web/controllers/session_html.ex` - current login surface.
- `test/example/lib/example_web/controllers/session_controller.ex` - controller-based auth posture.
- `test/example/lib/example_web/live/organization_settings_live.ex` - current enterprise connection operator surface.
- `test/example/test/example_web/smoke/session_active_org_round_trip_test.exs` - DB-backed active-org round-trip proof.
- `https://hexdocs.pm/phoenix/Phoenix.Router.html` - scoped routes, pipelines, `route_info/4`.
- `https://hexdocs.pm/phoenix/1.8.5/router.html` - scoped route and verified-route examples.
- `https://hexdocs.pm/plug/Plug.Conn.html` - session vs assigns, `get_session/2`, `put_session/3`.
- `https://hexdocs.pm/assent/Assent.Strategy.OIDC.html` - OIDC `authorize_url/1`, `callback/3`, `session_params`, nonce handling.
- `https://hex.pm/packages/phoenix` - current Phoenix release metadata.
- `https://hex.pm/packages/ecto` - current Ecto release metadata.
- `https://hex.pm/packages/assent` - current Assent release metadata.

### Secondary (MEDIUM confidence)

- `.planning/threads/enterprise-sso-b2b-connections.md` - milestone prior art summary.
- `.planning/research/SUMMARY.md` - milestone wedge and sequencing.
- `.planning/research/ARCHITECTURE.md` - library vs generated-host boundary.
- `.planning/research/PITFALLS.md` - wrong-org routing risk framing.
- `https://docs.allauth.org/en/latest/socialaccount/providers/saml.html` - prior art for org-slug-scoped enterprise entry endpoints.
- `https://workos.com/docs/sso/domains` - prior art for verified-domain gating and outside-organization rejection.

### Tertiary (LOW confidence)

- None. [VERIFIED: this research used repo evidence and official docs only]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - current project deps and current Hex metadata were verified in-session, and no new package is required. [VERIFIED: `mix.exs`, `mix hex.info ...`]
- Architecture: HIGH - the repo already contains the relevant router, session, org, and OAuth seams Phase 123 should extend. [VERIFIED: codebase review]
- Pitfalls: HIGH - locked context decisions, prior milestone research, and official session/OIDC docs align on the main failure modes. [VERIFIED/CITED: sources above]

**Research date:** 2026-05-25 [VERIFIED: session context]
**Valid until:** 2026-06-24 for repo-specific findings; re-check Hex package versions and official docs if planning slips beyond 30 days. [VERIFIED: current research date + fast-moving dependency metadata]
