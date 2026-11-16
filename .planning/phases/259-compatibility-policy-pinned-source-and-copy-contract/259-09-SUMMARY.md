---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 09
subsystem: docs
tags: [instruction-files, brand-pointers, doc-contract-test, exunit, claude-md, agents-md, admin-guides]

requires:
  - phase: 259-01
    provides: ADR 005 (token names stay, token values move in Phase 261) and the compatibility policy docs the pointer wording defers to
provides:
  - CLAUDE.md (Admin UI Direction) and AGENTS.md (brand bullet) point at the v1.51 brand book in brand/ (brand/BRAND.md, brand/tokens.json) instead of the retired brandbook/ source
  - guides/reference/admin-ui-principles.md and admin-design-contract.md retired pointer lines replaced, with explicit "token values move in a later phase" wording and no alignment claim
  - test/sigra/brand/instruction_pointers_test.exs, Sigra.Brand.InstructionPointersTest - 11 tests over four files with planted-string positive controls
  - two pending todos for the pointers the approval does not cover
affects: [260, 261, 262, 263]

actuals:
  tokens: 4319
  tasks: 2
  commits: 2
commits: 2
plan_head_before: 13137b84af6e9a4684903f65dc80604e8aee415b
plan_head_after: d6225b3ae9b7454011ef863091d9953457259414

tech-stack:
  added: []
  patterns:
    - "Doc-contract negative grep with a pure violations/1 helper applied line by line, so a failure names the offending line, plus planted-string positive controls for each defect class"
    - "Tracer-then-expand: the test and the two root instruction files landed first with a two-file scope, then the file list was extended to the two guides"

key-files:
  created:
    - test/sigra/brand/instruction_pointers_test.exs
    - .planning/todos/pending/2026-11-13-example-agents-md-retired-brand-pointer.md
    - .planning/todos/pending/2026-11-13-residual-brandbook-pointers.md
  modified:
    - CLAUDE.md
    - AGENTS.md
    - guides/reference/admin-ui-principles.md
    - guides/reference/admin-design-contract.md

key-decisions:
  - "Approval evidence was verified before any instruction-file edit: REQUIREMENTS BPOL-06 (commit aeda7273d) records owner approval granted 2026-11-13 for pointers to the new brand/ book, which matches what the tasks edit"
  - "CLAUDE.md changed by exactly one line (numstat 1 added, 1 removed); GSD marker count is unchanged"
  - "AGENTS.md keeps the single pointer bullet and carries the 'names stay, values move in a later phase' clause in the same bullet rather than adding a new bullet"
  - "admin-design-contract.md first sentence is rewritten in the past tense for the v1.36 pass and says the chrome is being aligned to the book, so it no longer claims the system was already ratified into chrome"
  - "test/example/AGENTS.md is left alone and filed as a todo: its 'Rail Accent brand assets' line names no brandbook/ path, so it is not the identical defect the approval covers"

patterns-established:
  - "Pointer defects are enforced as three line-level classes (retired Rail Accent pointer, retired tokens path, alignment claim), each with its own planted control"

requirements-completed: [BPOL-06]

coverage:
  - id: D1
    description: "CLAUDE.md and AGENTS.md point at brand/ (brand/BRAND.md, brand/tokens.json); one changed line in CLAUDE.md; sg-*, Light/Dark/System and deterministic-test wording preserved; token-names-stay clause present"
    requirement: "BPOL-06"
    verification:
      - kind: unit
        ref: "test/sigra/brand/instruction_pointers_test.exs#preserved wording, instruction files point at the new brand book"
        status: pass
      - kind: other
        ref: "git diff aeda7273d --numstat -- CLAUDE.md (1 1) and GSD marker count equal to the base"
        status: pass
    human_judgment: false
  - id: D2
    description: "Both admin guides point at brand/ with H1s unchanged, no alignment claim, and say token values move to brand/tokens.json in a later phase"
    requirement: "BPOL-06"
    verification:
      - kind: unit
        ref: "test/sigra/brand/instruction_pointers_test.exs#admin guides keep their H1 and say token values move to the book in a later phase"
        status: pass
    human_judgment: false
  - id: D3
    description: "Doc-contract test over the four files with planted-string positive controls for the retired pointer, the retired tokens path and the alignment claim, and a clean-line control"
    requirement: "BPOL-06"
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand test/sigra/architecture_guides_contract_test.exs (220 tests, 0 failures)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Two todos filed for the pointers outside the approval (test/example/AGENTS.md, and the two reference guides plus scripts/panel/lenses.mjs); the orphaned files are untouched"
    requirement: "BPOL-06"
    verification:
      - kind: other
        ref: "todo frontmatter fence check, status: pending, file-name greps, and git diff --stat against aeda7273d on the orphan files (empty)"
        status: pass
    human_judgment: false

duration: 11min
completed: 2026-11-14
status: complete
---

# Phase 259 Plan 09: Instruction-file pointer fix Summary

**CLAUDE.md, AGENTS.md and the two admin guides now send executors to the v1.51 brand book in brand/ instead of the retired brandbook/ source, with a line-level doc-contract test that also forbids claiming admin token values already match the book.**

## Performance

