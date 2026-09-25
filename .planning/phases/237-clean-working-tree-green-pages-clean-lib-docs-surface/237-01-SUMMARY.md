---
phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface
plan: 01
subsystem: repo-hygiene
tags: [gitignore, exdoc, llms.txt, clean-tree, tracer]
status: complete
requires: []
provides:
  - reachable `.gitignore` negation for `doc/llms.txt` (D-06 form)
  - `/.gsd/` ignore rule
  - regenerated, committed `doc/llms.txt` at v1.5.0
affects:
  - .gitignore
  - doc/llms.txt
tech-stack:
  added: []
  patterns:
    - "gitignore directory-glob + root-anchored negation (`/doc/*` + `!/doc/llms.txt`)"
    - "`git check-ignore --no-index` + same-block positive control"
key-files:
  created: []
  modified:
    - .gitignore
    - doc/llms.txt
decisions:
  - "D-06 form implemented, not the roadmap's bare `!doc/llms.txt`"
  - "D-05 regenerate-and-commit the docs index in this phase"
  - "D-08 SC-1 verified by a literal clone; launch-pack contract run manually"
  - "D-02 the tracked `.log` and `.png` under the planning directory are deliberately kept"
metrics:
  duration: ~20m
  completed: 2026-09-16
actuals:
  tokens: 527
  tasks: 2
  commits: 2
commits: 2
plan_head_before: ab5c487d
---

# Phase 237 Plan 01: Clean Working Tree Tracer Summary

Made the repository's ignore surface honest end-to-end — a reachable `doc/llms.txt` negation,
an ignore rule for the 268-file agent scratch directory, and a regenerated docs index that a
`mix docs` can no longer dirty — verified by a literal fresh clone rather than a CI proxy.

## What Was Built

**Task 1 — ignore surface (commit `3bd51461`).** `.gitignore` now carries the D-06 working form:

