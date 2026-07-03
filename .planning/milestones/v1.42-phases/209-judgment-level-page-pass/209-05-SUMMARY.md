---
phase: 209-judgment-level-page-pass
plan: "05"
subsystem: admin-ui
tags: [admin, audit, scope_ribbon, applied_chip, quality-ledger, page-pass]
status: complete

dependency_graph:
  requires: [209-02]
  provides: [audit-explorer-scope-ribbon-fixed, audit-chips-waiver-documented, users-index-no-regression-confirmed, ledger-evidence-refreshed]
  affects: [audit-index-live, audit-user-live, users-index-live, admin-quality-ledger]

tech_stack:
  added: []
  patterns:
    - "Audit Explorer Archetype post-form chip position documented as defined D-03 intentional pattern"
    - "per-page divergence D-09 waiver pattern for subject-scoped field absence"
    - "scope_ribbon-above-header canonical position enforced across all list/leaf pages"

key_files:
  created: []
  modified:
    - lib/sigra/admin/live/audit_index_live.ex
    - .planning/uat-evidence/v1.42-persona-jtbd/audit-index-live.md
    - .planning/uat-evidence/v1.42-persona-jtbd/audit-user-live.md
    - .planning/uat-evidence/v1.42-persona-jtbd/users-index-live.md
    - guides/reference/admin-quality-ledger.md

decisions:
  - "audit_index scope_ribbon moved above <header> — lone outlier vs siblings is now aligned (user_show_live, user_sessions_live, audit_user_live all render scope_ribbon before header)"
  - "chips-post-form asymmetry resolved via documented waiver: Audit Explorer Archetype D-03 explicitly defines chips as post-form (position [3], navigation-only <a> tags); List Archetype uses chips-inside-form for GET contract — two intentionally different archetypes"
  - "audit_user Effective-user absence resolved via D-09 waiver: per-user audit is subject-scoped at route level; effective_user filter is redundant in that context; documented legitimate per-page divergence"
  - "users_index chips-inside-form confirmed canonical (List Archetype D-01) — keep, no change"
  - "users_index phx-click toggle_filters confirmed acceptable divergence — keep, no change"
  - "users_index_live.ex:188 label='Total users' confirmed present as Plan-03 retained metric owner; this plan makes NO mutation (Plan 03 single-owns dedup)"

metrics:
  duration: "3m"
  completed: "2026-07-01"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 5
  commits: 2
---

# Phase 209 Plan 05: Audit Explorer + Users Index Coherence Pass Summary

Resolved cross-page composition actionable verdicts from the Wave-1 panel: moved audit_index_live scope_ribbon above the header (lone outlier fix), documented chips-post-form as the intentional Audit Explorer Archetype pattern, confirmed users_index no-regression, and refreshed ledger evidence strings.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | audit_index_live — move scope_ribbon above header + resolve chips-position asymmetry | 77025399 | audit_index_live.ex, audit-index-live.md, audit-user-live.md |
| 2 | users_index_live no-regression confirmation + ledger evidence refresh | cdaea9ea | users-index-live.md, admin-quality-ledger.md |

## What Was Built

**Task 1 — scope_ribbon fix + chips waiver:**

- `audit_index_live.ex`: Moved `<.scope_ribbon copy={scope_copy(@admin_scope)} />` from below `</header>` (former line 56) to above `<header class="sg-page-header">` (now line 52). The audit index was the lone outlier — all siblings (user_show_live, user_sessions_live, audit_user_live) render scope_ribbon before the header. UI-SPEC Interaction Contract enforced: "Scope ribbon position — Above the page `<header>` on every list/leaf page; NOT below."

- Chips-outside-form asymmetry: Resolved via **documented waiver**. The Audit Explorer Archetype in `admin-design-contract.md` explicitly defines chips as post-form at position [3]: "Navigation-only `<a>` tags, post-form." The `applied_chip` component contract even cites `audit_user_live.ex applied-chip cluster (post-form, contiguous with filter panel — see Audit Explorer Archetype for elevated composition)`. The List Archetype (users_index_live) uses chips-inside-form for GET contract participation (D-01). These are intentionally different archetypes — the post-form position is the correct Audit Explorer pattern, not a coherence gap. No DOM change to chips on either audit page.

- audit_user "Effective user" absence: Resolved via **D-09 waiver**. Per-user audit is subject-scoped at the route level (`/admin/users/:id/audit`); filtering by effective_user is redundant because the page subject IS the effective user. admin-design-contract.md D-09 documents this as legitimate per-page divergence.

**Task 2 — users_index confirmation + ledger refresh:**

- Confirmed `users_index_live.ex:107-114` chips-inside-form is canonical List Archetype D-01 pattern — keep, no change.
- Confirmed `users_index_live.ex:121-128` phx-click toggle_filters is acceptable divergence from CSS-only `<details>` — keep, no change.
- Confirmed `users_index_live.ex:188` `label="Total users"` present as Plan-03 retained metric owner. Made NO mutation to this side (Plan 03 single-owns the Total-users dedup by dropping the Overview side, index_live.ex:88).
- Refreshed quality ledger evidence strings for `audit-index-live`, `audit-user-live`, and `users-index-live` to reflect Phase 209-05 remediations and waivers. All tier digits unchanged (audit-index-live: 2, audit-user-live: 2, users-index-live: 2).

## Deviations from Plan

None — plan executed exactly as written. The chips-position asymmetry was resolved via documented-intentional waiver (Audit Explorer Archetype D-03) rather than code change, which is explicitly the preferred resolution per the plan: "Prefer the documented-intentional resolution unless the contract says otherwise (avoids needless baseline churn per D-05/Pitfall 5)."

## Verification Results

| Check | Result |
|-------|--------|
| `mix test test/sigra/admin/glossary_test.exs` | 2 tests, 0 failures |
| `quality-ledger-monotonic.sh --base origin/main` | PASS (36 cells checked) |
| `quality-ledger-monotonic.test.sh` self-test | 6 assertions pass |
| scope_ribbon not after `</header>` in audit_index_live.ex | PASS |
| `label="Total users"` present in users_index_live.ex | PASS |

## Known Stubs

None — this plan contains no stubs. All changes are either a single-element position fix (scope_ribbon) or documentation/waiver records.

## Self-Check: PASSED

- `lib/sigra/admin/live/audit_index_live.ex` — modified (scope_ribbon moved above header)
- `guides/reference/admin-quality-ledger.md` — modified (evidence strings refreshed for 3 pages)
- Panel docs updated with resolution notes for all 3 actionable verdicts
- Commits 77025399 and cdaea9ea exist in git log
