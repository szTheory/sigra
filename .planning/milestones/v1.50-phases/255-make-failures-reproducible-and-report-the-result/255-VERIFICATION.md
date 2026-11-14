---
phase: 255-make-failures-reproducible-and-report-the-result
verified: 2026-11-10T20:36:21Z
status: passed
score: 29/29 plan truths verified; roadmap 4/4 success criteria covered
covered_files:
  - ".github/actions/ci-diagnostic-upload/action.yml"
  - ".github/actions/example-playwright-boot/action.yml"
  - ".github/workflows/ci.yml"
  - ".planning/execution/255-diagnostics-canary/API-ARTIFACT-LIST-40122912945.body.json"
  - ".planning/execution/255-diagnostics-canary/API-RUN-40122912945.body.json"
  - ".planning/execution/255-diagnostics-canary/FREEZE.json"
  - ".planning/execution/255-diagnostics-canary/RESULT.json"
  - ".planning/execution/255-replay/DISTRIBUTION-ATTEMPTS.json"
  - ".planning/execution/255-replay/DISTRIBUTION.json"
  - ".planning/execution/255-replay/INPUTS.json"
  - ".planning/execution/255-replay/PREFLIGHT.json"
  - ".planning/execution/255-replay/REPORT.json"
  - ".planning/execution/255-replay/REPORT.md"
  - ".planning/execution/255-replay/RESULT.json"
  - ".planning/execution/255-replay/input-package.tar.gz"
  - ".planning/execution/255-review-fix/CR-04-FRAGMENT-FOLLOWUP.json"
  - ".planning/execution/255-review-fix/RESULT.json"
  - ".planning/execution/255-verification/BROWSER-CAPTURE.json"
  - ".planning/execution/255-verification/BROWSER-DIAGNOSTICS-AFTER-REVIEW.json"
  - ".planning/execution/255-verification/FINAL-MIX-RECEIVERS-AFTER-REPAIR.json"
  - ".planning/execution/255-verification/FINAL-MIX-RECEIVERS.json"
  - ".planning/execution/255-verification/FINAL-REGRESSION.json"
  - ".planning/execution/255-verification/MIX-CAPTURE.json"
  - ".planning/execution/255-verification/PRIOR-PHASE-REGRESSION.json"
  - ".planning/execution/255-verification/RAW-STORAGE-FINAL.json"
  - ".planning/execution/255-verification/REGRESSION-GATE.json"
  - ".planning/execution/255-verification/TRACE-OVERHEAD-AFTER-REVIEW.json"
  - ".planning/execution/255-verification/browser-diagnostics-after-review.zip"
  - ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-01-PLAN.md"
  - ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-01-SUMMARY.md"
  - ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-02-PLAN.md"
  - ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-02-SUMMARY.md"
  - ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-03-PLAN.md"
  - ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-03-SUMMARY.md"
  - ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-04-PLAN.md"
  - ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-04-SUMMARY.md"
  - ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-05-PLAN.md"
  - ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-05-SUMMARY.md"
  - ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-06-PLAN.md"
  - ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-06-SUMMARY.md"
  - ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-07-PLAN.md"
  - ".planning/phases/255-make-failures-reproducible-and-report-the-result/255-07-SUMMARY.md"
  - "CONTRIBUTING.md"
  - "MAINTAINING.md"
  - "mix.exs"
  - "scripts/ci/ci-browser-command.mjs"
  - "scripts/ci/ci-browser-command.test.mjs"
  - "scripts/ci/ci-browser-diagnostics.test.mjs"
  - "scripts/ci/ci-browser-local.py"
  - "scripts/ci/ci-browser-local.test.py"
  - "scripts/ci/ci-browser-records.mjs"
  - "scripts/ci/ci-command-record.py"
  - "scripts/ci/ci-command-record.test.py"
  - "scripts/ci/ci-comparison-replay.py"
  - "scripts/ci/ci-comparison-replay.test.py"
  - "scripts/ci/ci-comparison-report.test.py"
  - "scripts/ci/ci-diagnostic-bundle.py"
  - "scripts/ci/ci-diagnostic-bundle.test.py"
  - "scripts/ci/ci-diagnostics-canary.py"
  - "scripts/ci/ci-diagnostics-canary.test.py"
  - "scripts/ci/ci-hosted-gate-verify.py"
  - "scripts/ci/ci-measure-workflow.test.mjs"
  - "scripts/ci/ci-mix-receivers.py"
  - "scripts/ci/ci-mix-receivers.test.py"
  - "scripts/ci/ci-playwright-report.test.mjs"
  - "scripts/ci/ci-prep-profile.mjs"
  - "scripts/ci/ci-prep-profile.test.mjs"
  - "scripts/ci/ci-prep-semantics.test.mjs"
  - "scripts/ci/ci-run-metrics.sh"
  - "scripts/ci/fixtures/playwright-admin-theme-diagnostics.spec.ts"
  - "scripts/ci/fixtures/playwright-diagnostics.config.ts"
  - "scripts/ci/fixtures/playwright-diagnostics.spec.ts"
  - "scripts/ci/sigra-dep-off.sh"
  - "scripts/ci/test-sigra-dep-off.sh"
  - "test/example/priv/playwright/fixtures/adminTheme.ts"
  - "test/example/priv/playwright/lib/reporters/failure-jsonl.mjs"
  - "test/example/priv/playwright/playwright.config.ts"
  - "test/sigra/planning/ci_timing_formatter_test.exs"
  - "test/sigra/planning/phase_198_contributor_dx_contract_test.exs"
  - "test/sigra/planning/phase_230_design_gallery_split_test.exs"
  - "test/sigra/planning/phase_232_playwright_economics_test.exs"
  - "test/sigra/planning/phase_233_library_economics_contract_test.exs"
  - "test/sigra/planning/phase_234_playwright_inventory_contract_test.exs"
  - "test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs"
  - "test/sigra/planning/phase_235_terminal_ratification_contract_test.exs"
  - "test/support/ci_timing_formatter.ex"
  - "test/test_helper.exs"
