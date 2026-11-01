---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
reviewed: 2026-09-19T17:10:55Z
depth: standard
files_reviewed: 33
files_reviewed_list:
  - .github/ci-skip-manifest.tsv
  - MAINTAINING.md
  - scripts/ci/prohibitions/_p18-lib.mjs
  - scripts/ci/prohibitions/p18-allowlist.tsv
  - scripts/ci/prohibitions/p18-bookkeeping-ratchet.test.mjs
  - scripts/ci/prohibitions/p18-doc-range.test.mjs
  - scripts/ci/prohibitions/p18-planning-paths.test.mjs
  - scripts/ci/prohibitions/p18-ratchet-baseline.tsv
  - scripts/ci/prohibitions/p18-templates-bookkeeping.test.mjs
  - scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs
  - test/fixtures/prohibitions/p10-manifest-stale-entry.tsv
  - test/fixtures/prohibitions/p18-doc-range-delimited-sigils.ex
  - test/fixtures/prohibitions/p18-doc-range-leak.ex
  - test/fixtures/prohibitions/p18-doc-range-lowercase-sigil.ex
  - test/fixtures/prohibitions/p18-planning-path-leak.ex
  - test/fixtures/prohibitions/p18-ratchet-r1-exceeded.tsv
  - test/fixtures/prohibitions/p18-ratchet-r2-exceeded.tsv
  - test/fixtures/prohibitions/p18-ratchet-r3-exceeded.tsv
  - test/fixtures/prohibitions/p18-template-allowlist-shadow.ex
  - test/fixtures/prohibitions/p18-template-bookkeeping.ex
  - test/fixtures/prohibitions/p21-maintaining-stale-topology.md
  - test/fixtures/prohibitions/phase241-composite-unpinned-bare-uses.yml
  - test/fixtures/prohibitions/phase241-composite-unpinned-dashed-uses.yml
  - test/fixtures/prohibitions/phase241-composite-unpinned-quoted-uses.yml
  - test/fixtures/prohibitions/phase241-composite-unpinned-space-before-colon-uses.yml
  - test/fixtures/prohibitions/phase241-library-economics-two-owners.yml
  - test/fixtures/prohibitions/phase241-nested-composite-unpinned/release/bootstrap/action.yml
  - test/fixtures/prohibitions/phase241-release-workflow-external-composite/release-workflow.yml
  - test/fixtures/prohibitions/phase241-release-workflow-external-composite/release/bootstrap/action.yml
  - test/sigra/planning/phase_233_library_economics_contract_test.exs
  - test/sigra/planning/phase_234_action_pinning_contract_test.exs
  - test/support/ci/ex_unit_timing_formatter.ex (deleted)
  - test/support/ci/ex_unit_timing_formatter_test.exs (deleted)
findings:
  critical: 3
  warning: 1
  info: 0
  total: 4
status: issues_found
---

# Phase 241: Code Review Report

**Reviewed:** 2026-09-19T17:10:55Z
**Depth:** standard
**Files Reviewed:** 33
**Status:** issues_found

## Summary

The three fixes recorded in `241-REVIEW-FIX.md` work for their supplied fixtures: quoted and
space-before-colon `uses` keys are visible, release workflows reject the supplied external local
action, and pipe/paired sigil docs are scanned. The implementations remain line-oriented parsers,
however, leaving valid YAML and Elixir representations outside the asserted surfaces. The
single-owner contract also excludes valid `library_tests*` job IDs.

Verification passed: `node --check` on the modified p18 modules,
`node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` (106 passing),
`mix test test/sigra/planning/phase_233_library_economics_contract_test.exs
test/sigra/planning/phase_234_action_pinning_contract_test.exs` (15 passing),
`mix format --check-formatted`, and `git diff --check`.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: Line-oriented action extraction bypasses valid YAML `uses` forms

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/test/sigra/planning/phase_234_action_pinning_contract_test.exs:12,211-220`

**Issue:** The inventory only recognizes a complete, block-style `uses` mapping on one line. A
composite action can validly put an action step in a flow mapping (`- { uses: actions/checkout@v4 }`)
or use a block scalar (`uses: >-` followed by the action ref). Neither
line matches `@action_pattern`, so the unpinned action adds no inventory entry; the existing
minimum-count floor remains satisfied and the pin guard passes.

**Fix:** Decode action manifests as YAML and inspect every decoded `uses` value, rather than
parsing individual lines. If a YAML dependency is not acceptable in this test, make every
unrecognized `uses`-shaped mapping an explicit assertion failure rather than silently dropping it.
Add committed flow-mapping and folded-scalar fixtures containing `actions/checkout@v4`; each must
fail with its source path and the non-immutable-ref diagnostic.

### CR-02: Prefix matching permits local-action paths to escape `.github/actions`

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/test/sigra/planning/phase_234_action_pinning_contract_test.exs:248-254`

**Issue:** The exemption accepts every string beginning `./.github/actions/`, including paths such
as `./.github/actions/../release/bootstrap`. GitHub resolves that local path outside the composite
glob's root, so an unpinned third-party action inside the resolved `action.yml` is neither rejected
as external nor scanned by `composite_action_paths/1`.

**Fix:** Canonicalize local action paths and verify the resolved path is a descendant of the
canonical `.github/actions` root (or reject any local reference containing `..`). Add a release
workflow fixture using `./.github/actions/../release/bootstrap` plus a floating third-party action
in the escaped composite, and require the contract to fail.

### CR-03: The doc-range scanner still skips valid sigils and closes escaped delimiters early

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/scripts/ci/prohibitions/_p18-lib.mjs:27-57,179-180`

**Issue:** `docRangeOpening` recognizes only nine literal delimiters, although Elixir string
sigils can use other delimiters (for example `@doc ~s!.planning/!`). Such a doc range is not
counted at all, so both the zero-history hard fail and R1 miss its planning artifact. For the
recognized delimiters, `includes(closingDelimiter)` also treats an escaped delimiter as the end of
a multiline sigil, allowing a following documentation line to evade the scan.

**Fix:** Parse a general sigil delimiter, map paired delimiters to their closer, and locate only an
unescaped closing delimiter while retaining state across lines. Add fixtures for an `!`-delimited
sigil and a multiline sigil with an escaped delimiter before a `.planning/` token; both must be
observed as dirty. Re-measure and deliberately update R1's baseline if the corrected scanner finds
existing legitimate docs that the current parser omitted.

## Warnings

### WR-01: The library-suite contract excludes valid `library_tests*` job IDs

**Classification:** WARNING

**File:** `/Users/jon/projects/sigra/test/sigra/planning/phase_233_library_economics_contract_test.exs:68-70,160-161`

**Issue:** The stated invariant covers the `library_tests*` universe, but the extractor accepts
only the exact name or a lowercase-underscore suffix. A new `library_tests_canary_2` or
`library_tests-canary` job is a valid workflow job identifier yet is omitted; a second full-suite
owner in that job would not be counted. The body-boundary regex has the same restricted character
set, so widening only the first regex would not fix the parser.

**Fix:** Match the complete permitted job-id suffix (including digits and hyphens) and make the
body boundary use the same job-id grammar. Add a committed two-owner fixture whose second owner is
named `library_tests-canary` (or `library_tests_canary_2`) and assert the distinctive ownership
failure.

---

_Reviewed: 2026-09-19T17:10:55Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
