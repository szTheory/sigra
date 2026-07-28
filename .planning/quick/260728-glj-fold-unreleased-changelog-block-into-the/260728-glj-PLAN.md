---
phase: quick-260728-glj
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - CHANGELOG.md
  - .planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md
autonomous: true
requirements: [QUICK-260728-glj]
must_haves:
  truths:
    - "The published 1.4.0 release notes contain the v1.46 adopter-experience summary (persisted platform-admin grants + mix sigra.admin.* tasks, sigra-auth-* vocabulary, audit URL presets, scope-propagating sensitive operations, generated-host Playwright coverage, v1.46 upgrade guide) rather than leaving it labelled Unreleased."
    - "Every generated Features / Bug Fixes bullet and commit link in the 1.4.0 section survives the edit byte-identically."
    - "Every hand-written bullet survives the edit byte-identically — moved, never reworded, reordered, or dropped."
    - "A maintainer cutting the next release PR is warned in-file that release-please inserts its generated section below the hand-written block."
    - "mix.exs and .release-please-manifest.json are untouched, so the release-please CI version/manifest assertions still pass."
  artifacts:
    - CHANGELOG.md
    - .planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md
  key_links:
    - "CHANGELOG.md is packaged into the Hex tarball (.github/workflows/release-please.yml 'Inspect packaged files' asserts test -f sigra-hex-inspect/CHANGELOG.md) — its state at merge of PR #83 is permanent for 1.4.0."
    - "CHANGELOG.md is listed in mix.exs docs :extras (line ~219), so mix docs renders it on HexDocs."
---

<objective>
Fold the hand-written `## Unreleased` block in `CHANGELOG.md` into the release-please-generated
`## [1.4.0]` section so the v1.46 content ships as part of the 1.4.0 Hex release instead of being
published inside a released package still labelled "Unreleased".

Purpose: release-please inserts each generated version section BELOW the hand-written `## Unreleased`
block rather than into it. Merging release PR #83 tags v1.4.0 and publishes to Hex with CHANGELOG.md
inside the tarball, so whatever this file says at merge time is permanent. Left as-is, 1.4.0 would
ship notes listing only phase-221 commit stubs plus the #113 fix, while the real headline content
stays orphaned above it.

Output: an edited `CHANGELOG.md` (doc-only, single file) plus one new pending todo recording the
systemic release-please footgun.

Scope guard — this plan does NOT: push, open a PR, merge a PR, or create a tag. The orchestrator
pushes to the existing release PR #83. The executor commits locally and stops.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@CHANGELOG.md

Verified facts from planning discovery (do not re-derive, but Task 1 re-confirms the git log):