- **Duration:** about 11 min (approximate; the start timestamp was not captured in a persistent variable)
- **Started:** 2026-11-14
- **Completed:** 2026-11-14T16:54Z
- **Tasks:** 2
- **Files modified:** 7 (3 created, 4 modified)

## Accomplishments

- The retired-book pointer in the CLAUDE.md Admin UI Direction paragraph and the AGENTS.md brand bullet now name `brand/`, `brand/BRAND.md` and `brand/tokens.json`. Every other clause is kept, and the `--sg-*` names stay while token values move to the book in a later phase.
- `admin-ui-principles.md` (intro, token reference, brand application) and `admin-design-contract.md` (addendum opening, token sentence, mark/lockup sentence) carry the same pointer and the same "later phase" wording. Neither claims token values already align, and neither claims the shipped logo assets were replaced. Both H1s and the light/dark lockup rules are unchanged.
- `instruction_pointers_test.exs` asserts, across all four files: no "Rail Accent" line with a backticked brandbook path, no retired tokens path, a backticked `brand/` pointer in each, no alignment claim. It also asserts the preserved CLAUDE.md and AGENTS.md wording and the guide H1s, and plants each defect class as a positive control.
- Two todos were filed instead of widening the edit: `test/example/AGENTS.md` (outside the approval wording) and the three orphaned retired pointers (two reference guides and `scripts/panel/lenses.mjs`), which have no owning requirement.

## Task Commits

1. **Task 1: Pointer test plus CLAUDE.md and AGENTS.md pointer lines (tracer)** - `4dad2ca17` (feat)
2. **Task 2: Admin guide pointer lines and the out-of-approval-scope todos** - `d6225b3ae` (docs)

The tracer gate ran after Task 1: auto mode was off and `human_verify_mode` was `end-of-phase` with an automated-only verify, so the verify was re-run end to end (10 tests green, CLAUDE.md numstat within bound) before expanding.

**Plan metadata:** committed separately after this file (docs: complete plan).

## Files Created/Modified

- `test/sigra/brand/instruction_pointers_test.exs` - doc-contract test with a pure `violations/1` helper and planted controls
- `CLAUDE.md` - one pointer line in Admin UI Direction
- `AGENTS.md` - one bullet naming the brand source
- `guides/reference/admin-ui-principles.md` - three pointer lines (intro, token bullet, brand application bullet)
- `guides/reference/admin-design-contract.md` - three addendum lines (opening sentence, token sentence, mark/lockup sentence)
- `.planning/todos/pending/2026-11-13-example-agents-md-retired-brand-pointer.md` - owner todo for `test/example/AGENTS.md`
- `.planning/todos/pending/2026-11-13-residual-brandbook-pointers.md` - owner todo for the three orphaned pointers, with no `resolves_phase` key

## Decisions Made

- Approval was checked first: BPOL-06 in REQUIREMENTS.md (commit `aeda7273d`) records owner approval granted 2026-11-13 for pointers to the new `brand/` book, which matches the edits made. No refusal occurred on the CLAUDE.md edit.
- The AGENTS.md bullet carries the "names stay, values move in a later phase" clause itself, so the file states the same boundary as CLAUDE.md without adding a bullet.
- The contract addendum's first sentence is rewritten to say the v1.36 pass preserved the v1.34 contract and that the chrome is being aligned to the book, so it no longer implies the new system is already in the chrome.

## Deviations from Plan

None - plan executed exactly as written.

Two small notes, neither a deviation: Task 1's test file list was scoped to the two root files and extended to the guides in Task 2 as the plan directs; and an initial `assert @instruction_files != []` was dropped because the compile-time list made the type checker warn, and the per-file loop already covers the non-empty case.

## Issues Encountered

None.

## Verification Results

- `mix test test/sigra/brand test/sigra/architecture_guides_contract_test.exs`: 220 tests, 0 failures
- `mix test test/sigra/brand/instruction_pointers_test.exs`: 11 tests, 0 failures (the RED run before the Task 1 edits, at 10 tests with the two-file scope, showed 3 failures, then green)
- Zero shipped bytes (Verification item 2): `lib`, `priv`, `brandbook`, `brand`, `.github`, `scripts`, `mix.exs` and `doc/llms.txt` unchanged against `aeda7273d`, with a non-empty instruction-file diff as the positive control
- Privacy gate (item 3): no `/Users/...` or `/home/...` path in the diff, planted-failure control matches
- `mix format --check-formatted`: exit 0
- Acceptance: `grep brandbook` on all four edited files prints nothing (control: `mix.exs` still has 1 match); no "already align" or "stay aligned" in the four files; CLAUDE.md numstat is `1 1`; GSD marker count equals the base; `test/example/AGENTS.md`, `mix.exs`, `doc/llms.txt` and the three orphan files untouched

## Known Stubs

None.

## Threat Flags

None. The plan edits documentation and one test only; no network, auth, file-access or schema surface was added. T-259-28, T-259-29 and T-259-30 are mitigated by the negative-grep test with controls, the alignment-phrase assertions with explicit "later phase" wording, and the CLAUDE.md numstat bound with out-of-scope lines filed as todos.

## Self-Check: PASSED

All seven created or modified files exist on disk, and commits `4dad2ca17` and `d6225b3ae` are ancestors of HEAD.
