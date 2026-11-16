---
phase: quick
plan: 261115-nnd
subsystem: docs
tags: [claude-md, gsd-workflow, maintaining, ci-efficiency]

requires: []
provides:
  - "CLAUDE.md `## GSD Workflow Preferences` section (Discuss phases, Verify phases) read by every GSD subagent"
  - "MAINTAINING.md `CI efficiency sweep` pointer paragraph under `### CI cadence`"
affects: [gsd-autonomous, discuss-phase, verify-work, ci-maintenance]

actuals:
  tokens: 743
  tasks: 1
  commits: 1

plan_head_before: 5ab99d0e7451a0fbfa3167e259ed0a7272811e2b
plan_head_after: 4dd223ffc97ccfe12b1816bfcfbfa10e378ad98b
commits: 1

tech-stack:
  added: []
  patterns:
    - "Standing owner preferences live in a CLAUDE.md section outside the generator-managed GSD marker blocks"

key-files:
  created: []
  modified:
    - CLAUDE.md
    - MAINTAINING.md

key-decisions:
  - "New section sits after `## Admin UI Direction` and before the `<!-- GSD:workflow-start -->` marker, so it is outside every generator-managed block and survives `generate-claude-md` regeneration"
  - "MAINTAINING.md pointer placed at the end of `### CI cadence` (before the Honest-skip section) so the p07 honest-skip section regex and rot-surface bans are unaffected"
  - "MAINTAINING.md is a docs extra in mix.exs, so the pointer names `CLAUDE.md` in plain code formatting rather than a relative markdown link (CLAUDE.md is not an extra and a link would dangle on HexDocs)"

requirements-completed: []

duration: 12min
completed: 2026-11-15
status: complete
---

# Quick 261115-nnd: GSD Workflow Preferences in CLAUDE.md Summary

**Standing owner discuss and verify boilerplates are now a `## GSD Workflow Preferences` section in CLAUDE.md, with a short CI efficiency sweep pointer in MAINTAINING.md, docs-only and unpinned.**

## Performance

- **Duration:** about 12 min
- **Tasks:** 1 of 1
- **Files modified:** 2 (CLAUDE.md +22 lines, MAINTAINING.md +5 lines)

## Accomplishments

- Added `## GSD Workflow Preferences` to CLAUDE.md with the plan's verbatim wording: a `### Discuss phases` list (fan out then synthesize, stakeholder-role lenses, primary sources, adversarial pass, one-shot auto-follow, UI/UX, dependencies, cheap checks first) and a `### Verify phases` list (shift left and automate, throwaway verification, record it so we never loop, CI efficiency sweep).
- Placed it immediately before the `GSD Workflow Enforcement` block (heading at line 232, Enforcement at 255); no other CLAUDE.md section, including the generated `Developer Profile` block, was touched.
- Added a 4-line `**CI efficiency sweep.**` paragraph to MAINTAINING.md at the end of `### CI cadence — PR-fast vs nightly/main-broad (Phase 196)`, pointing back to the CLAUDE.md section.

## Task Commits

1. **Task 1: Add the section to CLAUDE.md and the MAINTAINING.md pointer** - `4dd223ffc` (docs)

## Byte-pin check (plan precondition for the MAINTAINING.md edit)

The plan said to skip the MAINTAINING.md edit if any test pins its bytes. Result: **no pin found, edit applied.**

- `grep -rln "MAINTAINING.md" test scripts` returned 6 ExUnit planning tests (phases 50, 51, 57, 146, 222, 260), 5 prohibition scripts or fixtures and 2 helper scripts. All ExUnit hits do `read!`/`File.read!` plus regex or `=~` content assertions on named sections; none hashes or byte-compares the file.
- Searched the repo for the file's SHA-256 and git blob id: no hit anywhere.
- `scripts/ci/prohibitions/p07-docs-only-green-is-labelled.test.mjs` scopes its rot-surface bans (`ci.yml:<line>`, `N ExUnit files`, `~N min`) to the `### Honest-skip set after Phase 230` section only; the new paragraph sits before that heading and contains none of those shapes anyway.
- Phase 260's `PNG compare switch` paragraph test is a regex on that paragraph, which was not touched.

## Verification

- `git diff --stat` for the task commit: only CLAUDE.md and MAINTAINING.md.
- `grep -n "GSD Workflow Preferences" CLAUDE.md`: one heading, before `## GSD Workflow Enforcement`.
- `mix test` over every test file referencing MAINTAINING.md plus `test/sigra/brand/instruction_pointers_test.exs` (which reads CLAUDE.md): **48 tests, 0 failures, 8 skipped.** The 8 skips are all in `phase_50_nyquist_docs_contract_test.exs` (that whole module reports skipped, so it is independent of this edit); they were not caused by the change and are not a verification gap for the new text.
- `node --test scripts/ci/prohibitions/p07-docs-only-green-is-labelled.test.mjs`: 5 pass, 0 fail.
- PII grep over the added lines (home paths, email shapes, personal names): no hits.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] STATE.md had no `Quick Tasks Completed` table**
- **Found during:** state update
- **Issue:** `quick-tasks-append` warned "no Quick Tasks Completed section" and wrote nothing; the previous quick task (261115-dug) had no STATE row either.
- **Fix:** Created the `### Quick Tasks Completed` section with the canonical non-validate header (per quick.md step 7b) in STATE.md after the Session Continuity paragraph, then appended the row through `quick-tasks-append` (not hand-authored).
- **Side effect to know about:** the command also refreshed STATE.md frontmatter `last_updated` and `state_head` (now `4dd223ffc`). `.planning/state.json` and `.planning/config.json` were verified byte-identical before and after (SHA-256), and are not staged.
- **Files modified:** .planning/STATE.md

**2. [Rule 1 - Bug avoided] Relative markdown link replaced by plain text in MAINTAINING.md**
- **Found during:** Task 1
- **Issue:** the first draft linked `[CLAUDE.md](CLAUDE.md)`; MAINTAINING.md is a docs extra in `mix.exs` (ex_doc runs with warnings as errors) and CLAUDE.md is not, so the link would dangle on HexDocs.
- **Fix:** reworded to "the repository-root `CLAUDE.md`" in code formatting before committing.
- **Commit:** 4dd223ffc

No other deviations; ROADMAP.md was not touched, per the instructions.

## Known Stubs

None.

## Deferred Issues

None. No follow-up from the byte-pin check was needed because nothing is pinned.

## Threat Flags

None. Docs-only; no endpoints, auth paths, file access or schema changes.

## Self-Check: PASSED

- FOUND: CLAUDE.md `## GSD Workflow Preferences` (line 232) before `## GSD Workflow Enforcement` (line 255)
- FOUND: MAINTAINING.md `**CI efficiency sweep.**` paragraph
- FOUND: commit 4dd223ffc is an ancestor of HEAD
