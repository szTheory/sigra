---
phase: 231-gate-honesty-nightly-revival
plan: 11
subsystem: infra
tags: [github-actions, ci, gate-honesty, evidence-ledger, nightly, github-pages]

requires:
  - phase: 231-10
    provides: "GATE-01's two structural defects (D-17 Pages seeding, D-19 schedule-lane leniency) fixed and guarded; D-18 diagnosed as structurally unobservable pre-merge; ci-gate confirmed green at branch HEAD."
provides:
  - "231-EVIDENCE.md: the phase's observed-run evidence ledger, one slot per success criterion, in Phase 230's inherited BEFORE-/AFTER- format — the eleven plans' scattered receipts gathered into one re-derivable record"
  - "GATE-01's D-16 disposition procedure, written down before any post-merge nightly run exists: literal-green primary target, the fallback's exact activation criteria (filed + diagnosed + named owner per remaining red), and a per-red table mapping the baseline's three non-success jobs to the plan and slot that already fixed each"
  - "A corrected baseline count: 231-CONTEXT.md D-16's '23 green' is off by one against the live job list (22 success / 3 non-success is the accurate, re-verified figure)"
  - "A pre-merge hygiene scan: 55 commits between origin/main's merge-base and this branch's HEAD, zero occurrences of the [skip ci] squash-merge footgun"
  - "The phase's final requirement call on GATE-01: left Pending, because its literal text is a claim about a schedule-triggered run and none has happened post-fix — the honest form per the plan's own explicit prohibition"
affects: [232, 233, 234, 235]

tech-stack:
  added: []
  patterns:
    - "A phase-closing evidence ledger whose slots are criterion-shaped (one per SC) rather than before/after-shaped, inheriting Phase 230's generic BEFORE-/AFTER- slot parser with zero format changes — the pattern phases 232-235 inherit"
    - "A disposition procedure written into the ledger BEFORE the observation it governs exists, so a pending criterion's eventual pass/fail judgment is a pre-agreed rubric rather than a post-hoc negotiation"

key-files:
  created: []
  modified:
    - .planning/phases/231-gate-honesty-nightly-revival/231-EVIDENCE.md

key-decisions:
  - "GATE-01 left Pending. Its literal text ('the nightly scheduled run is green, or every remaining red lane is a filed, diagnosed defect with an owner') is a claim about a specific schedule-triggered run. No such run has occurred with this phase's fixes in place — the cron cannot be forced forward and no workflow_dispatch produces a schedule event. Declaring it satisfied on the strength of already-fixed baseline reds is the exact move Task 2's own prohibition forbids ('MUST NOT declare GATE-01 satisfied on the basis that the nightly's known reds were fixed... no run has happened yet at ledger time'). The AFTER-NIGHTLY-POST-MERGE slot is booked pending with the exact capture command and the disposition procedure recorded in advance."
  - "GATE-04 left untouched, per explicit instruction not to alter its status regardless of how satisfied its literal text reads from 231-05/231-06's evidence."
  - "231-CONTEXT.md D-16's baseline count ('25 jobs, 23 green') is corrected in the ledger against a live re-capture of run 30425416933: the accurate figure is 22 success / 3 non-success (25 total), matching 231-RESEARCH.md's own three-row live-verified table exactly. Recorded as a reconciliation, not silently repeated."
  - "The AFTER-ROT-PROBE slot's first fenced command block (gh workflow run) does not itself satisfy p12's producing-command assertion (it matches neither ci-run-metrics.sh nor /\\bgh (run|pr|api)\\b/); added three gh run view --json jobs commands to the same slot so the fenced-block requirement is satisfied by an actually-reproducible read, not merely a dispatch trigger."

requirements-completed: []

