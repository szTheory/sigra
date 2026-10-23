---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "174"
subsystem: ci-reliability / offline recovery acceptance
status: halted
gap_closure: true
tags: [ci-reliability, git-permission-recovery, offline-acceptance, r13]
requires: ["253-166"]
provides: ["same-process elevated Git permission proof", "retained failed once-only offline acceptance"]
affects: ["253-168", "253-169", "253-170", "253-171", "253-172"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-174-PERMISSION-PREFLIGHT.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-174-REGRESSION.log
  modified: []
metrics:
  duration: "13m 23s acceptance"
  completed: 2026-10-20
actuals:
  tasks: 0
  commits: 1
---

# Phase 253 Plan 174: Git permission proof passed; acceptance halted

The root launched the exact first automated body once with `exec_command`, `sandbox_permissions=require_escalated`, under `caffeinate -i -s`. The Git object write/readback succeeded in the same shell as acceptance. The acceptance later failed one publication regression test. The retained final line is `VERIFY-EXIT 1`. No retry, Task 2, success receipt, freeze, browser launch or GitHub request followed.

## Input and launch identities

- Clean source: `441442566071ac5cc861fe87f35297c1b2e1d240`, branch `phase-244-playwright-measurement`.
- Exact first automated body SHA-256: `090350ba19dbfd1311feb14134286c0a3c4eaf0a2d004a43f21e154506c4ddcc`.
- Actual launch: `exec_command` chunk `a6e350`, session `87298`; terminal chunk `80eb44`, exit 1. Arguments are retained in the permission record and external `tool-arguments.json`.
- Shell PID: `15673`; probe object: `7ff2c3db6ad020b35e643bf121bfab2eb31eb695`. Exact 77-byte readback SHA-256: `efe7b9b6bc0f9ada188589e382a204523cfb865bf9b9c86c2d87272827692f9a`.
- UTC: `2026-10-20T17:20:25Z` to `2026-10-20T17:33:48Z`; actual power line is retained in the log.
- Raw diagnostics: `/private/tmp/sigra-253-174-to4qb_2g`; script, outer log, projection, three gate objects, deadline controls and actual launch metadata are retained there.
- The direct 166/publisher/dry-run pins and ten protected 167/173 files matched. The margin-1 deadline check exited 0; the margin-20 positive control exited 1.

## Actual results

- Permission probe: passed; no ref, index or tracked file changed by the probe.
- Publication projection: 17 requests, 0 binary blobs. Tree bodies: 2094034, 2096775, 1513109 and 17686 bytes. Maximum 2097152, remaining margin 377 bytes. Parent remains `09df342a82e03c3d5d40173c912b70e827f7eadc`; merge check clean.
- Hermetic, live-policy and paged `--stop-after full-pass` gates: passed. The old full-run `attempt_jobs` 7/7 stop remains a limitation, with no new full-run retry or cap change.
- `ci-hermetic-live-audit.test.py`: 66 tests passed.
- `ci-git-publication.test.py`: 118 tests, one failure (117 passed), 227.667 seconds.
- Later suites, including the required unfiltered dry-run suite of at least 79 tests: not started. No full dry-run count exists for this attempt.

## Failure and read-only diagnosis

`PublicationTests.test_exact_preserved_config_status_and_bytes_allow_only_planning_metadata_changes` failed at `scripts/ci/ci-git-publication.test.py:902`: the publisher returned `PublicationError: source working tree is dirty outside the exact preserved config bytes/status exception`.

The test copies the current project config into its fixture (`:889`). Current config SHA-256 is `225737694e79b502993ffa4a64a8e437d758711432aca20da8caa18ef3e52f7c`; the publisher's `CONFIG_SHA` and the test's expected result hard-code `8e312f6ccd3485941059446e5852b39651f7ad1863fa003c62f6e5635d7c0b8d`. `clean_source` correctly refuses those different bytes. This is a fixture dependency on the current config; changing Git permissions does not resolve it. No source, config, assertion, timeout or cap was changed and no test was rerun.

A second, static receipt-contract mismatch was found while recording diagnostics: Task 2's exact verifier reads `review["product_changes"]`, but the unchanged 173 review stores that field inside `status_dispositions`. Task 2 did not run because Task 1 failed. Preserve the original review and plan; resolve this mismatch in any separately planned successor rather than fabricating a field or success receipt.

## Commits

| Task | Commit | Result |
|---|---|---|
| Task 1 failure retention | `9f4f6f5fe` | Exact failed log and successful permission probe committed |

## Deviations and status

No source repair is authorized by this plan after failure. The once-only failure stops the chain, so Task 1 acceptance is incomplete and Task 2 is unstarted. 168–172 remain blocked. 167 and 173 remain halted at their exact original bytes; 173's final sentinel remains `VERIFY-EXIT 1` and both 173/174 success receipts are absent.

CIREL-01 remains `partial_not_reproduced`; CIREL-02 remains `unaccepted`; whole-phase verification is `not_started`. Product changes, actual GitHub requests, native browser launches, remote changes and installation: zero. The four shared planning files remained byte-identical throughout this plan; root owns later routing updates.

Next command: `$gsd-plan-phase 253 --gaps` to plan the fixture/receipt-contract corrections and a separately identified acceptance attempt. Plan 174 must not be rerun.

## Self-Check: PASSED

This checks honest failure retention, not acceptance: canonical log is byte-identical to raw output, ends `VERIFY-EXIT 1`, and has SHA-256 `a53f6b0e9174accd8da1a7cbe68287429305f6b927ece2b56262079088250b3a`; probe readback is exact; all protected input/shared hashes match; success receipt is absent. Acceptance remains failed.
