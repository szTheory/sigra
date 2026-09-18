---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 10
subsystem: planning
tags: [criterion-amendment, scope-narrowing, decision-record, routed-finding, gap-closure, surf-01, surf-03]

requires:
  - phase: 239 (plan 09)
    provides: "The V3 vocabulary definition + allowlist and 239-EVIDENCE.md § VOCABULARY-LEDGER, where D-28 and D-30 are stated; the unchecked SURF-03 checkbox"
  - phase: 239 (plans 01–08)
    provides: "239-VERIFICATION.md's SC-1 and SC-2 gap entries with the measured per-file breakdown; 239-REVIEW.md's WR-04 and IN-05 findings; D-01 … D-26 in 239-CONTEXT.md"
provides:
  - "ROADMAP SC-2 amended to lib/+priv/ with an inline D-27 note stating what is given up"
  - "ROADMAP SC-1 amended to name V3 as its measuring definition, with the measured form and the allowlist path"
  - "A SURF-01 ↔ SC-2 consistency note quoting both scope clauses side by side"
  - "SURF-04 extended to own the packaged docs/ + README.md + CHANGELOG.md surface"
  - "D-27, D-28, D-29, D-30 in 239-CONTEXT.md's Implementation Decisions block"
  - "239-EVIDENCE.md § BATCH-JUSTIFICATION with an unfilled, greppable batch-3 slot"
  - "Three new pending todos: packaged-docs surface, WR-04, IN-05"
affects: [239-11, 239-12, 239-13, 241 SURF-04]

actuals:
  tokens: 8700
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "A criterion narrowing is legitimate only when every finding it removes leaves behind a named owner — here, two owners per finding (a requirement clause and a todo)"
    - "An amendment states in its own text what it gives up, so a later reader reconstructs the pre-amendment claim from the criterion itself"
    - "Bounding an unbounded amendment with an evidence obligation rather than by re-opening the criterion's prose (the prose carries other clauses)"

key-files:
  created:
    - .planning/todos/pending/2026-09-18-packaged-docs-surface-carries-planning-paths-into-the-hex-tarball.md
    - .planning/todos/pending/2026-09-18-wr-04-login-route-rationale-deleted-at-the-core-ex-source.md
    - .planning/todos/pending/2026-09-18-in-05-mfa-challenge-auto-submit-contradicts-the-strengthened-settings-comment.md
  modified:
    - .planning/ROADMAP.md
    - .planning/REQUIREMENTS.md
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-CONTEXT.md
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md

key-decisions:
  - "D-27: SC-2 narrows to lib/+priv/ — the claim narrows, the surface is not cleaned; the 58 packaged-docs occurrences are routed to Phase 241 SURF-04 plus a todo, never dropped"
  - "D-28: V3 is a measurement instrument only; SC-1 now names it, and naming it widens the bar because V3 strictly contains V2"
  - "D-29: the D-26 residue is bounded by an evidence obligation (per-batch justification recorded before the re-bless runs), not by restoring a count and not by re-amending SC-3/SURF-03 prose"
  - "D-30: detection width and asserted surface are separate — copied out of EVIDENCE into the decision block so 239-11 … 239-13 read it where they read D-01 … D-29"

patterns-established:
  - "Quote both texts side by side when asserting two documents describe the same surface — an inference a reader has to make is an inference a re-verifier can make differently"
  - "A deliberately unfilled slot with a greppable marker (`BATCH-3-JUSTIFICATION-PENDING`) so 'the obligation was skipped' is mechanically detectable, not a matter of noticing an absence"

requirements-completed: []

