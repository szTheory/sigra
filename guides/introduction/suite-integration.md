<!-- validated_against: sigra v1.29 -->
<!-- last_validated: 2026-05-27 -->
# Suite Integration

Last validated: 2026-05-27.

> **Sigra works fully standalone.** Threadline, Mailglass, Accrue, Lockspire, Relyra, and Rulestead are all optional integrations; Sigra ships without any of them, and removing the integration sections below returns Sigra to standalone operation with no further changes.

## What this is

Six companion libraries form an optional suite around Sigra's authentication core. Each one owns a single, well-defined surface that Sigra deliberately does not own — and each one ships as an independent dependency you opt into.

- **Threadline** owns audit-row projection and queryable timelines. Sigra fires audit events; Threadline projects those events into per-actor and per-resource timeline views your application can query.
- **Mailglass** owns transactional auth-email dispatch with the `NoTrackingOnAuthStream` privacy guard that prevents tracking pixels and click-redirect rewrites on auth-flow emails.
- **Accrue** owns seat-based billing webhook consumption. It subscribes to host-emitted `billing.*` events to gate identity-level entitlement changes — Sigra holds the identity, Accrue holds the seat.
- **Lockspire** is the OAuth 2.0 / OIDC authorization-server companion. Sigra establishes identity; Lockspire issues access tokens to third-party clients on behalf of that identity.
- **Relyra** handles SAML 2.0 and enterprise SSO identity-provider federation. External IdPs federate into Sigra sessions through Relyra, keeping the SAML state machine out of Sigra's core.
- **Rulestead** provides rule-engine and feature-flag evaluation at the Sigra auth boundary, letting you gate routes and actions on evaluated rules without building a policy engine inside Sigra.

Read this page before any individual recipe. The recipes show wiring; this page shows the picture — where each library sits relative to Sigra's core, what data flows between them, and where the deliberate boundary walls are. The Diminishing Returns Wall section near the bottom defines the edges Sigra will not cross, by design.

## How to read this page

The next four sections move from picture to specifics:

1. **Ecosystem diagram** — the visual layout of Sigra plus the six satellites.
2. **Who owns what** — a role table pinning each library to a single ownership surface.
3. **Audit event fan-out matrix** — which sinks receive which audit events by default.
4. **The Diminishing Returns Wall** — the boundaries Sigra deliberately will not cross.

If you only have time for one section, read the diagram and the role table; together they answer "where does X belong" for any new responsibility you might be considering.

## Ecosystem diagram

```
                ╔══════════════════════════════════════╗
                ║           Sigra (auth core)          ║
                ║  sessions · MFA · passkeys · audit   ║
                ║  webhooks · SSO · magic links        ║
                ╚═══════════════╤══════════════════════╝
                                │
              ──[:sigra, :audit, :log]──►  (telemetry tap)
                                │
       ┌────────────────────────┼────────────────────────┐
       │                        │                        │
  ┌────▼─────┐            ┌─────▼────┐            ┌──────▼─────┐
  │  email   │            │  audit   │            │  OAuth AS  │
  │ dispatch │            │ project. │            │            │
  │ Mailglass│            │Threadline│            │ Lockspire  │
  └────┬─────┘            └──────────┘            └────────────┘
       │
  ┌────▼─────┐            ┌──────────┐            ┌────────────┐
  │  seats / │            │  SAML /  │            │  rules /   │
  │ billing  │            │ ent SSO  │            │  flags     │
  │  Accrue  │            │  Relyra  │            │ Rulestead  │
  └──────────┘            └──────────┘            └────────────┘
```

*Diagram: a host Phoenix app sits at the center; Sigra owns auth identity, sessions, MFA, passkeys, audit DB rows, webhooks, and SSO. Threadline, Mailglass, Accrue, Lockspire, Relyra, and Rulestead are six optional satellites the host wires in. The labeled edge `[:sigra, :audit, :log]` shows the telemetry tap Threadline subscribes to for audit-row projection.*

The central double-line box is heavier than the satellite single-line boxes on purpose — Sigra is load-bearing, and the satellites attach to it rather than the other way around. The telemetry tap is drawn as an outgoing edge (not a box) because it is a fan-out point, not a process. Any number of subscribers can attach to it; Threadline is one example.

The satellite arrangement is conceptual, not topological. Mailglass and Accrue happen to be drawn in the left column because email and billing are both host-discretion side-effects of identity events. Threadline and Relyra share the middle column because both are projection-style integrations: one projects audit rows into a timeline, the other projects external identities into Sigra sessions. Lockspire and Rulestead share the right column as authorization-flavored extensions — Lockspire issues tokens, Rulestead evaluates policy. None of those column groupings imply data flow between the satellites; each satellite talks to Sigra independently.

