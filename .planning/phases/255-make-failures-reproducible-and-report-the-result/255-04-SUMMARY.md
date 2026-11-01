---
phase: 255-make-failures-reproducible-and-report-the-result
plan: "04"
subsystem: ci-browser-testing
tags: [playwright, local-reproduction, resource-ownership]
dependency_graph:
  requires: ["255-01", "255-02"]
  provides: [shared-browser-selection, owned-local-browser-reproduction]
  affects: [".github/workflows/ci.yml", ".github/actions/example-playwright-boot/action.yml"]
tech_stack:
  added: []
  patterns: [shared-native-selection-catalog, invocation-owned-MIX_BUILD_PATH, token-checked-resource-cleanup]
key_files:
  created:
    - scripts/ci/ci-browser-command.mjs
    - scripts/ci/ci-browser-command.test.mjs
    - scripts/ci/ci-browser-local.py
    - scripts/ci/ci-browser-local.test.py
    - .planning/phases/255-make-failures-reproducible-and-report-the-result/255-04-01-RED.json
    - .planning/phases/255-make-failures-reproducible-and-report-the-result/255-04-02-RED.json
    - .planning/phases/255-make-failures-reproducible-and-report-the-result/255-04-NATIVE-BLOCKER.json
    - .planning/phases/255-make-failures-reproducible-and-report-the-result/255-04-NATIVE-POSTCHECK-FAILED.json
    - .planning/phases/255-make-failures-reproducible-and-report-the-result/255-04-NATIVE.json
  modified:
    - scripts/ci/ci-browser-records.mjs
    - scripts/ci/ci-playwright-report.test.mjs
    - scripts/ci/ci-measure-workflow.test.mjs
    - scripts/ci/ci-hosted-gate-verify.py
    - .github/workflows/ci.yml
    - .github/actions/example-playwright-boot/action.yml
decisions:
  - Keep exact Playwright argv, project selection, report names, and event-specific snapshot behavior in one shared command catalog.
  - Give every local invocation its own database, server process group, output root, and Mix build path.
  - Apply a local grep to both native listing and execution so recorded selection identities match executed identities.
metrics:
  duration: "23 minutes from first task commit through native gate"
  completed: 2026-10-24
  tasks: 2
  files: 15
  commits: 5
plan_head_before: e70889c8f95499ba032d9333042b9e1adcb06629
plan_head_after: a22308d2bdee5cb7ff6887e4e16660ea38e79e68
actuals:
  tokens: 23988
  tasks: 2
  commits: 5
status: complete
---

# Phase 255 Plan 04: Shared Browser Reproduction Summary

CI and local reproduction now use the same exact Playwright selections, and local runs own and clean their database, server, build output, and diagnostics.

## What Changed

- Added a shared browser command catalog for all five seams. The CI workflow uses it without changing job names, step IDs, reports, matrices, retries, or event-specific design-gallery behavior.
- Updated browser policy recording to read the shared catalog while keeping native report identity checks independent. The hosted verifier now copies the catalog into its temporary policy root.
- Added a local runner that refuses occupied ports and existing target databases, creates a token-marked database, uses `CI=true` and one matching `PORT` for preparation and serving, waits for HTTP readiness, and records preparation, discovery, and execution commands.
- Each run uses an exclusive output root and a `MIX_BUILD_PATH` inside it, so an existing build compiled for a different port is left untouched. Cleanup checks the recorded database comment and server process group before removal.
- Updated the composite example boot action to set `CI=true` for preparation and serving. Added unit, native-selection, workflow-contract, ownership, and TIME_WAIT checks.

## Verification

- Task 1: Node 20.19.5 `node --test` over browser command, browser records, Playwright report, and workflow measurement suites: **53 passed**.
- Hosted policy-copy integration check: **1 passed**.
- Task 2 local safety tests: **10 passed**.
- Task 2 browser command, workflow measurement, and preparation contract suites: **19 passed**.
- Final native command, run with Node 20.19.5 and the locked Playwright 1.59.1 binaries: **passed**. It selected and executed exactly the chromium and mobile `golden-path.spec.ts` “full user lifecycle” cases. The occupied-port check preserved its listener. The invocation database, server, and output directory were removed; the unrelated `jon` database fingerprint stayed `171292|jon|true|-1`; no screenshot files changed. Evidence is in [255-04-NATIVE.json](255-04-NATIVE.json).
- `git diff --check`: passed. No hosted workflow was dispatched and no snapshots were rewritten.
- This run was on macOS and proves behavior. Pixel and font parity still requires Ubuntu 24.04.

## TDD Gate Compliance

Both tasks started with assertion-based RED reports, classified with `tdd-red-evidence`, and committed before their implementations. Task 1 first failed on the missing shared demo selection; Task 2 first failed on an occupied-port safety assertion. The RED reports are [255-04-01-RED.json](255-04-01-RED.json) and [255-04-02-RED.json](255-04-02-RED.json).

## Deviations from Plan

1. **Rule 3 — temporary policy dependency closure:** once browser records imported the shared command catalog, the hosted verifier's temporary copy omitted that dependency. The verifier now copies the catalog too; its focused fixture integration test passes. Commit: `30ebd28d6`.
2. **Rule 1 — database comment lookup:** the first native setup showed that PostgreSQL database comments require `shobj_description`, not `obj_description`. The query now reads the shared-object comment. The failed attempt's evidence remains in [255-04-NATIVE-BLOCKER.json](255-04-NATIVE-BLOCKER.json); its exact invocation-owned database was verified by token and removed.
3. **Isolated build path:** a pre-existing compiled Phoenix endpoint had a different compile-time port. The local runner now builds under the invocation output root and uses that path for both preparation and serving, preserving the contributor's shared build cache.
4. **Exact filtered selection:** native execution showed a narrowed grep must also be applied to `--list`. Both operations now receive the same filter, and a native selection test asserts the two exact identities.
5. **TIME_WAIT postcondition:** one completed native run returned success and passed the database/server/output cleanup and exact identity checks, then the harness's bind-based postcheck treated macOS TIME_WAIT as a live server. A read-only TCP listener check found no listener; the real TIME_WAIT fixture passes. This earlier nonzero wrapper result is preserved in [255-04-NATIVE-POSTCHECK-FAILED.json](255-04-NATIVE-POSTCHECK-FAILED.json). The final unchanged-source native gate then exited 0.
6. **Cache note:** an early `py_compile` command wrote bytecode in the pre-existing untracked `scripts/ci/__pycache__/`. That directory was left untouched afterwards and is not part of the commit.

## Deferred Issues

- None for Plan 255-04. The temporary macOS browser sandbox failure and first database marker failure are preserved as diagnostics; the final native gate passed after the implementation fixes.

## Self-Check: PASSED

The summary, native evidence, and both RED reports exist. All five measured plan task commits are ancestors of the current branch head.
