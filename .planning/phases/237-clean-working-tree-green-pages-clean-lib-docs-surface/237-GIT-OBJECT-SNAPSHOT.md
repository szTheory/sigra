# Phase 237 Plan 03 — Git Object Snapshot

Pre-prune inventory of `git worktree list` and `git stash list`, captured before any
mutating command ran in this plan. Recorded so the retirement below is provably
non-destructive: every SHA that existed before the prune is named here first.

## WORKTREE INVENTORY

Captured via `git worktree list --porcelain` before any prune/remove. The main
checkout's absolute path names the operator's home directory and this repository is
public, so the home-directory prefix is **redacted** below and replaced with the
placeholder `<REDACTED_HOME>`. The `/private/tmp/` entries carry no personal identity
and are recorded as-is.

| # | Path | HEAD SHA | Branch | State |
|---|------|----------|--------|-------|
| 1 | `<REDACTED_HOME>/projects/sigra` | `5f090285d394c8fb65dd2381915a87a19f09e6ca` | `main` | LIVE (main checkout) |
| 2 | `/private/tmp/sigra-chimeway-backport-62ceb46` | `b8d71e3af866dd5b3456610cdbfd9dd16904cfb5` | `fix/chimeway-opaque-recipient-backport-62ceb46` | live checkout, clean working tree — not reachable by `git worktree prune` alone (directory still present); retired via `git worktree remove` |
| 3 | `/private/tmp/sigra-chimeway-opaque-main` | `0000000000000000000000000000000000000000` | `fix/chimeway-opaque-recipient-main` | NULL HEAD — half-broken admin record; the branch is **unborn** (`git rev-parse --verify refs/heads/fix/chimeway-opaque-recipient-main` fails, no commit was ever made on it); not reachable by `git worktree prune` alone (directory still present); retired via `git worktree remove --force` |
| 4 | `/private/tmp/sigra-plan35.5RDe7U/candidate` | `a1f9e34af6c7e3df69f23c2d8669893c0afb179b` | (detached HEAD) | prunable — gitdir file points to non-existent location; retired by `git worktree prune` |
| 5 | `/private/tmp/sigra-plan35.5RDe7U/candidate-final` | `f179e3afc8b328849a3c12ba9c74abe1356d2664` | (detached HEAD) | prunable — gitdir file points to non-existent location; retired by `git worktree prune` |
| 6 | `/private/tmp/sigra-plan36.NlKLPW/candidate` | `0bf7b8e9369592f7781f2bc51a93d9db62e13483` | (detached HEAD) | prunable — gitdir file points to non-existent location; retired by `git worktree prune` |

**Deviation from the plan's literal tool choice, recorded here (Rule 1/3 — not
architectural):** the plan's action text names only `git worktree prune`. Live
verification showed only entries 4–6 are actually "prunable" in git's own sense
(their gitdir back-reference points to a directory that no longer exists — `git
worktree prune -n -v` confirms exactly those three and no others). Entries 2 and 3
still have real, existing directories on disk with valid `.git` back-references, so
`git worktree prune` — run alone — leaves them untouched and the "exactly one entry
remains" assertion would fail. This is a factual correction to the plan's premise
that all five were already-orphaned records; two were live-but-unwanted checkouts.

The fix uses `git worktree remove`, git's own native, non-destructive removal
command — never `rm -rf` on the directory first (the prohibition this plan actually
states). `git worktree remove` deletes the worktree's checkout directory and its
admin record together, atomically, and touches **no commit and no branch ref**:

- Entry 2 (`sigra-chimeway-backport-62ceb46`): `git status --short` inside the
  worktree was empty (clean tree) before removal — nothing uncommitted to lose.
  Removed with plain `git worktree remove` (no `--force` needed). The branch
  `fix/chimeway-opaque-recipient-backport-62ceb46` still exists locally at
  `b8d71e3a` and remotely on `origin` after removal — verified below.
- Entry 3 (`sigra-chimeway-opaque-main`): the branch is unborn (no commit ever
  landed on it — HEAD is the all-zeroes ref this plan's `<read_first>` flagged as
  the "half-broken admin record"), so `git status` inside it shows every file as a
  staged addition relative to no parent — an artifact of the unborn branch, not real
  uncommitted work. There is nothing to lose. Removed with `git worktree remove
  --force` because git refuses a plain remove on a dirty-looking tree; forced here
  with the reason recorded per the plan's own "do not use `--force` without
  recording why."

Neither removal deleted a branch or a commit — the plan's "No branch was deleted"
acceptance criterion holds for both.

## STASH INVENTORY — UNTOUCHED

This is a census of what is being **left alone**. It is not a prelude to an archive
step, a push, or a drop — see the `SC-3 STASH HALF` section below for why. Six
distinct stashes existed before this plan ran and all six still exist after it, with
identical commit SHAs (`git stash list` reports the same 6 entries at the top and
bottom of this plan).

```
STASH-ROW|0|089ced30df5f91ede6c97d7c63076da03758075b
STASH-ROW|1|9c959d2274aabee537a8d4ea97ce00cde4a72a18
STASH-ROW|2|b15f95edd6ee8dadb964829fe2b44b138028d320
STASH-ROW|3|2fc400fd196c08a923599ca4d11d5b353d247221
STASH-ROW|4|44e310947ce46140e059d25e453427471e8f4e51
STASH-ROW|5|a649b5affa184835eb835fc9e766331b65b446c7
```

Subjects are summarized rather than reproduced verbatim where a subject line could
carry a path (the full grep in D-09 of `237-CONTEXT.md` found ~2,018 home-directory
path lines across 4 of the 6 stash diffs, not in the subject lines themselves, but
this section stays deliberately terse): stash 0 is a pre-release workspace safety
snapshot; stashes 1–2 are broken/incomplete work-in-progress from an earlier phase
range; stashes 3–5 are per-worktree-agent WIP from earlier executor runs.
