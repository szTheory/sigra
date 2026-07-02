---
status: complete
phase: quick-260602-i3m
plan: 01
subsystem: admin-ui / org-overview
tags: [admin, organizations, liveview, seeds, library-data-layer]
requires: [Sigra.Admin.Authorizer, Sigra.Admin.Scope, Sigra.Admin.Users.Query]
provides: [Sigra.Admin.Organizations.Detail, org-overview-members, org-overview-invitations, morgan-persona, admin-multi-session-seed]
affects: [lib/sigra/admin/live/organization_live.ex, test/example demo seeds]
key-files:
  created:
    - lib/sigra/admin/organizations/detail.ex
    - test/sigra/admin/organizations_detail_test.exs
  modified:
    - lib/sigra/admin/live/organization_live.ex
    - test/example/lib/example/demo/personas.ex
    - test/example/lib/example/demo/seeds.ex
    - test/example/test/example/demo/personas_test.exs
    - test/example/lib/example_web/live/demo/credentials_live.ex
decisions:
  - "Org data layer is org-scope-only (no global behavior) — these surfaces are inherently per-org."
  - "expired? computed in Elixir against DateTime.utc_now() to avoid DB-time skew; role ordering done in Elixir (owner/admin/member rank + downcased label)."
  - "Admin session timestamps set to {0, 6} microsecond precision explicitly; DateTime.truncate(:microsecond) on a second-precision anchor yields {0,0} which :utc_datetime_usec rejects."
  - "Reused existing sg-* primitives (sg-list/sg-list-row/sg-status-pill[data-tone]/sg-section-heading/sg-section-copy) — app.css untouched."
metrics:
  duration: ~55 min
  completed: 2026-06-02
---

# Phase quick-260602-i3m: Stage 6 — Org Overview Made Real Summary

Made the admin org overview a real screen: a library org-scoped data layer (member
roster + pending invitations, fails closed), rendered Members + Pending invitations
sections in `OrganizationLive`, and seeded a Morgan org-admin persona plus three
populated admin sessions.

## What changed (all 4 tasks)

**Task 1 — `Sigra.Admin.Organizations.Detail` (NEW library module)**
- `member_roster/2`: org-scoped member list (full user struct + role + `confirmed?`/`locked?`
  flags + display label). Inner-joins user, filters by `organization_id`, calls
  `Authorizer.authorize_organization!` first. Ordered owners → admins → members, then
  downcased display name. Returns `[]` when membership schema absent.
- `pending_invitations/2`: only pending rows (`accepted_at IS NULL AND revoked_at IS NULL`),
  `expired?` computed in Elixir against `now`. Returns `[]` when invitation schema absent.
- Schema resolution mirrors `Users.Detail.helpers/1` (`accounts_module/1` + `optional_schema/2`
  namespace inference). No new `Sigra.Config` keys.

**Task 2 — `test/sigra/admin/organizations_detail_test.exs` (NEW, 11 tests)**
- Mirrors `users_query_test` harness (`Sigra.Test.PostgresCase`, `@repo PostgresRepo`,
  `setup_all` DDL via `checkout_repo!`, test-local schemas + a test `Accounts` module
  namespacing `OrganizationInvitation` to exercise the production `optional_schema` path,
  plus a `BareAccounts` module for graceful-absence).
- Covers: roster scope-isolation (org2 members/invites excluded → fail closed), status flags,
  owner/admin/member ordering, pending-only invitations, expired flagging (past `~U[2020]`
  true / future `~U[2099]` false), empty results, and graceful schema absence.

**Task 3 — `OrganizationLive` render**
- mount loads `:members` + `:pending_invitations`. Two new `sg-card` sections added AFTER the
  posture strip (inside the outer stack): Members roster + Pending invitations, each with a
  teaching empty state. Role pills (`owner`/`admin` → `info`, `member` → `ok`), confirmed/
  unconfirmed/locked status pills, and `Expires <YYYY-MM-DD>` / `Expired` (risk) invite rows.
- Pinned `"Work inside this organization scope"`, the two task cards, the Scoped attention
  card, and the posture strip preserved exactly.

