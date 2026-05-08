# Phase 99: Admin and generated-host webhook UX - Research

**Researched:** 2026-05-06
**Domain:** Phoenix LiveView admin UX for Sigra webhooks
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

### Subscription workflow
- **D-99-01 — Use a mixed workflow, not all-inline CRUD.** The primary subscription surface should be a list-centered LiveView with fast `new` / light `edit` flows via LiveView modal or drawer patterns, plus a dedicated subscription detail page for runtime-heavy operations.
- **D-99-02 — Reserve the detail page for operational depth.** Secret rotation, delivery history, attempt inspection, endpoint status, and setup guidance belong on the subscription detail page, not on the index.
- **D-99-03 — Keep the index efficient and URL-driven.** The subscription index should follow Sigra's existing admin idiom: filterable list, deep-linkable states, and quick create/edit without losing list context.

### Event-scope editor
- **D-99-04 — Use grouped presets plus explicit checkbox refinement.** Operators should start from curated event-group presets such as user lifecycle or session lifecycle, then refine with explicit event checkboxes.
- **D-99-05 — Persist only explicit event lists.** Presets are a UX accelerator only; the saved subscription must still store the resolved explicit `event_types` list from Phase 97.
- **D-99-06 — Avoid flat-list-only and preset-only extremes.** A raw flat list is too noisy as the catalog grows, while preset-only selection is too rigid and would push adopters toward duplicate endpoints or workarounds.

### Delivery-history UX
- **D-99-07 — Make subscription history the default operator view.** Delivery history should primarily be experienced in the context of a selected subscription, matching the endpoint-centric mental model used by successful webhook products.
- **D-99-08 — Add a separate global failures/retrying inbox.** Phase 99 should also expose a global view for recent failures and retrying deliveries so operators can triage active incidents quickly without drilling through every subscription.
- **D-99-09 — Reuse one delivery-detail surface.** Both the per-subscription history view and the global failures view should link into the same delivery detail page backed by `webhook_deliveries` summary fields plus `webhook_delivery_attempts`.
- **D-99-10 — Query summary rows first, ledger rows second.** Lists and triage views must rely on cheap current-state fields from `webhook_deliveries`; the append-only attempt ledger is for detail inspection, not for powering every list row.

### Secret rotation and receiver setup UX
- **D-99-11 — Ship an intermediate detail-page setup experience.** The generated host should expose a practical setup checklist and receiver-verification guidance, but not a full wizard or contract-expanding test-send flow.
- **D-99-12 — Secret reveal/copy must be intentional and scoped.** The active signing secret may be revealed or copied from the detail page, but only through explicit operator actions with clear copy around sensitivity.
- **D-99-13 — Rotation is a confirmed one-way replace action in v1.22.** The rotation UX must clearly state that Sigra currently uses one active secret per subscription and does not promise overlap or zero-downtime sender-side rollover.
- **D-99-14 — End-to-end proof should use real Sigra events.** Setup guidance should tell adopters to trigger a real Sigra-owned event and inspect delivery history, rather than introducing synthetic ping/test-event semantics in this phase.

### Host boundary and docs emphasis
- **D-99-15 — Use concise in-page boundary callouts plus generated docs/recipes.** The UI should contain short, high-signal reminders that Sigra emits trusted signed events while the host app owns the receiving endpoint and downstream automation; the full implementation path belongs in generated docs.
- **D-99-16 — Keep inline copy short and contractual.** In-page guidance should focus on the receiver boundary, raw-body verification, dedupe by `delivery_id`, and the implications of secret rotation. Longer receiver setup belongs in guides, not repeated banners.
- **D-99-17 — Generated docs must be host-actionable.** The generated guidance should include the receiver route shape, `Plug.Parsers.body_reader` pattern, verification flow, dedupe expectations, and the operational note that sender-side rotation does not yet provide dual-secret overlap.

### Cross-cutting UX and architecture
- **D-99-18 — Stay inside Sigra's existing admin idiom.** Webhook UX should look and behave like the current user and audit admin surfaces: LiveView list/detail flows, server-rendered filters, explicit actions, and host-owned shell chrome.
- **D-99-19 — Do not imply unsupported product guarantees.** The UX must not suggest wildcard event expansion, replay tooling, dual-secret sender overlap, or synthetic delivery probes that the underlying contract does not actually support.
- **D-99-20 — Keep library-owned runtime concerns on stable pages, not in generated sprawl.** The generated host can own thin wrappers, routes, and shell integration, but the operational behavior should remain aligned with Sigra's library-owned runtime and persisted-state model.

