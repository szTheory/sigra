---
phase: 199-foundation-tier-2-scorecard-stress-fixtures
plan: 03
subsystem: testing
tags: [elixir, ecto, seeds, fixtures, demo-data, audit, pagination]

requires:
  - phase: 199-02
    provides: Phase 199 plans 01-02 — scorecard Tier-2 proxy definitions and monotonic guard self-test

provides:
  - Admin persona topped up to 29 self-tied audit events (>=25 FIXT-01 pagination threshold)
  - 36-user list-scale ugly bulk cohort seeded before personas (FIXT-02 pagination stress)
  - Pitfall-3 resolved: both persona-count queries exclude loadtest-* bulk users
  - Multi-session (3 sessions) and multi-org (2 memberships) breadth on admin documented as deliberate FIXT-02 cases
  - seeds_test.exs contract raised: admin_tied >=25, bulk-cohort count/exclusion/idempotency, breadth assertions

affects:
  - Phase 200 (users index elevation — needs list-scale + bulk cohort data)
  - Phase 201 (audit explorer elevation — needs >=25 admin events for pagination)
  - Phase 202 (user-detail elevation — needs sessions/memberships breadth)
  - Plan 199-04 (content-equivalence un-skip — depends on first-listed-user insert order fix from this plan)

tech-stack:
  added: []
  patterns:
    - "Count-threshold + Repo.transaction idempotency for non-uniquely-indexed bulk inserts (seeds.ex pattern)"
    - "loadtest-* local-part prefix on @demo.tasklane.test domain as Pitfall-3 bulk-cohort exclusion marker"
    - "Insert bulk cohort BEFORE personas in run/0 so personas stay newest (inserted_at DESC sort; Finding 1)"

key-files:
  created: []
  modified:
    - test/example/test/example/demo/seeds_test.exs
    - test/example/lib/example/demo/seeds.ex

key-decisions:
  - "Pitfall-3 resolution: bulk users use loadtest-* prefix on @demo.tasklane.test so not like(u.email, 'loadtest-%') excludes them from BOTH independent persona-count queries (snapshot_counts/0 and SEED-02/03 catalog count)"
  - "Bulk cohort size: 36 users (36 + 9 personas = 45 total, 2 pages at limit 25 without bloating CI time)"
  - "Admin audit top-up: 27 @audit_actions entries (9 new, offset_days 34-42) + 2 admin persona_audit_events = 29 total admin-tied (>=25 FIXT-01 threshold with margin)"
  - "Admin multi-session/multi-org breadth is already present (3 sessions, 2 orgs); Task 4 makes intent explicit via inline comments without structural change"
  - "seed_bulk_users() called FIRST in run/0 before seed_users() so personas remain newest rows (admin stays first-listed for content-equivalence test)"

patterns-established:
  - "Bulk-cohort seed step: count-threshold guard + Repo.transaction + upsert_user on_conflict path, mirroring seeds.ex:634-651"
  - "Pitfall-3 exclusion: apply not like(u.email, 'loadtest-%') to every domain-glob count that feeds a length(Personas.all()) assertion"

requirements-completed: [FIXT-01, FIXT-02]

coverage:
  - id: D1
    description: "Admin persona has >=25 self-tied audit events after run/0 (FIXT-01 pagination threshold)"
    requirement: FIXT-01
    verification:
      - kind: unit
        ref: "test/example/test/example/demo/seeds_test.exs#audit liveness (SEED-04) at least 25 audit events across at least 6 distinct actions, admin-tied (FIXT-01)"
        status: pass
    human_judgment: false

  - id: D2
    description: "Bulk cohort of 36 ugly users seeded before personas, idempotent, excluded from Personas.all() and both persona-count assertions (FIXT-02)"
    requirement: FIXT-02
    verification:
      - kind: unit
        ref: "test/example/test/example/demo/seeds_test.exs#bulk user cohort (FIXT-02) bulk cohort contains exactly @bulk_cohort_size users after run/0"
        status: pass
      - kind: unit
        ref: "test/example/test/example/demo/seeds_test.exs#bulk user cohort (FIXT-02) bulk cohort emails are absent from Personas.all()"
        status: pass
      - kind: unit
        ref: "test/example/test/example/demo/seeds_test.exs#bulk user cohort (FIXT-02) bulk count is stable across two run/0 calls (idempotency — SEED-01, FIXT-02)"
        status: pass
    human_judgment: false

  - id: D3
    description: "Admin persona has >=2 active UserSession rows AND >=2 OrganizationMembership rows (FIXT-02 multi-session/multi-org breadth)"
    requirement: FIXT-02
    verification:
      - kind: unit
        ref: "test/example/test/example/demo/seeds_test.exs#multi-session/multi-org breadth (FIXT-02, D-11) admin persona has >=2 active UserSession rows and >=2 OrganizationMembership rows"
        status: pass
    human_judgment: false

  - id: D4
    description: "BOTH length(Personas.all()) assertions stay green with bulk cohort present (Pitfall-3 resolved)"
    requirement: FIXT-02
    verification:
      - kind: unit
        ref: "test/example/test/example/demo/seeds_test.exs#idempotency (SEED-01) running run/0 twice yields identical counts"
        status: pass
      - kind: unit
        ref: "test/example/test/example/demo/seeds_test.exs#persona catalog + states (SEED-02, SEED-03) seeds exactly the @demo.tasklane.test persona catalog of users"
        status: pass
    human_judgment: false

