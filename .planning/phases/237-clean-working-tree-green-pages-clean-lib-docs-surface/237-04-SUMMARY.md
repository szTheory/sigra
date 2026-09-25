---
phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface
plan: 04
subsystem: testing
tags: [ci-check, docs, hexdocs, moduledoc, regex-guard]

requires:
  - phase: 237-01
    provides: "regenerated, committed doc/llms.txt at v1.5.0 with a reachable .gitignore negation"
provides:
  - "a demonstrated-RED regex-class preservation check replacing SC-5's unfireable literal-marker check"
  - "two committed synthetic fixture diffs pinning both the trip and tolerate directions"
  - "the four D-01 named dead .planning/ references removed from lib/ documentation attributes"
  - "measured class-size baseline (52 lines) for Phase 241's p18 ratchet"
affects:
  - "Phase 241 p18 ratchet (baseline: 52 rationale-class comment lines in lib/, this phase's D-01 scope was exactly 4 of 348 total doc-surface hits)"
  - "Phase 239 SC-5 (carries the same dead-literal defect per D-04, filed as a todo)"

actuals:
  tokens: 3000
  tasks: 3
  commits: 2

tech-stack:
  added: []
  patterns:
    - "regex-class diff guard with a tolerated bookkeeping-token exception, pinned by a committed RED fixture and a committed tolerated-case fixture (not a single self-reported pass)"
    - "fail-closed empty-input guard proven on both the file-argument AND stdin `-` channels, because the real evidence run uses stdin"
    - "examined_removed_lines=<N> machine-readable count so a vacuous pass (0 lines examined) is mechanically distinguishable from a real pass"

key-files:
  created:
    - .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-security-comment-diff-check.sh
    - .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/fixtures/237-security-sentence-deleted.diff
    - .planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/fixtures/237-bookkeeping-only-deleted.diff
  modified:
    - lib/sigra/audit.ex
    - lib/sigra/testing.ex
    - lib/mix/tasks/sigra.fixture.rebless_golden.ex

key-decisions:
  - "D-04 applied as written: the check searches the regex class security|CSRF|enumeration|timing|scope|impersonation, never the dead literal `# SECURITY:` (zero occurrences repo-wide)"
  - "D-01 scope held to exactly the 4 named dead references; the other ~344 benign phase-mention hits in lib/ are explicitly out of scope and handed to Phase 241's p18 ratchet"
  - "Task 3's doc/llms.txt rebuild produced zero delta (byte-identical), so no commit was made for that file — the D-05 regeneration from 237-01 already covers this HEAD"

requirements-completed: [SURF-02]

coverage:
  - id: D1
    description: "Regex-class preservation check demonstrated RED against a fixture that deletes a pure security-rationale line"
    requirement: SURF-02
    verification:
      - kind: unit
        ref: "bash -c '! bash 237-security-comment-diff-check.sh fixtures/237-security-sentence-deleted.diff'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Check discriminates: exits zero on a fixture that deletes a bookkeeping-token-bearing (tolerated rewrite) line"
    requirement: SURF-02
    verification:
      - kind: unit
        ref: "bash 237-security-comment-diff-check.sh fixtures/237-bookkeeping-only-deleted.diff"
        status: pass
    human_judgment: false
  - id: D3
    description: "Check fails closed on empty input via both the stdin `-` channel (the real evidence-run channel) and an empty file argument"
    requirement: SURF-02
    verification:
      - kind: unit
        ref: "bash -c '! printf \"\" | bash 237-security-comment-diff-check.sh -'"
        status: pass
      - kind: unit
        ref: "bash -c '! bash 237-security-comment-diff-check.sh /dev/null'"
        status: pass
    human_judgment: false
  - id: D4
    description: "Check exits zero against this phase's real lib/ diff vs origin/main merge-base, with a non-vacuous examined_removed_lines count"
    requirement: SURF-02
    verification:
      - kind: integration
        ref: "git diff <merge-base> HEAD -- ':/lib/' | 237-security-comment-diff-check.sh - → examined_removed_lines=14"
        status: pass
    human_judgment: false
  - id: D5
    description: "The 4 named dead .planning/ references removed from lib/sigra/audit.ex, lib/sigra/testing.ex, lib/mix/tasks/sigra.fixture.rebless_golden.ex, with load-bearing rationale sentences preserved"
    requirement: SURF-02
    verification:
      - kind: unit
        ref: "grep -rq '\\.planning' across the 3 files (negated) + per-file defmodule control + Ecto.Multi/reserved-prefixes/thin-alias/Signature-note survival greps"
        status: pass
    human_judgment: false
  - id: D6
    description: "mix docs --warnings-as-errors still exits zero after the moduledoc edits; doc/llms.txt stays byte-clean; no new documentation-warning gate added"
    requirement: SURF-02
    verification:
      - kind: integration
        ref: "mix docs --warnings-as-errors && git diff --exit-code -- doc/llms.txt"
        status: pass
    human_judgment: false

