---
phase: 205-foundation
plan: "02"
subsystem: demo-fixtures
tags:
  - fixtures
  - seeds
  - personas
  - quality-guard
  - hardening
dependency_graph:
  requires:
    - 205-01-SUMMARY.md
  provides:
    - zoe zero-state persona (10th persona in Personas.all/0)
    - ghost-org (zero-member organization in seeds)
    - i18n/RTL loadtest overflow user
    - Seeds.bulk_cohort_size/0 public function
    - "@seconds_per_day module attribute replacing 3 literal 86_400 occurrences"
    - quality-ledger-monotonic.test.sh Test C (1→2 exits 0) and Test D (decorated cell invisible)
  affects:
    - test/example/lib/example/demo/personas.ex
    - test/example/lib/example/demo/seeds.ex
    - test/example/test/example/demo/seeds_test.exs
    - scripts/ci/quality-ledger-monotonic.test.sh
tech_stack:
  added: []
  patterns:
    - SSoT public function over duplicated module attribute (Seeds.bulk_cohort_size/0)
    - Named module attribute for magic numbers (@seconds_per_day)
    - Zero-state persona pattern for empty-panel testing
    - Extra loadtest user outside cohort size guard (i18n/RTL)
    - Empirical bash self-test for monotonic guard behavior documentation
key_files:
  created: []
  modified:
    - test/example/lib/example/demo/personas.ex
    - test/example/lib/example/demo/seeds.ex
    - test/example/test/example/demo/seeds_test.exs
    - scripts/ci/quality-ledger-monotonic.test.sh
decisions:
  - "D-16/D-17: zoe added as 10th persona (confirmed, all state false/nil) to give empty-panel navigation surface distinct from filter-to-nothing (D-15)"
  - "D-16: ghost-org seeded in seed_organizations/0 via upsert_organization/2; excluded from seed_memberships by returning {acme, beta, _ghost}"
  - "D-18: i18n/RTL user uses loadtest- prefix to stay out of Personas.all/0; seeded outside @bulk_cohort_size guard as an extra user; test excludes it from the 36-user count assertion"
  - "IN-02: Seeds.bulk_cohort_size/0 exposed as public function backed by @bulk_cohort_size attribute; test removed @bulk_cohort_size 36 local attribute and uses Seeds.bulk_cohort_size() at all call sites"
  - "IN-03: @seconds_per_day 86_400 extracted; all 3 DateTime.add 86_400 literals replaced"
  - "Test D behavior: decorated '2*' is correctly documented as invisible to the guard awk parse (exits 0, not protected) — this converts the ledger's prose warning into an empirically proven contract"
metrics:
  duration_minutes: 35
  completed_date: "2026-06-28"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 4
status: complete
---

# Phase 205 Plan 02: FIXT-01 Edge/Empty Fixtures + IN-01..IN-05 Hardening Summary

Zoe persona + ghost-org + i18n/RTL overflow user + Seeds.bulk_cohort_size/0 SSoT + @seconds_per_day extraction + quality-ledger self-test Tests C and D.

## What Was Built

### Task 1 — Add zoe persona to Personas.all/0 and feature_map/0 (D-16, D-17)

Added `zoe@demo.tasklane.test` as the 10th persona in `Personas.all/0`. Zoe is confirmed with all state fields false/nil (no TOTP, no passkey, no OAuth identity, no org membership). Added "zoe" key to `feature_map/0` with zero-state description. Updated `@moduledoc` to reflect 10 personas and document zoe's role as empty-panel surface driver. D-19 determinism: password is a static literal.

**Commit:** `aed13f63`

### Task 2 — Extend seeds.ex: ghost-org, zoe wiring, i18n/RTL user, IN-01/02/03 hardening (D-16, D-18, D-19, IN-01, IN-02, IN-03)

Applied 5 changes in order:

- **IN-01**: Added comment to `seed_bulk_users/0` confirm-branch: "Already confirmed — only reachable on partial-cohort re-runs (idempotency recovery path)"
- **IN-02**: Exposed `Seeds.bulk_cohort_size/0` as a public function backed by `@bulk_cohort_size 36`; no change to internal usage of the attribute
- **IN-03**: Extracted `@seconds_per_day 86_400` module attribute immediately after `@seed_reference_ts`; replaced all 3 `DateTime.add(..., 86_400, :second)` call-sites with `@seconds_per_day`
- **D-16 ghost-org**: Added `ghost = upsert_organization("Ghost Org", "ghost-org")` in `seed_organizations/0`; updated return to `{acme, beta, ghost}`; updated `run/0` to destructure `{acme, beta, _ghost}` — ghost receives no memberships or invitations
- **D-18 i18n/RTL user**: Added `loadtest-i18n-rtl@demo.tasklane.test` with display name `"张三李四 مستخدم café résumé 🌏 Test"` after the main cohort loop, with separate count-threshold guard (`< 1`), confirmed, static password `"I18nRtl1!LoadTest2026"`

