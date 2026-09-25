---
phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface
plan: 05
subsystem: docs
tags: [exdoc, hexdocs, docs-warnings, mix-exs, guides]

requires:
  - phase: 237-04
    provides: "the 4 named dead lib/ doc references removed, and the phase's demonstrated D-01 scoping discipline"
provides:
  - "3 dead .planning/ links removed from published upgrade guides, claims preserved as prose"
  - "skip_undefined_reference_warnings_on shrunk from 9 to 7 entries for an earned reason"
  - "corrected mix.exs comment describing what the surviving 7 entries actually suppress"
  - "remove-and-retest proof that the 7 survivors are load-bearing and the 4 dead-link warnings are gone"
affects:
  - "SURF-02 (fully satisfied — both the content half and the already-existing gate-recording half)"

actuals:
  tokens: 4500
  tasks: 3
  commits: 2

tech-stack:
  added: []
  patterns:
    - "byte-copy + checksum + clean-diff restore discipline for a temporary build-file mutation used as evidence, not left in place"
    - "remove-and-retest with a positive-absence check: confirm the specific warnings expected to disappear are actually absent from the emptied-list capture, not just that a warning count changed"

key-files:
  modified:
    - guides/introduction/upgrading-to-v1.10.md
    - guides/introduction/upgrading-to-v1.11.md
    - mix.exs

key-decisions:
  - "D-03 applied as written: fixed the 3 dead links (2 in v1.10, 1 in v1.11) before removing the 2 skip entries they justified — earning the reduction rather than declaring it"
  - "Rewrote each sentence to drop the pointer and keep the claim as prose, per the plan's preferred shape; did not restate the target documents' content and did not substitute an absolute URL to a still-nonexistent target"
  - "The milestone-labels-vs-Hex-versions sentence in both guides was left untouched — verified present after edits via the 'second installable version axis' acceptance check"
  - "The warnings-as-errors gate already runs in three workflows (ci.yml, release-please.yml, hex-publish.yml) and was NOT duplicated; no docs/0 warnings_as_errors key and no workflow file changed (verified: empty diff under .github/workflows/ against the phase merge-base)"

requirements-completed: [SURF-02]

coverage:
  - id: D1
    description: "Three dead relative links to non-existent planning documents removed from the two upgrade guides; each sentence's claim survives as prose; the milestone-labels sentence is untouched"
    requirement: SURF-02
    verification:
      - kind: unit
        ref: "bash -c '! grep -Fq \"](../../.planning/\" guides/introduction/upgrading-to-v1.10.md guides/introduction/upgrading-to-v1.11.md'"
        status: pass
      - kind: unit
        ref: "per-file grep -q 'planning milestone' (positive control against gutting)"
        status: pass
      - kind: unit
        ref: "grep -q 'second installable version axis' in both files"
        status: pass
      - kind: integration
        ref: "git diff <merge-base> HEAD -- the two named files (count==2) and the whole introduction/ dir (no extras beyond the two plus 237-02's walkthrough)"
        status: pass
    human_judgment: false
  - id: D2
    description: "skip_undefined_reference_warnings_on shrinks from 9 to 7 entries; the two removed are exactly the upgrade-guide entries; the false 'intentionally relative' comment is corrected"
    requirement: SURF-02
    verification:
      - kind: unit
        ref: "sed-scoped entry count == 7"
        status: pass
      - kind: unit
        ref: "no upgrading-to-v1.1[01].md entries remain in the list"
        status: pass
      - kind: unit
        ref: "companion-libs entries survive (positive control against over-removal)"
        status: pass
      - kind: unit
        ref: "grep -q 'intentionally relative' mix.exs negated (comment corrected)"
        status: pass
      - kind: integration
        ref: "mix compile --warnings-as-errors"
        status: pass
    human_judgment: false
  - id: D3
    description: "Remove-and-retest proves the surviving 7 entries load-bearing and the 4 dead-link warnings are gone; mix.exs restored byte-identically; warnings-as-errors build exits zero with 7 entries; no fourth gate added"
    requirement: SURF-02
    verification:
      - kind: integration
        ref: "mix docs with skip list emptied to [] -> 10 warnings captured, none referencing .planning or the upgrade guides"
        status: pass
      - kind: integration
        ref: "git diff --exit-code -- mix.exs after restore (clean) + shasum match (96fde01f... before and after)"
        status: pass
      - kind: integration
        ref: "mix docs --warnings-as-errors with 7-entry list restored -> exit 0"
        status: pass
      - kind: integration
        ref: "mix docs >/dev/null && git diff --exit-code -- doc/llms.txt (no drift)"
        status: pass
      - kind: integration
        ref: "git diff <merge-base> HEAD -- .github/workflows/ is empty"
        status: pass
    human_judgment: false

