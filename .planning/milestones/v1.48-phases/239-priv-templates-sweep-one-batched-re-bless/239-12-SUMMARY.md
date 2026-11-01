---
phase: 239-priv-templates-sweep-one-batched-re-bless
plan: 12
subsystem: installer-golden-fixture
tags: [gap-closure, surf-01, surf-03, re-bless, d-29, classifier, red-green]
status: complete

requires:
  - phase: 239 (plan 09)
    provides: "239-v3-vocabulary-check.sh + 239-v3-allowlist.tsv, frozen (D-30); the golden tier's RED half (hits_outside_allowlist=2)"
  - phase: 239 (plan 10)
    provides: "D-26 (one re-bless per batch) and D-29 (every batch justified before it runs); § BATCH-JUSTIFICATION with its unfilled batch-3 slot"
  - phase: 239 (plan 11)
    provides: "the batch-3 template edits (7eee6b00) and their test/example mirror (8dc2ecc4) — the drift this plan carries into the fixture"
provides:
  - "test/fixtures/install_golden/ carries batch 3: one batched re-bless commit (87581665), nothing else in it"
  - "`MIX_ENV=test mix sigra.fixture.rebless_golden --check` exit 0 — the golden tree is again provably equal to freshly generated output"
  - "golden tier GREEN under V3 (hits=0, outside=0, control_defmodule=78, files_measured=84) — the RED/GREEN pair plan 239-09 opened on this tier is closed"
  - "D-29 discharged for batch 3: the BATCH-3-JUSTIFICATION-PENDING marker is gone, replaced by composition + not-foldable argument, in a strict ancestor of the re-bless commit"
  - "239-golden-expected-3.txt (frozen round-3 expected-removed set) + fixtures/239-golden-rebless3-code-change.diff (round-3 known-bad fixture)"
  - "239-EVIDENCE.md §§ REFREEZE-LEDGER-3 and REBLESS-COMMIT-3"
affects: [239-13]

actuals:
  tokens: 7300
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Freeze-before-bless as a commit-graph property: the expected set lands in a strict ancestor of the re-bless commit, proven by `git merge-base --is-ancestor`, not by prose ordering"
    - "Two floors for two jobs: GOLDEN_MIN_FILES=1 on a single-hunk known-bad fixture (must fail on the code line), the computed value on the real diff (the run the floor protects) — both numbers recorded side by side"
    - "Re-run the generator, not the record: the re-bless ran twice (capture, then commit) and the two diffs were proven byte-identical, giving one commit and a real-shaped known-bad fixture"

key-files:
  created:
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-golden-expected-3.txt
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/fixtures/239-golden-rebless3-code-change.diff
  modified:
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/invitation_accept_live.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_members_live.ex
    - .planning/phases/239-priv-templates-sweep-one-batched-re-bless/239-EVIDENCE.md

key-decisions:
  - "The re-bless was run twice deliberately — once before the freeze to capture the real diff shape the known-bad fixture is derived from, then restored path-scoped and run again for the commit. SC-3 counts commits, not runs; the two captures are byte-identical, which also makes the run deterministic on the record"
  - "GOLDEN_MIN_FILES computed as 2 (the expected set's distinct-path count) for the real classification and left at 1 only for the single-hunk RED demonstration; both numbers plus the reason are in the ledger so the pair cannot read as a contradiction"
  - "The freeze commit records everything about the freeze EXCEPT the two shas, which a commit cannot carry about itself while staying path-scoped; the shas and their ancestor proof land in the final docs commit as § REBLESS-COMMIT-3"

requirements-completed: []

metrics:
  duration: ~35m
  completed: 2026-09-18
---

# Phase 239 Plan 12: Batch-3 Freeze and Re-bless Summary

Carried the batch-3 template edits into the golden fixture with one batched re-bless whose diff was
proven comment-only against an expected set frozen in a strict ancestor commit — closing the `golden`
tier's RED/GREEN pair at `hits_outside_allowlist=0` under the untouched V3 instrument, and
discharging D-29's batch-3 justification before the re-bless ran rather than after.

## What Changed

| # | Commit | Scope |
|---|---|---|
| 1 (freeze) | `4f94278f` | exactly 3 paths: `239-golden-expected-3.txt`, `fixtures/239-golden-rebless3-code-change.diff`, `239-EVIDENCE.md`. Zero paths under `test/fixtures/install_golden/`. |
| 2 (re-bless) | `87581665` | exactly the 2 golden files batch 3 renders into. Zero other paths. |
| 3 (docs) | this summary | `239-EVIDENCE.md` § `REBLESS-COMMIT-3`, `239-12-SUMMARY.md`, `STATE.md`, `ROADMAP.md` |

`git merge-base --is-ancestor 4f94278f 87581665` → exit 0, shas distinct. D-19 topology holds.

## Verification

