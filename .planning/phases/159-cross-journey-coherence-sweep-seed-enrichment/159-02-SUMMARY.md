---
phase: 159-cross-journey-coherence-sweep-seed-enrichment
plan: "02"
subsystem: demo-seed
tags:
  - personas
  - seed-data
  - demo
dependency_graph:
  requires: []
  provides:
    - personas.all/0 with 9 personas (pat, grace added)
    - personas.feature_map/0 with 9 entries
  affects:
    - test/example/lib/example/demo/seeds.ex (Plan 03 consumer)
    - test/example/lib/example_web/live/demo/credentials_live.ex (feature_map consumer)
tech_stack:
  added: []
  patterns:
    - Pure-data module with no DB access
key_files:
  created: []
  modified:
    - test/example/lib/example/demo/personas.ex
    - test/example/test/example/demo/personas_test.exs
decisions:
  - Pat persona: totp=false, passkey=true — the only persona satisfying Passkeys (no-MFA) pill condition
  - Grace persona: scheduled_deletion=true, org_member=:acme — only Acme roster member with deleted_at set
  - Test file updated from 7→9 expected personas to keep test suite consistent with data module
metrics:
  duration: "~4 minutes"
  completed_date: "2026-06-04T22:04:46Z"
  tasks_completed: 1
  files_modified: 2
---

# Phase 159 Plan 02: Add Pat and Grace Demo Personas Summary

**One-liner:** Two new demo personas (pat passkey-only, grace deletion-scheduled Acme member) added to personas.ex all/0 and feature_map/0, expanding the catalog from 7 to 9 entries.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add pat and grace personas to all/0 and feature_map/0 | a5c4f9a4 | test/example/lib/example/demo/personas.ex, test/example/test/example/demo/personas_test.exs |

## What Was Built

Added two new demo personas to `test/example/lib/example/demo/personas.ex`:

**Pat** (`pat@demo.sigra.dev`): Passkey-only user with `totp: false, passkey: true, org_member: nil`. This is the only persona satisfying the "Passkeys (no-MFA)" pill condition in the users index LiveView (requires `NOT has_mfa AND passkey_count > 0`).

**Grace** (`grace@demo.sigra.dev`): Deletion-scheduled Acme member with `scheduled_deletion: true, org_member: :acme`. This is the only persona satisfying the in-roster "Deletion scheduled" pill condition (requires `member.deletion_scheduled? = true` AND org membership).

Both personas have all 11 required map keys: `email, display_name, password, confirmed, totp, passkey, locked, scheduled_deletion, identity_github, org_owner, org_admin, org_member`.

Updated `feature_map/0` with matching entries for both new personas:
- `"pat"` => "Passkey-only user — no MFA, passkey display row, demonstrates Passkeys pill on users index"
- `"grace"` => "Deletion-scheduled Acme member — demonstrates in-roster Deletion scheduled pill"

Updated module docs and @doc strings from "seven" to "nine" throughout.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated personas_test.exs to match new 9-persona count**
- **Found during:** Task 1 (post-change test run)
- **Issue:** `personas_test.exs` had hardcoded `length(personas) == 7` assertion and `@expected_handles` with only 7 handles. Running tests produced 7 failures.
- **Fix:** Updated `@expected_handles` to include `pat` and `grace`, changed count assertion from 7 to 9, updated test name from "seven" to "nine"
- **Files modified:** `test/example/test/example/demo/personas_test.exs`
- **Commit:** a5c4f9a4 (included in same commit as the main change)
- **Note:** Pre-existing test infrastructure issue (tests fail when run from main project root via `mix test`; must be run from `test/example/` directory). This is not related to this plan's changes.

## Verification Results

```
grep -n "pat@demo\|grace@demo\|\"pat\"\|\"grace\"" test/example/lib/example/demo/personas.ex
139:        email: "pat@demo.sigra.dev",
153:        email: "grace@demo.sigra.dev",
184:      "pat"   => "Passkey-only user — no MFA, passkey display row, demonstrates Passkeys pill on users index",
185:      "grace" => "Deletion-scheduled Acme member — demonstrates in-roster Deletion scheduled pill"

grep -c "email:" personas.ex => 9 (correct)
```

Tests pass when run from `test/example/` directory (8 tests, 0 failures).

## Known Stubs

None — this is a pure-data module with no stubs.

## Threat Flags

None — this plan only adds public-by-design demo credentials to an existing pure-data module. All persona passwords are intentionally public fixtures per the existing module docstring contract. No new trust boundaries introduced.

## Self-Check: PASSED

- [x] test/example/lib/example/demo/personas.ex exists with 9 personas
- [x] test/example/test/example/demo/personas_test.exs updated to 9 personas
- [x] Commit a5c4f9a4 exists
- [x] pat@demo.sigra.dev: totp=false, passkey=true
- [x] grace@demo.sigra.dev: scheduled_deletion=true, org_member=:acme
- [x] feature_map/0 has "pat" and "grace" keys
- [x] All 11 persona map keys present in both new personas
