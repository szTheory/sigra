# Phase 103: Overlap-safe webhook secret rotation - Research

**Researched:** 2026-05-07
**Domain:** Outbound webhook signing-secret rotation for Sigra's Phoenix/Ecto/Oban webhook pipeline
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
## Implementation Decisions

### Rotation lifecycle
- **D-103-01 — Use an explicit dual-slot subscription lifecycle, not a normalized secrets subsystem.** Each subscription should hold the currently active signing secret plus one staged next secret and explicit lifecycle metadata for the overlap window. Do not introduce a separate `webhook_subscription_secrets` table in this phase.
- **D-103-02 — Rotation state must be explicit and operator-readable.** The subscription model should distinguish at least `stable`, `prepared`, and `overlap_active` states rather than inferring rotation from nullable timestamps alone.
- **D-103-03 — Keep lifecycle truth queryable on the subscription record.** The subscription should persist non-secret lifecycle metadata such as state, who initiated the latest transition, when overlap started, and when the old secret becomes eligible for retirement. This should be readable in admin/detail surfaces without reconstructing state from attempt history.
- **D-103-04 — Keep the secret model bounded to “current + next.”** Phase 103 should optimize for one active secret and one staged replacement. Do not generalize into arbitrary concurrent secret versions or a keyring product.

### Sender behavior during overlap
- **D-103-05 — Dual-sign every delivery attempt during the active overlap window.** While overlap is active, Sigra should sign each outbound webhook attempt with both the current and next secret and include both `v1=...` values in `Sigra-Webhook-Signature`.
- **D-103-06 — Use one shared timestamp per attempt across all overlap signatures.** A given delivery attempt should still produce one `Sigra-Webhook-Timestamp`, one `delivery_id`, and multiple signatures over the same canonical string rather than emitting per-secret timestamps.
- **D-103-07 — Pre-overlap and post-retirement stay single-secret.** Before overlap begins, only the current secret signs deliveries. After the operator completes rotation and the old secret is retired, only the next secret signs deliveries.
- **D-103-08 — Do not pin a delivery lineage to one secret version.** Retries that occur during overlap should remain verifiable via all currently active overlap secrets rather than forcing a delivery to stick to the secret that signed its first attempt.

### Verification and replay contract
- **D-103-09 — Replay protection remains keyed strictly to `delivery_id`.** Temporary multi-secret validity must not change the dedupe contract. Receivers should continue treating `delivery_id` as the sole logical delivery key, including across retries and overlap.
- **D-103-10 — Do not add a public key-identifier header in Phase 103.** Sigra should not introduce `kid`-style public metadata or other secret-selection headers. Receivers should verify against candidate secrets and succeed when any valid signature matches.
- **D-103-11 — Multi-secret verification is receiver-local and env-driven.** Generated guidance should default to a receiver holding `current` and `previous` secrets locally and calling `Sigra.Webhooks.Signature.verify/4` with a candidate-secret list. Verification must not depend on a signed hint from the sender to choose the secret.
- **D-103-12 — Timestamp tolerance behavior stays unchanged.** Overlap support must not widen or weaken the existing freshness rules. Stale timestamps remain invalid even if one of the secret digests matches.
- **D-103-13 — Generated-host proof code must not become the public verification contract.** The current example-host trick of resolving a sender-owned secret through delivery context is acceptable only as proof scaffolding. The documented adopter contract remains raw-body verification against receiver-owned secrets.

### Operator workflow and admin UX
- **D-103-14 — Use an explicit three-step operator flow: prepare, start overlap, complete rotation.** Sigra should not treat secret rotation as a one-click replace anymore. The recommended admin flow is:
  - prepare a new secret
  - start overlap after the receiver is ready to accept both secrets
  - complete rotation after a real overlap-window delivery verifies successfully
- **D-103-15 — Keep lifecycle transitions operator-driven, not timer-driven.** Phase 103 should avoid background schedulers, auto-cutover, and auto-retirement jobs. Explicit operator actions are less surprising, easier to prove, and better aligned with Sigra’s current admin idioms.
- **D-103-16 — The admin surface should tell the truth about state and required next step.** Subscription detail UX should show the current lifecycle state, what Sigra is signing with right now, what the receiver is expected to do next, and whether the old secret has been retired.
- **D-103-17 — Rotation is not considered safe until a real post-change delivery proves it.** UX and docs should explicitly require at least one real overlap-window delivery and one post-retirement delivery to validate the path. Do not imply that clicking “rotate” or “complete” alone is sufficient proof.

### Proof and verification depth
- **D-103-18 — Phase 103 must prove the full lifecycle end to end.** Verification for this phase should include:
  - a successful pre-rotation delivery
  - a successful overlap-window delivery signed with both secrets
  - a successful post-retirement delivery signed only with the new secret
  - receiver dedupe and history still keyed by `delivery_id`
- **D-103-19 — Proof should correlate operator and receiver evidence on `delivery_id`.** Admin history, receiver receipts, and any artifact bundles should all correlate using the stable delivery identifier rather than inferred time windows.

### User preference carried forward
- **D-103-20 — Shift routine product and architecture decisions left within GSD.** Downstream research, planning, and execution should prefer decisive recommendations that preserve production honesty, least surprise, and strong developer ergonomics. Escalate decisions only when they materially change the security model, public webhook contract, semver surface, generated-host contract, or another similarly high-impact boundary.

### the agent's Discretion
- Exact schema field names for the current/next secret slots and lifecycle metadata
- Whether overlap lifecycle state is modeled as a string enum, atom-backed enum, or equivalent explicit state representation
- Exact admin copy, badge names, and detail-page layout, as long as state and next-step truth remain explicit
- Exact proof artifact format and test decomposition across library, generated-host, and browser/integration lanes
- Whether non-secret secret metadata is represented as fingerprints, masked summaries, or equivalent operator-safe identifiers

### Deferred Ideas (OUT OF SCOPE)
## Deferred Ideas

- Generalized secret-history timeline or normalized secret-version tables
- Scheduler-driven cutover or auto-retirement
- KMS/HSM-backed secret-management abstractions
- Public key-identifier (`kid`) or secret-selection headers
- Replay/redrive controls and manual resend flows — Phase 104
- Broader endpoint health or auto-disable policy changes
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|---|---|---|
| WH-04 | Adopter can rotate a webhook signing secret with an overlap window, complete the cutover without delivery loss, and retire the old secret without reopening replay risk. | Dual-slot subscription schema, explicit lifecycle transitions, overlap dual-sign sender behavior, unchanged `delivery_id` dedupe contract, updated receiver docs, and full pre/overlap/post proof lanes. [VERIFIED: .planning/REQUIREMENTS.md] |
</phase_requirements>