duration: 6min
completed: 2026-06-25
status: complete
---

# Phase 199 Plan 03: Stress Fixtures — Admin Audit Top-Up + Bulk User Cohort + Breadth Summary

**29 admin self-tied audit events (>=25 FIXT-01 threshold), a 36-user ugly bulk loadtest cohort inserted before personas, and explicit FIXT-02 multi-session/multi-org breadth on admin — all idempotent with Pitfall-3 persona-count invariants intact.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-06-25T18:08:55Z
- **Completed:** 2026-06-25T18:14:57Z
- **Tasks:** 4
- **Files modified:** 2

## Accomplishments

- Admin persona topped from 20 to 29 self-tied audit events by extending `@audit_actions` with 9 new entries (offset_days 34-42, including one `error` outcome for full vocab coverage)
- 36-user ugly bulk cohort (`loadtest-NN-<hex>@demo.tasklane.test`, long display names with UUID-shaped identifiers) seeded before personas so admin stays first-listed at `/admin/users`
- Pitfall-3 resolved in seeds_test.exs: `not like(u.email, 'loadtest-%')` applied to BOTH independent persona-count queries so `first.demo_users == length(Personas.all())` (line 107) AND `count == length(Personas.all())` (line 126) stay green
- Admin's 3 sessions and 2 org memberships documented as deliberate FIXT-02 multi-session/multi-org breadth cases (with inline comments warning against reduction)
- seeds_test.exs contract raised and extended: `admin_tied >= 25`, bulk-cohort count/exclusion/idempotency tests, and multi-session/multi-org breadth assertion (all 21 seeds tests pass)

## Task Commits

1. **Task 1: Lock seeds_test contract** - `304d4deb` (test)
2. **Task 2: Top up admin to >=25 self-tied audit events** - `0adb3fdb` (feat)
3. **Task 3: Add 36-user ugly bulk user cohort** - `6ab94ae5` (feat)
4. **Task 4: Mark multi-session/multi-org breadth as deliberate FIXT-02** - `e7fced64` (feat)

## Files Created/Modified

- `test/example/test/example/demo/seeds_test.exs` — Added `UserSession` alias, `@bulk_cohort_size 36` module attribute, Pitfall-3 comment, `not like(u.email, 'loadtest-%')` exclusion to both persona-count queries, raised `admin_tied >= 25`, added bulk-cohort describe block (3 tests), added multi-session/multi-org breadth describe block (1 test)
- `test/example/lib/example/demo/seeds.ex` — Extended `@audit_actions` from 18 to 27 entries, added `@bulk_cohort_size 36`, added `seed_bulk_users/0` private function, inserted `seed_bulk_users()` call at the top of `run/0` before `seed_users()`, added FIXT-02 intent comments to `@admin_sessions` and admin membership pair

## Decisions Made

- Pitfall-3 resolution: `loadtest-` local-part prefix on `@demo.tasklane.test` domain (not a sub-domain) — both persona-count queries exclude it via `not like(u.email, "loadtest-%")`. Applied to BOTH snapshot_counts/0 (seeds_test.exs line ~40) AND the independent SEED-02/03 catalog count (line ~122). This was the safest approach requiring no count-query restructuring.
- Bulk cohort size 36: 36 + 9 personas = 45 total visible users across 2 pages at the `@default_limit 25` page size, providing a clear second page without bloating CI snapshot time.
- Admin audit top-up strategy: grow `@audit_actions` (not `persona_audit_events`) since those rows are inserted with `effective_user_id: admin.id` automatically. Count-threshold guard still references `length(@audit_actions)` (not hardcoded).
- Multi-session/multi-org breadth is comment-only in Task 4 — admin already had 3 sessions + 2 orgs satisfying the >=2 assertions from Day 1; the task made the intent explicit and added a guard-comment.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Known Stubs

None.

## Threat Flags

None. This plan touches only demo fixture data and test assertions; no new auth/crypto/network/schema surface introduced.

## Next Phase Readiness

- Plan 199-04 (content-equivalence un-skip) can proceed: admin is now guaranteed first-listed (bulk cohort seeded first, personas are newest), and admin carries 29 >=25 self-tied audit events for pagination.
- Phases 200-204 (admin UI elevation) have the data instrumentation they need: list-scale users for `/admin/users` pagination, >=25 admin events for `/admin/audit` and user-detail feed pagination, multi-session/multi-org breadth for per-user Sessions/Organizations panels.

---
*Phase: 199-foundation-tier-2-scorecard-stress-fixtures*
*Completed: 2026-06-25*

## Self-Check: PASSED

Files verified:
- FOUND: test/example/test/example/demo/seeds_test.exs
- FOUND: test/example/lib/example/demo/seeds.ex

Commits verified:
- FOUND: 304d4deb (Task 1)
- FOUND: 0adb3fdb (Task 2)
- FOUND: 6ab94ae5 (Task 3)
- FOUND: e7fced64 (Task 4)