- Branch is `release-1.4.0-changelog`, based on `origin/release-please--branches--main` (release PR #83).
- `git log --oneline v1.3.0..origin/main -- CHANGELOG.md` returns exactly ONE commit:
  `40240903 v1.46: adopter experience + architecture & code-walkthrough guides (#104)`.
  So 100% of the `## Unreleased` content is v1.46 work being released right now as 1.4.0.
- Current heading layout: line 8 `## Planning milestones vs Hex releases`, line 12 `## Unreleased`,
  line 29 `## [1.4.0](...) (2026-07-28)`, line 47 `## [1.3.0](...)`.
- Bullet discriminator: hand-written bullets start with `- `, release-please generated bullets start
  with `* `. The 1.4.0 region currently holds 6 hand-written bullets (2 Added, 3 Changed,
  1 Upgrade notes) and 8 generated bullets (2 Features, 6 Bug Fixes) = 14 after the fold.
- `CHANGELOG.md` IS in `mix.exs` docs `:extras` (~line 219), so `mix docs` covers it.
- `release-please-config.json` sets no `changelog-sections` override, so default sections apply:
  only `feat` and `fix` commits surface in generated notes; `docs`/`chore` are hidden.
- A second, legacy historical `## [Unreleased]` heading exists at ~line 424 (below the 0.3.0
  section). It is pre-release-please history and is OUT OF SCOPE.
</context>

<tasks>

<task type="tracer">
  <name>Task 1: Fold the hand-written block into the 1.4.0 section</name>
  <files>CHANGELOG.md</files>
  <precondition>Working tree is clean and HEAD is the release-1.4.0-changelog branch tip; `git show HEAD:CHANGELOG.md` must resolve for the before/after bullet-set diffs to work.</precondition>
  <read_first>
    Read `CHANGELOG.md` lines 1-50 once before editing. Then re-confirm the single-commit provenance
    claim with `git log --oneline v1.3.0..origin/main -- CHANGELOG.md` — it must print exactly one
    line (`40240903 ...`). If it prints more than one commit, STOP and report: the assumption that
    all hand-written content belongs to 1.4.0 no longer holds.
  </read_first>
  <action>
Edit `CHANGELOG.md` and nothing else. Four changes, all with the Edit tool (never a whole-file
rewrite, never a heredoc):

(a) Relocate the three subsections that currently sit under the top `## Unreleased` heading — the
`### Added`, `### Changed`, and `### Upgrade notes` headings together with their bullets — so they
sit under the `## [1.4.0]` heading, positioned ABOVE the generated `### Features` and
`### Bug Fixes` subsections. Move the bullet lines verbatim: identical characters, identical order
within each subsection, no rewording, no re-wrapping, no link rewriting. The three relocated
headings keep their relative order (Added, then Changed, then Upgrade notes). Rationale: the
hand-written subsections are the reader-facing summary; the generated ones are commit-level detail
underneath it.

(b) Preserve the `## [1.4.0](https://github.com/szTheory/sigra/compare/v1.3.0...v1.4.0) (2026-07-28)`
heading line byte-for-byte, and do not delete, reword, reorder, or relink any generated bullet under
`### Features` or `### Bug Fixes`.

(c) Leave the top-level `## Unreleased` heading in place directly above `## [1.4.0]`, now carrying no
subsections — just a placeholder italic line reading exactly: `_Nothing yet._` — so the next cycle
has a home for hand-written notes.

(d) Directly under that `## Unreleased` heading (above the placeholder line), add a maintainer
warning as an HTML comment, worded so a human hitting it at the next release understands the
required action. Use wording equivalent to: Release Please inserts each generated version section
BELOW this block; anything written here must be folded into the new version section by hand when the
Release PR is cut, or it will ship inside a released package still carrying this heading.

Do NOT touch `mix.exs` or `.release-please-manifest.json` — release-please owns both and CI verifies
them (`grep -nF "@version \"1.4.0\"" mix.exs` plus a manifest-match step). Do NOT touch the legacy
historical bracketed Unreleased heading further down the file (~line 424, below the 0.3.0 section).
Do not reflow, re-indent, or reformat any untouched line.
  </action>
  <verify>
    <automated>
# 1. Heading order at the top of the file
grep -n '^## ' CHANGELOG.md | head -4
# EXPECT, in order: Planning milestones vs Hex releases / ## Unreleased / ## [1.4.0](...) / ## [1.3.0](...)

# 2. The 1.4.0 section now owns exactly five subsections, in this order
awk '/^## \[1\.4\.0\]/{f=1;next} /^## \[1\.3\.0\]/{f=0} f && /^### /' CHANGELOG.md
# EXPECT exactly 5 lines: ### Added / ### Changed / ### Upgrade notes / ### Features / ### Bug Fixes

# 3. Bullet conservation: 14 bullets inside 1.4.0, 0 bullets left in the top block
awk '/^## \[1\.4\.0\]/{f=1;next} /^## \[1\.3\.0\]/{f=0} f' CHANGELOG.md | grep -cE '^[-*] '   # EXPECT 14
awk '/^## Unreleased$/{f=1;next} /^## \[1\.4\.0\]/{f=0} f' CHANGELOG.md | grep -cE '^[-*] ' || true   # EXPECT 0

# 4. Generated bullets byte-identical before vs after (generated bullets start with "* ")
git show HEAD:CHANGELOG.md | awk '/^## \[1\.4\.0\]/{f=1;next} /^## \[1\.3\.0\]/{f=0} f' | grep -E '^\* ' | sort > /tmp/glj-gen-before.txt
awk '/^## \[1\.4\.0\]/{f=1;next} /^## \[1\.3\.0\]/{f=0} f' CHANGELOG.md | grep -E '^\* ' | sort > /tmp/glj-gen-after.txt
diff /tmp/glj-gen-before.txt /tmp/glj-gen-after.txt   # EXPECT empty diff, exit 0

# 5. Hand-written bullets byte-identical after the move (hand-written bullets start with "- ")
git show HEAD:CHANGELOG.md | awk '/^## Unreleased$/{f=1;next} /^## \[1\.4\.0\]/{f=0} f' | grep -E '^- ' | sort > /tmp/glj-hand-before.txt
awk '/^## \[1\.4\.0\]/{f=1;next} /^## \[1\.3\.0\]/{f=0} f' CHANGELOG.md | grep -E '^- ' | sort > /tmp/glj-hand-after.txt
diff /tmp/glj-hand-before.txt /tmp/glj-hand-after.txt   # EXPECT empty diff, exit 0

# 6. Version heading intact byte-for-byte, and the maintainer warning + placeholder are present
grep -cF '## [1.4.0](https://github.com/szTheory/sigra/compare/v1.3.0...v1.4.0) (2026-07-28)' CHANGELOG.md   # EXPECT 1
grep -c 'Release Please' CHANGELOG.md   # EXPECT >= 1
grep -cF '_Nothing yet._' CHANGELOG.md  # EXPECT 1

# 7. Blast radius: only CHANGELOG.md changed by this task
git status --porcelain                                       # EXPECT only CHANGELOG.md (M)
git diff --quiet -- mix.exs .release-please-manifest.json && echo "release-please files untouched: OK"

# 8. Markdown still builds (CHANGELOG.md is in mix.exs docs :extras)
mix docs --warnings-as-errors
# If deps are not fetched or this is prohibitively slow, do NOT claim it passed. Fall back to a
# careful visual check of heading nesting and state IN THE SUMMARY, verbatim:
# "mix docs not run (<reason>); heading nesting checked visually only."
    </automated>
  </verify>
  <done>
    Checks 1-7 all match their EXPECT values; check 8 either passes or its stated fallback wording is
    recorded in the summary. The 1.4.0 section reads as summary-first (Added, Changed, Upgrade notes)
    followed by commit-level detail (Features, Bug Fixes), with zero bullet text lost.
  </done>
  <reversibility rating="reversible">Doc-only edit on a local branch; `git checkout -- CHANGELOG.md` restores it. It becomes one-way only at merge of PR #83, which this plan does not perform.</reversibility>
</task>

<task type="auto">
  <name>Task 2: File the systemic release-please footgun todo</name>
  <files>.planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md</files>
  <read_first>
    Read `.planning/todos/pending/2026-07-27-playwright-github-pages-publisher-red.md` once to copy
    the front-matter shape (`created`, `status`, `title`, `area`, `files`, `source`) and the
    What / Root cause / Options body rhythm.
  </read_first>
  <action>
Create one new pending todo recording the SYSTEMIC issue — not the one-off fix Task 1 just applied.

Front matter: `created: 2026-07-28T00:00:00.000Z`, `status: pending`, `area: release`, a `files:`
list naming `CHANGELOG.md` and `release-please-config.json`, and a `source:` line pointing at this
quick task (`2026-07-28 quick 260728-glj — found while cutting release PR #83 for 1.4.0`).

Body must state:
- WHAT: release-please always inserts its generated version section BELOW the hand-written top block
  in CHANGELOG.md, never into it. Hand-written entries are therefore silently orphaned at every
  release unless a human folds them in by hand while the Release PR is open — and if nobody notices,
  the notes ship inside a released Hex package still carrying the wrong heading. Cite 1.4.0 as the
  live instance that was caught and hand-folded (quick 260728-glj), and note CHANGELOG.md is
  packaged into the Hex tarball, so the mistake is permanent per release.
- WHY THE CURRENT MITIGATION IS NOT A FIX: the HTML comment added to CHANGELOG.md by this quick task
  only warns a human who happens to read the file at the right moment. It is a mitigation, not a fix.
- REAL FIX OPTIONS, with the tradeoff for each:
  1. A release-please changelog-section / changelog config change so generated notes land in the
     right place or the hand-written convention is expressed in a way the tool understands. Note
     that `release-please-config.json` currently sets NO `changelog-sections` override, so default
     sections apply (only `feat` and `fix` surface; `docs`/`chore` are hidden) — that default is
     what makes a hand-written summary feel necessary in the first place.
  2. Drop the hand-written top-block convention entirely in favour of conventional-commit bodies, so
     the generated section is the only source of release notes and nothing can be orphaned. Trades
     the curated reader-facing summary for tool-guaranteed correctness.
- ACCEPTANCE: whichever option is chosen, a maintainer cutting a release PR cannot silently ship
  orphaned notes — either the tool places them, or there is nothing to place.
  </action>
  <verify>
    <automated>
test -f .planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md && echo "todo exists: OK"
head -12 .planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md   # EXPECT front matter with status: pending
grep -c 'changelog-sections' .planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md   # EXPECT >= 1
grep -ci 'conventional-commit' .planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md # EXPECT >= 1
git status --porcelain   # EXPECT only CHANGELOG.md (M) and this todo file (??) — nothing else
    </automated>
  </verify>
  <done>
    The todo file exists with pending front matter, describes the systemic orphaning behavior (not
    just the 1.4.0 instance), explicitly frames the HTML comment as a mitigation rather than a fix,
    and lists both real fix options with their tradeoffs.
  </done>
</task>

<task type="auto">
  <name>Task 3: Commit locally — no push, no PR, no tag</name>
  <files>CHANGELOG.md, .planning/todos/pending/2026-07-28-release-please-orphans-unreleased-block.md</files>
  <action>
Stage and commit both files locally. Two commits, in this order:

1. `docs(changelog): fold Unreleased block into the 1.4.0 release section` — CHANGELOG.md only.
2. `chore(planning): file todo for release-please orphaning hand-written changelog notes` — the todo
   file only.

Use the `docs(` and `chore(` prefixes deliberately: `release-please-config.json` sets no
`changelog-sections` override, so default sections apply and neither prefix surfaces in a future
generated release section — this housekeeping will not pollute the next release's notes.

HARD STOP after committing. Do NOT run `git push`. Do NOT run any `gh pr` command (no create, no
edit, no merge). Do NOT create or move any git tag. The orchestrator owns pushing these commits to
the existing release PR #83.
  </action>
  <verify>
    <automated>
git log --oneline -2                     # EXPECT the two commits above, newest first
git status --porcelain                   # EXPECT empty (clean tree)
git diff --stat HEAD~2 -- mix.exs .release-please-manifest.json   # EXPECT empty output
git log origin/release-1.4.0-changelog..HEAD --oneline 2>/dev/null | wc -l
# EXPECT 2 if the remote branch exists (commits local-only, unpushed); if the remote branch does not
# exist yet the command errors — that is also fine and equally proves nothing was pushed.
git tag --points-at HEAD                 # EXPECT empty — no tag created
    </automated>
  </verify>
  <done>
    Two local commits exist, the working tree is clean, `mix.exs` and `.release-please-manifest.json`
    carry zero changes, no tag points at HEAD, and nothing was pushed or opened as a PR.
  </done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| local branch → release PR #83 → Hex tarball | Content crossing this boundary at merge is permanently published as 1.4.0 release notes; CHANGELOG.md is asserted present in the packaged tarball by release-please.yml. |
| planner/executor → release-please-owned files | `mix.exs` `@version` and `.release-please-manifest.json` are tool-owned; CI asserts both. Any edit here breaks the release lane. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-glj-01 | Tampering | CHANGELOG.md generated `### Features` / `### Bug Fixes` bullets | high | mitigate | Task 1 verify checks 4 diffs the sorted set of `* `-prefixed bullets before vs after against `git show HEAD:CHANGELOG.md`; any loss, reword, or relink fails the gate. |
| T-glj-02 | Tampering | CHANGELOG.md hand-written bullets (silent reword/drop during the move) | high | mitigate | Task 1 verify check 5 diffs the sorted set of `- `-prefixed bullets before vs after; the move must be byte-verbatim. |
| T-glj-03 | Denial of Service | release-please CI lane (`grep -nF "@version \"1.4.0\"" mix.exs`, manifest-match step) | high | mitigate | Task 1 forbids touching `mix.exs` / `.release-please-manifest.json`; verify checks 7 and Task 3 assert both are diff-clean. |
| T-glj-04 | Elevation of Privilege | git remote / GitHub release PR #83 | critical | mitigate | Task 3 forbids push, `gh pr` commands, and tagging; verify asserts commits are unpushed and no tag points at HEAD. Orchestrator retains sole publish authority. |
| T-glj-05 | Information Disclosure | pasted release notes | low | accept | Content is already-public v1.46 release copy taken verbatim from commit 40240903; the move introduces no new information. |
| T-glj-SC | Tampering | package-manager installs | low | accept | No npm/pip/cargo/hex install occurs in this plan; doc-only edit. No legitimacy audit required. |
</threat_model>

<verification>
1. `grep -n '^## ' CHANGELOG.md | head -4` shows Planning-milestones note, `## Unreleased`,
   `## [1.4.0]`, `## [1.3.0]` in that order.
2. The 1.4.0 section contains all five subsections — Added, Changed, Upgrade notes, Features,
   Bug Fixes — in that order.
3. Bullet conservation proven both ways: 14 bullets inside 1.4.0, 0 left in the top block, and both
   the generated (`* `) and hand-written (`- `) bullet sets diff empty against `HEAD:CHANGELOG.md`.
4. `mix docs --warnings-as-errors` passes, OR the summary states verbatim that it was not run,
   with the reason, and that heading nesting was checked visually only. Never claim a build that
   did not run.
5. `git diff` on `mix.exs` and `.release-please-manifest.json` is empty.
6. The legacy bracketed Unreleased heading (~line 424) is unmodified.
7. Nothing pushed, no PR touched, no tag created.
</verification>

<success_criteria>
- 1.4.0 release notes lead with the v1.46 reader-facing summary and carry the commit-level generated
  detail beneath it, with zero bullet text lost or altered.
- `## Unreleased` survives as an empty, warning-annotated home for the next cycle.
- Systemic footgun captured as a pending todo with real fix options, not just the applied mitigation.
- Working tree clean, two local commits, release-please-owned files untouched, nothing published.
</success_criteria>

<output>
Create `.planning/quick/260728-glj-fold-unreleased-changelog-block-into-the/260728-glj-SUMMARY.md` when done.

The summary MUST state explicitly whether `mix docs --warnings-as-errors` actually ran. If it did
not, say so with the reason and record that heading nesting was checked visually only — do not
report it as a passing build.
</output>
