---
phase: 205-foundation
plan: "04"
subsystem: ia-diagnostic
tags: [ia-diagnostic, persona-panel, admin-ui, rubric, sequencing, advisory]
dependency_graph:
  requires:
    - 205-01-SUMMARY.md (rubric instrument)
    - 205-02-SUMMARY.md (zoe + ghost-org fixtures)
  provides:
    - .planning/v1.42-IA-DIAGNOSTIC.md
  affects:
    - .planning/phases/206-*/PLAN.md (Users List sequencing)
    - .planning/phases/207-*/PLAN.md (Audit List sequencing)
    - .planning/phases/208-*/PLAN.md (Overview pages sequencing)
    - .planning/phases/209-*/PLAN.md (binding gate + User Detail)
    - .planning/phases/210-*/PLAN.md (Sessions sequencing)
    - .planning/phases/211-*/PLAN.md (Branding + terminal ratification)
tech_stack:
  added: []
  patterns:
    - Advisory diagnostic at diagnostic depth (one-pass, headline findings only)
    - D-07 anti-collision enforced (no bare integer in any table column-4)
    - D-13 double-gate avoidance (Phase 209 is single binding gate)
    - D-14 Impact×Effort 3-bin priority (High/Med/Low, P1/P2/P3)
    - kill-from-any-lens auto-promotion to ≥P2 applied
key_files:
  created:
    - .planning/v1.42-IA-DIAGNOSTIC.md
  modified: []
decisions:
  - D-12 implemented: advisory diagnostic committed to .planning/ root (not phases/ subdirectory) as planning artifact, not reference doc
  - D-13 double-gate avoidance: advisory notice is first substantive content; Phase 209 named explicitly as binding gate throughout
  - D-14 disposition table uses High/Med/Low for Impact/Effort and P1/P2/P3 for Priority; no bare integer in column-4
  - kill-from-any-lens auto-promotion: org-admin kill on Global Overview and Branding correctly categorized as intended access control (correct 403), not surface flaws — avoids false-positive kill promotion
  - "Feeds phase" column populated for all 15 disposition rows pointing to Phases 206-211
  - zoe zero-state incorporated: all 4 panels (Sessions/Identities/Organizations/Recent audit) empty simultaneously; empty copy consistency gap noted for Phase 209
  - ghost-org empty-state incorporated: bare <p> vs <.empty_state> component coherence gap for organization-live zero-member roster
metrics:
  duration_minutes: 4
  completed_date: "2026-06-28"
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 0
status: complete
---

# Phase 205 Plan 04: Foundation — IA Diagnostic Summary

Advisory persona-panel diagnostic across all 8 admin pages applying the admin-persona-jtbd-rubric.md instrument at diagnostic depth — 3-lens × 3-question matrices, empty-entity observations from zoe and ghost-org, and a 15-row prioritized disposition list sequencing Phases 206-211.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Author .planning/v1.42-IA-DIAGNOSTIC.md | 6f472b7e | .planning/v1.42-IA-DIAGNOSTIC.md (created, 287 lines) |

## What Was Built

### Task 1: .planning/v1.42-IA-DIAGNOSTIC.md (287 lines)

**Section 1 — Admin Page Inventory (8 rows)**

Tabulates all 8 admin pages with ledger cell name, archetype, and primary L0/L1/L2 block
inventory. Confirms archetype assignments: Overview (index-live, organization-live), List
(users-index-live, audit-index-live), Detail (user-show-live, user-sessions, audit-user-live),
Workbench (branding-live).

**Section 2 — Persona-Panel Pass (24 matrices = 8 pages × 3 lenses)**

Applied all 3 verdict questions (Earning its place, IA muddy, Redundant/coherent) per lens
at diagnostic depth. Key findings by page:

- **index-live:** alarm-notice renders "All clear" text even when no risk present (verbosity);
  Total users count duplicates between Overview dl and Users List metric strip.
