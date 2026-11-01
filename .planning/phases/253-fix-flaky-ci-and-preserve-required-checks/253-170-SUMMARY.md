---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "170"
status: complete
requirements-completed: []
---

# Plan 170: actual hosted canary completed

Jon replied verbatim: **yes u can run it** to the prepared CI approval request. Codex recorded that direct reply in the standalone approval commit and ran both committed runner steps. This explicit instruction superseded the old plan's Jon-only execution boundary for this exact canary scope. No older approval was reused; the separate docs_and_prs actions remain unapproved.

The runner returned DONE step 1 and DONE step 2, both exit 0. The exact Task 2 verification and exact Task 4 offline verification each ended VERIFY-EXIT 0. Both Plan 168 offline gates and its 66-test audit are reused unchanged; no Plan 179 acceptance rerun occurred.

| Scenario | Run | Conclusion |
| --- | --- | --- |
| full-pass | 39646563957 | success |
| docs-only | 39646864198 | success |
| actual-failure | 39647090310 | failure |
| missing-seam | 39647319381 | failure |
| unexpected-skip | 39647556494 | failure |
| cancelled | 39647788924 | cancelled |
| separate verifier | 39648174669 | passed |

All six sources and the independent verifier were checked against the actual recorded GitHub responses. The first two passed; all deliberate rejection cases stayed non-green; cancellation was cancelled. No synthetic transport supplied these results.

Budget: **85/117 requests, 37/45 jobs, 832/3600 seconds**. Window 253-170-canary-window-1 started 2026-10-21T17:43:36Z; the runner finished at 17:57:29Z, before 18:43:36Z. Discovery wait 20 seconds, poll interval 60 seconds, remaining-step reservation 1860 seconds; only one watcher per run. Infrastructure retries and reruns: zero.

| Category | Used / limit |
| --- | --- |
| artifact_downloads | 10 / 12 |
| artifact_metadata | 6 / 7 |
| attempt_jobs | 7 / 7 |
| cancellation | 1 / 1 |
| dispatch | 7 / 7 |
| failure_logs | 6 / 6 |
| infrastructure_retry | 0 / 5 |
| pre_watch_rate | 7 / 7 |
| preflight | 7 / 16 |
| publication | 19 / 24 |
| run_discovery | 7 / 7 |
| terminal_polls | 8 / 18 |

The main check-run preflight read all 277 checks across exactly three contiguous 200 pages; the guard projected four pages, ceiling ten. All next links used api.github.com /repositories/1207487684/commits/09df342a82e03c3d5d40173c912b70e827f7eadc/check-runs. Requests were re-derived to approved /repos routes; no /repositories URL was requested. Per-name counts, link records, redirect groups and every record hash are in [253-170.json](../../execution/253-170.json).

First live observations from the R13 audit:
- check_runs-next-link-query-keys: both next links were accepted by the strict query-key and ordinal validator; query strings are deliberately scrubbed from retained ledger headers, so exact raw keys cannot be claimed from those bytes.
- check_runs-server-parent-pages-2-plus: pages two and three passed complete-source identity and duplicate-name checks. Actual per-name counts are retained in the execution JSON.
- check_runs-main-nightly-growth: actual 277, compared with the older 209 and conservative current four-page projection; no page/category limit hit.
- canary-failure_logs-zero-slack: exactly six log transactions served the three deliberate failures, all accepted; no seventh transaction was attempted. Refusal beyond the allocation remains an offline-tested limit.
- paginated-listing-two-page: jobs, artifacts and workflow discovery remained one page each; real extra pages remain unobserved. The historical seven-of-seven jobs limit was preserved, not renewed.

Live artifact downloads used trusted blob hosts and failure logs used the scoped results-receiver hop without token forwarding, verified by Task 4. Actual grouped hosts and counts are recorded in the execution JSON. The allocation, approval, evidence, ledger and publication receipt hashes are recorded there too.

Approval commit f06b2e182; runner de4b561c1; allocation 952ebb7a9; first results e01083692; final results 803a00620. Approval and allocation each committed alone before the first request. No lock file or dirty record remained after the runner. Starting HEAD and exact hashes/byte counts of config/state/HANDOFF are preserved in execution/253-170/entry.json and were unchanged throughout the window.

Historical halts, Plan 179's receipt and all Plan 180 history remain unchanged. The r8-r13 scoped refs and draft PR #337 remain on GitHub for optional manual cleanup; this task did not delete, reuse or modify older refs/PRs. No PR was created or merged in this window.

Phase 253 verification remains not_started. CIREL-01 remains partial_not_reproduced; CIREL-02 still needs the normal and docs-only draft PR evidence. Next existing plan is 171; command **$gsd-execute-phase 253 --gaps-only --wave 7**, conditional on its separate docs_and_prs approval. No progress command or new numbered repair plan is required.