`mix compile --warnings-as-errors` clean after all changes.

**Commit:** `01381378`

### Task 3 — Extend seeds_test.exs and quality-ledger-monotonic.test.sh (D-17, IN-02, IN-05)

**seeds_test.exs changes:**
- Removed `@bulk_cohort_size 36` module attribute; replaced with `Seeds.bulk_cohort_size()` at all 2 bulk cohort assertion call-sites (IN-02 SSoT)
- Updated `snapshot_counts/0` organizations query to include `"ghost-org"` (slug list now 3 orgs)
- Updated idempotency test organization assertion from `== 2` to `== 3`
- Added test "zoe is the zero-state persona with zero sessions, identities, orgs, and audit events" (0 UserSession, 0 UserIdentity, 0 OrganizationMembership, 0 AuditEvent, confirmed_at not nil)
- Added test "ghost-org has zero memberships and zero invitations" (0 OrganizationMembership, 0 OrganizationInvitation)
- Updated "Acme Corp and Beta Labs organizations exist" to also assert ghost-org
- Updated bulk cohort count tests to exclude `loadtest-i18n-rtl@demo.tasklane.test` (extra user outside the 36-user threshold)

**quality-ledger-monotonic.test.sh changes:**
- Added **Test C**: mutates `visual-baseline` from 1→2, runs guard, asserts exit 0 and no "tier decreased" in stderr (2 sub-checks)
- Added **Test D**: mutates `accessibility` from `2` to `2*` (decorated), runs guard, asserts exit 0 — proves the documented-but-dangerous behavior that decorated cells are invisible to the awk `/^[012]$/` parse and thus unprotected; includes explanatory comment

Script now reports: "6 passed, 0 failed" across 4 named tests (A/B/C/D). Both verification commands exit 0.

**Commit:** `cf5f6135`

## Verification Results

```
mix test test/example/test/example/demo/seeds_test.exs
=> 22 tests, 0 failures

bash scripts/ci/quality-ledger-monotonic.test.sh
=> 6 passed, 0 failed (quality-ledger-monotonic.test: PASS)
```

Plan verification criteria:
- `grep -c "bulk_cohort_size()" test/example/test/example/demo/seeds_test.exs` → 5 (≥2)
- `grep -c "^  @bulk_cohort_size" test/example/test/example/demo/seeds_test.exs` → 0 (removed)
- `grep -c "def bulk_cohort_size" test/example/lib/example/demo/seeds.ex` → 1
- `grep -c "@seconds_per_day" test/example/lib/example/demo/seeds.ex` → 4 (1 def + 3 use-sites)
- `grep -c "86_400" test/example/lib/example/demo/seeds.ex` → 1 (only the `@seconds_per_day 86_400` definition — 0 raw literals)
- `grep -c "ghost-org" test/example/lib/example/demo/seeds.ex` → 2
- `grep -c "zoe" test/example/lib/example/demo/personas.ex` → 2 (all/0 and feature_map/0)
- `grep -c "loadtest-i18n-rtl" test/example/lib/example/demo/seeds.ex` → 1

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] i18n/RTL user counted in bulk cohort test assertions**
- **Found during:** Task 3 execution
- **Issue:** The i18n/RTL overflow user (`loadtest-i18n-rtl@demo.tasklane.test`) uses the `loadtest-` prefix, which caused it to be counted by the `like(u.email, "loadtest-%")` query in the bulk cohort tests. The plan says this user is "EXTRA to the cohort, not counted in the 36" but the test query counted it, causing `got 37` instead of 36.
- **Fix:** Updated both bulk cohort count assertions in seeds_test.exs to exclude `loadtest-i18n-rtl@demo.tasklane.test` via `u.email != ^"loadtest-i18n-rtl@demo.tasklane.test"` condition. This preserves the D-18 design intent (user is extra to the 36) while keeping the tests green.
- **Files modified:** `test/example/test/example/demo/seeds_test.exs`
- **Commit:** `cf5f6135`

## Known Stubs

None. All new personas and seed data are fully wired.

## Threat Flags

No new threat-relevant surface added beyond what was analyzed in the plan's threat model (T-205-04 through T-205-07). No new network endpoints, auth paths, file access patterns, or schema changes introduced.

## Self-Check: PASSED

- [x] `test/example/lib/example/demo/personas.ex` modified — verified `length(Personas.all()) == 10`
- [x] `test/example/lib/example/demo/seeds.ex` modified — verified `mix compile --warnings-as-errors` clean
- [x] `test/example/test/example/demo/seeds_test.exs` modified — verified 22 tests, 0 failures
- [x] `scripts/ci/quality-ledger-monotonic.test.sh` modified — verified 6 passed, 0 failed
- [x] Commit `aed13f63` exists — Task 1 (zoe persona)
- [x] Commit `01381378` exists — Task 2 (seeds.ex hardening)
- [x] Commit `cf5f6135` exists — Task 3 (test extensions)
