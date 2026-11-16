---
phase: 260-deterministic-output-before-catalog-and-png-park
plan: 04
subsystem: ci
tags: [github-actions, playwright, png-compare, park-pr, squash-merge, owner-approval, bgen-06]

requires:
  - phase: 260
    provides: "Plan 01's local branch ci/park-png-compare (comparison-level SIGRA_PNG_COMPARE_SKIP switch, six files, tip 5e351ebea)"
provides:
  - "Park PR #381 squash-merged to main through the ruleset, no admin, no force, no branch deletion"
  - "Merge commit SHA on origin/main recorded for plan 11 (4154a913e6c31f54f357587553c0dc7846ebc915), ancestry proven"
  - "Live positive control: the same board test compares with the switch unset or 0 and is reported skipped with 1"
  - "Gate ledger and PR body as the durable record of both owner approvals"
affects: [260-11, 261]

actuals:
  tokens: 2708
  tasks: 3
  commits: 24

# `commits: 24` is the MEASURED count of the persisted-ledger range and is contaminated: plan 04 paused at its owner
# checkpoint while plans 06 to 09 committed on the same branch. Plan 04 authored 3 of the 24 before this SUMMARY
# (61788d61b, ad878767f, 44a79f15d); the other 21 belong to plans 06, 07, 08 and 09. Not rounded or reattributed.
plan_authored_commits: 3
plan_head_before: 4dcb0292c29b9119964bbb6ba936349e46f79cd7
plan_head_after: 44a79f15db9837a2beac19844285e7e37e58b37c

tech-stack:
  added: []
  patterns:
    - "Two-gate publish: a separate plain-chat owner approval for the push/PR and for the merge, each recorded verbatim in a durable ledger committed before the next gate"
    - "Skip-switch positive control: the same test on the same server, switch toggled between runs, so the only variable is the switch"

key-files:
  created:
    - .planning/phases/260-deterministic-output-before-catalog-and-png-park/260-park-pr-body.md
    - .planning/phases/260-deterministic-output-before-catalog-and-png-park/260-04-GATE-LEDGER.md
  modified: []

key-decisions:
  - "Squash merge only, with the conventional ci: title and no ! or BREAKING footer; the RED/GREEN test-first pairs collapse into one commit on main"
  - "Stripped the stray 'Suggested title:' first line from the PR body before merging (the owner-approved recommendation), via a scratchpad file and gh pr edit --body-file"
  - "Left the park branch (remote and local) and the worktree in place; nothing deleted, so plan 11 and the owner can still inspect the four test-first commits"

patterns-established:
  - "Re-verify the PR immediately before the merge and again after any body edit, because a pull_request edited event can re-trigger required checks"

requirements-completed: [BGEN-06]

coverage:
  - id: D1
    description: "The skip switch is proven live in both polarities on a real browser run: unset or 0 executes the comparison and fails, 1 reports the same test skipped, with axe and behavior tests still passing"
    requirement: BGEN-06
    verification:
      - kind: other
        ref: "live Playwright runs on ci/park-png-compare against the example app in dev mode (raw outputs in the session scratchpad); summary in 260-park-pr-body.md 'Guard evidence', commit 61788d61b"
        status: pass
    human_judgment: false
  - id: D2
    description: "Park PR #381 is merged by squash after both plain-chat owner approvals, with no admin, force or branch deletion, and the merge SHA is recorded and reachable from origin/main"
    requirement: BGEN-06
    verification:
      - kind: other
        ref: "gh pr view 381 --json state,mergedAt reports MERGED 2026-11-15T21:01:34Z; git merge-base --is-ancestor 4154a913e6c31f54f357587553c0dc7846ebc915 origin/main exits 0; squash commit has one parent and exactly six files"
        status: pass
    human_judgment: false
  - id: D3
    description: "All five ruleset-required contexts were green before the merge (and re-checked after the body edit)"
    requirement: BGEN-06
    verification:
      - kind: other
        ref: "gh pr checks 381 --required: Library tests, Example unit smoke, Install smoke, Example HTTP smoke, Example Playwright smoke all pass; ci-gate pass"
        status: pass
    human_judgment: false
  - id: D4
    description: "The PR body, park added lines, park commit messages, squash message and the phase directory carry no home path, personal name, maintainer address, non-reserved address-shaped token or authoring origin"
    requirement: BGEN-06
    verification:
      - kind: other
        ref: "privacy legs script (run after the merge; each leg has a planted self-match control): 9 PASS, 0 FAIL, exit 0"
        status: pass
    human_judgment: false

