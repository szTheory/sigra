# Phase 104: Failed-delivery replay controls - Pattern Map

**Mapped:** 2026-05-07
**Files analyzed:** 20 likely files/modules
**Analogs found:** 19 / 20

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/webhooks.ex` | service | CRUD + event-driven | `lib/sigra/webhooks.ex:203-258`, `lib/sigra/webhooks.ex:374-433`, `lib/sigra/webhooks.ex:466-600` | exact |
| `lib/sigra/webhooks/dispatcher.ex` | service | CRUD + event-driven | `lib/sigra/webhooks/dispatcher.ex:33-139` | exact |
| `lib/sigra/workers/webhook_delivery.ex` | worker | event-driven | `lib/sigra/workers/webhook_delivery.ex:33-99`, `lib/sigra/workers/webhook_delivery.ex:126-269` | exact |
| `lib/sigra/admin/webhooks/actions.ex` | service | request-response | `lib/sigra/admin/webhooks/actions.ex:8-85` | exact |
| `lib/sigra/admin/webhooks/detail.ex` | service/query | request-response | `lib/sigra/admin/webhooks/detail.ex:13-70` | exact |
| `lib/sigra/admin/webhooks/failures.ex` | service/query | request-response | `lib/sigra/admin/webhooks/failures.ex:59-146` | exact |
| `lib/sigra/admin/live/webhook_delivery_failures_live.ex` | LiveView/component | request-response | `lib/sigra/admin/live/webhook_delivery_failures_live.ex:24-174` | exact |
| `lib/sigra/admin/live/webhook_delivery_show_live.ex` | LiveView/component | request-response | `lib/sigra/admin/live/webhook_delivery_show_live.ex:24-99` | exact |
| `lib/sigra/admin/live/webhook_subscription_show_live.ex` | LiveView/component | request-response | `lib/sigra/admin/live/webhook_subscription_show_live.ex:49-173`, `lib/sigra/admin/live/webhook_subscription_show_live.ex:295-349` | role-match |
| `test/example/lib/example/accounts/webhook_delivery.ex` | model | CRUD + summary | `test/example/lib/example/accounts/webhook_delivery.ex:17-67` | exact |
| `test/example/lib/example/accounts/webhook_delivery_attempt.ex` | model | append-only event-driven | `test/example/lib/example/accounts/webhook_delivery_attempt.ex:16-59` | exact |
| `priv/templates/sigra.install/core/webhook_delivery.ex` | template/model | CRUD + summary | `priv/templates/sigra.install/core/webhook_delivery.ex:17-67` | exact |
| `priv/templates/sigra.install/core/webhook_migration.exs` | migration/template | CRUD | `priv/templates/sigra.install/core/webhook_migration.exs:45-102` | exact |
| `test/example/priv/repo/migrations/20260506170000_create_webhook_tables.exs` | migration | CRUD | `test/example/priv/repo/migrations/20260506170000_create_webhook_tables.exs:45-108` | exact |
| `test/sigra/webhooks_integration_test.exs` | integration test | event-driven | `test/sigra/webhooks_integration_test.exs:564-729`, `test/sigra/webhooks_integration_test.exs:837-910` | exact |
| `test/sigra/admin/webhooks_test.exs` | integration/admin test | request-response | `test/sigra/admin/webhooks_test.exs:411-578` | exact |
| `test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs` | LiveView test | request-response | `test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs:9-59` | exact |
| `test/example/lib/example/accounts.ex` | proof/context service | request-response + proof | `test/example/lib/example/accounts.ex:899-1023` | exact |
| `test/example/lib/example/accounts/webhook_receipt.ex` | proof model | append-only proof | `test/example/lib/example/accounts/webhook_receipt.ex:15-48` | exact |
| `test/example/lib/example_web/controllers/sigra_webhook_controller.ex` | controller | request-response | `test/example/lib/example_web/controllers/sigra_webhook_controller.ex:7-49` | exact |
| `test/example/priv/playwright/tests/admin-generated.spec.ts` / `helpers/adminArtifacts.ts` | browser proof | request-response + file-I/O | `test/example/priv/playwright/tests/admin-generated.spec.ts:154-249`, `:366-449`; `helpers/adminArtifacts.ts:126-217` | exact |

## Pattern Assignments

### `lib/sigra/webhooks.ex`

**Analog:** `lib/sigra/webhooks.ex`

**Replay API shape to copy**
- Lifecycle mutation style: `lib/sigra/webhooks.ex:203-258`
- Job enqueue seam: `lib/sigra/webhooks.ex:374-433`
- Summary-row + append-only ledger persistence: `lib/sigra/webhooks.ex:466-600`

**Pattern to keep**
- Library-owned state transition API.
- One durable summary row per delivery lifecycle.
- One append-only attempt ledger scoped to that delivery.
- Jobs store only `delivery_id`; creation and enqueue stay separate but composable.

**Phase 104 adaptation**
- Add a replay API here, not in LiveView.
- Build replay as “insert child delivery row + enqueue new job” using the dispatcher/enqueue seams, not by mutating the original row back to `pending`.
- Reuse the existing explicit rejection style by returning changeset-style or typed errors for unsafe states.

**Anti-patterns to avoid**
- Do not copy `rotate_secret/2` at `lib/sigra/webhooks.ex:191-200` as a model for replay. Replay is not a blind field swap; it needs guard checks, lineage writes, and concurrency protection.
- Do not reuse `persist_delivery_outcome/3` to append replay as attempt `N+1`. `lib/sigra/webhooks.ex:583-600` proves attempts are scoped to one delivery row.

### `lib/sigra/webhooks/dispatcher.ex`

**Analog:** `lib/sigra/webhooks/dispatcher.ex`

**Fresh-row insertion pattern**
- Transaction builder: `lib/sigra/webhooks/dispatcher.ex:33-57`
- Canonical delivery insert attrs: `lib/sigra/webhooks/dispatcher.ex:110-139`

**Pattern to keep**
- New delivery rows are inserted with fully explicit summary fields.
- `delivery_id` is always regenerated for a new lifecycle.
- Caller owns the outer transaction and can compose additional steps.

**Phase 104 adaptation**
- Replay child insertion should match this fresh-row shape and then add lineage/operator metadata.
- Prefer a new helper near this seam if replay needs a delivery insert path without creating a new webhook event row.

### `lib/sigra/workers/webhook_delivery.ex`

**Analog:** `lib/sigra/workers/webhook_delivery.ex`

**Worker semantics to preserve**
- Job payload contract: `lib/sigra/workers/webhook_delivery.ex:33-50`
- Send-time reload and dependency checks: `lib/sigra/workers/webhook_delivery.ex:126-154`
- Failure classification and retry scheduling: `lib/sigra/workers/webhook_delivery.ex:206-269`

**Pattern to keep**
- Worker truth comes from persisted delivery state, not queue guesses.
- Local dependency failures become persisted terminal facts.
- Retry scheduling reuses the same delivery row; replay must not.

**Phase 104 adaptation**
- Replay must only enqueue a brand-new child delivery, then let this unchanged worker process it as a normal first-attempt delivery.
- Guard replay against `retry_scheduled` because this worker already owns that state machine.

### `lib/sigra/admin/webhooks/actions.ex`

**Analog:** `lib/sigra/admin/webhooks/actions.ex`

**Mutation boundary**
- Authz-first thin wrappers: `lib/sigra/admin/webhooks/actions.ex:8-85`

**Pattern to keep**
- `Authorizer.authorize_global!/1` first.
- Load minimal identifiers.
- Delegate business rules into `Sigra.Webhooks`.

**Phase 104 adaptation**
- Add replay wrappers here only.
- Keep admin actor metadata flowing via `admin_scope.scope`, like secret rotation already does.

### `lib/sigra/admin/webhooks/detail.ex`

**Analog:** `lib/sigra/admin/webhooks/detail.ex`

**Authority-page loader pattern**
- Subscription detail assembly: `lib/sigra/admin/webhooks/detail.ex:13-25`
- Delivery detail assembly: `lib/sigra/admin/webhooks/detail.ex:28-38`
- Recent deliveries query: `lib/sigra/admin/webhooks/detail.ex:51-60`
- Attempt timeline query: `lib/sigra/admin/webhooks/detail.ex:62-69`

**Pattern to keep**
- Detail module, not LiveView, owns the read model.
- Delivery page loads summary row plus ordered attempts.
- Subscription page loads recent deliveries for context.

**Phase 104 adaptation**
- Extend `load_delivery!/3` with replay lineage read-model data.
- Extend `load_subscription!/3` only enough to show replayed recent deliveries; keep delivery detail as the authority for lineage truth.

### `lib/sigra/admin/webhooks/failures.ex`

**Analog:** `lib/sigra/admin/webhooks/failures.ex`

**Inbox query truth**
- Inbox state partition: `lib/sigra/admin/webhooks/failures.ex:59-104`
- Search and filter application: `lib/sigra/admin/webhooks/failures.ex:106-146`

**Pattern to keep**
- Failures inbox is delivery-row based.
- Only retrying and dead-lettered rows appear.
- Subscriptions are attached as display context, not as the primary unit.

**Phase 104 adaptation**
- Replay eligibility and “already replayed” badges should hang off delivery rows here.
- Keep replay shortcut narrow; do not turn this into a queue-control dashboard.

### `lib/sigra/admin/live/webhook_delivery_failures_live.ex`

**Analog:** `lib/sigra/admin/live/webhook_delivery_failures_live.ex`

**Triage UI pattern**
- Param-driven reload: `lib/sigra/admin/live/webhook_delivery_failures_live.ex:24-50`
- Delivery-row cards and open-detail CTA: `lib/sigra/admin/live/webhook_delivery_failures_live.ex:96-121`

**Pattern to keep**
- Inbox shows concise status, next attempt, terminal reason.
- Primary action today is “Open delivery”.

**Phase 104 adaptation**
- If a replay shortcut ships here, keep it secondary to “Open delivery”.
- Use existing card-level truth; do not hide lineage behind optimistic flash-only flows.

### `lib/sigra/admin/live/webhook_delivery_show_live.ex`

**Analog:** `lib/sigra/admin/live/webhook_delivery_show_live.ex`

**Shared delivery detail truth**
- Page load and event fetch: `lib/sigra/admin/live/webhook_delivery_show_live.ex:24-33`
- Current-status block: `lib/sigra/admin/live/webhook_delivery_show_live.ex:46-59`
- Attempt timeline block: `lib/sigra/admin/live/webhook_delivery_show_live.ex:62-75`

**Pattern to keep**
- Delivery detail is a shared drill-down.
- Attempt timeline stays scoped to one delivery.
- Return path is preserved between inbox and subscription views.

**Phase 104 adaptation**
- Add replay lineage and confirmation here.
- Keep manual replay visually distinct from the automatic attempt timeline.

**Anti-pattern already locked by test**
- `test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs:47-58` currently asserts no replay control exists. Replace that absence with explicit replay-specific assertions; do not silently stuff replay into the existing attempt list.

### `lib/sigra/admin/live/webhook_subscription_show_live.ex`

**Analog:** `lib/sigra/admin/live/webhook_subscription_show_live.ex`

**High-risk action idiom**
- Confirm-action workflow: `lib/sigra/admin/live/webhook_subscription_show_live.ex:49-173`
- Recent-deliveries context list: `lib/sigra/admin/live/webhook_subscription_show_live.ex:295-319`

**Pattern to keep**
- Detail page actions use explicit confirmation.
- Page copy states what Sigra does and what the operator must do next.
- Recent deliveries are context, not the main mutation surface.

**Phase 104 adaptation**
- Subscription page may show replayed children in recent history, but should not become the primary replay home.
- If any replay affordance is added here, keep it read-mostly and link through to delivery detail.

### Generated-host delivery schema and migration

**Analogs**
- Schema: `test/example/lib/example/accounts/webhook_delivery.ex:17-67`
- Install template: `priv/templates/sigra.install/core/webhook_delivery.ex:17-67`
- Migration: `priv/templates/sigra.install/core/webhook_migration.exs:45-102`

**Pattern to keep**
- Delivery summary row carries operator-visible truth.
- Attempt ledger is separate and append-only.
- Migration/template and example schema stay in lockstep.

**Phase 104 adaptation**
- Replay lineage fields belong on `webhook_deliveries`, not on attempts.
- Add indexes for parent/root lineage queries here.
- Keep the attempt unique key `[:delivery_id, :attempt_number]` untouched so replay child starts at attempt `1`.

### Proof seams: generated host + receiver

**Analogs**
- Receiver controller verify + persist: `test/example/lib/example_web/controllers/sigra_webhook_controller.ex:7-31`
- Receiver proof bundle assembly: `test/example/lib/example/accounts.ex:899-1023`
- Proof receipt schema: `test/example/lib/example/accounts/webhook_receipt.ex:15-48`
- Browser artifact collection: `test/example/priv/playwright/tests/admin-generated.spec.ts:154-249`, `:366-449`
- Bundle writer: `test/example/priv/playwright/helpers/adminArtifacts.ts:149-217`

**Pattern to keep**
- Receiver continues deduping on `delivery_id`.
- Proof bundle correlates admin and receiver evidence by `delivery_id`.
- Browser proof writes durable machine-readable and human-readable artifacts.

**Phase 104 adaptation**
- Proof should show two delivery ids in one lineage: original failed row and replay child.
- Keep receipts keyed by `delivery_id`; replay success should create a second receipt, not overwrite the first.
- Extend the proof bundle schema with lineage keys rather than changing the receiver contract.

## Shared Patterns

### Replay lineage should live on `webhook_deliveries`
**Sources:** `test/example/lib/example/accounts/webhook_delivery.ex:17-67`, `priv/templates/sigra.install/core/webhook_migration.exs:45-76`

Apply replay lineage metadata to the delivery summary row, because that row already owns operator-visible lifecycle truth. The attempt ledger is the wrong level.

Recommended shape:
- `replayed_from_webhook_delivery_id`
- `replay_root_webhook_delivery_id`
- `replayed_by_user_id`
- `replayed_at`
- `replay_source`

### Admin action ownership stays thin
**Source:** `lib/sigra/admin/webhooks/actions.ex:8-85`

Replay mutations should enter through `Sigra.Admin.Webhooks.Actions`, authorize once, then delegate into `Sigra.Webhooks`.

### Detail page owns confirmation and lineage truth
**Sources:** `lib/sigra/admin/webhooks/detail.ex:28-38`, `lib/sigra/admin/live/webhook_delivery_show_live.ex:46-75`

The delivery detail page is the right place for eligibility checks, confirm modal, parent/root links, and “replay already exists” truth.

### Failures inbox stays a delivery-row triage surface
**Sources:** `lib/sigra/admin/webhooks/failures.ex:99-146`, `lib/sigra/admin/live/webhook_delivery_failures_live.ex:96-121`

If planning adds a replay shortcut, keep it narrow and row-scoped. Do not introduce batch or queue-level semantics.

### Proof correlation remains `delivery_id`-based
**Sources:** `test/example/lib/example/accounts.ex:966-1023`, `test/example/lib/example/accounts/webhook_receipt.ex:15-48`

Replay lineage proof belongs in sender/admin artifacts. Receiver verification stays per-delivery and continues to dedupe by the child delivery's new `delivery_id`.

## Anti-patterns To Avoid

- Mutating the original failed row back to `pending` or `retry_scheduled`. Current summary-row truth at `lib/sigra/webhooks.ex:545-576` and worker retry behavior at `lib/sigra/workers/webhook_delivery.ex:206-269` assume one lifecycle per row.
- Appending replay as attempt `N+1` on the original row. `test/example/lib/example/accounts/webhook_delivery_attempt.ex:16-59` and `priv/templates/sigra.install/core/webhook_migration.exs:78-102` lock attempts to a per-delivery ledger.
- Using Oban uniqueness as the only double-submit guard. The phase context explicitly rejects queue-only safety; planner should prefer DB-backed transactional guards on the source delivery row.
- Making the subscription page the main replay surface. Existing idiom in `lib/sigra/admin/live/webhook_subscription_show_live.ex:295-319` keeps recent deliveries secondary.
- Changing receiver dedupe to lineage-root semantics. `test/example/lib/example_web/controllers/sigra_webhook_controller.ex:10-18` and `test/example/lib/example/accounts/webhook_receipt.ex:27-48` already define the proof boundary.

## Likely Plan Slices

1. **Replay persistence + safety guards**
   Copy `lib/sigra/webhooks.ex:203-258`, `:374-433`, and `lib/sigra/webhooks/dispatcher.ex:110-139`.
   Add schema/migration fields on `webhook_deliveries`, enforce dead-letter-only replay, current-precondition checks, truth-gap rejection, and concurrent-child prevention.

2. **Admin mutation and read-model seams**
   Copy `lib/sigra/admin/webhooks/actions.ex:8-85`, `lib/sigra/admin/webhooks/detail.ex:13-70`, and `lib/sigra/admin/webhooks/failures.ex:59-146`.
   Add replay wrapper, eligibility/result loading, lineage queries, and inbox annotations.

3. **Admin UI authority + shortcut**
   Copy `lib/sigra/admin/live/webhook_delivery_show_live.ex:24-75` and `lib/sigra/admin/live/webhook_delivery_failures_live.ex:96-121`.
   Put confirm-and-replay on delivery detail; optionally add a narrow failures shortcut that still routes through the same truth.

4. **Proof and regression coverage**
   Copy `test/sigra/webhooks_integration_test.exs:670-729`, `:837-910`; `test/sigra/admin/webhooks_test.exs:411-578`; `test/example/priv/playwright/tests/admin-generated.spec.ts:154-249`, `:366-449`; `helpers/adminArtifacts.ts:149-217`.
   Prove fail -> inspect -> downstream repair -> replay child -> success, while original failed lineage remains visible.

## No Exact Analog Found

| File/Concern | Role | Data Flow | Reason |
|---|---|---|---|
| Replay lineage partial-uniqueness / transactional guard implementation | migration + service | CRUD | The codebase has no existing self-referential delivery lineage or parent-only uniqueness guard. Compose this from the existing delivery summary model plus transaction-owned insert patterns. |

## Metadata

**Analog search scope:** `lib/sigra/webhooks*`, `lib/sigra/admin/webhooks*`, `lib/sigra/admin/live/*webhook*`, `priv/templates/sigra.install/core/*webhook*`, `test/sigra/*webhook*`, `test/example/**/*webhook*`

**Key reusable seams identified**
- Library-owned durable mutation in `Sigra.Webhooks`
- Fresh delivery insertion in `Sigra.Webhooks.Dispatcher`
- Delivery-row truth + append-only attempts
- Admin authz wrappers and detail loaders
- `delivery_id`-based proof correlation across admin and receiver
