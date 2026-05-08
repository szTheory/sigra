# Phase 97: Webhook subscription registry + signed dispatcher contract - Context

**Gathered:** 2026-05-06
**Status:** Ready for planning

<domain>
## Phase Boundary

Define Sigra's public outbound webhook contract and durable subscription model so Sigra-owned auth and identity events can be emitted as a trustworthy machine-to-machine integration surface. This phase locks the event catalog, public payload shape, subscription registry semantics, signature verification contract, and the library-owned persisted dispatcher seam. Reliable retries, dead-letter handling, and delivery-history UX belong to Phases 98 and 99.

**Explicitly out of scope:**
- Inbound webhook consumers for third-party systems
- A wildcard-by-default subscription model that silently expands when new events are added
- Raw audit-row mirroring as the public webhook contract
- Synchronous remote delivery on the auth request path
- Replay tooling, dead-letter replay UX, or broad secret-overlap rotation windows
- A general-purpose pluggable event bus for arbitrary host-domain events

</domain>

<decisions>
## Implementation Decisions

### Event catalog
- **D-97-01 — Curated public catalog, not audit-stream mirroring.** Sigra should expose a small, resource-oriented auth/identity event catalog with stable public names and serializers. Do not expose internal audit actions, changeset shapes, or low-level auth flow branches as webhook events.
- **D-97-02 — Day-one event families stay factual and adoption-oriented.** The initial catalog should cover durable identity and access facts rather than noisy security telemetry: user lifecycle (`user.created`, `user.updated`, `user.deleted`), session lifecycle (`session.created`, `session.revoked`), org access lifecycle where already public in Sigra (`organization_membership.created`, `organization_membership.updated`, `organization_membership.deleted` or equivalent role/revocation events), and machine identity lifecycle (`service_account.created`, `service_account.revoked`). Password-reset requests, failed logins, MFA attempts, rate limits, and other high-noise/internal-security signals are deferred.
- **D-97-03 — Public webhook naming must follow domain nouns, not internal implementation verbs.** Event types should read like public facts about durable resources and transitions, not like audit implementation names or controller/action internals.

### Payload contract
- **D-97-04 — Stable envelope plus public object snapshot.** Each webhook payload uses a stable domain envelope containing `id`, `type`, `schema_version`, `occurred_at`, and `data.object`. The object payload is a public snapshot serializer, not a fetch-later pointer and not a dump of Ecto structs or audit metadata.
- **D-97-05 — Context objects are included when known and public.** Payloads should include `context.actor` (`type` + stable id), `context.organization` for org-scoped events, and `context.request.id` when available. Request IP/user-agent are not globally included; reserve that kind of data for future security-specific events if those ever become public contract.
- **D-97-06 — Update events may include narrow change hints only.** For `*.updated` events, Sigra may include a `changes` list of public field names when useful, but must not include previous values, internal diff structs, or sensitive field deltas. This preserves receiver ergonomics without turning the contract into an audit-log clone.
- **D-97-07 — Serializer boundary is mandatory.** Webhook payload structs must be modeled as explicit external contracts, separate from audit schemas and raw Ecto models, so internal schema churn does not become public webhook churn.

### Signature and verification contract
- **D-97-08 — Use a versioned signed-envelope contract with explicit id and timestamp headers.** Each delivery includes `Sigra-Webhook-Id`, `Sigra-Webhook-Timestamp`, and `Sigra-Webhook-Signature`. The signature is HMAC-SHA256 over `delivery_id.timestamp.raw_body`, where `raw_body` is the exact bytes sent on the wire.
- **D-97-09 — Signature format must support evolution and rotation.** `Sigra-Webhook-Signature` uses a versioned format (`v1=...`) and permits multiple `v1` values during secret rotation windows. Verification docs must define raw-body handling, UTF-8/encoding expectations, and duplicate-signature semantics explicitly.
- **D-97-10 — Replay awareness is part of the contract, not an afterthought.** The default timestamp tolerance is 300 seconds, configurable within reasonable bounds. Stable delivery ids are required so receivers can dedupe retries even when timestamps remain valid.
- **D-97-11 — Receiver ergonomics are first-class.** Sigra must document Plug/Phoenix verification using `Plug.Parsers` `:body_reader` and constant-time digest comparison. Missing headers, malformed signatures, stale timestamps, and digest mismatches should be distinguishable in docs/tests even if user-facing receivers choose simpler handling.