duration: ~25min
completed: 2026-09-16
status: complete
commits: 2
plan_head_before: 537189e965b0e6dc5ee5d6e220397d044aa3543c
---

# Phase 237 Plan 05: Retire Dead Doc-Link Warnings + Earned Suppression-List Reduction Summary

Removed the three dead `.planning/` links that were the source of 4 of the 9 `skip_undefined_reference_warnings_on` warnings, dropped the 2 suppression entries they justified (9 → 7), corrected the `mix.exs` comment's false "intentionally relative" claim about those paths, and proved — via a byte-copy-and-restore remove-and-retest — that the 7 survivors are still load-bearing and the documentation build still exits zero with the shorter list.

## Performance

- **Duration:** ~25 min
- **Started:** 2026-09-16
- **Completed:** 2026-09-16
- **Tasks:** 3 (Task 3 verification-only, no commit — no file ended up changed)
- **Files modified:** 3

## Accomplishments

- Rewrote the two affected sentences in `guides/introduction/upgrading-to-v1.10.md` (lines 5 and 9)
  and the one affected sentence in `guides/introduction/upgrading-to-v1.11.md` (line 7), dropping
  the dead relative Markdown links (`../../.planning/v1.10-ADOPTER-SCOPE.md`,
  `../../.planning/milestones/v1.9-ROADMAP.md`, `../../.planning/v1.11-TRIAGE.md` — none of which
  exist anywhere in the repository) while keeping each sentence's original claim as plain prose.
  The milestone-labels-vs-Hex-versions sentence (line 3 in both files) was left untouched.
- Removed the two `skip_undefined_reference_warnings_on` entries in `mix.exs` for
  `guides/introduction/upgrading-to-v1.10.md` and `guides/introduction/upgrading-to-v1.11.md` —
  the entries only existed because of the now-fixed dead links. The list is now 7 entries: the 5
  source-module entries (Phase 131 hidden-Application-helper suppression) and the 2
  companion-library recipe entries (Phase 132 hidden-helper + `Sigra.Mailer` behaviour-callback
  suppression), both group comments intact.
- Replaced the false comment above the list — it claimed the removed `.planning/` paths were
  "intentionally relative from this guide for repo navigation," which was never true for links to
  files that do not exist — with an accurate description of what the surviving 7 entries actually
  suppress: hidden `Application` helpers and a behaviour callback ExDoc cannot autolink.
- Ran the remove-and-retest: emptied `skip_undefined_reference_warnings_on` to `[]` on a working
  copy of `mix.exs`, ran `mix docs`, and captured **10 warnings** — all referencing hidden
  `Application` helpers or the `Sigra.Mailer` callback via the surviving 7 entries' sources. **None**
  reference `.planning/` or either upgrade guide, which is the positive evidence that Task 1 actually
  eliminated the 4 dead-link warnings rather than merely relocating them.
- Restored `mix.exs` from a byte copy taken before the empty-list mutation. Proved the restore two
  ways: `git diff --exit-code -- mix.exs` (clean) and a `shasum` comparison
  (`96fde01f9817c43cd3fd85eedddfc193c9022db0` identical before and after).
- Re-ran `mix docs --warnings-as-errors` with the restored 7-entry list — **exit 0**, the same
  invocation the three workflows (`ci.yml`, `release-please.yml`, `hex-publish.yml`) already run.
  Confirms the prune did not relocate a failure into CI.
