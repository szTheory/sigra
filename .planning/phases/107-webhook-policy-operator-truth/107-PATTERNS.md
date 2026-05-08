# Phase 107: Webhook policy operator truth - Pattern Map

**Mapped:** 2026-05-07
**Files analyzed:** 7
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `lib/sigra/admin/live/webhook_delivery_show_live.ex` | component | request-response | `lib/sigra/admin/live/webhook_delivery_show_live.ex` | exact |
| `lib/sigra/admin/live/webhook_delivery_failures_live.ex` | component | request-response | `lib/sigra/admin/live/webhook_delivery_failures_live.ex` | exact |
| `test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs` | test | request-response | `test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs` | exact |
| `test/example/test/example_web/live/admin_webhook_failures_live_test.exs` | test | request-response | `test/example/test/example_web/live/admin_webhook_failures_live_test.exs` | exact |
| `test/example/priv/playwright/tests/admin-generated.spec.ts` | test | event-driven | `test/example/priv/playwright/tests/admin-generated.spec.ts` | exact |
| `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VERIFICATION.md` | test | transform | `.planning/phases/99-admin-and-generated-host-webhook-ux/99-VERIFICATION.md` | role-match |
| `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VALIDATION.md` | config | transform | `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VALIDATION.md` | exact |

## Pattern Assignments

### `lib/sigra/admin/live/webhook_delivery_show_live.ex` (component, request-response)

**Analog:** `lib/sigra/admin/live/webhook_delivery_show_live.ex`

**LiveView load pattern** ([webhook_delivery_show_live.ex:11-37](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_show_live.ex:11))
```elixir
def mount(_params, session, socket) do
  {:ok,
   socket
   |> assign_new(:current_scope, fn -> Map.get(session, "current_scope") end)
   |> assign_new(:admin_scope, fn -> Map.get(session, "admin_scope") end)
   |> assign(:sigra_config, runtime_config!())
   |> assign(:detail, nil)
   |> assign(:event, nil)
   |> assign(:replay_confirm_open, false)
   |> assign(:replay_delivery_id, nil)
   |> assign(:return_to, "/admin/webhooks/failures")
   |> assign(:page_title, "Webhook delivery")}
end

def handle_params(%{"id" => id} = params, _uri, socket) do
  detail = Detail.load_delivery!(socket.assigns.sigra_config, socket.assigns.admin_scope, id)
  event = load_event(socket.assigns.sigra_config, detail.delivery.webhook_event_id)
```

Planner guidance: keep Phase 107 additive. Reuse `@detail` from `Detail.load_delivery!/3`; do not introduce a second query path for policy truth.

**Authority-page section pattern** ([webhook_delivery_show_live.ex:86-159](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_show_live.ex:86))
```elixir
<section class="rounded-lg border border-base-300 bg-base-100 p-5">
  <h1 class="text-2xl font-semibold">Webhook delivery</h1>
  <div class="mt-4 space-y-2 text-sm">
    <h2 class="text-lg font-semibold">Current status</h2>
    <p>{human_status(@detail.delivery.status)}</p>
    <p>Delivery ID: {@detail.delivery.delivery_id}</p>
    ...
    <p :if={@detail.delivery.terminal_reason}>Terminal reason: {@detail.delivery.terminal_reason}</p>
  </div>
</section>

<section class="rounded-lg border border-base-300 bg-base-100 p-5">
  <h2 class="text-lg font-semibold">Replay delivery</h2>
  ...
</section>

<section class="rounded-lg border border-base-300 bg-base-100 p-5">
  <h2 class="text-lg font-semibold">Attempt timeline</h2>
  ...
</section>
```

Planner guidance: implement the policy truth as a sibling card between existing top-level cards. Match the repeated `rounded-lg border ... bg-base-100 p-5` section idiom; do not merge policy copy into the replay or attempt sections.

**Conditional detail-card pattern to copy** ([webhook_delivery_show_live.ex:102-125](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_show_live.ex:102))
```elixir
<section class="rounded-lg border border-base-300 bg-base-100 p-5">
  <h2 class="text-lg font-semibold">Replay delivery</h2>
  <p class="mt-2 text-sm">{replay_copy(@detail.replay)}</p>

  <button
    :if={@detail.replay.eligible?}
    type="button"
    phx-click="open_replay"
    class="btn btn-primary min-h-11 mt-4"
  >
```

Planner guidance: the policy card should gate on `@detail.policy.blocked?` and use the same `:if={...}` conditional rendering style. Use short factual paragraphs/fields inside the card rather than a custom component or tabs.