duration: 23min
completed: 2026-11-15
status: complete
---

# Phase 260 Plan 04: Park PR Live Control, Open and Merge Summary

**The PNG-compare park (PR #381, squash `4154a913e6c31f54f357587553c0dc7846ebc915` on main) is merged through the ruleset after a live two-polarity positive control and two separate owner approvals, with no admin, force or baseline recapture; Phase 261 is unblocked by this plan.**

## Performance

- **Duration:** about 23 min active (about 13 min for Tasks 1 and 2 from commit timestamps, about 10 min for this continuation). Wall clock is about 1h46m from the plan ledger base; the rest was waiting on the owner and on the PR's own CI.
- **Started:** about 2026-11-15T19:18Z (reconstructed from the commit time of the plan's base commit; PLAN_START_TIME was not captured at start)
- **Completed:** 2026-11-15T21:04Z
- **Tasks:** 3 (Task 1 tracer, Task 2 push/PR gate, Task 3 merge gate)
- **Files modified:** 3 in the phase directory (PR body, gate ledger, this SUMMARY). The six files that reached main were authored by plan 01 and are not counted here.

## Accomplishments

- **Live positive control (Task 1).** On `ci/park-png-compare`, against the example app booted in dev mode, the same `board:` @snapshot test was run twice. Switch unset (and `0`, the dispatch shape): the comparison executes and fails. Switch `1`: reported skipped. Details and one honest caveat are under Deviations.
- **PR opened (Task 2).** After the owner's plain-chat approval, `ci/park-png-compare` was pushed with an explicit refspec and PR #381 was opened against `main` with the drafted body.
- **PR merged (Task 3).** After a second, separate approval, the PR body was cleaned, the five required contexts were re-verified green, and `gh pr merge 381 --squash` ran with no admin, no force, no `--delete-branch`. Merge commit `4154a913e6c31f54f357587553c0dc7846ebc915`; `origin/main` advanced from `4cf5829ea` to exactly that commit.
- **Nothing recaptured.** No baseline recapture, no `--update-snapshots`, no PNG in the diff, and the impersonation-banner canary is not allowlisted.

## Task Commits

On the milestone branch `milestone/v1.51-brand-identity-adoption`:

1. **Task 1: live positive control and PR body draft** - `61788d61b` (docs)
2. **Task 2: owner approval to open the PR, PR #381 opened** - `ad878767f` (docs, gate ledger)
3. **Task 3: owner approval to merge, merge recorded** - `44a79f15d` (docs, gate ledger). The merge itself is the GitHub-created squash commit `4154a913e6c31f54f357587553c0dc7846ebc915` on `origin/main`, not a commit on this branch.

**Plan metadata:** the docs commit that carries this SUMMARY, STATE and ROADMAP follows this file.

The park branch's own four commits (`3827d04cd`, `827c04c8e`, `3dc1d1ee7`, `5e351ebea`) belong to plan 01 and were collapsed into the squash commit.

## Owner Approvals (verbatim, plain chat)

| Gate | Action covered | Owner reply, verbatim |
| --- | --- | --- |
| 1 (Task 2) | push `ci/park-png-compare` and open the PR only | `approved` |
| 2 (Task 3) | squash-merge PR #381 and one PR-body edit only | `and then after that for all the things to open decisions, follow ur recs plz...` |

Gate 2 reads as a delegation to the recommendation that was on the table, which was `merge` after stripping the stray first line from the PR body. The orchestrator relayed the reply verbatim and instructed that it be treated as `merge`; this executor did not see the chat itself. Neither approval covers anything beyond its named action. The full ledger is `260-04-GATE-LEDGER.md`.

## PR and Merge Record

- **PR:** #381, https://github.com/szTheory/sigra/pull/381, title `ci: park PNG compare on pull_request and push`, base `main`, head `ci/park-png-compare` at `5e351ebea0890136f0fa945ec2e225266a2172da`.
- **State before merge:** OPEN, CLEAN, MERGEABLE, not a draft, head unchanged since open.
- **Required checks (all pass before and after the body edit):**

  | Required context | Result |
  | --- | --- |
  | Library tests | pass |
  | Example unit smoke (ExUnit + ConnTest) | pass |
  | Install smoke (fresh phx.new + sigra.install) | pass |
  | Example HTTP smoke (boot + curl critical routes) | pass |
  | Example Playwright smoke (full lifecycle) | pass |

  `ci-gate` also passed, as did the five Playwright shards and Release ref guard; the remaining jobs were `skipping` by their own `if:` predicates. None was `fail` or `pending`.
- **Merge:** `gh pr merge 381 --squash`, exit 0, state MERGED at `2026-11-15T21:01:34Z`. The ruleset did not block it and nothing was worked around.
- **Merge commit SHA on main:** `4154a913e6c31f54f357587553c0dc7846ebc915`.
- **Proof:** `git merge-base --is-ancestor 4154a913e6c31f54f357587553c0dc7846ebc915 origin/main` exits 0. One parent (`4cf5829ea`, the park base). Six files, 472 insertions, 1 deletion: `.github/workflows/ci.yml` (+6), `MAINTAINING.md` (+24), three Playwright specs, `test/sigra/planning/phase_260_png_park_contract_test.exs` (+406). Nothing under `lib/` or `priv/`, no PNG.

## Files Created/Modified

- `.planning/phases/260-deterministic-output-before-catalog-and-png-park/260-park-pr-body.md` - the PR body text used with `gh pr create --body-file` (mechanism, the four `release_ref_guard` dispatch shapes, what stays out of scope, guard evidence, diff budget, reviewer notes). The live PR body now lacks its first "Suggested title" line; this file still carries it, since the planning copy was drafted first and the stripped body only ever existed on GitHub.
- `.planning/phases/260-deterministic-output-before-catalog-and-png-park/260-04-GATE-LEDGER.md` - both owner gates, the check table, the merge SHA and the proof.

## Decisions Made

- Squash merge with the conventional `ci:` title (no `!`, no BREAKING footer), as the plan and the owner's standing preference require.
- Strip the stray first line from the live PR body only (owner-approved recommendation); the repo copy was left as drafted.
- Do not delete the park branch or worktree. The plan's prohibitions forbid `--delete-branch` on the merge, and nothing asked for cleanup afterwards.

## Deviations from Plan

### Auto-fixed Issues

None. No bug, missing-critical or blocking fix was needed in this continuation.

### Verification approach that differs from the plan's literal wording

**1. [Task 1] The unmodified `board:` test did not fail on darwin; the board control used a scratch viewport.** The plan expected mode (a), switch unset, to fail on the board test "because the committed baselines are ubuntu-native". On the stock config the board test passed (the design boards stay inside their pixel tolerance on that machine), so by itself that run proves nothing. The control was therefore made decisive in two ways, as recorded in `61788d61b`, in the PR body and in the raw run outputs (kept in the session scratchpad, not in the repo):

- **Board lane:** with a scratch config outside the repo that uses a narrower viewport (no baseline touched), the unset-switch run fails on `board: board-stat @snapshot` with `Expected an image 936px by 166px, received 388px by 166px` and is not skipped. The dispatch shape (switch `0`) fails identically. With `SIGRA_PNG_COMPARE_SKIP=1` and the same scratch config, the same test is reported `1 skipped`. Across the whole design spec on the chromium project, the switch set to `1` reports the 28 `@snapshot` tests skipped with the axe test and the behavior tests still passing.
- **Checkpoint and demo lanes:** with the switch unset they fail naturally against the Linux-native baselines (`35745` and `42349` differing pixels); with the switch `1` all five tests in those lanes pass.

This is the same test on the same server with only the switch toggled, so the switch is the only variable; it is not a weaker substitute for the plan's control, but it is not the literal "natural failure of a board test" the acceptance wording describes. The natural darwin failure was observed on the other two lanes instead.

**2. [Plan-level] `actuals.commits` is the contaminated measured count.** Plan 04 paused at its owner checkpoints while plans 06 to 09 committed on the same branch, so `git rev-list --count 4dcb0292c..HEAD` returns 24. Plan 04 authored 3 of those before this SUMMARY. The measured number is recorded as the contract requires, with `plan_authored_commits: 3` beside it; it should not be read as 24 plan-04 commits and should not feed estimate calibration as such.

**Total deviations:** 0 auto-fixed, 2 documented. **Impact on plan:** none on scope; every success criterion is met.

## Issues Encountered

- The unmodified board test could not serve as a failing control on this machine (Deviation 1).
- A PR body edit can fire `pull_request: edited` workflow runs, so the required checks were re-read after the edit. They were unchanged, and the head SHA was unchanged.
- The `gh pr checks` listing shows `Library tests` and `Example Playwright smoke (full lifecycle)` finishing in 3 s and 2 s: these are aggregate gate jobs over the shards, not a sign of skipped work (the shards ran 1m38s to 5m36s and passed).

## Authentication Gates

None.

## Known Stubs

None.

## Threat Flags

None. No new network endpoint, auth path, file access pattern or schema surface beyond what plan 01's threat model covers.

**Threat model disposition:** T-260-10 (agent self-granting push/merge approval, or admin/force) mitigated: two separate plain-chat approvals recorded verbatim, no `--admin`, no force-push, no `--delete-branch`, and the ruleset was never bypassed. T-260-11 (personal data in public text) mitigated: the privacy legs below passed over the PR body, park added lines, park commits, the squash message and the phase directory.

## Verification Run

| Check | Result |
| --- | --- |
| `gh pr view 381 --json state,mergedAt` | MERGED, `2026-11-15T21:01:34Z` |
| `git merge-base --is-ancestor 4154a913e6c31f54f357587553c0dc7846ebc915 origin/main` | exit 0 |
| `gh pr checks 381 --required` before merge | 5 of 5 pass |
| Squash commit shape | 1 parent (`4cf5829ea`), 6 files, +472/-1, no PNG, no `lib/` or `priv/` |
| Privacy legs (home path, address-shaped token, local user name, maintainer address, authoring origin) over PR body file and live body, park added lines, park commits, squash message, and the phase directory | 9 PASS, 0 FAIL, each with a planted self-match control |
| `git ls-remote --heads origin ci/park-png-compare` | still present (not deleted) |

The privacy legs were run with the park base SHA in place of `origin/main` for the diff and log ranges, because `origin/main` now holds the squash commit and an empty diff would read as clean; the maintainer-address leg excludes commit messages from the address-shaped leg only, as in the plan, because the harness-required trailer carries a mailer address.

`actuals.tokens` is chars/4 over the added lines of this plan's three commits (10,833 bytes / 4 = 2,708), excluding this SUMMARY to avoid counting itself, against a plan estimate of 25,000; not rounded toward the estimate. The park branch's 21,113 bytes belong to plan 01.

## Handoff for Plan 11 and Phase 261

- **Merge SHA to sync:** `4154a913e6c31f54f357587553c0dc7846ebc915` on `origin/main`. The milestone branch must take this commit (plan 11 owns the sync). Local `main` was not updated by this plan; only `origin/main` was fetched.
- **Park branch and worktree remain:** `ci/park-png-compare` (remote and local, tip `5e351ebea`) and `../sigra-park-png-compare`. Cleanup is a separate decision; this plan deleted nothing.
- **ADR 005 follow-up (from plan 01, still open for plan 11):** append a dated note that the park was authored first (Phase 260 wave 1) as a comparison-level skip with default-on compare, which departs from the literal decision-7 wording ("demote lanes to dispatch", "at the end of Phase 260").
- **What changed for every later PR:** `Example Playwright smoke (full lifecycle)` now measures axe and behavior, not pixels, on `pull_request`, `push` and `schedule`. Pixels compare on dispatch (release-tag, final-main and recapture evidence runs) and in both recapture jobs. Reverting the squash commit restores PR-blocking compare.
- **Expected red, not required:** `playwright-github-pages.yml` was deliberately left unedited and keeps comparing; it will report drift once Phase 261 changes rendered output, until baselines are recaptured in CI. Documented in `MAINTAINING.md` under "PNG compare switch".
- **Phase 261 gate:** the SC-4 condition "merged, with explicit owner approval, before Phase 261 starts" is satisfied by this plan once this SUMMARY is committed.

## Next Phase Readiness

Plan 04 is complete. Of Phase 260's 11 plans, 01 to 09 are done, 10 is paused at its own decision and 11 is pending; this plan does not touch plan 10's state.

## Self-Check: PASSED

- Files exist (checked with `[ -f ]`): `260-04-SUMMARY.md`, `260-04-GATE-LEDGER.md`, `260-park-pr-body.md`.
- Commits `61788d61b`, `ad878767f`, `44a79f15d` are ancestors of the milestone branch HEAD; merge commit `4154a913e6c31f54f357587553c0dc7846ebc915` is an ancestor of `origin/main`.
- The privacy legs were re-run after this SUMMARY was written, so it is included in the phase-directory scan: 9 PASS, 0 FAIL.
- Counts cited in Deviation 1 (28 skipped, 14 passed, 5 passed, 2 natural failures with the switch unset, 35745 and 42349 differing pixels) were re-read from the raw control outputs, not copied from the PR body.

---
*Phase: 260-deterministic-output-before-catalog-and-png-park*
*Completed: 2026-11-15*