## Summary

The current Sigra webhook stack already has the right cryptographic and replay primitives for overlap-safe rotation, but it lacks the subscription lifecycle and sender behavior to use them safely. `Sigra.Webhooks.Signature.verify/4` already accepts a list of candidate secrets and already parses multiple `v1=` signatures, while replay protection is already modeled around stable `delivery_id` values across retries. The gap is that the subscription model still stores only one `signing_secret`, `rotate_secret/2` immediately replaces it, the worker signs with only one secret, and the published docs still tell adopters to update the receiver immediately because sender-side overlap does not exist yet. [VERIFIED: lib/sigra/webhooks/signature.ex] [VERIFIED: lib/sigra/webhooks.ex] [VERIFIED: lib/sigra/workers/webhook_delivery.ex] [VERIFIED: guides/flows/webhooks.md] [VERIFIED: guides/recipes/webhook-verification.md]

The implementation should stay bounded to one active secret plus one staged replacement on the subscription row, with an explicit lifecycle enum and overlap metadata on the same record. That matches the locked Phase 103 decisions, preserves Sigra's existing preference for subscription-owned truth, avoids a new normalized secrets subsystem, and lets the worker keep loading state at execution time so retries during overlap automatically dual-sign with the currently valid pair. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md] [VERIFIED: lib/sigra/workers/webhook_delivery.ex] [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html] [CITED: https://docs.stripe.com/webhooks?lang=node] [CITED: https://www.svix.com/blog/zero-downtime-secret-rotation-webhooks/]

The public receiver contract should remain boring: raw-body verification, one timestamp tolerance policy, candidate-secret verification from receiver-local config, and dedupe keyed only by `delivery_id`. The example host may keep its proof-only delivery-context lookup as scaffolding, but docs and generated templates must switch to a two-secret receiver checklist and the phase proof must show pre-rotation, overlap, and post-retirement deliveries correlated by one stable `delivery_id` lineage model. [VERIFIED: test/example/lib/example_web/controllers/sigra_webhook_controller.ex] [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: .planning/phases/102-generated-host-proof-and-planning-reconciliation/102-CONTEXT.md] [CITED: https://docs.github.com/en/webhooks/using-webhooks/automatically-redelivering-failed-deliveries-for-a-repository-webhook] [CITED: https://docs.github.com/en/enterprise-cloud@latest/webhooks/testing-and-troubleshooting-webhooks/redelivering-webhooks]

**Primary recommendation:** Keep `signing_secret` as the active slot, add one encrypted `next_signing_secret` plus explicit rotation-state metadata on `webhook_subscriptions`, dual-sign only in `overlap_active`, and update receiver docs/tests to verify against `[current, previous]` secrets while keeping replay protection strictly on `delivery_id`. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md] [VERIFIED: lib/sigra/webhooks/signature.ex] [VERIFIED: lib/sigra/workers/webhook_delivery.ex]

## Project Constraints (from CLAUDE.md)

- Phoenix `1.8+` and Ecto `3.x` are the blessed path; recommendations should preserve Phoenix/Ecto integration first. [VERIFIED: CLAUDE.md]
- PostgreSQL is the primary database, with conditional support for MySQL/SQLite in generated migrations; phase design should stay portable unless PostgreSQL-specific behavior is isolated. [VERIFIED: CLAUDE.md]
- Security-sensitive code belongs in the library, while generated host code should stay thin and customizable. [VERIFIED: CLAUDE.md]
- Dependencies should stay minimal; small stable behavior should be preferred over introducing a new dependency. [VERIFIED: CLAUDE.md]
- Testing should cover happy path, main error cases, and boundary conditions with self-contained specs. [VERIFIED: CLAUDE.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Secret-slot persistence and lifecycle transitions | Database / Storage | API / Backend | Rotation truth must live on `webhook_subscriptions`, not in worker memory or UI state. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md] |
| Sender signing mode selection | API / Backend | Database / Storage | `Sigra.Workers.WebhookDelivery` decides how to sign by loading subscription state at execution time. [VERIFIED: lib/sigra/workers/webhook_delivery.ex] |
| Receiver signature verification and dedupe | API / Backend | Database / Storage | Verification happens on the receiver endpoint against raw request bytes and dedupe persists by `delivery_id`. [VERIFIED: guides/recipes/webhook-verification.md] [VERIFIED: test/example/lib/example/accounts/webhook_receipt.ex] |
| Operator workflow and status truth | Frontend Server (SSR) | API / Backend | LiveView detail surfaces read subscription lifecycle truth and trigger explicit admin actions. [VERIFIED: lib/sigra/admin/live/webhook_subscription_show_live.ex] [VERIFIED: lib/sigra/admin/webhooks/actions.ex] |
| Proof artifact correlation | API / Backend | Frontend Server (SSR) | Durable delivery rows and receiver receipts provide the truth, while Playwright proves the operator surface around them. [VERIFIED: test/example/lib/example/accounts.ex] [VERIFIED: test/example/priv/playwright/tests/admin-generated.spec.ts] |

## Current Baseline And Exact Constraints

### Current implementation baseline

