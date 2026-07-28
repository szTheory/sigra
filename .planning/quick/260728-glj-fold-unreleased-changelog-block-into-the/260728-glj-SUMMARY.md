---
phase: quick-260728-glj
plan: 01
subsystem: release
tags: [changelog, release-please, hex, docs]
status: complete
requires:
  - "release PR #83 (origin/release-please--branches--main) as the branch base"
provides:
  - "1.4.0 Hex release notes that lead with the v1.46 adopter-experience summary"
  - "empty, warning-annotated ## Unreleased block for the next release cycle"
  - "pending todo capturing the systemic release-please orphaning footgun"
affects:
  - CHANGELOG.md
  - "HexDocs rendering of CHANGELOG.md (mix.exs docs :extras)"
tech-stack:
  added: []
  patterns:
    - "hand-written changelog summary sits above release-please-generated commit detail within the same version section"
key-files:
  created:
    - .planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md
  modified:
    - CHANGELOG.md
decisions:
  - "Folded the hand-written block INTO the 1.4.0 section rather than retitling ## Unreleased to ## [1.4.0] — release-please owns the generated heading and its compare link, and CI asserts the version/manifest pair."
  - "Ordered the 1.4.0 section summary-first (Added, Changed, Upgrade notes) then commit-level detail (Features, Bug Fixes)."
  - "Left ## Unreleased in place with an HTML maintainer warning plus a `_Nothing yet._` placeholder instead of deleting it, so the next cycle has a home and the footgun is annotated in-file."
  - "Reverted the doc/llms.txt drift produced as a side effect of running `mix docs` — it is pre-existing staleness unrelated to this edit and outside the plan's single-file blast radius."
metrics:
  duration: ~12 min
  completed: 2026-07-28
  tasks: 3
  commits: 2
  files_changed: 2
---

# Quick 260728-glj: Fold Unreleased Changelog Block Into 1.4.0 Summary

Moved the hand-written v1.46 adopter-experience block out of `## Unreleased` and into the
release-please-generated `## [1.4.0]` section, so the content ships as the 1.4.0 Hex
release notes instead of being published inside a released package still labelled
"Unreleased" — with both byte-conservation gates proving zero bullet text was lost or
altered.

## What Was Built

**Task 1 — CHANGELOG fold** (`6b085dae`)

The three hand-written subsections (`### Added`, `### Changed`, `### Upgrade notes`) now
sit under `## [1.4.0](https://github.com/szTheory/sigra/compare/v1.3.0...v1.4.0)
(2026-07-28)`, positioned above the generated `### Features` and `### Bug Fixes`. The
version heading is byte-identical to what release-please wrote. `## Unreleased` survives
directly above it, now carrying an HTML maintainer warning and a `_Nothing yet._`
placeholder.

The resulting git diff is 12 insertions / 2 deletions: git rendered the change as the
`## [1.4.0]` heading moving *up* past the hand-written subsections, so **not a single
bullet line appears as a +/- in the diff**. That is the strongest available evidence that
the move was verbatim.

**Task 2 — systemic todo** (`4bbf3f8e`)

`.planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md` records the
underlying behavior (release-please always inserts below the hand-written block, never into
it), cites 1.4.0 as the caught live instance, explicitly frames the new HTML comment as a
mitigation rather than a fix, and lays out both real fix options with tradeoffs —
(1) `changelog-sections` / changelog-config change plus a release-PR gate, noting that
`release-please-config.json` currently sets no override so only `feat`/`fix` surface, which
is what makes a hand-written summary feel necessary in the first place; and (2) dropping
the hand-written convention in favour of conventional-commit bodies so nothing *can* be
orphaned.

**Task 3 — local commits only** (see Commits below). Nothing pushed, no `gh` command run,
no PR touched, no tag created.

## Verification Results

All eight Task 1 automated checks matched their EXPECT values:

| # | Check | Result |
|---|-------|--------|
| 1 | Heading order | `Planning milestones` / `## Unreleased` / `## [1.4.0]` / `## [1.3.0]` — correct |
| 2 | 1.4.0 subsections | exactly 5: Added, Changed, Upgrade notes, Features, Bug Fixes — in order |
| 3 | Bullet conservation | 14 bullets in 1.4.0; 0 left in the top block |
| 4 | **Generated bullets byte-identical** | sorted `* ` set diffs **empty** vs `HEAD:CHANGELOG.md` (8 bullets) |
| 5 | **Hand-written bullets byte-identical** | sorted `- ` set diffs **empty** vs `HEAD:CHANGELOG.md` (6 bullets) |
| 6 | Heading + warning + placeholder | version heading ×1, `Release Please` ×1, `_Nothing yet._` ×1 |
| 7 | Blast radius | only `CHANGELOG.md` modified; `mix.exs` + `.release-please-manifest.json` diff-clean |
| 8 | `mix docs --warnings-as-errors` | **ran, exit 0, zero warnings** |

