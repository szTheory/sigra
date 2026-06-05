---
phase: 159-cross-journey-coherence-sweep-seed-enrichment
plan: "03"
subsystem: demo-seeds
tags:
  - seeds
  - fixtures
  - idempotency
  - audit-trail
  - passkeys
  - memberships
  - invitations
dependency_graph:
  requires:
    - 159-01
    - 159-02
  provides:
    - enriched-seed-orchestrator
    - expired-invitation-fixture
    - grace-acme-membership-fixture
    - pat-passkey-fixture
    - fixt-04-audit-variety
  affects:
    - test/example/lib/example/demo/seeds.ex
    - test/example/test/example/demo/seeds_test.exs
tech_stack:
  added: []
  patterns:
    - upsert_passkey/2 extracted helper for multi-user passkey seeding
    - check-then-insert pattern for expired invitation (distinct email key)
    - @persona_audit_events list extension for lockstep idempotency guard
key_files:
  created: []
  modified:
    - test/example/lib/example/demo/seeds.ex
    - test/example/test/example/demo/seeds_test.exs
decisions:
  - Extracted upsert_passkey/2 helper from monolithic seed_passkey/1 to support multi-user passkey seeding cleanly
  - Used distinct email (expired-invite@demo.sigra.dev) for the expired invitation to avoid conflicts with the pending invite
  - Appended audit events to @persona_audit_events list (not inline Repo.insert!) to keep count-threshold guard correct
metrics:
  duration: 3m
  completed: "2026-06-04"
  tasks_completed: 2
  files_modified: 2
---

# Phase 159 Plan 03: Seed Enrichment — Wire New Personas + FIXT-01–05 Summary

Enriched seed orchestrator with expired invitation, grace Acme membership, pat passkey, and 4 new audit events. All 16 seeds_test.exs tests pass including idempotency.

## What Was Built

Four changes to `seeds.ex` (Task 1) and three changes to `seeds_test.exs` (Task 2) to deliver all FIXT-01 through FIXT-05 seed states.

### Task 1: seeds.ex — four changes

**CHANGE A (FIXT-01):** Added second invitation block inside `seed_invitation/1` for `expired-invite@demo.sigra.dev` with `expires_at: ~U[2026-01-01 00:00:00Z]` (real past). Uses identical check-then-insert pattern keyed on `(organization_id, email, is_nil(accepted_at), is_nil(revoked_at))`. The existing `invited@demo.sigra.dev` invitation is untouched — both pending and expired states render simultaneously on the org overview.

**CHANGE B (FIXT-02):** Added `grace = users["grace@demo.sigra.dev"]` lookup and `upsert_membership(grace.id, acme.id, :member)` call inside `seed_memberships/3` after the existing Acme block. Grace has `scheduled_deletion: true` in personas.ex (from Plan 02), so `maybe_schedule_deletion/2` already sets `deleted_at` + `scheduled_deletion_at` — the roster "Deletion scheduled" pill now has data.

**CHANGE C (FIXT-03):** Replaced monolithic `seed_passkey/1` with a version that calls `upsert_passkey/2` for both admin and pat. Extracted private `upsert_passkey(user, seed_string)` helper that computes `credential_id = :crypto.hash(:sha256, seed_string)` and `public_key = :crypto.hash(:sha256, seed_string <> "-pubkey")` then inserts with `on_conflict: :nothing, conflict_target: [:credential_id]`. Admin's seed string is identical to the original — idempotency preserved.

**CHANGE D (FIXT-04):** Appended 4 entries to `@persona_audit_events` at offsets 30–33 (sequential, no gaps):
- `{pat, auth.password.change, success, offset: 30, org: nil}`
- `{pat, auth.magic_link.sent, success, offset: 31, org: nil}`
- `{grace, api.token.create, success, offset: 32, org: :acme}`
- `{carol, auth.oauth.link, success, offset: 33, org: :acme}`

All use reserved prefixes (`auth.*`, `api.*`). Count-threshold guard at `seeds.ex:548` auto-covers new rows because it derives from `length(@audit_actions) + length(@persona_audit_events)` — no manual threshold to update (FIXT-05 lockstep D-05).

### Task 2: seeds_test.exs — three changes

**CHANGE A (FIXT-05):** Added `expired_invitations:` key to `snapshot_counts/0` scoped to `expired-invite@demo.sigra.dev`. The idempotency test (`first == second`) now enforces that the expired invite row is seeded exactly once and not duplicated on re-run.

**CHANGE B (three new tests):**
- `"grace is a deletion-scheduled Acme member"` — asserts `deleted_at/scheduled_deletion_at` non-nil and `membership_role(grace.id, acme.id) == :member`
- `"pat has no MFA credential but has a passkey row"` — asserts `mfa_count == 0` and `passkey_count >= 1`
- `"exactly one expired invitation for expired-invite@demo.sigra.dev"` — asserts length == 1 and `DateTime.compare(expires_at, utc_now()) == :lt`

**CHANGE C:** Added grace assertion to the membership shape test: `membership_role(grace.id, acme.id) == :member`.

## Verification

```
cd test/example && mix test test/example/demo/seeds_test.exs
# => 16 tests, 0 failures
```

Idempotency test passes — `first == second` on double run covers all new seed states including `expired_invitations` key.

## Deviations from Plan

None — plan executed exactly as written.

## Commits

| Task | Commit | Description |
|------|--------|-------------|
| Task 1 | 332d3c79 | feat(159-03): enrich seeds.ex with expired invite, grace Acme membership, pat passkey, FIXT-04 audit rows |
| Task 2 | 4261ad61 | feat(159-03): update seeds_test.exs — expired_invitations key, grace/pat/expired-invite tests |

## Self-Check: PASSED

- `test/example/lib/example/demo/seeds.ex` — modified, contains `expired-invite@demo.sigra.dev`, `grace@demo.sigra.dev`, `upsert_passkey`, `auth.password.change`
- `test/example/test/example/demo/seeds_test.exs` — modified, contains `expired_invitations`, grace/pat/expired-invite test blocks
- Commit 332d3c79 — verified in git log
- Commit 4261ad61 — verified in git log
- 16 tests, 0 failures confirmed
