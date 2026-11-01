# Finish Plan172 with the missing docs-only proof

PR341's normal CI succeeded. Its212-file comparison exposed a verifier limit of100, corrected offline to the documented300-file cap (a saturated300 remains rejected). The original closed attempt and its failed verifier output are unchanged. The corrected independent checker accepts its original saved evidence. All six canary cases and the independent hosted verifier also passed.

This continuation retains those successes and requests only one draft docs-only PR. It publishes the existing docs-base98f0e9e6 and docs-head879d628f objects under their original unused create-only refs. It does not republish a candidate or fixture, fetch main, dispatch canaries, create a normal PR, rerun a workflow or reopen an old allocation. A new approval and new120-request/60-minute window are mandatory.

Default operator behavior is offline validation. --run requires the two new committed approvals in APPROVAL.md. Missing or wrong approvals fail before state/allocation creation. Its transport guard enforces the narrower docs-only scope on every request, in addition to the existing frozen publisher/collector checks.

Continue the same Plan172 with $gsd-execute-phase 253 --gaps-only. No quick/progress scan or new numbered plan is needed. The original flaky failure remains not reproduced; Phase253 verification remains separate.