**Read-model contract already available** ([detail.ex:28-47](/Users/jon/projects/sigra/lib/sigra/admin/webhooks/detail.ex:28), [detail.ex:177-187](/Users/jon/projects/sigra/lib/sigra/admin/webhooks/detail.ex:177))
```elixir
%{
  delivery: delivery,
  attempts: attempts,
  policy: build_policy_detail(delivery),
  replay: replay,
  replay_parent: replay_parent,
  replay_root: replay_root,
  replay_children: replay_children
}

defp build_policy_detail(delivery) do
  if Map.get(delivery, :last_error_category) == "local_policy_error" do
    %{
      blocked?: true,
      reason: Map.get(delivery, :terminal_reason),
      detail: Map.get(delivery, :last_error_detail)
    }
```

Planner guidance: render `@detail.policy.reason` and `@detail.policy.detail` directly. Preserve the stable reason code verbatim; any friendlier label must remain adjacent to the canonical value, not replace it.

---

### `lib/sigra/admin/live/webhook_delivery_failures_live.ex` (component, request-response)

**Analog:** `lib/sigra/admin/live/webhook_delivery_failures_live.ex`

**Compact row-shell pattern** ([webhook_delivery_failures_live.ex:96-123](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_failures_live.ex:96))
```elixir
<article :for={row <- @rows} class="rounded-lg border border-base-300 bg-base-100 p-4">
  <div class="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
    <div class="space-y-1 text-sm">
      <p class="font-semibold">{row.subscription && row.subscription.description || row.delivery.endpoint_url}</p>
      <p>Delivery ID: {row.delivery.delivery_id}</p>
      <p>{row.delivery.endpoint_url}</p>
      <p>{human_status(row.delivery.status)}</p>
      <p :if={row.delivery.next_attempt_at}>
        Next attempt: {Calendar.strftime(row.delivery.next_attempt_at, "%Y-%m-%d %H:%M")}
      </p>
      <p :if={row.delivery.terminal_reason}>Terminal reason: {row.delivery.terminal_reason}</p>
      <p>{replay_badge(row)}</p>
    </div>
```

Planner guidance: keep the blocked-policy hint inline in this metadata stack. Add one compact policy badge/summary line inside the left column; do not add a nested card, accordion, or second action area.

**Action-column pattern** ([webhook_delivery_failures_live.ex:111-120](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_failures_live.ex:111))
```elixir
<div class="flex w-full flex-col gap-2 sm:w-auto">
  <a class="btn btn-primary min-h-11 w-full sm:w-auto" href={delivery_path(row.delivery.delivery_id)}>
    Open delivery
  </a>
  <a :if={row.replayable?} class="btn btn-outline min-h-11 w-full sm:w-auto" href={delivery_path(row.delivery.delivery_id)}>
    Replay
  </a>
```

Planner guidance: Phase 107 should not add policy-specific buttons. All policy truth stays in row copy and the detail page.

**Failures read-model contract** ([failures.ex:169-229](/Users/jon/projects/sigra/lib/sigra/admin/webhooks/failures.ex:169))
```elixir
%{
  delivery: delivery,
  subscription: subscription,
  replayable?: replay_reason == nil,
  replay_reason: replay_reason,
  policy_reason: policy_reason(delivery),
  policy_detail: policy_detail(delivery),
  replay_child_delivery_id: replay_child && replay_child.delivery_id,
  replay_parent_delivery_id: replay_source && replay_source.delivery_id
}

defp policy_reason(delivery) do
  if Map.get(delivery, :last_error_category) == "local_policy_error" do
    Map.get(delivery, :terminal_reason)
  end
end
```

Planner guidance: row rendering should branch on `row.policy_reason`, not on ad hoc string matching against `terminal_reason` or status text.

**Page-level tone to preserve** ([webhook_delivery_failures_live.ex:57-70](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_failures_live.ex:57))
```elixir
<h1 class="text-2xl font-semibold">Webhook failures</h1>
<p class="text-sm text-base-content/70">Triage retrying and dead-lettered deliveries across subscriptions.</p>

<div class="flex flex-wrap gap-2">
  <a class="btn btn-outline min-h-11" href={index_path(%{"delivery_state" => "retrying"})}>Retrying</a>
  <a class="btn btn-outline min-h-11" href={index_path(%{"delivery_state" => "dead_lettered"})}>Dead lettered</a>
</div>
```

Planner guidance: keep the inbox taxonomy unchanged. If blocked deliveries appear, they still live inside the existing retrying/dead-lettered framing.

---

### `test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs` (test, request-response)

**Analog:** `test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs`