| Area | Current behavior | Constraint this creates |
|---|---|---|
| Subscription schema | Example and install templates store only `signing_secret`; no `next` slot or lifecycle metadata exists. [VERIFIED: test/example/lib/example/accounts/webhook_subscription.ex] [VERIFIED: priv/templates/sigra.install/core/webhook_subscription.ex] | Phase 103 requires a schema migration and generated-schema/template changes before overlap can exist. |
| Rotation action | `Sigra.Webhooks.rotate_secret/2` immediately replaces `signing_secret` with a new generated value. [VERIFIED: lib/sigra/webhooks.ex] | Current behavior creates a cutover race and must be superseded, not wrapped. |
| Sender worker | `Sigra.Workers.WebhookDelivery.build_request/3` reads one `subscription.signing_secret` and calls `Signature.headers/4` once. [VERIFIED: lib/sigra/workers/webhook_delivery.ex] | Dual-sign overlap needs worker-level signing changes; delivery rows do not currently snapshot a secret version. |
| Verifier | `Signature.verify/4` already accepts one secret or a list of secrets and already accepts multiple comma-separated `v1=` values. [VERIFIED: lib/sigra/webhooks/signature.ex] [VERIFIED: test/sigra/webhooks_signature_test.exs] | Receiver cryptography does not need a new API surface; docs and sender behavior need to catch up. |
| Replay model | Delivery retries keep the same `delivery_id`, get a fresh timestamp per attempt, and receiver dedupe is documented on `delivery_id`. [VERIFIED: .planning/phases/98-reliable-delivery-pipeline/98-CONTEXT.md] [VERIFIED: guides/recipes/webhook-verification.md] | Rotation must not introduce secret-version dedupe or per-secret replay keys. |
| Example proof receiver | The example controller resolves the secret by loading the sender-owned subscription via `delivery_id`. [VERIFIED: test/example/lib/example_web/controllers/sigra_webhook_controller.ex] | This is acceptable proof scaffolding only; docs must not promote it as the public adopter contract. |
| Admin UX | The detail page still exposes one destructive `Rotate secret` flow and explicitly warns that overlap is unavailable in `v1.22`. [VERIFIED: lib/sigra/admin/live/webhook_subscription_show_live.ex] [VERIFIED: test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs] | Phase 103 must intentionally replace copy, state badges, and actions. |
| Published docs | Both product docs and generated receiver setup still instruct adopters to update the receiver immediately because sender-side overlap does not exist. [VERIFIED: guides/flows/webhooks.md] [VERIFIED: guides/recipes/webhook-verification.md] [VERIFIED: priv/templates/sigra.install/admin/webhook_receiver_setup.md] | Docs and generated host templates are part of the implementation surface, not cleanup. |

### External contract constraints

- Stripe documents delayed webhook-secret expiration for up to 24 hours and states that multiple secrets are active during that time, with one signature generated per active secret. Sigra's locked dual-sign overlap model is consistent with a mainstream production pattern. [CITED: https://docs.stripe.com/webhooks?lang=node]
- Svix's official rotation guidance recommends signing the same webhook with both the old and new key during a rotation window and treating verification as success when any signature matches. This directly supports the locked `D-103-05` and `D-103-10` decisions. [CITED: https://www.svix.com/blog/zero-downtime-secret-rotation-webhooks/]
- GitHub's webhook docs keep redelivery truth anchored to a stable delivery GUID across redeliveries. That reinforces keeping Sigra replay and proof correlation keyed to `delivery_id`, not to a secret version. [CITED: https://docs.github.com/en/webhooks/using-webhooks/automatically-redelivering-failed-deliveries-for-a-repository-webhook]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---|---|---|---|
| Phoenix | `1.8.5` | Admin LiveView and generated host web surface. [VERIFIED: mix.lock] | Existing webhook admin/detail flows already live in Phoenix LiveView; Phase 103 extends them rather than adding another UI tier. |
| Phoenix LiveView | `1.1.28` | Subscription detail lifecycle UI. [VERIFIED: mix.lock] | Current webhook operator surfaces are already LiveViews, so new rotation state belongs there. |
| Ecto / Ecto SQL | `3.13.5` | Schema migration, changesets, and transactional updates. [VERIFIED: mix.lock] | Phase 103 is primarily a subscription-schema and transition-transaction change. |
| Ecto.Enum | `3.13.x` feature in Ecto | Explicit persisted lifecycle enum. [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html] | It safely maps atoms to stored strings or integers and fits operator-readable lifecycle states. |
| Oban | `2.21.1` | Single-shot worker execution for persisted deliveries. [VERIFIED: mix.lock] | Worker remains the place where overlap signing is enforced at send time. |
| Jason | `1.4.4` | Raw JSON payload encoding for delivery attempts and proof receipts. [VERIFIED: mix.lock] | Existing webhook sender and example receiver already depend on raw JSON body handling. |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|---|---|---|---|
| Cloak Ecto | `1.3.0` | Encrypted secret fields in generated host schemas. [VERIFIED: mix.lock] | Keep both active and next secret slots encrypted at rest. |
| Flop / Flop Phoenix | `0.26.3` / `0.26.0` | Admin list/detail query plumbing. [VERIFIED: mix.lock] | Useful only if Phase 103 extends list filters or badges beyond the detail view. |
| Playwright | `@playwright/test ^1.48.0` | Generated-host browser proof lane. [VERIFIED: test/example/priv/playwright/package.json] | Required for the end-to-end operator proof path. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Dual-slot columns on `webhook_subscriptions` | Normalized `webhook_subscription_secrets` table | Rejected by locked decision `D-103-01`; adds key-history product surface that Phase 103 explicitly excludes. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md] |
| `Ecto.Enum` lifecycle state | Free-form string field | Free-form strings weaken validation and make generated-host state handling easier to drift. [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html] |
| Receiver-local candidate-secret verification | Public `kid` header | Rejected by locked decision `D-103-10`; signed secret hints add public contract complexity without solving the overlap problem better. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md] |

**Installation:**
```bash
mix deps.get
cd test/example && mix deps.get
cd test/example/priv/playwright && npm ci
```

**Version verification:** Core library versions above were verified against `mix.lock`, `mix.exs`, and `test/example/priv/playwright/package.json` in this repo rather than inferred from training data. [VERIFIED: mix.lock] [VERIFIED: mix.exs] [VERIFIED: test/example/priv/playwright/package.json]

## Architecture Patterns

### System Architecture Diagram

```text
Admin prepares next secret
  -> webhook_subscriptions.next_signing_secret written
  -> rotation_state = prepared
  -> sender still signs with signing_secret only

Admin starts overlap
  -> webhook_subscriptions.rotation_state = overlap_active
  -> overlap_started_at + retire_after_at recorded
  -> receiver now verifies with [current, previous]

Webhook event occurs
  -> dispatcher persists webhook_event + webhook_delivery
  -> Oban worker reloads subscription at execution time
  -> worker signs one canonical string with all active secrets
  -> receiver verifies any matching signature
  -> receiver dedupes strictly on delivery_id

Admin completes rotation after real overlap proof
  -> signing_secret <- next_signing_secret
  -> next_signing_secret cleared
  -> rotation_state = completed
  -> future attempts sign only with new active secret
```

### Recommended Project Structure

```text
lib/
├── sigra/webhooks.ex                      # lifecycle changesets + secret actions
├── sigra/webhooks/signature.ex            # multi-secret header emission + verify contract
├── sigra/workers/webhook_delivery.ex      # overlap send behavior at execution time
├── sigra/admin/webhooks/actions.ex        # prepare/start/complete admin mutation seam
└── sigra/admin/live/webhook_subscription_show_live.ex

test/example/
├── lib/example/accounts/webhook_subscription.ex
├── lib/example_web/controllers/sigra_webhook_controller.ex
└── priv/playwright/tests/admin-generated.spec.ts

guides/
├── flows/webhooks.md
└── recipes/webhook-verification.md
```

