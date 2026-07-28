---
created: 2026-07-28T00:00:00.000Z
status: pending
title: Release Please orphans the hand-written `## Unreleased` block at every release — notes ship inside a released Hex package still labelled "Unreleased"
area: release
files:
  - CHANGELOG.md
  - release-please-config.json
source: 2026-07-28 quick 260728-glj — found while cutting release PR #83 for 1.4.0
---

## What

Release Please always inserts its generated version section **below** the hand-written
top block in `CHANGELOG.md` — never into it. The generated `## [X.Y.Z](...)` heading with
its `### Features` / `### Bug Fixes` subsections is prepended above the *previous* version
section, which puts it underneath whatever a maintainer has been accumulating under
`## Unreleased`.

The consequence is that hand-written entries are silently orphaned at **every** release
unless a human notices while the Release PR is still open and folds them in by hand. If
nobody notices, the release ships with:

- release notes that contain only commit-level `feat`/`fix` stubs, and
- the actual reader-facing summary sitting above them under a heading that says
  "Unreleased" — inside a package that is, by definition, released.

`CHANGELOG.md` is packaged into the Hex tarball (`.github/workflows/release-please.yml`
asserts `test -f sigra-hex-inspect/CHANGELOG.md`) and is listed in `mix.exs` docs
`:extras`, so it renders on HexDocs too. Once the release PR merges and the tag publishes,
the mistake is **permanent for that version**.

**Live instance, caught and hand-folded:** 1.4.0. The `## Unreleased` block held the entire
v1.46 adopter-experience summary (persisted platform-admin grants + `mix sigra.admin.*`
tasks, `sigra-auth-*` vocabulary, audit URL presets, scope-propagating sensitive
operations, generated-host Playwright coverage, the v1.46 upgrade guide) while the
generated `## [1.4.0]` section below it listed only phase-221 commit stubs plus the #113
`auth-ui` fix. Quick task `260728-glj` folded the block into the 1.4.0 section by hand
before PR #83 was merged. Provenance was unambiguous —
`git log --oneline v1.3.0..origin/main -- CHANGELOG.md` returned exactly one commit
(`40240903`), so 100% of the orphaned content belonged to the release being cut.

## Why the current mitigation is not a fix

Quick task `260728-glj` also added an HTML comment under `## Unreleased` warning the next
maintainer that Release Please inserts below the block and that anything written there must
be folded in by hand while the Release PR is open.

That is a **mitigation, not a fix**. It only helps a human who happens to read the raw
Markdown at the right moment in the release cycle. It is invisible in rendered HexDocs, it
is not enforced by CI, and it fails exactly in the scenario that matters — a maintainer
cutting a release quickly, or a release cut by automation with a rubber-stamp merge. The
failure mode is silent and the blast radius is a permanently published artifact.

## Real fix options

### Option 1 — Make the tool place the notes

Configure Release Please so generated notes land in the right place, or so the
hand-written convention is expressed in a form the tool understands.

`release-please-config.json` currently sets **no** `changelog-sections` override, so the
defaults apply: only `feat` and `fix` commit types surface in generated notes; `docs`,
`chore`, `refactor`, `test`, `ci`, and `build` are hidden. That default is precisely what
makes a hand-written summary feel necessary in the first place — a milestone whose work
landed largely as `docs`/`chore` commits produces near-empty generated notes, so a human
writes prose above them, and the orphaning trap is set.

- **Pro:** keeps the curated, reader-facing summary that adopters actually want at the top
  of a release.
- **Con:** `changelog-sections` widens which commit types surface but does not by itself
  merge a free-form hand-written block into the generated section. Fully solving it likely
  means a custom changelog section config plus a release-PR CI check that fails when the
  `## Unreleased` block is non-empty on a release branch — i.e. new machinery to own.

### Option 2 — Drop the hand-written top-block convention entirely

Abandon `## Unreleased` as a prose staging area and put release-note content in
conventional-commit subjects and bodies, so the generated section is the only source of
release notes and there is nothing that *can* be orphaned.

- **Pro:** tool-guaranteed correctness. No human vigilance in the loop, no silent failure
  mode, no new CI guard to maintain. Aligns the changelog with the commit history that
  already gates the release.
- **Con:** trades the curated narrative summary for commit-level granularity. Milestone
  framing ("what v1.46 means for an adopter") has to be carried somewhere else — an
  upgrade guide, or deliberately-crafted `feat:` bodies — and every contributor now has to
  write commit subjects that read well as public release notes.

## Acceptance

Whichever option is chosen: a maintainer cutting a release PR **cannot silently ship
orphaned notes**. Either the tool places the hand-written content into the generated
version section, or a gate fails the release PR while content is still stranded, or the
convention is gone and there is nothing to place. A passing release lane must be
sufficient evidence that the published `CHANGELOG.md` is correct — reviewer attention must
not be the control.
