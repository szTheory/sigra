---
phase: 231-gate-honesty-nightly-revival
plan: 03
subsystem: infra
tags: [github-actions, ci, gh-cli, bash, testing, notifier]

requires:
  - phase: 231-01
    provides: "the scripts/ci/<name>.sh + <name>.test.sh + hermetic-stub house pattern this plan mirrors"
provides:
  - "scripts/ci/notify-failure-issue.sh — self-healing label creation (D-22), fail-soft"
  - "scripts/ci/notify-failure-issue.test.sh — cases D, E, F, G proving the heal and its fail-soft boundary"
affects: [231-04, 231-05, 231-06, 231-07, 231-08, 231-09, 231-10, 231-11]

tech-stack:
  added: []
  patterns:
    - "gh label list captured into a variable, then grep-tested — never piped straight into grep -q under set -euo pipefail (SIGPIPE risk on the upstream gh)"
    - "fail-soft self-heal: a denied side-effect (label create) degrades to a warning, never blocks the primary signal (issue create), with a last-resort unlabelled retry"

key-files:
  created: []
  modified:
    - scripts/ci/notify-failure-issue.sh
    - scripts/ci/notify-failure-issue.test.sh

key-decisions:
  - "D-22: self-heal lives inside the else (create) branch only — case F proves the comment branch makes zero gh label calls."
  - "D-22: fail-soft — a denied gh label create logs a warning and gh issue create retries once without --label, so the tracking issue always opens."
  - "D-23: no new tracking issue staged against the live repo. Issue #118 and its already-observed comments are cited as evidence, not re-derived."
  - "No permissions: block edited — both callers (ci.yml notify_release_lane_rot, release-please.yml notify-release-failure) already declare issues: write, which GitHub's permissions reference states covers gh label list and gh label create."

patterns-established:
  - "Stub-first sequencing: extend the hermetic gh recording stub with new argv branches in a behaviour-neutral commit before the script under test learns to call them, so existing cases never break mid-change."

requirements-completed: [DX-05]

coverage:
  - id: D1
    description: "notify-failure-issue.sh self-heals a missing release-lane-rot label before creating the tracking issue, fail-soft on a denied create"
    requirement: "DX-05"
    verification:
      - kind: unit
        ref: "scripts/ci/notify-failure-issue.test.sh (cases D, E, F, G)"
        status: pass
      - kind: other
        ref: "node -e structural assertion — comment branch contains zero `gh label` calls; create branch contains both `gh label list` and `gh label create`"
        status: pass
    human_judgment: false
  - id: D2
    description: "D-23: red-probe evidence not re-staged — issue #118 and its comment thread cited as already-observed proof of both notifier branches"
    requirement: "DX-05"
    verification:
      - kind: other
        ref: "gh issue view 118 --repo szTheory/sigra (read-only citation check, zero write calls made)"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-07-29
status: complete
---

# Phase 231 Plan 03: Notify-failure-issue label self-heal (D-22) Summary

**`scripts/ci/notify-failure-issue.sh` now self-heals a missing `release-lane-rot` label before creating its tracking issue — fail-soft, so a denied `gh label create` can never again cost the HARD-02 loud signal the way it did on nightly run `30331796188`.**

## Performance

- **Duration:** ~8 min (commit-to-commit)
- **Tasks:** 2/2 completed
- **Files modified:** 2

## Accomplishments