### Subscription model
- **D-97-12 — Store explicit event lists, not wildcard semantics.** Subscription records persist a concrete `event_types` list. Sigra must not treat subscriptions as "all current and future events" at the storage layer.
- **D-97-13 — Generated admin UX may offer fast presets, but presets expand to concrete lists.** The create/edit UX should offer presets like "all current auth events" or domain groupings, but the saved subscription still stores an explicit event list snapshot. This avoids surprise deliveries when the catalog grows.
- **D-97-14 — `enabled` means deliver or do not deliver.** Subscriptions are durably enabled/disabled rather than deleted for routine operational control. Endpoint URL, secret, enabled state, and event scope are core persisted fields in Phase 97.
- **D-97-15 — Endpoint policy is strict by default.** Production subscriptions require HTTPS endpoints. Narrow localhost/dev exceptions are allowed for development and test ergonomics, but not as the production default.
- **D-97-16 — Secret rotation overlap windows are not part of the Phase 97 contract.** The model should support rotation later, but the initial contract assumes one active signing secret per subscription. Overlap/replay-safe rollover belongs to the later `WH-04` follow-on.

### Dispatcher seam
- **D-97-17 — Persisted event and delivery rows are part of the Phase 97 seam.** The auth-domain transaction must atomically persist the business mutation, a stable public webhook event row, and per-subscription pending delivery rows before any remote HTTP attempt is made.
- **D-97-18 — The dispatcher is library-owned and async-only for webhook transport.** Sigra owns the signing and delivery seam. Do not expose a broad host-pluggable dispatcher behaviour in v1.22 and do not permit synchronous best-effort HTTP as an alternative success path.
- **D-97-19 — Delivery ids and event ids are distinct and both stable.** One webhook event may fan out to multiple deliveries. `event_id` identifies the public event contract; `delivery_id` identifies a concrete attempt lineage for a subscription and is what gets signed and surfaced to receivers.
- **D-97-20 — Optional dependency behavior is strict and operationally honest.** Webhooks disabled means no Oban requirement. Webhooks enabled means persisted async dispatch is mandatory and Oban must be configured and doctor-checkable. Do not mirror email delivery's `:auto` sync fallback for webhooks.
- **D-97-21 — Retry/history semantics build on the same persisted model in Phase 98.** Phase 97 should create the durable state model that Phase 98 extends for bounded retries, dead-letter handling, and attempt history, rather than introducing a separate pipeline later.

### User preference carried forward
- **D-97-22 — When the user delegates architecture/product tradeoffs, downstream GSD work should default to decisive researched recommendations.** Only escalate choices that materially change the security model, public/semver contract, or generated-host contract. Implementation-level forks should be resolved by the agent without reopening broad decision loops.

### the agent's Discretion
- Exact serializer module names, typed struct vs `embedded_schema` implementation details, and queue names
- Exact public field lists inside each object snapshot, as long as they stay within the stable public contract above
- Exact Ecto enum / schema field names for `event_types`, delivery status, and dispatcher state
- HTTP client selection and per-queue concurrency defaults
- Whether membership event names use `organization_membership.*` or the closest already-public Sigra noun, provided the naming remains resource-oriented and stable

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone framing and requirements
- `.planning/PROJECT.md` — v1.22 milestone goal, DX/product-trust framing, and library-first/generator-aware intent
- `.planning/REQUIREMENTS.md` — `WH-01..03` requirement framing and explicit out-of-scope list
- `.planning/ROADMAP.md` — Phase 97 goal and success criteria; dependency relationship to Phases 98 and 99
- `.planning/STATE.md` — current milestone handoff and active-phase framing

