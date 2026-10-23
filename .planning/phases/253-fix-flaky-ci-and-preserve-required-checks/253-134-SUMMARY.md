---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "134"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, pull-request, github, operator-run, r11, halted]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: "253-133 R11 hosted canary (complete), FREEZE-R11/PUBLICATION-R11 (253-131), R11 reconciliation contract (253-132)"
provides:
  - "Committed docs_and_prs approval bound to the FREEZE-R11 section sha256 (f0e47f00...6ee2)"
  - "Committed PR freeze (offline --prepare, sha256 8c82430d...07e3) and self-contained operator runner (253-R11-PR-OPERATOR.sh, sha256 4d59c9d5...6108)"
  - "Runner-committed production PR allocation (120 requests / 3600 s, window 253-134-pr-window-1, 42 hosts, no results-receiver)"
  - "First live pr_create response: draft PR #337 (open, draft, mergeable null, mergeable_state unknown, base main at 09df342a)"
  - "Halted normal-family evidence and the PR HTTP ledger (7 of 120 requests)"
affects: ["253-135", "R12 gap-closure replan"]
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PR-ACTION-APPROVAL-R11.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PR-FREEZE-R11.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-R11-PR-OPERATOR.sh
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PR-ALLOCATION-R11.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PR-HTTP-LEDGER-R11.json
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-PR-NORMAL-EVIDENCE-R11.json
  modified: []
key-decisions:
  - "Halted honestly at normal-family run discovery. PR #337 was created exactly as approved, but both discovery reads (seq 6 and 7, about 61 s apart) returned total_count 0, so ci-pr-proof.sh stopped with 'no pull_request workflow run was discovered for the published head'. The probable cause, proven offline, is that the R11 candidate 2b239a98 sits on the stale server parent 84ebcea60 and conflicts with current main in five files. GitHub does not create pull_request runs for a conflicting PR. This is the fourth hermetic-vs-live blind spot: the PR fake always creates a run and never models mergeability or a moving main. No source edit, rerun, extra window or option choice."
requirements-completed: []
estimate: {tokens: 32000, tasks: 4}
actuals:
  tokens: 41000
  tasks: 4
  commits: 5
commits: 5
plan_head_before: ce381d66980a7bd4a5c52baf414abc2fdca7817d
plan_head_after: e0af2f9eba7cbf7a97c838541479fb5e9f7e9688
duration: 8min (approval commit 00:33:22Z to halt commit 00:41:47Z; hosted window 64 s of requests)
completed: 2026-10-19
status: halted
---

# Phase 253 Plan 134: Pull-request families (R11, operator-run) Summary

**Halted in the normal family, before any run existed. Under Jon's docs_and_prs approval, the runner committed the PR allocation, passed the pre-clock asserts, and the preflight read the rate limit, main's rules, the (absent) legacy protection and workflow 259268962. It then created draft PR #337 (`gsd/253-replan-r11-candidate` at `2b239a98` into `main`) exactly as approved. Both run-discovery reads, about 61 s apart, returned `total_count: 0`. ci-pr-proof.sh stopped with `no pull_request workflow run was discovered for the published head` and the runner committed the halted records (`e0af2f9eb`) and printed `STOP: normal family exit 1`. The window used 7 of 120 requests: six GETs and one POST. `remaining` was never run, so the docs refs were not published and there is no docs-only PR. The offline evidence points to merge conflicts: the candidate's parent is main from 2026-10-11, and GitHub's main has moved on.**

## Task 1: decision (orchestrator)

- Jon's verbatim selection was "Approve (Recommended)", with an empty note. It was collected via AskUserQuestion by the orchestrator at 2026-10-19T00:31:12Z (`decided_by`).
- **Approval record:** `253-LOAD-RECOVERY-PR-ACTION-APPROVAL-R11.json`, sha256 `b981f78372f19dfade61f25885666d44ee6445a3a371d6c0c9255594f1b5554f`, section `docs_and_prs`, section_sha256 `f0e47f00c63f2ac3b9e8ed3a560ba9d5d2148c31aa00234329e18e2d65646ee2`, rerun `expired`.
  - Head/base pairs: normal `gsd/253-replan-r11-candidate` → `main` (draft); docs-only `gsd/253-replan-docs-head` → `gsd/253-replan-docs-base` (draft).
  - Committed alone in `239ae74c6` at 00:33:22Z, before `window_wall_start_epoch` 1792370443 (00:40:43Z).

