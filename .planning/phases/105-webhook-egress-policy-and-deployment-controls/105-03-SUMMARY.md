---
phase: 105-webhook-egress-policy-and-deployment-controls
plan: 03
subsystem: docs-and-proof
tags: [webhooks, deployment, docs, proof, generated-host]
requires:
  - phase: 105-webhook-egress-policy-and-deployment-controls
    provides: endpoint policy engine, operator truth, and generated-host seam from Plans 01-02
provides:
  - focused proof test for allowed and blocked delivery paths
  - webhook contract documentation for endpoint policy and local denials
  - deployment guidance covering app-layer and infrastructure-layer egress controls
affects: [guides-webhooks, deployment-recipe, generated-host-setup]
tech-stack:
  added: []
  patterns: [proof-oriented coverage, deployment-class guidance, generated-host operational checklist]
key-files:
  created:
    - .planning/phases/105-webhook-egress-policy-and-deployment-controls/105-03-SUMMARY.md
    - test/sigra/webhooks_egress_policy_proof_test.exs
  modified:
    - guides/flows/webhooks.md
    - guides/recipes/deployment.md
    - guides/recipes/webhook-verification.md
    - priv/templates/sigra.install/admin/webhook_receiver_setup.md
key-decisions:
  - "Proof coverage stays narrow and uses the real worker path instead of duplicating every unit-level assertion."
  - "Deployment docs explicitly pair webhook_endpoint_policy/1 with Kubernetes NetworkPolicy and Fly.io egress controls."
  - "Receiver verification docs clarify that blocked deliveries never reach the receiver and do not alter the HMAC contract."
patterns-established:
  - "Generated-host setup docs now treat webhook endpoint policy as a deployment concern, not just a code hook."
  - "Phase proof bundles can stay lightweight while still exercising allowed send, built-in denial, and callback denial paths."
requirements-completed: [WH-06]
duration: resumed execution pass
completed: 2026-05-07
---

# Phase 105 Plan 03: Deployment Guidance And Proof Summary

Shipped the deployment-facing guidance and proof-oriented verification bundle for the webhook egress policy contract.

## Accomplishments

- Added `test/sigra/webhooks_egress_policy_proof_test.exs` covering an allowed public delivery, a built-in blocked destination, and a host callback denial.
- Updated `guides/flows/webhooks.md` with the two-stage endpoint policy model, `local_policy_error`, and the generated-host seam.
- Updated `guides/recipes/deployment.md` with `webhook_endpoint_policy/1`, Kubernetes `NetworkPolicy`, Fly.io egress IP, and allowlist guidance.
- Updated receiver-facing docs and generated-host setup guidance so adopters know blocked deliveries never reach the receiver and where to verify them in admin history.

## Verification

PASSED

- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_egress_policy_proof_test.exs --no-color`
- `rg -n "webhook_endpoint_policy/1|local_policy_error|Kubernetes|NetworkPolicy|Fly.io|egress IP|allowlist|blocked delivery" guides/flows/webhooks.md guides/recipes/deployment.md guides/recipes/webhook-verification.md priv/templates/sigra.install/admin/webhook_receiver_setup.md`

## Notes

- This plan executed on a dirty worktree, so no atomic task commits were created.
- The proof file is intentionally narrow: it proves the end-to-end contract without replacing the deeper unit and admin suites from Plans 01-02.
