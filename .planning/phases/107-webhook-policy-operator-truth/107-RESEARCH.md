# Phase 107: Webhook policy operator truth - Research

**Researched:** 2026-05-07
**Status:** Ready for planning

## Summary

Phase 107 is a bounded finish pass on `WH-06`, not a new webhook feature phase. The core runtime and read-model work already exists from Phase 105:

- `Sigra.Admin.Webhooks.Detail.load_delivery!/3` already returns `policy: %{blocked?, reason, detail}` for `local_policy_error`.
- `Sigra.Admin.Webhooks.Failures.list_deliveries/3` already returns `policy_reason` and `policy_detail` on blocked rows.
- The current gap is presentation and proof: `WebhookDeliveryShowLive` and `WebhookDeliveryFailuresLive` do not render that truth, generated-host LiveView tests do not assert it, and Phase 105 still lacks authoritative verification/validation closeout.

The safest decomposition is three plans:

1. Surface blocked-policy truth in the shared admin LiveViews and generated-host LiveView tests.
2. Add denied-path generated-host/browser proof and publish `105-VERIFICATION.md`.
3. Reconcile `105-VALIDATION.md` and active truth files that still describe Phase 105 as draft/missing.

## Current State

### Already implemented

- Worker-side endpoint policy enforcement and truthful persistence exist from Phase 105 Plan 01.
- Admin read models already expose blocked-policy fields from persisted delivery truth.
- A focused proof test already exists at `test/sigra/webhooks_egress_policy_proof_test.exs` for allowed and denied worker paths.
- Docs and generated-host policy seams already landed in Phase 105 Plan 03.

### Missing

- `lib/sigra/admin/live/webhook_delivery_show_live.ex` does not render `@detail.policy`.
- `lib/sigra/admin/live/webhook_delivery_failures_live.ex` does not render `row.policy_reason` / `row.policy_detail`.
- Generated-host LiveView coverage does not assert blocked-policy copy on either operator surface.
- There is no generated-host/browser proof bundle for the denied-path operator workflow.
- `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VERIFICATION.md` is missing.
- `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VALIDATION.md` still says `status: draft`, `nyquist_compliant: false`, and `wave_0_complete: false` despite the proof test file now existing.

## Code Touch Points

### UI surfaces

- `lib/sigra/admin/live/webhook_delivery_show_live.ex`
  - Add a conditional `Endpoint policy result` section gated by `@detail.policy.blocked?`.
  - Keep it between `Current status` and `Replay delivery`.
  - Render canonical reason code and operator detail separately.

- `lib/sigra/admin/live/webhook_delivery_failures_live.ex`
  - Keep the current row-first layout.
  - Add compact inline blocked-policy truth inside the left metadata stack when `row.policy_reason` is present.
  - Do not add policy-specific actions or a new filter model.

### Tests

- `test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs`
  - Add a blocked-delivery case that asserts literal operator copy, the reason code, the detail string, and the local-denial framing.

- `test/example/test/example_web/live/admin_webhook_failures_live_test.exs`
  - Add a blocked-row case that asserts compact row truth, fallback/action behavior, and absence of new controls.

- `test/sigra/admin/webhooks_test.exs`
  - Existing query-layer assertions are already sufficient as the lower seam; this file may need only minimal extension if the planner wants tighter fallback coverage.

### Proof and closeout artifacts

- `test/example/priv/playwright/tests/admin-generated.spec.ts`
  - Extend the existing artifact flow with a blocked-policy scenario and screenshots for failures row + delivery detail.

- `.planning/uat-evidence/v1.23/...`
  - Publish a new denied-path proof bundle parallel to the replay bundle shape: README + manifest + screenshots.

- `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VERIFICATION.md`
  - Write repaired-form authoritative verification for `WH-06`.

- `.planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VALIDATION.md`
  - Reconcile the validation contract to reflect the shipped proof file and current Nyquist posture.

## Recommended Plan Decomposition

### Plan 01: Admin operator truth surfaces

Deliver:

- conditional policy card in delivery detail
- compact blocked-policy summary in failures inbox
- generated-host LiveView tests for both surfaces

Verification:

- `mix compile --warnings-as-errors`
- `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs --no-color`

### Plan 02: Denied-path generated-host proof and Phase 105 verification

Deliver:

- blocked-policy browser/proof scenario
- evidence bundle with screenshots and machine-readable manifest
- authoritative `105-VERIFICATION.md`

Verification:

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_egress_policy_proof_test.exs --no-color`
- generated-host/browser proof command from the existing Playwright flow, extended for blocked-policy artifacts
- integrity checks over the resulting README/manifest/screenshots

### Plan 03: Validation and active-truth reconciliation

Deliver:

- updated `105-VALIDATION.md`
- bounded updates to active truth files only if they still contradict the new `WH-06` closeout state

Likely touched files:

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/STATE.md`
- `.planning/v1.23-MILESTONE-AUDIT.md`

Verification:

- grep-based consistency checks across the reconciled files

## Risks And Sequencing Traps

### 1. Mixing policy truth into replay truth

The current UI already has strong replay/detail separation. Phase 107 should add a sibling policy section, not overload `Current status`, `Replay delivery`, or `Attempt timeline` with denial explanation.

### 2. Row bloat in the failures inbox

The inbox must stay triage-fast. A badge plus one compact `Policy reason: {reason} - {detail}` line is enough. Anything heavier should defer to `Open delivery`.

### 3. Over-claiming verification from unit/query proof alone

`WH-06` is blocked specifically because operators cannot see the truth. The required proof must include actual LiveView/browser-visible evidence, not only worker or read-model tests.

### 4. Broad historical cleanup

Follow the Phase 106 precedent: reconcile only active truth files. Do not turn this into archaeology across archived milestone artifacts.

## Recommended Verification Commands

- `mix compile --warnings-as-errors`
- `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/example/test/example_web/live/admin_webhook_delivery_show_live_test.exs test/example/test/example_web/live/admin_webhook_failures_live_test.exs --no-color`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_egress_policy_proof_test.exs --no-color`
- generated-host Playwright command extended to capture blocked failures-row and delivery-detail screenshots
- `rg -n "WH-06|105-VERIFICATION.md|nyquist_compliant|wave_0_complete" .planning/ROADMAP.md .planning/REQUIREMENTS.md .planning/STATE.md .planning/v1.23-MILESTONE-AUDIT.md .planning/phases/105-webhook-egress-policy-and-deployment-controls/105-VALIDATION.md`

## Recommendation

Plan Phase 107 as three execution plans with strict sequencing:

1. UI truth and generated-host LiveView coverage.
2. Browser proof and authoritative Phase 105 verification.
3. Validation and bounded active-truth reconciliation.

That decomposition matches the actual blocker order, minimizes rework, and gives the checker a clean evidence chain from runtime truth to operator truth to milestone truth.
