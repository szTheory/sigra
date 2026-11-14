---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 04
subsystem: testing
tags: [exunit, install-snippet, semver-pin, copy-contract, hex-retirement]

requires:
  - phase: 259-01
    provides: policy docs that deliberately carry no literal sigra dependency tuple, so this scan needs no exemptions
provides:
  - test/sigra/brand/install_snippet_test.exs, a pure-filesystem ExUnit contract that every documented {:sigra, "<req>"} tuple is three-segment and all are identical
  - Positive controls proving a planted two-segment pin, a planted mismatching three-segment pin and a planted bad snippet in every scan root each go red
affects: [259-05, 263]

actuals:
  tokens: 2650
  tasks: 1
  commits: 1
commits: 1
plan_head_before: b5b9ed93ac6c2a75dc7fc1f43627fb5d24325c28
plan_head_after: 9f63ff968fe399536490bb07b1650c999db571ac

tech-stack:
  added: []
  patterns:
    - "Shape-and-equality contract: assert the structure of a pinned value across files and that the set of distinct values has size one, never the value itself, so a later bump touches the docs and not this test"
    - "Pure helpers (collect/1, violations/1) tested against planted inputs and a throwaway tmp_dir tree, so the suite proves it can go red without ever mutating a real doc"
    - "Regexes held in private functions rather than module attributes, so they are never escaped into function bodies at compile time under OTP 28"

key-files:
  created:
    - test/sigra/brand/install_snippet_test.exs
  modified: []

key-decisions:
  - "The test asserts shape (anchored ~> digits.digits.digits) and set size 1, never a version value: it is green today because all 11 occurrences are the same three-segment requirement, and stays green after the later publish-readiness bump with no edit"
  - "No allow-list, exemption or per-file skip: Plan 01 writes no literal dependency tuple, so every occurrence the scan sees must pass as-is; a future non-conforming tuple is fixed in the doc, not in this test"
  - "Real-tree redness is proven only by planted in-memory inputs and a tmp_dir tree, because the plan prohibits editing any doc or bumping any pin"

patterns-established:
  - "Non-vacuity by construction: the scan roots must exist and README.md and guides/ must each contribute at least one occurrence, so a renamed directory fails loudly instead of passing on an empty list"
  - "Failure messages name the file and the offending requirement and state why two-segment requirements are unsafe (they still resolve to the retired stray 1.20.0 Hex release)"

requirements-completed: [BCOPY-05]

coverage:
  - id: D1
    description: "Every documented sigra dependency requirement in README.md, guides/**/*.md, docs/**/*.md and priv/templates/** is a three-segment requirement"
    requirement: "BCOPY-05"
    verification:
      - kind: unit
        ref: "test/sigra/brand/install_snippet_test.exs#every documented requirement is three-segment"
        status: pass
    human_judgment: false
  - id: D2
    description: "All documented requirements are identical (exactly one distinct value across files), without pinning which value"
    requirement: "BCOPY-05"
    verification:
      - kind: unit
        ref: "test/sigra/brand/install_snippet_test.exs#all documented requirements are identical"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/install_snippet_test.exs#the real docs report no findings at all"
        status: pass
    human_judgment: false
  - id: D3
    description: "The scan cannot pass vacuously: README.md, guides/ and priv/templates/ exist, and README.md and guides/ each contribute at least one occurrence"
    requirement: "BCOPY-05"
    verification:
      - kind: unit
        ref: "test/sigra/brand/install_snippet_test.exs#the scan cannot pass vacuously"
        status: pass
    human_judgment: false
  - id: D4
    description: "Positive controls: a planted two-segment requirement, other loose shapes, a planted mismatching three-segment pair, and a planted bad snippet in every scan root (including a dotfile and a skipped binary) are flagged; the ellipsis prose form is never collected"
    requirement: "BCOPY-05"
    verification:
      - kind: unit
        ref: "test/sigra/brand/install_snippet_test.exs#positive controls"
        status: pass
    human_judgment: false

duration: 3min
completed: 2026-11-14
status: complete
---

# Phase 259 Plan 04: Install-Snippet Shape Test Summary

