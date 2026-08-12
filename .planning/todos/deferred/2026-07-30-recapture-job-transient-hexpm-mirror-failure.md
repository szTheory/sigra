---
created: 2026-07-30T00:00:00.000Z
status: pending
title: "Recapture jobs intermittently fail on a transient hex.pm mirror fetch (the Postgres FATAL line in the log is a red herring)"
area: ci
files:
  - .github/workflows/ci.yml
severity: low
source: >-
  Diagnosed by plan 231-11 from Phase 231's own dispatch history (12 observed
  runs) after 231-06-SUMMARY.md reported the symptom inline without a root
  cause or a filed todo.
owner: unassigned (repo maintainer to triage; low severity, does not block
  merges — recapture jobs are Tier-A, never in ci-gate.needs)
---

## What

`admin_checkpoint_recapture` (and, by the same job template, `admin_design_recapture`) failed
once in Phase 231's own dispatch history: run `30514238789` (plan 231-06's dispatch), job
`90780471296`. `231-06-SUMMARY.md` recorded the symptom as "Postgres `role \"root\" does not
exist`, ~40s into the job" without diagnosing further.

**Re-diagnosed here: that is not the actual failure.** The job's log shows the real error
immediately before the Postgres line:

```
Action mix rebar failed for mirror https://builds.hex.pm, with Error: The process
  '/home/runner/work/_temp/.setup-beam/elixir/bin/mix' failed with exit code 1
##[error]Could not mix rebar from any hex.pm mirror
```

followed, ~0.2s later in the same log dump, by the Postgres service container's own health-check
noise:

```
2026-07-30 04:35:01.605 UTC [73] FATAL:  role "root" does not exist
```

The `FATAL: role "root" does not exist` line is the Postgres service container's own default
health-check probe connecting as the OS user (`root`, GitHub Actions runner's default), which is
expected, harmless log noise emitted by every Postgres-service job on every run — it is not
gated on and does not fail the job. The job actually failed because `mix rebar` could not fetch
the `rebar` build tool from any configured hex.pm mirror — a transient network failure fetching a
build dependency, unrelated to the database at all.

## Evidence

12 observed dispatches across Phase 231, cross-referenced against both recapture jobs' `Recapture
admin-checkpoint baselines (in-CI)` / `Recapture admin-design baselines (in-CI)` job names:

```
30414885679: success / success
30504235540: success / success
30506164137: success / success
30507841875: success / success
30509363963: success / success
30511228553: success / success
30512523387: success / success
30514238789: FAILURE (checkpoint only) / success   <- the one occurrence, diagnosed above
30521297923: success / success
30523113463: success / success
30526744204: success / success
30526771018: success / success
```

**1 failure in 12 observations (~8%)**, a classic transient-mirror-fetch rate, not a persistent
or structural defect. No PR opened on the failed run (the job died before the
git-commit/push/`gh pr create` steps), so no cleanup was required.

## Fix options (none chosen here — low severity, does not block anything)

1. Add a retry to the `mix rebar` / `setup-beam` step specifically for the
   `hex.pm mirror` failure class (distinct from retrying the whole job).
2. Leave as-is: at an ~8% rate on a Tier-A job that is never in `ci-gate.needs` and never blocks
   a merge, the cost of a re-dispatch is lower than the cost of adding retry logic that could mask
   a genuinely-broken mirror configuration.

## Owner

Unassigned — low severity, does not block any merge (Tier-A, absent from `ci-gate.needs`).
Worth a look by whoever next touches `setup-beam`/dependency-fetch reliability across the
workflow, since the same `mix rebar` step pattern likely exists in every job that installs
Elixir dependencies fresh.