**Task 4 — Seed enrichment**
- 7th persona Morgan (`morgan@demo.sigra.dev`, `MorganDemo1!OrgAdmin`, confirmed, non-platform);
  new `org_admin` persona key added to all 7 personas; seeded as Acme Corp `:admin` membership.
- `seed_sessions/1`: 3 deterministic admin `UserSession` rows (IPs 203.0.113.10 /
  198.51.100.22 / 192.0.2.44, distinct UAs, staggered `last_active_at` anchored off
  `@seed_reference_ts` minus 0/1/3 days, usec-precision timestamps). Idempotent via
  `on_conflict: :nothing, conflict_target: [:hashed_token]` (unique index confirmed).
- Contract updates: `personas_test` (6→7 + morgan handle), `feature_map` morgan entry,
  moduledocs "six"→"seven" across personas/seeds/credentials_live.

## Gate results

| Gate | Result |
|------|--------|
| New library tests (`organizations_detail_test.exs`) | **11 tests, 0 failures** |
| Full admin library group (`test/sigra/admin/`) | 55 tests, 0 failures |
| Root `mix compile --warnings-as-errors` | clean |
| Example gate group (`admin_*_live_test`, `admin_shell_test`, `personas_test`) | **33 tests, 0 failures** |
| Example `mix compile --warnings-as-errors` | clean |
| Reseed `ecto.reset` (PGDATABASE=example_dev) | **RAN — EXIT 0** (drop/create/migrate/seed all succeeded; server was not holding the DB) |
| Reseed idempotency (2nd `seeds.exs` run) | EXIT 0, session count stable at 3 |

Verified post-reseed via psql: Morgan = `acme-corp` / `admin`; admin has 3 sessions with
distinct IPs and staggered `last_active_at`; counts stable across two runs.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] UserSession usec-precision timestamp**
- **Found during:** Task 4 reseed gate.
- **Issue:** `UserSession.last_active_at`/`inserted_at` are `:utc_datetime_usec`; seeding with a
  second-precision anchor (`DateTime.add(@seed_reference_ts, …, :second)`) raised
  `ArgumentError: :utc_datetime_usec expects microsecond precision`. `DateTime.truncate(:microsecond)`
  did NOT fix it — truncating a second-precision DateTime yields `{0, 0}` precision, still rejected.
- **Fix:** `Map.put(:microsecond, {0, 6})` on the computed datetime.
- **Files modified:** test/example/lib/example/demo/seeds.ex
- **Commit:** Task-4 commit (Morgan persona + multi-session seed).

## Flags (per scope)

- **Library-owned → restart + reseed to view:** `organizations/detail.ex` and
  `organization_live.ex` are path-dep library code (not hot-reloaded). The running demo server
  on port 4011 must be RESTARTED to render the new Members / Pending invitations sections. The
  reseed gate already ran here (server was not holding example_dev), so the DB now contains
  Morgan + the 3 admin sessions.
- **Baselines shift → Stage 8:** demo-showcase + admin-checkpoint Playwright baselines WILL shift
  from the new org-overview sections and the 7th persona. Snapshot refresh is deferred to Stage 8
  (no snapshots regenerated here). Morgan is additive (not in `DEMO_LOCALS`), so the demo-showcase
  subset assertions remain safe.
- **Optional items deferred:** the optional fresh-unconfirmed-not-locked persona and the optional
  identity-unlink / mfa-disable audit row were DEFERRED (per the scope's optional clause) to avoid
  bloat and to keep the audit count-threshold guard arithmetic untouched.
- **New-test pass count:** 11/11.
- **Reseed gate:** RAN (not skipped) — `ecto.reset` succeeded EXIT 0 and is idempotent.

## Self-Check: PASSED
- lib/sigra/admin/organizations/detail.ex — FOUND
- test/sigra/admin/organizations_detail_test.exs — FOUND
- lib/sigra/admin/live/organization_live.ex — modified
- test/example/lib/example/demo/personas.ex / seeds.ex / personas_test.exs / credentials_live.ex — modified
- Commits present on branch ui-admin-polish-demo-evidence (3 commits).
