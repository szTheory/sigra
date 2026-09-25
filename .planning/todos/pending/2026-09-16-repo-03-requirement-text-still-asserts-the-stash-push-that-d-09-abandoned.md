---
created: 2026-09-16T00:00:00.000Z
status: pending
title: REPO-03 is marked Complete but its text still asserts the stash push that D-09 deliberately abandoned
area: planning
severity: major
source: phase 237 orchestrator close-out
files:
  - .planning/REQUIREMENTS.md
---

## Problem

`.planning/REQUIREMENTS.md:43` reads:

> - [x] **REPO-03**: All 6 stashes are materialized as pushed refs and the 5 stale worktrees
>   removed **before** any branch deletion. No `git gc` runs anywhere in this milestone.

The stash clause is **not true and was never intended to become true.** Phase 237's decision
D-09 (`237-CONTEXT.md`) abandoned it outright: `origin` is the public sigra repository, 4 of the
6 stashes carry ~2,018 lines of home-directory paths, and a push to a public remote is
irreversible with respect to content (objects stay fetchable by SHA after the ref is deleted).
All 6 stashes remain local and untouched — the inverse of the sentence above. Re-observed at
phase close: `git stash list` → 6 entries; `git ls-remote origin 'refs/stash-archive/*'` → empty.

The worktree clause and the `git gc` prohibition ARE satisfied (6 worktree entries → 1; no gc,
reflog expire, or prune anywhere).

## Why this matters more than usual

The v1.48 CLEAN-BASELINE milestone exists because a green gate verified nothing. A requirement
checkbox marked Complete over text asserting a deliberately-not-done action is that same defect
in the requirements ledger: a reader who trusts `REQUIREMENTS.md` will believe the stashes are
archived on `origin` and that deleting them locally is therefore safe. It is not — under D-09
the local objects are the ONLY copy, which is why the `git gc` prohibition is load-bearing for
the rest of the milestone.

The supersession IS recorded correctly in `237-EVIDENCE.md`'s closing SC table and in
`237-GIT-OBJECT-SNAPSHOT.md`. Only `REQUIREMENTS.md` still carries the stale assertion.

## Suggested fix

Amend REPO-03's text so it states what was actually decided and done, and cite D-09 so the
reasoning survives — e.g. the worktree reduction plus an explicit "the stash-archival half is
deliberately not done per D-09; all 6 stashes remain local and un-backed-up, which is why the
`git gc` prohibition stands for the milestone." Keep it marked Complete: the requirement closed
by a deliberately exercised authorized option, not by omission.

Not done automatically at phase close because `REQUIREMENTS.md` is a ratified artifact and
rewriting a requirement's text is an operator decision, not an orchestrator one.
