# Plan 260-04 gate ledger

Durable record of the two owner-approval gates for the park PR. The plan SUMMARY
(`260-04-SUMMARY.md`) is written only when the plan completes and folds this ledger in.
Approvals are plain-chat owner replies recorded verbatim; an agent message is never approval.

## Gate 1 (Task 2): push the branch and open the park PR

- Presented to the owner in chat: branch `ci/park-png-compare`, 4 commits, 6 files, title
  `ci: park PNG compare on pull_request and push`, the PR body file, and the push and PR commands.
- Owner reply, verbatim: `approved`
- Scope of the approval: the push of `ci/park-png-compare` and creating the PR only. It does not
  cover the merge.
- Pre-push re-verification: park worktree clean, tip `5e351ebea0890136f0fa945ec2e225266a2172da`,
  `origin/main` still `4cf5829eaa96973c064b9b32a215439ae200cf42`, no remote park branch, no PR.
- Executed: `git push -u origin ci/park-png-compare:ci/park-png-compare` (new branch, no force),
  then `gh pr create --base main --head ci/park-png-compare` with the title above and
  `--body-file 260-park-pr-body.md`.
- Result: PR #381, https://github.com/szTheory/sigra/pull/381, state OPEN, base `main`, head
  `ci/park-png-compare` at `5e351ebea0890136f0fa945ec2e225266a2172da`, not a draft, mergeable.

## Check status at open (single snapshot, not polled)

- Pending: Detect docs-only change, Fast checks, Release ref guard.
- Skipping: Install matrix, Nightly probe, Passkeys manual fallback smoke.
- None of the five ruleset-required contexts (Library tests, Example unit smoke, Install smoke,
  Example HTTP smoke, Example Playwright smoke) had been created yet at the snapshot; they sit
  downstream of the pending jobs.

## Gate 2 (Task 3): squash merge

- Presented to the owner in chat (by the orchestrator): PR #381, all five required checks green,
  squash merge with no `--admin`, no `--delete-branch`, no force, with the recommendation `merge`
  after stripping the stray "Suggested title:" first line from the PR body; the owner was asked to
  reply `merge`, `merge as-is` or `hold`.
- Owner reply, verbatim: `and then after that for all the things to open decisions, follow ur recs plz...`
- How it was read: the reply delegates to the presented recommendation, which was `merge` with the
  body line stripped first. The orchestrator relayed the verbatim reply and instructed that the
  resume signal be treated as `merge`; this executor did not see the chat itself. The approval
  covers only squash-merging PR #381 and that one body edit, nothing else.
- Re-verification just before the merge: PR #381 OPEN, base `main`, `mergeStateStatus` CLEAN,
  `mergeable` MERGEABLE, not a draft, head `5e351ebea0890136f0fa945ec2e225266a2172da` (unchanged).
  The five ruleset-required contexts were all `pass`, re-checked a second time after the body edit
  in case the edit had re-triggered a run (it had not):

  | Required context | Result | Duration |
  | --- | --- | --- |
  | Library tests | pass | 3s |
  | Example unit smoke (ExUnit + ConnTest) | pass | 55s |
  | Install smoke (fresh phx.new + sigra.install) | pass | 2m50s |
  | Example HTTP smoke (boot + curl critical routes) | pass | 47s |
  | Example Playwright smoke (full lifecycle) | pass | 2s |

  Every other check on the run was `pass` or `skipping`; none was `fail` or `pending`
  (`ci-gate` pass, the five Playwright shards pass, Release ref guard pass).
- Body edit: the first two lines (`Suggested title: ...` and the blank line) were removed. The
  edited body was written to a scratchpad file outside the repo and applied with
  `gh pr edit 381 --body-file`; the read-back is identical apart from a trailing newline that
  GitHub adds, and no `Suggested title` string remains.
- Executed: `gh pr merge 381 --squash` (exit 0). No `--admin`, no `--delete-branch`, no force, no
  auto-merge, no ruleset workaround; the ruleset did not block it.
- Result: PR #381 state MERGED at `2026-11-15T21:01:34Z`, title
  `ci: park PNG compare on pull_request and push`, squash merge commit
  `4154a913e6c31f54f357587553c0dc7846ebc915`.
- Merge commit SHA on `origin/main` (after `git fetch origin main`, `origin/main` advanced from
  `4cf5829ea` to this commit, which is exactly the squash commit):
  **`4154a913e6c31f54f357587553c0dc7846ebc915`**.
- Proof: `git merge-base --is-ancestor 4154a913e6c31f54f357587553c0dc7846ebc915 origin/main`
  exits 0. The squash commit has one parent (`4cf5829ea`, the base the park branch was cut from)
  and touches exactly the six planned files: `.github/workflows/ci.yml` (+6), `MAINTAINING.md`
  (+24), the three Playwright specs, and `test/sigra/planning/phase_260_png_park_contract_test.exs`
  (+406); 472 insertions, 1 deletion, no PNG, nothing under `lib/` or `priv/`.
- Left in place on purpose: branch `ci/park-png-compare` (remote and local) and the worktree
  `../sigra-park-png-compare` at `5e351ebea`. Nothing was deleted.
- Phase 261 is unblocked as far as this plan goes: the SHA is recorded. Plan 11 syncs the
  milestone branch with this commit.