## Task 2: PR freeze and runner (executor)

- PR-FREEZE-R11 (sha256 `8c82430dfcec56b89c09b791b30f4915dde82e1e49a5f33c976188feade607e3`) committed alone in `ec6f5b550`. Its normal head is `gsd/253-replan-r11-candidate` at `2b239a98df72b8d47e8c4e03edf193905b3239da`, base `main`. Poll: `discovery_attempts` 2, `interval_seconds` 60, terminal_polls normal 15 / docs-only 12. `source.server_parent_sha` is `84ebcea60024c9e8caee405d55cad1c76b0e858a`.
- Runner `253-R11-PR-OPERATOR.sh`, sha256 `4d59c9d5fe822b0fbc622703738528622bc6e9eb49127f9f46bdb58688036108`, committed alone in `047a0ef97`. The self-check receipt in `.git` reads `SELF-CHECK OK head=047a0ef97035becaff6da2bb7d39a866eab8f9f4 runner_sha256=4d59c9d5…6108`.
- **Receipt gap (found in Task 2, still open).** The plan lists `253-LOAD-RECOVERY-PR-DOCS-PUBLICATION-RECEIPT-R11.json` as an output, and the runner stages it as `$R` "if it exists". But `ci-pr-proof.sh` has no argument or code path that writes it: its parser (lines 519-540) has no receipt output flag, and `grep -c -E 'DOCS-PUBLICATION|docs.publication.receipt|--receipt|--docs-receipt'` returns 0 (control: `--docs-evidence` is found at line 535). Even a successful `remaining` step would not have produced that receipt. Not fixed here.

## Task 3: live window (Jon ran step 1 of the runner himself)

Jon's relayed output:

```
== commit the PR allocation alone
bd466064f docs(253-134): declare the R11 PR production allocation
== pre-clock asserts (offline)
CLOCK STARTS 2026-10-19T00:40:39Z (normal family)
{"allocation_valid": true, ... "status": "freeze_valid"}
{"family": "normal", "notes": [], "requests": 7, "status": "stopped", "stop": "no pull_request workflow run was discovered for the published head"}
e0af2f9eb docs(253-134): halted R11 PR records (normal family exit 1)
STOP: normal family exit 1
```

