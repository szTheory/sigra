---
phase: 98-reliable-delivery-pipeline
plan: 3
subsystem: webhooks
tags: [webhooks, integration, docs, dead-letter, delivery-history]
requires:
  - phase: 98-reliable-delivery-pipeline
    provides: bounded retry policy, dead-letter persistence, append-only attempt history
provides:
  - "Real Postgres-backed proof for retryable and terminal webhook failures"
  - "Adopter docs updated to the six-attempt persisted reliability contract"
  - "Receiver verification guidance updated for repeated attempts and stable `delivery_id` dedupe"
affects: [webhook-docs, generated-admin-history, receiver-implementations]
tech-stack:
  added: []
  patterns: [real-worker integration proof, docs aligned to persisted truth]
key-files:
  created: []
  modified:
    - test/sigra/webhooks_integration_test.exs
    - guides/flows/webhooks.md
    - guides/recipes/webhook-verification.md
key-decisions:
  - "Integration proof continues to use the same Postgres harness rather than a second fake reliability environment."
  - "Receiver docs treat `delivery_id` as the stable dedupe key across retries and call out fresh per-attempt timestamps/signatures."
patterns-established:
  - "When persisted reliability semantics change, extend the real worker-path integration harness and the receiver docs in the same slice."
requirements-completed: [WH-02]
duration: 1 session
completed: 2026-05-06
---

# Phase 98 Plan 3: End-to-End Reliability Proof Summary

**The real worker path now proves retry and dead-letter outcomes against Postgres, and the webhook docs match the implemented six-attempt persisted contract**

## Performance

- **Duration:** 1 session
- **Completed:** 2026-05-06
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Extended the Postgres-backed integration harness with a retryable `429 + Retry-After` path and a permanent `404` dead-letter path, both using the real worker seam and Sigra-owned tables only.
- Updated the feature guide to document the six total attempts, nominal schedule, append-only attempt history, in-place dead-letter semantics, and remaining non-goals.
- Updated the receiver-verification recipe to explain stable `delivery_id` dedupe across retries plus fresh per-attempt timestamps and signatures.

## Task Commits

1. **Task 1: Extend the Postgres-backed integration proof for retries, dead-letter, and history truth** - `c87e978`
2. **Task 2: Update the webhook docs to match the Phase 98 persisted reliability contract** - `af36c49`

## Files Created/Modified

- `test/sigra/webhooks_integration_test.exs` - Real worker-path retry/dead-letter assertions against Postgres-backed delivery and attempt rows.
- `guides/flows/webhooks.md` - Feature-level reliability contract and operator-visible persisted-state description.
- `guides/recipes/webhook-verification.md` - Receiver guidance for repeated attempts, stable `delivery_id`, fresh timestamps, and dead-letter scope.

## Decisions Made

- Kept the docs explicit that manual replay, automatic subscription disablement, and a separate dead-letter subsystem remain out of scope.
- Used the same auth-path registration harness for the end-to-end proof so webhook failure behavior is validated where adopters will actually feel it.

## Deviations from Plan

None in scope. The integration proof stayed centered on persisted retry/dead-letter truth and the existing auth-path harness.

## Issues Encountered

None after the Wave 1 `dispatched_at` regression was corrected.

## User Setup Required

None.

## Next Phase Readiness

- Phase 99 can build operator-facing delivery history and subscription management on top of verified persisted summary/attempt rows and docs that already describe those semantics accurately.
- Receiver implementers now have guidance that matches the code Sigra actually ships today, not the Phase 97 pre-reliability contract.

## Self-Check

PASSED

- `mix compile --warnings-as-errors`
- `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/webhooks_integration_test.exs --no-color`
- `rg -n "dead_lettered|attempt_count|next_attempt_at|Retry-After|six total attempts|delivery_id" test/sigra/webhooks_integration_test.exs guides/flows/webhooks.md guides/recipes/webhook-verification.md`

---
*Phase: 98-reliable-delivery-pipeline*
*Completed: 2026-05-06*
