---
phase: 205-foundation
plan: "01"
subsystem: admin-ui-reference-docs
tags: [rubric, persona-jtbd, admin-ui, quality-ledger, fractal-scorecard, cross-reference]
dependency_graph:
  requires: []
  provides:
    - guides/reference/admin-persona-jtbd-rubric.md
  affects:
    - guides/reference/admin-fractal-scorecard.md
    - guides/reference/admin-quality-ledger.md
    - .planning/phases/205-foundation/ (rubric is the instrument for Plans 02-04 and downstream Phases 206-210)
tech_stack:
  added: []
  patterns:
    - adversarial rubric / forced-finding floor (keep/tighten/kill × 3 lenses × 3 refutation questions)
    - YAML frontmatter output schema (machine-rollup-able; 9-key verdicts map + findings list)
    - D-07 anti-collision: rubric docs never place bare 0/1/2 in table column-4
key_files:
  created:
    - guides/reference/admin-persona-jtbd-rubric.md
  modified:
    - guides/reference/admin-fractal-scorecard.md
    - guides/reference/admin-quality-ledger.md
decisions:
  - Rubric positioned as complementary to fractal scorecard — scorecard grades visual/technical quality (D1-D11, Tier 0/1/2); rubric grades UX fitness-for-purpose (keep/tighten/kill per 3 lenses)
  - Three lenses bound by entry-point + intent (not credentials): platform-admin → /admin triage; support-investigator → /admin/users/:id investigate; org-admin → /admin/organizations/:slug bound
  - Adversarial anti-rubber-stamp framing is standing rubric instruction — forced-finding floor requires NONE token with explicit search description; vibe-level assertions prohibited
  - D-07 enforced: rubric uses keep/tighten/kill + clean/actionable/blocked vocab; no bare 0/1/2 integer in column-4 of any rubric table
  - IN-04 resolved: stale 'Phases 200-204' forward reference replaced with dated completion note (v1.41 completed 2026-06-27) + ROADMAP pointer
metrics:
  duration_minutes: 3
  completed_date: "2026-06-28"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 2
status: complete
---

# Phase 205 Plan 01: Foundation — Persona-JTBD Rubric Summary

Authored `guides/reference/admin-persona-jtbd-rubric.md` as the adversarial persona/JTBD judge instrument with 3 admin-operator lenses, keep/tighten/kill ordinal scale, forced-finding floor, fixed YAML output schema, and D-07 anti-collision guard; added bidirectional cross-reference pointers into the fractal scorecard and quality ledger; fixed the stale IN-04 "200-204" prose in the ledger.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Author admin-persona-jtbd-rubric.md | e7895602 | guides/reference/admin-persona-jtbd-rubric.md (created, 325 lines) |
| 2 | Add bidirectional cross-references + fix IN-04 stale prose | d98cd624 | guides/reference/admin-fractal-scorecard.md, guides/reference/admin-quality-ledger.md |

## What Was Built

### Task 1: admin-persona-jtbd-rubric.md (325 lines)

The rubric formalizes the 3 admin-operator lenses that were implicit in the fractal scorecard and quality ledger. Key sections:

**IMPORTANT DISAMBIGUATION** — explicitly states that the 3 admin lenses are distinct from the integrator personas (A–E) in the JTBD prompt. Reviewers must not conflate admin operators with library adopters.

**Lens Definitions** — 3-row table binding each lens by entry-point + intent (not credentials):
- Platform admin → `admin@demo.tasklane.test`, entry `/admin`, posture triage, ledger cell `flow-platform-admin`
- Support investigator → `admin@demo.tasklane.test` acting on a target (dave/frank/grace/carol), entry `/admin/users/:id`, posture investigate, ledger cell `flow-support-investigator`
- Org admin → `morgan@demo.tasklane.test` (`org_admin: :acme`, non-platform), entry `/admin/organizations/:slug`, posture bound, ledger cell `flow-org-admin`

**Verdict Scale** — 3-point ordinal: keep / tighten / kill. Each level has a one-line anchor and worked example mirroring the scorecard's Tier 0/1/2 style. Worst-verdict-across-3-lenses disposition rule documented. Application-level rollup: any kill → blocked; any tighten and no kill → actionable; all keep → clean.

**Three Verdict Questions** — each as a refutation prompt mapped to a named failure mode:
1. "Earning its place?" → verbosity/info-dump
2. "Is the IA muddy?" → IA hierarchy failure
3. "Redundant / coherent / least-surprising?" → redundancy and coherence

**Adversarial Framing and Forced-Finding Floor** — standing rubric instruction documented verbatim. Every (lens × question) cell holds either a cited DOM/section anchor or the literal token `NONE — searched for: <what>`. Vibe-level assertions without concrete anchors explicitly prohibited.

**Output Schema** — YAML frontmatter (machine-rollup-able): `surface`, `ledger_cell`, `rubric_version`, `disposition`, `verdicts` (9-key map), `findings` list. Markdown body: per-lens refutation log ordered platform-admin / support-investigator / org-admin.

**Relationship to Quality Ledger** — D-07 anti-collision contract documented: rubric never places bare 0/1/2 in table column-4 (would false-match the ledger's `awk -F'|'` monotonic guard). Roll-up index (`v1.42-PERSONA-JTBD-PANEL.md`) uses `clean/actionable/blocked`, not integers. Scorecard and ledger cross-reference pointers included.

### Task 2: Cross-reference edits + IN-04 fix

**admin-fractal-scorecard.md** — inserted `### Persona-JTBD Rubric (Cross-Reference)` section immediately after the L4 Flow Add-ons bullet list, before `### Tier-2 Award-grade Add-on`. Points to `admin-persona-jtbd-rubric.md` and explains the relationship.

**admin-quality-ledger.md** — two edits:
1. Inserted `## Persona-JTBD Rubric (Cross-Reference)` section after the `flow-org-admin` row, before `## Terminal Ratification`. Binds L4 flow cells to rubric lenses; explains Phase 209 panel → roll-up index flow.
2. **IN-04 fix:** replaced stale `Ratcheting individual surfaces to Tier 2 begins in Phases 200-204.` with dated completion note: "began in Phases 200-204 (v1.41 ADMIN-DS-ELEVATION milestone, completed 2026-06-27). v1.42 ADMIN-DS-ELEVATION continues this work in Phases 205-211; see `.planning/ROADMAP.md` for the current phase map."

## Verification Results

| Check | Result |
|-------|--------|
| `test -f guides/reference/admin-persona-jtbd-rubric.md` | PASS |
| Rubric line count ≥ 100 | PASS (325 lines) |
| Rubric contains all 6 required sections (lens defs, verdict scale, verdict questions, adversarial framing, output schema, ledger relationship) | PASS |
| Scorecard has pointer to rubric (grep count ≥ 1) | PASS (count: 1) |
| Ledger has pointer to rubric (grep count ≥ 1) | PASS (count: 1) |
| D-07 anti-collision: no bare integer in rubric column-4 | PASS (count: 0) |
| IN-04: '200-204' line includes completion date mention | PASS |
| Monotonic guard exits 0 vs origin/main (36 cells) | PASS |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — this plan creates reference documentation; no data stubs or placeholders.

## Threat Flags

None — documentation-only changes with no new network endpoints, auth paths, file access patterns, or schema changes.

## Self-Check: PASSED

- `/Users/jon/projects/sigra/guides/reference/admin-persona-jtbd-rubric.md` — FOUND
- Commit `e7895602` — FOUND
- Commit `d98cd624` — FOUND
- Monotonic guard: PASS (36 cells checked vs origin/main)
