---
phase: 241
fixed_at: 2026-09-19T17:20:09Z
review_path: .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-REVIEW.md
iteration: 3
findings_in_scope: 4
fixed: 3
skipped: 1
status: partial
verification_location: main checkout
---

# Phase 241: Code Review Fix Report

**Fixed at:** 2026-09-19T17:20:09Z  
**Source review:** `.planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-REVIEW.md`  
**Iteration:** 3

## Summary

- Findings in scope: 4
- Fixed: 3
- Declined on scope evidence: 1
- Verification location: main checkout (this bounded final iteration explicitly used no worktree).

## Fixed Issues

### CR-01: Line-oriented action extraction bypasses valid YAML `uses` forms

**Files modified:** `test/sigra/planning/phase_234_action_pinning_contract_test.exs`, `test/fixtures/prohibitions/phase241-composite-unpinned-flow-uses.yml`, `test/fixtures/prohibitions/phase241-composite-unpinned-block-uses.yml`  
**Commit:** `dad457cc`  
**Applied fix:** Flow mappings and block-scalar `uses` declarations now fail closed with a path-and-line diagnostic instead of silently disappearing from the inventory. Committed fixtures exercise both valid YAML forms. Decoding YAML would be a larger parser/dependency change outside Plan 241-04's deliberately line-oriented inventory; fail-closed rejection preserves the supply-chain guarantee until that scope is explicitly widened.

### CR-02: Prefix matching permits local-action paths to escape `.github/actions`

**Files modified:** `test/sigra/planning/phase_234_action_pinning_contract_test.exs`, `test/fixtures/prohibitions/phase241-release-workflow-external-composite/release-workflow.yml`  
**Commit:** `dad457cc`  
**Applied fix:** Local action paths are lexically canonicalized with `Path.expand/1` and exempted only when the resulting path is `.github/actions` or one of its descendants. The known-bad workflow now uses `./.github/actions/../release/bootstrap` and fails as outside the permitted root.

### WR-01: The library-suite contract excludes valid `library_tests*` job IDs

**Files modified:** `test/sigra/planning/phase_233_library_economics_contract_test.exs`, `test/fixtures/prohibitions/phase241-library-economics-two-owners.yml`  
**Commit:** `fd77f0db`  
**Applied fix:** Both the job extractor and its body boundary now use the same `[A-Za-z0-9_-]` job-id grammar. The committed two-owner fixture uses `library_tests-canary_2`; the parser test proves it is included and the fixture still produces the distinctive single-owner failure.

## Declined Issues

### CR-03: The doc-range scanner still skips valid sigils and closes escaped delimiters early

**File:** `scripts/ci/prohibitions/_p18-lib.mjs:27-57,179-180`  
**Reason:** Declined by the Phase 241 scope contract. D-30 and Plan 241-06 make this scanner a faithful JavaScript port of the committed Phase-237 Python scanner. The Python scanner's declared state machine covers doc-attribute heredocs and one-line quoted attributes; adding general sigil delimiters or escaped-delimiter state would recognize a broader language and alter that defined scanner surface. The required cross-check remains exact at the current commit: Python `total_hits=337`; JavaScript `docRangeTotal("lib")=337`. A general Elixir-doc parser requires a separately authorized scanner-spec revision and re-baselining, not a final review-fix iteration.

**Original issue:** The reviewer requested general sigil delimiter and escaped-delimiter parsing for the doc-range scanner.

## Verification

All checks ran in the main checkout:

- `mix format --check-formatted` — passed.
- `mix test test/sigra/planning/phase_233_library_economics_contract_test.exs test/sigra/planning/phase_234_action_pinning_contract_test.exs` — 18 tests, 0 failures.
- The single-owner known-bad fixture REDed with `more than one owner of the full library suite`, identifying `library_tests` and `library_tests-canary_2`.
- `node --check scripts/ci/prohibitions/_p18-lib.mjs` and `node --check scripts/ci/prohibitions/p18-doc-range.test.mjs` — passed.
- `node --test --test-reporter=tap scripts/ci/prohibitions/p18-*.test.mjs` — 10 tests, 0 failures.
- Phase-237 Python scanner and the Phase-241 JS port both measured `337` doc-range hits in `lib/`.
- `git diff --check` — passed.

---

_Fixed: 2026-09-19T17:20:09Z_  
_Fixer: the agent (gsd-code-fixer)_  
_Iteration: 3_