**Generated-host LiveView detail test shape** ([admin_webhook_delivery_show_live_test.exs:12-89](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs:12))
```elixir
test "delivery detail keeps replay lineage separate from the attempt timeline", %{conn: conn} do
  admin = platform_admin_fixture()
  subscription = webhook_subscription_fixture(%{description: "Timeline endpoint"})
  ...
  {:ok, _view, html} =
    conn
    |> log_in_user(admin)
    |> live("/admin/webhooks/deliveries/#{source.delivery_id}?return_to=%2Fadmin%2Fwebhooks%2Ffailures")

  assert html =~ "Webhook delivery"
  assert html =~ "Current status"
  assert html =~ "Attempt timeline"
  assert html =~ "Replay lineage"
```

Planner guidance: Phase 107 should add a focused blocked-policy test in the same fixture-first style. Assert the section heading, stable reason code, human detail, and the “no outbound request attempted” style copy in one end-to-end HTML render.

**Explicit state/assertion style** ([admin_webhook_delivery_show_live_test.exs:91-188](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs:91))
```elixir
assert replayable_html =~ "Replay delivery"
assert replayable_html =~ "Replay is available for this dead-lettered delivery."
...
assert in_flight_html =~ "Replay unavailable: this delivery is still in flight."
refute in_flight_html =~ "Confirm replay"
```

Planner guidance: keep assertions user-visible and literal. Do not assert only assigns or selectors when the requirement is operator truth copy.

**Policy fixture fields to reuse** ([webhooks_test.exs:478-513](/Users/jon/projects/sigra/test/sigra/admin/webhooks_test.exs:478))
```elixir
delivery_fixture(config, subscription, %{
  delivery_id: "del_blocked",
  status: "dead_lettered",
  attempt_count: 1,
  last_error_category: "local_policy_error",
  last_error_detail: "blocked by deployment callback",
  terminal_reason: "policy_denied",
  dead_lettered_at: ~U[2026-05-06 16:00:00Z]
})
```

Planner guidance: build the new LiveView test around `last_error_category: "local_policy_error"` plus canonical `terminal_reason` and `last_error_detail`; that matches the real persisted truth contract from Phase 105.

---

### `test/example/test/example_web/live/admin_webhook_failures_live_test.exs` (test, request-response)

**Analog:** `test/example/test/example_web/live/admin_webhook_failures_live_test.exs`

**Inbox truth test pattern** ([admin_webhook_failures_live_test.exs:9-79](/Users/jon/projects/sigra/test/example/test/example_web/live/admin_webhook_failures_live_test.exs:9))
```elixir
{:ok, _view, retrying_html} =
  conn
  |> log_in_user(admin)
  |> live("/admin/webhooks/failures?delivery_state=retrying")

assert retrying_html =~ "Webhook failures"
assert retrying_html =~ retrying.delivery_id
assert retrying_html =~ "Replay unavailable: this delivery is still in flight."
refute retrying_html =~ ">Replay<"
...
assert dead_letter_html =~ "Replay available"
assert dead_letter_html =~ "Already replayed"
assert dead_letter_html =~ "Open delivery"
```

Planner guidance: extend this file with a blocked-row case that asserts compact row truth only: blocked badge/copy, policy reason label, one-line detail or fallback, and no policy action controls.

**Query truth already proven below LiveView** ([webhooks_test.exs:505-513](/Users/jon/projects/sigra/test/sigra/admin/webhooks_test.exs:505))
```elixir
assert %{policy: %{blocked?: true, reason: "policy_denied", detail: "blocked by deployment callback"}} =
         Detail.load_delivery!(config, admin_scope, "del_blocked")

assert {:ok, {[row], _meta, _normalized}} =
         Failures.list_deliveries(config, admin_scope, %{"delivery_state" => "dead_lettered"})

assert row.policy_reason == "policy_denied"
assert row.policy_detail == "blocked by deployment callback"
```

Planner guidance: the Phase 107 LiveView tests should sit one layer above these assertions. Do not duplicate query tests; prove the row copy actually surfaces this metadata.

---

### `test/example/priv/playwright/tests/admin-generated.spec.ts` (test, event-driven)

**Analog:** `test/example/priv/playwright/tests/admin-generated.spec.ts`