duration: ~20min
completed: 2026-09-16
status: complete
commits: 2
plan_head_before: 8a105c9f9731745e51e2dae984bd57f64a1f7bdf
---

# Phase 237 Plan 04: SC-5 Regex-Class Check + Four Dead lib/ Doc References Summary

Replaced SC-5's unfireable literal `# SECURITY:` check (zero occurrences repo-wide) with a
regex-class diff guard demonstrated RED on a committed fixture, GREEN-and-discriminating on a
second committed fixture, fail-closed on empty stdin, and green on this phase's real 14-line
`lib/` diff — then used it as the safety net while removing the four D-01-named dead
`.planning/` references from `lib/sigra/audit.ex`, `lib/sigra/testing.ex`, and
`lib/mix/tasks/sigra.fixture.rebless_golden.ex` without losing a single rationale sentence.

## Performance

- **Duration:** ~20 min
- **Tasks:** 3 (all completed; Task 3 required no commit — see below)
- **Files modified:** 6 (3 new phase-directory artifacts, 3 edited `lib/` files)

## Accomplishments

- Built `237-security-comment-diff-check.sh`: a phase-directory (not repository-tooling, per
  D-04) shell script that greps removed diff lines for the class
  `security|CSRF|enumeration|timing|scope|impersonation`, tolerates lines that also carry a
  bookkeeping token (`D-NN`, `SC-N`, `Phase NN`, `.planning/` path) as the reviewed rewrite case,
  and fails closed on empty input on both the file-argument and stdin (`-`) channels.
- Demonstrated the check RED against `fixtures/237-security-sentence-deleted.diff` (a synthetic
  removed line: `# Constant-time comparison prevents timing attacks against the token check.` —
  no bookkeeping token) — exits 1, printing the offending line.
- Demonstrated the check discriminating (not universally blocking) against
  `fixtures/237-bookkeeping-only-deleted.diff` (a synthetic removed line carrying `D-99`
  alongside `scope`) — exits 0 with `examined_removed_lines=1`.
- Proved the fail-closed guard on the exact channel the real evidence run uses:
  `printf "" | ... -` exits 1, and a zero-length file argument (`/dev/null`) also exits 1.
- Ran the check against this phase's real `lib/` diff versus `git merge-base origin/main HEAD` —
  exit 0, `examined_removed_lines=14` (non-vacuous).
- Removed the 4 named dead `.planning/` references (D-01) from three `@moduledoc` blocks,
  rewriting rather than deleting where the sentence carried meaning:
  - `lib/sigra/audit.ex`: dead pointer sentence replaced by a short "Design summary:" phrase
    that still introduces the bullet list; the `Ecto.Multi` write-mechanism bullet and the
    reserved-prefix authority-boundary bullet are untouched.
  - `lib/sigra/testing.ex`: the "Signature note" keeps the statement of the deliberate
    `(map, keyword)` shape, the rejected `(repo, fields)` name, and the process-dict-magic /
    "thin alias" rationale; only the dead document path and its decision id were stripped.
  - `lib/mix/tasks/sigra.fixture.rebless_golden.ex`: the pure-bookkeeping two-sentence runbook
    block (naming two historical runbooks) was removed entirely; the moduledoc reads correctly
    with the `## Usage` section immediately following the description paragraph.
