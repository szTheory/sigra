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
  next_action: "Inspect Phase256 readiness construction, source commit materialization, and authorization boundaries; propose and implement only local code/test changes. Do not use hosted APIs, update PR368, create a new claim, retry, renew, collect measurements, or alter Phase255.1 evidence."
  goal: find_and_fix
  specialist_dispatch_enabled: true
---

## Evidence

- timestamp: 2026-11-05T15:09:52Z — PREP-LEDGER recorded 11 GET requests, 0 mutations, and a blocked `prep-readiness` stage. First request was `/rate_limit`; the candidate commit GET failed. The persisted readiness receipt records four blockers.
- timestamp: 2026-11-05T15:10Z — Independent `verify-prepared` wrote PREP-VERIFY with status `blocked`, zero samples, zero mutations, zero workloads, and zero runner timeout-job minutes.
- timestamp: 2026-11-05T15:20Z — Corrected the outer-process JSON newline after preserving the original bytes under `preparation/write-ahead-preservation/20261105T152048Z-before-outer-receipt-format-repair/`.

## Eliminated

- hypothesis: "A timeout or rate limit caused the stop."
  reason: "The outer process completed in 26.175 seconds without timeout. The `/rate_limit` request passed; no 403/429 stop was recorded."
- hypothesis: "The main branch changed during the readiness pass."
  reason: "Both stored main-ref observations have SHA 970055abcf1ee4e8b5d8ebcf79de0eeecf4f223d. The false blocker comes from the readiness implementation comparing the second read to a missing `source_identities.control.proposed_pr_base_sha` rather than the present contract `base_sha`."
- hypothesis: "The planned PR368 update was attempted and failed."
  reason: "The ledger contains no mutation intent/result and reports 0 mutations; readiness failed before the Phase256 existing-branch update method."

## Resolution

Pending local code-path audit. The consumed attempt remains immutable terminal history; no hosted retry or acceptance sample is allowed under its authorization.