### Pattern 1: Persist lifecycle truth on the subscription row

**What:** Keep one active secret slot plus one staged secret slot and all overlap metadata on the subscription record. This is the authoritative operator truth, and it avoids reconstructing state from attempts or queue history. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md]

**When to use:** Always for Phase 103. Do not build a normalized secrets subsystem in this milestone. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md]

**Recommended fields:**

| Field | Type | Purpose |
|---|---|---|
| `signing_secret` | encrypted binary | Current active signing secret. [VERIFIED: test/example/lib/example/accounts/webhook_subscription.ex] |
| `next_signing_secret` | encrypted binary, nullable | Prepared replacement secret, present in `prepared` and `overlap_active`. |
| `rotation_state` | `Ecto.Enum` stored as string | `:stable | :prepared | :overlap_active | :completed`. [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html] |
| `rotation_prepared_at` | `:utc_datetime_usec`, nullable | When the next secret was staged. |
| `rotation_overlap_started_at` | `:utc_datetime_usec`, nullable | When sender dual-signing started. |
| `rotation_retire_after_at` | `:utc_datetime_usec`, nullable | Operator-declared earliest safe retirement time; informational, never auto-enforced. |
| `rotation_completed_at` | `:utc_datetime_usec`, nullable | When old secret was retired and active slot promoted. |
| `rotation_last_changed_by_user_id` | `:binary_id`, nullable | Latest global admin actor for operator truth. |
| `signing_secret_fingerprint` | short string | Non-secret operator-safe identifier for the active slot. |
| `next_signing_secret_fingerprint` | short string, nullable | Non-secret operator-safe identifier for the staged slot. |

**Migration guidance:** Add nullable Phase 103 columns first, backfill existing rows to `rotation_state = "stable"` with `signing_secret_fingerprint`, then update generated schema/template changesets to require `signing_secret` but not `next_signing_secret`. Existing subscriptions can stay live during migration because the current secret slot remains unchanged. [VERIFIED: test/example/priv/repo/migrations/20260506170000_create_webhook_tables.exs]

### Pattern 2: Load active secrets at send time and sign one canonical string per active secret

**What:** The worker should derive the list of active signing secrets from subscription state at execution time and produce one `Sigra-Webhook-Signature` header containing comma-separated `v1=` values over one shared `delivery_id.timestamp.raw_body` canonical string. [VERIFIED: lib/sigra/workers/webhook_delivery.ex] [VERIFIED: lib/sigra/webhooks/signature.ex]

**When to use:** For every actual HTTP attempt. This is especially important for retries because the same delivery may cross lifecycle boundaries between attempt 1 and attempt 2. [VERIFIED: .planning/phases/98-reliable-delivery-pipeline/98-CONTEXT.md]

**Example:**
```elixir
# Source: repo pattern from lib/sigra/workers/webhook_delivery.ex and lib/sigra/webhooks/signature.ex
timestamp = System.os_time(:second)
secrets = active_signing_secrets(subscription)

signature_value =
  secrets
  |> Enum.map(&Sigra.Webhooks.Signature.sign(delivery.delivery_id, timestamp, raw_body, &1))
  |> Enum.join(", ")

headers = [
  {"Sigra-Webhook-Id", delivery.delivery_id},
  {"Sigra-Webhook-Timestamp", Integer.to_string(timestamp)},
  {"Sigra-Webhook-Signature", signature_value},
  {"Content-Type", "application/json"}
]
```

### Pattern 3: Receiver verifies any active secret and dedupes on `delivery_id`

**What:** Receivers should continue to capture raw request bytes, verify against a local list of candidate secrets, reject stale timestamps, and suppress duplicates by `delivery_id`. [VERIFIED: guides/recipes/webhook-verification.md] [VERIFIED: lib/sigra/webhooks/signature.ex]

**When to use:** In public docs, generated receiver setup, and example-host proof code. [VERIFIED: guides/recipes/webhook-verification.md] [VERIFIED: priv/templates/sigra.install/admin/webhook_receiver_setup.md]

**Example:**
```elixir
# Source: guides/recipes/webhook-verification.md + Signature.verify/4 contract
Sigra.Webhooks.Signature.verify(conn.req_headers, raw_body, [
  System.fetch_env!("SIGRA_WEBHOOK_SECRET_CURRENT"),
  System.fetch_env!("SIGRA_WEBHOOK_SECRET_PREVIOUS")
], tolerance: 300)
```

### Anti-Patterns to Avoid

- **One-click replace:** Reusing `rotate_secret/2` as-is would recreate the delivery-loss race that Phase 103 exists to remove. [VERIFIED: lib/sigra/webhooks.ex]
- **Per-delivery secret pinning:** Storing a secret version on `webhook_deliveries` would conflict with locked decision `D-103-08` and make retries less truthful during overlap. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md]
- **Secret selection hints in headers:** Adding `kid` or similar metadata violates `D-103-10` and is unnecessary because verification already supports candidate-secret lists. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md] [VERIFIED: lib/sigra/webhooks/signature.ex]
- **Background completion timers:** Auto-retirement would introduce surprising state changes and contradict `D-103-15`. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md]

## Recommended Schema And Lifecycle Design

### Lifecycle state machine

| State | Active secret(s) for sender | Required columns | Allowed next action |
|---|---|---|---|
| `stable` | `signing_secret` only | `next_signing_secret = nil` | `prepare` |
| `prepared` | `signing_secret` only | `next_signing_secret` present, `rotation_prepared_at` present | `start_overlap` or `discard_prepared_secret` |
| `overlap_active` | `signing_secret` and `next_signing_secret` | `rotation_overlap_started_at` present | `complete_rotation` after at least one verified overlap delivery |
| `completed` | `signing_secret` only, where it now contains the former next secret | `rotation_completed_at` present, `next_signing_secret = nil` | `prepare` |

### Transition rules