## Who owns what

Each row is a distinct library with a distinct ownership boundary. Sigra owns the source-of-truth `AuditEvent` row for every auth action; Threadline projects that row into a queryable timeline. Mailglass owns email dispatch; Sigra owns auth events but delegates the email side-effect. The four Phase 134 libraries (Accrue, Lockspire, Relyra, Rulestead) extend Sigra's surface without blurring Sigra's own boundary.

The `Owns` column states the surface each library is responsible for. The `Recipe` column links to the wiring guide for that library — start there once you have decided which companions to integrate.

| Library | Owns | Recipe |
|---------|------|--------|
| **Sigra core** | Auth identity, sessions, MFA, passkeys, audit DB row (source-of-truth), webhooks, SSO | [Getting started](./getting-started.html) |
| **Threadline** | Audit row projection / queryable timeline (idempotency by Sigra audit UUID + `occurred_at`) | [Threadline recipe](../recipes/companion-libs/threadline.html) |
| **Mailglass** | Transactional auth-email dispatch + `NoTrackingOnAuthStream` privacy guard | [Mailglass recipe](../recipes/companion-libs/mailglass.html) |
| **Accrue** | Seat-based billing webhook consumer (host-emitted `billing.*` events; not on Sigra's audit fan-out by default) | [Accrue recipe](../recipes/companion-libs/accrue.html) |
| **Lockspire** | OAuth 2.0 / OIDC authorization-server (Sigra is the *identity* source; Lockspire is the *AS*) | [Lockspire recipe](../recipes/companion-libs/lockspire.html) |
| **Relyra** | SAML 2.0 + enterprise SSO IdP federation | [Relyra recipe](../recipes/companion-libs/relyra.html) |
| **Rulestead** | Rule-engine / feature-flag evaluation surface | [Rulestead recipe](../recipes/companion-libs/rulestead.html) |

### Standalone or suite-augmented

A Sigra install without any of the satellites is a complete authentication library: registration, login, password reset, magic links, MFA via TOTP and passkeys, OAuth/OIDC clients, session management, audit logging, and webhook egress. The companion libraries do not fill gaps in Sigra; they extend Sigra's surface into adjacent problem domains that are deliberately not part of an auth library's job. A pragmatic rollout starts with Sigra alone, adds Mailglass when transactional email becomes a concern, adds Threadline when audit data needs a queryable surface, and adds the remaining four as enterprise or billing requirements arrive.

The role table groups libraries by ownership, not by integration order. Read each row independently. If a library is not in your roadmap, you can skip its row entirely — the recipe links will still resolve once you come back.

## Audit event fan-out matrix

Which sinks receive each Sigra audit event by default. This matrix covers a representative subset of audit actions; the complete list of action strings is in [Audit logging](../flows/audit-logging.html).

| Event | Sigra audit DB row | `[:sigra, :audit, :log]` telemetry | Sigra webhooks | Threadline forwarder | Mailglass |
|-------|--------------------|------------------------------------|----------------|----------------------|-----------|
| `auth.login.success` | ✓ | ✓ | (host) | ✓ | — |
| `auth.login.failure` | ✓ | ✓ | (host) | — | — |
| `auth.password_reset.success` | ✓ | ✓ | (host) | ✓ | (host) |
| `mfa.challenge.success` | ✓ | ✓ | — | — | — |
| `account.deletion_execute` | ✓ | ✓ | (host) | ✓ | — |
| `billing.subscription.upgraded` | n/a | — | — | — | — |

```
✓      = Sigra fans this event into the named sink by default.
(host) = Host code may opt into this sink (e.g. Mailglass receives email side-effects).
—      = This sink does not receive this event.
n/a    = This event is host-emitted; Sigra does not own it.
```

Two cells worth calling out explicitly:

**`auth.password_reset.success` / Mailglass column is `(host)`:** Mailglass receives the *email side-effect* of a password reset (the notification email), not the audit event itself. Sigra fires the audit event; your application code calls `Mailglass.deliver/1` with the password reset context. These are two separate fan-out paths. A common misread is to expect Mailglass to subscribe directly to `auth.password_reset.success` telemetry — it does not.

**`billing.subscription.upgraded` / Sigra audit DB row is `n/a`:** Sigra does not own billing events. A host-emitted `billing.*` event originates from your billing webhook handler, not from Sigra's auth core. The row is included here to demonstrate that the matrix generalizes: any host-emitted event reads `n/a` in the Sigra audit DB column.

Sigra webhooks are `(host)` everywhere because webhook egress is opt-in per audit action — your host application registers webhook endpoints, and Sigra fans matching events out to those endpoints. If no host webhook is registered for a given action, the column reads as no-op even though the audit row and telemetry still fire.

The fan-out columns are listed left-to-right in roughly increasing distance from Sigra's core: the audit DB row is the canonical write; the telemetry stream is the in-process notification; webhooks cross a network boundary; Threadline projects on top of the audit row from a separate process; Mailglass fires only as a host-driven email side-effect. Reading the matrix in that order is the easiest way to reason about latency and failure isolation for any given event.

## The Diminishing Returns Wall

Sigra owns identity, not policy, not billing, not aesthetics — the boundaries below define where Sigra deliberately stops and companion libraries or host code take over.

> - **Opinionated Authorization (RBAC / Zanzibar):** Sigra provides the identity (`user_id`, `organization_id`); the host app must own the *policy* (what the user can do). We provide seams, but we will not build a built-in roles engine.
> - **Billing & Subscription Integration:** Direct mappings to Stripe or other billing providers are domain logic. Sigra provides webhook egress for syncing identity state, not billing logic.
> - **Frontend / UI Component Libraries:** Sigra generates functional HTML (`mix sigra.install`); it will not ship a heavy CSS framework or React component library. Aesthetics belong to the adopter.

Each companion library above respects this boundary by owning the surface Sigra deliberately doesn't. Threadline owns the queryable timeline layer Sigra chose not to build. Mailglass owns email rendering and privacy controls Sigra chose not to embed. Lockspire owns token issuance to third parties; Relyra owns external IdP federation; Rulestead owns the policy / rule evaluation surface.

The phrasing matters: Sigra provides **seams**, not built-ins. A seam is a callback, a telemetry event, a webhook hook, or a structured audit row that a companion library or host application subscribes to. Pulling a policy engine into Sigra would force every adopter to inherit one specific model of authorization; shipping a built-in billing integration would couple identity to a specific billing provider. The seam-based design keeps those choices in the adopter's hands.

If you find yourself asking "why doesn't Sigra do X?", the answer is almost always that X belongs to a companion library or to your host application — and that the seam to attach X already exists. The recipes show how to attach the existing seams.

## Where to next

Start with any recipe in the order that matches your current need. Each recipe is self-contained — you do not need to read all six before wiring the first one. The two recipes already shipped (Threadline and Mailglass) are the closest mirrors of this page's framing; the remaining four arrive in v1.30.

- **[Threadline recipe](../recipes/companion-libs/threadline.html)** — wire audit row projection to a queryable timeline with idempotency by Sigra audit UUID.
- **[Mailglass recipe](../recipes/companion-libs/mailglass.html)** — wire Mailglass behind `Sigra.Mailer` for transactional auth email with `NoTrackingOnAuthStream` privacy-guard opt-in.
- **[Accrue recipe](../recipes/companion-libs/accrue.html)** — consume `billing.*` webhook events from Sigra and sync seat-based entitlements in your host app.
- **[Lockspire recipe](../recipes/companion-libs/lockspire.html)** — configure Lockspire as the OAuth 2.0 / OIDC authorization-server backed by Sigra identity.
- **[Relyra recipe](../recipes/companion-libs/relyra.html)** — federate enterprise SSO identity providers via SAML 2.0 into Sigra sessions.
- **[Rulestead recipe](../recipes/companion-libs/rulestead.html)** — evaluate feature flags and rules at the Sigra auth boundary without a built-in policy engine.

A pragmatic ordering: integrate Threadline first if you need an audit-row UI; Mailglass first if your application is sending auth emails and you care about deliverability and tracker-free user mail; Accrue first if you sell seats; Lockspire first if you are an OAuth provider for downstream apps; Relyra first if enterprise customers require SAML SSO; Rulestead first if you want one place to evaluate feature flags and authorization rules. You can also wire none of them and Sigra remains a complete auth library on its own.

Each recipe targets a single companion library and assumes Sigra is already installed. The recipes do not require each other — you can wire Threadline without Mailglass, or Lockspire without Relyra. If you are unsure where to start, the [Getting started](./getting-started.html) page covers the Sigra-only baseline that every install begins from.

If you reach the end of a recipe and find yourself adapting the wiring beyond what the recipe shows, that is expected — the recipes describe a default integration shape, not a contract you must follow exactly. The companion libraries are independent of Sigra, and your application owns the final wiring. Sigra's role is to provide the seams; how you connect the satellites is yours to decide.

Once a companion library is wired, treat it as part of your application surface, not as part of Sigra's. Upgrading Sigra does not change the companion's API; upgrading the companion does not require a Sigra release. The two release cycles are independent on purpose.

> **Reminder:** every integration above is opt-in; Sigra runs fully standalone without any of them.
