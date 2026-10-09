---
phase: 249-publish-and-prove-sigra-1-6-0
plan: 04
status: complete
completed_at: 2026-10-09T13:35:26Z
---

# Plan 249-04: Live Closeout Inventory and Dispositions

Captured and validated the current worktree, dirty-path, and open-PR populations. The ledger is [249-CLOSEOUT.json](249-CLOSEOUT.json); [validate-closeout.mjs](validate-closeout.mjs) re-reads GitHub and Git, checks full identities and content hashes, and rejects missing, duplicated, or partial inventories.

The complete snapshot was read at 2026-10-09 13:34:40–13:34:56 UTC and then revalidated live. It contains **5 worktrees**, **95 dirty paths**, and **14 open PRs**. Dirty-path distribution is 87 in the shared root checkout, 4 in the Phase 246 CI evidence worktree, and 4 in the Phase 246 verification worktree; the other two worktrees are clean. Every dirty path has its current status, content hash or explicit hashless state, owner, target, action, and blocker record.

All 14 PRs have one source-backed disposition. PRs **#302, #283, #275, and #219** are release-relevant; the other 10 (**#286, #285, #274, #273, #272, #271, #269, #268, #267, and #266**) are separate follow-ups. No PR is classified release-blocking. PR #302 is the Release Please 1.6.1 candidate; exact-head required CI and guarded auto-merge eligibility were not evaluated in this inventory and remain required before any merge.

The ledger’s inventory and disposition validators pass, but its closeout verdict remains **blocked** by 95 unverified preservation records. The shared root’s task-level ownership is unclear, and the two Phase 246 worktrees contain uncommitted evidence. Plan 05 must prove durable, path-scoped preservation before any of these worktrees can be called clean. No PR or worktree was modified during this plan.

Validation: `node --test .planning/phases/249-publish-and-prove-sigra-1-6-0/validate-closeout.test.mjs` — 16 passed; live `--mode inventory` — valid; live `--mode dispositions` — valid with 95 explicit blockers; `node --check` and `git diff --check` — passed.