1. `prepare`: generate a new secret, store it in `next_signing_secret`, set state to `prepared`, stamp `rotation_prepared_at`, refresh `next_signing_secret_fingerprint`, and record `rotation_last_changed_by_user_id`. This transition must not change sender behavior. [RECOMMENDATION]
2. `start_overlap`: require `prepared`, require `enabled == true`, set state to `overlap_active`, stamp `rotation_overlap_started_at`, persist operator-declared `rotation_retire_after_at`, and keep both secrets present. [RECOMMENDATION]
3. `complete_rotation`: require `overlap_active`, require proof of at least one successful overlap-window delivery after `rotation_overlap_started_at`, then promote `next_signing_secret` into `signing_secret`, clear next-slot columns, set state to `completed`, stamp `rotation_completed_at`, and rotate fingerprints. [RECOMMENDATION]
4. Optional cleanup action `discard_prepared_secret` is acceptable only from `prepared` and should clear the next slot without touching the active secret. This is safer than overloading `disable` or `rotate`. [RECOMMENDATION]

### Why preserve a `completed` state

Persisting `completed` instead of immediately collapsing back to `stable` makes the admin detail page truthful about the last completed cutover and aligns with the user's requested stable/prepared/overlap/completed lifecycle narrative. Ecto already supports explicit enum-backed state values cleanly, so the extra state is operationally cheap. [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html]

## Sender Signing Behavior

### Stable

- Sign exactly once with `signing_secret`. [VERIFIED: lib/sigra/workers/webhook_delivery.ex]
- Continue emitting one `Sigra-Webhook-Id`, one timestamp, and one `v1=` signature. [VERIFIED: lib/sigra/webhooks/signature.ex]

### Prepared

- Keep sender behavior identical to `stable`; the prepared secret is staged but unused until the receiver is ready. This preserves least surprise and matches the locked operator-driven workflow. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md]

### Overlap active

- Build one timestamp once per attempt, then sign the same canonical string with both active secrets and join the resulting `v1=` values in the existing signature header. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md] [CITED: https://docs.stripe.com/webhooks?lang=node] [CITED: https://www.svix.com/blog/zero-downtime-secret-rotation-webhooks/]
- Do not add a new header or mutate `delivery_id`. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md]
- Because the worker already reloads subscription state at execution time, retries that happen after overlap starts can naturally dual-sign without any delivery-row mutation. [VERIFIED: lib/sigra/workers/webhook_delivery.ex]

### Completed

- Sign exactly once with the promoted secret in `signing_secret`. [RECOMMENDATION]
- Keep `delivery_id` semantics unchanged so receivers treat post-cutover traffic as the same webhook product contract, not a new secret version. [VERIFIED: guides/recipes/webhook-verification.md]

## Receiver Verification Contract And Docs Implications

### Public contract changes

| Surface | Current wording | Required Phase 103 change |
|---|---|---|
| `guides/recipes/webhook-verification.md` | Says receiver may verify against current and previous secrets, but still says Sigra does not define sender overlap yet. [VERIFIED: guides/recipes/webhook-verification.md] | Promote candidate-secret verification from future-proofing to the canonical rotation contract, remove the "not yet" wording, and keep timestamp tolerance unchanged. |
| `guides/flows/webhooks.md` | Lists one `signing_secret` and calls overlap rotation out of scope. [VERIFIED: guides/flows/webhooks.md] | Update subscription contract and out-of-scope section to reflect bounded dual-slot overlap as shipped in Phase 103. |
| `priv/templates/sigra.install/admin/webhook_receiver_setup.md` | Tells adopters to update the receiver immediately because dual overlap is unavailable. [VERIFIED: priv/templates/sigra.install/admin/webhook_receiver_setup.md] | Replace with three-step prepare/start/complete guidance and explicit `CURRENT` + `PREVIOUS` env var examples. |

### Example-host proof implications

- The example controller currently looks up the sender-owned secret through `delivery_id`, which violates the public receiver ownership boundary if copied into real adopter code. That lookup should stay proof-only and be documented as such. [VERIFIED: test/example/lib/example_web/controllers/sigra_webhook_controller.ex] [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md]
- For proof coverage, the example host can still resolve the subscription by `delivery_id`, but it should construct a candidate-secret list from locally stored current/next secrets so the proof exercises the same verification path the docs recommend. [RECOMMENDATION]

## Admin And Generated-host Workflow Implications

### Admin mutation seam

Replace `rotate_secret/3` as the primary Phase 103 control surface with explicit actions in `Sigra.Admin.Webhooks.Actions`: `prepare_secret/3`, `start_secret_overlap/4`, `complete_secret_rotation/3`, and optionally `discard_prepared_secret/3`. The current admin action module is already the correct authorization boundary for these transitions. [VERIFIED: lib/sigra/admin/webhooks/actions.ex]

### Detail-page UX

| Current UI seam | Required change |
|---|---|
| One `Rotate secret` button with destructive copy. [VERIFIED: lib/sigra/admin/live/webhook_subscription_show_live.ex] | Replace with state-driven CTAs: `Prepare new secret`, `Start overlap`, `Complete rotation`, and `Discard prepared secret` where applicable. |
| Setup copy says "Update your receiver immediately after rotating the secret." [VERIFIED: lib/sigra/admin/live/webhook_subscription_show_live.ex] | Replace with state-specific next-step copy: update receiver, then start overlap, then prove one overlap delivery, then complete rotation, then prove one post-retirement delivery. |
| Secret reveal shows one plaintext secret only. [VERIFIED: lib/sigra/admin/live/webhook_subscription_show_live.ex] | Show current and staged secret sections separately, with safe fingerprints always visible and plaintext reveal still gated. |
| No lifecycle truth surface. [VERIFIED: lib/sigra/admin/live/webhook_subscription_show_live.ex] | Add a lifecycle status block showing state, what Sigra signs with now, overlap start time, retire-after timestamp, and last actor. |

### Generated host schema and template impact

- `test/example/lib/example/accounts/webhook_subscription.ex` and the install template copy under `priv/templates/sigra.install/core/webhook_subscription.ex` both need new fields and updated changesets. [VERIFIED: test/example/lib/example/accounts/webhook_subscription.ex] [VERIFIED: priv/templates/sigra.install/core/webhook_subscription.ex]
- `test/example/priv/repo/migrations/20260506170000_create_webhook_tables.exs` is the current schema baseline and should inform a new additive migration rather than editing the original migration in-place. [VERIFIED: test/example/priv/repo/migrations/20260506170000_create_webhook_tables.exs]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Lifecycle state validation | Custom string-parsing helpers everywhere | `Ecto.Enum` on the subscription schema | Centralizes allowed states and keeps LiveView/admin changesets honest. [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html] |
| Sender overlap cryptography | New signing subsystem or `kid` scheme | Existing `Signature.sign/4` + expanded header emission | The verifier already supports multiple signatures and candidate secrets. [VERIFIED: lib/sigra/webhooks/signature.ex] |
| Replay suppression | Secret-version dedupe or attempt-number dedupe | Existing `delivery_id` receiver receipt table and contract | Current proof receiver already dedupes by `delivery_id`, matching the published docs. [VERIFIED: test/example/lib/example/accounts/webhook_receipt.ex] [VERIFIED: guides/recipes/webhook-verification.md] |
| Automatic lifecycle completion | Scheduler/cron/Oban timer for retirement | Explicit admin completion after real proof | Timer-driven cutover is out of scope and less truthful. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md] |

