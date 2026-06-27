---
phase: 203-consistency-propagation
plan: "01"
subsystem: ui
tags: [admin-ui, status-pills, sg-status-pill, summary_chip, heex, phoenix-liveview]

requires:
  - phase: 201-users-index-elevation
    provides: "status_pills/1 reduction — Confirmed/ok pill dropped; absence of Unconfirmed implies confirmed"
  - phase: 202-audit-explorer-elevation
    provides: "overview composition patterns; coverage KPI demotion precedent"

provides:
  - "Org roster drops always-on green Confirmed pill (D-02) — decision-bearing pills only"
  - "Global overview drops Authentication coverage chip (D-03) — coverage KPI removed to match Users Index"
  - "Same status signal now renders identically across org overview, global overview, and Users Index"

affects: [203-02, 203-03, 203-04, 203-05]

tech-stack:
  added: []
  patterns:
    - "Pill reduction: drop always-on ok pills — absence of warn implies ok (established Phase 201, extended Phase 203)"
    - "Coverage KPI removal: non-decision-bearing metrics removed from Overview dl (D-03 precedent)"

key-files:
  created: []
  modified:
    - lib/sigra/admin/live/organization_live.ex
    - lib/sigra/admin/live/index_live.ex

key-decisions:
  - "D-02: always-on Confirmed/ok pill removed from org roster — decision-bearing pills only (role, Locked, Deletion scheduled, Unconfirmed)"
  - "D-03: Authentication coverage summary_chip removed from global overview dl — non-decision-bearing coverage KPI"
  - "Unused mfa_users/passkey_users bindings and percent_of/2 helper removed after compile --warnings-as-errors flagged them"

patterns-established:
  - "Pure reductive markup pass: zero new sg-* class, zero new component, zero new archetype"

requirements-completed: [PROP-01]

coverage:
  - id: D1
    description: "Org roster Confirmed/ok always-on pill removed; decision-bearing pills (role, Locked, Deletion scheduled, Unconfirmed) retained"
    requirement: PROP-01
    verification:
      - kind: unit
        ref: "grep -c 'data-tone=\"ok\">Confirmed' lib/sigra/admin/live/organization_live.ex == 0"
        status: pass
      - kind: unit
        ref: "mix compile --warnings-as-errors exits 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Global overview Authentication coverage chip removed; other summary_chips in dl unchanged"
    requirement: PROP-01
    verification:
      - kind: unit
        ref: "grep -c 'overview-metric-auth-coverage' lib/sigra/admin/live/index_live.ex == 0"
        status: pass
      - kind: unit
        ref: "mix compile --warnings-as-errors exits 0"
        status: pass
    human_judgment: false
  - id: D3
    description: "Both Overviews stay glossary-clean and three sigra_admin.css copies share one md5 (D-12 untripped)"
    verification:
      - kind: unit
        ref: "mix test test/sigra/admin/glossary_test.exs -- 2 tests, 0 failures"
        status: pass
      - kind: unit
        ref: "md5 three CSS copies | sort -u | wc -l == 1"
        status: pass
    human_judgment: false

duration: 69s
completed: 2026-06-26
status: complete
---

# Phase 203 Plan 01: Overview Pill/Chip Reduction Summary

**Org roster drops always-on Confirmed pill and global overview drops Authentication coverage chip — same status signals now render identically across org overview, global overview, and Users Index (D-02/D-03, zero new CSS)**

## Performance

- **Duration:** 69 seconds
- **Started:** 2026-06-26T17:03:12Z
- **Completed:** 2026-06-26T17:04:21Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Dropped `<span :if={member.confirmed?} class="sg-status-pill" data-tone="ok">Confirmed</span>` from org roster member loop (`organization_live.ex:105`) — decision-bearing-only pill vocabulary now matches `users_index_live.ex` status_pills/1
- Removed `overview-metric-auth-coverage` `<.summary_chip>` block from global overview `<dl>` (`index_live.ex:113-122`) — coverage KPI dropped as non-decision-bearing, matching Users Index precedent
- Cleaned up now-unused `mfa_users`/`passkey_users` template bindings and `percent_of/2` private helper (flagged by `mix compile --warnings-as-errors`)
- Glossary drift guard passes for both edited files; all three `sigra_admin.css` copies still share a single md5 (D-12 lockstep untripped)

## Task Commits

Each task was committed atomically:

1. **Task 1: Drop the org roster always-on Confirmed pill (D-02)** - `d8d03a2f` (feat)
2. **Task 2: Demote the global Authentication coverage chip (D-03)** - `e3851179` (feat)
3. **Task 3: Prove both Overviews stay glossary-clean and CSS untouched (D-11/D-12)** - verification only (no source changes)

## Files Created/Modified

- `lib/sigra/admin/live/organization_live.ex` - Removed always-on Confirmed/ok pill from member roster sg-cluster loop
- `lib/sigra/admin/live/index_live.ex` - Removed overview-metric-auth-coverage summary_chip; removed mfa_users/passkey_users bindings and percent_of/2 helper

## Decisions Made

- Removed `mfa_users`, `passkey_users`, and `percent_of/2` from `index_live.ex` because `mix compile --warnings-as-errors` flagged all three as unused (per plan instruction: only remove bindings/helpers if the compiler flags them — do not speculatively delete shared helpers)
- Task 3 produced no source commit because it is a verification-only gate (runs tests, checks md5); the source changes are captured in Tasks 1 and 2

## Deviations from Plan

None — plan executed exactly as written. The compiler-flagged binding/helper removals are explicitly anticipated in the plan's Task 2 action: "only remove a binding if `mix compile --warnings-as-errors` flags it as unused — do not speculatively delete shared helpers used elsewhere."

## Issues Encountered

None.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. Both edits are pure HEEx markup deletions (pill/chip removal) — only reduce surfaced data, never expose new data. HEEx auto-escaping preserved; no `raw/1` introduced. T-203-01-I (information disclosure) and T-203-01-T (stored XSS) both remain at plan-approved disposition.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Both Overview files are now aligned with the Phase 201 reduced-pill vocabulary
- The same status signal renders identically across org overview, global overview, and Users Index
- Ready for Plan 02: component-level alignment pass on remaining Overview surfaces
- Zero new CSS, zero new components, zero new archetypes — D-12 lockstep clean

---
*Phase: 203-consistency-propagation*
*Completed: 2026-06-26*