- Extended the hermetic `gh` recording stub in `notify-failure-issue.test.sh` with `label list` (reads `GH_STUB_LABEL_EXISTS`) and `label create` (reads `GH_STUB_LABEL_CREATE_FAIL`) branches, placed before the stub's unrecognized-invocation fallthrough — in its own behaviour-neutral commit, confirmed cases A/B/C still pass unchanged before the script under test learned to call `gh label` at all.
- Added the D-22 self-heal to `notify-failure-issue.sh`'s create (`else`) branch: capture `gh label list --limit 200 --json name --jq '.[].name'` into a variable, test it with `grep -qxF` (never piping `gh` straight into `grep -q`, which risks SIGPIPE under `set -euo pipefail`), and `gh label create` when absent — soft-failing with a warning on denial. The subsequent `gh issue create --label` call itself retries once without `--label` if it fails, so a denied/missing label can never cost the tracking issue.
- The self-heal lives inside the create branch only. A structural assertion confirms the comment branch (taken when an open issue already exists) makes zero `gh label` calls of any kind.
- Added four hermetic cases (D: label absent → 1 label create + 1 issue create; E: label present → 0 label create + 1 issue create; F: existing issue → 0 label list/create + 1 issue comment; G: label create denied → warning logged, still 1 issue create, exit 0). All 7 cases (A–G) pass.
- No `permissions:` block edited anywhere. Both existing callers (`ci.yml`'s `notify_release_lane_rot`, `release-please.yml`'s `notify-release-failure`) already declare `issues: write`, which GitHub's own permissions reference states covers both `gh label list` and `gh label create`.
- No new tracking issue staged against the live repository (D-23). `notify-failure-issue.test.sh` remains fully hermetic — a read-only `gh issue view 118` citation check (see Verification below) made zero write calls.

## Task Commits

Each task was committed atomically:

1. **Task 1: Teach the gh recording stub about labels, before the script needs it** - `9a3caccf` (test)
2. **Task 2: Self-heal the label in the create path, with four hermetic cases** - `676f0ed2` (feat)

_No separate plan-metadata commit is included in this response's commit list — the final `docs(231-03): complete …` metadata commit is created in the state-update step below._

## Files Created/Modified