**Key insight:** Sigra already has the hard parts of cryptographic verification and stable replay identifiers; the missing work is truthful lifecycle state plus sender behavior, not a new webhook security primitive. [VERIFIED: lib/sigra/webhooks/signature.ex] [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Keeping one-click rotation code and layering overlap on top

**What goes wrong:** The old `rotate_secret/2` path can still replace the active secret immediately, recreating the exact delivery-loss race this phase is meant to remove. [VERIFIED: lib/sigra/webhooks.ex]
**Why it happens:** The current API is mutation-oriented around one field, not lifecycle-oriented. [VERIFIED: lib/sigra/webhooks.ex]
**How to avoid:** Deprecate or internally reroute one-shot rotation to `prepare`, and remove the old destructive UI affordance from the admin detail page. [RECOMMENDATION]
**Warning signs:** Any code path still writes directly to `signing_secret` without validating `rotation_state`. [RECOMMENDATION]

### Pitfall 2: Making overlap depend on a delivery-owned secret version

**What goes wrong:** Retries after a lifecycle transition become harder to reason about, and the system violates locked decision `D-103-08`. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md]
**Why it happens:** Teams often try to "freeze" attempt behavior by stamping secret version data onto deliveries. [CITED: https://docs.github.com/en/webhooks/using-webhooks/automatically-redelivering-failed-deliveries-for-a-repository-webhook]
**How to avoid:** Keep the worker's existing execution-time reload model and derive active secrets from subscription state only. [VERIFIED: lib/sigra/workers/webhook_delivery.ex]
**Warning signs:** New delivery or attempt columns named like `secret_version`, `key_id`, or `signing_slot`. [RECOMMENDATION]

### Pitfall 3: Letting proof-only example-host lookup become public guidance

**What goes wrong:** Adopters copy a receiver that can only verify by querying Sigra-owned delivery context, which defeats the receiver-local contract. [VERIFIED: test/example/lib/example_web/controllers/sigra_webhook_controller.ex]
**Why it happens:** The example host is convenient because sender and receiver live in one codebase. [VERIFIED: test/example/lib/example/accounts.ex]
**How to avoid:** Keep the proof harness, but make docs and generated templates use environment-driven candidate secrets explicitly. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md]
**Warning signs:** Public docs mention fetching the secret by `delivery_id` or by looking up a subscription from Sigra tables. [RECOMMENDATION]

### Pitfall 4: Completing rotation without proving both overlap and post-retirement deliveries

**What goes wrong:** Operators think the rotation is finished even though the receiver never proved overlap acceptance or new-secret-only acceptance. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md]
**Why it happens:** UI copy or verification scope treats the admin click itself as the proof. [VERIFIED: lib/sigra/admin/live/webhook_subscription_show_live.ex]
**How to avoid:** Require one real overlap-window success before `complete_rotation`, then require one more post-retirement success in docs and proof artifacts. [RECOMMENDATION]
**Warning signs:** Tests assert state transitions only, with no receiver artifact or successful delivery rows after each phase. [RECOMMENDATION]

## Code Examples

Verified patterns from repo and official docs:

### Candidate-secret verification
```elixir
# Source: guides/recipes/webhook-verification.md
Sigra.Webhooks.Signature.verify(conn.req_headers, raw_body, [
  System.fetch_env!("SIGRA_WEBHOOK_SECRET_CURRENT"),
  System.fetch_env!("SIGRA_WEBHOOK_SECRET_PREVIOUS")
], tolerance: 300)
```

### Explicit enum-backed lifecycle field
```elixir
# Source: https://hexdocs.pm/ecto/Ecto.Enum.html
schema "webhook_subscriptions" do
  field :rotation_state, Ecto.Enum,
    values: [:stable, :prepared, :overlap_active, :completed],
    default: :stable
end
```

### Single-shot worker remains the execution unit
```elixir
# Source: lib/sigra/workers/webhook_delivery.ex
use Oban.Worker,
  queue: :sigra_webhooks,
  max_attempts: 1
```

## State Of The Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| One-shot secret replacement | Bounded overlap with multiple active signatures per attempt | Current Stripe docs and long-standing Svix guidance both document this model. [CITED: https://docs.stripe.com/webhooks?lang=node] [CITED: https://www.svix.com/blog/zero-downtime-secret-rotation-webhooks/] | Removes receiver cutover race without changing replay keys. |
| Per-attempt secret-specific replay reasoning | Stable delivery identifier across retries/redeliveries | GitHub's webhook docs still treat delivery GUID as the cross-redelivery truth key. [CITED: https://docs.github.com/en/webhooks/using-webhooks/automatically-redelivering-failed-deliveries-for-a-repository-webhook] | Supports replay-safe rollover keyed to delivery lineage instead of secret lineage. |
| Implicit/null-based lifecycle | Explicit persisted lifecycle enum | Supported cleanly by Ecto today. [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html] | Better operator truth and safer state transitions. |

**Deprecated/outdated:**

- The current Sigra `rotate_secret/2` immediate replacement path is outdated for the `WH-04` requirement because it intentionally lacks sender-side overlap. [VERIFIED: lib/sigra/webhooks.ex] [VERIFIED: .planning/REQUIREMENTS.md]
- The current generated receiver template text that says dual-secret overlap is unavailable in `v1.22` is outdated for Phase 103 planning. [VERIFIED: priv/templates/sigra.install/admin/webhook_receiver_setup.md]

## Decision Resolution

The research questions that initially remained open are now resolved and folded into the Phase 103 execution contract:

