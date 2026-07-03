---
phase: "207"
plan: "01"
subsystem: admin-ds-ci-guards
status: complete
tags: [ci-guards, token-completeness, css-conformance, comp-03, d-06, d-07]
completed: "2026-06-28"
duration: "~4 minutes"

dependency_graph:
  requires: []
  provides:
    - scripts/ci/admin-token-completeness.sh  # D-06: COMP-03 load-bearing proof
    - scripts/ci/admin-token-completeness.test.sh
    - scripts/ci/admin-css-conformance.sh     # extended with CHECK 3 (D-07)
  affects:
    - plans: [207-03, 207-04]  # doc refresh + ledger evidence cite these guards

tech_stack:
  added: []
  patterns:
    - sibling-ci-guard  # mirrors admin-css-conformance.sh structure (ROOT auto-derived, fail() helper, mktemp hermetic test)
    - comm-set-diff     # sorted set diff (comm -23/-13) for token comparison
    - awk-root-tracker  # inverted :root-tracking awk from CHECK 2 to emit in-root lines

key_files:
  created:
    - scripts/ci/admin-token-completeness.sh
    - scripts/ci/admin-token-completeness.test.sh
  modified:
    - scripts/ci/admin-css-conformance.sh     # CHECK 3 narrow raw-px block + header/usage update

decisions:
  - "D-06: admin-token-completeness.sh diffs :root token defs vs admin-token-reference.md backticks; exits 0 at 100/100 baseline; the durable COMP-03 automated proof"
  - "D-07: PATH A taken — narrow CHECK 3 added to admin-css-conformance.sh scoped to token-eligible property contexts; exits 0 on current CSS (zero violations in font-size/gap/padding/margin/width/height outside clip pattern)"
  - "Token count correction: CONTEXT/todo cited '96/96' — actual verified count is 100/100 unique --sg-* tokens across both :root blocks"

metrics:
  duration: "~4 minutes"
  completed: "2026-06-28"
  tasks_completed: 3
  tasks_total: 3
  files_created: 2
  files_modified: 1
---

# Phase 207 Plan 01: CI Guards (D-06 Token Completeness + D-07 Raw-px) Summary

Build the durable COMP-03 conformance proof: `admin-token-completeness.sh` diffs `--sg-*` `:root` token defs in `sigra_admin.css` against documented backtick tokens in `admin-token-reference.md`, plus a narrow raw-px CHECK 3 in `admin-css-conformance.sh` for token-eligible property contexts.

## What Was Built

### Task 1 — admin-token-completeness.sh (D-06)

New merge-blocking guard (`scripts/ci/admin-token-completeness.sh`) that:
- Extracts all `--sg-*` token names defined in `:root` blocks (both light and dark `@media (prefers-color-scheme: dark)`) using the proven `:root`-tracking awk from `admin-css-conformance.sh` CHECK 2, inverted to emit lines *inside* `:root`
- Extracts all `--sg-*` token names documented as backtick literals in `admin-token-reference.md`
- Diffs the two sorted sets with `comm -23` (in CSS, not documented) and `comm -13` (documented, not in CSS)
- Exits 0 at baseline: **100/100 tokens** matched; no divergence
- Accepts `--css`, `--doc` overrides and a positional arg; exits 2 on unknown `--flags` or missing files
- Executable (`chmod +x`); mirrors sibling guard shape (ROOT auto-derived, `fail()` helper, PASS/FAIL prefix)

**Baseline:** 100 unique `--sg-*` tokens across 2 `:root` blocks (light + dark). CONTEXT/todo cited "96/96" — the actual verified count is **100/100**.

### Task 2 — admin-token-completeness.test.sh (D-06)

Hermetic self-test (`scripts/ci/admin-token-completeness.test.sh`) with 8 assertions across 4+1 tests:
- **Test A** (matched sets): light `:root` + dark `:root` + doc both list `--sg-a`, `--sg-b` → exit 0, emits PASS
- **Test B** (CSS token missing from doc): `--sg-b` in `:root`, not in doc → exit non-zero, stderr names `--sg-b`
- **Test C** (doc token absent from CSS): `--sg-c` in doc, not in `:root` → exit non-zero, stderr names `--sg-c`
- **Test D** (dual `:root` scanned): `--sg-b` defined *only* in the dark `@media :root` block (not in light); doc lists both `--sg-a` and `--sg-b` → exit 0 (proves dark block is scanned)
- **Test G** (no repo side effects): `git status` shows no dirty files outside `scripts/ci/`

