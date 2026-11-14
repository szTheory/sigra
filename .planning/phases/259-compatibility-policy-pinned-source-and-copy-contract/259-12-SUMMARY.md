---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 12
subsystem: docs
tags: [admin-glossary, brand-book, vocabulary, doc-contract, exunit, anchors]

requires:
  - phase: 259-01
    provides: the compatibility decisions on Suspended (out of scope) and the status labels (Active, Unconfirmed, Locked, Deletion scheduled kept) that rulings 2, 3 and 5 follow
  - phase: 259-02
    provides: guides/reference/brand-compatibility.md, whose ownership lanes the section points at
  - phase: 259-08
    provides: test/sigra/brand/copy_contract_test.exs, named in the Enforcement column and checked for existence by the new test
provides:
  - a "Brand book v2.0 reconciliation" H2 in guides/reference/admin-glossary.md with 23 rows, each marked Agrees (11) or Differs (12) against the book
  - the seven rulings (sign in, Locked vs Suspended, Deletion scheduled, revoke/delete/remove, Active/Unconfirmed/Locked status vocabulary, Admin not Admin (operator), Review users) with grep-derived full-path file:line anchors
  - test/sigra/brand/vocabulary_docs_test.exs, a doc contract that reads voice.terms from the pinned brand.json at run time and verifies every anchor against the source
affects: [259-11, 262, 263]

actuals:
  tokens: 9028
  tasks: 3
  commits: 3
commits: 3
plan_head_before: 8ccbbf274551cac7b6b0211e086a5bcf7ee131e6
plan_head_after: 35a2fff59e68179b24c5d7a36d875f0e926febfb

tech-stack:
  added: []
  patterns:
    - "Doc-contract test over a Markdown section: pure helpers (section_slice, anchors, bad_anchors, unverified_anchors, uncovered_terms), each shown red on a planted bad input before its verdict on the real file is trusted"
    - "Anchors are full repo paths plus a line, and the test requires each anchor's line to still hold a term registered for that file, so one drifted anchor cannot hide behind a sibling"
    - "The book's term list is read from the pinned brand.json at run time, so a re-vendored book forces a new row instead of silently narrowing coverage"

key-files:
  created:
    - test/sigra/brand/vocabulary_docs_test.exs
  modified:
    - guides/reference/admin-glossary.md
    - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/deferred-items.md

key-decisions:
  - "Every row opens its Context rule with Agrees or Differs; Differs means the book and the glossary disagree on a word or meaning, or the book names a word or state the glossary has no row for. Rows are not defaulted to Agrees: 12 of 23 differ."
  - "The Banned synonyms cell carries the book's avoid text; words only the glossary bans are named in the Context rule, so the two lists are never presented as equal"
  - "revoke is marked Differs: the book bans cancel without qualification, the glossary keeps cancel for an invitation not yet sent, and the glossary governs Sigra-owned copy"
  - "The status vocabulary row is recorded as a TARGET: the shipped pill still reads Confirmed (user_show_live.ex:332) and Active is only the stat label Active users (index_live.ex:96); aligning it is a later copy change, not claimed as done"
  - "The Locked row states the admin has no unlock control and that the shipped sentence at user_show_live.ex:385 points at one that is not there, instead of repeating the book's claim that an admin can unlock"
  - "Review users is two rows (shipped copy, and the documentation example in components.ex) so the three-term line-count acceptance criterion holds on separate rows rather than by cramming"

patterns-established:
  - "Published guide prose cites test file paths in the Enforcement column and no plan, planning path or decision number; the test flags all three"

requirements-completed: [BCOPY-01]

coverage:
  - id: D1
    description: "guides/reference/admin-glossary.md carries one 'Brand book v2.0 reconciliation' H2 after the Canonical Terms rules and before the Voice Rubric, with the four-column header and a row for every voice.terms term, each opening its Context rule with Agrees or Differs"
    requirement: BCOPY-01
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand/vocabulary_docs_test.exs#placement, #table shape, #the book's vocabulary (every voice.terms term heads a row marked Agrees or Differs)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The seven rulings are present with product-truth anchors that name a real file and line, whose line still holds the cited term, and every anchor sits on a registered term line"
    requirement: BCOPY-01
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand/vocabulary_docs_test.exs#anchors (resolve, floor of 6, content per pair, every anchor on a registered term line, planted miss per pair)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The Agrees/Differs verdict per row and the choice of which spelling governs Sigra-owned copy; rulings 2, 3 and 5 follow decisions recorded as 'Recommended default - owner confirmation pending'"
    requirement: BCOPY-01
    verification: []
    human_judgment: true
    rationale: "A test can prove the table is complete, marked and anchored, not that a given verdict is the owner's intent; the owner reviews the 12 Differs rows and the three pending-confirmation rulings."
  - id: D4
    description: "Published-text hygiene: no plan number, planning path or decision number in the section; every Enforcement cell names an existing test file or the word editorial; glossary drift guard, copy contract and brand tests still green"
    requirement: BCOPY-01
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand test/sigra/admin/glossary_test.exs test/sigra/architecture_guides_contract_test.exs (285 tests, 0 failures)"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-11-14
status: complete
---