1. `rotation_retire_after_at` is optional operator metadata on `start_overlap`, not a required gate.
2. Secret fingerprints remain subscription/admin-surface metadata and are not required on proof receipts.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| Elixir | Library tests and implementation | ✓ | `1.19.5` | — |
| Erlang/OTP | Elixir runtime | ✓ | `28` | — |
| Node.js / npm / npx | Playwright proof lane | ✓ | `22.14.0` / `11.1.0` / `11.1.0` | — |
| PostgreSQL client / local server | Example app DB-backed proof lane | ✓ | `psql 14.17`; `pg_isready` reports localhost ready | — |
| Playwright package | Browser proof lane | ✓ | `@playwright/test ^1.48.0` | — |
| `CLOAK_KEY` env var | Example app boot and tests | ✗ by default in shell | CI uses base64 32-byte key | Export env var before running example app/tests |
| `EXAMPLE_DB_PROBE_ENABLED` env var | Generated-host proof artifact endpoint | ✗ by default in shell | — | Set env var when running the proof lane |

**Missing dependencies with no fallback:**

- None. [VERIFIED: local command probe]

**Missing dependencies with fallback:**

- Example-app proof commands require `CLOAK_KEY`; CI provides `MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=` and local runs can use the same base64 value. [VERIFIED: test/example/lib/example/vault.ex] [VERIFIED: .github/workflows/ci.yml]
- Generated-host proof artifact checks require `EXAMPLE_DB_PROBE_ENABLED=1`; without it the browser lane can still navigate, but it cannot produce the receiver proof bundle. [VERIFIED: test/example/priv/playwright/tests/admin-generated.spec.ts] [VERIFIED: .github/workflows/ci.yml]

## Validation Architecture

### Test Framework

