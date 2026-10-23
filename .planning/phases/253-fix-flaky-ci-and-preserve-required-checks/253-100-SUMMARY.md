---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "100"
subsystem: ci-reliability / hosted canary driver
status: complete
tags: [ci-reliability, load-recovery, canary-driver, route-mapping, errexit, r8]
requirements: ["CIREL-02"]
dependency_graph:
  requires: ["253-95", "253-96"]
  provides: ["braced canary route captures", "server-parent check-source rule (D-12 decision)", "success-returning dispatch_scenario", "route/check-source/errexit offline tests"]
  affects: ["253-101", "253-102", "253-104", "253-105"]
tech-stack:
  added: []
  patterns: ["real-function extraction + recording stub transport (no network)", "RED receipt committed before fix"]
key-files:
  created:
    - scripts/ci/ci-gate-canary-flow.test.py
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-ROUTES-RED-R8.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CHECK-SOURCE-DECISION-R8.json
  modified:
    - scripts/ci/ci-gate-canary.sh
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
decisions:
  - "D-12 check source: Jon chose server-parent-identity (verbatim label 'server-parent-identity (Recommended)', no note). Canary reads native check runs from the frozen server parent, identity only; success on the PR head stays in the PR family."
  - "The canary verifier path takes the check source from the publication receipt that the evidence names (.publication.receipt_path/.receipt_sha256), re-hashed. No new evidence field is needed for the receipt."
metrics:
  started: not recorded (resumed after the Task 2 checkpoint)
  completed: 2026-10-15T12:58:34Z
  tasks: 3
  files: 6
estimate: {tokens: 34000, tasks: 3}
actuals:
  tokens: 16000
  tasks: 3
  commits: 5
plan_head_before: 9db1b5dd1cc3d3a03c4109be50c786035c1e1880
plan_head_after: 2903b0b235af765e756198fcf4995295e0482444
---

# Phase 253 Plan 100: Canary route mapping, check-source decision and errexit fix Summary

This plan fixes three defects in the canary driver, each with a test that failed first. The ten unbraced `$BASH_REMATCH[1]` captures are now braced; these were the 253-97 halt cause. Native check sources are now read from the frozen server parent, as Jon decided (identity only). `dispatch_scenario` now ends with an explicit `return 0`. All tests run offline through stubs: zero GitHub requests, no push and no fetch.

## Commits

| Step | Commit | Message |
|---|---|---|
| Task 1 RED (test + receipt) | aefa86b5fedf4cf5aeb3d1de0f677d166b5240e7 | test(253-100): canary route mapping through a recording stub transport (RED) |
| Task 1 fix | 1e85c409c91c3c4a7e56a25cb45f65b618879c95 | fix(253-100): brace canary route capture expansions |
| Decision record (alone) | b9fca6eb1601513a6940614f70be6b4f87d9d082 | docs(253-100): record Jon's check-source decision (server-parent-identity) |
| Commit A | ff8023d3ac3b20a66ccfaeedddda9b7c0ed22362 | fix(253-100): check source per the decision (server-parent-identity) |
| Commit B | 2903b0b235af765e756198fcf4995295e0482444 | fix(253-100): end dispatch_scenario with an explicit success return |

The ledger base is 9db1b5dd1, and 5 commits were measured before this SUMMARY commit.

## Decision (Task 2)

- **Option chosen:** `server-parent-identity`. Jon picked it in an AskUserQuestion prompt; the verbatim label was "server-parent-identity (Recommended)". He added no note.
- **Record:** `253-LOAD-RECOVERY-CHECK-SOURCE-DECISION-R8.json`, committed alone in b9fca6eb. It contains the three options as presented and the code/config evidence.
- **Evidence confirmed offline:**
  - ci.yml:32-35 runs on push only for main and release-please--branches--main, and on pull_request only for base main.
  - Only three workflows have a push trigger: ci.yml, release-please.yml (main) and playwright-github-pages.yml (main, paths-filtered). None matches gsd/\*.
  - In ci-hosted-gate-verify.py, the check-run URL was tied to `candidate_sha` at :269-274 and :361-364, and success was required at :310.
  - The PR family re-runs the five-name rule on the PR head with success required (:1214-1225, using `_view_for_checks` :932-944).

## Task 1: route mapping (RED, then GREEN)