- **Allocation:** `253-LOAD-RECOVERY-PR-ALLOCATION-R11.json`, sha256 `811a5d43d8d08f45ec3ec047eaddebcbaabde66972672ed7593384f4ff6ef5c7` (equal to the ledger's `allocation_sha256`). Live, production, 120 requests / 3600 s, max_hops 2, window `253-134-pr-window-1`, `source_sha256` equal to PR-FREEZE-R11. It lists 42 download hosts (pipelines.actions.githubusercontent.com plus productionresultssa0 through 40); results-receiver is absent (`index` null). Committed alone in `bd466064f` at 00:40:38Z, before the first request.
- **Halt records:** `e0af2f9eb` (00:41:47Z) adds exactly the PR ledger and the normal evidence. The evidence has `collection: {complete: false, notes: [], stop: "no pull_request workflow run was discovered for the published head"}`, `downloads: []`, `synthetic: false`, and an `action_approval` binding commit `239ae74c6`, sha256 `b981f783…`, section `docs_and_prs`, window start 1792370443. The ledger has `terminal_stop: null`, so the stop came from ci-pr-proof.sh (line 410), not from the transport.
- `remaining` was not run. `253-LOAD-RECOVERY-PR-DOCS-EVIDENCE-R11.json` and `253-LOAD-RECOVERY-PR-DOCS-PUBLICATION-RECEIPT-R11.json` do not exist (control: the normal evidence does).

## Ledger (decoded from committed bytes)

Times are seconds from the ledger's `started_monotonic_ns`.

| seq | category | route | method | status | start | note |
|---|---|---|---|---|---|---|
| 1 | preflight | rate_limit | GET | 200 | 0.00 | |
| 2 | preflight | rules_main | GET | 200 | 0.38 | |
| 3 | preflight | branch_protection | GET | 404 | 0.87 | |
| 4 | preflight | workflow | GET | 200 | 1.35 | id 259268962, name CI, path .github/workflows/ci.yml, state active |
| 5 | pr_create | pr_create | POST | 201 | 1.76 | PR #337 |
| 6 | run_discovery | workflow_runs | GET | 200 | 3.20 | `?event=pull_request&head_sha=2b239a98…&per_page=100`, total_count 0 |
| 7 | run_discovery | workflow_runs | GET | 200 | 63.74 | same URL, total_count 0 |

- Seq 7 started 61.98 s after seq 5 started (60.6 s after it ended), which matches one 60 s `sleep()` between the two discovery attempts (`ci-pr-proof.sh:400-410`).
- The last request ended 64.23 s after the first. Wall clock: CLOCK STARTS 00:40:39Z, window start 00:40:43Z, PR `created_at` 00:40:45Z, seq-7 response `date` 00:41:47 GMT, halt commit 00:41:47Z.
- **Seq 5 response body (15520 B decoded):** number **337**, state `open`, draft `true`, merged `false`, mergeable `null`, mergeable_state `"unknown"`, html_url https://github.com/szTheory/sigra/pull/337, title "Phase 253 normal CI proof (draft, do not merge)". Head `gsd/253-replan-r11-candidate` at `2b239a98df72b8d47e8c4e03edf193905b3239da`; base `main` at **`09df342a82e03c3d5d40173c912b70e827f7eadc`**. Both repos are `szTheory/sigra`. The response `location` header is `/repos/szTheory/sigra/pulls/337`.
- **Seq 6 and 7 bodies:** both `{"total_count":0,"workflow_runs":[]}` (36 B). Control: the same decode of seq 4 gives the full workflow object.

## Requests by category (7 of 120)

| Category | Used / limit |
|---|---|
| preflight | 4/8 |
| pr_create | 1/2 |
| run_discovery | 2/4 |
| pre_watch_rate | 0/2 |
| terminal_polls | 0/27 |
| attempt_jobs | 0/4 |
| pr_identity | 0/8 |
| native_checks | 0/4 |
| artifact_metadata | 0/4 |
| artifact_downloads | 0/20 |
| failure_logs | 0/2 |
| docs_publication | 0/14 |
| infrastructure_rerun | 0/21 (expired) |

Elapsed: 64 s of requests; the halt was committed 68 s after CLOCK STARTS. Jobs: 0 (no run).

## GitHub actions actually performed

- **Methods:** 6 GET and exactly 1 POST (`POST /repos/szTheory/sigra/pulls`, seq 5). No PUT, PATCH or DELETE. All 7 hosts are `api.github.com`; none is results-receiver.
- **The one POST matched the approval.** Its request body is not stored, but it reconstructs exactly from the recorded sha256 and length. The compact JSON `{"title":"Phase 253 normal CI proof (draft, do not merge)","head":"gsd/253-replan-r11-candidate","base":"main","body":"Draft proof pull request; never merged.","draft":true}` is 173 B with sha256 `4f3f0496…5f25`, equal to the ledger. Control: the sorted-keys form gives a different hash (`6c656b2a…`). The body is the approval's `approved_pr_body.body`, and the title and pair match the approval.
- **No merge, push, ref creation or deletion.** URL counts across the ledger: `git/refs` 0, `git/trees` 0, `git/commits` 0, `/merge` 0, `rerun` 0, `replan-docs` 0, `replan-r8`/`r9`/`r10` 0. Control: `pulls` matches 1 (seq 5). The docs refs `gsd/253-replan-docs-base` and `gsd/253-replan-docs-head` were never created.
- **Left on GitHub for Jon:** PR #337 stays open as a draft. The r8, r9, r10 and r11 scoped refs remain. No agent closes or deletes anything.

## Diagnosis (read-only, from committed bytes and local git objects)

1. **Ledger sequence: confirmed.** See the table above. seq 1 rate_limit 200, 2 rules_main 200, 3 branch_protection 404, 4 workflow 200 (CI, `.github/workflows/ci.yml`, active), 5 pr_create 201, 6 and 7 workflow_runs 200 with total_count 0, about 61 s apart. PR-FREEZE-R11 has `poll.discovery_attempts` 2 and `interval_seconds` 60.
2. **The PR: confirmed.** Seq 5 is #337, open, draft, mergeable null, mergeable_state unknown; head at `2b239a98`, base main at `09df342a`. `git cat-file -t 09df342a…` fails, so that commit is not in the local object store (control: `git cat-file -t 4ff6c50e4` returns `commit`). Local `origin/main` is `4ff6c50e4c6122ed8f27e67473f3b6408b3aaa97` (2026-10-11 10:13 -04:00, "Capture admin-eval registration failure diagnostics").
3. **Triggers: confirmed.** In the candidate's `ci.yml` (blob `072a1ea3…`, equal to PR-FREEZE-R11 `normal.workflow_blob`), lines 34-35 are `pull_request:` / `branches: [main]`. There is no `types:` anywhere in the file (`grep -c` 0; control: `branches:` lines exist at 33 and 35). Draft PRs therefore trigger on `opened`.
4. **Stale publication parent: confirmed.** `2b239a98` ("Phase 253 frozen CI candidate", 2026-10-17T07:37:24Z) has the single parent `84ebcea60` ("fix(ci): read observer workflow names from metadata (#325)", 2026-10-11 07:40:43 -04:00). PUBLICATION-R11 and PR-FREEZE-R11 both carry `server_parent_sha` 84ebcea60. Row 1 of the R8 and R9 canary ledgers is `git_get_commit` on that same SHA, so the parent was taken from earlier windows and never re-read. `git log 84ebcea60..origin/main` lists #326 (release 1.7.1), #327, #329, #328 (release 1.7.2) and `4ff6c50e4`. **Not confirmed offline:** that `09df342a` is the #332 CI quick-wins squash. That rests on the orchestrator's account; no local object or record names it. The local branch `ci/efficiency-quick-wins` (`6567a62e3`, equal to its origin ref) has three CI commits on top of origin/main.
5. **Merge test: confirmed.** `git merge-tree --write-tree --name-only 2b239a98 4ff6c50e4` exits 1 with 5 CONFLICTs: `.release-please-manifest.json`, `CHANGELOG.md`, `doc/llms.txt`, `mix.exs` and `test/example/priv/playwright/tests/admin-eval.spec.ts`. The same five appear against `ci/efficiency-quick-wins`. Positive control: against `84ebcea60` it exits 0 with 0 conflicts (the merge base is 84ebcea60 in both cases). Real main at `09df342a` was not tested because the object is absent. It descends from the conflicting history only if the orchestrator's account in point 4 is right.
6. **Why no run: inferred, not proven.** GitHub does not create `pull_request` workflow runs while a PR has merge conflicts, because the run needs the test merge commit. The seq-5 response's `mergeable: null` / `"unknown"` is GitHub's normal value right after creation and says nothing either way. This is the probable cause.
7. **Alternative explanation: still open.** Run creation took longer than about 61 s. The conflict evidence makes this unlikely, but two discovery attempts cannot exclude it.
8. **Can't be checked offline:** the live mergeable state of #337. Jon can see it in the browser at https://github.com/szTheory/sigra/pull/337 ("This branch has conflicts that must be resolved" would confirm point 6). No agent request was made.
9. **Blind spot #4: confirmed.** In `ci-pr-proof.test.sh`, the fake's `workflows/259268962/runs` handler (lines 186-192) returns the family's run on the second discovery whenever the PR was created, and its PR-create handler (lines 220-234) sets `base.sha` to `server.parent_sha`, the same stale parent. `grep -rl mergeable scripts/ci/` finds nothing (control: `pull_request` appears 5 times in the test). The fake never models mergeability or a moving main, and PR creation does not compare `base.sha` with the frozen parent. The earlier blind spots were #1 the 253-104 redirect host, #2 the 253-113 run-name and #3 the 253-122 log host.

## First real PR-route shapes compared with the R11 audit

- **pr_create** (audit row `shape-pr_create`, `justified`, no real sample): every compared field is present with the expected type (number, draft, merged, state, head/base ref, sha and repo.full_name, status 201). The real create response also carries `mergeable: null` and `mergeable_state: "unknown"`, which the audit does not list. Its residual risk ("the window halts with one open draft PR … that must be closed by the operator") is what happened, though through run discovery rather than check_pr.
- **workflow_runs** with `event=pull_request` (audit row `shape-workflow_runs`, real-shape-test on canary R8/R9 samples): the empty-result shape is `{"total_count":0,"workflow_runs":[]}`. That is consistent with the audited shape, but no populated pull_request run list was observed.
- **pr_read, compare, repo_contents, attempt_jobs:** never reached; still unobserved live.

## Task 4: offline verification (this executor)

- **The verbatim Task 4 verify** (only the Task 4 `<verify>` line, extracted to a scratch script; offline only) exits 1. `--check-only` passes first (`freeze_valid`, `network_requests: 0`). The first failing check is `hosted-gate-verify: FAIL: collection did not complete (an honest stop is preserved but never accepted)` on the normal evidence. The docs-only and pair checks cannot pass because the docs evidence does not exist.
- **Checks that apply to a halted window, run one by one:**
  - Pass: the allocation jq (window, live, production, 120, no results-receiver); the ledger jq (≤120 transactions, 0 on results-receiver, >0 on api.github.com); `--check-approval --section docs_and_prs` rc 0 (control: `--section canary` rc 1); ancestry approval `239ae74c6` → allocation `bd466064f` → ledger `e0af2f9eb`, rc 0 (control: ledger → approval rc 1); allocation commit has exactly 1 path; the node approval binding on the normal evidence alone, rc 0 (commit, sha256, section, committer time 1792370002 ≤ window start 1792370443; control: an exit-3 probe returned 3); `PRESERVATION-R11.sha256` (87 lines) rc 0; config.json sha256.
  - Not applicable (halt): the normal, docs-only and pair verifications and the two-document node binding.

## R11 canary is unaffected

253-133 (complete, `canary_verified`, 82/117 requests) is untouched by this plan. Its records are covered by `PRESERVATION-R11.sha256`, which still checks clean. The canary evidence stays valid for candidate `2b239a98`.

## What a replan needs (options, not chosen here)

- **A. R12 round: rebase or rebuild the candidate on current main.** This needs one approved read of main, a new FREEZE and PUBLICATION, and a new canary, because the canary evidence binds candidate `2b239a98`. Then the PR families.
- **B. R12 round with only a new normal head.** Freeze a merge commit of the candidate and current main as the normal PR head. Both the plan and the code require the head to equal the canary-published candidate, so this changes the D-16/D-23 contract.
- **C. Make the publication parent current main at freeze time,** and add a mergeability check to the PR preflight and to the fakes, so this fails before any request. Can be combined with A.
- **D. Jon dispositions the normal-PR evidence differently,** for example by changing the D-16 evidence contract.
- **Carry forward:** the docs publication receipt gap (Task 2 above); pr_read, compare, repo_contents and attempt_jobs still never observed live; `09df342a` not in the local object store, so any replan must read main first.

## Cleanup for Jon (manual, optional except the PR)

- Close draft PR #337: https://github.com/szTheory/sigra/pull/337. Do not merge it.
- Optional: delete the scoped refs `gsd/253-replan-r8-*`, `gsd/253-replan-r9-*`, `gsd/253-replan-r10-*` and `gsd/253-replan-r11-candidate` / `-fixture`. If you choose A or B, keep the r11 refs until the replan decides whether to reuse them.

## Commits

- `239ae74c6`: docs(253-134): record Jon's R11 docs_and_prs action approval
- `ec6f5b550`: docs(253-134): R11 PR freeze (offline --prepare)
- `047a0ef97`: docs(253-134): R11 PR operator runner (Jon runs the live steps)
- `bd466064f`: docs(253-134): declare the R11 PR production allocation (runner, Jon)
- `e0af2f9eb`: docs(253-134): halted R11 PR records (normal family exit 1) (runner, Jon)
- This SUMMARY: docs(253-134): halted SUMMARY (normal PR #337 got no pull_request run)

## Deviations from Plan

1. **Receipt gap (Task 2).** `ci-pr-proof.sh` never writes PR-DOCS-PUBLICATION-RECEIPT-R11. Recorded, not fixed.
2. **Otherwise as written.** The halt follows the plan's rule: no source edit, rerun or extra window. The offline `git merge-tree --write-tree` runs wrote tree objects only into `.git/objects` (no ref and no working-tree change). STATE, ROADMAP and REQUIREMENTS writers were skipped per the orchestrator's hard constraints.

## Remaining gaps

- **CIREL-02 stays open:** no pull_request family has been proven.
- **CIREL-01** stays partial under the 253-89 not_reproduced disposition.
- **253-135 is blocked** by this halt. Full Phase 253 verification stays not_started.

## Known Stubs

None.

## Self-Check: PASSED

- All six 253-134 records exist and are committed; the two docs records are absent, as expected for this halt.
- `239ae74c6`, `ec6f5b550`, `047a0ef97`, `bd466064f` and `e0af2f9eb` are ancestors of HEAD; `git rev-list --count ce381d669..e0af2f9eb` = 5.
- The tree is clean except config.json (sha256 `8e312f6ccd34…`). state.json is 70229 bytes, prefix `e45278c2cee0`. `scripts/ci/__pycache__` is absent.