covered_digest: "v4:sha256:0974b122a74285da13c500ea0b5b6ab52690cb6791ef17bb97499f9264e52fb4"
behavior_unverified: 0
overrides_applied: 0
---

# Phase 255: Make Failures Reproducible and Report the Result — Verification Report

**Phase Goal:** Contributors can reproduce updated CI checks locally and maintainers can independently replay the final speed and reliability comparison.
**Verified:** 2026-11-10T20:36:21Z
**Status:** passed
**Re-verification:** No — initial verification

## Goal Achievement

The phase goal is achieved in the current source tree. Contributors have documented local entry points that preserve `mix ci`, share the CI/browser selection logic, and make prerequisites explicit. Native failure records and invocation-bound diagnostic bundles are present and wired. The saved-input replay package currently hashes to `6d098e9bee2d28b0d88dda2c517503467448939b4e48af84bf6e2ffd5255fe23`; a current local replay returns `insufficient_data`, zero successful pairs, null median/p95, and runner costs of 2,046/1,589 seconds. The immutable remote ref still resolves to the recorded evidence commit. This satisfies CIMEAS-03's replay/reporting requirement; it does not show that either speed target passed.

### Roadmap Success Criteria

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | Documented local commands execute the relevant updated CI paths; `mix ci` remains the contributor entry point and browser/database preparation is explicit. | ✓ VERIFIED | `CONTRIBUTING.md` and `MAINTAINING.md` document the exact local commands and prerequisites. Current named tests pass for exact browser selection parity and ordinary/scaffold/dep-off receiver identity; the saved native `mix ci` record shows all seven ordered legs completed. |
| 2 | A failed updated check identifies the failed test/command, reproduction command, applicable seed, and retained diagnostic output. | ✓ VERIFIED | Current named process-recorder and safe-bundle tests pass. `FINAL-MIX-RECEIVERS-AFTER-REPAIR.json` records actual invocation IDs, reproduction commands, seeds, and exits; the final local browser record has seven native cases, and the source-bound hosted failure artifact contains the intentional assertion and verified logs. The cancellation artifact's two absent files remain explicitly listed. |
| 3 | The final before/after calculation is replayable from saved inputs, with sample sizes, terminal outcomes, attempt numbers, cache conditions, percentile method, and limitations. | ✓ VERIFIED | The current package replay passes with 191 members and no network command attempts; its SHA-256 matches `DISTRIBUTION.json`. The recorded unrelated-checkout replay independently produced zero pairs, null median/p95, and the literal costs. `REPORT.json` states the two attempts, sample requirement, cache observations, outcomes, percentile methods, cancellations, and limitations. |
| 4 | The report names the tested sources, says whether the 20% median and non-increasing p95/runner-time targets hold, and separates remaining failures from implemented changes. | ✓ VERIFIED | `REPORT.md` and `REPORT.json` name measured, analysis, and diagnostic sources; the current report semantic test passes. Both artifacts say `insufficient_data`, null median/p95, and speed targets unproven, while separating later development and failure evidence from the measured comparison. |

