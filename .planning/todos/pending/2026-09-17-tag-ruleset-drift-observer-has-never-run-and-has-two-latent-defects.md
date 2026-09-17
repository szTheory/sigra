---
created: 2026-09-17T00:00:00.000Z
status: pending
title: The `tag_ruleset_drift` observer has never executed, and carries an unreachable error branch plus an unpaginated list
area: ci
severity: minor
source: phase 238 code review (IN-03)
files:
  - .github/workflows/ci-observe.yml
---

## Problem

The `tag_ruleset_drift` job (`.github/workflows/ci-observe.yml:189`) has never run: it is a
`workflow_run` lane, which executes only the default-branch copy, and nothing has been pushed
since it landed. Two defects are therefore unproven and unobserved:

1. `:204-209` — under `set -e`, a failing `gh api` aborts the step before the named `ABSENT`
   message at `:207` can print. The common failure (ruleset deleted, 404) surfaces as a raw
   non-zero exit, not as the diagnostic the job was written to emit.
2. The ruleset list is fetched unpaginated. Past 30 rulesets the target would fall off the first
   page and the job would report the guard "silently removed" when it is present — a false alarm
   on the one signal this lane exists to raise.

## Suggested fix

Capture the `gh api` status explicitly rather than relying on `set -e`, and add `--paginate`.
Then push to `main` once and confirm the lane actually executes and reports, since neither the
fix nor the job is proven until it has run.

## Why it was not fixed in phase 238

Editing a workflow that has never executed trades one unverified state for another. The honest
move is to fix and observe in the same pass, which needs a push to `main` that phase 238 did not
make. Recorded in the phase evidence as a known limitation.
