---
phase: 238-generated-auth-runtime-proof
plan: "05"
subsystem: ci-evidence
tags: [github-actions, generated-auth, runtime-proof, blocked]
requires:
  - phase: 238-04
    provides: dedicated generated-auth runtime CI lane
provides:
  - durable exact-SHA CI failure diagnostics
affects: [AUTH-01, AUTH-02, AUTH-03]
key-files:
  created:
    - .planning/phases/238-generated-auth-runtime-proof/238-EVIDENCE.json
    - .planning/phases/238-generated-auth-runtime-proof/238-05-SUMMARY.md
  modified:
    - scripts/ci/generated-auth-runtime-proof.sh
decisions:
  - "Exact-SHA evidence remains blocked after the single permitted retry failed in the direct runtime lane."
status: blocked
---

# Phase 238 Plan 05: Generated Auth Runtime Proof Summary

**Exact-commit CI evidence is blocked; no AUTH requirement was marked complete.**

## Evidence Attempts

- `13a9f12eac5180427a9328cb7a94688e7dd076e5` — CI run `31019501361` failed before harness execution because the committed script was non-executable.
- `85b94ff503dd3513847b4ae20bd87ca6b1a7bdc8` — CI run `31021611104` reached the fresh generated host but failed the direct job because the harness checks a relative `$0` after changing directories.

## Deviation from Plan

### Auto-fixed Issues

1. [Rule 3 - Blocking integration] Made the runtime harness executable in `85b94ff5`.

## Blocker

The direct `Generated auth runtime proof` job remains red (`92359472633`). The single permitted corrected-SHA retry has been consumed; a subsequent fix must make the script self-reference absolute before a new exact-SHA CI proof can be requested.

## Self-Check: PASSED

- The evidence JSON records only run/job metadata and no credentials or logs.
- Its run and job conclusions are explicitly `failure`, so it cannot be confused with a passing proof.
