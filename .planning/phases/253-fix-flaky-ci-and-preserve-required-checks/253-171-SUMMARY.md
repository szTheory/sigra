---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "171"
status: halted
requirements-completed: []
---

# Plan 171: actual normal PR run failed; collector stopped on corrupted JSON

Jon replied verbatim **yes** to the prepared PR approval request. Codex recorded the new docs_and_prs approval and ran the committed runner, as explicitly requested. This superseded the historical Jon-only operator boundary for the exact prepared scope. Earlier canary approval was not reused.

Step 0 fetched main exactly once. Current main was 09df342a82e03c3d5d40173c912b70e827f7eadc, unchanged; the local merge preflight was clean with no conflicts. Approval 0d6d0c774, offline PR freeze c7d7b3988, runner e790d9a3f, preflight c1d7547dd, allocation 8d9266b44 were separate commits in that order. The real partial records were committed by the runner as 416b70f9b.

Draft [PR #338](https://github.com/szTheory/sigra/pull/338) was created, head gsd/253-replan-r13-candidate at d38f647ce573653a242fb42d0c5826aab92e5ed0, base main. GitHub started [run 39651372938](https://github.com/szTheory/sigra/actions/runs/39651372938), attempt 1, event pull_request. Its saved terminal response reports **failure**. No failed-job listing or logs were collected, so the CI failure cause is unknown. No CI success or required-check success is claimed.

After the failed run, pr_read succeeded. Transaction 19, compare, returned HTTP 200 with 1,239,711 original bytes. The redactor stored 1,232,709 bytes; that JSON is invalid at character 595495. A URL query in an escaped quoted test patch causes the raw-text regex to remove the backslash before the closing quote. A minimal offline reproduction against the unchanged transport independently fails at the same escaped-quote boundary. This is a collector defect separate from the actual CI failure.

The literal runner result was **STOP: normal family exit 1**, after JSONDecodeError. The initial evidence placeholder still contains zero embedded transactions and collection started; the ledger contains all 19 actual requests. Both exact records remain unchanged. The exact Task 4 verifier rejected the missing measured production ledger in that placeholder (VERIFY-EXIT 1), as required. No success record was manufactured.

Budget: **19/120 requests, 552.817/3600 seconds**, nine terminal polls, no retry or rerun. Rate checks reported 4886 and 4860 remaining; no rate-limit stop. The docs-only step never started; neither docs ref nor the docs draft PR was created. No merge, push, cleanup, deletion, protection change or new window occurred.

| Category | Used / limit |
| --- | --- |
| artifact_downloads | 0 / 20 |
| artifact_metadata | 0 / 4 |
| attempt_jobs | 0 / 4 |
| docs_publication | 0 / 14 |
| failure_logs | 0 / 2 |
| infrastructure_rerun | 0 / 21 |
| native_checks | 0 / 4 |
| pr_create | 1 / 2 |
| pr_identity | 2 / 8 |
| pre_watch_rate | 1 / 2 |
| preflight | 4 / 8 |
| run_discovery | 2 / 4 |
| terminal_polls | 9 / 27 |

Task 2 and Task 3 checks ended VERIFY-EXIT 0; Task 4 ended VERIFY-EXIT 1. The independent original regression ran three tests: two passed and the escaped-patch case raised JSONDecodeError. An isolated JSON-aware redaction candidate passed four offline checks, including escaped patches, secret removal, value/type preservation and unchanged header validation. This candidate is review material only: the frozen transport was not edited, no source was resealed, and it cannot turn this failed window into a pass. Files, hashes, exact logs and the candidate are in [253-171.json](../../execution/253-171.json) and its sibling folder.

The R13 audit's populated workflow discovery and pr_read shapes were observed. Main did not move. The tested comparison response exposed the redaction defect before source reads, job/check listings, artifacts or docs publication. Those later audit shapes remain unobserved. The >100-check refusal and moved/conflicted-main branches were not exercised. No paginated listing or download occurred in this window.

Starting HEAD 7b9f1aaf55f5db145b726ea81443e3ae18a56199 and exact config/state/HANDOFF hashes and byte counts are retained in entry.json; those files stayed unchanged throughout execution. Plan 179 receipt, Plan 180 history, all prior halts and all budgets remain unchanged. Plan 172 cannot execute: normal PR proof failed and docs-only PR proof is absent. Do not resume it or generate superseded summaries on this result.

Phase 253 verification remains not_started; CIREL-01 partial_not_reproduced and CIREL-02 unaccepted. Existing r8-r13 refs, draft PR #337 and new draft PR #338 remain for optional manual cleanup. No new numbered repair plan is needed: the next task is a bounded diagnosis of this existing failed run plus review of the reproduced local fix, without launching CI. The failed window remains historical and closed.
