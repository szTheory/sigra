# Phase 99: Admin and generated-host webhook UX - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Turn the webhook system from Phases 97 and 98 into a usable adopter feature through generated admin LiveViews, routes, host wrappers, and setup guidance. This phase decides how operators create and manage subscriptions, how they inspect delivery health, how secret rotation/setup guidance is exposed, and how Sigra explains the host boundary. It does not change the webhook event contract, retry semantics, or signing model already locked in earlier phases.

**Explicitly in scope:**
- generated admin routes and LiveViews for webhook subscriptions
- generated host wrapper functions and navigation wiring
- delivery-history and failure inspection UX backed by Sigra-owned tables
- secret reveal/rotation UX within the already-locked single-active-secret contract
- adopter guidance that makes receiver ownership and verification expectations explicit

**Explicitly out of scope:**
- wildcard subscription semantics
- synthetic test-event or ping contract beyond real Sigra-owned events
- replay/redrive tooling
- overlapping sender-side dual-secret rotation windows
- public self-service webhook UI outside admin
- analytics-heavy dashboards or general-purpose event-bus tooling

</domain>

<decisions>
## Implementation Decisions

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

### the agent's Discretion
- Exact module names and route paths for webhook subscription/detail/history LiveViews
- Exact preset group names and event-group taxonomy, provided the saved state remains an explicit `event_types` list
- Exact copy and component treatment for reveal-secret, rotate-secret confirmation, and setup checklist cards
- Exact placement of the global failures/retrying inbox within the admin nav, provided it remains clearly secondary to subscription management
- Exact filters, pagination controls, and badge wording for delivery-history views, provided they stay URL-driven and summary-row-backed

</decisions>

<specifics>
## Specific Ideas

- Treat the webhook admin surface more like Stripe/GitHub endpoint management than like a generic CRUD table: create/edit quickly, then inspect and operate from a dedicated endpoint page.
- Use presets like "User lifecycle", "Sessions", "Organization membership", and "Service accounts" as accelerators, but always show the explicit resolved event list before save.
- Keep a clear "Failures / Retrying" operator path for triage, but do not turn the webhook UX into a dashboard-first product.
- Use real Sigra events for end-to-end proof; do not add a fake ping/test contract just to make the UI feel more SaaS-like.
- Keep inline guidance short:
  - Sigra sends signed auth events.
  - Your host app owns the receiver.
  - Verify against the raw body.
  - Dedupe by `delivery_id`.
  - Rotating the sender secret requires updating the receiver too.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone framing and requirements
- `.planning/PROJECT.md` — v1.22 milestone goals, DX/product-trust framing, and library-first/generator-aware intent
- `.planning/REQUIREMENTS.md` — `WH-03` requirement framing and out-of-scope boundaries
- `.planning/ROADMAP.md` — Phase 99 goal, success criteria, and dependency on Phases 97 and 98
- `.planning/STATE.md` — active milestone framing

### Prior webhook contract and reliability decisions
- `.planning/phases/97-webhook-subscription-registry-signed-dispatcher-contract/97-CONTEXT.md` — locked subscription/event/signature/dispatcher contract
- `.planning/phases/98-reliable-delivery-pipeline/98-CONTEXT.md` — locked retry, dead-letter, and attempt-history model
- `guides/flows/webhooks.md` — public webhook contract, async-only posture, and host-owned receiver boundary
- `guides/recipes/webhook-verification.md` — raw-body verification, dedupe, and timestamp/signature rules

### Webhook milestone research
- `.planning/research/SUMMARY.md` — milestone summary and watch-outs
- `.planning/research/ARCHITECTURE.md` — durable event/outbox-first architecture and build order
- `.planning/research/FEATURES.md` — table stakes and scoped admin UX expectations
- `.planning/research/PITFALLS.md` — failure modes and prevention strategy
- `.planning/research/STACK.md` — generated-host and async stack framing