| Property | Value |
|---|---|
| Framework | ExUnit + Phoenix LiveViewTest + Playwright. [VERIFIED: mix.exs] [VERIFIED: test/example/priv/playwright/package.json] |
| Config file | Root Mix project plus separate example Mix project under `test/example`; Playwright config lives under `test/example/priv/playwright`. [VERIFIED: mix.exs] [VERIFIED: test/example/mix.exs] |
| Quick run command | `mix test test/sigra/webhooks_signature_test.exs test/sigra/workers/webhook_delivery_test.exs` |
| Full phase command | `cd test/example && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= mix ecto.create && mix ecto.migrate && mix test test/example_web/live/admin_webhook_subscription_show_live_test.exs` plus the Playwright proof command from CI. [VERIFIED: .github/workflows/ci.yml] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|---|
| WH-04 | Verify multiple signatures from one attempt using candidate secrets and unchanged timestamp tolerance | unit | `mix test test/sigra/webhooks_signature_test.exs` | ✅ |
| WH-04 | Sender emits dual signatures only in overlap and one signature otherwise | unit | `mix test test/sigra/workers/webhook_delivery_test.exs` | ⚠ Needs new overlap cases |
| WH-04 | Lifecycle transitions enforce `prepare -> overlap -> complete` rules | unit/integration | `mix test test/sigra/webhooks_test.exs test/sigra/webhooks_integration_test.exs` | ⚠ Needs new schema/lifecycle cases |
| WH-04 | Admin detail truth and control flow reflect lifecycle states | example LiveView | `cd test/example && CLOAK_KEY=... mix test test/example_web/live/admin_webhook_subscription_show_live_test.exs` | ✅ existing file, needs new assertions |
| WH-04 | Generated-host proof correlates pre/overlap/post deliveries with receiver evidence | browser/integration | `cd test/example/priv/playwright && npx playwright test tests/admin-generated.spec.ts --project=chromium --grep "generated host canonical proof"` | ✅ existing file, needs lifecycle extension |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/webhooks_signature_test.exs test/sigra/workers/webhook_delivery_test.exs`
- **Per wave merge:** Root library webhook suite plus example LiveView test
- **Phase gate:** Example LiveView test and generated-host Playwright proof both green with receiver artifacts

### Wave 0 Gaps

- [ ] Add overlap-specific worker tests that assert two `v1=` signatures in `overlap_active`, one shared timestamp, and single-sign behavior in `prepared` and `completed`.
- [ ] Add lifecycle transition tests around invalid state moves, disabled subscriptions, and completion without verified overlap delivery.
- [ ] Extend the example LiveView test to assert new state badges, CTA gating, and removal of the old immediate-rotation copy.
- [ ] Extend `admin-generated.spec.ts` to run the full prepare/overlap/complete lifecycle and persist correlated artifacts for at least three deliveries.

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---|---|---|
| V2 Authentication | no | Outbound webhook rotation does not authenticate end users directly. [VERIFIED: phase scope] |
| V3 Session Management | no | No session-state behavior changes in this phase. [VERIFIED: phase scope] |
| V4 Access Control | yes | Global-admin-only rotation actions through `Sigra.Admin.Webhooks.Actions` and admin scope authorizer. [VERIFIED: lib/sigra/admin/webhooks/actions.ex] |
| V5 Input Validation | yes | Ecto changesets for lifecycle transitions and `Signature.verify/4` header/timestamp parsing. [VERIFIED: lib/sigra/webhooks.ex] [VERIFIED: lib/sigra/webhooks/signature.ex] |
| V6 Cryptography | yes | HMAC-SHA256 signatures plus encrypted secret storage through Cloak-backed fields. [VERIFIED: lib/sigra/webhooks/signature.ex] [VERIFIED: test/example/lib/example/accounts/webhook_subscription.ex] |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---|---|---|
| Forged webhook requests | Spoofing | Continue HMAC verification against raw body and candidate secrets only. [VERIFIED: guides/recipes/webhook-verification.md] |
| Replay during overlap | Repudiation / Tampering | Keep stale timestamp rejection unchanged and dedupe strictly on `delivery_id`. [VERIFIED: guides/recipes/webhook-verification.md] |
| Delivery loss during cutover | Denial of Service | Use explicit prepared state and overlap dual-signing before retirement. [CITED: https://docs.stripe.com/webhooks?lang=node] [CITED: https://www.svix.com/blog/zero-downtime-secret-rotation-webhooks/] |
| Secret leakage into jobs or history | Information Disclosure | Keep job args limited to `delivery_id`; never persist secrets in delivery or attempt rows. [VERIFIED: lib/sigra/workers/webhook_delivery.ex] [VERIFIED: test/sigra/webhooks_integration_test.exs] |
| Unauthorized rotation action | Elevation of Privilege | Keep mutations behind global admin authorization and explicit confirmation UI. [VERIFIED: lib/sigra/admin/webhooks/actions.ex] [VERIFIED: lib/sigra/admin/live/webhook_subscription_show_live.ex] |

## Sources

### Primary (HIGH confidence)

- `lib/sigra/webhooks.ex` - current subscription mutation, validation, and immediate secret rotation behavior. [VERIFIED: codebase grep]
- `lib/sigra/webhooks/signature.ex` - current multi-signature parsing and candidate-secret verification behavior. [VERIFIED: codebase grep]
- `lib/sigra/workers/webhook_delivery.ex` - current sender signing path and execution-time subscription reload model. [VERIFIED: codebase grep]
- `lib/sigra/admin/webhooks/actions.ex` and `lib/sigra/admin/live/webhook_subscription_show_live.ex` - current admin mutation boundary and one-shot rotation UX. [VERIFIED: codebase grep]
- `test/example/lib/example/accounts/webhook_subscription.ex`, `test/example/lib/example_web/controllers/sigra_webhook_controller.ex`, and `test/example/lib/example/accounts.ex` - current generated-host schema and proof-receiver seams. [VERIFIED: codebase grep]
- `guides/flows/webhooks.md`, `guides/recipes/webhook-verification.md`, and `priv/templates/sigra.install/admin/webhook_receiver_setup.md` - current published contract and generated host receiver guidance. [VERIFIED: codebase grep]
- `test/sigra/webhooks_signature_test.exs`, `test/sigra/workers/webhook_delivery_test.exs`, and `test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs` - baseline proof of existing behavior and regression seams. [VERIFIED: codebase grep]
- `test/example/priv/repo/migrations/20260506170000_create_webhook_tables.exs` - current database baseline for webhook tables. [VERIFIED: codebase grep]
- `mix.lock`, `mix.exs`, `test/example/priv/playwright/package.json`, and `.github/workflows/ci.yml` - version and environment verification. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- https://docs.stripe.com/webhooks?lang=node - active-secret overlap and per-secret signature behavior in current Stripe docs. [CITED: https://docs.stripe.com/webhooks?lang=node]
- https://hexdocs.pm/ecto/Ecto.Enum.html - official enum persistence behavior for recommended lifecycle modeling. [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html]
- https://docs.github.com/en/webhooks/using-webhooks/automatically-redelivering-failed-deliveries-for-a-repository-webhook - stable delivery GUID across redeliveries. [CITED: https://docs.github.com/en/webhooks/using-webhooks/automatically-redelivering-failed-deliveries-for-a-repository-webhook]
- https://docs.github.com/en/enterprise-cloud@latest/webhooks/testing-and-troubleshooting-webhooks/redelivering-webhooks - current operator-facing redelivery workflow and recent-deliveries truth model. [CITED: https://docs.github.com/en/enterprise-cloud@latest/webhooks/testing-and-troubleshooting-webhooks/redelivering-webhooks]

### Tertiary (LOW confidence)

- https://www.svix.com/blog/zero-downtime-secret-rotation-webhooks/ - official Svix blog guidance on zero-downtime dual-sign rotation. This is authoritative for Svix's position but is still a blog post, not a normative API reference. [CITED: https://www.svix.com/blog/zero-downtime-secret-rotation-webhooks/]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - versions and current framework/tooling were verified from `mix.lock`, `mix.exs`, local environment probes, and `package.json`. [VERIFIED: mix.lock] [VERIFIED: test/example/priv/playwright/package.json]
- Architecture: HIGH - the key design constraints are locked in `103-CONTEXT.md`, and the current seams clearly show where single-secret assumptions live. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md]
- Pitfalls: HIGH - they are directly grounded in the current one-shot rotation path, current docs, and existing proof harness boundaries. [VERIFIED: lib/sigra/webhooks.ex] [VERIFIED: guides/recipes/webhook-verification.md]

**Research date:** 2026-05-07
**Valid until:** 2026-06-06

## RESEARCH COMPLETE

**Phase:** 103 - Overlap-safe webhook secret rotation
**Confidence:** HIGH

### Key Findings

- Sigra already has multi-secret verification support and stable `delivery_id` replay keys; the missing work is subscription lifecycle truth and sender dual-sign behavior. [VERIFIED: lib/sigra/webhooks/signature.ex] [VERIFIED: guides/recipes/webhook-verification.md]
- The current one-shot `rotate_secret/2` path and admin copy must be replaced, not extended, because they still assume immediate sender cutover. [VERIFIED: lib/sigra/webhooks.ex] [VERIFIED: lib/sigra/admin/live/webhook_subscription_show_live.ex]
- The recommended implementation is a bounded dual-slot schema on `webhook_subscriptions` with explicit `stable/prepared/overlap_active/completed` states and operator-driven prepare/start/complete transitions. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md] [CITED: https://hexdocs.pm/ecto/Ecto.Enum.html]
- The receiver contract should stay raw-body + candidate-secret verification + `delivery_id` dedupe, while the example-host sender-owned secret lookup remains proof-only scaffolding. [VERIFIED: test/example/lib/example_web/controllers/sigra_webhook_controller.ex] [VERIFIED: guides/recipes/webhook-verification.md]
- Proof should span unit, example LiveView, and Playwright lanes, with correlated pre-rotation, overlap, and post-retirement evidence keyed by `delivery_id`. [VERIFIED: test/example/priv/playwright/tests/admin-generated.spec.ts] [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md]

### File Created

`.planning/phases/103-overlap-safe-webhook-secret-rotation/103-RESEARCH.md`

### Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | Versions, tooling, and required env vars were verified from the repo and local machine. [VERIFIED: mix.lock] [VERIFIED: .github/workflows/ci.yml] |
| Architecture | HIGH | The locked phase decisions align cleanly with the current code seams and external webhook rotation patterns. [VERIFIED: .planning/phases/103-overlap-safe-webhook-secret-rotation/103-CONTEXT.md] [CITED: https://docs.stripe.com/webhooks?lang=node] |
| Pitfalls | HIGH | Risks are directly evidenced by the current one-shot rotation path, outdated docs, and proof-only example receiver behavior. [VERIFIED: lib/sigra/webhooks.ex] [VERIFIED: priv/templates/sigra.install/admin/webhook_receiver_setup.md] |

### Resolved Follow-Ups

- `rotation_retire_after_at` is optional metadata on `start_overlap`, not a required gate. If provided, Sigra persists it as operator-facing retirement guidance, but sender behavior and transition legality do not depend on it. This preserves the explicit operator-driven model from D-103-15 without turning overlap start into a pseudo-scheduler contract.
- Fingerprints stay on the subscription/admin side only. Proof receipts and lifecycle evidence remain keyed to `delivery_id` plus receiver verification outcome; they do not need to persist secret fingerprints because that would not strengthen the public adopter contract and would add unnecessary secret-adjacent surface to evidence artifacts.

### Ready for Planning

Research complete. Planner can now create `PLAN.md` files for Phase 103 with no unresolved contract questions.
