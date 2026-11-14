---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "125"
subsystem: ci-reliability
status: complete
gap_closure: true
tags: [ci-reliability, load-recovery, hosted-transport, redirect-policy, results-receiver, r11]
requirements: [CIREL-02]
requirements-completed: []
requires:
  - phase: 253-122
    provides: the halted R10 canary; R10 ledger sequence 47 (run_logs hop 0, 302 to results-receiver.actions.githubusercontent.com) as the real-shape fixture
  - phase: 253-116
    provides: the RED-first transport/verifier fix pattern and the RED receipt shape
  - phase: 253-118
    provides: the response-shape class in the hermetic-vs-live audit
provides:
  - RESULTS_RECEIVER_HOST admitted by exact name only as hop 1 of the run_logs route (transport) and in the live host rule (verifier)
  - 253-LOAD-RECOVERY-PRESERVATION-R11.sha256 (87 lines: the 62 R10 lines plus 25 R10-round pins)
  - two RED receipts (-TRANSPORT-RESULTS-RECEIVER-RED-R11, -LIVE-HOST-RED-R11)
  - 253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R11.json, and the checker now reads it
affects: [253-126, 253-127, 253-128, 253-131]
tech-stack:
  added: []
  patterns: ["route- and hop-scoped exact-host admission", "real-shape positive control read from the committed ledger at test time", "layered RED (allocation layer, then hop rule alone)"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PRESERVATION-R11.sha256
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-TRANSPORT-RESULTS-RECEIVER-RED-R11.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-LIVE-HOST-RED-R11.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-HERMETIC-LIVE-AUDIT-R11.json
  modified:
    - scripts/ci/ci-hosted-transport.py
    - scripts/ci/ci-hosted-transport.test.py
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py
    - scripts/ci/ci-hermetic-live-audit.test.py
key-decisions:
  - "results-receiver is admitted only by exact string, on run_logs, at hop_ordinal 1 (type(hop) is int, so True is refused), and only when it is in download_hosts. The transport and the verifier apply the same rule."
  - "The pre-R11 predicate (pipelines or productionresultssaN blob) is kept unchanged for every route, run_logs included. The change only adds; narrowing run_logs was not requested, and the fakes and 253-128 still depend on run_logs to the blob host."
  - "The PR transport host check (verify_pr_transport, allocation download_hosts) is not touched. The R11 PR allocation must not list results-receiver, because PR families never call run_logs, so the weaker deferred rule (253-111 R3) cannot admit it."
  - "The shape-run_logs audit row stays justified. Hop 0 is now a real sample (seq 47); hop 1 is unobserved until 253-127."
coverage:
  - id: D1
    description: "seq-47 real-shape chain followed with no Authorization off api.github.com; lookalike, port, scheme, userinfo, fragment, off-route, hop-2 and absent-host negatives refused before their socket"
    requirement: "CIREL-02"
    verification:
      - kind: integration
        ref: "scripts/ci/ci-hosted-transport.test.py#LivePolicyRedirectTests.test_live_r10_seq47_results_receiver_location_is_followed_without_authorization"
        status: pass
    human_judgment: false
  - id: D2
    description: "verify_live_transaction_host accepts the seq-47 hop-1 transaction only on run_logs hop 1; blob (seq 31) and pipelines are unchanged; the step-1 R10 evidence still verifies offline"
    requirement: "CIREL-02"
    verification:
      - kind: unit
        ref: "scripts/ci/ci-hosted-gate-verify.test.py#LiveResultsReceiverHostTests.test_live_r10_seq47_results_receiver_hop_is_a_trusted_run_logs_hop"
        status: pass
    human_judgment: false
  - id: D3
    description: "R11 audit record complete with zero gap rows; every suite and both offline gates pass; v1-r10 check-only, both predicates and both checklists unchanged"
    verification:
      - kind: other
        ref: "253-125-PLAN.md Task 3 <verify> (exit 0)"
        status: pass
    human_judgment: false
estimate: {tokens: 46000, tasks: 3}
actuals:
  tokens: 48880
  tasks: 3
  commits: 6
commits: 6
plan_head_before: 1058a9236d983fdc7d9ed75abd52a7019cc8bfe0
plan_head_after: 4ec50b500a707a059db480e8b79db1f87bb70af7
results_receiver_fix_commit: 0226f20ae1e08419a9c1a91ddecade9e52fb6403
live_host_fix_commit: 6551f3f05076792a4ae01c0bee4011881d24b4c0
duration: "about 40 minutes (22:05Z to 22:45Z)"
completed: 2026-10-16
---

# Phase 253 Plan 125: run_logs-scoped results-receiver admission Summary

**This fixes the cause of the 253-122 halt. GitHub's real log redirect host, `results-receiver.actions.githubusercontent.com`, is now trusted in two places, both scoped the same way:**

- **in the transport:** in `_validate_allocation`, `_approved_redirect` and request_one's hop re-validation;
- **in the verifier:** in `verify_live_transaction_host`.

**In both places it is trusted by exact name, only on the `run_logs` route, only at hop 1, and only when it is listed in download_hosts. Both fixes were proven RED-first against the committed R10 ledger sequence 47. Every lookalike and every off-route or off-hop use is refused before its socket. The pre-R11 blob and pipelines behaviour is unchanged. Zero GitHub requests were made.**

## Task Commits

1. **Task 1, checklist:** `b680e267b` docs(253-125): R11 preservation checklist
2. **Task 1, RED:** `14597d8a7` test(253-125): results-receiver on the run_logs hop from the real seq-47 shape (RED)
3. **Task 1, GREEN:** `0226f20ae` fix(253-125): admit results-receiver for the run_logs redirect hop only (**results_receiver_fix_commit** `0226f20ae1e08419a9c1a91ddecade9e52fb6403`; the subject is unique in the repository)
4. **Task 2, RED:** `fcdea4b7b` test(253-125): results-receiver run_logs hop in the live host rule (RED)
5. **Task 2, GREEN:** `6551f3f05` fix(253-125): accept the run_logs results-receiver hop in the live host rule (`6551f3f05076792a4ae01c0bee4011881d24b4c0`; the subject is unique)
6. **Task 3:** `4ec50b500` docs(253-125): R11 hermetic-vs-live audit record

## Preconditions (checked before any edit)

- PLANs 253-125..135 are in HEAD (1058a9236).
- The tree was clean except config.json.
- 253-122-SUMMARY.md is `status: halted`.
- `shasum -c PRESERVATION-R10` exited 0.
- `--verify-load-acceptance ... --require-target-disposition` exited 0.

## Preservation checklist

- `253-LOAD-RECOVERY-PRESERVATION-R11.sha256` has 87 lines. These are the 62 PRESERVATION-R10 lines, unchanged and in order, followed by 25 pins:
  - PRESERVATION-R10 itself;
  - the SUMMARYs for 253-116 through 253-122;
  - the six R10 freeze-line records;
  - the 253-122 action approval, `253-R10-CANARY-OPERATOR.sh`, and the allocation, evidence, ledger, publication-receipt and five preflight records.
- Every computed hash equalled the value pinned in the plan.
- `shasum -c` passes. Positive control: a scratch copy with one hash digit flipped (line 70) exits 1.

## RED / GREEN counts

- **Task 1 RED, entry 1 (fully unfixed transport):** exit 1. 73 tests ran: 22 failures and 2 errors.
  - Every new test whose allocation lists results-receiver fails at the allocation layer with `download_host_allocation: live allocation contains a host outside the trusted policy`. This includes the seq-47 positive control (`1 != 0 : ci-hosted-transport: download_host_allocation: ...`).
  - The direct helper tests fail with AttributeError (no `RESULTS_RECEIVER_HOST`) and TypeError (`_trusted_download_host() takes 3 positional arguments but 5 were given`).
- **Task 1 RED, entry 2 (hop rule alone):** a working-tree transport carried only the `_validate_allocation` alternative. It was never committed and was reverted with `git checkout` immediately after the run.
  - On it, the seq-47 positive control and the hop-2 chain both fail (exit 1, 2/2) with `redirect_rejected: redirect host is outside the frozen download-host list or trusted download policy`. That is the exact 253-122 message, so the test does exercise the hop rule.
- **Task 1 GREEN:** 73/73 pass. The verbatim Task 1 `<verify>` exits 0. That run includes the offline CLI tracer:
  - `--check-only` accepts R10 allocation + results-receiver;
  - it refuses R10 allocation + `results-receiver.actions.githubusercontent.com.evil`;
  - it accepts the unmodified R10 allocation (positive control).
  - Tracer gate: the `<verify>` was re-run on the clean tree after the commit and passed before expansion.
- **Task 2 RED:** exit 1. 122 tests ran, with 1 error: `test_live_r10_seq47_results_receiver_hop_is_a_trusted_run_logs_hop`.
  - On the unfixed rule it accepts seq 47 itself as hop 0, then refuses the seq-47 hop-1 transaction with `VerificationError: live redirect hop is not on a trusted download host` (line 147).
  - The other new tests already passed, as they must: the negatives, and the seq-31 blob and pipelines positives.
- **Task 2 GREEN:** 122/122 pass. The verbatim Task 2 `<verify>` exits 0, including the step-1 R10 evidence from `8343b9f82` (`--mode canary --scenario full-pass`, `scenario.run_id == "38962706886"`). That run is a real-shape fixture check, not acceptance evidence.
- **Task 3:** the verbatim Task 3 `<verify>` exits 0 (run under caffeinate). Suite results:
  - audit 30/30, transport 73/73, verifier 122/122, publication 85/85, canary-flow 22/22, canary-recovery 5/5;
  - `ci-gate-canary.test.sh` passed, `ci-pr-proof.test.sh` 64/64;
  - both gates passed;
  - acceptance `--require-target-disposition` exit 0, `--require-target-accepted` exit 3 (unchanged);
  - v1 and r2-r10 `--check-only` all 0;
  - both checklists pass.

## Gate summaries (synthetic r10 pair, r8 and r9 refs seeded)

| Gate | status | requests | requests_by_category | live_hops | authorization | shim refusals |
|---|---|---|---|---|---|---|
| hermetic | passed (verifier passed, response_shape ok, seeded refs unchanged) | 93 | artifact_downloads 10, artifact_metadata 6, attempt_jobs 7, cancellation 1, dispatch 7, failure_logs 6, pre_watch_rate 7, preflight 5, publication 19, run_discovery 7, terminal_polls 18 | 8 hop-1 rows on localhost (5 artifact_zip, 3 run_logs, all 200) | n/a | 0 |
| live-policy | passed (verifier passed, response_shape ok, seeded refs unchanged) | 93 | same as hermetic | 8 hop-1 rows on productionresultssa17.blob.core.windows.net (5 artifact_zip, 3 run_logs, all 200) | api_with 85, api_without 0, blob_with 0 | 0 |

The fakes still send run logs to the blob host. That is still accepted, because the pre-R11 predicate is kept for run_logs. 253-128 moves the fakes to the real results-receiver shape.

## Edited existing tests

- **`ci-hosted-transport.test.py`:**
  - `SHIM_HOSTS` gains productionresultssa16, results-receiver and the four lookalikes.
  - The `LivePolicyRedirectTests.setUp` TLS identity gains `*.actions.githubusercontent.com` and `results-receiver.actions.githubusercontent.com.evil`. With these, a regression would reach a real local socket and be caught by the connect-log assertions, instead of failing at TLS.
  - No existing assertion was changed or weakened.
  - New constants: `R10_LEDGER`, `RESULTS_RECEIVER`, `RESULTS_RECEIVER_LOOKALIKES`.
  - New tests: the seq-47 control, the hop-2 blob chain, the self/untrusted/absent hop-2 and third-redirect cases, 404/500 at hop 1, the lookalikes, the port/http/userinfo/fragment cases, artifact_zip, job_logs, the 253-122 reproduction (R10 download_hosts), and the direct request_one scope cases. Two allocation/predicate tests were added in `LivePolicyAllocationTests`.
- **`ci-hosted-gate-verify.test.py`:** a new `LiveResultsReceiverHostTests` class only.
- **`ci-hermetic-live-audit.test.py`:** only `AUDIT_REL` changed, to the R11 path.

## Audit record (R11)

- **Schema:** `sigra.phase253.hermetic-live-audit/r10` (unchanged; 253-126 bumps it). `audit_head` is `6551f3f05...`, the HEAD after Task 2.
- **match_counts** are unchanged and equal the scan: transport 25, canary.sh 6, pr-proof 2, publication 8, verifier 28. **There are no new matcher sites**, so no new rows were added.
- All 72 branch rows had their `line` refreshed; ids are unchanged.
- Host-rule rows gained live refs and a one-clause `live_behavior` update:
  - transport-507: the allocation test;
  - transport-594: the direct scope test and the seq-47 test;
  - transport-816: seven results-receiver live tests;
  - verifier-128-supplementary: the seq-47 verifier test.
- **shape-run_logs:**
  - Real sample: R10 ledger `3b0dd91e...` seq 47 (status 302).
  - `fields_compared` is meta:actual_status, meta:hop_ordinal, header:location and header:location.host; all four resolve in the sample, so `fields_without_real_sample` was removed.
  - The kind stays justified, with the plan's residual_risk text.
- **Gaps and checks:** zero gap rows. The R10 record still hashes `db60df7b...`.

## Deviations from Plan

1. **[Rule 1 - plan/reality mismatch] RED for the seq-47 control has two layers.**
   - **What the plan expected:** the seq-47 control would fail with `redirect_rejected` on the unfixed transport.
   - **What happened:** on the fully unfixed code it cannot. The test's allocation must list results-receiver, and the unfixed `_validate_allocation` refuses that allocation first, with `download_host_allocation`, before hop 0.
   - **How it was recorded:** the receipt records both real runs instead of one:
     - entry 1: the fully unfixed transport (download_host_allocation);
     - entry 2: the hop rule alone, on an uncommitted, reverted working-tree patch of the allocation layer only (redirect_rejected, the exact 253-122 message).
   - Both entries are nonzero real runs. The receipt was committed before the fix.
   - Nothing was loosened. The extra layer makes the evidence stricter: it shows both hard-coded sites refuse the host.
2. **[Rule 2] Exact-int hop check.** The predicate uses `type(hop_ordinal) is int`, so a boolean `True` hop cannot pass as hop 1. Both the transport and the verifier have a test for this.
3. **[Rule 1] Audit justification text.** The shape-run_logs `justification` was rewritten along with residual_risk. The old text said no run-logs response was committed, which is no longer true.
4. **Verifier refs.** Three of the new verifier tests are not cited as audit coverage. Their class name does not match the checker's LIVE_MARKER floor, and Task 3 may not edit the test file. The seq-47 verifier test (named `test_live_...`) is cited instead.

## Known Stubs

None.

## Remaining gaps / handoff

- **Unobserved:** what results-receiver really returns on hop 1 (200 with bytes, or another redirect). 253-126/127 observe it in a separate read-only probe window. An unexpected shape fails closed: redirect_rejected, redirect_budget_exhausted, or a non-200 final receipt.
- **FREEZE-R10:** it no longer validates the current tree, as expected. `ci-gate-canary.sh --check-only` was not run against it. FREEZE-R11 is cut in 253-131.
- **Not yet run:** the dry-run test suite (34-44 minutes) runs in 253-128.

## Invariants

- The tree is clean except config.json. config.json sha256 is `8e312f6c...0b8d`.
- state.json is 70229 bytes, sha256 prefix e45278c2cee0. STATE.md, ROADMAP.md, REQUIREMENTS.md and HANDOFF.json are unchanged.
- No gsd-tools writer verbs were run.
- No `scripts/ci/__pycache__` remains.
- Zero GitHub requests, fetches or pushes. Full Phase 253 verification stays not_started.

## Self-Check: PASSED

- All four created records exist. All six commits are ancestors of HEAD.
- Each fix subject appears on exactly one commit in the repository.
- Each RED receipt commit is an ancestor of its fix commit, and the checklist commit comes first.
