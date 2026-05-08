# Phase 103: Overlap-safe webhook secret rotation - Pattern Map

**Mapped:** 2026-05-07
**Files analyzed:** 17 likely files/modules
**Analogs found:** 17 / 17

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/webhooks.ex` | service | CRUD + request-response | `lib/sigra/webhooks.ex:169-190`, `lib/sigra/webhooks.ex:374-618` | exact |
| `lib/sigra/workers/webhook_delivery.ex` | worker | event-driven | `lib/sigra/workers/webhook_delivery.ex:62-269` | exact |
| `lib/sigra/webhooks/signature.ex` | utility | transform + request-response | `lib/sigra/webhooks/signature.ex:40-149` | exact |
| `lib/sigra/admin/webhooks/actions.ex` | service | request-response | `lib/sigra/admin/webhooks/actions.ex:8-51` | exact |
| `lib/sigra/admin/live/webhook_subscription_show_live.ex` | LiveView/component | request-response | `lib/sigra/admin/live/webhook_subscription_show_live.ex:38-244` | exact |
| `lib/sigra/admin/webhooks/detail.ex` | service/query | request-response | `lib/sigra/admin/webhooks/detail.ex:13-69` | exact |
| `lib/sigra/admin/live/webhook_delivery_show_live.ex` | LiveView/component | request-response | `lib/sigra/admin/live/webhook_delivery_show_live.ex:35-99` | exact |
| `test/example/lib/example/accounts/webhook_subscription.ex` | model | CRUD | `test/example/lib/example/accounts/webhook_subscription.ex:16-32` | exact |
| `test/example/lib/example/accounts/webhook_delivery.ex` | model | CRUD + summary | `test/example/lib/example/accounts/webhook_delivery.ex:17-67` | exact |
| `test/example/lib/example/accounts/webhook_delivery_attempt.ex` | model | append-only event-driven | `test/example/lib/example/accounts/webhook_delivery_attempt.ex:16-59` | exact |
| `test/example/lib/example_web/controllers/sigra_webhook_controller.ex` | controller | request-response | `test/example/lib/example_web/controllers/sigra_webhook_controller.ex:7-31` | exact |
| `test/example/lib/example/accounts.ex` | context/service | request-response + proof | `test/example/lib/example/accounts.ex:866-940` | exact |
| `test/example/lib/example/accounts/webhook_receipt.ex` | model | append-only proof | `test/example/lib/example/accounts/webhook_receipt.ex:15-48` | exact |
| `test/example/priv/playwright/tests/admin-generated.spec.ts` | browser proof | request-response | `test/example/priv/playwright/tests/admin-generated.spec.ts:119-290` | exact |
| `test/example/priv/playwright/helpers/adminArtifacts.ts` | utility | file-I/O + evidence | `test/example/priv/playwright/helpers/adminArtifacts.ts:122-200` | exact |
| `guides/flows/webhooks.md` / `guides/recipes/webhook-verification.md` | docs | request-response | existing webhook guides plus Phase 98/102 proof wording | role-match |
| `.planning/phases/103-*/103-0X-PLAN.md` | planning | batch | `.planning/phases/98-*/98-0{1,2,3}-PLAN.md`, `.planning/phases/99-*/99-0{1,2,3,4,5}-PLAN.md`, `.planning/phases/100-*/100-0{1,2}-PLAN.md`, `.planning/phases/101-*/101-0{1,2}-PLAN.md`, `.planning/phases/102-*/102-0{1,2,3}-PLAN.md` | exact |

## Pattern Assignments

### `lib/sigra/webhooks.ex`

**Copy from**

- Secret mutation seam: `lib/sigra/webhooks.ex:169-190`
- Changeset pipeline and local validation ownership: `lib/sigra/webhooks.ex:374-387`
- Secret generation and validation: `lib/sigra/webhooks.ex:498-502`, `lib/sigra/webhooks.ex:575-582`
- Delivery summary/attempt co-update helpers: `lib/sigra/webhooks.ex:400-457`

**Pattern to keep**

- Library-owned orchestration with generated-host schema modules looked up from config.
- One validated changeset pipeline per subscription mutation.
- Secret generation stays library-owned.
- Delivery-level truth is persisted explicitly on the summary row plus append-only attempt rows.

**Phase 103 adaptation**

- Replace one-shot `rotate_secret/2` with explicit `prepare`, `start overlap`, and `complete rotation` mutations at this seam.
- Keep non-secret lifecycle metadata queryable on the subscription row the same way delivery status is queryable on `webhook_deliveries`.
- Follow the existing summary-row approach: explicit `rotation_state` plus overlap timestamps and actor metadata on the subscription record.

**Do not copy**

- `rotate_secret/2` at `lib/sigra/webhooks.ex:183-189` as-is. It is the exact anti-pattern Phase 103 is replacing.

### `test/example/lib/example/accounts/webhook_subscription.ex`

**Copy from**

- Encrypted/redacted secret field declaration: `test/example/lib/example/accounts/webhook_subscription.ex:16-22`
- Simple generated-host changeset shape: `test/example/lib/example/accounts/webhook_subscription.ex:28-32`

**Pattern to keep**

- Secret-bearing fields live on the generated host schema, use the encrypted binary type, and are `redact: true`.
- The generated schema stays thin; library code owns workflow and invariants.

**Phase 103 adaptation**

- Add dual-slot secret fields and lifecycle metadata here, not in a new normalized secrets table.
- Keep operator-readable metadata separate from secret material.
- Preserve the same generated-host ownership boundary used for the current `signing_secret`.

### Explicit lifecycle/status modeling on schemas

**Primary analog to copy**

- Explicit state string on delivery summaries: `test/example/lib/example/accounts/webhook_delivery.ex:18-29`
- LiveView status presentation bound to persisted truth: `lib/sigra/admin/live/webhook_subscription_show_live.ex:241-244`, `lib/sigra/admin/live/webhook_delivery_show_live.ex:96-99`

**Anti-pattern to avoid**

- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_invitation.ex:5-10`

