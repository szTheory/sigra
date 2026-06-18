---
phase: 191-microcopy-ia-sweep
plan: "02"
subsystem: admin-copy
tags: [glossary, copy-enforcement, synonym-elimination, green-phase]
depends_on: [191-01]
requires: [COPY-01, COPY-02, COPY-03]
provides: [banned-synonym-elimination, chip-label-coherence, wR-04-fix]
affects:
  - lib/sigra/admin/live/index_live.ex
  - lib/sigra/admin/live/organization_live.ex
  - lib/sigra/admin/live/users_index_live.ex
  - lib/sigra/admin/live/user_show_live.ex
  - lib/sigra/admin/live/branding_live.ex
  - test/sigra/admin/components_test.exs
tech_stack:
  added: []
  patterns: [exact-string-substitution, pattern-matched-clause-insertion]
key_files:
  created: []
  modified:
    - lib/sigra/admin/live/index_live.ex
    - lib/sigra/admin/live/organization_live.ex
    - lib/sigra/admin/live/users_index_live.ex
    - lib/sigra/admin/live/user_show_live.ex
    - lib/sigra/admin/live/branding_live.ex
    - test/sigra/admin/components_test.exs
decisions:
  - "Auth-replica carve-out preserved: branding_live.ex lines 580-610 (sigra-auth--preview) untouched; only line 583 admin chrome heading fixed"
  - "Pre-existing install test failures (GoldenDiffTest, VaultPromotionTest) are not regressions — confirmed by stash-and-test on clean main"
  - "index_live.ex line 43 'review risky accounts' fixed to 'review risky users' — acceptance criteria required 0 matches for risky accounts even though research marked it OK"
  - "components_test.exs inner_block render string also updated (not just @notice_golden) — both must match for the assertion to pass"
metrics:
  duration: "~20 minutes"
  completed: "2026-06-18"
  tasks_completed: 2
  tasks_total: 2
  files_created: 0
  files_modified: 6
status: complete
---

# Phase 191 Plan 02: GREEN — Banned-Synonym Elimination Summary

Applied all 21 copy violations identified in RESEARCH.md §Exhaustive String Inventory across 5 admin LiveViews. Glossary drift guard turns GREEN. COPY-03 chip label coherence added. WR-04 inspect leak patched.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Apply copy violations to index_live.ex and organization_live.ex | bb9cfea5 | index_live.ex, organization_live.ex |
| 2 | Apply copy violations to users_index, user_show, branding; add chip_label clause; update components_test golden | 3e796fcf | users_index_live.ex, user_show_live.ex, branding_live.ex, components_test.exs |

## What Was Built

### Task 1 — index_live.ex + organization_live.ex

**index_live.ex — 6 edits:**
- L43: "review risky accounts" → "review risky users" (page copy intro)
- L49: "accounts need review" → "users need review" (notice warning)
- L50: "Review accounts" → "Review users" (notice_link label)
- L70: "Review risky accounts" → "Review risky users" (task_card title)
- L71: "deletion-scheduled accounts" → "deletion-scheduled users" (task_card body)
- L73: "Review locked" → "Review users" (incomplete action label fixed)
- L102: "Accounts registered since Monday UTC" → "Users registered since Monday UTC" (help text)

**organization_live.ex — 5 edits:**
- L67: "account needs"/"accounts need" → "member needs"/"members need" (org-surface notice)
- L67: "Review accounts" → "Review members" (notice_link label, org surface)
- L77: "Search org members, open account detail" → "Search organization members, open member detail"
- L82: "Investigate org events" → "Investigate organization events" (task_card title)
- L96: "invite teammates" → "invite members" (empty-state copy)

### Task 2 — users_index_live.ex + user_show_live.ex + branding_live.ex + components_test.exs

**users_index_live.ex — 3 string edits + 1 clause insertion:**
- L135: "Review the account before unlocking." → "Review the user before unlocking." (locked help text)
- L355: "Once accounts exist" → "Once users exist" (empty-state body)
- L647: "Last activity: Not available" → "Last activity: None recorded" (activity label)
- COPY-03: Added `defp chip_label("deleted", nil), do: "Deletion scheduled"` immediately before catch-all, after `"needs_review"` clause — "deleted" filter chip now shows "Deletion scheduled" consistent with status pill