coverage:
  - id: D1
    description: "SC-2 claims only what holds (lib/+priv/), states what the narrowing gives up, and the 58-occurrence packaged-docs finding keeps two named owners"
    requirement: SURF-01
    verification:
      - kind: other
        ref: "bash: extracted SC-2 bullet contains lib/, priv/, D-27, the original 'source tree is never the thing that is asserted' clause, 'claimed' and 'Phase 241' (6/6); SURF-04 bullet contains docs/ + README.md + CHANGELOG.md AND all four pre-existing clauses; SURF-04 still '- [ ]' (count 1) with roll-up row 'Phase 241 | Pending'"
        status: pass
    human_judgment: false
  - id: D2
    description: "SURF-01's requirement sentence is byte-unchanged while the SC-2 ↔ SURF-01 consistency assertion is written down rather than inferred"
    requirement: SURF-01
    verification:
      - kind: other
        ref: "bash: git diff for REQUIREMENTS.md shows 0 removed lines containing **SURF-01**; the added consistency note contains both 'SC-2' and 'priv/templates/' and quotes each scope clause verbatim"
        status: pass
    human_judgment: false
  - id: D3
    description: "SC-1 names its measuring definition, states the measured form, names the allowlist file, and rules out the moved-goalpost reading"
    requirement: SURF-03
    verification:
      - kind: other
        ref: "bash: extracted SC-1 bullet contains VOCABULARY-LEDGER, 'strictly wider', 'moved goalpost', 'zero hits outside', '239-v3-allowlist.tsv', and still contains 'organizations.ex:59' (6/6)"
        status: pass
    human_judgment: false
  - id: D4
    description: "D-27/D-28/D-29/D-30 recorded in the block downstream executors read, each with alternatives-not-taken, a Reversibility line and an implementing plan; SC-3 and SURF-03 prose untouched"
    requirement: SURF-03
    verification:
      - kind: other
        ref: "bash: all four IDs present in 239-CONTEXT.md; `git diff HEAD~1 -- .planning/REQUIREMENTS.md` empty on the Task-2 commit; ROADMAP diff's only removed line is SC-1 (SC-3 bullet byte-unchanged)"
        status: pass
    human_judgment: false
  - id: D5
    description: "WR-04 and IN-05 tracked with their out-of-range diagnoses; no source file moved anywhere in this plan"
    verification:
      - kind: other
        ref: "bash: both todos non-empty with status: pending + audit_acknowledged/milestone v1.48; WR-04 contains core.ex:503, live_session :redirect_if_user_is_authenticated and phx-submit; IN-05 names both files and 'lockout'; `git diff --name-only HEAD~3 -- priv/ test/ lib/ .github/ CHANGELOG.md README.md docs/ mix.exs` => 0 lines"
        status: pass
    human_judgment: false

duration: 22min
completed: 2026-09-18
status: complete
---

# Phase 239 Plan 10: Criteria That Claim Only What Holds Summary

**Phase 239's two over-claiming criteria now state their real scope in their own text, and every finding that narrowing removes from the phase has two named owners downstream — so the amendment is a correction, not a deletion.**

## Performance

- **Duration:** ~22 min
- **Tasks:** 3 of 3
- **Files modified:** 7 (3 created, 4 modified)

## Accomplishments

- **SC-2 stops over-claiming (D-27).** The criterion now reads "greps clean for `.planning/` paths **under `lib/` and `priv/`**", keeping its original `the source tree is never the thing that is asserted` clause byte-intact, and carries an inline amendment note in SC-3's established style. The note says out loud what the narrowing gives up: **it narrows what is claimed, not what is cleaned** — the 58 occurrences still ship after this phase closes.
- **The measurement was re-taken, not copied.** The plan cited per-file counts summing to 32 against a stated total of 58. Both numbers are real and they measure different things: **58 occurrences across 32 matching lines in 6 files** (`CHANGELOG.md` 43/19, `docs/uat-ci-coverage.md` 7/6, `docs/ga-evidence.md` 3/3, `docs/nyquist-posture-matrix.md` 3/2, `docs/audit-semantics.md` 1/1, `README.md` 1/1). Both are recorded everywhere the figure appears, because either one alone reads as the whole truth.
- **The finding kept two owners.** SURF-04's requirement text now names `docs/`, `README.md` and `CHANGELOG.md` as packaged surfaces its monotonic-decrease ratchet covers, with all four of its pre-existing clauses intact and its checkbox still `[ ]` / `Phase 241` / `Pending`. A new todo carries the measured breakdown, the `mix.exs:184` `files:` list verbatim, the D-05/D-06 reason the surface was deliberately left, and cross-references to the two existing SURF-04 inheritance todos so a triager reads one cluster.
- **SURF-01 ↔ SC-2 consistency is asserted, not inferred.** A note quotes both scope clauses side by side and states the containment plainly: `priv/templates/` ⊂ `priv/`, so SC-2 is the wider of the two and SURF-01 cannot pass while SC-2 fails. SURF-01's own requirement sentence is byte-unchanged.
- **SC-1 names a strictly wider instrument (D-28).** "Planning bookkeeping" is now measured under V3, recorded in `239-EVIDENCE.md` § `## VOCABULARY-LEDGER`, with the measured form spelled out — **zero hits outside** the committed per-line allowlist (named by path) over the frozen tier file lists — and an explicit sentence ruling out the moved-goalpost reading: a narrower instrument would be a moved goalpost, this one is wider and the containment is checkable against the ledger.
- **D-29 bounds D-26's residue without re-opening its prose.** "One re-bless per batch" stays unbounded; what changes is that every batch must now be justified by name in `239-EVIDENCE.md` *before* its re-bless runs. `## BATCH-JUSTIFICATION` exists with batch 1 and batch 2 justified retrospectively and batch 3 left explicitly unfilled behind the greppable marker `BATCH-3-JUSTIFICATION-PENDING`.
- **WR-04 and IN-05 are tracked, with their roots located.** Neither is fixed. WR-04's todo names the fix *order* — `core.ex:503` first, then the example mirror, then the golden re-bless — so the next owner does not re-derive that the example is the reflection and not the defect. IN-05's todo states why it is a correctness question: the challenge screen is the one guarded by the lockout counter the settings comment cites, so the sibling with the weaker comment carries the higher consequence.

