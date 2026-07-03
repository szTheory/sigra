---
phase: 209-judgment-level-page-pass
plan: "03"
subsystem: admin-live-overviews
tags: [admin-ui, overview, empty-state, copy, ux]
status: complete
dependency_graph:
  requires: [209-02]
  provides: [209-04, 209-05, 209-06]
  affects: [lib/sigra/admin/live/index_live.ex, lib/sigra/admin/live/organization_live.ex]
tech_stack:
  added: []
  patterns: [empty_state-component-swap, posture-descriptive-alarm-copy, panel-verdict-resolution]
key_files:
  created: []
  modified:
    - lib/sigra/admin/live/index_live.ex
    - lib/sigra/admin/live/organization_live.ex
    - .planning/uat-evidence/v1.42-persona-jtbd/index-live.md
    - .planning/uat-evidence/v1.42-persona-jtbd/organization-live.md
decisions:
  - "Replace 'All clear' with 'No flagged accounts' on both Overview pages for cross-page coherence"
  - "Remove Total-users summary chip from Global Overview; Users-List strip is the single owner (Plan 03 dedup)"
  - "Swap both org_live empty-states from bare <p> to <.empty_state> component"
  - "Waiver for members action-link: admin overview is read-only, no admin invite route per D-06/OQ-1"
metrics:
  duration: "2 minutes"
  completed_date: "2026-07-01"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 4
---

# Phase 209 Plan 03: Overview LiveViews Remediation Summary

Remediates both Overview LiveViews' `actionable` panel verdicts from Wave 1: replaces bare "All clear" alarm copy with posture-descriptive "No flagged accounts" on both pages, removes the duplicated "Total users" metric from the Global Overview (Users-List strip is the single owner), and upgrades the Org Overview empty-states from bare `<p>` tags to the `<.empty_state>` component. All four panel doc actionable verdicts receive committed diff or documented waiver resolution notes.

---

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | index_live — kill bare "All clear" + dedup Total-users | f5d8fb84 | lib/sigra/admin/live/index_live.ex, .planning/uat-evidence/v1.42-persona-jtbd/index-live.md |
| 2 | organization_live — kill bare "All clear" (NEW-1) + swap empty-states | fd1ca311 | lib/sigra/admin/live/organization_live.ex, .planning/uat-evidence/v1.42-persona-jtbd/organization-live.md |

---

## Decisions Made

1. **"No flagged accounts" phrase for both Overview pages** — The plan's `must_haves.truths` specify this exact phrase. Applied to both `index_live.ex` and `organization_live.ex` for cross-page coherence. Glossary test confirms "account" in this usage is not a banned synonym (the `account` ban targets "account" as a person-noun synonym for "user"; "flagged accounts" describes security state).

2. **Remove Total-users chip (not reframe)** — The cleanest dedup is full removal from the Overview side. The chip was a pure duplicate (same label, same value, same icon) with no additional context. The unused `total_users =` template binding was also removed. Plan 05 will confirm the Users-List side retains the chip without modification.

3. **`<.empty_state>` title + one-sentence body** — Following UI-SPEC Standard Admin Copy Patterns: title is a noun phrase of the absent thing ("No members yet", "No pending invitations"); body is one sentence explaining what populates the surface. Empty-state rubric rule: "Explain what populates the surface, even briefly."

4. **Waiver for members action-link** — OQ-1 disposition is LOCKED. The admin overview is read-only; there is no admin-pipeline invite route. A cross-pipeline `/members` link would violate D-06 (no net-new surfaces, no cross-pipeline navigation). Documented explicitly in both the code comment and the panel doc resolution note. The `<.empty_state>` component swap is the structural fix; the action-link clause is waived.

---

## Deviations from Plan

None — plan executed exactly as written.

---

## Known Stubs

None. Both LiveViews render real data paths; no hardcoded empty values or placeholder text introduced.

---

## Threat Surface Scan

No new security-relevant surface introduced. Changes are copy/IA edits and a component swap on read-only overview pages. No new routes, no new auth paths, no new file access patterns, no schema changes. T-209-03-01 (elevation of privilege via action link) was mitigated by the Waiver disposition — no action link was added.

---

## Self-Check: PASSED

- `lib/sigra/admin/live/index_live.ex` — modified, committed at f5d8fb84
- `lib/sigra/admin/live/organization_live.ex` — modified, committed at fd1ca311
- `.planning/uat-evidence/v1.42-persona-jtbd/index-live.md` — resolution notes appended, committed at f5d8fb84
- `.planning/uat-evidence/v1.42-persona-jtbd/organization-live.md` — resolution notes appended, committed at fd1ca311
- `glossary_test.exs` — 2 tests, 0 failures
- `quality-ledger-monotonic.sh --base origin/main` — PASS (36 cells checked)
- Negative grep `'All clear'` in index_live.ex — PASS
- Positive grep `'No flagged accounts'` in index_live.ex — PASS
- Negative grep `'All clear'` in organization_live.ex — PASS
- Positive grep `'No flagged accounts'` in organization_live.ex — PASS
- `<.empty_state` count in organization_live.ex — 2 (≥ 2 required) — PASS
- Bare `:if={@members|pending_invitations == []} class="sg-section-copy"` count — 0 — PASS