### Plan Truths

All 29 distinct plan truths were checked against implementation and recorded behavior. The phase context's 17 trackable decisions were honored (`check.decision-coverage-verify`: 17/17). Plan prohibitions are assessed separately below.

| Plan | Truth | Status | Evidence |
|---|---|---|---|
| 255-01 | D-11: preflight resolves measured sources, receipts and dependencies before dependent work. | ✓ VERIFIED | `PREFLIGHT.json` and `INPUTS.json` exist; 255-01 artifact check passed 3/3. Missing receipt/dependency tests require a concrete blocked result. |
| 255-01 | D-12: replay uses the pinned repaired calculator and hash-pinned helpers/data separately from measured sources. | ✓ VERIFIED | `INPUTS.json`, distributed manifest, and replay test bind calculator `d5b7300c…`, transitive files, and source roles. The independent replay verified unchanged hashes with zero network command attempts. |
| 255-01 | D-13: replay returns insufficient data, zero pairs, null statistics, and literal 2,046/1,589 costs. | ✓ VERIFIED | The current named saved-result test passed; current package replay output, `REPORT.json`, and the independent retrieval record agree on zero pairs, null statistics, and both literal costs. |
| 255-01 | D-14: calculation preserves median/p95 methods, 20-pair requirement, and attempt costs. | ✓ VERIFIED | `REPORT.json` states ordinary median, nearest-rank `ceil(0.95*n)`, 20 required pairs, and both attempt-2 costs. Replay tests assert literal costs and attempts. |
| 255-02 | D-06: real failures preserve argv/native identity, safe reproduction, cwd, source/dirty state, tools, allowlisted config and applicable seed. | ✓ VERIFIED | Five current command-recorder tests passed, including real signal and cleanup-failure cases. Native Mix/browser records contain actual invocation context and seed-or-null values. |
| 255-02 | D-08: bundles identify invocation/source/run/attempt/seam and keep command streams separate. | ✓ VERIFIED | `ci-diagnostic-bundle.test.py` passed 15/15; hosted success/failure/cancellation records bind run, attempt, source and invocation. |
| 255-02 | D-09: final bundles stage only current invocation files and check auth, secrets and escaping paths. | ✓ VERIFIED | The finished-archive tests cover auth storage, secret sentinels, archive members, symlinks, traversal, identity, userinfo, camel-case/query/form/fragment credentials. The sanitized final browser ZIP is retained with a verified hash. |
| 255-02 | D-17: implementation uses small repository-local tools and existing test infrastructure. | ✓ VERIFIED | The 48-file final-source manifest contains repository CI scripts, workflow/action files, tests, and contributor docs; no dependency or new test framework was added. |
| 255-03 | D-01: `MIX_ENV=test mix ci` remains the seven-leg contributor command with one library-suite owner. | ✓ VERIFIED | `mix.exs`, `CONTRIBUTING.md`, and the native receiver capture agree on the ordered seven legs and single ordinary-suite owner. |
| 255-03 | D-02: ordinary, six scaffold modules, and dep-off receivers actually execute and propagate failure. | ✓ VERIFIED | Final native gate: 2,695 ordinary tests, 22 scaffold tests, and 65 dep-off checks; all passed. The preserved earlier failed native gate and receiver-specific negative tests remain separate. |
| 255-03 | D-03: required prerequisites are checked and each failed test invocation records its real seed. | ✓ VERIFIED | Contributor guide names live PostgreSQL and pinned `phx_new 1.8.8`; native records show actual per-receiver seeds. No seed is invented for non-test errors. |
| 255-03 | D-06: Mix failures retain native identity/argv and output before ExUnit reporting. | ✓ VERIFIED | Recorder failure/signal tests pass; native records retain independent command streams and invocation identities. |
| 255-04 | D-04: local and CI browser commands share exact selections, projects, and snapshot rules across five seams. | ✓ VERIFIED | Six current `ci-browser-command.test.mjs` tests pass, including actual selection identity checks. Workflow-to-helper links pass and the source declares all five owners. |
| 255-04 | D-05: local browser runs own fresh database, port, server, output, and matching CI/PORT settings. | ✓ VERIFIED | Native browser records show invocation-owned resources and distinct ports/databases; `ci-browser-local.test.py` and native ownership checks cover collision and cleanup behavior. |
| 255-04 | D-03: browser preparation checks lockfile/browser/OS and separates example from library PostgreSQL settings. | ✓ VERIFIED | `CONTRIBUTING.md` and wrapper checks identify pinned Playwright/browser setup, supported visual environment, and separate PG variables. |
| 255-04 | D-06: prep/start/discovery errors preserve native output and focused reproduction. | ✓ VERIFIED | Browser native diagnostics include startup/discovery failure cases and unavailable-trace reasons; output remains per invocation. |
| 255-05 | D-07: first assertion failure retains a usable trace at zero retries, while pass traces are discarded. | ✓ VERIFIED | Final native browser evidence records seven cases and three inspected traces; the browser diagnostic test exercises failure retention and pass disposal with retries zero. |
| 255-05 | D-08: sequential browser invocations preserve reports, streams, logs and failure files. | ✓ VERIFIED | Native diagnostic evidence has separate invocation roots; process/browser regression tests cover output isolation and preserved prior output. |
| 255-05 | D-09: custom contexts use synthetic-account scoped trace handling; auth remains temporary. | ✓ VERIFIED | Final browser record declares synthetic accounts only; finished archive tests validate auth exclusion and sanitized trace payloads. |
| 255-05 | D-10: real tests cover startup/discovery/assertion failure, passing disposal, and isolation. | ✓ VERIFIED | `.planning/execution/255-verification/BROWSER-DIAGNOSTICS-AFTER-REVIEW.json` records the seven native cases and three traces; its sanitized archive hash matches `BROWSER-CAPTURE.json`. |
| 255-06 | D-08: CI retains and verifies explicitly staged, source/run/attempt/job/seam-bound artifacts for seven days. | ✓ VERIFIED | The production upload action is wired to workflow owners; all three actual artifacts were retrieved and verified against run/source/attempt identity and member hashes. Retention expiry is recorded as 2026-10-31. |
| 255-06 | D-10: bounded non-publishing canary proves hosted success, failure and actual fixture cancellation. | ✓ VERIFIED | `RESULT.json` binds success 40122912945, failure 40123954650, and cancelled 40124112173 to the fixture/source and actual uploaded artifacts. Cancellation is partial; absent files remain listed. |
| 255-06 | D-07: passing trace overhead is measured on final changed diagnostic source and kept outside comparison. | ✓ VERIFIED | Final overhead record has six observations (3 off/3 on), source `0e35a4c83…`, one worker, zero retries, and reports noisy/inconclusive. It adds no acceptance samples. |
| 255-06 | D-16: hosted diagnostics have a separate finite allowance and do not restart the original comparison. | ✓ VERIFIED | Frozen ledger ended at 37/120 requests, 3/4 invocations, 1/2 pushes, and zero retries. The first rate read lacks a saved receipt/time and is marked unverified and conservatively charged; it is not described as precharged. No comparison window or allowance was renewed. |
| 255-07 | D-11: exact immutable package is retrieved from a remote branch and replayed from a clean, offline checkout. | ✓ VERIFIED | `DISTRIBUTION.json` records the successful unrelated-checkout retrieval and replay with 191 verified members and zero network command attempts. Current local replay matches the package hash, and a read-only `git ls-remote` confirms the evidence ref still points to the recorded commit. |
| 255-07 | D-15: concise report links commands and keeps original, repaired, and diagnostic sources distinct. | ✓ VERIFIED | Report and both guides link the executable paths; source identities are separate in text and machine-readable JSON. Report assertions passed 6/6. |
| 255-07 | D-16: faithful replay says insufficient data and leaves speed requirements open. | ✓ VERIFIED | Report status is `insufficient_data`; both speed requirements remain open; no replacement sample or extended window is claimed. |
| 255-07 | D-17: contributor instructions use existing repository tools and keep maintenance scoped. | ✓ VERIFIED | Guide commands use Mix, Python, Node, and the existing browser lockfile; no added dependency or unrelated capability appears in the source scope. |
| 255-07 | D-03: cold-checkout, PostgreSQL, Phoenix archive, runtime, lockfile, and browser/OS preparation are explicit. | ✓ VERIFIED | `CONTRIBUTING.md` lists each prerequisite and supported visual comparison environment; report semantic tests assert the guide coverage. |

