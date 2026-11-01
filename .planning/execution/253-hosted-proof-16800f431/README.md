# Hosted proof proposal for repaired source 16800f431

This is an offline proposal. It grants no permission, creates no allocation, and launches no CI. The source is `16800f4319cdd0e2554938071d4ebc48caa969ac`. PR338, its failed run39651372938, its19 charged requests and its closed120-request window remain unchanged. The old canary's85/117 requests and all other closed windows also remain unchanged.

The actual pinned source was rebuilt locally with the production publisher. All1,485 product paths, file modes and blob identities match. Its candidate tree `28924e64262e3a2acb8bc41278acd5f7b0102abc` equals the candidate tree whose library, metrics and docs checks passed in the repair report. This task checked identities and limits; it did not rerun those suites or treat their old-source hosted results as proof of this source.

| Object | Exact proposed identity |
|---|---|
| Candidate | `8e87e1dc2f28d6bbc4623d292fe143f2e005eeaa` |
| Canary fixture child | `e795647eaadaa99d4bb750daddfff21966ee4d92` |
| Docs base | `07950d542c3bb3d2bbb6e28c031eeaaedad47caa` |
| Docs head | `b30da458d48389b3e94e7cec6c69079f4d2449ad` |
| Locally available parent | `09df342a82e03c3d5d40173c912b70e827f7eadc` |

These objects were constructed in a disposable local Git directory. `publication-proposal.json` records their fixed timestamp, paths, hashes and reconstruction inputs. They have not been published; the parent has not been fetched and remote ref availability is unknown.

Proposed refs use `gsd/253-proof-16800f431-` followed by `candidate`, `fixture`, `docs-base` and `docs-head`. Each is create-only. An occupied ref or changed main stops the operation before publication; no forced update, silent rebase or changed proposal after approval.

| Separate proposed window | Request cap | Time cap | Work |
|---|---:|---:|---|
| Repaired-source canary |117|60 minutes|Six expected outcomes plus independent verifier; at most45 tiny jobs,7 dispatches,1 cancellation|
| Repaired-source draft PRs |120|60 minutes|One normal draft PR and one docs-only draft PR; docs publication at most14 requests|

These are proposed ceilings for new, separately identified windows. None is allocated or started. Category ceilings are copied explicitly into `proposal.json`; unused infrastructure retry categories remain disabled and cannot be reassigned. Reruns are zero. The canary publication projects19/24 requests and the largest tree body is2,092,801/2,097,152 bytes (4,351 bytes spare). The six immutable historical inputs are hash checked; the metrics fixture remains test-only. Original historical archive and baseline bytes are unchanged.

The canary cases are full-pass→success, docs-only→success, actual-failure→failure, missing-seam→failure, unexpected-skip→failure and cancelled→cancelled. The separate verifier must accept those actual results before either draft PR is created. Normal and docs-only results must show all five required checks with the correct work/skip behavior. No merge, cleanup, rerun or rules change is proposed. Every request, including failures, must be charged and saved. One watcher per run, at least60 seconds between polls; inspect the API limit first, stop at250 remaining or less, and honor any403/429 reset. Fetch a terminal summary once and failure logs only on failure.

## What must be prepared before approval

The current publisher accepts only legacy/r8–r13 ref pairs. Its closed-window wrappers and docs refs cannot execute this new identity safely. Do not edit the R13 freeze, supply its old approval, or run its old scripts. Prepare and test an isolated execution bundle under `.planning/` that binds these fresh refs and the unchanged product source. Its tests must reject old approval/allocation files, old refs, expired windows, source drift and changed action hashes. Record exact helper hashes and a complete action list before requesting approval. This remaining work is offline preparation, not a new numbered phase plan.

Only then can explicit approval bind the final bundle hash, these object identities and separate canary/PR windows. A fresh main fetch and remote checks belong after that approval, and a changed parent or occupied ref invalidates execution rather than selecting another ref automatically. The earlier yes responses apply to old windows only. No approval is requested by this task.

The broader example precommit warning at `/dev/mailbox` and the macOS Python3.9 timestamp limitation remain recorded in the repair report. Hosted outcomes remain unknown. CIREL-01 is still partial_not_reproduced, CIREL-02 is unaccepted, Plan172 is blocked and Phase253 verification has not started. The historical29 halts,80 completed plans and74 without summaries stay unchanged.

Next command:

```text
$gsd-quick "Phase 253: prepare and verify the offline execution bundle for .planning/execution/253-hosted-proof-16800f431/proposal.json; keep source 16800f431 and fresh refs; preserve all closed windows; no CI"
```
