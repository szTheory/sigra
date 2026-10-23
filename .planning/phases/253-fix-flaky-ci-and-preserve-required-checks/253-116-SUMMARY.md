---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "116"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, hosted-verifier, run-identity, ledger-binding, r10]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-113 halted R9 canary records (EVIDENCE-R9 a3ca8cc0..., real run 38906314106), 253-111 FREEZE-R9, 253-112 R9 reconciliation contract, 253-110 R9 hermetic-vs-live audit"
provides:
  - "Run-name identity rule (expected_run_title / require_run_title) used by verify_scenario and verify_separate_verifier"
  - "Canary receipt-to-ledger binding (verify_canary_bindings) on the replan path: run, discovery, dispatch scenario, jobs, artifacts, archive raw digest and run_attempts"
  - "R10 preservation checklist (62 lines)"
  - "RED receipts for both fixes, captured on the unfixed verifier"
  - "R10 hermetic-vs-live audit record (72 rows, zero gaps); the checker now reads it"
affects: ["253-117", "253-118", "253-119", "253-120", "253-121", "253-122", "253-123", "253-124"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PRESERVATION-R10.sha256
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-RUN-IDENTITY-RED-R10.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-CANARY-BINDING-RED-R10.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R10.json
  modified:
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
    - scripts/ci/ci-hermetic-live-audit.test.py
key-decisions:
  - "Run identity: display_title must equal f'{FIXTURE_NAME} / {scenario} / {id}-{run_attempt}' for the run's own id and attempt; name must be the bare FIXTURE_NAME or that same title, and a templated name must equal display_title. Exact strings, no strip or casefold. The separate verifier uses scenario literal 'verifier'."
  - "Binding runs only on the replan path (--mode canary full scenario, sources, matrix and verify_canary_matrix), after verify_transport_v2 and before verify_sources/verify_scenario. Legacy mode, verify_sources on a compact matrix, verify_transport_v2 and the PR path are unchanged."
  - "The binding compares the final artifact_zip hop's raw_observation_sha256 and response_bytes, never the scrubbed binary body."
  - "The dispatch bound to a run is the last POST dispatch before that run's discovery; it must be HTTP 204 (as the plan states), and its transmitted request-body scenario must equal the scenario."
requirements-completed: []
estimate: {tokens: 46000, tasks: 3}
actuals:
  tokens: 33300
  tasks: 3
  commits: 6
commits: 6
plan_head_before: cefbe6ceee18032e47ec5befebdf6c7913bd7228
plan_head_after: cf5448d7f3efc721a6927311ca9bb970fdca0b2f
run_identity_fix_commit: e3ed66e913b88bfbd4c10fde153acbfae8bed82c
binding_fix_commit: 9f796f4b5d9a5ea1c84196a4d84c7489cd42c1e2
duration: 30min
completed: 2026-10-16
status: complete
---

# Phase 253 Plan 116: run-name identity and canary ledger binding (R10) Summary

**The verifier now accepts the run identity GitHub actually returns: name and display_title both set to the fixture's run-name for the run's own scenario, id and attempt. This was proven RED-first on the committed R9 bytes of run 38906314106. Every canary receipt and the separate verifier receipt are now also re-bound to the measured ledger, so the 253-113 receipt-only control is refused. Both offline full gates pass with both rules active, and no GitHub requests were made.**

## Performance

- **Duration:** about 30 min (first commit 14:58Z, last task commit 15:13Z, full gates done about 15:24Z)
- **Tasks:** 3/3
- **Files:** 4 created, 3 modified

## Task commits

1. **Task 1 (tracer): R10 checklist, then the run-name identity rule**
   - `c0b63132f` docs(253-116): R10 preservation checklist
   - `d7a1b1ea2` test(253-116): run-name identity on GitHub's real run bytes (RED)
   - `e3ed66e91` fix(253-116): accept the GitHub run-name as the canary run identity (**run_identity_fix_commit** `e3ed66e913b88bfbd4c10fde153acbfae8bed82c`)
2. **Task 2: canary receipt-to-ledger binding**
   - `d1a839dfd` test(253-116): canary receipt-to-ledger binding (RED)
   - `9f796f4b5` fix(253-116): bind canary run, jobs, artifacts and archive to the measured ledger (**binding_fix_commit** `9f796f4b5d9a5ea1c84196a4d84c7489cd42c1e2`)
3. **Task 3: R10 audit record and the full offline gates**
   - `cf5448d7f` docs(253-116): R10 hermetic-vs-live audit record

Both fix subjects appear exactly once in the repository; each was checked as absent before its commit.

## Task 1: R10 preservation checklist and run-name identity

### Preservation checklist

`253-LOAD-RECOVERY-PRESERVATION-R10.sha256` has 62 lines:
- all 39 PRESERVATION-R9 lines, unchanged and in order;
- PRESERVATION-R9 itself;
- the seven 253-107..113 SUMMARYs;
- the five R9 freeze-line records;
- the ten halted 253-113 records.

Every value matched its pinned hash, and none of the new paths was already in R9. `shasum -a 256 -c --quiet` returns rc 0. Positive control: a scratch copy with one hash altered returns rc 1.

### RED (`253-LOAD-RECOVERY-RUN-IDENTITY-RED-R10.json`, produced on c0b63132f)

The suite ran 103 tests and exited 1, with 10 failures and 7 errors (17 failing tests):
- **Real-shape positives:** `verify_scenario` on EVIDENCE-R9 full-pass failed with `run workflow identity mismatch`.
- **Fixtures moved to the real shape:** every existing test whose fixture now uses the real shape failed with that same message: 6 HostedGate/RegisteredFixture/V2 tests and 2 subtests.
- **Bare-name negatives:** the two negatives (display_title missing, and display_title for another scenario) were accepted, giving `VerificationError not raised`.
- **Separate verifier positive:** failed at the old :836 check.
- **Missing helper:** three direct-helper tests (R8 poll, run 38347679431, bare name with bound display_title) errored with `AttributeError`, because `require_run_title` did not exist yet.
- **CLI:** `--mode canary --scenario full-pass --evidence EVIDENCE-R9` exited 1 with `hosted-gate-verify: FAIL: run workflow identity mismatch`.

The real-shape positives did fail on the unfixed verifier, so the plan's halt-if-they-pass check did not fire.

### GREEN

- **Suite:** 103 tests, OK.
- **CLI on EVIDENCE-R9:** exits 0 with `canary_scenario_verified`, `run_id` 38906314106 and `transport_verified`. EVIDENCE-R9's sha256 is still `a3ca8cc0…`.
- **Tracer gate:** Task 1's full `<verify>` was re-run, with rc 0.

### New tests (RunIdentityTests)

- **Real-shape positives:**
  - `test_live_r9_real_full_pass_run_is_accepted` (receipt, plus the run object decoded from ledger seq 27);
  - `test_live_r9_cli_accepts_the_real_full_pass_evidence_offline`;
  - `test_live_r8_real_run_poll_title_is_accepted` (38791286863);
  - `test_live_first_canary_run_title_is_accepted` (38347679431);
  - `test_bare_name_with_bound_display_title_is_accepted`.
- **`test_every_wrong_title_is_refused_with_the_identity_message`:** 13 one-field negatives built from the real R9 run object, each refused with `run workflow identity mismatch`:
  - scenario docs-only in the title;
  - run id 38906314107;
  - attempt 2;
  - a ` / x` suffix;
  - a trailing space;
  - the prefixes `Phase 253 Gate Canary2 / ` and `CI / `;
  - name templated with display_title bare;
  - name templated with display_title for another run;
  - display_title missing;
  - name None;
  - bare name with display_title missing;
  - bare name with display_title for another scenario.
- **`test_unchanged_run_checks_keep_refusing`:** workflow_id, path, head_branch, head_sha, event and conclusion are each refused.
- **`test_separate_verifier_requires_its_own_verifier_title`:** accepts the verifier title and the bare name, and refuses a full-pass title and a title for another verifier run id with `run workflow identity mismatch`.

### Source change

- **verify_scenario:** only the `run.get("name") == FIXTURE_NAME` clause was removed, and a `require_run_title(run, scenario)` call was added after the unchanged workflow_id/path check (same message).
- **verify_separate_verifier:** the name clause was removed from the combined check, and `require_run_title(run, "verifier")` was added after it.
- **Unchanged:** FIXTURE_NAME and the `expected.workflow_name` check are byte-identical.

## Task 2: canary receipt-to-ledger binding

### RED (`253-LOAD-RECOVERY-CANARY-BINDING-RED-R10.json`, produced on e3ed66e91)

The suite ran 108 tests and exited 1, with 8 failures and 2 errors.
- **Tampers accepted:** all seven tampers gave `VerificationError not raised`. Each tamper first passed `verify_transport_v2` inside the test (the positive control that only a binding could refuse it).
- **CLI on the 253-113 control:** exited 0 with `canary_scenario_verified`. This is recorded under `red_cli_observation`, so the `entries` keep the nonzero-exit schema.
- **Direct binding tests:** the two direct `verify_canary_bindings` tests errored with `AttributeError`.

### GREEN

- **Suite:** 108 tests, OK.
- **Task 2 `<verify>`:** rc 0. It includes the jq-tampered CLI run, which exits 1 with `canary receipt not bound to the measured ledger`, and both quick smokes.
- **Quick smokes:** `--ref-pair r9 --seed-r8-refs --stop-after full-pass` passed hermetic and with `--live-policy`, both with synthetic true. Requests by category for each: publication 18, preflight 5, dispatch 1, run_discovery 1, pre_watch_rate 1, terminal_polls 3, attempt_jobs 1, artifact_metadata 1, artifact_downloads 2.

### New tests (CanaryBindingTests)

- **`test_live_r9_real_full_pass_receipt_binds_to_its_ledger`:**
  - `replan_result` passes;
  - the binding reports dispatch 24, discovery 25, polls [27], jobs [28] and artifacts [29];
  - the archive is hops [30, 31], artifact 12048052856, 933 bytes, raw digest `6ff02bc7…`.
- **`test_tampered_receipts_and_ledgers_are_refused_with_the_binding_prefix`:** seven tampers, each refused with the binding prefix:
  - receipt run.name set to the bare FIXTURE_NAME (the exact 253-113 control);
  - a job's runner_name changed;
  - an artifact's created_at changed;
  - the artifact_zip hop-0 URL changed to name artifact 12048052857 (url_sha256 recomputed);
  - the final hop's raw_observation_sha256 changed;
  - the dispatch's transmitted scenario changed to docs-only (request body, sha256s and input metrics recomputed);
  - the run poll removed (sequences and request_count recomputed).
- **`test_cli_refuses_the_253_113_receipt_only_edit`.**
- **`test_the_separate_verifier_receipt_binds_to_its_own_ledger_rows`:**
  - EVIDENCE-R9 is extended with a modeled verifier dispatch, discovery, poll and jobs (seq 32-35), and they bind;
  - refused: an edited verifier run, an edited verifier job, an edited run_attempts entry, and a verifier dispatch that transmitted full-pass.
- **`test_legacy_mode_and_verify_sources_on_a_compact_matrix_are_unchanged`:** `verify_canary_bindings` is replaced by a function that raises. `verify_sources` on a v2 compact-matrix-shaped document without `transport_ledger` still verifies all six scenarios, and legacy-mode CLI still passes.

## Edited existing tests (no assertion weakened)

- **`fixture()`:** the run moves to GitHub's real shape. `name` and `display_title` both become `Phase 253 Gate Canary / full-pass / 901-1`; before, name was bare and there was no display_title.
- **`scenario_fixture()`:** the run's `name` and `display_title` become `Phase 253 Gate Canary / {scenario} / {run_id}-1`.
- **`HostedGateVerifierTests.test_final_matrix_checks_separate_verifier_and_recounts_executions`:** the separate verifier run gets `name` and `display_title` `Phase 253 Gate Canary / verifier / 999-1`.
- **`DryRunWindowGuardTests.test_canary_matrix_result_on_a_dryrun_window_is_synthetic`:** a stub for `verify_canary_bindings` was added next to the other stubs, because `verify_canary_matrix` now calls the binding.

## Task 3: R10 audit record and the full offline gates

### Audit record

`253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R10.json`:
- schema `sigra.phase253.hermetic-live-audit/v1`, with `audit_head` `9f796f4b5d9a5ea1c84196a4d84c7489cd42c1e2`;
- the 71 R9 rows, ids unchanged; 19 verifier rows had their `line` refreshed (verifier-677, -950, -951, -968, -969, -991, -1014, -1015, -1021, -1369, -1403, -1462, -1482, -1634, -1652, -1664, -1674, -1725, -1729);
- match_counts unchanged: transport 25, canary.sh 6, pr-proof 2, publication 8, verifier 28.

**New matcher sites from Tasks 1-2: none.** The identity helper and the binding contain no line that the matcher selects.

One reasoned supplementary row was added, `verifier-1655-supplementary`, for the binding's `view = api_view(evidence)` (occurrence 2). That call is the binding's hermetic/live branch. Its live coverage is `test_live_r9_real_full_pass_receipt_binds_to_its_ledger` plus `test_api_view_returns_live_evidence_unchanged_and_rewrites_only_hermetic_evidence`, with 0 gap rows. The R9 record still hashes to `9bb3e935…`. Only `AUDIT_REL` changed in the checker.

### Task 3 `<verify>` (rc 0, under caffeinate)

| Check | Result |
|---|---|
| ci-hermetic-live-audit.test.py | 14 OK |
| ci-hosted-gate-verify.test.py | 108 OK |
| ci-hosted-transport.test.py | 59 OK |
| ci-git-publication.test.py | 76 OK |
| ci-gate-canary-flow.test.py | 22 OK |
| ci-gate-canary-recovery.test.py | 5 OK |
| ci-gate-canary.test.sh | passed |
| ci-pr-proof.test.sh | 59 OK |

| Full gate | Status | Notes |
|---|---|---|
| `--ref-pair r9 --seed-r8-refs` (hermetic) | passed | synthetic true, seeded_r8_refs_changed false, all six scenarios, verifier passed (matrix mode with the separate-verifier binding active) |
| same with `--live-policy` | passed | same results; authorization api_with 85, api_without 0, blob_with 0; shim_refusals 0 |

Requests by category, identical in both gates (93 total):

| Category | Requests |
|---|---|
| publication | 19 |
| preflight | 5 |
| dispatch | 7 |
| run_discovery | 7 |
| pre_watch_rate | 7 |
| terminal_polls | 18 |
| attempt_jobs | 7 |
| artifact_metadata | 6 |
| artifact_downloads | 10 |
| failure_logs | 6 |
| cancellation | 1 |

The remaining `<verify>` checks also held:
- `--require-target-disposition` exits 0 and `--require-target-accepted` exits 3;
- v1 and r2-r9 reconcile `--check-only` exit 0;
- both preservation checklists return rc 0.

## Deviations from Plan

1. **Some RED tests failed with AttributeError, not the identity message.** In Task 1, three direct-helper tests and the separate-verifier positive failed with `AttributeError` or the old :836 message. In Task 2, the two direct-binding tests failed with `AttributeError`. The receipts record this as observed. The planned failures, identity mismatch and tampers accepted, come from the other real-shape tests, the fixture-moved tests and the CLI. Each receipt's `semantic_assessment` states this.
2. **The binding RED CLI observation is outside `entries`.** It exited 0, which is the RED signal (the tamper was accepted). It is stored in `red_cli_observation` so the `entries` keep Task 1's nonzero `exit_code` schema.
3. **Tests added beyond the plan's list:**
   - the CLI end-to-end positive on EVIDENCE-R9;
   - two extra bare-name negatives;
   - the CLI refusal of the 253-113 control;
   - a modeled separate-verifier binding test (positive plus four tampers).

   All are tighter than planned, none looser.
4. **One supplementary audit row.** Task 1-2 created no new matcher sites, so this row is optional. It was added so that the binding's api_view branch is audited.
5. **The separate verifier's message changed for title-only defects.** It is now `run workflow identity mismatch` (from `require_run_title`), where it used to be the combined `separate hosted verifier run identity or conclusion mismatch`. Every other condition in that combined check, and its message, is unchanged.

**Not done by design:** the STATE, ROADMAP and REQUIREMENTS writer steps were skipped, per the orchestrator's hard constraints. `.planning/config.json` (sha256 `8e312f6c…`) and `state.json` (70229 bytes, `e45278c2cee0…`) are untouched.

## Remaining gaps / handoff

- **CIREL-02 stays open.** Run 38906314106 is used only as a real-shape fixture, never as acceptance evidence. Full Phase 253 verification stays not_started.
- **FREEZE-R9 no longer matches the tree.** It cannot validate it, because scripts/ci changed. The R10 freeze is cut by 253-120.
- **For 253-117, which owns the fakes:**
  - `ci-gate-canary-dryrun.py:441` still writes the bare run `name`. That is accepted, because its display_title (line 442) is the exact templated title. The fake should move to the real shape, name == display_title.
  - The binding now requires every receipt to equal its ledger body. It also requires the last dispatch before a discovery to be HTTP 204, with the transmitted scenario. The run must be listed by a 200 discovery before its first poll, and exactly one run_attempts entry must exist per run. Every listed fake passes today.
  - The dry-run test suite (34-44 min) was not run here, as the plan allows.
- **Possible live risk (halt-never-loosen).** The driver accepts dispatch 202 or 204, but the binding requires 204, as the plan states. Real GitHub returned 204 in R9, and the fakes send 204.

## Known Stubs

None.

## Self-Check: PASSED

- All four created files and the three modified files exist. `git status` shows only ` M .planning/config.json`.
- All six commits (`c0b63132f`, `d7a1b1ea2`, `e3ed66e91`, `d1a839dfd`, `9f796f4b5`, `cf5448d7f`) are ancestors of HEAD.
- The checklist commit precedes the identity RED, which precedes the identity fix. The binding RED precedes the binding fix.
- No `scripts/ci/__pycache__` remains.