### Webhook research
- `.planning/research/SUMMARY.md` — webhook milestone summary and top-level cautions
- `.planning/research/ARCHITECTURE.md` — recommended durable event/outbox-first architecture and delivery separation
- `.planning/research/FEATURES.md` — table stakes and useful v1.22 scope boundaries
- `.planning/research/PITFALLS.md` — main webhook failure modes and prevention strategy
- `.planning/research/STACK.md` — stack additions and async/Oban implications for the feature

### Prior phase context that constrains this phase
- `.planning/AUDIT-ATOMICITY-DEFAULTS.md` — transaction and co-fated write defaults relevant to persisted event/delivery state
- `.planning/phases/91-org-level-mfa-enforcement-b2b-01/91-CONTEXT.md` — atomic-audit and org-scope precedents that webhook event production should not violate
- `.planning/phases/92-rbac-seams-b2b-02/92-VERIFICATION.md` — actor/role seam framing that affects webhook actor context
- `.planning/phases/93-m2m-service-account-tokens-b2b-03/93-CONTEXT.md` — service-account public seam, org scope, and existing event-worthy machine identity lifecycle

### Existing code and config patterns
- `lib/sigra/delivery.ex` — current async-vs-sync delivery seam; useful contrast because webhooks should be stricter than email
- `lib/sigra/config.ex` — existing NimbleOptions patterns for feature configuration and optional seams
- `lib/sigra/optional_deps.ex` — dependency-enforcement and doctor-facing optional-dependency behavior
- `lib/sigra/telemetry.ex` — existing public event catalog style and logging expectations; useful as source material, not as the webhook contract itself
- `lib/sigra/token.ex` — signing/comparison primitives and existing HMAC-minded patterns

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Delivery` — existing async-delivery abstraction and Oban integration pattern; useful as a contrast and for queue/job ergonomics, but webhook transport should not inherit sync fallback behavior
- `Sigra.Config` — established NimbleOptions configuration surface for new webhook config keys and docs
- `Sigra.OptionalDeps` — existing dependency gating and doctor integration pattern for Oban-backed features
- `Sigra.Telemetry` — existing event-catalog documentation discipline and emitted-event naming conventions
- `Sigra.Token` plus `Plug.Crypto.secure_compare/2` usage — existing security primitives and verification style that can inform receiver docs/tests

### Established Patterns
- Durable local state before side effects is already a project value via audit atomicity and service-account issuance work
- Sigra favors explicit generated-host seams over "wire it yourself" integration burdens
- Optional dependency behavior is expected to be explicit, validated, and honest rather than magical

### Integration Points
- New webhook config should plug into `Sigra.Config` and `Sigra.OptionalDeps`
- Persisted webhook event/delivery rows should follow the same `Repo.transact/2` / `Ecto.Multi` discipline as other co-fated writes
- Generated admin and host surfaces in Phase 99 will depend on whatever subscription/event/delivery schema Phase 97 locks now

</code_context>

<specifics>
## Specific Ideas

- Use a Svix-like signed envelope adapted to Sigra: explicit id and timestamp headers plus versioned HMAC signature
- Keep webhook payloads self-contained enough that generated Phoenix hosts do not need an extra authenticated fetch API just to use the feature
- Treat webhooks as systems integration, not human notification and not internal audit export
- Default to decisive recommendations in delegated design discussions; only reopen genuinely contract-defining forks

</specifics>

<deferred>
## Deferred Ideas

### Reviewed Todos (not folded)
- 2026-04-30 JOSE warning install-smoke todo — unrelated hardening work; left out of webhook milestone scope
- 2026-04-30 Postgres `too_many_connections` install-smoke todo — CI/adopter hardening, not part of webhook contract definition

### Future webhook follow-ons
- Replay tooling and manual resend UX — Phase 99 or later follow-on
- Secret rotation overlap windows / dual-secret rollover semantics — `WH-04`
- Broad security-signal webhooks (failed login, MFA failures, rate limits, suspicious login) — later phase only if public semantics and privacy posture are worth the contract cost
- Generalized host-defined/custom-domain event publishing — separate future capability, not v1.22 core

</deferred>

---

*Phase: 97-webhook-subscription-registry-signed-dispatcher-contract*
*Context gathered: 2026-05-06*