- Confirmed `doc/llms.txt` did not drift: `mix docs` followed by `git diff --exit-code -- doc/llms.txt`
  is clean, so no regeneration commit was needed for that file this plan (the D-05 regeneration
  from 237-01 already covers this HEAD, same pattern as 237-04's Task 3).
- Confirmed no workflow file changed: `git diff <merge-base> HEAD -- .github/workflows/` is empty.
  The warnings-as-errors gate's already-existing three-workflow coverage is recorded, not
  duplicated — no `warnings_as_errors:` key was added to `docs/0`, no fourth gate exists.

## Task Commits

1. **Task 1: Remove the three dead planning-document links from the two upgrade guides, keeping each sentence's claim** - `5243df70` (docs)
2. **Task 2: Drop the two now-unjustified suppression entries and correct the false comment above the list** - `223162e3` (fix)
3. **Task 3: Prove the surviving seven still earn their place, and that the build and tree are clean with the shorter list** - no commit (verification-only; `mix.exs` restored byte-identical, `doc/llms.txt` unchanged — nothing to stage)

**Plan metadata:** committed alongside this SUMMARY (docs: complete plan).

## Files Created/Modified

- `guides/introduction/upgrading-to-v1.10.md` - two dead `.planning/` links removed, claims kept as prose
- `guides/introduction/upgrading-to-v1.11.md` - one dead `.planning/` link removed, claim kept as prose
- `mix.exs` - two suppression entries removed (9 → 7); comment above the list corrected

## Decisions Made

- D-03 applied literally: fixed the source (the 3 dead links) before touching the suppression list,
  so the reduction is earned rather than declared. This is the order the plan's `acceptance_criteria`
  require and the order the remove-and-retest in Task 3 depends on for its positive-absence check
  to mean anything.
- Chose the "drop the pointer, keep the statement as prose" rewrite shape for all three sentences
  (rather than restating target-document content inline) — the shortest rewrite that keeps each
  paragraph reading naturally, per the plan's stated preference.
- Did not substitute absolute GitHub URLs for the removed links, even though that is the house style
  used elsewhere in the guides (`upgrading-to-v1.12.md`) for planning documents that DO exist — these
  three targets do not exist anywhere, so an absolute URL would trade a loud build warning for a
  silent 404, which the plan explicitly prohibits.
- No warnings-as-errors key was added to `docs/0` in `mix.exs`, and no workflow file was touched —
  the plan's prohibition against adding a fourth documentation-warning gate is satisfied by leaving
  the existing three-workflow CLI-flag enforcement exactly as it was.

## Deviations from Plan

None - plan executed exactly as written. All acceptance criteria across the three tasks were run
and passed; the only procedural adjustment was ordering Task 1's diff-scoped verification (V4,
which diffs against `merge-base origin/main HEAD`) after Task 1's commit rather than before it —
the check compares *committed* history, not working-tree state, so it could only pass once the
edit was committed. This is a verification-sequencing detail, not a deviation from the plan's
intent or scope; every check specified in the plan ran and passed.

## Issues Encountered

None.

## Threat Register Disposition

| Threat ID | Disposition | Evidence |
|---|---|---|
| T-237-05-01 (Spoofing of green — suppression-list prune) | mitigated | Entries removed only after Task 1 fixed the underlying dead links; remove-and-retest (Task 3) shows the 7 survivors still warn when emptied, and the 4 dead-link warnings are specifically absent from that capture |
| T-237-05-02 (Tampering — temporary build-file edit) | mitigated | Byte copy taken before the empty-list mutation; restore proven by both `git diff --exit-code` (clean) and a `shasum` match |
| T-237-05-03 (Repudiation — false comment) | mitigated | The false "intentionally relative" claim is gone (`! grep -q "intentionally relative" mix.exs`); replaced with an accurate description of what the 7 survivors suppress |
| T-237-05-04 (Information Disclosure — dead internal links in published guides) | mitigated | Links removed, not redirected; positive controls (`planning milestone`, `second installable version axis` presence) prove the search/edit ran correctly rather than gutting the files |
| T-237-05-05 (Tampering — package installs) | accepted | No registry packages installed by this plan |

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. No stub values, placeholder text, skipped tests, or unrun `<verify>` commands were produced
by this plan — every verification listed above was executed and its exit status recorded.

## Next Phase Readiness

- SURF-02 is now fully satisfied: the content half (dead `.planning/` links in `lib/` from 237-04,
  and the 3 dead links in published `guides/` from this plan) is done, the suppression list is
  genuinely smaller (9 → 7) for an earned reason with its survivors proven load-bearing, its
  comment tells the truth, and the already-existing warnings-as-errors gate (three workflows) was
  recorded rather than duplicated.
- The working tree is clean with respect to this plan's own file set at this plan's HEAD;
  `.planning/STATE.md`, `.planning/state.json`, and the untracked `.planning/milestone.lock`
  session-lock file are orchestrator/session bookkeeping outside this plan's task scope, reconciled
  by this plan's own closing STATE/ROADMAP update step (same treatment as 237-04's SUMMARY records
  for the identical files).

---
*Phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface*
*Completed: 2026-09-16*

## Self-Check: PASSED

- All 3 modified files FOUND on disk (`guides/introduction/upgrading-to-v1.10.md`,
  `guides/introduction/upgrading-to-v1.11.md`, `mix.exs`).
- Commits `5243df70` and `223162e3` FOUND in `git log`.
- `commits: 2` (measured via `git rev-list --count 537189e9..HEAD`), `plan_head_before: 537189e965b0e6dc5ee5d6e220397d044aa3543c`.