**Plan-truth score:** 29/29 verified. No truth depends on an untested state transition or cancellation invariant: current named tests exercise the failure/bundle paths, and retained native execution records cover the Mix and browser outcomes.

### Current Working-Tree Diagnostics

The current working tree has local edits in `.github/workflows/ci.yml` and `scripts/ci/ci-diagnostics-canary.test.py` that add OS dependency report/log capture and metadata. The latest main CI run does not contain these edits, so it is not evidence for them. The focused current-worktree regression `CanaryContractTests.test_browser_diagnostics_bundle_captures_os_dependency_failure_report` passed; it executes the extracted workflow steps against temporary runner/workspace roots, stages and verifies the bundle with the current production helpers, and checks missing and symlinked report paths. This is local regression evidence only. The hosted canary remains bound to its recorded 2026-10-24 source; no new hosted run or acceptance sample is claimed.

### Plan Prohibitions

The plans marked these prohibitions unresolved during planning. I checked them as negative requirements instead of treating the planning status as proof. The explicit regression tests and captured outcomes below resolve them; none is silently waived.

| Plan | Prohibited behavior | Status | Evidence |
|---|---|---|---|
| 255-01 | Renew collection, replace observations, or run the collection driver. | ✓ VERIFIED | Report shows zero replacement samples and no extended window; the replay tests calculate from pinned saved inputs. |
| 255-01 | Treat missing family metadata as source divergence or a speed improvement. | ✓ VERIFIED | Report calls the source comparison insufficient and both speed requirements open; semantic tests reject false speed/source claims. |
| 255-02 | Replace a failed process/signal with a cleanup or reporting error. | ✓ VERIFIED | Named primary-failure, signal, SIGKILL and failing-cleanup tests pass. |
| 255-02 | Retain credentials, authentication state, or unrelated files. | ✓ VERIFIED | Finished-bundle secret/auth/escaping-path tests pass, including fragment credentials; final archive is sanitized. |
| 255-03 | Weaken coverage, hide missing prerequisites, or infer execution from alias text. | ✓ VERIFIED | Final native receiver counts prove actual execution; prerequisite and receiver regression checks pass. |
| 255-03 | Promise seed propagation or invent seeds for non-test failures. | ✓ VERIFIED | Seed tests and actual records store each ExUnit seed per invocation and record `null` when no test seed exists. |
| 255-04 | Reset unowned databases, kill unowned processes, or reuse occupied ports. | ✓ VERIFIED | Local owner tests and the recorded real SIGTERM probe remove only owned resources; an unrelated database/listener remain unchanged. |
| 255-04 | Replace exact CI selections, snapshots, five-job isolation, one worker, or zero retries. | ✓ VERIFIED | Shared-selection tests assert exact identities/projects and retry/worker policy; workflow owners remain five. |
| 255-05 | Change all Playwright consumers, add retry wrappers, or claim traces before context/hard runner loss. | ✓ VERIFIED | Scoped config and no-retry checks pass; reports state `context_not_created` and `runner_terminated` when no trace can exist. |
| 255-05 | Treat passing-run tracing as free or subtract it from original results. | ✓ VERIFIED | Six-run final-source overhead is reported as noisy/inconclusive and adds zero comparison samples. |
| 255-06 | Change required checks/gate protections or reuse a prior acceptance allowance. | ✓ VERIFIED | Current source and regression records preserve gate names; the canary uses its own frozen ledger and closes inside its caps. |
| 255-06 | Fake cancellation or invent final artifacts after runner loss. | ✓ VERIFIED | GitHub reports a real cancelled run; its partial artifact explicitly lacks `final-output.log` and `final-trace.zip`. |
| 255-07 | Claim speed from unequal success/failure costs, development runs, or unknown initiating event. | ✓ VERIFIED | Report separates the 2,046/1,589 observations and later development runs; it states the original event is unknown and speed is unproven. |
| 255-07 | Count reservations/preparations as samples or treat missing times as zero. | ✓ VERIFIED | Report says zero prep/reservation samples; baseline wait remains `null`. Report tests reject sample inflation. |

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `scripts/ci/ci-comparison-replay.py`, `PREFLIGHT.json`, `INPUTS.json` | Pinned, read-only preflight and replay closure | ✓ VERIFIED | 255-01 artifact check 3/3; helper is substantive and called by distribution/replay commands. |
| `scripts/ci/ci-command-record.py`, `scripts/ci/ci-diagnostic-bundle.py` | Native command record and safe archive staging | ✓ VERIFIED | 255-02 artifact check 2/2; both are called from browser/Mix flows and exercised by tests. |
| `scripts/ci/ci-mix-receivers.test.py`, `255-local/MIX-RECEIVERS.json` | Native receiver identities | ✓ VERIFIED | 255-03 artifact check 2/2; current final receiver capture records all three suites and seeds. |
| `scripts/ci/ci-browser-command.mjs`, `scripts/ci/ci-browser-local.py` | Shared browser commands and owned local lifecycle | ✓ VERIFIED | 255-04 artifact check 2/2; CI workflow calls shared selectors and local wrapper calls command recorder. |
| `scripts/ci/ci-browser-diagnostics.test.mjs`, `255-local/BROWSER-DIAGNOSTICS.json` | First-failure traces and native browser outcomes | ✓ VERIFIED | 255-05 artifact check 2/2; final local evidence after review independently covers seven cases. |
| `.github/actions/ci-diagnostic-upload/action.yml`, canary `FREEZE.json` and `RESULT.json` | Bounded upload path and retrieved hosted outcomes | ✓ VERIFIED | 255-06 artifact check 3/3; workflow wiring and all three actual terminal outcomes were verified. |
| `255-replay/DISTRIBUTION.json`, `REPORT.md`, `REPORT.json` | Independent replay and final result | ✓ VERIFIED | 255-07 artifact check 3/3; actual remote retrieval and offline replay match the report. |

