---
phase: 105
slug: webhook-egress-policy-and-deployment-controls
status: verified
nyquist_compliant: true
wave_0_complete: true
created: 2026-05-07
---

# Phase 105 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | ExUnit + generated-host/example tests |
| **Config file** | `test/test_helper.exs` |
| **Quick run command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/workers/webhook_delivery_test.exs --no-color` |
| **Full suite command** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test --no-color` |
| **Estimated runtime** | ~120 seconds |

---

## Sampling Rate

- **After every task commit:** Run `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/workers/webhook_delivery_test.exs --no-color`
- **After every plan wave:** Run the plan-specific command from the relevant PLAN.md plus any docs `rg` checks
- **Before `$gsd-verify-work`:** Full suite must be green
- **Max feedback latency:** 120 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 105-01-01 | 01 | 1 | WH-06 | T-105-01 / T-105-02 | Unsafe destinations are rejected at write time and blocked before send | unit | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/workers/webhook_delivery_test.exs --no-color` | ✅ | ⬜ pending |
| 105-01-02 | 01 | 1 | WH-06 | T-105-01 / T-105-03 / T-105-04 | Worker re-checks all resolved A/AAAA answers and persists truthful `local_policy_error` outcomes | unit/integration | `mix compile --warnings-as-errors && PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_test.exs test/sigra/workers/webhook_delivery_test.exs --no-color` | ✅ | ⬜ pending |
| 105-02-01 | 02 | 2 | WH-06 | T-105-05 / T-105-06 | Admin detail/failures surfaces expose stable policy reason/detail truth | unit | `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/sigra/install/generator_wiring_test.exs --no-color` plus Phase 107 LiveView coverage `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/example_web/live/admin_webhook_delivery_show_live_test.exs test/example_web/live/admin_webhook_failures_live_test.exs --no-color` | ✅ | ✅ green |
| 105-02-02 | 02 | 2 | WH-06 | T-105-07 / T-105-08 | Generated host exposes `webhook_endpoint_policy/1` seam without moving policy ownership out of the library | unit | `mix compile --warnings-as-errors && CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/admin/webhooks_test.exs test/sigra/install/generator_wiring_test.exs --no-color` | ✅ | ⬜ pending |
| 105-03-01 | 03 | 3 | WH-06 | T-105-11 / T-105-12 | Proof covers allowed send plus built-in and host-callback denials with no requester call on blocked paths | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_egress_policy_proof_test.exs --no-color` plus generated-host/browser proof under `.planning/uat-evidence/v1.23/webhook-policy-operator-truth/` | ✅ | ✅ green |
| 105-03-02 | 03 | 3 | WH-06 | T-105-09 / T-105-10 | Docs name `webhook_endpoint_policy/1`, `local_policy_error`, and deployment control points | docs | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_egress_policy_proof_test.exs --no-color && rg -n "webhook_endpoint_policy/1|local_policy_error|Kubernetes|NetworkPolicy|Fly.io|egress IP|allowlist|blocked delivery" guides/flows/webhooks.md guides/recipes/deployment.md guides/recipes/webhook-verification.md priv/templates/sigra.install/admin/webhook_receiver_setup.md` with repaired-form closeout in `105-VERIFICATION.md` and blocked-policy browser evidence bundle `webhook-policy-operator-truth` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `test/sigra/webhooks_egress_policy_proof_test.exs` — proof file for allowed send plus built-in and callback denials

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Generated-host/operator wording remains understandable in the admin surface after blocked deliveries appear | WH-06 | Copy tone and page affordances still benefit from a human pass even though the automated LiveView and browser proof now cover the blocked-policy path | Optional supplement: run the generated host, create one blocked subscription/delivery case, and confirm the delivery detail and failures views distinguish local policy denial from receiver outage |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 120s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** complete — reconciled after Phase 107 blocked-policy operator-truth closeout and `105-VERIFICATION.md`
