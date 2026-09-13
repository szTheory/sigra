---
schema_version: 1
open_count: 53
waived_count: 0
fixed_count: 0
total_count: 53
last_updated: 2026-09-13T13:58:38.159Z
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
| 13 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-49-PLAN.md |  | Exact Plan 49 allocator location-bearing AST digest differs under mandated /usr/bin/python3 3.9.6; no allocator invocation occurred | open |  | 2026-09-11T21:58:14.807Z |  |
| 14 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-51-PLAN.md |  | Plan 51 persistent root nlink=2 contract fails after exclusive marker creation; live root nlink is 3 | open |  | 2026-09-11T23:52:23.970Z |  |
| 15 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-52-PLAN.md |  | Plan 52 Task 1 verifier requires expected_authority.plan51 and later requires exact expected_authority equality to a closed object that omits plan51 | open |  | 2026-09-12T00:25:02.798Z |  |
| 16 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json |  | Plan 52 Task 2 local timing and Task 3 GitHub validation were prohibited after the no-retry Task 1 contradictory verifier halt | open |  | 2026-09-12T00:25:02.890Z |  |
| 17 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-53-PLAN.md |  | Plan 53 consumed dry-run environment verifier failed before collector-tests receipt; no retry or downstream action occurred | open |  | 2026-09-12T01:10:19.006Z |  |
| 18 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json |  | Plan 53 candidate, admission, timing, and GitHub validation were prohibited after the consumed dry-run environment hard stop | open |  | 2026-09-12T01:10:19.097Z |  |
| 19 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-54-PLAN.md |  | Plan 54 Task 1 selects full Plan 53 descendant rows but requires the reduced cache-manifest byte count and digest; allocator was not invoked | open |  | 2026-09-12T01:46:46.219Z |  |
| 20 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json |  | Plan 54 allocation, local timing, and GitHub validation were prohibited after the pre-allocation cache-schema contradiction | open |  | 2026-09-12T01:46:46.324Z |  |
| 21 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-55-PLAN.md |  | Approved Plan55 reuses Plan54 allocator AST digest although the Plan55 literals changed; both pinned runtimes derive 90651ac4 instead of ad6595a0 | open |  | 2026-09-12T02:45:29.763Z |  |
| 22 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-55-PLAN.md |  | Plan55 Tasks 2-3 were not run after the no-retry Task1 authority gate failed | open |  | 2026-09-12T02:45:29.868Z |  |
| 23 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-56-PLAN.md |  | Plan56 canonical sorted expected-authority JSON cannot satisfy the verifier non-sorted key tuple; allocator was not invoked | open |  | 2026-09-12T03:49:50.973Z |  |
| 24 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json |  | Plan56 allocation, local timing, and GitHub validation were prohibited after deterministic pre-allocation verifier contradictions | open |  | 2026-09-12T03:49:51.057Z |  |
| 25 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-57-PLAN.md |  | Plan57 sole allocation receipt records identity-preflight completion equal to parent-launch start while its first verifier requires strict precedence | open |  | 2026-09-12T04:17:45.542Z |  |
| 26 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json |  | Plan57 parser, local timing, and GitHub validation were prohibited after the no-retry Task1 receipt-order failure | open |  | 2026-09-12T04:17:45.653Z |  |
| 27 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-58-PLAN.md | 104 | Plan 58 cache harness requires a Plan 55 input schema while the approved Task 1 verifier requires a Plan 58 input schema | open |  | 2026-09-12T06:33:36.033Z |  |
| 28 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-58-PLAN.md |  | Plan 58 allocation, parser, Perl dry run, local timing, and GitHub validation were prohibited after the pre-allocation cache-harness schema contradiction | open |  | 2026-09-12T06:33:43.824Z |  |
| 29 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-59-PLAN.md | 233 | Plan 59 first Task 1 verifier constructs six label-mutant rows while the exact manifest harness produces seven and the verifier demands the seven-row digest | open |  | 2026-09-12T07:01:51.078Z |  |
| 30 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-59-PLAN.md |  | Plan 59 allocation, parser, Perl dry run, local timing, and GitHub validation were prohibited after the pre-allocation manifest label-ledger contradiction | open |  | 2026-09-12T07:01:51.153Z |  |
| 31 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-60-PLAN.md | 162 | Plan 60 first Task 1 verifier references schema_audit at source line 45 before defining it at source line 189 after the sole allocation | open |  | 2026-09-12T07:53:02.019Z |  |
| 32 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-60-PLAN.md |  | Plan 60 parser, Perl dry run, local timing, and GitHub validation were prohibited after the no-retry Task 1 verifier definition-order failure | open |  | 2026-09-12T07:53:02.106Z |  |
| 33 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-61-PLAN.md | 7 | Authenticated allocator exact two-key environment rejects five Apple Python injected toolchain variables before mktemp | open |  | 2026-09-12T13:38:26.075Z |  |
| 34 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json |  | Plan 61 allocation, parser, local timing, and GitHub validation were prohibited after the authenticated allocator child-environment hard stop | open |  | 2026-09-12T13:38:33.595Z |  |
| 35 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-62-PLAN.md | 213 | Plan 62 embedded Task 2 verifier decodes to 40,816 bytes/SHA a4239aa7 instead of required 40,372 bytes/SHA a0fea47f after the sole allocation | open |  | 2026-09-12T14:58:12.725Z |  |
| 36 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json |  | Plan 62 parser, Perl dry run, candidate/database, local timing, and GitHub validation were prohibited after the post-allocation Task 2 verifier identity contradiction | open |  | 2026-09-12T14:58:12.819Z |  |
| 37 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-63-PLAN.md | 138 | Plan 63 Task 1 tracer verify is the consumed one-shot allocator chain, so the mandatory tracer feedback rerun would violate exact launcher/allocator/root budgets | open |  | 2026-09-12T15:29:21.919Z |  |
| 38 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json |  | Plan 63 Task 2 and live validation were prohibited because Task 1 produced no local/verify-task2.py and its tracer rerun was unsafe | open |  | 2026-09-12T15:29:22.011Z |  |
| 39 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-64-PLAN.md |  | Plan 64 Tasks 2-3 unrun: immutable collector requires absent /opt/homebrew/var/postgresql@16 disk path on PostgreSQL 14 host | open |  | 2026-09-12T16:42:28.441Z |  |
| 40 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-65-PLAN.md |  | Plan 65 Tasks 2-3 unrun: sole Task 1 finalizer halted before finalization because its pinned source omitted base64 import required by validate_host_path | open |  | 2026-09-12T19:14:58.557Z |  |
| 41 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-66-PLAN.md | 354 | Plan 66 Task 2 host gate compares process-relative Python 3.9 and system-wide Python 3.14 monotonic timestamps as one numeric epoch and rejects after consuming the nonce marker | open |  | 2026-09-12T20:05:21.548Z |  |
| 42 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json |  | Plan 66 collector, candidate/database, local timing, and GitHub validation were prohibited after the sole Task 2 host gate failed before publishing its receipt | open |  | 2026-09-12T20:05:21.633Z |  |
| 43 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-67-PLAN.md | 272 | Plan 67 sole dry-run command returned nonzero or emitted stderr after the authenticated host gate and 22 parser cases passed; the consumed wrapper/dry-run chain was frozen without retry | open |  | 2026-09-12T20:43:40.427Z |  |
| 44 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json |  | Plan 67 candidate database, admission, timing, terminal receipt, and all GitHub validation remained prohibited after the sole dry-run gate failed | open |  | 2026-09-12T20:43:40.536Z |  |
| 45 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-68-PLAN.md | 135 | Plan 68 execute launcher called undefined nodup while validating the authenticated bytecode probe after the sole allocator created its root; the consumed launcher/driver/allocator chain was frozen without retry | open |  | 2026-09-12T22:22:53.807Z |  |
| 46 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json |  | Plan 68 finalizer, Task 1 verifier, all Task 2 local/database/timing actions, terminal PASS, and all Task 3 GitHub validation remained prohibited after the execute launcher failed post-allocation | open |  | 2026-09-12T22:22:53.885Z |  |
| 47 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-69-DRY-RUN-FAILURE.json | 1 | Plan 69's sole dry run failed before psql launch because the blanket backslash ban rejected the authenticated E-string tab sentinel; the consumed root and all Plan 69 actions must never be retried or reused | open |  | 2026-09-13T02:51:01.729Z |  |
| 48 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-71-LOCAL-FAILURE.json | 1 | Plan 71 source reconstruction failed after its sole allocation because the expected committed Plan 68 health_sql_base64 element was absent; the consumed root must never be retried or reused | open |  | 2026-09-13T03:47:11.551Z |  |
| 49 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json |  | Plan 71 local source/database/timing chain and every network/GitHub validation remained prohibited after post-allocation source reconstruction failed | open |  | 2026-09-13T03:47:11.642Z |  |
| 50 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-72-LOCAL-FAILURE.json |  | Plan 72 sole local chain failed at the exact-six scaffold command after three green timing pairs; root is frozen and retry is forbidden. | open |  | 2026-09-13T04:33:55.397Z |  |
| 51 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-72-PLAN.md |  | Plan 72 remote capture and final verification were not run because the local terminal prerequisite failed. | open |  | 2026-09-13T04:33:55.527Z |  |
| 52 | 235.1 | deviation | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-76-PLAN.md |  | Plan 76 sole local chain froze after a green repeat timing child emitted no receipt at the non-allowlisted formatter path; retry is forbidden. | open |  | 2026-09-13T13:58:38.044Z |  |
| 53 | 235.1 | unrun-verify | .planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-76-PLAN.md |  | Plan 76 exact-six, terminal, GitHub capture, validation, and final verification were not run because the one-shot local prerequisite failed. | open |  | 2026-09-13T13:58:38.159Z |  |

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
    "resolved_at": null
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
    "resolved_at": null
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
    "resolved_at": null
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
    "resolved_at": null
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
    "resolved_at": null
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
    "resolved_at": null
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
    "resolved_at": null
  },
  {
    "id": 13,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-49-PLAN.md",
    "line": null,
    "description": "Exact Plan 49 allocator location-bearing AST digest differs under mandated /usr/bin/python3 3.9.6; no allocator invocation occurred",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-11T21:58:14.807Z",
    "resolved_at": null
  },
  {
    "id": 14,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-51-PLAN.md",
    "line": null,
    "description": "Plan 51 persistent root nlink=2 contract fails after exclusive marker creation; live root nlink is 3",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-11T23:52:23.970Z",
    "resolved_at": null
  },
  {
    "id": 15,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-52-PLAN.md",
    "line": null,
    "description": "Plan 52 Task 1 verifier requires expected_authority.plan51 and later requires exact expected_authority equality to a closed object that omits plan51",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T00:25:02.798Z",
    "resolved_at": null
  },
  {
    "id": 16,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json",
    "line": null,
    "description": "Plan 52 Task 2 local timing and Task 3 GitHub validation were prohibited after the no-retry Task 1 contradictory verifier halt",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T00:25:02.890Z",
    "resolved_at": null
  },
  {
    "id": 17,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-53-PLAN.md",
    "line": null,
    "description": "Plan 53 consumed dry-run environment verifier failed before collector-tests receipt; no retry or downstream action occurred",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T01:10:19.006Z",
    "resolved_at": null
  },
  {
    "id": 18,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json",
    "line": null,
    "description": "Plan 53 candidate, admission, timing, and GitHub validation were prohibited after the consumed dry-run environment hard stop",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T01:10:19.097Z",
    "resolved_at": null
  },
  {
    "id": 19,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-54-PLAN.md",
    "line": null,
    "description": "Plan 54 Task 1 selects full Plan 53 descendant rows but requires the reduced cache-manifest byte count and digest; allocator was not invoked",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T01:46:46.219Z",
    "resolved_at": null
  },
  {
    "id": 20,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json",
    "line": null,
    "description": "Plan 54 allocation, local timing, and GitHub validation were prohibited after the pre-allocation cache-schema contradiction",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T01:46:46.324Z",
    "resolved_at": null
  },
  {
    "id": 21,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-55-PLAN.md",
    "line": null,
    "description": "Approved Plan55 reuses Plan54 allocator AST digest although the Plan55 literals changed; both pinned runtimes derive 90651ac4 instead of ad6595a0",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T02:45:29.763Z",
    "resolved_at": null
  },
  {
    "id": 22,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-55-PLAN.md",
    "line": null,
    "description": "Plan55 Tasks 2-3 were not run after the no-retry Task1 authority gate failed",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T02:45:29.868Z",
    "resolved_at": null
  },
  {
    "id": 23,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-56-PLAN.md",
    "line": null,
    "description": "Plan56 canonical sorted expected-authority JSON cannot satisfy the verifier non-sorted key tuple; allocator was not invoked",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T03:49:50.973Z",
    "resolved_at": null
  },
  {
    "id": 24,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json",
    "line": null,
    "description": "Plan56 allocation, local timing, and GitHub validation were prohibited after deterministic pre-allocation verifier contradictions",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T03:49:51.057Z",
    "resolved_at": null
  },
  {
    "id": 25,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-57-PLAN.md",
    "line": null,
    "description": "Plan57 sole allocation receipt records identity-preflight completion equal to parent-launch start while its first verifier requires strict precedence",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T04:17:45.542Z",
    "resolved_at": null
  },
  {
    "id": 26,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json",
    "line": null,
    "description": "Plan57 parser, local timing, and GitHub validation were prohibited after the no-retry Task1 receipt-order failure",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T04:17:45.653Z",
    "resolved_at": null
  },
  {
    "id": 27,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-58-PLAN.md",
    "line": 104,
    "description": "Plan 58 cache harness requires a Plan 55 input schema while the approved Task 1 verifier requires a Plan 58 input schema",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T06:33:36.033Z",
    "resolved_at": null
  },
  {
    "id": 28,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-58-PLAN.md",
    "line": null,
    "description": "Plan 58 allocation, parser, Perl dry run, local timing, and GitHub validation were prohibited after the pre-allocation cache-harness schema contradiction",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T06:33:43.824Z",
    "resolved_at": null
  },
  {
    "id": 29,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-59-PLAN.md",
    "line": 233,
    "description": "Plan 59 first Task 1 verifier constructs six label-mutant rows while the exact manifest harness produces seven and the verifier demands the seven-row digest",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T07:01:51.078Z",
    "resolved_at": null
  },
  {
    "id": 30,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-59-PLAN.md",
    "line": null,
    "description": "Plan 59 allocation, parser, Perl dry run, local timing, and GitHub validation were prohibited after the pre-allocation manifest label-ledger contradiction",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T07:01:51.153Z",
    "resolved_at": null
  },
  {
    "id": 31,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-60-PLAN.md",
    "line": 162,
    "description": "Plan 60 first Task 1 verifier references schema_audit at source line 45 before defining it at source line 189 after the sole allocation",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T07:53:02.019Z",
    "resolved_at": null
  },
  {
    "id": 32,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-60-PLAN.md",
    "line": null,
    "description": "Plan 60 parser, Perl dry run, local timing, and GitHub validation were prohibited after the no-retry Task 1 verifier definition-order failure",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T07:53:02.106Z",
    "resolved_at": null
  },
  {
    "id": 33,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-61-PLAN.md",
    "line": 7,
    "description": "Authenticated allocator exact two-key environment rejects five Apple Python injected toolchain variables before mktemp",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T13:38:26.075Z",
    "resolved_at": null
  },
  {
    "id": 34,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json",
    "line": null,
    "description": "Plan 61 allocation, parser, local timing, and GitHub validation were prohibited after the authenticated allocator child-environment hard stop",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T13:38:33.595Z",
    "resolved_at": null
  },
  {
    "id": 35,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-62-PLAN.md",
    "line": 213,
    "description": "Plan 62 embedded Task 2 verifier decodes to 40,816 bytes/SHA a4239aa7 instead of required 40,372 bytes/SHA a0fea47f after the sole allocation",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T14:58:12.725Z",
    "resolved_at": null
  },
  {
    "id": 36,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json",
    "line": null,
    "description": "Plan 62 parser, Perl dry run, candidate/database, local timing, and GitHub validation were prohibited after the post-allocation Task 2 verifier identity contradiction",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T14:58:12.819Z",
    "resolved_at": null
  },
  {
    "id": 37,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-63-PLAN.md",
    "line": 138,
    "description": "Plan 63 Task 1 tracer verify is the consumed one-shot allocator chain, so the mandatory tracer feedback rerun would violate exact launcher/allocator/root budgets",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T15:29:21.919Z",
    "resolved_at": null
  },
  {
    "id": 38,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json",
    "line": null,
    "description": "Plan 63 Task 2 and live validation were prohibited because Task 1 produced no local/verify-task2.py and its tracer rerun was unsafe",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T15:29:22.011Z",
    "resolved_at": null
  },
  {
    "id": 39,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-64-PLAN.md",
    "line": null,
    "description": "Plan 64 Tasks 2-3 unrun: immutable collector requires absent /opt/homebrew/var/postgresql@16 disk path on PostgreSQL 14 host",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T16:42:28.441Z",
    "resolved_at": null
  },
  {
    "id": 40,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-65-PLAN.md",
    "line": null,
    "description": "Plan 65 Tasks 2-3 unrun: sole Task 1 finalizer halted before finalization because its pinned source omitted base64 import required by validate_host_path",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T19:14:58.557Z",
    "resolved_at": null
  },
  {
    "id": 41,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-66-PLAN.md",
    "line": 354,
    "description": "Plan 66 Task 2 host gate compares process-relative Python 3.9 and system-wide Python 3.14 monotonic timestamps as one numeric epoch and rejects after consuming the nonce marker",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T20:05:21.548Z",
    "resolved_at": null
  },
  {
    "id": 42,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json",
    "line": null,
    "description": "Plan 66 collector, candidate/database, local timing, and GitHub validation were prohibited after the sole Task 2 host gate failed before publishing its receipt",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T20:05:21.633Z",
    "resolved_at": null
  },
  {
    "id": 43,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-67-PLAN.md",
    "line": 272,
    "description": "Plan 67 sole dry-run command returned nonzero or emitted stderr after the authenticated host gate and 22 parser cases passed; the consumed wrapper/dry-run chain was frozen without retry",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T20:43:40.427Z",
    "resolved_at": null
  },
  {
    "id": 44,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json",
    "line": null,
    "description": "Plan 67 candidate database, admission, timing, terminal receipt, and all GitHub validation remained prohibited after the sole dry-run gate failed",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T20:43:40.536Z",
    "resolved_at": null
  },
  {
    "id": 45,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-68-PLAN.md",
    "line": 135,
    "description": "Plan 68 execute launcher called undefined nodup while validating the authenticated bytecode probe after the sole allocator created its root; the consumed launcher/driver/allocator chain was frozen without retry",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T22:22:53.807Z",
    "resolved_at": null
  },
  {
    "id": 46,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json",
    "line": null,
    "description": "Plan 68 finalizer, Task 1 verifier, all Task 2 local/database/timing actions, terminal PASS, and all Task 3 GitHub validation remained prohibited after the execute launcher failed post-allocation",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-12T22:22:53.885Z",
    "resolved_at": null
  },
  {
    "id": 47,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-69-DRY-RUN-FAILURE.json",
    "line": 1,
    "description": "Plan 69's sole dry run failed before psql launch because the blanket backslash ban rejected the authenticated E-string tab sentinel; the consumed root and all Plan 69 actions must never be retried or reused",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-13T02:51:01.729Z",
    "resolved_at": null
  },
  {
    "id": 48,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-71-LOCAL-FAILURE.json",
    "line": 1,
    "description": "Plan 71 source reconstruction failed after its sole allocation because the expected committed Plan 68 health_sql_base64 element was absent; the consumed root must never be retried or reused",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-13T03:47:11.551Z",
    "resolved_at": null
  },
  {
    "id": 49,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-VALIDATION-RUN.json",
    "line": null,
    "description": "Plan 71 local source/database/timing chain and every network/GitHub validation remained prohibited after post-allocation source reconstruction failed",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-13T03:47:11.642Z",
    "resolved_at": null
  },
  {
    "id": 50,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-72-LOCAL-FAILURE.json",
    "line": null,
    "description": "Plan 72 sole local chain failed at the exact-six scaffold command after three green timing pairs; root is frozen and retry is forbidden.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-13T04:33:55.397Z",
    "resolved_at": null
  },
  {
    "id": 51,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-72-PLAN.md",
    "line": null,
    "description": "Plan 72 remote capture and final verification were not run because the local terminal prerequisite failed.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-13T04:33:55.527Z",
    "resolved_at": null
  },
  {
    "id": 52,
    "kind": "deviation",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-76-PLAN.md",
    "line": null,
    "description": "Plan 76 sole local chain froze after a green repeat timing child emitted no receipt at the non-allowlisted formatter path; retry is forbidden.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-13T13:58:38.044Z",
    "resolved_at": null
  },
  {
    "id": 53,
    "kind": "unrun-verify",
    "phase": "235.1",
    "file": ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-76-PLAN.md",
    "line": null,
    "description": "Plan 76 exact-six, terminal, GitHub capture, validation, and final verification were not run because the one-shot local prerequisite failed.",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-13T13:58:38.159Z",
    "resolved_at": null
  }
]
````