**`mix docs --warnings-as-errors` DID run** — `MIX_ENV=dev mix docs --warnings-as-errors`
completed with exit code 0 and zero occurrences of "warning" in its log. This is an
observed passing build, not an assumption.

Provenance was re-confirmed before editing, per the plan's `read_first`:
`git log --oneline v1.3.0..origin/main -- CHANGELOG.md` returned exactly one commit
(`40240903 v1.46: adopter experience + architecture & code-walkthrough guides (#104)`), so
100% of the folded content belongs to the release being cut.

Task 3 gates: two commits present, working tree clean apart from the untracked quick-task
directory the orchestrator owns, `git diff --stat HEAD~2 -- mix.exs
.release-please-manifest.json` empty, `git tag --points-at HEAD` empty.
`origin/release-1.4.0-changelog` **does not exist** (`git rev-parse` fatal), which proves
nothing was pushed; HEAD is exactly 2 commits ahead of its upstream
`origin/release-please--branches--main`.

The legacy bracketed `## [Unreleased]` heading (now line 434, below the 0.3.0 section) was
not touched.

## Deviations from Plan

### 1. [Rule 3 — Blocking issue] Reverted `doc/llms.txt` drift from the docs build

- **Found during:** Task 1, verify check 8.
- **Issue:** `mix docs` regenerated `doc/llms.txt`, which is a **tracked** file (not
  gitignored), dirtying the working tree with a 2-line change: `Sigra v1.3.0` →
  `Sigra v1.4.0` in the ToC header, and a new `upgrading-to-v1-46.md` entry.
- **Analysis:** this drift is **not caused by the CHANGELOG edit**. It is pre-existing
  staleness — the version line reflects release-please's `mix.exs` bump to 1.4.0, and the
  new guide entry came from commit `40240903`. The committed `doc/llms.txt` was already
  behind before this task started.
- **Fix:** `git checkout -- doc/llms.txt`. The plan's hard constraint is a single-file blast
  radius, and verify check 7 requires `git status --porcelain` to show only `CHANGELOG.md`.
- **Files modified:** none (revert restored the tracked state).
- **Out-of-scope note for the orchestrator:** the committed `doc/` build artifacts are stale
  relative to the 1.4.0 version bump. Not fixed here (out of scope, and `doc/` is a
  generated tree). Worth a separate decision on whether `doc/` should be tracked at all.

### 2. [Process] Commit ordering relative to the plan's task structure

- The plan placed both commits inside Task 3. The executor contract requires per-task atomic
  commits. Resolved by committing `CHANGELOG.md` at the end of Task 1 and the todo at the
  end of Task 2/3, using the plan's **exact prescribed messages and ordering**. End state is
  byte-identical to what the plan demands: two commits, `docs(changelog):` then
  `chore(planning):`.

### 3. [Process] Worktree branch-namespace guard not applicable

- The checkout is a linked worktree (`.git` is a file), so the executor's per-commit guard
  would normally require a `worktree-agent-*` branch. The orchestrator explicitly declared
  worktree isolation auto-degraded (`fork-ref-unknown`) and mandated that commits land on
  `release-1.4.0-changelog` at `b7523ebc`. HEAD matched that exactly, and the branch is not
  a protected ref (`main`/`master`/`develop`/`trunk`/`release/*`). Substituted an explicit
  branch-name assertion against the orchestrator's stated target before each `git add`.

No other deviations. No auth gates. No architectural (Rule 4) decisions required.

## Known Stubs

None.

## Threat Flags

None. Doc-only edit; no new network, auth, file-access, or schema surface. The registered
threats were all mitigated as planned: T-glj-01 and T-glj-02 by the two empty bullet-set
diffs, T-glj-03 by the diff-clean `mix.exs`/manifest assertion, T-glj-04 by the
no-push/no-`gh`/no-tag verification.

## Commits

| Hash | Message | Files |
|------|---------|-------|
| `6b085dae` | `docs(changelog): fold Unreleased block into the 1.4.0 release section` | `CHANGELOG.md` |
| `4bbf3f8e` | `chore(planning): file todo for release-please orphaning hand-written changelog notes` | `.planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md` |

Both local-only on `release-1.4.0-changelog`. The orchestrator retains sole publish
authority over PR #83.

## Self-Check: PASSED

- `CHANGELOG.md` — FOUND
- `.planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md` — FOUND
- Commit `6b085dae` — FOUND
- Commit `4bbf3f8e` — FOUND
