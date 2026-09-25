---
created: 2026-09-17
status: pending
title: Home-directory paths are already public in ten committed planning files
area: public-repo hygiene
severity: warning
source: phase 238 push-gate scrub (pre-push public-repo check)
files:
  - .planning/milestones/v1.47-phases/235-terminal-ratification-measured-not-read/235-15-EXECUTION-DIAGNOSTICS.md
  - .planning/milestones/v1.47-phases/235-terminal-ratification-measured-not-read/235-15-PLAN.md
  - .planning/milestones/v1.47-phases/235-terminal-ratification-measured-not-read/235-16-PLAN.md
  - .planning/milestones/v1.47-phases/235-terminal-ratification-measured-not-read/235-17-PLAN.md
  - .planning/milestones/v1.47-phases/235-terminal-ratification-measured-not-read/235-18-PLAN.md
  - .planning/milestones/v1.47-phases/235-terminal-ratification-measured-not-read/235-19-PLAN.md
  - .planning/milestones/v1.47-phases/235-terminal-ratification-measured-not-read/235-FAST-01-SOURCE-COMPLETE-DISPATCH-CORRELATION.json
  - .planning/milestones/v1.47-phases/235-terminal-ratification-measured-not-read/235-REVIEW.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-EVIDENCE.md
  - .planning/phases/236-flake-root-cause-reproduce-name-fix/236-RESEARCH.md
---

## Problem

`sigra` is a public repository. Ten committed planning files carry the literal absolute path
`/Users/<username>/...`, which discloses the operator's local account name. They are **already on
`origin/main`** — this is not a leak introduced by the phase 238 push, and the push-gate scrub
that found them explicitly separated "already public" from "newly introduced".

Counts at the time of discovery: `235-REVIEW.md` 10 occurrences, the five `235-1N-PLAN.md`
files 2 each, `235-15-EXECUTION-DIAGNOSTICS.md` 1, the `235-FAST-01-…json` correlation file 1,
`236-EVIDENCE.md` 3, `236-RESEARCH.md` 2.

One file in the same class, `237-RESEARCH.md` (15 occurrences), was **not** yet public and was
sanitized to `<REPO_ROOT>` in phase 238's push gate before the push. That is the template for
the fix here.

## Suggested fix

Rewrite each occurrence to `<REPO_ROOT>` (or a repo-relative path) in a single commit, exactly
as `237-RESEARCH.md` was rewritten. Then add the check to the standing pre-push surface so it
cannot recur — phase 237 already wrote a one-file version of this assertion with a positive
control, and the generalized form is:

```bash
! git grep -qE '/Users/[a-zA-Z0-9._-]+' -- . ':!*positive-control*'
# positive control: printf '/Users/example/x' | grep -qE '/Users/[a-zA-Z0-9._-]+'
```

The positive control is required: a bare "no output" from the guard is ambiguous between
"clean" and "the guard did not run".

Note the guard must not match the *intentional* occurrences — several planning files contain
`/Users/example/x` literals and `/Users/[a-zA-Z0-9._-]+` regexes **as** the scrub's own positive
controls, plus already-redacted forms like `/Users/<username>/` and `/Users/<redacted>/`. A
naive grep flags all of those. Scope the pattern to a real account name, or exclude the
control literals explicitly.

## Why it was not fixed in phase 238

Out of scope: these files belong to phases 235, 236 and the v1.47 milestone archive, not to
phase 238, and phase 238's mandate is the tag namespace. More importantly the content is
**already published** — editing the working tree now removes it from `HEAD` but not from the
public history, so the fix is a hygiene improvement rather than a containment action, and it
does not need to ride an unrelated phase's push. Rewriting public history to purge it is a
separate, larger decision that needs an explicit operator call.
