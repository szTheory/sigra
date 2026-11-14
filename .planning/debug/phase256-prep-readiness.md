---
status: investigating
trigger: "Diagnose and fix the Phase256 candidate preparation readiness deadlock so the workflow does not consume a one-shot claim before its planned existing-PR publication can run. Preserve the failed attempt and all ceilings; no hosted action or rerun in this debug session."
created: 2026-11-05
updated: 2026-11-05
symptoms:
  expected: "Phase256 Plan03 should verify the exact pre-update state of existing PR368, perform its single authorized candidate branch publication, run one bounded candidate CI workload, then independently verify it. If an essential precondition cannot hold, stop before spending the one-shot claim where possible and report the exact blocker."
  actual: "The one authorized prepare-approved invocation returned exit 2 after 11 recorded GET requests. It made no branch mutation, started no CI workload, and produced zero performance samples. The one-shot invocation claim is consumed and this scope cannot be retried."
  errors: "prepare-approved stderr: ValueError: readiness_receipt_not_ready_for_fresh_preparation. PREP-VERIFY is blocked with readiness_default_branch_sha_changed_during_pass, readiness_prep_pull_request_already_open:phase256-candidate-initial, readiness_prep_source_ref_missing_or_changed:phase256-candidate-initial, and readiness_source_commit_object_unavailable_or_changed:candidate:5effabe754c74fcd3086128ae9ce2e01ae07ab79. The main ref was unchanged at 970055abcf1ee4e8b5d8ebcf79de0eeecf4f223d in both saved observations; the readiness code used a missing proposed_pr_base_sha instead of contract.base_sha. Generic readiness also requires a new PR/no open PR and the target candidate SHA on the branch before the Phase256 PR368 update step. GitHub's GET commit observation failed for candidate SHA 5effabe754c74fcd3086128ae9ce2e01ae07ab79, and that object is absent from the local Git object store."
  timeline: "2026-11-05; first counted GitHub request was 2026-11-05T15:09:36.488690Z. The outer process ended after 26.175 seconds."
  repro: "The single recorded command was scripts/ci/ci-repaired-comparison.py prepare-approved with the Phase256 proposal, approval, authorization, ledger, and preparation/EXECUTION.json paths, under a 2700-second process-group hard timeout. It ran read_only_readiness before the Phase256 existing-PR branch-update method. Do not rerun it."
Current Focus:
  hypothesis: "Phase256 routes through generic live readiness that validates the post-publication state before the authorized mutation that could produce it. A false base-SHA blocker and unmaterialized Git commit add independent failures."
  test: "Trace the production readiness → claim → branch-update path against saved ledger responses and focused tests; determine the smallest safe local correction and the necessary source-publication contract."
  expecting: "Captured production-path tests should accept the exact existing PR368 old-branch state as a precondition, require the candidate commit object to be publishable before any branch mutation, verify the default branch against contract.base_sha, and assert the exact single mutation plus post-update state."
  next_action: "Parent reports local repair completion and remote publication scope blocker. Preserve Plan03 halted; no execute command, hosted retry, claim or measurement is authorized."
  bug_class: Bohrbug
  sbfl: skipped — no per-test coverage spectrum is available
  reasoning_checkpoint:
    hypothesis: "Live readiness applies new-PR/post-update preconditions to Phase256 existing-PR preparation and omits the contract.base_sha fallback; both reject valid frozen pre-update identities."
    confirming_evidence:
      - "read_only_readiness compares final main SHA to missing control.proposed_pr_base_sha; both captured main refs equal contract.base_sha."
      - "It requires family.source_sha on the branch and no open PR, whereas update_existing_candidate_pull_request_branch requires PR368 open on its prior SHA."
    falsification_test: "A production readiness replay using a stable contract base, exact old PR368 identity, available target commit and valid caches remains blocked."
    fix_rationale: "Use the frozen base fallback and validate the exact captured old PR/head state only for Phase256; preserve commit/tree availability, rule, cache, claim and one-mutation gates."
    blind_spots: "No remote object availability or hosted effect can be established locally; the consumed scope cannot be retried."
    candidate_causes:
      - "code: generic readiness preconditions and missing base fallback"
      - "data/environment: local-only source objects are not present on GitHub"
    and_gate: "no — each independent failed check can block preparation; fixing local checks does not remove the remote object blocker"
  goal: find_and_fix
  specialist_dispatch_enabled: true
audit_acknowledged:
  milestone: v1.50
  at: 2026-11-10
  status: investigating
---

## Evidence

- timestamp: 2026-11-05T15:09:52Z — PREP-LEDGER recorded 11 GET requests, 0 mutations, and a blocked `prep-readiness` stage. First request was `/rate_limit`; the candidate commit GET failed. The persisted readiness receipt records four blockers.
- timestamp: 2026-11-05T15:10Z — Independent `verify-prepared` wrote PREP-VERIFY with status `blocked`, zero samples, zero mutations, zero workloads, and zero runner timeout-job minutes.
- timestamp: 2026-11-05T15:20Z — Corrected the outer-process JSON newline after preserving the original bytes under `preparation/write-ahead-preservation/20261105T152048Z-before-outer-receipt-format-repair/`.