That invitation schema intentionally infers lifecycle from timestamps. Phase 103 explicitly decided the opposite. Do not copy that modeling style for rotation state.

**Recommendation**

- Use the webhook delivery pattern, not the invitation pattern: persist an explicit string state on the subscription row and render directly from it.
- Keep overlap timestamps and actor fields as supporting metadata, not as the only source of truth.

### `lib/sigra/workers/webhook_delivery.ex`

**Copy from**

- Single-shot worker contract and `delivery_id`-only job payload: `lib/sigra/workers/webhook_delivery.ex:12-34`
- Reload current state at execution time: `lib/sigra/workers/webhook_delivery.ex:126-154`
- One timestamp per attempt passed into signing: `lib/sigra/workers/webhook_delivery.ex:77-96`
- Attempt persistence and summary-row co-fate: `lib/sigra/workers/webhook_delivery.ex:156-269`

**Pattern to keep**

- Jobs store only `delivery_id`.
- Worker reloads subscription, event, and delivery at send time.
- Attempt history remains append-only and parent summary updates in the same persistence helper path.
- Retries are allowed to observe current subscription state, not frozen enqueue-time state.

**Phase 103 adaptation**

- Extend `build_request/3` so overlap-active deliveries emit multiple `v1=` signatures over one shared timestamp, not separate sends or per-secret timestamps.
- Preserve current “reload at execution time” behavior so retries during overlap use all currently active secrets.

**Do not copy**

- The single-secret branch at `lib/sigra/workers/webhook_delivery.ex:78-99` as final behavior. It is the right skeleton, but incomplete for overlap.

### `lib/sigra/webhooks/signature.ex`

**Copy from**

- Canonical string contract: `lib/sigra/webhooks/signature.ex:40-47`
- `v1=` digest generation: `lib/sigra/webhooks/signature.ex:49-61`
- Multi-signature parsing and any-match verification: `lib/sigra/webhooks/signature.ex:78-149`
- Constant-time comparison path: `lib/sigra/webhooks/signature.ex:119-128`

**Pattern to keep**

