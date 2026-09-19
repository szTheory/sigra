---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
reviewed: 2026-09-19T16:03:15Z
depth: standard
files_reviewed: 26
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
  - test/example/test/example_web/live/admin_audit_index_live_test.exs
  - test/fixtures/prohibitions/p10-manifest-stale-entry.tsv
  - test/fixtures/prohibitions/p18-doc-range-leak.ex
  - test/fixtures/prohibitions/p18-planning-path-leak.ex
  - test/fixtures/prohibitions/p18-ratchet-r1-exceeded.tsv
  - test/fixtures/prohibitions/p18-ratchet-r2-exceeded.tsv
  - test/fixtures/prohibitions/p18-ratchet-r3-exceeded.tsv
  - test/fixtures/prohibitions/p18-template-bookkeeping.ex
  - test/fixtures/prohibitions/p21-maintaining-stale-topology.md
  - test/fixtures/prohibitions/phase241-composite-unpinned-bare-uses.yml
  - test/fixtures/prohibitions/phase241-composite-unpinned-dashed-uses.yml
  - test/fixtures/prohibitions/phase241-library-economics-two-owners.yml
  - test/sigra/planning/phase_233_library_economics_contract_test.exs
  - test/sigra/planning/phase_234_action_pinning_contract_test.exs
  - test/support/ci/ex_unit_timing_formatter.ex (deleted)
  - test/support/ci/ex_unit_timing_formatter_test.exs (deleted)
findings:
  critical: 2
  warning: 2
  info: 0
  total: 4
status: issues_found
---

# Phase 241: Code Review Report

**Reviewed:** 2026-09-19T16:03:15Z
**Depth:** standard
**Files Reviewed:** 26
**Status:** issues_found

## Summary

The Phase 241 source changes, including the omitted changed test/deletion files, were reviewed in context. Current-tree p18, p21, and affected ExUnit suites pass, and the committed negative fixtures fail. However, two new supply-chain/leakage guards can be bypassed, and two advertised document-guard properties are narrower than their claims.

## Narrative Findings (AI reviewer)

The findings below are independently confirmed from the current source and its executable fixture paths.

## Critical Issues

### CR-01: The template allowlist suppresses unrelated matches on its allowlisted line

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/scripts/ci/prohibitions/_p18-lib.mjs:246-248`

**Issue:** `scanBookkeeping` makes one hit per line and labels that whole line allowlisted whenever it contains the allowlist anchor. The only permitted SVG line currently contains the anchor at `priv/templates/sigra.gen.oauth/oauth_html.ex:54`; adding another V3 token such as `# Phase 241` to that same line still produces an allowlisted hit and leaves `outsideAllowlist` at zero. This violates the documented pair-keyed disposition and lets new bookkeeping leak through the template guard.

**Fix:** Record each V3 match (including its matched token) rather than only the line, and make the TSV identify the specific permitted match (for example, `373-12`) plus its path/anchor. Mark only that exact match allowlisted; require all other matches on the line to remain dirty. Add a fixture that combines the SVG anchor with a second V3 token and assert that it fails.

### CR-02: Nested composite actions are outside the pinning inventory

**Classification:** BLOCKER

**File:** `/Users/jon/projects/sigra/test/sigra/planning/phase_234_action_pinning_contract_test.exs:11,156-160`

**Issue:** The inventory uses `.github/actions/*/action.yml`, which only discovers one directory level. GitHub Actions permits a workflow to use a local composite action below a nested directory (for example `./.github/actions/release/bootstrap`); its `action.yml` would not be scanned. The existing inventory remains at its 16-entry floor, so a floating third-party action in that nested manifest passes every pinning assertion.

**Fix:** Discover all composite manifests recursively (for example `Path.wildcard(".github/actions/**/action.yml")`) and add a nested composite-action fixture/coverage case with an unpinned `uses:` reference.

## Warnings

### WR-01: The doc-range scanner misses valid lowercase-string sigil documentation

**Classification:** WARNING

**File:** `/Users/jon/projects/sigra/scripts/ci/prohibitions/_p18-lib.mjs:26-27`

**Issue:** Both attribute recognizers accept `~S` but not `~s`. `@doc ~s""" ... """` is valid Elixir and produces documentation, but it is outside the scanner state machine. Since the live tree already has recognized doc ranges, adding a forbidden token in such a range does not cause the p18 doc-range hard fail or R1 to increase.

**Fix:** Accept both string sigils (for example `~[sS]` in both recognizers) and add a fixture containing a normal recognized doc range plus a lowercase-`~s` range with a hard-fail token, proving the latter is detected.

### WR-02: Honest-skip parity cannot detect a stale documentation entry

**Classification:** WARNING

**File:** `/Users/jon/projects/sigra/scripts/ci/prohibitions/p21-honest-skip-parity.test.mjs:60-75`

**Issue:** The guard only proves that every manifest id and step parent occurs somewhere in the section. It never derives a documented honest-skip inventory or checks it against the manifest, so a removed/renamed lane can remain described as an active skip while all current ids still appear and p21 stays green. This conflicts with the manifest's three-way/stale-documentation claim at `.github/ci-skip-manifest.tsv:8-10`.

**Fix:** Give the section a small, explicitly delimited machine-readable list of active honest-skip ids (separate from historical prose), parse it, and assert set equality with the manifest ids plus required step parents. Add a known-bad subject that contains every current id and one extra stale active entry.

---

_Reviewed: 2026-09-19T16:03:15Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
