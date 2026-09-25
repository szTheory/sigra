---
created: 2026-09-17T00:00:00.000Z
status: pending
title: The `tag_ruleset_drift` observer carries an unreachable error branch, an unpaginated list, and no assertion that it ran
area: ci
severity: minor
source: phase 238 code review (IN-03)
files:
  - .github/workflows/ci-observe.yml
---

## Problem

**Update 2026-09-17: the lane HAS now executed.** Merge commit `6b03af05` reached `main` and
`CI (observe)` run `35249205910` ran the job green (`live tag-namespace ruleset (id 23574716)
matches the committed snapshot`), closing phase 238's UAT. The "never run" premise below is
resolved; the two defects it shielded are still unfixed, and observing the lane surfaced a third.

The `tag_ruleset_drift` job (`.github/workflows/ci-observe.yml:189`) is a `workflow_run` lane,
which executes only the default-branch copy. Three defects remain unfixed:

1. `:204-209` — under `set -e`, a failing `gh api` aborts the step before the named `ABSENT`
   message at `:207` can print. The common failure (ruleset deleted, 404) surfaces as a raw
   non-zero exit, not as the diagnostic the job was written to emit.
2. The ruleset list is fetched unpaginated. Past 30 rulesets the target would fall off the first
   page and the job would report the guard "silently removed" when it is present — a false alarm
   on the one signal this lane exists to raise.

3. **Nothing asserts the job actually executed.** Its guard is
   `github.event.workflow_run.event != 'pull_request'`, so an observe run triggered by a
   PR-event CI run SKIPS the job and still reports the run `success`. Two such runs
   (`35247765541`, `35247921328`) sat at the same head SHA as the real one during phase 238's
   UAT and would have "confirmed" a job that never ran. Reading the run's conclusion is not
   proof; only the JOB's conclusion plus its stdout line is. Today that distinction lives
   only in a human's head, which is the part worth automating.

## Suggested fix

1. Capture the `gh api` status explicitly rather than relying on `set -e`, so the named
   `ABSENT` diagnostic at `:207` can actually print on the 404 it was written for.
2. Add `--paginate` to the ruleset list so the target cannot fall off page 1 past 30 rulesets.
3. Give the job a `$GITHUB_STEP_SUMMARY` receipt, matching the idiom the two sibling receipt
   jobs in the same file already use — an executed run then leaves a visible artifact and a
   skipped one leaves none, with no log-grepping.
4. Add a scriptable executed-assertion (`scripts/ci/…`) that takes a `main` push-CI run id,
   resolves the observe run it triggered, and fails unless the `tag_ruleset_drift` JOB
   concluded `success` — explicitly treating `skipped` as a failure. Runnable locally and
   cheap enough to wire as a step, so no future phase needs a human UAT item for this.

Recurring value is real for (3) and (4): the drift guard itself already runs on every push to
`main`, so the only un-automated part left is proving it ran.

## Why it was not fixed in phase 238

Editing a workflow that has never executed trades one unverified state for another. The honest
move is to fix and observe in the same pass, which needs a push to `main` that phase 238 did not
make. That push has now happened, so this is unblocked — fix and re-observe in one pass.