**user_show_live.ex — 7 edits:**
- L193: `title="No active sessions."` → `title="No active sessions"` (empty_state — no trailing period per contract)
- L251: "This account is not currently attached to a tenant." → "This user is not a member of any organization."
- L258: "Recent Audit" → "Recent audit" (sentence case)
- L259-261: "Recent activity stays aligned with the full scoped audit history for this user." → "Shows the most recent events. Open the full audit to filter and export." (active voice, action-oriented)
- L278: "Session revocation uses Sigra's canonical session APIs." → "Revoking a session signs the user out of that device immediately." (plain language, avoids internal ref)
- L502: "Locked — revoke active logins and unlock below." → "Locked — revoke active sessions and unlock below." (logins→sessions)
- L508: "No MFA configured — recommend enabling a second factor." → "No MFA configured — ask the user to set up a second factor." (imperative, operator-directed)

**branding_live.ex — 3 edits (carve-out untouched):**
- L101: "generated login, account" → "generated sign-in, account" (page copy intro)
- L583: `<h2>Login preview</h2>` → `<h2>Sign-in preview</h2>` (admin chrome heading, outside carve-out)
- L731: `"Could not save auth branding: #{inspect(reason)}"` → `"Could not save auth branding. Check the values and try again."` (WR-04 fix — no raw Elixir terms in UI)

**components_test.exs — 2 edits:**
- L68: `@notice_golden` — "revoke active logins" → "revoke active sessions"
- L401: `inner_block` render string — "revoke active logins" → "revoke active sessions" (both must match)

## Verification Results

| Check | Result |
|-------|--------|
| `mix test test/sigra/admin/glossary_test.exs` — GREEN (0 violations) | PASS |
| `mix test test/sigra/admin/components_test.exs` — GREEN | PASS |
| `mix test` full suite | PASS (2399 tests, 0 additional failures; 2 pre-existing install-golden failures unrelated to this plan) |
| Carve-out intact: branding_live.ex lines 601/602/605 unchanged | PASS |
| `defp chip_label("deleted", nil), do: "Deletion scheduled"` before catch-all | PASS |
| `inspect(reason)` eliminated from branding_live.ex | PASS |
| `grep "Login preview" branding_live.ex` → 0 matches | PASS |
| `grep "logins" user_show_live.ex` → 0 matches | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated inner_block render string in components_test.exs (not just @notice_golden)**
- **Found during:** Task 2 test run — `mix test test/sigra/admin/components_test.exs` failed even after updating `@notice_golden`
- **Issue:** The test at line 396-407 renders the component using an `inner_block` with the hardcoded old string "revoke active logins". Updating only `@notice_golden` (what the plan specified) leaves the test rendering the old string and comparing it against the new golden — guaranteed mismatch.
- **Fix:** Updated line 401 `inner_block` render string from "revoke active logins" to "revoke active sessions" to match the golden.
- **Files modified:** `test/sigra/admin/components_test.exs`
- **Commit:** 3e796fcf

**2. [Acceptance Criteria Alignment] Fixed index_live.ex line 43 "risky accounts" → "risky users"**
- **Found during:** Task 1 verification grep — acceptance criteria specified 0 matches for "risky accounts"
- **Issue:** RESEARCH.md §index_live.ex marked line 43-44 as OK, but the acceptance criteria explicitly required `risky accounts` to return 0 matches in index_live.ex
- **Fix:** Changed "or review risky accounts" → "or review risky users" in the page copy intro at line 43
- **Files modified:** `lib/sigra/admin/live/index_live.ex`
- **Commit:** bb9cfea5

## Known Stubs

None. All edits are complete string substitutions; no placeholder copy remains. The `chip_label("deleted", nil)` clause is fully wired — "Deletion scheduled" is the live label for the deleted quick-filter chip.

## Threat Flags

None. All modified files are operator-console admin surfaces (behind auth, D-08 scope). The WR-04 fix (`inspect(reason)` → generic message) reduces information disclosure surface — a mitigation, not a new threat.

## Self-Check: PASSED

- lib/sigra/admin/live/index_live.ex exists: FOUND
- lib/sigra/admin/live/organization_live.ex exists: FOUND
- lib/sigra/admin/live/users_index_live.ex exists: FOUND
- lib/sigra/admin/live/user_show_live.ex exists: FOUND
- lib/sigra/admin/live/branding_live.ex exists: FOUND
- test/sigra/admin/components_test.exs exists: FOUND
- Commit bb9cfea5 exists: FOUND
- Commit 3e796fcf exists: FOUND
- `mix test test/sigra/admin/glossary_test.exs` passes GREEN: CONFIRMED
- `mix test test/sigra/admin/components_test.exs` passes GREEN: CONFIRMED
- `mix test` full suite: 2399 tests, 0 new failures (2 pre-existing install-golden failures unrelated to this plan)
- Carve-out lines 601/602/605 unchanged: CONFIRMED
