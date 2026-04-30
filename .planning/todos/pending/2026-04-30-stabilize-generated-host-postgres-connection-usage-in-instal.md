---
created: 2026-04-30T20:01:33.965Z
title: Stabilize generated-host Postgres connection usage in install smoke
area: tooling
files:
  - scripts/ci/install-smoke.sh
  - .planning/uat-evidence/v1.20/getting-started-clean-machine/transcript.log
---

## Problem

The Phase 94 generated-host install-smoke run completed successfully, but the logs showed transient Postgres `too_many_connections` errors during the smoke sequence. Even though the suite recovered, leaving that untracked makes the CI harness look less deterministic and risks intermittent failures as test parallelism or local database limits change.

## Solution

Audit connection usage across the generated-host smoke steps and the spawned test services, then either reduce parallel demand, serialize the hotspot, or raise the harness configuration deliberately. Close this only after the smoke path runs without `too_many_connections` noise under the intended local/CI limits.