### User preference carried forward
- **D-99-21 — Shift routine implementation decisions left within GSD.** Downstream planning and execution should default to a coherent recommendation set without reopening choices unless a question materially changes the security model, public webhook contract, semver surface, or generated-host contract.
- **D-99-22 — Optimize for least surprise and strong DX over surface-minimizing cleverness.** Preference goes to patterns that feel idiomatic in Phoenix/LiveView/Ecto, align with successful webhook products, and make generated hosts easy to operate and maintain.

### Claude's Discretion
- Exact module names and route paths for webhook subscription/detail/history LiveViews
- Exact preset group names and event-group taxonomy, provided the saved state remains an explicit `event_types` list
- Exact copy and component treatment for reveal-secret, rotate-secret confirmation, and setup checklist cards
- Exact placement of the global failures/retrying inbox within the admin nav, provided it remains clearly secondary to subscription management
- Exact filters, pagination controls, and badge wording for delivery-history views, provided they stay URL-driven and summary-row-backed

### Deferred Ideas (OUT OF SCOPE)
- Sender-side overlapping dual-secret rotation windows and true zero-downtime rotation semantics (`WH-04`)
- Synthetic ping/test-event contract or setup wizard that implies new webhook semantics
- Replay/redrive tooling from UI or CLI (`WH-05`)
- Public/self-service subscription UI outside admin
- Analytics-heavy dashboards, tenant-wide webhook observability, or event-bus-style abstractions
- Endpoint policy / egress controls beyond the current milestone (`WH-06`)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| WH-03 | Generated admin LiveView lets adopters create, enable or disable, rotate, and inspect webhook subscriptions and delivery history, and the generated host gets the minimum wiring needed to expose the feature without reverse-engineering Sigra internals. | Use Sigra-owned LiveView list/detail patterns, add library-owned webhook query/action APIs for detail/history/rotation, extend generated host wrappers/router/nav seams, and verify through Example ExUnit plus generated-host Playwright parity lanes. [VERIFIED: requirements] [VERIFIED: codebase] [VERIFIED: context] |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Keep Phoenix `1.8+` and Ecto `3.x` as the blessed path. [VERIFIED: codebase]
- Preserve PostgreSQL as the primary local/CI test database posture. [VERIFIED: codebase]
- Keep security aligned with OWASP posture; do not weaken signing, secret handling, or enumeration-safe patterns for DX. [VERIFIED: codebase]
- Prefer minimal transitive dependencies and copy-paste over new dependencies when the code is small and stable. [VERIFIED: codebase]
- Keep LiveView supported but optional overall; Phase 99 may use LiveView because this requirement is explicitly about generated admin LiveViews. [VERIFIED: codebase] [VERIFIED: requirements]
- Login/logout and other security-sensitive mutations stay HTTP-post backed even when triggered from LiveView chrome or confirmation flows. [VERIFIED: codebase]
- Tests should be comprehensive, AAA-style, flat, and self-contained. [VERIFIED: codebase]
- Local `mix test` expects Postgres on `localhost:5432` with `postgres/postgres`. [VERIFIED: codebase]

## Summary

Phase 99 should be planned as an extension of Sigra’s existing admin architecture, not as a fresh webhook UI subsystem. Current admin screens already standardize on URL-driven LiveView lists, dedicated detail pages for risky or dense operations, generated-host shell ownership, and ExUnit plus Playwright verification around those flows. [VERIFIED: codebase] [VERIFIED: context] [CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/server/live-navigation.md]

The existing webhook runtime is already library-owned for subscription CRUD validation, event catalog, async dispatch, retry classification, and delivery summary plus attempt persistence, but it does not yet expose library APIs for subscription detail lookup, delivery-history queries, delivery-detail reads, or secret rotation/reveal actions. Phase 99 should therefore add those missing library-owned admin query/action seams first, then keep generated hosts thin by wrapping and routing them rather than embedding operational logic in templates or context sprawl. [VERIFIED: codebase] [VERIFIED: context]