# Phase 259 Plan 12: Brand Book Vocabulary Reconciliation Summary

**The admin glossary now reconciles every brand book voice.term (17 at the pinned v2.0) in one 23-row Agrees/Differs table with seven rulings anchored to verified file:line product truth, guarded by a doc test that reads the book at run time and turns red on a missing term, a stripped marker or a drifted anchor.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-11-14T17:13:49Z
- **Completed:** 2026-11-14T17:26:29Z
- **Tasks:** 3 of 3
- **Files modified:** 3 (glossary, new doc test, deferred-items log)

## Accomplishments

- Added the "Brand book v2.0 reconciliation" H2 to `guides/reference/admin-glossary.md`: 23 rows (11 Agrees, 12 Differs) in the book's own order, reusing the glossary's four columns, with no change to the H1, any existing row or the Voice Rubric.
- Recorded all seven rulings with anchors produced by grep at edit time: sign in (the demo host's "Log in" at `test/example/lib/example_web/controllers/session_html.ex:58` is host-owned), Locked vs Suspended (Locked at `user_show_live.ex:335`, `:385`; Suspended is out of scope and no Suspended copy may ship), Deletion scheduled kept (`user_show_live.ex:336`), revoke/delete/remove, the status vocabulary as a target (shipped pill "Confirmed" at `user_show_live.ex:332`, "Active users" at `index_live.ex:96`), "Admin" not "Admin (operator)" (`personas.ex:60`), and "Review users" not "Review accounts" (`index_live.ex:49`, `:72`; the doc example at `components.ex:532`).
- Wrote `test/sigra/brand/vocabulary_docs_test.exs` (26 tests): placement, four-column header, per-row marker, nine required terms, voice.terms coverage read from `brand/brand.json`, anchor existence and range, anchor floor of six, per-pair content check, every-anchor-on-a-registered-term-line check, planning-citation hygiene and Enforcement-path existence, each with a planted control.
- Mutation-checked the real section: removing a row's marker, deleting a book term's row, shifting one anchor by a line and inserting a plan number each turned the suite red, and the glossary was restored byte-identical after each.

## Task Commits

1. **Task 1 (tracer): doc test plus rulings 1-3 (sign in, Locked vs Suspended, Deletion scheduled)** - `f1953e7bb` (docs)
2. **Task 2: rulings 4-7 (revoke/delete/remove, status vocabulary, Admin, Review users) and anchor-content checks** - `711fe5860` (docs)
3. **Task 3: Agrees/Differs rows for every voice.terms term and the coverage test** - `35a2fff59` (docs)

**Plan metadata:** the docs(259-12) commit that adds this SUMMARY, the deferred-items entry, STATE, ROADMAP and REQUIREMENTS.

The tracer gate ran after Task 1: HUMAN_VERIFY_MODE is end-of-phase and the verify was automated-only, so the tracer verify was re-run (20 tests, 0 failures) and the plan expanded.

## Files Created/Modified

- `guides/reference/admin-glossary.md` - the new reconciliation H2 and table (32 added lines)
- `test/sigra/brand/vocabulary_docs_test.exs` - the doc contract and its planted controls
- `.planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/deferred-items.md` - four out-of-scope findings for the copy phase

## Decisions Made

See `key-decisions` above. The load-bearing ones: Differs is used where the book and glossary disagree or the glossary has no row (12 rows), the Banned synonyms cell carries the book's avoid text with glossary-only words named in the rule, and the status vocabulary is recorded as a target rather than as shipped fact.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical] Anchor check strengthened so one drifted anchor cannot hide**
- **Found during:** Task 3 (mutation check)
- **Issue:** The plan's per-pair rule ("at least one anchor for the file lands on a line holding the term") passed when I shifted `user_show_live.ex:335` to `:334`, because `:385` still held "Locked". That leaves the T-259-39 failure mode (a stale anchor giving false product evidence) open.
- **Fix:** added `unverified_anchors/2` and a test that every anchor in the section sits on a line holding a term registered for its file, plus a planted control (a drifted line and an unregistered file are both listed). Re-ran the shift mutation: red.
- **Files modified:** `test/sigra/brand/vocabulary_docs_test.exs`
- **Commit:** `35a2fff59`

**2. [Rule 1 - Bug] Wrong Enforcement claim caught before commit**
- **Found during:** Task 3 self-review of the finished table
- **Issue:** the lock row cited `test/sigra/admin/glossary_test.exs` as enforcement, but that test bans no word for lock (its banned list has no freeze, suspend or disable; the existing glossary row says editorial).
- **Fix:** the row now cites the copy contract for "freeze" and says editorial for "suspend" and "disable". I re-checked every other Enforcement claim against the banned lists in `glossary_test.exs` and `test/support/brand/copy_scan.ex`.
- **Files modified:** `guides/reference/admin-glossary.md`
- **Commit:** `35a2fff59`

**3. [Rule 3 - Blocking] Review users split into two rows**
- **Found during:** Task 2 acceptance check
- **Issue:** the criterion counts lines holding "Admin (operator)", "Review users" or "Review accounts" (at least 3), but ruling 7 sat on one table row, giving 2.
- **Fix:** split ruling 7 into two honest rows (shipped copy, and the library documentation example), not by padding.
- **Commit:** `711fe5860`

**4. [Rule 2 - Missing critical] Extra anchors and a corrected product claim**
- **Found during:** Task 1
- **Issue:** the book says an admin can unlock a Locked user, and the shipped sentence at `user_show_live.ex:385` says "unlock below", but a search of `lib/`, `priv/` and `test/example/lib` finds no unlock control or handler.
- **Fix:** the Locked row says so instead of repeating the claim, citing `lib/sigra/lockout.ex:8` (auto-unlock) and the `:385` sentence; the test registers terms "unlock below" and "auto-unlocks" so those anchors are content-checked too. Also registered "No flagged accounts" (`index_live.ex:51`), "Unconfirmed" and "Log in" for the extra anchors.
- **Files modified:** `guides/reference/admin-glossary.md`, `test/sigra/brand/vocabulary_docs_test.exs`
- **Commit:** `f1953e7bb`, `711fe5860`

**5. Matching rule slightly wider than the plan states**
- The coverage helper also strips `*` and backticks and matches on word boundaries, because a first cell such as `**role** and **permission**` carries emphasis between the words of a book term, and a bare substring match would let "User" be satisfied by "Review users". Case and curly-apostrophe handling are as specified.

**Total deviations:** 5 (2 Rule 2, 1 Rule 1, 1 Rule 3, 1 interpretation note). **Impact:** all tighten the guard or correct a claim; no scope was added outside the two plan files plus the deferred-items log, and nothing under `lib/`, `priv/`, `brand/`, `brandbook/`, `.github/`, `scripts/` or the demo host changed.

## Issues Encountered

None blocking. Four out-of-scope findings were logged to `deferred-items.md`: the shipped copy that promises an unlock control the admin lacks, "accounts" as a person-noun in shipped admin copy (no test catches it), the "Confirmed" pill, and stale short-name anchors in the glossary's own Voice Rubric exemplars (`user_show_live.ex:81` and `:89` now live in `user_sessions_live.ex:83` and `:91`).

## Known Stubs

None. No stub, skipped test or unrun verify was introduced, so nothing was appended to `.planning/WINDOWS.md`.

## Threat Flags

None. No file touched introduces network, auth, file-access or schema surface.

## Next Phase Readiness

Plans 259-11 remains in the phase. The table gives the copy phases (262-263) a single agreed vocabulary and a verified list of shipped strings that still differ from it; the status pill, the unlock sentence and the "accounts" wording are the concrete rewrites. The ADR decisions behind rulings 2, 3 and 5 are still marked owner confirmation pending.

## Self-Check: PASSED

- Files exist: `guides/reference/admin-glossary.md`, `test/sigra/brand/vocabulary_docs_test.exs`, `.planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/deferred-items.md`.
- Commits reachable from HEAD: `f1953e7bb`, `711fe5860`, `35a2fff59`; `git rev-list --count 8ccbbf274..HEAD` is 3 at write time.
- All task acceptance criteria re-run and passing; `mix test test/sigra/brand test/sigra/admin/glossary_test.exs test/sigra/architecture_guides_contract_test.exs` is 285 tests, 0 failures; `mix format --check-formatted` clean; the zero-shipped-bytes gate and the privacy gate both pass.