- Confirmed `git diff --name-only <merge-base> HEAD -- ':/lib/'` lists exactly the three edited
  files — `lib/sigra/admin/live/audit_index_live.ex` (Phase 236's file) does not appear.
- Confirmed `git diff --name-only <merge-base> HEAD -- ':/scripts/ci/prohibitions/'` is empty —
  nothing was added under any name to the durable-guard directory reserved for Phase 241.
- Recorded the current class size in `lib/`: `rg -n -i '^\s*#.*\b(security|CSRF|enumeration|timing|scope|impersonation)\b' lib/` → **52** lines, with the positive control
  `rg -c 'defmodule' lib/sigra/audit.ex` → `1` proving the search machinery works. This is the
  baseline Phase 241's `p18` ratchet starts from.
- Rebuilt docs (`mix docs --warnings-as-errors`) after the prose edits — exit 0, no warnings.
  `doc/llms.txt` is byte-identical before and after the rebuild (`git diff --exit-code` exit 0),
  so no regeneration commit was needed for Task 3 — the D-05 regeneration already landed in
  237-01 covers this HEAD.
- Confirmed no new gate was added: `git diff --name-only <merge-base> HEAD -- ':/.github/workflows/'` is empty.

## Task Commits

1. **Task 1: Build the regex-class preservation check and demonstrate it RED, then demonstrate it discriminating** - `93f723bb` (feat)
2. **Task 2: Remove the four dead planning-directory references from documentation attributes, keeping every sentence that was doing work** - `d790184b` (docs)
3. **Task 3: Run the preservation check GREEN against this phase's real diff and re-prove the docs build** - no commit (verification-only; `doc/llms.txt` did not change, so there was nothing to stage)

**Plan metadata:** committed alongside this SUMMARY (docs: complete plan).

## Files Created/Modified

- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/237-security-comment-diff-check.sh` - the regex-class preservation check
- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/fixtures/237-security-sentence-deleted.diff` - RED fixture (pure rationale line, no bookkeeping token)
- `.planning/phases/237-clean-working-tree-green-pages-clean-lib-docs-surface/fixtures/237-bookkeeping-only-deleted.diff` - discriminating fixture (rationale + bookkeeping token, tolerated)
- `lib/sigra/audit.ex` - dead `.planning/` pointer replaced with a self-contained intro sentence
- `lib/sigra/testing.ex` - Signature note rewritten to stand on its own without the dead path/decision id
- `lib/mix/tasks/sigra.fixture.rebless_golden.ex` - pure-bookkeeping runbook-pointer block removed

## Decisions Made

- D-04 applied literally: the check's subject is the regex class, never the dead `# SECURITY:` literal.
- D-01 scope held to exactly 4 named references; the residual ~344 benign phase-mention hits across
  71 files are explicitly out of scope for this plan and belong to Phase 241's `p18` ratchet.
- Task order followed the plan (Task 1 tool built first, demonstrated RED/GREEN/fail-closed before
  being trusted; Task 2 edits made using the tool's own class definition as a mental guard; Task 3
  ran the tool against the real diff as the closing evidence gate).
- No commit was made for Task 3 because the docs rebuild produced a byte-identical `doc/llms.txt` —
  committing a no-op diff would violate the "no changes, no commit" discipline; the check-and-build
  verification itself is the deliverable of that task, not a file change.

## Deviations from Plan

None - plan executed exactly as written. All four `<acceptance_criteria>` in Task 1, six in Task 2,
and four in Task 3 were run and passed on first attempt; no auto-fixes, no architectural questions,
no auth gates.

## Issues Encountered

None.

## Threat Register Disposition

| Threat ID | Disposition | Evidence |
|---|---|---|
| T-237-04-01 (Repudiation/knowledge loss) | mitigated | check demonstrated RED first; real-diff run exits 0 with `examined_removed_lines=14` |
| T-237-04-02 (Spoofing of green) | mitigated | two fixtures pin both directions; empty-input guard proven on the stdin channel the real run uses |
| T-237-04-03 (Dead internal paths on public docs site) | mitigated | all 4 named references verified individually removed; `mix docs` confirms no rendering regression |
| T-237-04-04 (Synthetic fixture leakage) | mitigated | both fixtures use invented module names (`Example.SyntheticSecurityNote`, `Example.SyntheticScopeNote`); no real source lines, no identity, no local paths |
| T-237-04-05 (package installs) | accepted (no packages installed) | n/a |

## User Setup Required

None - no external service configuration required.

## Known Stubs

None. No stub values, placeholder text, skipped tests, or unrun `<verify>` commands were produced
by this plan — every verification listed above was executed and its exit status recorded.

## Next Phase Readiness

- SURF-02's content half is satisfied for this plan's D-01 scope: 4 named dead references removed,
  no rationale sentence lost, documentation build still clean.
- Phase 241's `p18` ratchet has its starting baseline: 52 rationale-class comment lines in `lib/`
  today (measured with the same regex the check uses), plus the wider ~344-hit residual
  doc-surface count recorded in plan 237-06.
- A todo should be filed (not yet filed by this plan — out of its own scope per D-04's closing
  note) to correct Phase 239's SC-5 wording, which carries the same dead-literal defect.
- Working tree is clean with respect to this plan's own file set at this plan's HEAD;
  `.planning/STATE.md`, `.planning/state.json`, and the untracked `.planning/milestone.lock`
  session-lock file are orchestrator/session bookkeeping outside this plan's task scope and are
  reconciled by this plan's own closing STATE/ROADMAP update step below.

---
*Phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface*
*Completed: 2026-09-16*

## Self-Check: PASSED

- All 7 created/modified files FOUND on disk.
- Commits `93f723bb` and `d790184b` FOUND in `git log`.
- `commits: 2` (measured via `git rev-list --count ${plan_head_before}..HEAD`), `plan_head_before: 8a105c9f9731745e51e2dae984bd57f64a1f7bdf`.