The GSD key-link query found 13 of 14 links by text pattern. The remaining link, canary controller → frozen ledger, was checked manually: `load_freeze()` reads and validates the passed `freeze_path`; `assert_source_identity()` checks that file before requests; `charge_request()` locks, enforces, and persists every budget reservation. The query's uppercase `FREEZE` string pattern was too narrow. All 14 links are WIRED.

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `ci-comparison-replay.py` | `ci-run-metrics.sh` | pinned `--evaluate-comparison` | WIRED | query found invocation. |
| `INPUTS.json` | captured Phase 254 receipt | receipt path, commit and SHA-256 | WIRED | query found hash validation. |
| `ci-command-record.py` | `ci-diagnostic-bundle.py` | invocation manifest and streams | WIRED | query found shared invocation ID. |
| `mix.exs` | `ci-command-record.py` | seven native command legs | WIRED | query found recorder wrapper in alias. |
| timing formatter | `ci-command-record.py` | seed and failed test identity | WIRED | query found seed record calls. |
| workflow | `ci-browser-command.mjs` | shared exact selectors | WIRED | query found all five browser owners. |
| `ci-browser-local.py` | `ci-command-record.py` | preparation/start/select/run output capture | WIRED | query found recorder calls. |
| `ci-browser-local.py` | Playwright config | scoped diagnostics environment | WIRED | query found `SIGRA_CI_DIAGNOSTICS`. |
| admin theme fixture | diagnostic bundle helper | custom trace registration | WIRED | query found trace registration path. |
| workflow | upload action | explicit retained-file boundary | WIRED | query found action use in library/browser owners. |
| canary controller | frozen allowance | load, identity-check and atomic budget reservation | WIRED | manually traced `load_freeze`, `assert_source_identity`, and `charge_request`; see note above. |
| `CONTRIBUTING.md` | browser local wrapper | focused command and preparation | WIRED | query found documented command. |
| `MAINTAINING.md` | final report | report and exact retrieval command | WIRED | query found report link. |
| distribution receipt | replay helper | exact archive then offline calculation | WIRED | query found package digest and replay fields. |