coverage:
  - id: D1
    description: "231-EVIDENCE.md built with one BEFORE-/AFTER- slot per success criterion (baseline, SC-2 generated-host smoke, SC-3 rot probe, SC-4 eval harness, SC-5 release-lane wait, GATE-01's D-17/D-18 Pages publisher), each carrying a run ID, a reproducible gh/ci-run-metrics.sh command, and verbatim output"
    requirement: "GATE-01"
    verification:
      - kind: unit
        ref: "GSD_PROHIB_SUBJECT=231-EVIDENCE.md node --test scripts/ci/prohibitions/p11-sc-restatement-recorded.test.mjs scripts/ci/prohibitions/p12-run-id-provenance.test.mjs -- 9/9 passing"
        status: pass
      - kind: other
        ref: "python3 slot-count assertion (plan's own verify block) -- slots=7 captured=6 pending=1"
        status: pass
    human_judgment: false
  - id: D2
    description: "SC-1 booked honestly as a pending slot with the exact capture command; D-16's disposition procedure (primary target, fallback activation criteria, per-red table, non-CI-nightly items, non-vacuity clause) written into the ledger before any post-merge run exists"
    requirement: "GATE-01"
    verification:
      - kind: unit
        ref: "GSD_PROHIB_SUBJECT=231-EVIDENCE.md node --test scripts/ci/prohibitions/p11-sc-restatement-recorded.test.mjs scripts/ci/prohibitions/p12-run-id-provenance.test.mjs -- 9/9 passing; python3 pending-slot-grammar assertion -- OK"
        status: pass
    human_judgment: false
  - id: D3
    description: "Pre-merge hygiene check: full-series [skip ci] scan (55 commits, zero occurrences) recorded with its exact command, range, count and result; terminal guard confirmation (66-test prohibition suite + all six scripts/ci/*.test.sh pairs this phase touched, actionlint across all four modified workflows) re-run and recorded green"
    requirement: "GATE-01"
    verification:
      - kind: other
        ref: "git log <merge-base>..HEAD --format=%B | grep -i 'skip ci' -- 0 matches across 55 commits; node --test scripts/ci/prohibitions/*.test.mjs -- 66/66; actionlint -shellcheck= (4 workflows) -- exit 0"
        status: pass
    human_judgment: false
  - id: D4
    description: "GATE-01's final requirement call: left Pending, with the exact reasoning and the exact next-observation command recorded in both the ledger and this SUMMARY"
    requirement: "GATE-01"
    verification: []
    human_judgment: true
    rationale: "Whether a requirement whose literal text names a specific future event ('the nightly scheduled run') can be marked Complete before that event has occurred is a judgment about the requirement's own wording, not a mechanically checkable property. The plan's own Task 2 prohibition resolves it explicitly for this phase (do not declare satisfied on the strength of already-fixed reds), and this SUMMARY records that resolution rather than deferring it further."

duration: ~50min
completed: 2026-07-30
status: complete
---

# Phase 231 Plan 11: The phase evidence ledger, GATE-01's D-16 disposition written in advance, and the final GATE-01 requirement call Summary

**Built `231-EVIDENCE.md` — one BEFORE-/AFTER- slot per success criterion, gathering all eleven plans' scattered run-ID receipts into a single re-derivable record — wrote GATE-01's fallback disposition procedure before any post-merge nightly exists, ran the pre-squash `[skip ci]` hygiene scan clean across 55 commits, and made the phase's final honest call: GATE-01 stays Pending because its literal text is a claim about a `schedule`-triggered run that has not yet happened with this phase's fixes in place.**

## Performance

- **Duration:** ~50 min (research/context-gathering + three task commits + CI observation)
- **Started:** 2026-07-30 (immediately after 231-10)
- **Completed:** 2026-07-30
- **Tasks:** 3/3 completed
- **Files modified:** 1 (231-EVIDENCE.md, created then extended across all three tasks)

## Accomplishments