- One canonical string: `delivery_id.timestamp.raw_body`
- Receiver verification accepts a list of candidate secrets and succeeds if any valid signature matches.
- Timestamp freshness is checked before digest acceptance and stays unchanged.

**Phase 103 adaptation**

- Extend `headers/4` to emit multiple `v1=` values in one `Sigra-Webhook-Signature` header during overlap.
- Do not add a `kid` or secret hint header.
- Keep stale timestamps invalid even if one digest matches.

**Tests to copy**

- `test/sigra/webhooks_signature_test.exs:35-52` already proves multiple `v1=` values and candidate-secret verification.
- `test/sigra/webhooks_signature_test.exs:55-87` locks the unchanged timestamp and malformed-header contract.

### `lib/sigra/admin/webhooks/actions.ex`

**Copy from**

- Thin authz-first admin mutation boundary: `lib/sigra/admin/webhooks/actions.ex:8-51`

**Pattern to keep**

- `Authorizer.authorize_global!/1` first.
- Then delegate into `Sigra.Webhooks`.
- Keep generated hosts out of direct `Repo` writes for webhook operations.

**Phase 103 adaptation**

- Add `prepare_secret`, `start_overlap`, and `complete_rotation` here as separate admin-safe mutations.
- Keep this module as the mutation boundary; do not spread workflow state transitions across LiveView event handlers.

### `lib/sigra/admin/live/webhook_subscription_show_live.ex`

**Copy from**

- Progressive disclosure with `confirm_action`: `lib/sigra/admin/live/webhook_subscription_show_live.ex:49-105`
- Truthful setup copy and next-step guidance block: `lib/sigra/admin/live/webhook_subscription_show_live.ex:128-139`
- Detail-page summary and recent delivery state: `lib/sigra/admin/live/webhook_subscription_show_live.ex:117-125`, `lib/sigra/admin/live/webhook_subscription_show_live.ex:175-199`

**Pattern to keep**

- The detail page owns operator messaging and confirmation UX, not business logic.
- The page states what Sigra does now and what the receiver must do next.
- Real delivery history is shown inline to anchor operator decisions.

**Phase 103 adaptation**

- Replace one-shot rotate messaging with explicit three-step rotation lifecycle messaging.
- Add truthful status/action copy for `stable`, `prepared`, and `overlap_active`.
- Keep the delivery-history section visible so operators can prove one overlap-window delivery and one post-retirement delivery.

**Do not copy**

- The current warning at `lib/sigra/admin/live/webhook_subscription_show_live.ex:65-71` or the flash at `lib/sigra/admin/live/webhook_subscription_show_live.ex:97-103`. Those messages encode the old unsafe contract.

### `lib/sigra/admin/webhooks/detail.ex` and `lib/sigra/admin/live/webhook_delivery_show_live.ex`

**Copy from**

- Shared detail loader boundary: `lib/sigra/admin/webhooks/detail.ex:27-69`
- Delivery detail truthful status/timeline rendering: `lib/sigra/admin/live/webhook_delivery_show_live.ex:46-75`
- Regression test: `test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs:9-59`

**Pattern to keep**

- Summary state comes from the delivery row.
- Drill-down history comes from append-only attempts.
- Delivery detail pages state current status, next attempt, last HTTP status, and terminal reason directly from persisted truth.

**Phase 103 adaptation**

- Mirror this honesty on the subscription detail page for rotation state and signing behavior.
- If rotation history or proof cues are added, treat them like delivery drill-down: persisted truth first, copy second.

### `test/example/lib/example_web/controllers/sigra_webhook_controller.ex`

**Copy from**

- Published verification seam: `test/example/lib/example_web/controllers/sigra_webhook_controller.ex:7-31`

**Pattern to keep**

- Verify against `conn.assigns[:raw_body]`.
- Keep explicit response mapping for missing, malformed, stale, and invalid signature cases.
- Persist deduped receiver proof keyed on `delivery_id`.

**Phase 103 adaptation**

- The proof controller can accept `[current_secret, previous_secret]` during overlap.
- It should continue deduping strictly on `delivery_id`.

**Anti-pattern to avoid**