### Existing admin and generated-host patterns
- `.planning/phases/27-admin-access-foundation/27-CONTEXT.md` — admin shell, scope, and ownership model
- `.planning/phases/28-user-operations-surface/28-CONTEXT.md` — list/detail, URL-driven filters, and operator-first admin posture
- `.planning/phases/33-admin-shell-navigation-and-audit-preview-polish/33-CONTEXT.md` — generated-host admin shell parity and route-driven UX expectations
- `lib/sigra/admin/live/users_index_live.ex` — current admin list/filter idiom
- `lib/sigra/admin/live/user_show_live.ex` — current entity detail idiom
- `lib/sigra/admin/live/audit_index_live.ex` — current scoped explorer/filter idiom
- `lib/sigra/admin/live/audit_user_live.ex` — current detail-to-explorer flow
- `lib/sigra/admin/users/query.ex` — URL-driven query/filter architecture for admin lists
- `lib/sigra/admin/users/detail.ex` — current detail loading and summary/detail split
- `test/example/lib/example_web/components/admin_shell.ex` — example host admin shell/navigation pattern
- `test/example/lib/example_web/router.ex` — example global/org admin route structure
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/components/admin_shell.ex` — generated-host shell parity
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/router.ex` — generated-host admin route structure

### Existing webhook and generated wrapper surfaces
- `lib/sigra/webhooks.ex` — public webhook API, event catalog, config helpers, and delivery helpers
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex` — generated host webhook wrapper functions and runtime config seam
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_subscription.ex` — subscription schema shape
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery.ex` — delivery summary row shape
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/webhook_delivery_attempt.ex` — append-only attempt ledger shape
- `lib/sigra/install/features/admin.ex` — admin feature generation and host-owned boundary files

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Admin.Live.UsersIndexLive` and `Sigra.Admin.Users.Query` already provide the strongest local pattern for URL-driven admin lists with filters, summary chips, and list-to-detail navigation.
- `Sigra.Admin.Live.UserShowLive` provides the current entity-detail pattern for placing higher-risk actions and richer operational context on dedicated pages.
- `Sigra.Admin.Live.AuditIndexLive` and `AuditUserLive` show how Sigra already handles scoped operational inspection views without inventing dashboards.
- Generated host wrappers in `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts.ex` already expose a clean seam for webhook subscription CRUD that Phase 99 can extend rather than replace.
- Generated admin shell/router files in the example app and install golden fixture already give Phase 99 a consistent place to mount webhook surfaces.

### Established Patterns
- Sigra prefers list/detail LiveView flows with explicit actions over wizard-heavy UI.
- Generated hosts own thin routing, shell, and wrapper seams; long-lived security/runtime behavior remains library-owned.
- Operational inspection should come from Sigra-owned persisted tables, not queue internals or log scraping.
- Configuration and feature boundaries should stay explicit and unsurprising.

### Integration Points
- Add webhook subscription routes and nav alongside the existing admin users/audit surfaces rather than inventing a separate admin namespace.
- Extend the generated accounts context with any additional read helpers needed for subscription detail/history views while preserving the existing thin-wrapper pattern.
- Build delivery-history queries against `webhook_deliveries` first, then load `webhook_delivery_attempts` for drill-down detail.
- Cross-link setup guidance from the webhook UI to `guides/recipes/webhook-verification.md` and any generated host-specific docs.

</code_context>

<deferred>
## Deferred Ideas

- Sender-side overlapping dual-secret rotation windows and true zero-downtime rotation semantics (`WH-04`)
- Synthetic ping/test-event contract or setup wizard that implies new webhook semantics
- Replay/redrive tooling from UI or CLI (`WH-05`)
- Public/self-service subscription UI outside admin
- Analytics-heavy dashboards, tenant-wide webhook observability, or event-bus-style abstractions
- Endpoint policy / egress controls beyond the current milestone (`WH-06`)

</deferred>

---

*Phase: 99-admin-and-generated-host-webhook-ux*
*Context gathered: 2026-05-06*
