---
schema_version: 1
open_count: 12
waived_count: 0
fixed_count: 0
total_count: 12
last_updated: 2026-09-11T19:42:38.151Z
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
| 4 | 235.1 | unrun-verify | scripts/ci/library-partitions-portability.test.sh |  | Plan 29 timed validation and live evidence were not run because the frozen portability test pins superseded Plan 22 calibration values | open |  | 2026-09-11T01:27:46.425Z |  |
| 5 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-30-PLAN.md |  | Plan 30 live capture and validation were not run after the sole local harness failed pair 3 comparability | open |  | 2026-09-11T01:56:40.455Z |  |
| 6 | 235.1 | deviation | scripts/ci/verify-library-routing-evidence.test.sh |  | Archive replay exposed and removed a pin-test historical Git lookup. | open |  | 2026-09-11T15:09:45.853Z |  |
| 7 | 235.1 | deviation | test/sigra/planning/phase_235_1_library_economics_contract_test.exs |  | Archive verification required a format-stable authority refresh under the installed compatible Erlang runtime. | open |  | 2026-09-11T15:09:45.978Z |  |
| 8 | 235.1 | deviation | test/sigra/planning/phase_235_1_library_economics_contract_test.exs |  | Symlink-sensitive wildcard discovery was replaced with the authoritative ordinary-path registry. | open |  | 2026-09-11T15:09:46.100Z |  |
| 9 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-43-PLAN.md |  | Plan 43 collector, timing, and live verification were prohibited after the sole RR/RO snapshot produced no materialized tuple output | open |  | 2026-09-11T17:55:47.673Z |  |
| 10 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-44-SUMMARY.md |  | Plan 44 sole fixture wrapper stopped at 2/6 after Python injected five environment keys; probe, protected snapshot, collector, timing, and live verification were prohibited | open |  | 2026-09-11T18:22:36.789Z |  |
| 11 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-45-PLAN.md |  | Plan 45 Task 2 health/timing and Task 3 live verification were prohibited after the sole collector dry-run parser failure | open |  | 2026-09-11T18:43:52.896Z |  |
| 12 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json |  | Plan 46 timing and GitHub validation were prohibited by the consumed Task 1 hard stop | open |  | 2026-09-11T19:42:38.151Z |  |

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
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": "scripts/ci/library-partitions-portability.test.sh",
    "line": null,
    "description": "Plan 29 timed validation and live evidence were not run because the frozen portability test pins superseded Plan 22 calibration values",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-11T01:27:46.425Z",
    "resolved_at": null
  },
  {
    "id": 5,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-30-PLAN.md",
    "line": null,
    "description": "Plan 30 live capture and validation were not run after the sole local harness failed pair 3 comparability",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-11T01:56:40.455Z",
    "resolved_at": null
  },
  {
    "id": 6,
    "kind": "deviation",
    "phase": "235.1",
    "file": "scripts/ci/verify-library-routing-evidence.test.sh",
    "line": null,
    "description": "Archive replay exposed and removed a pin-test historical Git lookup.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-11T15:09:45.853Z",
    "resolved_at": null,
    "milestone": "v1.47"
  },
  {
    "id": 7,
    "kind": "deviation",
    "phase": "235.1",
    "file": "test/sigra/planning/phase_235_1_library_economics_contract_test.exs",
    "line": null,
    "description": "Archive verification required a format-stable authority refresh under the installed compatible Erlang runtime.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-11T15:09:45.978Z",
    "resolved_at": null,
    "milestone": "v1.47"
  },
  {
    "id": 8,
    "kind": "deviation",
    "phase": "235.1",
    "file": "test/sigra/planning/phase_235_1_library_economics_contract_test.exs",
    "line": null,
    "description": "Symlink-sensitive wildcard discovery was replaced with the authoritative ordinary-path registry.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-11T15:09:46.100Z",
    "resolved_at": null,
    "milestone": "v1.47"
  },
  {
    "id": 9,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-43-PLAN.md",
    "line": null,
    "description": "Plan 43 collector, timing, and live verification were prohibited after the sole RR/RO snapshot produced no materialized tuple output",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-11T17:55:47.673Z",
    "resolved_at": null,
    "milestone": "v1.47"
  },
  {
    "id": 10,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-44-SUMMARY.md",
    "line": null,
    "description": "Plan 44 sole fixture wrapper stopped at 2/6 after Python injected five environment keys; probe, protected snapshot, collector, timing, and live verification were prohibited",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-11T18:22:36.789Z",
    "resolved_at": null,
    "milestone": "v1.47"
  },
  {
    "id": 11,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-45-PLAN.md",
    "line": null,
    "description": "Plan 45 Task 2 health/timing and Task 3 live verification were prohibited after the sole collector dry-run parser failure",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-11T18:43:52.896Z",
    "resolved_at": null,
    "milestone": "v1.47"
  },
  {
    "id": 12,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json",
    "line": null,
    "description": "Plan 46 timing and GitHub validation were prohibited by the consumed Task 1 hard stop",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-11T19:42:38.151Z",
    "resolved_at": null,
    "milestone": "v1.47"
  }
]
````