- **Harness:** `scripts/ci/ci-gate-canary-flow.test.py` pulls the real `api_get`, `download_no_follow`, `transport_call`, `request_category` and `record_budget` out of the script text by regex. It runs them under bash with a stub transport module that records each request envelope and returns a canned 200 reply. `gh` and `curl` on PATH are recorders that fail the test if called. The file fails if a function is not found or if no `test_route_*` test is discovered. It has one exact-envelope test for each of the 10 GET routes and 2 download routes, plus a coverage-set test.
- **RED:**
  - Ran on 9db1b5dd1 (the unfixed script): 14 tests, 9 failures, exit 1.
  - `check_runs` received `commit_sha` = `commits/84ebcea6…/check-runs?per_page=100[1]`, and `get_ref` received `branch` = `git/ref/heads/gsd/253-replan-fixture[1]`.
  - The numeric routes and both downloads failed with `jq: invalid JSON text passed to --argjson`.
  - The GSD `tdd-red-evidence` classifier returned RED_EVIDENCE_OK (target_test_failed, target `test_route_check_runs`).
  - Semantic check: every failure came from the real extracted functions, either as assertion mismatches or as jq errors captured from stderr. None was an import error or a harness crash.
  - The receipt is `253-LOAD-RECOVERY-CANARY-ROUTES-RED-R8.json` (sha256 44ef9696…1dae4), committed in aefa86b5 before the fix.
- **GREEN:**
  - All ten sites are braced (:550, :551, :553, :554, :555, :556, :557, :558, :604, :606).
  - The diff only changes quoting: when the braces are stripped back out, each of the 10 lines matches its old version.
  - Flow 14/14, `ci-gate-canary.test.sh` passed, recovery 5/5.
  - Task 1's `<verify>` block, run verbatim, exited 0.

## Task 3 Commit A: check source (server-parent-identity)

- **Script (`ci-gate-canary.sh`):**
  - `FROZEN_SERVER_PARENT_SHA` is read from the freeze's `identity.server_parent_sha`, and `CHECK_SOURCE_SHA` is set from it.
  - Both places that create evidence write `expected.check_source_sha` and `check_source_role: "server_parent"`.
  - Resumed evidence must carry the same check source as the freeze, otherwise the existing "does not match this new recovery freeze" refusal fires.
  - The preflight refuses a missing or malformed source before any request. It then reads `commits/$CHECK_SOURCE_SHA/check-runs`.
  - For each required name, the preflight requires exactly one run with `head_sha` equal to the source, an app id > 0, a non-empty slug and an https `html_url`. It no longer requires completed/success.
  - Category, caps, routes, ref names and the request count are unchanged.
- **Verifier (`ci-hosted-gate-verify.py`):**
  - New `canary_check_source` and `verify_canary_checks`. `--mode preflight`, `--mode canary` and `verify_canary_matrix` now go through `verify_canary_checks`.
  - That path requires `check_source_role == "server_parent"` and a well-formed `check_source_sha` that differs from the candidate.
  - It requires the named publication receipt to be in the checkout, re-hashed to `.publication.receipt_sha256`, with `server_parent_sha` equal to the check source and `candidate_sha` equal to the candidate.
  - It binds the check-run URL to that SHA, keeps every five-producer, app and source identity check, and records conclusions without requiring success.
  - `hydrate_effective_checks` and `verify_effective_checks` default to `check_source=None`, which keeps the old behaviour for the PR family. `verify_pr_family` and `_view_for_checks` are unchanged.
- **RED (on the Task 1 driver and the unchanged verifier):**
  - Flow suite: 18 tests, 7 failures. The preflight read the candidate, a non-success run was refused, the malformed source was not refused before requests, and the https and head_sha identity checks were missing.
  - Verifier `CanaryCheckSourceTests`: 21 subtest failures across the 5 new canary tests. The PR-family pin passed, as intended.
  - Cases rejected after the fix: candidate URL, wrong SHA, unbound, mismatched or escaping receipts, four or six producers, a foreign app, a missing or http source, a missing slug, and the CLI preflight given candidate-bound evidence.
- **GREEN:** flow 18/18, verifier 72/72 (PR-family tests unedited; the new test shows a PR view without five successful checks is still rejected), recovery 5/5, shell suite passed, transport 26/26, publication 59/59, ci-pr-proof 34/34.

## Task 3 Commit B: errexit

- **Tests:**
  - `dispatch_scenario` is extracted and run under `set -euo pipefail` with its collaborators stubbed. It must return 0 for full-pass, docs-only, actual-failure, missing-seam, unexpected-skip (each concluding failure) and cancelled (concluding cancelled).
  - It must still fail with "negative source unexpectedly concluded success" when a negative scenario concludes success.
  - Malformed endpoints must fail closed with "no typed HTTP route" and no transport call: 39-hex sha, uppercase sha, non-numeric run id, non-numeric workflow id, extra query key, unknown query and unknown path. Malformed download URLs must fail with "download URL did not match an approved typed route".
- **RED (on the commit-A driver):** 22 tests, 6 failures, all in the errexit test (one per expected outcome, `1 != 0` with empty stderr, which is the silent errexit). The malformed-endpoint tests already passed and now pin existing behaviour.
- **GREEN:** the guard line now ends with an explicit `return 0`, so only the guard can fail. Flow 22/22.

## Audit (unbraced shell-array element expansions)

