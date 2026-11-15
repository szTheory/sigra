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

- Status: NOT YET APPROVED. PR #381 is left open. No merge, no `--admin`, no force, no
  `--delete-branch`.
- Required before the merge: all five required contexts green, then a plain-chat owner approval
  to squash-merge. After the merge, record the merge commit SHA on `origin/main` here and in the
  SUMMARY (Phase 261 is blocked until it is recorded).