- timestamp: 2026-11-05 — Bound-store check corrects the gathered symptom: candidate 5effabe754c74fcd3086128ae9ce2e01ae07ab79 is a commit in .planning/execution/256/objects.git. Workspace git cat-file alone returns 128; bound-store cat-file and rev-list closure return 0. SOURCE-CHECK validates this bound store and cannot prove GitHub object availability.
- timestamp: 2026-11-05 — Production order is claim creation → live readiness → complete_preparation → existing PR368 branch PATCH. Claim is deliberately required at each network boundary. SOURCE-CHECK copies ready_within_scope from offline feasibility and verifies local objects, selected source bytes and runner cost; the sole allowed PATCH contains SHA/force only, with no object-upload transport.
- timestamp: 2026-11-05 — Knowledge-base fallback has no matching readiness pattern. Per-test coverage ranking skipped because no passing/failing coverage spectrum exists. Dirty source, tests, and debug session preserved with verified exact readback in phase256-prep-readiness-local-20261105/PRESERVATION.json.

- timestamp: 2026-11-05 — Agent-authored production readiness test reproduced the three false blockers. Fixed readiness accepts exact old PR368/head and stable contract.base_sha; independent receipt verification checks commit/tree, PR/ref, base, rules and caches. Rehashed wrong-tree/branch/PR observations are rejected.
- timestamp: 2026-11-05 — Focused test command in phase256-prep-readiness-local-20261105/FOCUSED-COMMAND.json passed (exit 0), covering unavailable source, changed branch and PR identities, default-base changes, one valid PATCH and existing claim/Plan10 behavior. Preserved source compiled in isolation reproduces the old three-blocker failure; shared source was never reverted. git diff --check passed. Stryker skipped because it is not configured for this Python unittest path.
- timestamp: 2026-11-05 — Producer build-task2-receipts.py constructs ready_within_scope from local materialization, one ref update and runner cost. Materialization reports zero hosted requests. Saved remote commit GET return_code is 1; its request row does not retain exact HTTP failure cause. Remote object availability is unproven. LOCAL-RESULT.json compares a single leased push against Git Database API publication and lists required preflight invariants; neither is allowed by the consumed exact PATCH scope.

## Eliminated

- hypothesis: "A timeout or rate limit caused the stop."
  reason: "The outer process completed in 26.175 seconds without timeout. The `/rate_limit` request passed; no 403/429 stop was recorded."
- hypothesis: "The main branch changed during the readiness pass."
  reason: "Both stored main-ref observations have SHA 970055abcf1ee4e8b5d8ebcf79de0eeecf4f223d. The false blocker comes from the readiness implementation comparing the second read to a missing `source_identities.control.proposed_pr_base_sha` rather than the present contract `base_sha`."
- hypothesis: "The planned PR368 update was attempted and failed."
  reason: "The ledger contains no mutation intent/result and reports 0 mutations; readiness failed before the Phase256 existing-branch update method."

## Resolution

local_status: completed_and_automatically_verified
root_cause:
  - "Missing contract.base_sha fallback causes a false default-branch movement blocker."
  - "Generic new-PR readiness requires post-update source and no open PR before the existing-PR method requires old source and open PR368."
  - "Source feasibility proves local objects only; remote commit GET failed and SHA-only PATCH cannot publish local objects."
fix: "Apply frozen base fallback, validate exact old PR368/ref preconditions for Phase256, independently verify all readiness observations. Preserve remote commit/tree requirement, claim boundaries and transport."
files_changed: [scripts/ci/ci-repaired-comparison.py, scripts/ci/ci-repaired-comparison.test.py]
oracle_type: specified — frozen contract and source-bound PR368 snapshot
verification:
  target_test: {result: pass}
  mutation_check: {result: skipped, reason_if_skipped: Stryker not configured for Python unittest}
  no_op_deletion: {result: pass, deletion_justified_by_rca: true}
  adjacent_tests: {result: pass, suites_run: [focused candidate readiness, existing branch update, invocation claim]}
  revert_and_reconfirm: {result: pass, bug_returned_on_revert: true, fixed_on_reapply: true}
  guardrail_verdict: accepted
remaining: "Remote object publication requires a distinct source-bound transport scope; consumed Plan03 remains halted with 11 GETs and no mutation/workload/sample. No retry or hosted success is claimed."
preservation: phase256-prep-readiness-local-20261105/PRESERVATION.json
evidence: phase256-prep-readiness-local-20261105/LOCAL-RESULT.json
archive: "Not archived because overall hosted preparation remains blocked; local repair uses automatic verification without a routine human checkpoint."