**A pure-filesystem ExUnit contract that every documented `{:sigra, "<req>"}` tuple across README, guides, docs and generator templates is a three-segment `~> X.Y.Z` requirement and that all of them are identical, with planted-input controls proving it can go red.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-11-14T15:51:30Z (approximate; the previous plan's close-out was stamped 15:51:29Z)
- **Completed:** 2026-11-14T15:54:32Z (task commit and verification complete; SUMMARY written immediately after)
- **Tasks:** 1
- **Files modified:** 1 (created)

## Accomplishments

- Added `Sigra.Brand.InstallSnippetTest` (11 tests, 0 failures) that collects every `{:sigra, "<req>"}` occurrence under `README.md`, `guides/**/*.md`, `docs/**/*.md` and `priv/templates/**/*`, then asserts the anchored three-segment shape and that the distinct set has exactly one member. This closes the gap where a two-segment pin such as `~> 1.7` still resolves to the retired stray 1.20.0 Hex release (BCOPY-05).
- Made the scan non-vacuous: `README.md`, `guides/` and `priv/templates/` must exist and README.md and `guides/` must each contribute an occurrence, so a renamed directory cannot produce a silent green (threat T-259-11).
- Proved the checks can go red without touching a single doc: planted two-segment, loose-shape and mismatching-pin lists, plus a `tmp_dir` tree that plants a bad snippet in each scan root (nested guide, `docs/`, template, dotfile), a non-UTF-8 binary that must be skipped, and out-of-scope files that must be ignored.
- Left the Phase 242 value-pin test untouched and bumped no pin in any doc; the value bump stays with the later publish-readiness work, and this test needs no edit when it lands.

## Task Commits

Each task was committed atomically:

1. **Task 1: Install-snippet shape and equality test with positive controls** - `9f63ff968` (test)

**Plan metadata:** committed separately as `docs(259-04)` (SUMMARY) and `docs(259-04)` / `chore(259-04)` (state, roadmap, requirements).

## Files Created/Modified

- `test/sigra/brand/install_snippet_test.exs` - Three-segment, all-equal, non-vacuous install-pin contract with planted-input positive controls (new, 267 lines).

## Decisions Made

- The test asserts shape and set size, never a version value, so it is green for any equal three-segment set and the later pin bump does not touch it. A value assertion belongs to the Phase 242 contract test, which this plan leaves alone.
- No allow-list, exemption or per-file skip exists. The only files skipped are non-UTF-8 binaries, which cannot carry a documented snippet. If a doc ever adds a non-conforming tuple the fix is the doc.
- Regexes live in private functions, not module attributes, to stay clear of the OTP 28 hazard where compiled regexes stored in attributes are escaped into function bodies at compile time.
- The ellipsis prose form in `guides/introduction/troubleshooting-install.md` is covered two ways: an in-memory unit check, and a real-file check that only inspects lines actually containing the ellipsis form. The file is therefore free to change without making the test brittle.

## Deviations from Plan

None - plan executed exactly as written.

Two additions go slightly beyond the plan's five listed behaviors and are not deviations: an extra malformed-shape control (`>= 1.5.0`, `~> 1`, `== 1.5.0`, a pre-release, a missing space, the empty string) and the `tmp_dir` end-to-end control for `collect/1`. Both strengthen Test 4 and add no scope.

## Issues Encountered

None.

## Verification Results

Task acceptance criteria (all re-run after the task commit):

| Criterion | Result |
|-----------|--------|
| `mix test test/sigra/brand/install_snippet_test.exs` | PASS, 11 tests, 0 failures |
| `mix format --check-formatted` (file and whole repo) | PASS |
| `grep -rn '{:sigra, "' README.md guides docs priv/templates` count is 11 | PASS (11) |
| `git diff --stat aeda7273d` over `phase_242_shift_left_contract_test.exs` and `README.md` is empty | PASS |
| Phase-gate: no `{:sigra, ` line changed in `README.md` or `guides` since `aeda7273d` | PASS |
| `mix test test/sigra/planning/phase_242_shift_left_contract_test.exs` | PASS, 2 tests, 0 failures |
| `1.5.0` / `1.7` literals in the new test appear only inside planted fixtures | PASS (all matches are planted controls) |

Plan-level verification:

| Check | Result |
|-------|--------|
| Zero shipped bytes: `git diff --stat aeda7273d -- lib priv brandbook brand .github scripts` empty, test diff non-empty, tracked-tree sample non-empty, no untracked | PASS |
| Privacy gate: no `/Users/<x>` or `/home/<x>` in the phase diff outside the phase planning dir, with planted-failure control; new file also grepped directly | PASS |
| `mix format --check-formatted` | PASS |

## Known Stubs

None.

## Threat Flags

None. The plan's threat model (T-259-10 two-segment pin resolving to the retired release, T-259-11 vacuous green after a directory rename) is mitigated by the anchored shape assertion and the non-emptiness assertions respectively. No new network, auth, file-access or schema surface was introduced.

## Next Phase Readiness

Ready for 259-05. The install-snippet contract is in place and independent of the later pin value. One note carried forward from research: the retired 1.20.0 release's own retirement message recommends `~> 1.5.0`, so a later bump to a newer minor line should revisit that message.

## Self-Check: PASSED

- FOUND: `test/sigra/brand/install_snippet_test.exs`
- FOUND: commit `9f63ff968` (ancestor of HEAD)
- `commits: 1` measured from the persisted ledger (`plan_head_before` `b5b9ed93a` to `plan_head_after` `9f63ff968`)