The main planning risk is scope semantics. Webhook events can carry `organization_id` in event context, but webhook subscriptions and webhook deliveries are currently global rows with no organization foreign key. The safest plan is to treat webhook management as a global operator surface with optional organization context shown in delivery details where present, unless the planner explicitly adds a new scoped data contract. [VERIFIED: codebase] [VERIFIED: context]

**Primary recommendation:** Build four Sigra-admin LiveViews backed by new library-owned webhook admin query/action modules, mount them only in the existing global admin lane by default, and keep generated hosts limited to router/nav/docs/wrapper glue. [VERIFIED: codebase] [VERIFIED: context]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Subscription list/filter/create/edit UX | Frontend Server (SSR) | API / Backend | The established admin pattern is Phoenix LiveView with URL-driven `handle_params/3` state and server-rendered GET forms. [VERIFIED: codebase] [CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/server/live-navigation.md] |
| Subscription validation, enable/disable, rotation, reveal policy | API / Backend | Database / Storage | Validation and secret handling already live in `Sigra.Webhooks`; secrets are stored in the generated host schema and should stay behind library-owned actions. [VERIFIED: codebase] [VERIFIED: context] |
| Delivery history list and failures inbox | API / Backend | Database / Storage | Lists must query `webhook_deliveries` summary fields first and only drill into attempt rows on detail pages. [VERIFIED: context] [VERIFIED: codebase] |
| Delivery attempt forensic detail | Database / Storage | API / Backend | `webhook_delivery_attempts` is the append-only ledger and must remain the source for timeline detail, loaded through backend query modules. [VERIFIED: context] [VERIFIED: codebase] |
| Admin shell chrome, nav, route mounts | Generated Host / Frontend Server | — | The host already owns admin shell and router injection seams through installer templates. [VERIFIED: codebase] [VERIFIED: context] |
| Receiver setup guidance and host docs | Generated Host / Docs | API / Backend | The UI needs concise contractual copy, while full receiver steps belong in generated docs and recipes. [VERIFIED: context] [VERIFIED: codebase] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix | `1.8.5` in `mix.lock`, published 2026-03-05 | Router scopes, `live_session`, verified routes, host-generated route mounts | Existing admin and generated-host router patterns already depend on Phoenix scopes plus `live_session` guards. [VERIFIED: codebase] [VERIFIED: npm registry] [CITED: https://github.com/phoenixframework/phoenix/blob/main/guides/authn_authz/scopes.md] |
| Phoenix LiveView | `1.1.28` in `mix.lock`, published 2026-03-27 | URL-driven admin surfaces, modal/drawer interactions, server-rendered forms | Existing admin list/detail pages already use LiveView and `handle_params/3`; official docs support patch-driven URL state without remounting. [VERIFIED: codebase] [VERIFIED: npm registry] [CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/server/live-navigation.md] |
| Ecto | `3.13.5` in `mix.lock`, published 2025-11-09 | Scope-safe query modules, preloads, transactional secret/action persistence | Delivery summary and attempt persistence already rely on `Ecto.Multi`; new admin read models should stay query-module based. [VERIFIED: codebase] [VERIFIED: npm registry] [CITED: https://hexdocs.pm/ecto/3.13.5/Ecto.Multi.html] |
| Flop | `0.26.3` in `mix.lock`, published 2025-05-29 | Filter normalization, sorting, pagination metadata | `Sigra.Admin.Users.Query` already uses `Flop.Schema`, `Flop.validate/2`, and `Flop.meta/4` for the canonical admin list contract. [VERIFIED: codebase] [VERIFIED: npm registry] |
| Flop.Phoenix | `0.26.0` in `mix.lock`, published 2026-03-13 | Phoenix-facing support for the existing Flop stack | This is already part of the project’s admin stack, so webhook list/query work should stay within the same pagination/filter ecosystem rather than introducing a second one. [VERIFIED: codebase] [VERIFIED: npm registry] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Phoenix.LiveViewTest | bundled via `phoenix_live_view 1.1.28` | Assert list/detail ordering, URL state, confirmation flows, and generated copy in Example ExUnit tests | Use for page contracts, query-param preservation, form validation, and detail-page action flows. [VERIFIED: codebase] [CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/client/form-bindings.md] |
| Playwright | `@playwright/test ^1.48.0` in `test/example/priv/playwright/package.json` | Generated-host parity smoke and browser-truth admin flows | Use for generated-host router/nav parity and one end-to-end admin behavior lane, not for exhaustive state matrices already covered in ExUnit. [VERIFIED: codebase] |
| lazy_html | `0.1.0`, published 2025-04-04 | Test-time dependency required by Example LiveView tests | Keep this in the example app test stack for any new LiveView contract tests. [VERIFIED: codebase] [VERIFIED: npm registry] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| URL-driven LiveView forms and patching | Client-side SPA state | This would diverge from Sigra’s current admin idiom and lose the return-to/filter persistence that existing admin tests already enforce. [VERIFIED: codebase] [CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/server/live-navigation.md] |
| Flop-backed list normalization | Hand-rolled params parsing and pagination | Sigra already has a stable query contract using Flop; a second list stack would duplicate filtering and sorting semantics. [VERIFIED: codebase] |
| Library-owned webhook admin queries/actions | Generated host context logic and raw Repo queries in templates | That would violate D-99-20 and make every adopter reverse-engineer internals instead of consuming stable wrappers. [VERIFIED: context] [VERIFIED: codebase] |

**Installation:**
```bash
# No new dependency is required for Phase 99; reuse the existing admin stack.
mix deps.get
```

**Version verification:** Current project-lock versions were verified against `mix.lock`, and release timestamps were verified against the Hex package API for `phoenix`, `phoenix_live_view`, `ecto`, `flop`, `flop_phoenix`, and `lazy_html`. [VERIFIED: codebase] [VERIFIED: npm registry]

## Architecture Patterns

### System Architecture Diagram

```text
Admin operator
  -> Global admin route (/admin/webhooks, /admin/webhooks/:id, /admin/webhook-failures, /admin/webhook-deliveries/:id)
    -> Phoenix live_session + AdminScope mount
      -> Webhook LiveView handle_params/event handlers
        -> Sigra.Admin.Webhooks.Query / Detail / Failures / Actions
          -> Sigra.Webhooks library APIs + Ecto queries
            -> webhook_subscriptions (global registry)
            -> webhook_deliveries (summary rows)
            -> webhook_delivery_attempts (append-only attempt ledger)
            -> guides/recipes/webhook-verification.md links + generated host docs

Auth or identity mutation
  -> Sigra.Webhooks.Dispatcher
    -> webhook_events + webhook_deliveries persisted
      -> Oban webhook worker
        -> update delivery summary + append attempt rows
          -> Phase 99 admin views read persisted state only
```

### Recommended Project Structure
```text
lib/
├── sigra/admin/webhooks/          # library-owned admin queries, detail loaders, actions
├── sigra/admin/live/              # WebhookSubscriptionsIndex/Show, WebhookFailures, WebhookDeliveryShow LiveViews
└── sigra/install/features/        # generator injections, docs templates, wrapper additions

test/example/
├── lib/example_web/router.ex      # generated-host route mounts
├── lib/example_web/components/    # admin shell nav wiring
└── test/example_web/live/         # Example ExUnit LiveView contracts
```

### Pattern 1: URL-Driven Admin List LiveView
**What:** Use GET forms plus `handle_params/3` as the source of truth for filters, pagination, sort order, and open-row navigation. [VERIFIED: codebase] [CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/server/live-navigation.md]
**When to use:** Subscription index and failures inbox. [VERIFIED: context]
**Example:**
```elixir
# Source: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/server/live-navigation.md
def handle_params(params, _uri, socket) do
  {:noreply, load_rows(socket, params)}
end
```

### Pattern 2: Dedicated Detail Page For Operational Depth
**What:** Put secret reveal, rotate confirmation, setup checklist, and recent delivery history on a show page rather than the index. [VERIFIED: context] [VERIFIED: codebase]
**When to use:** Subscription detail and shared delivery detail. [VERIFIED: context]
**Example:**
```elixir
# Source: local pattern in Sigra.Admin.Live.UserShowLive
def handle_params(%{"id" => id} = params, _uri, socket) do
  detail = Detail.load!(socket.assigns.sigra_config, socket.assigns.admin_scope, id)
  {:noreply, assign(socket, :detail, detail)}
end
```

### Pattern 3: Summary-First, Ledger-Second Data Loading
**What:** Power list rows from `webhook_deliveries` current-state fields, then preload or separately query `webhook_delivery_attempts` only on drill-down. [VERIFIED: context] [VERIFIED: codebase]
**When to use:** Every list, inbox, and delivery detail path. [VERIFIED: context]
**Example:**
```elixir
# Source: https://hexdocs.pm/ecto/3.13.5/Ecto.Repo.html
delivery = Repo.preload(delivery, [attempts: from(a in Attempt, order_by: [desc: a.attempt_number])])
```

### Anti-Patterns to Avoid
- **Generated-host business logic for webhook operations:** Keep wrapper functions thin and move operational reads/mutations into Sigra library modules. [VERIFIED: context] [VERIFIED: codebase]
- **Attempt-ledger powered indexes:** Do not derive inbox rows by aggregating `webhook_delivery_attempts` on every page load when `webhook_deliveries` already stores summary state. [VERIFIED: context] [VERIFIED: codebase]
- **Org-scoped subscription UX without data support:** Do not imply organization-specific subscription ownership when the current subscription and delivery schemas are global. [VERIFIED: codebase]
- **Implicit or automatic secret exposure:** Do not render plaintext signing secrets on page load or tie reveal semantics to general page access. [VERIFIED: context]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| URL-state synchronization | Custom client JS store for filters/modals | LiveView `handle_params/3`, `push_patch/2`, and GET forms | Official LiveView navigation already covers this pattern and Sigra’s admin screens already rely on it. [CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/server/live-navigation.md] [VERIFIED: codebase] |
| Pagination/filter contract | New bespoke pagination structs | Flop schema + validation + meta pipeline | The user admin surface already standardizes this and the planner should keep one admin list contract. [VERIFIED: codebase] |
| Delivery-state explanation | Reading Oban job state or logs in UI | `webhook_deliveries` + `webhook_delivery_attempts` | Phase 98 explicitly shaped persistence so Phase 99 can explain state without queue internals. [VERIFIED: context] [VERIFIED: codebase] |
| Receiver verification guidance | Custom prose invented per screen | Existing webhook guides plus generated docs snippets | The verification recipe already locks raw-body, timestamp, and dedupe rules. [VERIFIED: codebase] [CITED: guides/recipes/webhook-verification.md] |

**Key insight:** The real implementation work is not drawing forms; it is defining stable library-owned webhook admin reads/actions so generated hosts never need to understand signing, retry semantics, or summary-versus-ledger state on their own. [VERIFIED: codebase] [VERIFIED: context]

## Common Pitfalls

### Pitfall 1: Treating webhook admin as organization-scoped when the data model is global
**What goes wrong:** The UI shows org-specific routes or filters that suggest ownership semantics the tables cannot enforce. [VERIFIED: codebase]
**Why it happens:** `webhook_events` has optional `organization_id`, but `webhook_subscriptions` and `webhook_deliveries` do not. [VERIFIED: codebase]
**How to avoid:** Plan the first cut as global subscription management, and only display organization context as delivery metadata where available. [VERIFIED: codebase] [VERIFIED: context]
**Warning signs:** Proposed routes include `/admin/organizations/:org/webhooks` with no corresponding subscription scope field or authorizer rule. [VERIFIED: codebase]

### Pitfall 2: Querying the attempt ledger for every list row
**What goes wrong:** Failure lists get expensive and drift away from the summary model Phase 98 already optimized. [VERIFIED: context]
**Why it happens:** Attempts feel richer, so planners reach for the append-only table first. [VERIFIED: context]
**How to avoid:** Keep list screens summary-row backed and reserve attempt queries for delivery detail pages. [VERIFIED: context] [VERIFIED: codebase]
**Warning signs:** A list query needs grouping or aggregation over `webhook_delivery_attempts` just to show current status. [VERIFIED: codebase]

### Pitfall 3: Letting generated templates own secret rotation semantics
**What goes wrong:** Reveal/rotate flows become inconsistent across example, golden fixture, and adopter apps, or secrets leak into logs and assigns. [VERIFIED: context]
**Why it happens:** The current generated host only has CRUD plus enable/disable wrappers, so it is tempting to implement rotation inline in templates or local context code. [VERIFIED: codebase]
**How to avoid:** Add explicit library-owned rotation/reveal actions and keep host wrappers as pass-through seams. [VERIFIED: codebase] [VERIFIED: context]
**Warning signs:** The plan proposes direct `Repo.update` calls on `signing_secret` inside generated host modules. [VERIFIED: codebase]

### Pitfall 4: Expanding product semantics through UX copy
**What goes wrong:** The UI implies replay, wildcard future events, dual-secret overlap, or synthetic ping support that the runtime does not implement. [VERIFIED: context] [VERIFIED: requirements]
**Why it happens:** Webhook products often expose those affordances, and Phase 99 is the first operator-facing UX. [VERIFIED: context]
**How to avoid:** Keep copy contractual and tie all setup proof to real Sigra events plus delivery history. [VERIFIED: context] [VERIFIED: codebase]
**Warning signs:** Buttons or helper text mention “Replay”, “Test event”, “All future events”, or “zero-downtime rotation”. [VERIFIED: context]

## Code Examples

Verified patterns from official sources:

### Preserve list context with LiveView URL params
```elixir
# Source: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/server/live-navigation.md
{:noreply, push_patch(socket, to: ~p"/admin/webhooks?page=#{page}")}
```

### Mount authenticated LiveView routes inside `live_session`
```elixir
# Source: https://github.com/phoenixframework/phoenix/blob/main/guides/authn_authz/scopes.md
live_session :admin_global,
  on_mount: [{MyAppWeb.UserAuth, :ensure_authenticated}] do
  live "/admin/webhooks", WebhookSubscriptionsIndexLive, :index
end
```

### Preload a filtered association for delivery detail
```elixir
# Source: https://hexdocs.pm/ecto/3.13.5/Ecto.Repo.html
Repo.preload(delivery, [attempts: from(a in Attempt, order_by: [desc: a.attempt_number])])
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CRUD-only subscription registry | Registry plus operator-facing summary and attempt-history persistence | Locked by Phases 97 and 98 on 2026-05-06. [VERIFIED: context] | Phase 99 can build UX on persisted state without queue internals. [VERIFIED: context] |
| One mutable delivery record | Summary row plus append-only attempt ledger | Locked by Phase 98 on 2026-05-06. [VERIFIED: context] | Lists stay cheap while detail remains forensic. [VERIFIED: context] |
| Controller or SPA assumptions for admin flows | Phoenix `live_session` plus URL-driven LiveView admin pages | Already established in current admin codebase. [VERIFIED: codebase] [CITED: https://github.com/phoenixframework/phoenix/blob/main/guides/authn_authz/scopes.md] | Phase 99 should follow existing tests, router seams, and shell chrome instead of inventing a new UI stack. [VERIFIED: codebase] |

**Deprecated/outdated:**
- Using Oban job state as the operator truth is outdated for this milestone because Phase 98 explicitly requires Sigra-owned summary plus attempt rows for Phase 99 admin UX. [VERIFIED: context] [VERIFIED: codebase]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The proposed quick-run command will be the right targeted ExUnit path once Phase 99 adds the recommended Example LiveView test file. | Validation Architecture | Low; the planner may need to rename the exact file path after module names are finalized. |
| A2 | The local full-suite phase-gate command should include generated-host Playwright parity in addition to root `mix test`. | Validation Architecture | Low; verification coverage could be narrower than intended if the command changes. |
| A3 | Per-wave merge and phase-gate sampling should include the generated-host Playwright parity lane. | Validation Architecture | Low; this affects verification completeness, not implementation architecture. |

## Resolved Questions

1. **Webhook route mounting**
   - Decision: mount Phase 99 webhook pages only in the existing global admin lane.
   - Rationale: subscriptions and deliveries are global rows today, while organization context appears only as event metadata. Adding `/admin/organizations/:org/webhooks` in this phase would imply unsupported ownership and authorization semantics. [VERIFIED: codebase] [VERIFIED: context]
   - Planning impact: generated router, shell, and tests should treat webhook management as a global operator surface and may show organization context only inside delivery details where the underlying event carries it.

2. **Reveal-secret policy**
   - Decision: allow an explicit reveal action for the current active secret on the subscription detail page, but never preload or list plaintext secrets and never imply that rotation is the only way to recover the value.
   - Rationale: D-99-12 explicitly allows reveal or copy from the detail page through intentional operator action, while D-99-13 separately constrains rotation to an immediate one-way replacement with no sender-side overlap guarantee. [VERIFIED: context] [VERIFIED: codebase]
   - Planning impact: library-owned actions may return the current decrypted secret only after an explicit detail-page action; list pages, default detail renders, logs, and generated wrappers must not expose plaintext by default.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | library/admin implementation, ExUnit | ✓ | `1.19.5` | — |
| Mix | build and test commands | ✓ | `1.19.5` | — |
| PostgreSQL server on localhost | root `mix test` and Example app tests | ✓ | port `5432` accepting connections; local `psql 14.17` client installed | none for full test suite |
| Node.js | Playwright lane | ✓ | `v22.14.0` | — |
| npm | Playwright install/run | ✓ | `11.1.0` | — |
| Docker | local disposable Postgres bootstrap | ✓ | `29.4.1` | existing local Postgres already works |

**Missing dependencies with no fallback:**
- None found. [VERIFIED: codebase]

**Missing dependencies with fallback:**
- None found. [VERIFIED: codebase]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit on Elixir `1.19.5` plus Example `Phoenix.LiveViewTest`; Playwright `@playwright/test ^1.48.0` for browser parity. [VERIFIED: codebase] |
| Config file | root: `test/test_helper.exs`; browser: `test/example/priv/playwright/playwright.config.ts`. [VERIFIED: codebase] |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs` [ASSUMED] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && cd test/example/priv/playwright && npx playwright test tests/admin-generated.spec.ts --project=admin-generated` [VERIFIED: codebase] [ASSUMED] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| WH-03 | subscription index is URL-driven, filterable, and preserves return-to context | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs` | ❌ Wave 0 |
| WH-03 | subscription detail shows setup guidance, intentional reveal/copy, and confirmed rotation copy | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs` | ❌ Wave 0 |
| WH-03 | failures inbox and shared delivery detail render summary-first and link to attempt history | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test test/example/test/example_web/live/admin_webhook_failures_live_test.exs test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs` | ❌ Wave 0 |
| WH-03 | generated-host router/nav parity exposes webhook pages without reverse-engineering | browser smoke | `cd test/example/priv/playwright && npx playwright test tests/admin-generated.spec.ts --project=admin-generated` | ⚠ existing spec, new assertions needed |

### Sampling Rate
- **Per task commit:** targeted ExUnit file for the touched LiveView/query/action plus any affected generator test. [VERIFIED: codebase]
- **Per wave merge:** all new webhook admin ExUnit files plus `tests/admin-generated.spec.ts --project=admin-generated`. [VERIFIED: codebase] [ASSUMED]
- **Phase gate:** root `mix test` green and generated-host Playwright parity green before `/gsd-verify-work`. [VERIFIED: codebase] [ASSUMED]

### Wave 0 Gaps
- [ ] `test/example/test/example_web/live/admin_webhook_subscriptions_index_live_test.exs` — URL-state, create/edit shell contract for WH-03. [VERIFIED: codebase]
- [ ] `test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs` — setup guidance, reveal/rotate confirmation, recent delivery history. [VERIFIED: codebase]
- [ ] `test/example/test/example_web/live/admin_webhook_failures_live_test.exs` — global retrying/dead-letter inbox. [VERIFIED: codebase]
- [ ] `test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs` — shared delivery detail and attempt timeline. [VERIFIED: codebase]
- [ ] `test/example/priv/playwright/tests/admin-generated.spec.ts` — add webhook nav/router assertions to the existing generated-host parity lane. [VERIFIED: codebase]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Keep webhook admin behind existing authenticated `live_session` plus `RequireAdminAccess` / `AdminScope` mounts. [VERIFIED: codebase] [CITED: https://github.com/phoenixframework/phoenix/blob/main/guides/authn_authz/scopes.md] |
| V3 Session Management | yes | Reuse existing authenticated admin shell and sudo/impersonation posture; do not introduce separate session semantics for webhook actions. [VERIFIED: codebase] |
| V4 Access Control | yes | Treat webhook admin as admin-only and do not fake organization scoping unsupported by the data model. [VERIFIED: codebase] [VERIFIED: context] |
| V5 Input Validation | yes | Keep endpoint URL and explicit `event_types` validation in `Sigra.Webhooks.subscription_changeset/3`. [VERIFIED: codebase] |
| V6 Cryptography | yes | Keep HMAC signing and verification semantics in `Sigra.Webhooks.Signature`; do not reimplement signature logic in generated UI or docs. [VERIFIED: codebase] [CITED: guides/recipes/webhook-verification.md] |

### Known Threat Patterns for Phoenix LiveView webhook admin

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Accidental secret disclosure in HTML, logs, or assigns | Information Disclosure | Reveal only on explicit action, keep plaintext out of default renders, and centralize reveal/rotate actions in the library boundary. [VERIFIED: context] [VERIFIED: codebase] |
| Unsupported org-route access that leaks global webhook state | Information Disclosure | Mount globally by default or make organization exposure an explicit new contract with authorization and data support. [VERIFIED: codebase] |
| CSRF or unauthorized mutation through admin actions | Tampering | Keep mutation flows inside authenticated Phoenix routes and standard LiveView/controller protections already used by admin surfaces. [VERIFIED: codebase] |
| Trusting decoded JSON instead of raw request bytes in guidance | Tampering | Generated docs and setup copy must point to `Plug.Parsers.body_reader` and raw-body verification. [VERIFIED: codebase] [CITED: guides/recipes/webhook-verification.md] |

## Sources

### Primary (HIGH confidence)
- `CLAUDE.md` - project constraints, local Postgres prerequisite, testing posture. [VERIFIED: codebase]
- `.planning/phases/99-admin-and-generated-host-webhook-ux/99-CONTEXT.md` - locked decisions for workflow, delivery history, secret UX, and docs emphasis. [VERIFIED: context]
- `.planning/phases/99-admin-and-generated-host-webhook-ux/99-UI-SPEC.md` - approved UI inventory and copy contract. [VERIFIED: context]
- `lib/sigra/admin/live/users_index_live.ex`, `user_show_live.ex`, `audit_index_live.ex`, `audit_user_live.ex` - current admin LiveView patterns. [VERIFIED: codebase]
- `lib/sigra/admin/users/query.ex`, `detail.ex` - canonical query/detail module structure. [VERIFIED: codebase]
- `lib/sigra/webhooks.ex`, `lib/sigra/webhooks/dispatcher.ex`, `lib/sigra/workers/webhook_delivery.ex`, `lib/sigra/webhooks/retry_policy.ex` - current webhook CRUD, persistence, retry, and failure taxonomy. [VERIFIED: codebase]
- `guides/flows/webhooks.md`, `guides/recipes/webhook-verification.md` - public webhook contract and receiver verification recipe. [VERIFIED: codebase]
- `test/example/lib/example_web/router.ex`, `components/admin_shell.ex`, install-golden equivalents - generated-host router/nav seams. [VERIFIED: codebase]
- Hex package API for `phoenix`, `phoenix_live_view`, `ecto`, `flop`, `flop_phoenix`, `lazy_html` - version and release-date verification. [VERIFIED: npm registry]

### Secondary (MEDIUM confidence)
- `https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/server/live-navigation.md` - `handle_params/3`, patch-driven URL state. [CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/server/live-navigation.md]
- `https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/client/form-bindings.md` - LiveView form event patterns. [CITED: https://github.com/phoenixframework/phoenix_live_view/blob/main/guides/client/form-bindings.md]
- `https://github.com/phoenixframework/phoenix/blob/main/guides/authn_authz/scopes.md` - authenticated `live_session` and scoped LiveView route guidance. [CITED: https://github.com/phoenixframework/phoenix/blob/main/guides/authn_authz/scopes.md]
- `https://hexdocs.pm/ecto/3.13.5/Ecto.Multi.html`, `https://hexdocs.pm/ecto/3.13.5/Ecto.Repo.html` - transaction and preload patterns. [CITED: https://hexdocs.pm/ecto/3.13.5/Ecto.Multi.html] [CITED: https://hexdocs.pm/ecto/3.13.5/Ecto.Repo.html]

### Tertiary (LOW confidence)
- None. [VERIFIED: codebase]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all recommended libraries are already in the repo and their versions were verified against `mix.lock` plus Hex package metadata. [VERIFIED: codebase] [VERIFIED: npm registry]
- Architecture: MEDIUM - the admin and webhook patterns are clear, but subscription scope for organization routes remains a real product-contract question. [VERIFIED: codebase] [VERIFIED: context]
- Pitfalls: HIGH - each pitfall is grounded in the current schemas, worker classifications, or locked phase decisions. [VERIFIED: codebase] [VERIFIED: context]

**Research date:** 2026-05-06
**Valid until:** 2026-06-05
