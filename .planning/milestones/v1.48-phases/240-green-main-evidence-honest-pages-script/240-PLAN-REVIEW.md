---
phase: 240
slug: green-main-evidence-honest-pages-script
artifact: plan-review
status: passed
iterations: 2
created: 2026-09-18
---

# Phase 240 — Plan Verification Record

`gsd-plan-checker` returns its verdict to the orchestrator and writes no file of its
own. This document persists that verdict so the reasoning survives a context reset.
It is a record, not an input: nothing in `/gsd-execute-phase` reads it.

## Final verdict

**PASSED** after 2 revision iterations. All gates green at `bdad8398`.

| Gate | Result |
|---|---|
| Plan checker (12 checks) | pass (iteration 2) |
| Requirements coverage | 2/2 — GREEN-04 → plans 02/03/04; GREEN-05 → plans 01/05 |
| Decision coverage (§13a, blocking) | 28/28 |
| Post-planning gap analysis | 30/30 |
| Frontmatter + structure | 5/5 valid, 0 errors |

## Blockers found and fixed

### B-1 — job-name selector contract (iteration 1, commit `14d44af0`)

Plan 02 gives `green_04_evidence_repeat` both a `name:` and a
`strategy.matrix.repeat: [1..20]`. Per this repo's own comment at `ci.yml:556-560`,
a bare matrix on a *named* job makes the API emit `Name (1)`…`Name (20)` — never a
bare `Name`. Plan 03 Task 1 selected legs by exact equality (`.name == $JOB_NAME`),
which yields zero legs and a spurious `insufficient_legs`.

Four aggravating factors made this worth blocking on rather than noting:

1. Plan 03 was internally contradictory — it also asked to parse a trailing
   parenthesised integer, so the two halves of one task disagreed.
2. Its acceptance criterion *entrenched* the bug ("byte-identical" to the
   equality form), so review would have ratified it.
3. Plan 04 already used the correct `startswith`, so the plans disagreed with
   each other about the same API contract.
4. Worst: plan 03's hermetic stub would have been built to the same wrong shape.
   The self-test would have gone green against a payload the real API never
   emits, all the way up to an irreversible 75–100 runner-minute dispatch.

**Fix:** anchored regex `^<JOB_NAME> \((\d+)\)$` with `matrix_repeat` taken from
that same capture group; a new `no_matrix_suffix` failure token distinct from
`insufficient_legs`; acceptance rewritten to prefix-identity plus `grep -n '\.name =='`
returning no hit; the stub generates all 20 names from a `1..20` loop with
`FAKE_JOB_NAME_SHAPE` (`suffixed`|`bare`) driving a `bare_job_names` negative
control off the *same* generator. The contract paragraph is byte-identical across
plans 02/03/04 (md5 `ff4fbb3e3c760808057f9e3e63f8f230`, 698 bytes).

### B-2 — decision-coverage placement (iteration 2, commit `fd4dbd45`)

`check.decision-coverage-plan` reported `passed: false, total: 28, covered: 25,
uncovered: [D-01, D-03, D-05]`. Root cause was citation **placement**, not missing
coverage: those three appeared only in `##` prose sections of `240-02-PLAN.md`
(lines 72, 91, 95, 108, 110). The gate scans frontmatter `must_haves`/`truths`/
`objective`, `## must_haves`/`truths`/`tasks`/`objective` headings, and the
`<objective>`/`<tasks>`/`<task>`/`<action>`/`<read_first>`/`<behavior>`/`<verify>`/
`<acceptance_criteria>`/`<done>` bodies — prose sections are invisible to it.

**Fix:** D-01 → Task 1 `<action>`; D-03 → Task 2 `<action>`; D-05 → Task 1
`<action>` as a recorded rejected alternative. 4 insertions, 2 deletions. Gate
then returned `passed: true, covered: 28`.

**Gate footgun worth remembering:** `check.decision-coverage-plan` takes **two**
positional args (`<phase_dir> <context_path>`). Called with one it returns
`{"passed": false, "skipped": false, "reason": "missing context path argument",
"total": 0, ...}`. During iteration 2 this was first misread as the gate being
blind to the bullets — a false-negative reading that failed in the *reassuring*
direction. Both invocation forms were then verified directly; the parser handles
all 28 bullets correctly.

## Smaller corrections applied during revision

- Plan 02 Task 1's `<verify>` invoked a guard that Task 2 creates — Task 1 would
  have failed its own verify. Replaced with a self-contained `node -e` structural
  check that strips `#`-comment lines *before* asserting `needs:`/`concurrency:`
  absence (the header comment deliberately names both omissions, so an unfiltered
  grep would have been self-invalidating).
- D-02's exceptions were mandated in prose but never acceptance-asserted. Added
  explicit criteria, including: an exception present in the YAML but absent from
  the header is a failure of this criterion.
- "eleven steps" corrected to thirteen — `ci.yml:1401-1533` has 3 unnamed `uses:`
  + 6 named + 4 uploads.
- D-22's line citations were off by one in CONTEXT.md. The three `|| true`
  build-trigger swallows are at `ensure-github-pages-legacy-branch.sh:30`, `:50`,
  `:75` — not `:31`/`:52`. Confirmed independently by researcher and
  pattern-mapper; corrected throughout the plans.
- `check gap-analysis` is not a subcommand; the correct name is
  `check gap-analysis-plan-post` (dots→hyphens).

## Conflicts reconciled between locked CONTEXT decisions and research findings

- D-02's byte-faithfulness vs the `upload-artifact` name collision.
- SC-3's "fails loudly on a 403" vs D-19's tolerable PUT-403.
- D-12's "modelled on fast-01" vs the jobs-endpoint code actually living in
  `capture-terminal-ratification-evidence.sh`.

## Known fragility carried forward (documented, not fixed)

- `p12-run-id-provenance.test.mjs:26` is hardcoded to
  `.planning/phases/230-…/230-EVIDENCE.md` and reaches 240 only via
  `GSD_PROHIB_SUBJECT`. Generalising it is deferred to Phase 241's existing todo.
- `236-EVIDENCE.md` uses a bare `Status: captured` that would fail p12's regex; it
  passes today only because p12 never reads it.
- Two `capture-*.test.sh` self-tests have no CI caller at all.

## Operator notes for execution

- Waves 1–2 are `autonomous: true`. Waves 3–4 (`240-04`, `240-05`) are
  `autonomous: false` and operator-credentialed.
- **D-13 ordering trap:** nothing may be committed to `main` between the
  squash-merge and the evidence capture. The dispatch must run at the final
  committed HEAD on a clean tree, or the run ids do not prove what the slot claims.
- Plan 05 holds the phase's only one-way action — a public comment on issue #231 —
  behind a `checkpoint:decision`.
- Per D-20 the 403 branch is unreachable on the real repo (Pages is
  `built/legacy/gh-pages//`). The proof is a fake-`gh`-on-PATH stub. No task may
  deliberately misconfigure Pages on the public repo to manufacture a live 403.