| Check | Result |
|---|---|
| `--check` precondition (start of plan) | **exit 2**, `DRIFT DETECTED:` on exactly the 2 batch-3 files |
| Classifier RED (known-bad fixture, `GOLDEN_MIN_FILES=1`) | **exit 1**, `nonconforming=1`, offending line named: `-  defp render_mismatch(assigns) do` |
| Classifier fail-closed (empty diff on stdin) | **exit 1**, `refusing to report success on no input` |
| Classifier GREEN (real diff, `GOLDEN_MIN_FILES=2`) | **exit 0** — `changed_lines=10 removed_lines=5 files=2 nonconforming=0 nonconforming_removed=0 nonconforming_files=0 nonconforming_addonly_hunks=0 removed_lines_floor=2` |
| Non-vacuity floor cleared, not disabled | `GOLDEN_MIN_FILES=2` = reported `files=2` = expected-set distinct paths `2`; `removed_lines=5 >= floor 2` |
| `--check` after the commit, clean tree | **exit 0**, `OK: fixture is up-to-date (check mode.)`; `git diff --quiet` → 0 |
| V3 `golden` tier | `hits=0 allowlisted=0 hits_outside_allowlist=0 control_defmodule=78 files_measured=84`, **exit 0** (was `outside=2`, exit 1) |
| `STDOUT.txt` under V3 (D-13) | **0** hits, positive control (`sigra`) **83**, 186 lines |
| Instrument + allowlist byte-unchanged | `git diff --name-only 4f94278f~1..HEAD --` those two paths (and the classifier): empty |
| `.github/`, `lib/`, `priv/`, `test/example/` untouched | `git diff --name-only 4f94278f~1..HEAD --` those: empty |
| Exactly one re-bless commit | `git log --format=%H 4f94278f..HEAD -- test/fixtures/install_golden \| wc -l` → **1** |
| Re-bless commit isolation | `git show --name-only --format= 87581665 \| grep -cv '^test/fixtures/install_golden/'` → **0** |
| SURF-03 still `[ ]` | `grep -c '^- \[ \] \*\*SURF-03\*\*' .planning/REQUIREMENTS.md` → **1** (control: 3 total mentions) |
| Determinism | the two captured re-bless diffs (pre-freeze and post-freeze runs) are byte-identical |

Full record: `239-EVIDENCE.md` §§ `## REFREEZE-LEDGER-3` (a)–(h) and `## REBLESS-COMMIT-3` (a)–(h).

## Round-3 Expected Set

2 `T:` records (the two SC-1 gap sentences, matched by V3) + 3 `N:` records (the WR-01 prose lines
and the pagination bullet, located by literal anchor), across 2 distinct golden paths. **5 anchors →
5 records**, every anchor a line removed from a template by `7eee6b00`, searched with `grep -nF` only
inside that template's own golden counterpart. No blanket radius; nothing derived from the diff it
validates.

## Deviations from Plan

**1. [Rule 3 - Blocking] The round-3 generator, pasted from round 2's header line, was a dead command**

- **Found during:** Task 1, expected-set generation
- **Issue:** Round 2's header line carries an inline `#` comment between `BASE=…` and `V3=…`. Executed
  verbatim, that `#` comments out the entire rest of the line, and the generator emitted **zero**
  records — a result indistinguishable from "the golden tree is already clean", which would have made
  the expected set empty and the classifier vacuous.
- **Fix:** Caught by the paired positive control (`grep -cE '\bdefmodule\b'` over the same 84-file
  list, non-zero) before anything was written. Re-generated with the comment removed from the command
  form while keeping it in the file's header line. Recorded in evidence § `REFREEZE-LEDGER-3` (h).
- **Files modified:** none (a measurement fix, not a code change)
- **Commit:** `4f94278f`

**2. [Sequencing, not a scope change] The re-bless was run twice**

The known-bad fixture must be derived from the *real* diff shape, which does not exist until a
re-bless has run — but the freeze commit must precede the re-bless commit. Resolved by running the
re-bless before the freeze to capture the diff, restoring with a path-scoped
`git checkout -- test/fixtures/install_golden` (the only path the task writes), committing the
freeze, then running it again for the commit. SC-3 as amended by D-26 counts *commits*: exactly one
landed. The two captures are byte-identical, which is recorded as a determinism result rather than
glossed over.

## Open / Routed

- **SURF-03 stays `[ ]` by design.** Plan 239-13 re-checks it last and alone, after the live external
  observations. Not flipped here even though every check in this plan is green.
- **T-239-12-03 carried to plan 239-13 Task 1:** the two observations the WR-01 replacement rests on
  (T19's subject is the template path; the generated `test/` tree contains 0 `_test.exs` files) must
  be re-made against a freshly generated app with a `*.exs` positive control, not cited from plan
  239-11's SUMMARY, which measured them against the committed snapshot.
- **No `MIX_ENV=test mix ci` run here**, by declared plan boundary. The full gate, the fixed-string
  proof on a freshly generated app, the tarball under the D-27 scope, SC-5's two-base re-proof and
  the three-tier re-confirmation at final HEAD are plan 239-13's.
- **No `install_golden_contract` CI claim.** This phase pushes nothing; the Actions clause remains a
  recorded ship-time deferral.
- **Every line number in this plan's and plan 239-11's evidence is invalidated by this re-bless.**
- The three flagged edge-probe assumptions (`ordering`, `adjacency`, `empty`, `unclassified`) remain
  UNRESOLVED and surfaced: the D-19 ordering is asserted by commit-graph checks, not enforced by
  tooling; template↔example equality still has no mechanism (FUT-01, filed and unbuilt).

## Known Stubs

None. No source file changed: the only non-`.planning/` bytes that moved are the 2 golden fixture
files, rewritten wholesale by `mix sigra.fixture.rebless_golden` and never hand-edited (D-09), whose
diff is 5 removed lines and 5 added lines of `@moduledoc` prose and one `#` comment.

## Self-Check: PASSED

- `.planning/…/239-golden-expected-3.txt` — FOUND
- `.planning/…/fixtures/239-golden-rebless3-code-change.diff` — FOUND
- `.planning/…/239-EVIDENCE.md` § `## REFREEZE-LEDGER-3` — FOUND
- `.planning/…/239-EVIDENCE.md` § `## REBLESS-COMMIT-3` — FOUND
- `test/fixtures/install_golden/tree/…/invitation_accept_live.ex` — FOUND
- `test/fixtures/install_golden/tree/…/organization_members_live.ex` — FOUND
- Commit `4f94278f` — FOUND
- Commit `87581665` — FOUND
- `BATCH-3-JUSTIFICATION-PENDING` marker — GONE (grep count 0)