- **Command:** run under bash with `globstar nullglob` over `scripts/**/*.sh .github/**/*.sh test/**/*.sh` (142 files). A standard-library python scanner collects every array name the scripts declare (`declare/local/typeset/readonly -a`, `name=(`/`name+=(`, `read -a`, `mapfile`/`readarray`), 73 names in total. It adds BASH_REMATCH, PIPESTATUS, FUNCNAME, BASH_SOURCE, BASH_LINENO and BASH_ARGV, then reports `$NAME[` outside single-quoted text, comments and quoted-delimiter heredoc bodies, treating `$(` inside double quotes as a new unquoted context.
- **Positive control:**
  - Run on `git show aefa86b5:scripts/ci/ci-gate-canary.sh` alone, it finds exactly 10 sites (:550, :551, :553-:558, :604, :606).
  - Run repo-wide with that RED file substituted for the current one, it again finds 10.
- **Result at HEAD 2903b0b23:** 0 sites (exit 0).
  - The first scanner pass flagged `$runs[` at scripts/ci/ci-run-metrics.sh:2034-2035. Those are jq variables (`as $runs`) inside a `"$(jq '...')"` program, which is the expected kind of false positive.
  - I fixed the scanner to handle that nesting and re-ran both controls before accepting the 0.
  - A raw grep that includes quoted text matches 108 lines; all of them are jq programs.
- **publish_fixture_ref observation (recorded, not changed):**
  - With `allow_missing` (ci-gate-canary.sh:435), `api_get` treats a 404 from `get_ref` as success. The if-branch then fails closed on the identity check ("remote fixture ref exists with a different identity; refusing to update it", :436).
  - That is fail-closed, and it is not on the R8 path, because `--publish-only` creates both refs first.

## Verification

- **Task 3 `<verify>` block (run verbatim under bash):** exit 0. That covers all seven offline suites, the v1/r2/r3/r4/r5/r6/r7 reconcile `--check-only` commands, the decision record committed alone, no unbraced captures, the R7 evidence sha, the config.json sha, the state.json byte count, and a clean tree apart from config.json.
- **Disposition predicates:** `--require-target-disposition` exits 0 and `--require-target-accepted` exits 3. CIREL-01 stays partial.
- **Byte preservation:**
  - Every pre-existing md, json, yml and mjs file in the phase directory has the same sha256 as before this plan started. The only additions are the two R8 records.
  - The R7 pins match: approval fb6c554c, allocation 72284acc, evidence e5be2150, ledger 48587280, receipt 3aa75308, freeze f608a445, publication manifest 6813630f, readback-RED d745038c, workflow 3c31cb72, R7 contract 8b077547, and 253-97-SUMMARY de6b8ee0.
  - config.json is still 8e312f6c… and was never staged. state.json is still 70229 bytes.
- **Not run:** no state, roadmap or requirements writer verbs were run, per the phase 253 hard rules (this overrides the execute-plan state steps).
- **R7 freeze:** it no longer validates the current tree. That is expected and terminal: this plan changed `ci-gate-canary.sh` and `ci-hosted-gate-verify.py`, which that freeze binds.

## Deviations from Plan

None that change scope.
- I reused the publication receipt the evidence already names (`.publication.receipt_path` and `.receipt_sha256`, written by `--publish-only`) as the "publication receipt the evidence names". No new field was needed.
- The preflight also checks `head_sha == check_source_sha` and an https source. This is stronger, fail-closed producer-identity binding within the decided option.
- Commit A puts its tests and the fix in one commit; its RED counts are in the commit message and above. The plan says only "Commit A ... write its tests, observe RED and record the counts, implement".

## Deferred / Remaining gaps

- 253-101 owns two fixes not done here: preflight running on every invocation, and api_get returning the transport status without marking the evidence halted.
- The 253-91 deferred review findings are recorded here and not acted on:
  - approvals have no consumed-once marker;
  - `require_listed` does not count uses;
  - an interrupted PR collection needs a new evidence path;
  - later publication-category rows are not pinned.

  None is folded in. The fail-closed halt marking added in 253-101 closes the practical re-dispatch path that the uncounted `require_listed` would otherwise leave open.
- Full Phase 253 verification stays not_started. Offline tests are implementation checks, not hosted proof.

## Known Stubs

None. The stubs in the test file are test doubles for offline execution.

## Threat Flags

None. No new network endpoint or auth path was added. The verifier change narrows the canary rule to a bound, re-hashed source.

## Self-Check: PASSED

- FOUND: scripts/ci/ci-gate-canary-flow.test.py, 253-LOAD-RECOVERY-CANARY-ROUTES-RED-R8.json, 253-LOAD-RECOVERY-CHECK-SOURCE-DECISION-R8.json
- FOUND on HEAD: aefa86b5, 1e85c409, b9fca6eb, ff8023d3, 2903b0b2