## Data-Flow Trace (Level 4)

| Artifact | Data variable | Source | Produces real data | Status |
|---|---|---|---|---|
| `REPORT.json` | comparison result, attempts, cost, cache conditions | pinned evaluator over hashed saved receipts | Yes | ✓ FLOWING |
| `FINAL-MIX-RECEIVERS-AFTER-REPAIR.json` | tests, failures and seeds per receiver | actual ExUnit/dep-off process outputs | Yes | ✓ FLOWING |
| `BROWSER-DIAGNOSTICS-AFTER-REVIEW.json` and sanitized ZIP | native exits and traces | actual Playwright/server invocations | Yes | ✓ FLOWING |
| canary `RESULT.json` | conclusions and archive member hashes | actual GitHub run/artifact responses retained locally | Yes | ✓ FLOWING |

## Behavioral Spot-Checks

| Behavior | Command/evidence | Result | Status |
|---|---|---|---|
| Saved-input result | `python3 -B scripts/ci/ci-comparison-replay.test.py ReplayTest.test_saved_result_is_calculated_without_changing_inputs` | 1 named test passed in 9.311 s; literal costs and null statistics checked | ✓ PASS |
| Report semantics | `python3 -B scripts/ci/ci-comparison-report.test.py ComparisonReportTest.test_saved_sources_costs_and_zero_pair_result_are_literal` | 1 named test passed; source identities and zero-pair result checked | ✓ PASS |
| Browser command parity | `node --test --test-name-pattern='native Playwright selections match exact' scripts/ci/ci-browser-command.test.mjs` | 1 selected test passed in 7.108 s | ✓ PASS |
| Mix receiver identity | `python3 -B scripts/ci/ci-mix-receivers.test.py MixReceiverReportTest.test_accepts_exact_ordinary_scaffold_and_dep_off_identities` | 1 named test passed | ✓ PASS |
| Native failure recording | `python3 -B scripts/ci/ci-command-record.test.py CommandRecordTest.test_primary_failure_survives_failing_cleanup_with_exact_streams_and_record` | 1 named test passed | ✓ PASS |
| Invocation-bound bundle | `python3 -B scripts/ci/ci-diagnostic-bundle.test.py DiagnosticBundleTest.test_staged_archive_contains_only_hashed_current_invocation_files_and_identity` | 1 named test passed | ✓ PASS |
| Current local OS-dependency capture | `python3 -B scripts/ci/ci-diagnostics-canary.test.py CanaryContractTests.test_browser_diagnostics_bundle_captures_os_dependency_failure_report` | 1 named regression passed in 6.607 s against current worktree snippets and helpers | ✓ PASS |
| Current package replay | `python3 -B scripts/ci/ci-comparison-replay.py replay --package .planning/execution/255-replay/input-package.tar.gz --output /tmp/phase255-current-replay.json` | Exit 0; package hash matches; result is `insufficient_data`, zero pairs, null median/p95, costs 2,046/1,589 | ✓ PASS |
| Final native contributor gate | `FINAL-MIX-RECEIVERS-AFTER-REPAIR.json`, `MIX-CAPTURE.json` | Saved 381.237 s `mix ci` record shows all seven legs succeeded; ordinary 2,695 (including 12 skipped), scaffold 22, dep-off 65 | ✓ PASS (saved result) |
| Final local browser diagnostics | `BROWSER-DIAGNOSTICS-AFTER-REVIEW.json` and sanitized ZIP | Seven native cases recorded; passing/failing, startup/discovery, SIGTERM, and cleanup outcomes retained | ✓ PASS (saved result) |
| Remote distribution reference | `git ls-remote --exit-code origin refs/heads/evidence/phase255-replay-6d098e9bee2d28b0d88d` | Ref resolves to `52d2f3611fa195042d52ab0ef9dba64e4d75a2eb`; no package fetch was performed | ✓ PASS |