- **Task 1 — the ledger's six captured slots.** `231-EVIDENCE.md` created with `BEFORE-NIGHTLY-BASELINE` (run `30425416933`, the pre-fix nightly), `AFTER-GENERATED-HOST-SMOKE` (SC-2, runs `30521272305`/`30523049209`, plus a `## Restated Success Criterion (SC-2)` section transcribing the already-recorded C-4 restatement word for word), `AFTER-ROT-PROBE` (SC-3, runs `30526744204`/`30526771018`/`30526727106`), `AFTER-EVAL-HARNESS` (SC-4, runs `30512523387`/`30514238789`), `AFTER-RELEASE-LANE-WAIT` (SC-5, run `30466318240` via the extracted `wait-for-ci-gate.sh`), and `AFTER-PAGES-PUBLISHER` (GATE-01's D-17/D-18, run `30529885885`). Both shipped ledger guards (`p11-sc-restatement-recorded`, `p12-run-id-provenance`) exit 0 pointed at this ledger via `GSD_PROHIB_SUBJECT`, and still exit 0 against their pinned Phase-230 subject.
- **Corrected the baseline count on the record.** `231-CONTEXT.md` D-16 describes run `30425416933` as "25 jobs, 23 green" — a figure off by one against the actual job list (25 total minus 3 non-success leaves 22 `success`, not 23). Re-captured live via `ci-run-metrics.sh --jobs 30425416933` on 2026-07-30, confirming `231-RESEARCH.md`'s own three-row "live-verified" table exactly. The ledger states the correction plainly rather than silently repeating the CONTEXT figure.
- **Task 2 — SC-1 booked honestly, with D-16's fallback written before any post-merge run exists.** `AFTER-NIGHTLY-POST-MERGE` is a `pending` slot naming the structural reason (a `schedule` event cannot be forced forward) and the exact capture command. The `GATE-01 Disposition Procedure` section (not a slot — no `BEFORE-`/`AFTER-` heading) records: the primary target (literal green — no job outside `{success, skipped}`); the fallback's exact activation criteria (every remaining red must be filed, diagnosed, and carry a named owner, and the fallback is explicitly **not** available for an un-diagnosed red); the observation that `ci-gate` running the GATE-03 honest-skip verdict on every event (including `schedule`, since `ci-gate` carries `if: always()`) is what distinguishes a legitimately green-because-skipped nightly from a silently-rotted one; a per-red disposition table mapping the baseline's three non-success jobs to the plan that fixed each and the ledger slot proving the fix; both non-CI-nightly GATE-01 items (the Pages publisher's own cron, the GitHub-managed Pages build deployment) recorded with their own dispositions, with D-18's filed defect linked under the fallback branch and fenced to repo-admin scope; and a non-vacuity clause naming all three empty-read failure shapes (empty jobs array, unresolvable run ID, a status citing no run ID).
- **Task 3 — the pre-squash hygiene scan, run clean.** `git log <merge-base>..HEAD --format=%B | grep -i 'skip ci'` across the full 55-commit range between `origin/main`'s merge-base (`64c39f3b`) and this branch's HEAD returned zero matches — a genuine full-series check (the same concatenation a squash merge would produce), not a spot check of the latest commit. The terminal guard confirmation re-ran the full 66-test prohibition suite plus all six `scripts/ci/*.test.sh` pairs this phase created or extended (`wait-for-ci-gate`, `honest-skip-verdict`, `playwright-cache-key-guard`, `fix-queue-lint`, `quality-findings-monotonic`, `ci-demotion-observer`) and `actionlint` across all four workflow files this phase touched — all green, recorded in the ledger's `Pre-Merge Hygiene Check` section.
- **The phase's final GATE-01 call: left Pending.** GATE-01's literal REQUIREMENTS.md text is a claim about a specific `schedule`-triggered run. No such run has occurred with this phase's fixes (D-17, D-19, GATE-02, GATE-04) in place — the earliest possible observation is the first `30 4 * * *` cron tick after this PR merges to `main`. Declaring the requirement satisfied on the strength of the baseline run's already-fixed reds is exactly the move this plan's own Task 2 prohibition forbids. `REQUIREMENTS.md`'s GATE-01 checkbox is left `[ ]`, unchanged by this plan; `AFTER-NIGHTLY-POST-MERGE`'s pending slot and the disposition procedure above are the mechanism by which the eventual capture — whoever performs it — closes the requirement honestly, against a rubric already agreed rather than negotiated after the fact.

## Task Commits

Each task was committed atomically:

1. **Task 1: Build the phase evidence ledger from the captured receipts (D-25)** - `83ca08f5` (docs)
2. **Task 2: Book SC-1 honestly, with D-16's fallback criteria written in advance (D-16, D-18)** - `80824783` (docs)
3. **Task 3: Pre-merge hygiene — protect SC-1's future receipt from a squashed skip directive** - `e2584c47` (docs)

**Plan-metadata commit:** created after this SUMMARY, per `commit_docs: true`.

## Files Created/Modified

- `.planning/phases/231-gate-honesty-nightly-revival/231-EVIDENCE.md` — the phase's observed-run evidence ledger: 7 slots (6 captured, 1 pending), a `Restated Success Criterion (SC-2)` section, a `GATE-01 Disposition Procedure` analysis section, and a `Pre-Merge Hygiene Check` analysis section.

## Decisions Made

See `key-decisions` in frontmatter. In full:

