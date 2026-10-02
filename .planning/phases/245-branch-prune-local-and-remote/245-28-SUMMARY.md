---
phase: 245-branch-prune-local-and-remote
plan: 28
status: halted
requirements-completed: []
---

# Plan 245-28: Coordinator admission blocked

The plan made its single authorized coordinator admission attempt. The coordinator returned `coordinator_admission_gate_busy_or_stale` before the child command ran. Task 2 did not start, no commit was made by this plan, and no production ref operation occurred. The exact staged two-file digest and HEAD remained unchanged. The immutable details are in `245-28-RECOVERY.json`, whose outcome remains `blocked`. This SUMMARY uses `status: halted` to record the designed stop and prevent GSD from replaying the failed attempt before Plan 31 can recover it.

The present workspace sandbox makes `.git` and its coordinator root non-writable. That is evidence for the current policy/path restriction, while the original failing `mkdir` errno and any transient gate owner at that instant were not captured. Do not replay Plan 28, remove or repair coordinator state, or treat this blocked receipt as a pass.

Plan 245-31 is the separately scoped recovery. It requires explicit elevated access and fresh exact preconditions before one new admission. This blocked summary may be superseded only after that recovery and Plan 16 supersession evidence are committed. REPO-04 remains open.
