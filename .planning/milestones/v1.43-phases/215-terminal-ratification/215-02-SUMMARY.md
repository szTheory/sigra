---
phase: 215
plan: 02
subsystem: example-app-parity
tags: [verification, ratification, health-02, example-suite, generated-host]
dependency_graph:
  requires: []
  provides: [health-02-parity-signal]
  affects: [215-04-health-04-ci-gate]
tech_stack:
  added: []
  patterns: [ci-parity-env, example-app-test-suite, generated-host-verification]
key_files:
  created: [.planning/phases/215-terminal-ratification/215-02-SUMMARY.md]
  modified: []
key_decisions:
  - "D-02 CONFIRMED: Example suite is 0-failures — no accepted-failure residue. The Phase 211-era tolerated set is fully resolved."
  - "Jetstream #907 deny-path log lines (5 lines, 5 branches: :expired/:invalid/:revoked/:already_accepted/:mismatch) are the TESTED structural defense firing — the emitting tests PASS."
  - "HEALTH-02 generated-host parity signal: 323 tests, 0 failures — mirrors CI Example unit smoke required check."
metrics:
  duration: "~4 minutes (suite: 2.8 seconds)"
  completed: 2026-07-03
status: complete
---

# Phase 215 Plan 02: Example App Suite (HEALTH-02 Parity Signal) Summary

**One-liner:** Example app test suite proven green — 323 tests, 0 failures against CI-parity localhost:5432 Postgres; Jetstream #907 deny-path correctly classified as tested-passing.

## What Was Done

Re-proved the `test/example` generated-host test suite green in the CI-parity environment
(`PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost`, localhost:5432 — the same DB coordinates
the CI `Example unit smoke (ExUnit + ConnTest)` required check uses). This is a verification-only
plan (D-06): no product code, example templates, tests, or fixtures were modified.

## HEALTH-02 Parity Signal

### Exact Reproducible Command

```bash
cd test/example
export PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost
unset PGPORT
MIX_ENV=test mix ecto.create && MIX_ENV=test mix ecto.migrate
mix test --include example_app
```

### Observed Counts (verbatim from test output)

```
Finished in 2.8 seconds (0.4s async, 2.4s sync)
323 tests, 0 failures
```

### Zero-Failures Confirmation (D-02)

**0 failures. No accepted-failure residue.** The Phase 211-era "green modulo known set" posture
(3 `Sigra.UpgradeIntegrationTest` env-DB failures) is fully resolved. D-02's "green means green"
bar is met: every one of the 323 tests passes.

## Jetstream #907 Structural Defense — Deny-Path Log Lines

During the test run, the following `[error]` log lines appeared:

```
** (ArgumentError) accept_invitation is not bound on branch=:expired — Jetstream #907 structural defense. This event should not originate from a legitimate client.
** (ArgumentError) accept_invitation is not bound on branch=:invalid — Jetstream #907 structural defense. This event should not originate from a legitimate client.
** (ArgumentError) accept_invitation is not bound on branch=:revoked — Jetstream #907 structural defense. This event should not originate from a legitimate client.
** (ArgumentError) accept_invitation is not bound on branch=:already_accepted — Jetstream #907 structural defense. This event should not originate from a legitimate client.
** (ArgumentError) accept_invitation is not bound on branch=:mismatch — Jetstream #907 structural defense. This event should not originate from a legitimate client.
```

**Classification: TESTED DENY-PATH — NOT FAILURES.**

These are the `accept_invitation` invalid-branch structural defense (Jetstream #907) firing
as the tests exercise the deny branches (expired, invalid, revoked, already-accepted, and
token-mismatch invitation accept paths). The tests that emit these lines all PASS. These
`[error]` log lines are expected test output confirming the structural defense control is
operational.

## CI Mirror

This local result is the **HEALTH-02 generated-host parity signal** and is mirrored remotely by
the **CI `Example unit smoke (ExUnit + ConnTest)` required check** (gated in plan 215-04,
HEALTH-04). The CI lane runs the same command in an equivalent environment on the PR's commit.

The local 323/0-failures result here provides pre-push confidence that the CI lane will pass
when the 215-04 PR is surfaced to GitHub Actions.

## Source Cleanliness (D-06)

```
git status --short -- test/example/
(no output — clean)
```

No example template, test, or fixture file was modified. The `test/example/` working tree is
completely clean. Verified.

## Deviations from Plan

None — plan executed exactly as written. This is a re-prove-and-record pass; no fixes were
needed because the suite was already green.

## Self-Check: PASSED

- [x] SUMMARY.md written at correct path
- [x] 323 tests, 0 failures confirmed
- [x] `example_app` keyword present in SUMMARY
- [x] `0 failures` string present in SUMMARY
- [x] Jetstream #907 deny-path lines classified as tested-passing
- [x] CI `Example unit smoke` link recorded
- [x] `git status -- test/example/` clean (no tracked source modified)
- [x] No product code, templates, tests, or fixtures modified (D-06)