- `signing_secret/1` at `test/example/lib/example_web/controllers/sigra_webhook_controller.ex:41-48` is acceptable only for proof scaffolding. Do not treat sender-owned secret lookup as the public adopter contract.

### `test/example/lib/example/accounts.ex` and `test/example/lib/example/accounts/webhook_receipt.ex`

**Copy from**

- Proof correlation helper: `test/example/lib/example/accounts.ex:882-909`
- Receipt persistence and duplicate handling: `test/example/lib/example/accounts.ex:911-940`
- Durable proof schema keyed by `delivery_id`: `test/example/lib/example/accounts/webhook_receipt.ex:15-48`

**Pattern to keep**

- Browser/admin artifacts and receiver artifacts correlate on `delivery_id`.
- Duplicate receipts return existing proof rows instead of mutating state again.
- Proof artifacts stay narrow and reviewer-friendly.

**Phase 103 adaptation**

- Extend proof bundle shape to prove pre-overlap, overlap, and post-retirement deliveries with the same `delivery_id`-correlation discipline.
- Add only the minimum receiver metadata needed to prove which lifecycle step was exercised.

### `test/example/priv/playwright/tests/admin-generated.spec.ts` and `helpers/adminArtifacts.ts`

**Copy from**

- Wait for real admin-visible delivery evidence: `test/example/priv/playwright/tests/admin-generated.spec.ts:119-133`
- Canonical generated-host proof flow: `test/example/priv/playwright/tests/admin-generated.spec.ts:186-290`
- Evidence bundle writer: `test/example/priv/playwright/helpers/adminArtifacts.ts:145-200`

**Pattern to keep**

- URL-driven admin flow.
- Real event trigger from a second browser context.
- Durable bundle with `README.md`, `manifest.json`, screenshots, and stable identifiers.

**Phase 103 adaptation**

- Extend this lane to one canonical rotation proof run:
  - create subscription / capture stable secret
  - prepare next secret
  - start overlap
  - trigger real overlap delivery
  - complete rotation
  - trigger real post-retirement delivery
- Keep the artifact directory approach; only widen the manifest schema enough to record both proof deliveries and receiver acceptance.

## Shared Patterns

### Secret storage

**Source:** `test/example/lib/example/accounts/webhook_subscription.ex:16-22`

- Secret fields belong on generated-host schemas.
- Use encrypted binary fields with `redact: true`.
- Keep operator-readable lifecycle metadata separate from secret material.

### Explicit persisted truth

**Source:** `test/example/lib/example/accounts/webhook_delivery.ex:18-29`, `lib/sigra/admin/live/webhook_delivery_show_live.ex:46-75`

- Persist the operational state explicitly on the row that operators inspect.
- Use append-only history rows for drill-down, not for reconstructing the primary state.

### Admin mutation boundary

**Source:** `lib/sigra/admin/webhooks/actions.ex:8-51`

- Authorize first.
- Delegate to `Sigra.Webhooks`.
- Keep generated hosts thin.

### Replay and verification contract

**Source:** `lib/sigra/webhooks/signature.ex:84-149`, `test/example/lib/example/accounts.ex:911-940`

- Verification accepts candidate secrets locally.
- Dedupe remains keyed only on `delivery_id`.
- Timestamp freshness remains unchanged.

## Anti-Patterns To Avoid

- `lib/sigra/webhooks.ex:183-189`: one-shot secret replacement with no overlap window.
- `lib/sigra/admin/live/webhook_subscription_show_live.ex:65-71`: UI copy that tells operators to rotate immediately and race the receiver update.
- `test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp/accounts/organization_invitation.ex:5-10`: inferred lifecycle from timestamps only. Phase 103 needs explicit state.
- `lib/sigra/workers/webhook_delivery.ex:78-99`: single-secret send path copied without extending it for overlap.
- `test/example/lib/example_web/controllers/sigra_webhook_controller.ex:41-48`: sender-owned secret lookup presented as if it were the public receiver contract.
- Any plan that couples rotation state to attempt history reconstruction instead of storing subscription lifecycle truth directly on the subscription row.
- Any proof lane that stops at screenshots or action clicks instead of correlating durable sender and receiver evidence on `delivery_id`.