### Test Quality Audit

| Test group | Linked requirement | Disabled tests | Expected-value and assertion check | Verdict |
|---|---|---:|---|---|
| Replay and report tests | CIMEAS-03 | None found | Current replay runs the pinned saved-input calculation; semantic checks assert literal sources, costs, zero pairs, null statistics, and open speed status | ✓ PASS |
| Browser selection and Mix receiver tests | CIDX-01 | None found | Exact spec/project identities and native receiver identities are asserted against the documented command paths | ✓ PASS |
| Command recorder, bundle, and canary tests | CIDX-02 | None found | Real subprocess outcome/streams and verified staged archive contents are checked; current workflow regression exercises report capture and path rejection | ✓ PASS |

The requirement-linked test scan found no skipped tests. Test writes found by the scan create temporary input/output fixtures; expected report values are asserted as literals or against pinned saved records, not generated from the behavior under test.
## Probe Execution

No phase-declared probe paths or conventional `scripts/*/tests/probe-*.sh` probes were found.

## Requirements Coverage

| Requirement | Source plan | Description | Status | Evidence |
|---|---|---|---|---|
| CIDX-01 | 255-03, 255-04, 255-06, 255-07 | Documented local commands match updated CI checks and retain `mix ci`. | ✓ SATISFIED | Plan03 SUMMARY now records `requirements-completed: [CIDX-01]`; this verification relies on the actual focused browser-selection and Mix receiver-identity tests, documentation, and saved native `mix ci` evidence for the commands, prerequisites, and seven legs. |
| CIDX-02 | 255-02 through 255-07 | Failures identify what failed and how to reproduce, with logs/traces and applicable seeds. | ✓ SATISFIED | Current named process-recorder and safe-bundle tests pass; native Mix/browser records retain actual identities, commands, outcomes, and seeds; the hosted failure artifact was retrieved and verified. Cancellation remains partial and explicitly lists its missing files. |
| CIMEAS-03 | 255-01, 255-07 | Replay final comparison with outcomes, sample size and limitations. | ✓ SATISFIED | Current package replay and report semantic test pass; the hash-bound remote record proves prior clean-checkout replay. The actual result is `insufficient_data`, with outcomes, costs, sample size, cache conditions, and limitations disclosed. |