- **organization-live:** ghost-org drives zero-member + zero-invitation empty state; bare
  `<p class="sg-section-copy">` used instead of `<.empty_state>` component (coherence gap
  vs user-show-live which uses `<.empty_state>`); invite CTA is soft copy with no link
  (IA dead-end for ghost-org).
- **users-index-live:** applied-chip row sits inside the form between search and quick-filter
  rows (IA muddle); More-filters uses `phx-click` LiveView toggle vs `<details>` on audit
  pages (same-job, different mechanism).
- **user-show-live:** zoe drives 4 simultaneous empty panels; sessions count duplicated in
  header dl AND panel sub-heading copy; "Manage sessions" link-out is easily missed as a
  secondary button.
- **user-sessions:** `<h1>Sessions</h1>` heading hierarchy inconsistent with sibling detail
  pages where `<h1>` is the user name; revoke copy "They can sign in again" may undermine
  security-remediation investigator intent.
- **audit-index-live:** applied-chip position is OUTSIDE the form (vs inside form on
  users-index-live) — same-job-same-component principle violated at composite level; scope
  ribbon placement differs from audit-user-live.
- **audit-user-live:** scope_ribbon ABOVE the header (vs BELOW on audit-index-live) —
  same incoherence from the sibling side; "Effective user" filter absent vs global audit.
- **branding-live:** scope_ribbon hardcodes "Global auth/email profile" literal string
  instead of using `scope_copy/1` function; org-admin correctly 403'd (kill = correct gate,
  not surface flaw).

**Section 3 — Prioritized Disposition List (15 rows)**

Priority breakdown:
- **P1 (8 rows):** Quick wins + high-impact findings — applied-chip position coherence,
  empty-state component coherence, scope_ribbon placement, sessions count duplication,
  sessions heading hierarchy, alarm all-clear verbosity, invite CTA dead-end.
- **P2 (4 rows):** Higher effort — More-filters mechanism unification, revoke copy,
  Effective-user filter gap, checkbox Apply-on-submit expectation gap.
- **P3 (3 rows):** Low impact polish — zoe empty-state copy consistency, branding
  scope_ribbon hardcode, Overview/List Total-users minor redundancy.

## Verification Results

| Check | Result |
|-------|--------|
| `test -f .planning/v1.42-IA-DIAGNOSTIC.md` | PASS |
| Advisory framing + "Phase 209" explicit (count ≥ 4) | PASS (count: 12) |
| All 8 page ledger names present | PASS (all 8 confirmed, ≥5 occurrences each) |
| All 3 lens names present (count ≥ 10 each) | PASS (count: 43 combined) |
| Earning its place / IA muddy / Redundant (count ≥ 6) | PASS (count: 8 headers) |
| Feeds phase column present | PASS (count: 2 in table header + rows) |
| D-07 anti-collision: `awk -F'|' ... if (t ~ /^[012]$/)` | PASS (count: 0) |
| zoe / zero-state references | PASS (count: 5) |
| ghost-org references | PASS (count: 3) |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — this is a planning artifact (advisory diagnostic document). No data stubs or
UI placeholders.

## Threat Flags

None — `.planning/v1.42-IA-DIAGNOSTIC.md` is a planning artifact committed to `.planning/`
only. No new network endpoints, auth paths, file access patterns, or schema changes. The
document contains UX weakness analysis but is accessible only to maintainers (T-205-13
accepted disposition in plan threat model).

## Self-Check: PASSED

- `/Users/jon/projects/sigra/.planning/v1.42-IA-DIAGNOSTIC.md` — FOUND
- Commit `6f472b7e` — FOUND (git log confirms)
- D-07 anti-collision guard: PASS (0 bare integers in column-4)
- All 8 page names present: PASS
- All 3 lens names present: PASS
- zoe + ghost-org incorporated: PASS
- Advisory notice is first substantive content: PASS
- "Feeds phase" column populated for all 15 rows: PASS