## Planning Decomposition Patterns From Phases 97-102

### Recommended slice order for Phase 103

1. **Schema + generated-host foundation first**
   - Copy the Phase 98 Wave 0 shape:
   - `.planning/phases/98-reliable-delivery-pipeline/98-01-PLAN.md:1-46`
   - Start with generated schema/migration/config seams before worker logic or UI.

2. **Library runtime behavior second**
   - Copy the Phase 98 Wave 1 and Phase 100 Wave 1 shape:
   - `.planning/phases/98-reliable-delivery-pipeline/98-02-PLAN.md:1-43`
   - `.planning/phases/100-production-webhook-dispatch-handoff/100-01-PLAN.md:1-40`
   - Keep worker/signature/webhooks runtime changes in a dedicated slice before proof or docs.

3. **Admin query/action seam before LiveView polish**
   - Copy the Phase 99 Wave 1 and Phase 101 Wave 1 split:
   - `.planning/phases/99-admin-and-generated-host-webhook-ux/99-01-PLAN.md:1-46`
   - `.planning/phases/101-operator-delivery-state-truth/101-01-PLAN.md:1-34`
   - Build action/query truth modules first, then wire LiveViews.

4. **LiveView/operator copy as a separate follow-on slice**
   - Copy the Phase 99 Wave 2 and Phase 101 Wave 2 pattern:
   - `.planning/phases/99-admin-and-generated-host-webhook-ux/99-02-PLAN.md:1-31`
   - `.planning/phases/101-operator-delivery-state-truth/101-02-PLAN.md:1-34`
   - Subscription detail truthfulness and action messaging should be isolated from lower-level state changes.

5. **Generated-host proof and evidence last**
   - Copy the Phase 102 split:
   - `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-01-PLAN.md:1-70`
   - `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-02-PLAN.md:1-70`
   - First add the receiver/runtime seam, then extend Playwright/evidence, then reconcile docs if needed.

### House planning structure to copy

**Common shape across 98-102**

- Frontmatter with `wave`, `depends_on`, `files_modified`, `requirements`, and `tags`
- `must_haves` split into `truths`, `artifacts`, and `key_links`
- A short `<objective>` focused on one boundary
- `<interfaces>` that lock invariants before coding
- Explicit verification commands at plan level
- 1-2 concrete `<task>` blocks that keep slices vertically testable

**Best matches**

- Schema/runtime decomposition: `.planning/phases/98-reliable-delivery-pipeline/98-01-PLAN.md:1-80`, `.planning/phases/98-reliable-delivery-pipeline/98-02-PLAN.md:1-80`
- Admin/data-vs-UI separation: `.planning/phases/99-admin-and-generated-host-webhook-ux/99-01-PLAN.md:1-80`, `.planning/phases/99-admin-and-generated-host-webhook-ux/99-02-PLAN.md:1-80`
- Query-truth before LiveView copy: `.planning/phases/101-operator-delivery-state-truth/101-01-PLAN.md:1-80`, `.planning/phases/101-operator-delivery-state-truth/101-02-PLAN.md:1-80`
- Proof runtime before Playwright evidence: `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-01-PLAN.md:1-80`, `.planning/phases/102-generated-host-proof-and-planning-reconciliation/102-02-PLAN.md:1-80`

## No Analog Found

| File/Concern | Reason |
|---|---|
| Normalized `webhook_subscription_secrets` table | No current code uses a separate secret-history table, and Phase 103 explicitly rejects that design. |
| Timer-driven overlap retirement job | No webhook phase uses scheduler-driven rotation transitions; current admin/operator pattern is explicit action-driven state change. |

## Metadata

**Analog search scope:** `lib/`, `test/example/`, `test/sigra/`, `guides/`, `.planning/phases/97-*` through `.planning/phases/102-*`

**Files scanned:** code seams, example-host proof seams, webhook tests, webhook guides, and recent webhook plan artifacts

**Pattern extraction date:** 2026-05-07

PATTERNS COMPLETE