- `scripts/ci/notify-failure-issue.sh` — self-heals a missing `release-lane-rot` label before creating the issue; fail-soft on a denied create; header comment extended to record the permissions ambiguity (community discussion #13565) and why the design makes it non-load-bearing.
- `scripts/ci/notify-failure-issue.test.sh` — `gh` stub extended with `label list`/`label create` branches; four new hermetic cases D, E, F, G; case-table docstring updated to name them.

## Decisions Made

- **D-22 implemented exactly as `231-CONTEXT.md`/`231-PATTERNS.md`/`231-RESEARCH.md` specified:** self-heal inside the `else` branch only, `grep -qxF` against a captured variable (not a `gh | grep -q` pipe), fail-soft label create, last-resort unlabelled `gh issue create` retry. No alternative considered — this shape was owner-selected in context-gathering and confirmed correct by RESEARCH's SIGPIPE caveat.
- **D-23 honored by omission and by citation, not re-derivation.** See the D-23 evidence section below.
- **No `ci.yml` edit made.** `notify-failure-issue.test.sh` was already wired into `fast_checks` at `ci.yml:256` from Phase 222/223 — this plan's `files_modified` fence (`scripts/ci/notify-failure-issue.sh`, `scripts/ci/notify-failure-issue.test.sh`) did not need to be crossed. Confirmed via `grep -n "notify-failure-issue" .github/workflows/ci.yml` before starting Task 2.

## Deviations from Plan

None — plan executed exactly as written. Both tasks matched their `<action>` blocks and passed their literal `<verify>` scripts on the first attempt.

## Issues Encountered

**DX-05 requirement-completion timing note (not a deviation in this plan's own work, but worth recording for the record's honesty).** `git log -p -- .planning/REQUIREMENTS.md` shows commit `2766fcab` (231-01's metadata commit) already flipped `DX-05` to `[x]` / "Complete" in `REQUIREMENTS.md`, before this plan's D-22/D-23 half of DX-05 had landed. `231-01-SUMMARY.md`'s own text says "DX-05 is fully closed by this plan," which was not accurate at the time — 231-01 closed only D-20/D-21 (the `gate-ci-green` timeout half); D-22/D-23 (the notifier self-heal half, this plan) were still open. As of this plan's commits, DX-05 genuinely is now fully satisfied (both filed defects resolved), so no revert of the checkbox is needed — but the completion should have waited for this plan. Flagging per this plan's brief ("Honesty of the record is this phase's entire point") rather than silently letting the premature mark stand uncommented. `requirements.mark-complete DX-05` is re-run in the state-update step below; it is now idempotently and genuinely true.

## Verification Evidence (actually run)

```
$ bash scripts/ci/notify-failure-issue.test.sh
Test A: no open issue -> gh issue create exactly once, never gh issue comment
  PASS: Test A: created once, never commented (exit 0)
Test B: existing open issue #123 -> gh issue comment 123 exactly once, never gh issue create
  PASS: Test B: commented on #123 once, never created (exit 0)
Test C: LABEL/TITLE/BODY unset -> exits non-zero, zero gh calls (fail-closed)
  PASS: Test C: exited non-zero (1) with zero gh calls (fail-closed, no partial call)
Test D: label absent, no open issue -> one label create, then one issue create
  PASS: Test D: one label create then one issue create (exit 0)
Test E: label present, no open issue -> zero label create, one issue create
  PASS: Test E: zero label create, one issue create (exit 0)
Test F: existing open issue -> zero label list/create, one issue comment
  PASS: Test F: zero label calls, one issue comment (exit 0)
Test G: label create denied -> issue still created exactly once, exit 0
  PASS: Test G: denied label create still yields one issue create (exit 0)

----------------------------------------
Results: 7 passed, 0 failed
----------------------------------------
notify-failure-issue.test: PASS
```

```
$ bash -n scripts/ci/notify-failure-issue.sh
(exit 0, no output)
```

```
$ shellcheck scripts/ci/notify-failure-issue.sh scripts/ci/notify-failure-issue.test.sh
(exit 0, no output)
```

Structural assertion (Task 2's literal `<verify>`):
```
$ node -e "...(branch-structure check)..."
OK
```
Confirms: the comment branch (taken when an open issue exists) contains zero `gh label` invocations; the create branch contains both `gh label list` and `gh label create`.

```
$ node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs
# tests 53
# pass 53
# fail 0
```
(regression check — this plan changes no prohibition subject; all 53 still pass, matching 231-01's baseline)

### D-23 evidence citation (no new probe staged)

Per D-23, SC-5's "a red-probe creates a tracking issue" is already observed and is cited here, not re-derived. A single **read-only** `gh issue view 118 --repo szTheory/sigra` call (zero write calls, zero side effects) confirms issue **#118** (`release-lane-rot`, "ci-gate red on main", created `2026-07-29T01:39:14Z` by run `30414636733`) is still open and carries comment-bearing evidence from, at minimum, the three runs named in `231-CONTEXT.md` D-23 — `30414885679`, `30425416933`, `30461966943` — proving both script branches (create at the original `:33`, find-and-comment at the original `:26-30`) against the real Issues API. (The live issue has since accumulated further comments from ordinary production `ci-gate` red events in the time since `231-CONTEXT.md` was gathered — that accumulation is incidental real-world evidence, not something this plan generated; no `gh issue create`, `gh issue comment`, `gh label create`, or any other write call was made during this plan's execution.) The failure branch is also already observed: the notifier concluded `failure` on nightly `30331796188` (pre-label, the exact defect D-22 fixes) and `success` on `30425416933` (post-label).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- DX-05 is now genuinely, fully satisfied: both filed release-lane defects (the `gate-ci-green` timeout from 231-01, and this plan's label self-heal) are resolved with hermetic proof.
- The house guard shape (stub-first, then script + hermetic self-test, structural assertion, regression check) continues to hold for every later plan in Phase 231.
- No blockers for subsequent 231 plans. This plan touched only `scripts/ci/notify-failure-issue.sh` and its sibling test file, per D-24's "DX-05 is fully parallel" sequencing note.

---
*Phase: 231-gate-honesty-nightly-revival*
*Completed: 2026-07-29*

## Self-Check: PASSED

- FOUND: `scripts/ci/notify-failure-issue.sh`
- FOUND: `scripts/ci/notify-failure-issue.test.sh`
- FOUND: `.planning/phases/231-gate-honesty-nightly-revival/231-03-SUMMARY.md`
- FOUND commit: `9a3caccf`
- FOUND commit: `676f0ed2`