## Task Commits

1. **Task 1: D-27 — narrow SC-2, assert SURF-01 consistency, route the packaged docs surface** — `41c62dc6` (docs)
2. **Task 2: Record D-27/D-28/D-29/D-30 and amend SC-1** — `2168498a` (docs)
3. **Task 3: File WR-04 and IN-05 as todos** — `89de04a2` (docs)

## Backstop check: did the SC-2 amendment relax anything beyond scoping?

Clause-by-clause diff of the old and new bullet:

| Clause | Old | New | Delta |
|---|---|---|---|
| Vehicle — "The `mix hex.build` **tarball**, extracted" | present | present | unchanged |
| Assertion — "greps clean for `.planning/` paths" | present | present | unchanged |
| Scope qualifier | *absent* | "**under `lib/` and `priv/`**" | **added** |
| "the source tree is never the thing that is asserted" | present | present | byte-unchanged |
| Amendment note | absent | D-27 note | **added** |

No clause was removed, softened or re-worded. The only semantic change is the added scope qualifier;
everything else is additive. `git diff` confirms the ROADMAP's only removed lines across both commits
are the single old SC-2 line and the single old SC-1 line — SC-3, SC-4 and SC-5 are byte-identical.

## Deviations from Plan

**1. [Rule 1 — measurement correction] The plan's quoted per-file breakdown did not sum to its stated total**

- **Found during:** Task 1
- **Issue:** The plan (and `239-VERIFICATION.md`) quoted per-file counts of CHANGELOG.md 19, docs/uat-ci-coverage.md 6, docs/ga-evidence.md 3, docs/nyquist-posture-matrix.md 2, docs/audit-semantics.md 1, README.md 1 as "total 58". Those sum to **32**. Writing 58 next to rows that sum to 32 would have shipped an arithmetic contradiction into a criterion.
- **Fix:** Re-measured at HEAD. The quoted rows are *matching lines*; 58 is the *occurrence* count. Both are recorded, labelled, in all three places the figure appears (SC-2 note, D-27, the todo), with a sentence in the todo explaining why both are kept.
- **Files modified:** `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, the packaged-docs todo
- **Commit:** `41c62dc6`

**2. [Rule 2 — auditability] `BATCH-3-JUSTIFICATION-PENDING` marker added**

- **Found during:** Task 2
- **Issue:** The plan asked for an "explicitly empty, labelled slot". An empty slot is detectable only by a reader noticing an absence, which is the failure mode D-29 exists to prevent.
- **Fix:** The slot carries the literal marker `BATCH-3-JUSTIFICATION-PENDING`, and the section states that a re-bless running while the marker is present is a D-29 violation — so plan 239-12's discharge is mechanically checkable with one grep.
- **Files modified:** `239-EVIDENCE.md`
- **Commit:** `2168498a`

No other deviations. No existing todo already owned any of the three findings, so all three were filed as new files — no extend-instead-of-duplicate case arose.

## Known Stubs

None. The `BATCH-3-JUSTIFICATION-PENDING` slot is an intentional, documented obligation owned by plan
239-12, not a stub: it is named in D-29, in the section header, and in this summary, and the plan that
fills it is identified by number.

## Threat Flags

None. No file under `priv/`, `test/`, `lib/`, `.github/`, nor `CHANGELOG.md`, `README.md`, `docs/` or
`mix.exs` was modified — `git diff --name-only HEAD~3 -- priv/ test/ lib/ .github/ CHANGELOG.md README.md docs/ mix.exs`
returns nothing. All three new todos carry repo-relative paths and quoted repo content only, with no
home-directory paths, adopter PII, or brand hex values (T-239-10-03 satisfied).