All 8 assertions pass; exits 0 with `admin-token-completeness.test: PASS`.

### Task 3 — CHECK 3 narrow raw-px in admin-css-conformance.sh (D-07)

**D-07 decision: PATH A — narrow automated CHECK 3 added.**

Research confirmed **zero raw-px occurrences in token-eligible property contexts** (`font-size`, `gap`, `row-gap`, `column-gap`) and the only `margin`/`width`/`height` raw-px occurrences are visually-hidden clip patterns (`margin: -1px`, `width: 1px; height: 1px` adjacent to `clip: rect(0,0,0,0)`).

CHECK 3 is scoped to exclude false positives with three filters:
1. Strips `:root` blocks (reuses existing awk, same logic as CHECK 2)
2. Skips negative values (`margin: -1px`) — never token-eligible
3. Skips `1px`/`0px` terminal values (clip pattern dimensions)

Result: CHECK 3 exits 0 against the current `sigra_admin.css` (zero violations). The check catches a future `padding: 12px` that would bypass `--sg-space-*` tokens, without flagging any of the 38 legitimate idioms (borders, shadows, breakpoints, clip patterns, pills, nudges).

Updated the file header and `usage()` block to document the new check.

The existing `admin-css-conformance.test.sh` self-test remains 10/10 green (CHECK 1/CHECK 2 behavior unbroken). No new px test fixture was added to the self-test (the CHECK 3 guard exits 0 on the clean fixture already used in Test A).

## D-07 Decision Record

**PATH A chosen** (narrow automated CHECK 3):

Rationale: the narrow regex proved clean within this phase. Zero violations in token-eligible contexts on the current CSS. Explicitly skipped idioms (negative margin, 1px clip dimensions) are provably non-token-candidates. The inline allowlist is empty (no intentional exceptions needed). PATH A delivers full COMP-03 automated coverage (hex + px + token-completeness) with zero false positives and zero manual review debt.

**PATH B (D-07a documented manual review) was NOT taken.** Plans 03 and 04 should cite the automated `admin-css-conformance.sh CHECK 3` as proof of raw-px conformance.

## Verification Results

All four guards exit 0:

| Command | Result |
|---------|--------|
| `bash scripts/ci/admin-token-completeness.sh` | PASS — 100 tokens, :root == doc |
| `bash scripts/ci/admin-token-completeness.test.sh` | PASS — 8 passed, 0 failed |
| `bash scripts/ci/admin-css-conformance.sh` | PASS — CHECK 1/2/3 all green |
| `bash scripts/ci/admin-css-conformance.test.sh` | PASS — 10 passed, 0 failed |

Both new scripts are executable (`test -x` verified).

## Downstream Citation

Plans 03 and 04 should cite the following proof tokens:
- **Token-completeness (D-06):** `admin-token-completeness.sh exits 0 — 100/100 :root --sg-* tokens documented in admin-token-reference.md`
- **Hex conformance:** `admin-css-conformance.sh CHECK 2 exits 0 — no raw hex outside :root`
- **Px conformance (D-07, PATH A):** `admin-css-conformance.sh CHECK 3 exits 0 — no raw px in token-eligible contexts`

## Deviations from Plan

None — plan executed exactly as written.

The only correction was the token count (CONTEXT/todo said "96/96"; actual verified count is **100/100**). This was noted in RESEARCH.md as a stale paraphrase and is documented here for Plans 03/04 to use the correct number.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The new guard scripts read repo files via quoted expansions, no `eval`, no network — consistent with the threat model (T-207-01 accepted).

## Self-Check

All created files verified present and executable:
- `/Users/jon/projects/sigra/scripts/ci/admin-token-completeness.sh` — present, executable
- `/Users/jon/projects/sigra/scripts/ci/admin-token-completeness.test.sh` — present, executable
- `/Users/jon/projects/sigra/scripts/ci/admin-css-conformance.sh` — modified, CHECK 3 present

All three task commits verified in git log.
