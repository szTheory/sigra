---
phase: 103
slug: overlap-safe-webhook-secret-rotation
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-07
---

# Phase 103 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from `103-CONTEXT.md`, `103-RESEARCH.md`, and the executable plan set.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit, Phoenix LiveViewTest, generator fixture assertions, Playwright |
| **Config file** | `test/test_helper.exs`, `config/test.exs`, `test/example/mix.exs`, `test/example/priv/playwright/playwright.config.ts` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_signature_test.exs test/sigra/workers/webhook_delivery_test.exs --no-color` |
| **Wave merge smoke** | `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/webhooks_integration_test.exs test/sigra/webhooks_signature_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/admin/webhooks_test.exs test/sigra/install/generator_wiring_test.exs --no-color` |
| **Full suite command** | `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/webhooks_integration_test.exs test/sigra/webhooks_signature_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_rotation_overlap_test.exs test/sigra/admin/webhooks_test.exs test/sigra/install/generator_wiring_test.exs test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs test/example/test/example_web/controllers/sigra_webhook_controller_test.exs test/example/test/example_web/accounts_webhook_proof_test.exs --no-color && cd test/example/priv/playwright && EXAMPLE_DB_PROBE_ENABLED=1 CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= npx playwright test tests/admin-generated.spec.ts --project=admin-generated` |
| **Estimated runtime** | ~20-40 seconds quick loop, ~90-180 seconds focused full phase gate plus browser proof |

---

## Sampling Rate

- **After every task commit:** Run the task-level automated verify command from the touched plan.
- **After Plan 01 / wave 1:** Run `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/webhooks_integration_test.exs test/sigra/install/generator_wiring_test.exs --no-color`.
- **After Plans 02-03 / wave 2:** Run the wave merge smoke command above.
- **Before `$gsd-verify-work`:** Run the full suite command and confirm the evidence bundle exists under `.planning/uat-evidence/v1.23/webhook-secret-rotation/`.
- **Max feedback latency:** ~40 seconds for crypto/worker quick loop, ~180 seconds for the focused full phase gate including Playwright.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 103-01-01 | 01 | 1 | WH-04 | Lifecycle tests prove bounded current-plus-next secret state, explicit transitions, discard path, and rejection of illegal moves | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/webhooks_integration_test.exs --no-color` | ✅ extend | ⬜ pending |
| 103-01-02 | 01 | 1 | WH-04 | Example, live install templates, and generator seams stay aligned on dual-slot schema and migration wiring | integration | `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/webhooks_integration_test.exs test/sigra/install/generator_wiring_test.exs --no-color` | ✅ extend | ⬜ pending |
| 103-02-01 | 02 | 2 | WH-04 | Signature and worker tests prove overlap dual-signing, shared timestamp, single-secret pre/post states, and unchanged candidate-secret verification | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_signature_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_rotation_overlap_test.exs --no-color` | ✅ extend/create | ⬜ pending |
| 103-02-02 | 02 | 2 | WH-04 | Sender reloads current lifecycle state at execution time so retries remain replay-safe across overlap boundaries | integration | `MIX_ENV=test mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_signature_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_rotation_overlap_test.exs --no-color` | ✅ extend/create | ⬜ pending |
| 103-03-01 | 03 | 2 | WH-04 | LiveView test proves truthful lifecycle copy, action gating, and visible recent-delivery proof cues | integration | `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs --no-color` | ✅ extend | ⬜ pending |
| 103-03-02 | 03 | 2 | WH-04 | Admin mutation boundary and generated wrapper wiring stay aligned across library, example, and install templates | integration | `MIX_ENV=test mix compile --warnings-as-errors && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/sigra/install/generator_wiring_test.exs test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs --no-color` | ✅ extend | ⬜ pending |
| 103-04-01 | 04 | 3 | WH-04 | Example receiver verifies raw bodies against candidate secrets and preserves `delivery_id` dedupe across lifecycle stages | integration | `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/test/example_web/controllers/sigra_webhook_controller_test.exs test/example/test/example_web/accounts_webhook_proof_test.exs --no-color` | ✅ extend | ⬜ pending |
| 103-04-02 | 04 | 3 | WH-04 | Browser proof and artifact bundle prove pre-rotation, overlap, and post-retirement flows with receiver evidence enabled | browser/integration | `MIX_ENV=test mix compile --warnings-as-errors && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example/test/example_web/controllers/sigra_webhook_controller_test.exs test/example/test/example_web/accounts_webhook_proof_test.exs --no-color && cd test/example/priv/playwright && EXAMPLE_DB_PROBE_ENABLED=1 CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= npx playwright test tests/admin-generated.spec.ts --project=admin-generated && cd /Users/jon/projects/sigra && test -f .planning/uat-evidence/v1.23/webhook-secret-rotation/README.md && test -f .planning/uat-evidence/v1.23/webhook-secret-rotation/manifest.json` | ✅ extend | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| WH-04 | Lifecycle transitions enforce `prepare -> overlap -> complete` with bounded current-plus-next secret truth | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/webhooks_integration_test.exs --no-color` | ✅ extend |
| WH-04 | Overlap-active deliveries emit multiple `v1=` signatures over one shared timestamp and verify against candidate secrets with no `kid` | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_signature_test.exs test/sigra/workers/webhook_delivery_test.exs test/sigra/webhooks_rotation_overlap_test.exs --no-color` | ✅ extend/create |
| WH-04 | Admin detail truth and generated-host wrappers reflect lifecycle state and required next step honestly | integration | `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/example/test/example_web/live/admin_webhook_subscription_show_live_test.exs test/sigra/install/generator_wiring_test.exs --no-color` | ✅ extend |
| WH-04 | Docs and proof bundle cover pre-rotation, overlap, and post-retirement behavior with receiver evidence keyed by `delivery_id` | browser/integration | `cd test/example/priv/playwright && EXAMPLE_DB_PROBE_ENABLED=1 CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= npx playwright test tests/admin-generated.spec.ts --project=admin-generated` | ✅ extend |

---

## Wave 0 Requirements

No separate Wave 0 scaffold is required. Every plan begins with runnable automated verification in existing or explicitly-created test files, and the Playwright proof lane remains the final phase gate rather than a prerequisite bootstrap task.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Operator copy on the subscription detail page communicates the next safe rotation step without implying proof is complete too early | WH-04 | Product-language clarity is easier to judge in rendered UI than from string assertions alone | Open the example admin subscription detail page in each lifecycle state, confirm the CTA and copy match `stable`, `prepared`, `overlap_active`, and `completed`, and confirm recent deliveries remain visible as proof cues |

---

## Validation Sign-Off

- [x] All tasks have runnable automated verify commands
- [x] Sampling continuity: no 3 consecutive tasks without automated verification
- [x] No standalone Wave 0 scaffold remains
- [x] No watch-mode flags
- [x] Playwright proof lane explicitly enables `EXAMPLE_DB_PROBE_ENABLED=1`
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