1. **GATE-01 left Pending**, per the plan's own explicit prohibition against declaring it satisfied on the strength of already-fixed baseline reds. This is the phase's own final requirement call, made honestly rather than optimistically.
2. **GATE-04 left untouched**, per explicit instruction not to alter its status in this plan.
3. **The D-16 "23 green" baseline figure corrected** against a live re-capture, rather than repeated verbatim from `231-CONTEXT.md`.
4. **AFTER-ROT-PROBE's fenced-block requirement satisfied with an added `gh run view --json jobs` command** per each of the three cited run IDs — the `gh workflow run` dispatch command alone did not match `p12`'s producing-command pattern, and a dispatch command is not itself a reproducible read in any case.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug in first draft] AFTER-ROT-PROBE's fenced command block did not satisfy p12's producing-command assertion**
- **Found during:** Task 1's own verify block, first run
- **Issue:** `p12-run-id-provenance.test.mjs`'s "every captured slot carries a fenced block naming the producing command" assertion requires a fenced block matching `ci-run-metrics.sh` or `/\bgh (run|pr|api)\b/`. The slot's only fenced command block was `gh workflow run "CI" ...` (dispatch, not a `run`/`pr`/`api` subcommand), so the assertion correctly failed.
- **Fix:** Added three `gh run view <id> --repo szTheory/sigra --json jobs -q '.jobs[] | select(.name=="ci-gate")'` commands to the same fenced block — genuinely reproducible reads against each of the three cited run IDs, not merely the trigger that created them.
- **Files modified:** `.planning/phases/231-gate-honesty-nightly-revival/231-EVIDENCE.md`.
- **Verification:** Re-ran `GSD_PROHIB_SUBJECT=... node --test p11... p12...` — 9/9 passing.
- **Committed in:** `83ca08f5` (part of Task 1's commit — caught before the commit landed).

---

**Total deviations:** 1 auto-fixed (Rule 1 — a verification gap in the ledger's own first draft, caught by the guard it was written to satisfy).
**Impact on plan:** No scope creep. The fix added three read commands to an already-planned slot; no new slot, no new file.

## Issues Encountered

**A GitHub Actions `pull_request` run for this plan's own final commit (`e2584c47`) did not appear within the observation window.** After pushing all three task commits to `worktree-discuss-231` (PR #125's head confirmed updated to `e2584c47` via `gh pr view --json headRefOid`), polling `gh api repos/szTheory/sigra/actions/runs` for a workflow run at that SHA returned nothing for over 20 minutes — well beyond the ~90-second webhook delay `231-07-SUMMARY.md` previously documented as a minor wrinkle. `Actions` is confirmed `enabled`/`allowed_actions: all` for the repo, the `CI` workflow is `active`, the repo is not `archived`/`disabled`, and the API rate limit was nowhere near exhausted — none of the usual causes explain the gap. This plan's own three commits touch exactly one file (`231-EVIDENCE.md`, entirely inside `.planning/`), carrying essentially zero risk to `ci.yml` or any script; `ci-gate` was independently confirmed `success` on the immediately-preceding commit (`315e94e2`, run `30532428285`, the final commit of plan 231-10) both before this plan started and again after this plan's own three commits, i.e., this plan changed no file that could plausibly redden `ci-gate`. Per Prohibition 5 ("leave `ci-gate` green on the non-probe path"), the last **directly observed** `ci-gate` conclusion on this branch is `success` (run `30532428285`). Whoever merges this PR should confirm `ci-gate` is still green at the actual merge commit before merging — the same discipline every other plan in this phase already followed — since this SUMMARY cannot cite a run ID for `e2584c47` itself that never registered inside the observation window.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- **The evidence ledger is complete and inherited by Phases 232-235 as-is** — `scripts/ci/prohibitions/_lib.mjs`'s `parseEvidenceSlots` is deliberately generic with no opt-in marker, so any later phase's own `-EVIDENCE.md` is parsed by the same two guards without modification.
- **GATE-01 remains the phase's one open item.** The `AFTER-NIGHTLY-POST-MERGE` slot and the `GATE-01 Disposition Procedure` are the exact mechanism for closing it: after this PR merges, whoever captures the first `30 4 * * *` scheduled run runs `gh run view <id> --repo szTheory/sigra --json jobs`, pastes the verbatim output into that slot, flips its status to `captured (run <id>)`, and judges the result against the procedure already written — literal green, or every remaining red filed/diagnosed/owned per the fallback's exact activation criteria.
- **GATE-04 remains `Pending` in REQUIREMENTS.md** by design (untouched by this plan, per explicit instruction) — its own literal-text-satisfied-but-left-open posture is unchanged from 231-06's hand-off.
- **DX-05, GATE-02, GATE-03 remain `Complete`**, untouched by this plan (confirmed via `git diff` on `.planning/REQUIREMENTS.md` showing no hunk from this plan's three task commits).
- **No blockers for Phase 232.** This plan touched no `ci.yml`, no script, and no file outside `.planning/`.

---
*Phase: 231-gate-honesty-nightly-revival*
*Completed: 2026-07-30*

## Self-Check: PASSED

- FOUND: `.planning/phases/231-gate-honesty-nightly-revival/231-EVIDENCE.md`
- FOUND: `.planning/phases/231-gate-honesty-nightly-revival/231-11-SUMMARY.md`
- FOUND commit: `83ca08f5`
- FOUND commit: `80824783`
- FOUND commit: `e2584c47`
