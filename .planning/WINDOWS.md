---
schema_version: 1
open_count: 8
waived_count: 0
fixed_count: 1
total_count: 9
last_updated: 2026-10-11T23:08:18.790Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 234 | unrun-verify | test/sigra/install/golden_diff_test.exs | 54 | Golden/idempotency verifier exits 1: generated config/dev.exs differs from committed fixture | open |  | 2026-08-02T01:35:01.034Z |  |
| 2 | 234 | deviation | .planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-EVIDENCE.json |  | Dependabot job-log evidence remains failed because authenticated browser capture is unavailable | open |  | 2026-08-02T01:35:01.099Z |  |
| 3 | 235 | stub | scripts/ci/verify-fast-01-source-complete-attestation-offline.sh | 14 | Four UNSET_PLAN_17 capture pins intentionally fail closed until Plan 17 installs protected capture provenance | open |  | 2026-09-09T01:27:29.104Z |  |
| 4 | 236 | deviation | test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs |  | Pre-existing, unrelated mix ci failure (3 tests) stale since v1.48 REQUIREMENTS.md rollover cc6f17e4; documented in 236-02-SUMMARY.md and filed as a todo, not fixed (out of plan 236-02's file scope) | open |  | 2026-09-15T21:56:09.715Z |  |
| 5 | 240 | deviation | .planning/phases/240-green-main-evidence-honest-pages-script/240-EVIDENCE.md |  | 240-05 Task 3: harness auto-mode classifier refused gh issue close 231; the close ran as gh api -X PATCH /issues/231 state=closed under operator standing authorization. Recorded in the AFTER-ISSUE-231-CLOSED slot; verification (gh issue view --json state => CLOSED) unchanged. | open |  | 2026-09-18T18:32:01.923Z |  |
| 6 | 245 | unrun-verify | .planning/phases/245-branch-prune-local-and-remote/245-24-PLAN.md |  | Task 2 current-contract/admission verifier was not run because Task 1 D-06 preflight blocked on unreadable live origin/gh-pages object. | open |  | 2026-10-01T11:42:24.708Z |  |
| 7 | 245 | unrun-verify | .planning/phases/245-branch-prune-local-and-remote/245-24-PLAN.md |  | Task 3 after-stage/post-state verifier was not run because Task 1 D-06 preflight blocked before contract and ref operation. | open |  | 2026-10-01T11:42:24.793Z |  |
| 8 | 247 | unrun-verify | .planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs |  | Plan 08 final readiness validator passed: valid=true with exact-source CI 37800067568 and authenticated dry-run 37803817504; PR #224 remains open and unpublished. | fixed |  | 2026-10-08T03:27:53Z | 2026-10-08T16:04:05.483Z |
| 9 | 251 | deviation | .planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs | 361 | Updated Nyquist expectations after marking all 12 Phase 251 validation rows proven; regenerated audit from current validation state. | open |  | 2026-10-11T23:08:18.790Z |  |

````json
[
  {
    "id": 1,
    "kind": "unrun-verify",
    "phase": "234",
    "file": "test/sigra/install/golden_diff_test.exs",
    "line": 54,
    "description": "Golden/idempotency verifier exits 1: generated config/dev.exs differs from committed fixture",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-02T01:35:01.034Z",
    "resolved_at": null
  },
  {
    "id": 2,
    "kind": "deviation",
    "phase": "234",
    "file": ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-EVIDENCE.json",
    "line": null,
    "description": "Dependabot job-log evidence remains failed because authenticated browser capture is unavailable",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-02T01:35:01.099Z",
    "resolved_at": null
  },
  {
    "id": 3,
    "kind": "stub",
    "phase": "235",
    "file": "scripts/ci/verify-fast-01-source-complete-attestation-offline.sh",
    "line": 14,
    "description": "Four UNSET_PLAN_17 capture pins intentionally fail closed until Plan 17 installs protected capture provenance",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-09T01:27:29.104Z",
    "resolved_at": null
  },
  {
    "id": 4,
    "kind": "deviation",
    "phase": "236",
    "file": "test/sigra/planning/phase_235_fast_01_source_complete_contract_test.exs",
    "line": null,
    "description": "Pre-existing, unrelated mix ci failure (3 tests) stale since v1.48 REQUIREMENTS.md rollover cc6f17e4; documented in 236-02-SUMMARY.md and filed as a todo, not fixed (out of plan 236-02's file scope)",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-15T21:56:09.715Z",
    "resolved_at": null
  },
  {
    "id": 5,
    "kind": "deviation",
    "phase": "240",
    "file": ".planning/phases/240-green-main-evidence-honest-pages-script/240-EVIDENCE.md",
    "line": null,
    "description": "240-05 Task 3: harness auto-mode classifier refused gh issue close 231; the close ran as gh api -X PATCH /issues/231 state=closed under operator standing authorization. Recorded in the AFTER-ISSUE-231-CLOSED slot; verification (gh issue view --json state => CLOSED) unchanged.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-18T18:32:01.923Z",
    "resolved_at": null
  },
  {
    "id": 6,
    "kind": "unrun-verify",
    "phase": "245",
    "file": ".planning/phases/245-branch-prune-local-and-remote/245-24-PLAN.md",
    "line": null,
    "description": "Task 2 current-contract/admission verifier was not run because Task 1 D-06 preflight blocked on unreadable live origin/gh-pages object.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-10-01T11:42:24.708Z",
    "resolved_at": null,
    "milestone": "v1.48"
  },
  {
    "id": 7,
    "kind": "unrun-verify",
    "phase": "245",
    "file": ".planning/phases/245-branch-prune-local-and-remote/245-24-PLAN.md",
    "line": null,
    "description": "Task 3 after-stage/post-state verifier was not run because Task 1 D-06 preflight blocked before contract and ref operation.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-10-01T11:42:24.793Z",
    "resolved_at": null,
    "milestone": "v1.48"
  },
  {
    "id": 8,
    "kind": "unrun-verify",
    "phase": "247",
    "file": ".planning/phases/247-release-candidate-and-repository-readiness/validate-release-readiness.mjs",
    "line": null,
    "description": "Plan 08 final readiness validator passed: valid=true with exact-source CI 37800067568 and authenticated dry-run 37803817504; PR #224 remains open and unpublished.",
    "status": "fixed",
    "reason": "",
    "recorded_at": "2026-10-08T03:27:53Z",
    "resolved_at": "2026-10-08T16:04:05.483Z",
    "milestone": "v1.49"
  },
  {
    "id": 9,
    "kind": "deviation",
    "phase": "251",
    "file": ".planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/verify-v149-traceability.test.mjs",
    "line": 361,
    "description": "Updated Nyquist expectations after marking all 12 Phase 251 validation rows proven; regenerated audit from current validation state.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-10-11T23:08:18.790Z",
    "resolved_at": null,
    "milestone": "v1.49"
  }
]
````