No requirement mapped to Phase 255 in `REQUIREMENTS.md` is orphaned. `CIMEAS-03` is satisfied because the requirement is faithful replay/reporting, including an insufficient-data outcome. `CISPEED-01/02` remain open: zero successful matched pairs means neither target has passed, and no independent verification exists to close those measured-outcome requirements.

## Prior Phase Context

Phase 252's verification report is historical and passed on 2026-10-13; Phase 253's verification report is historical and passed on 2026-10-23. There is no Phase 254 verification report in the phase directory. Its saved measurement is terminal `insufficient_data`, and the speed goals remain open. Those records are kept separate from this Phase 255 verdict: this phase verifies faithful replay/reporting, not Phase 254 speed acceptance.

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---:|---|---|---|
| — | — | No debt markers or stub implementation found in the 48-file final source scope. Grep matches for intentional `return null` fallbacks and the workflow variable `TODO_DATE` are not empty implementations or debt markers. | ℹ️ INFO | No blocker. |

## Human Verification Required

None. Local execution, failure reproduction, hosted artifact outcomes and the clean-checkout replay all have deterministic evidence. No visual or product UI change is in scope.

## Gaps Summary

No Phase255 goal or mapped requirement is missing. The replay correctly cannot establish a speed improvement: one baseline failed, one candidate succeeded, there are zero comparable successful pairs, and median/p95 are null. `CISPEED-01/02` remain open. The hosted cancellation artifact is partial and records both missing files. The current workflow addition has a passing local regression, but the latest main CI run does not include its dirty bytes and is not cited as evidence for them.

### Decision Coverage

All trackable CONTEXT.md decisions are honored by shipped artifacts (17/17; non-blocking coverage check).

---

_Verified: 2026-11-10T20:36:21Z_  
_Verifier: the agent (gsd-verifier)_
