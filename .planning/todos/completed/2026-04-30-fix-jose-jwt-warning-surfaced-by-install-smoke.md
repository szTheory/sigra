completed: 2026-05-07
---
created: 2026-04-30T20:01:33.965Z
title: Fix JOSE JWT warning surfaced by install smoke
area: general
files:
  - scripts/ci/install-smoke.sh
  - .planning/uat-evidence/v1.20/getting-started-clean-machine/transcript.log
---

## Problem

The Phase 94 install-smoke run passed, but the output still emitted an existing warning that `JOSE.JWT.peek_payload/1` is undefined. That leaves the generated-host smoke path noisy and weakens trust in the test output because a real regression could be buried in repeated known warnings.

## Solution

Trace the call site that still expects `JOSE.JWT.peek_payload/1`, update it to the supported JOSE API for the pinned dependency version, and add or adjust a regression test so the install-smoke path runs clean without this warning.