**Canonical generated-host proof workflow** ([admin-generated.spec.ts:322-479](/Users/jon/projects/sigra/test/example/priv/playwright/tests/admin-generated.spec.ts:322))
```ts
test("generated host canonical proof correlates failed source history with replay recovery", async ({
  browser,
  page,
}, testInfo) => {
  const proofUserEmail = buildProofUserEmail("generated-replay-proof-user");
  ...
  await waitForDeliveryText(
    page,
    description,
    "/admin/webhooks/failures?delivery_state=dead_lettered",
  );

  const deadLetterRow = page.locator("article").filter({ hasText: description }).first();
  ...
  await openDeliveryFromFailures(page, sourceDeliveryId);
  ...
  const sourceFailureScreenshot = await captureGeneratedHostProofArtifact(..., "failed-source-row.png");
  const sourceDetailScreenshot = await captureGeneratedHostProofArtifact(..., "source-delivery-detail.png");
  const replayDetailScreenshot = await captureGeneratedHostProofArtifact(..., "replay-delivery-detail.png");
```

Planner guidance: Phase 107’s proof should follow the same browser lane shape:
1. create or trigger the blocked condition,
2. land on `/admin/webhooks/failures?delivery_state=dead_lettered`,
3. capture the blocked row artifact,
4. open delivery detail,
5. capture the policy section artifact,
6. write a durable proof bundle.

**Artifact bundle write pattern** ([admin-generated.spec.ts:460-478](/Users/jon/projects/sigra/test/example/priv/playwright/tests/admin-generated.spec.ts:460))
```ts
writeGeneratedHostProofBundle({
  runAt: new Date().toISOString(),
  proofUserEmail,
  endpointUrl,
  subscriptionId,
  subscriptionScreenshot,
  sourceDeliveryId,
  replayDeliveryId,
  rootDeliveryId: sourceProof.lineage.root_delivery_id,
  sourceDeliveryStatus: sourceProof.delivery_status,
  replayDeliveryStatus: replayProof.delivery_status,
  sourceFailureScreenshot,
  sourceDetailScreenshot,
  replayDetailScreenshot,
  receiverVerification: {
```

Planner guidance: reuse the same durable-artifact approach, but Phase 107’s bundle should key truth around the blocked delivery id, reason/detail, and screenshots for failures row + detail page. Keep machine-readable fields aligned with the human README.

**Existing durable proof README pattern** ([webhook-delivery-replay/README.md:1-33](/Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-delivery-replay/README.md:1))
```md
# Generated Host Replay Proof

## Delivery lineage
- source delivery id: ...

## Receiver verification
- source delivery receiver verification: ...

## Screenshots
- failed source row: ...
- source delivery detail: ...

Artifacts:
- machine manifest: manifest.json
```

Planner guidance: Phase 107 should keep the same repaired-form evidence split: one human README with exact ids/screenshots plus one machine manifest. For blocked policy, replace replay lineage fields with blocked-delivery truth fields instead of inventing a new artifact format.

---

### `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VERIFICATION.md` (test, transform)

**Analog:** `.planning/phases/99-admin-and-generated-host-webhook-ux/99-VERIFICATION.md`

**Verification doc shape** ([99-VERIFICATION.md:1-36](/Users/jon/projects/sigra/.planning/phases/99-admin-and-generated-host-webhook-ux/99-VERIFICATION.md:1))
```md
---
phase: 99
verified: 2026-05-06T23:59:00Z
status: passed
score: 1/1 requirements verified
---

# Phase 99 — Verification

## Requirements
| ID | Result | Evidence |

## Evidence
- `...`

## Attestation
1. ...
```

Planner guidance: write `105-VERIFICATION.md` in this exact repaired-form structure. Make clear that Phase 105 implemented the behavior and Phase 107 closes the remaining operator-truth and evidence gap.

**Generated-host proof expectation to mirror** ([99-VERIFICATION.md:20-25](/Users/jon/projects/sigra/.planning/phases/99-admin-and-generated-host-webhook-ux/99-VERIFICATION.md:20))
```md
- `CLOAK_KEY=... mix test test/example/test/example_web/live/admin_webhook_failures_live_test.exs test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs --no-color`
- `cd test/example/priv/playwright && ... npx playwright test tests/admin-generated.spec.ts --project=admin-generated`
- `test -f .planning/uat-evidence/v1.22/generated-host-proof/README.md`
- `test -f .planning/uat-evidence/v1.22/generated-host-proof/manifest.json`
```

Planner guidance: Phase 107’s closeout should cite both executable coverage and durable artifact existence. Do not claim `WH-06` closed from unit tests alone.

---

### `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VALIDATION.md` (config, transform)

**Analog:** `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VALIDATION.md`

**Per-task verification table pattern** ([105-VALIDATION.md:37-46](/Users/jon/projects/sigra/.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VALIDATION.md:37))
```md
| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
| 105-02-01 | 02 | 2 | WH-06 | T-105-05 / T-105-06 | Admin detail/failures surfaces expose stable policy reason/detail truth | unit | `... mix test test/sigra/admin/webhooks_test.exs ...` | ✅ | ⬜ pending |
| 105-03-01 | 03 | 3 | WH-06 | T-105-11 / T-105-12 | Proof covers allowed send plus built-in and host-callback denials with no requester call on blocked paths | integration | `... mix test test/sigra/webhooks_egress_policy_proof_test.exs --no-color` | ❌ W0 | ⬜ pending |
```