```gitignore
# Where third-party dependencies like ExDoc output generated docs.
# `/doc/*` (not `/doc/`) because git never descends into an excluded directory, so a
# negation beneath the bare directory form is unreachable: the glob form is what makes
# the `!/doc/llms.txt` re-inclusion below actually take effect.
/doc/*
!/doc/llms.txt
```

plus one new root-anchored rule `/.gsd/` with a comment recording that it holds hundreds of
megabytes of CI artifacts, traces and logs that must never reach a public repository.

Nothing was deleted from disk. No `git clean`, no `git gc`, no `git reflog expire`, no prune.
The scratch directory still exists on disk with all 268 files intact — it is *ignored*, not removed.

**Task 2 — docs index (commit `36a9aa09`).** `mix docs` regenerated `doc/llms.txt`; the delta was
exactly the two drifts D-05 measured and nothing else:

- header `# Sigra v1.4.0` → `# Sigra v1.5.0` (matching `mix.exs` `@version "1.5.0"`)
- one added module row: `- [Sigra.Branding.Contrast](Sigra.Branding.Contrast.md): ...`

`git diff --stat` reported `1 file changed, 2 insertions(+), 1 deletion(-)` — no larger delta, so
no stop-and-report was triggered. Only `doc/llms.txt` was staged and committed; the rest of the
generated output directory is covered by the `/doc/*` rule from Task 1.

## Verification Results

All plan verify commands, run at final HEAD:

| Check | Result |
|-------|--------|
| `git check-ignore -q --no-index doc/llms.txt` exits 1 | PASS |
| positive control: `doc/index.html` and `.gsd/scratch/probe.log` both ignored | PASS |
| no `^?? \.gsd/` line in all-untracked status | PASS |
| control: `^!! \.gsd/` present in `--ignored` status | PASS (see deviation 1) |
| fresh `git clone` → empty all-untracked status, `doc/llms.txt` tracked, not ignore-matched in the clone | PASS |
| `mix docs` then `git diff --exit-code -- doc/llms.txt` | PASS (idempotent) |
| `mix deps.get && mix docs` **inside** a fresh clone leaves it clean | PASS |
| `doc/llms.txt` tracked AND contains `Sigra.Branding.Contrast` | PASS |

Negative/positive control discipline: the `Sigra.Branding.Contrast` grep was paired with a
control grep for an absent token (`Sigra.Branding.NoSuchModuleZZZ` → correctly absent), and the
`--ignored` status grep was paired with a pattern that must not match (`^!! \.nonexistent-zzz/`
→ correctly no match), so neither "it matched"/"it did not match" result rests on an unproven search.

## The Three Consumers (D-08 — honest coverage story)

| Consumer | Result | Coverage |
|----------|--------|----------|
| `test/sigra/planning/phase_148_evaluator_funnel_and_first_run_dx_test.exs` | 0 failures | **Runs under `mix ci`** |
| `test/sigra/planning/phase_149_launch_evidence_and_announcement_pack_test.exs` | 0 failures | **Runs under `mix ci`** |
| `scripts/ci/launch-pack-contract.sh` | exit 0, `==> launch-pack-contract: OK` | **Manual-only — no workflow caller** |

Both ExUnit modules ran together: `7 tests, 0 failures`.

`scripts/ci/launch-pack-contract.sh` is recorded as **manual-only with no workflow caller**
(known as FUT-04). It is *not* covered by `mix ci`. Confirmed at this HEAD:
`grep -rn "launch-pack-contract" .github/workflows/` → no match (rc=1), with the positive control
`grep -rln "scripts/ci/" .github/workflows/` returning three workflow files, proving the search ran
against a populated directory.

Precondition (live PostgreSQL per CLAUDE.md) was asserted before the ExUnit run:
`pg_isready` on the documented default port reported *accepting connections*, and a
`select 1` with the documented credentials returned `1`.

## D-02 Kept-Artifact Exception (deliberate, not undone)

The one tracked `.log` and one tracked `.png` under the planning directory are **deliberately
kept**, per D-02. Both remain tracked at this HEAD (`git ls-files --error-unmatch` succeeds for
both). REPO-01 is satisfied by there being **no tracked artifact of that class outside the
planning directory**, which is true today. The reason is the phase's own Out-of-Scope fence —
"no pruning the planning directory from the repo" — which outranks REPO-01's artifact clause.
This is a named, deliberate exception, not an item left undone.

## Deviations from Plan

**1. [Rule 1 — Bug] The `--ignored` positive-control verify command could never pass (SIGPIPE).**

- **Found during:** Task 1 verification.
- **Issue:** the plan's fourth verify command is
  `bash -c 'set -eo pipefail; out=$(git status ... --ignored); printf "%s\n" "$out" | grep -q "^!! \.gsd/"'`.
  `grep -q` exits as soon as it matches, closing the pipe; `printf` is then killed by SIGPIPE and,
  under `pipefail`, the pipeline returns **141**. The command therefore fails *precisely when the
  assertion succeeds* — it is unsatisfiable as written. Observed rc=141 directly.
- **Fix:** removed the pipe, not the assertion — `grep -q "^!! \.gsd/" <<< "$out"`. Same subject,
  same expectation, same strictness; no bound widened, no flag dropped, no control removed.
  Paired with a must-not-match control to prove the grep still discriminates.
- **Files modified:** none (verification command only).
- **Note:** the sibling third check (`! printf ... | grep -q`) is unaffected, because there grep
  finds nothing, so `printf` completes and no SIGPIPE occurs. That asymmetry is why only one of
  the two was latent.

**2. [Bookkeeping] `commits:` is 2, measured, and the naive HEAD range is contaminated.**

The per-plan commit ledger was not written before the first commit, so the count was measured
after the fact from the pre-plan HEAD `ab5c487d`. `git rev-list --count ab5c487d..HEAD` returns
**3**, but one of those (`06169df2`, `docs(237-02): record pre-change GitHub Pages configuration
and revert command`) belongs to sibling wave-1 plan 237-02 running concurrently on the same
branch. This plan's own commits are exactly two, by hash: `3bd51461` and `36a9aa09`. Reporting
the raw range count as this plan's total would be a narrated number, so the contaminated range is
disclosed rather than silently used.

No other deviations. No architectural changes, no package installs, no auth gates.

## Known Stubs

None.

## Threat Flags

None. This plan installed no packages, added no network surface, and changed no auth path.
The one trust-boundary item it touches — the public `origin` remote — moved in the safe
direction: a 660 MB directory of CI logs, traces and screenshots that was previously
*untracked and one `git add -A` away from disclosure* is now ignored by a root-anchored rule.

## Self-Check: PASSED

- `.gitignore` — FOUND, contains `/doc/*`, `!/doc/llms.txt`, `/.gsd/`, and no bare `/doc/` rule.
- `doc/llms.txt` — FOUND on disk and tracked (`git ls-files` prints the path).
- Commit `3bd51461` — FOUND in `git log`.
- Commit `36a9aa09` — FOUND in `git log`.
- `git reflog` still resolves; no garbage-collection, reflog-expiry, prune or `git clean`
  command was run at any point in this plan.
- Working tree at plan end: `git status --porcelain --untracked-files=all` is empty.
