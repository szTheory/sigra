---
phase: 054-changelog-milestone-anchors
plan: 01
subsystem: docs
tags: [changelog, semver, milestones, PUB-02]

requires:
  - phase: 053-package-hex-metadata
    provides: Hex-aligned public surface and @source_url for compare links
provides:
  - CHANGELOG.md with planning-milestone glossary, per-release roadmap traceability (v1.2–v1.4), risk-weighted 0.1.0 sections, and compare links
affects:
  - v1.5 phases 55–56 (README / maintainer narrative can assume changelog anchors exist)

tech-stack:
  added: []
  patterns:
    - "Hex `[0.x.y]` headings stay canonical; `v1.x` labels are planning milestones per MILESTONES.md"

key-files:
  created: []
  modified:
    - CHANGELOG.md

key-decisions:
  - "Glossary references a Roadmap traceability H3 without embedding the literal `### Roadmap traceability` substring so `grep -c` acceptance (==3 real subsections) stays unambiguous."

patterns-established:
  - "Keep a Changelog compare link footer aligned to mix.exs @source_url"

requirements-completed:
  - PUB-02

duration: 25min
completed: 2026-04-22
---

# Phase 54: Changelog & milestone anchors — Plan 01 summary

**CHANGELOG now separates Hex SemVer releases from planning v1.x milestones with explicit traceability blocks and Keep a Changelog compare URLs.**

## Performance

- **Duration:** ~25 min (estimated)
- **Started:** 2026-04-22 (session)
- **Completed:** 2026-04-22
- **Tasks:** 4
- **Files modified:** 1

## Accomplishments

- Glossary clarifies dual-axis story (Hex 0.x vs planning v1.0–v1.4).
- Unreleased, 0.2.0, and 0.1.0 each carry a **Roadmap traceability** subsection with dates and paths consistent with `.planning/MILESTONES.md`.
- `[0.1.0]` section follows Keep a Changelog risk order: Roadmap → Changed → Fixed → Added.
- Reference-style GitHub compare/release links appended for Unreleased / 0.2.0 / 0.1.0.

## Task commits

1. **Task 1: Add planning-milestones glossary** — `f6d067f` (docs)
2. **Task 2: Add Roadmap traceability under 0.1.0, 0.2.0, and Unreleased** — `cffeff5` (docs; combined with task 3 in same commit)
3. **Task 3: Reorder 0.1.0 Keep a Changelog sections** — `cffeff5` (docs)
4. **Task 4: Keep a Changelog compare links footer** — `1e7929c` (docs)

## Files created/modified

- `CHANGELOG.md` — glossary, traceability, section order, compare links

## Decisions made

- Adjusted glossary wording from the plan’s fenced example so the prose does not contain the substring `### Roadmap traceability` (which would inflate `grep -c` counts). Meaning unchanged.

## Deviations from plan

### Documented deviation

**1. Glossary wording vs verbatim plan block**

- **Found during:** Task 2 acceptance (`grep -c '### Roadmap traceability'` must equal 3).
- **Issue:** Verbatim plan text included `` `### Roadmap traceability` `` in the glossary paragraph, producing a fourth grep match.
- **Fix:** Rephrased to “**Roadmap traceability** subsection (H3)” without the leading `###` token sequence.
- **Files modified:** `CHANGELOG.md`
- **Verification:** `grep -c '### Roadmap traceability' CHANGELOG.md` → 3; plan-level verification commands re-run.

**Tasks 2 and 3** were committed together in `cffeff5` because both touched the same `CHANGELOG.md` region in one editing pass after acceptance checks passed.

## Issues encountered

- `gsd-sdk query init.execute-phase "54"` returns `phase_found: false`; padded phase **`054`** is required for this repo’s directory naming.

## User setup required

None.

## Next phase readiness

- Phase **55** (README & ExDoc) can assume changelog milestone anchors and compare links exist.

## Self-check: PASSED

- `mix compile --warnings-as-errors` — PASS
- `grep -c '### Roadmap traceability' CHANGELOG.md` — 3 — PASS
- `grep -Ei '## \[v1\.' CHANGELOG.md` — no matches — PASS
- `grep -Ei 'soc2|pen[- ]?test|audit[- ]certified' CHANGELOG.md` — no matches — PASS
- Spot-check: `MILESTONES.md` shipped dates for v1.2 / v1.3 / v1.4 match changelog traceability lines (2026-04-17, 2026-04-19, 2026-04-22) — PASS

---
*Phase: 054-changelog-milestone-anchors*  
*Completed: 2026-04-22*
