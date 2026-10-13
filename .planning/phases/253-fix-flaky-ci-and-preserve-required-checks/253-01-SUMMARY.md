---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: 01
subsystem: testing
tags: [ci, diagnosis, source-identity]
requires: [{phase: 252, provides: immutable CI source archive}]
provides: [versioned failure diagnosis, bounded source-indexed context]
affects: [253-02, 255]
tech-stack: {added: [], patterns: [offline source-bound companion]}
key-files:
  created: [.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-DIAGNOSIS.json]
  modified: [scripts/ci/ci-run-metrics.sh, scripts/ci/ci-run-metrics.test.sh, scripts/ci/ci_metrics_security.py]
requirements-completed: []
requirements-covered: [CIREL-01]
coverage:
  - id: D1
    description: Saved Test Z corrections retain original failures and passing Test D
    requirement: CIREL-01
    verification: [{kind: integration, ref: "bash scripts/ci/ci-run-metrics.test.sh --diagnosis-only", status: pass}]
    human_judgment: false
  - id: D2
    description: Late failure selection preserves redaction, line ranges and incomplete inputs
    verification: [{kind: unit, ref: "scripts/ci/ci-run-metrics.test.sh#test_late_failure_context_and_incomplete_inputs", status: pass}]
    human_judgment: false
status: complete
completed: 2026-10-13
actuals: {tasks: 2, commits: 4}
---

# Phase 253 Plan 01 Summary

The companion corrects two historical Test D signatures to the actual Test Z failure while preserving all original red outcomes. Forty producer/step records include explicit missing logs; this does not prove a current flake or satisfy CIREL-01.

## Accomplishments

- Added opt-in --diagnose-v1 consuming the saved archive and baseline with checked hashes and native jobs/steps.
- Selected actual failure lines before redaction/display clipping; missing, changed and truncated inputs remain incomplete.
- Full legacy replay remains unchanged: baseline verifier returned ready with no diagnostics; metrics contracts reported 48 passed, 0 failed.

## Task Commits

| Task | RED | GREEN |
|---|---|---|
| 1: archived Test Z diagnosis | d8d507b70 | 0e806c830 |
| 2: context and uncertainty | e7ecae3f7 | e46c616a82 |

## TDD Gate Compliance

Both target assertions failed intentionally before implementation. Both unchanged unittest reports were accepted as RED_EVIDENCE_OK. Their semantic assessments and original outputs are in 253-01-TASK1-RED.json and 253-01-TASK2-RED.json.

## Deviations from Plan

Diagnostics remain entirely offline, using the saved complete archive and existing fake-gh suite; additional GitHub acquisitions are zero. Records explicitly identify unretained producer logs rather than attempting to recreate missing historical context. CIREL-01 stays open despite this plan covering it.

## Issues Encountered

GitHub step timestamps have whole-second precision while logs have fractional timestamps; selection includes the final second, retaining the native command exit. Other producer logs were never retained. The original companion revision is preserved and read back at e46c616a82214503e56fca24d25da9adb61f6fbf; see 253-01-CHECKS.json.

## Self-Check: PASSED

Production commits are reachable; all deliverable paths exist; fresh contracts pass and the complete baseline replay matches. Diagnosis completeness remains explicit per record. No user setup is needed.