Planner guidance: reconcile this file by turning the current pending/red rows into truthful post-Phase-107 status entries. Keep the table shape; update only the rows that `WH-06` closeout actually resolves.

**Manual-only validation pattern** ([105-VALIDATION.md:58-62](/Users/jon/projects/sigra/.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VALIDATION.md:58))
```md
| Behavior | Requirement | Why Manual | Test Instructions |
| Generated-host/operator wording remains understandable in the admin surface after blocked deliveries appear | WH-06 | Copy tone and page affordances are best spot-checked by a human after implementation | Run the generated host, create one blocked subscription/delivery case, and confirm the delivery detail and failures views distinguish local policy denial from receiver outage |
```

Planner guidance: preserve this honesty. Even after automated/browser proof lands, keep a manual readability check if the copy/tone claim remains subjective.

## Shared Patterns

### List/detail authority split
**Sources:** [99-CONTEXT.md](/Users/jon/projects/sigra/.planning/phases/99-admin-and-generated-host-webhook-ux/99-CONTEXT.md), [webhook_delivery_show_live.ex:86-159](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_show_live.ex:86), [webhook_delivery_failures_live.ex:96-123](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_failures_live.ex:96)
**Apply to:** both admin LiveViews and their tests

- Rich operator truth belongs on the shared delivery detail page.
- Failures inbox stays row-first and incident-fast.
- Any new policy truth in the inbox must remain compact and inline.

### Conditional section/card rendering
**Sources:** [webhook_delivery_show_live.ex:102-125](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_show_live.ex:102), [detail.ex:177-187](/Users/jon/projects/sigra/lib/sigra/admin/webhooks/detail.ex:177)
**Apply to:** delivery detail policy card

- Gate the section with `:if={@detail.policy.blocked?}`.
- Use the same card chrome and text rhythm as the replay/attempt cards.
- Show canonical reason code plus operator detail from the normalized policy payload.

### Compact row metadata
**Sources:** [webhook_delivery_failures_live.ex:97-109](/Users/jon/projects/sigra/lib/sigra/admin/live/webhook_delivery_failures_live.ex:97), [failures.ex:207-215](/Users/jon/projects/sigra/lib/sigra/admin/webhooks/failures.ex:207)
**Apply to:** failures inbox blocked rows

- Treat `row.policy_reason` and `row.policy_detail` as a narrow metadata line.
- Do not add new actions or widen the row into a detail card.
- Preserve `Open delivery` as the path to deeper truth.

### Generated-host proof bundling
**Sources:** [admin-generated.spec.ts:390-478](/Users/jon/projects/sigra/test/example/priv/playwright/tests/admin-generated.spec.ts:390), [webhook-delivery-replay/README.md:11-33](/Users/jon/projects/sigra/.planning/uat-evidence/v1.23/webhook-delivery-replay/README.md:11)
**Apply to:** blocked-policy browser proof and any new artifact bundle

- Capture the failures row and detail page as named screenshots.
- Correlate browser-visible truth with machine-readable proof data.
- Keep README + `manifest.json` as the durable artifact pair.

### Verification/validation reconciliation
**Sources:** [99-VERIFICATION.md:12-36](/Users/jon/projects/sigra/.planning/phases/99-admin-and-generated-host-webhook-ux/99-VERIFICATION.md:12), [105-VALIDATION.md:37-75](/Users/jon/projects/sigra/.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VALIDATION.md:37)
**Apply to:** `105-VERIFICATION.md`, `105-VALIDATION.md`, and any active-truth updates tied directly to `WH-06`

- Verification file is the authoritative closeout artifact.
- Validation file keeps the per-task table and manual-only honesty.
- Do not blur “implemented in Phase 105” with “operator proof/reconciliation closed in Phase 107.”

## No Analog Found

None. Phase 107 fits existing Sigra patterns; it should extend current LiveView, generated-host proof, and repaired-form verification idioms rather than inventing new ones.

## Metadata

**Analog search scope:** `lib/sigra/admin/live`, `lib/sigra/admin/webhooks`, `test/example/test/example_web/live`, `test/example/priv/playwright/tests`, `.planning/phases/99-*`, `.planning/phases/105-*`, `.planning/phases/106-*`, `.planning/uat-evidence/v1.23`
**Files scanned:** 17
**Pattern extraction date:** 2026-05-07
