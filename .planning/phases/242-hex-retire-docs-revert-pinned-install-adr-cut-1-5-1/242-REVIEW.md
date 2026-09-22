---
phase: 242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1
reviewed: 2026-09-22T21:53:18Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - CHANGELOG.md
  - guides/introduction/troubleshooting-install.md
  - test/sigra/planning/phase_242_shift_left_contract_test.exs
findings:
  critical: 0
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 242: Code Review Report

**Reviewed:** 2026-09-22T21:53:18Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

The scoped Unreleased and maintained-line guidance makes the approved truth-boundary statements and contains none of the disallowed positive claims. The targeted contract test passes, but its negative regexes do not cover multiple equivalent, reverse-ordered positive claims. A future documentation change can therefore make a prohibited claim while retaining a green test.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Claim-denial regexes miss reverse-ordered prohibited claims

**File:** `/private/tmp/sigra-242-execution/test/sigra/planning/phase_242_shift_left_contract_test.exs:54-70`

**Issue:** The guards require a subject to precede the positive-result word. Consequently, statements such as `Retired 1.20.0 is no longer selectable`, `HexDocs is current`, `Reverted HexDocs are live`, `We fixed the registry`, `We published 1.5.1`, or `We cut the release 1.5.1` are all positive claims in the prohibited classes but do not match the current patterns. The HexDocs outcome guard also omits the explicitly named `new HexDocs` variant. This weakens the test’s purpose as a regression boundary for unverified external-state claims.

**Fix:** Add reverse-order alternatives and the `new` qualifier for each prohibited claim class, and keep compact positive/negative fixture assertions so the patterns prove both directions. For example:

```elixir
refute Regex.match?(~r/(?:\b(?:current|new)\b.{0,80}\bhexdocs\b|\bhexdocs\b.{0,80}\b(?:current|new)\b)/is, content)
refute Regex.match?(~r/(?:\bhexdocs\b.{0,40}\brevert(?:ed)?\b|\brevert(?:ed)?\b.{0,40}\bhexdocs\b)/is, content)
refute Regex.match?(~r/(?:\b1\.20\.0\b.{0,120}\bretir(?:ed|ement)\b|\bretir(?:ed|ement)\b.{0,120}\b1\.20\.0\b)/is, content)
refute Regex.match?(~r/(?:\b(?:registry|resolver|lockfile)\b.{0,80}\b(?:repair(?:ed)?|fix(?:ed)?)\b|\b(?:repair(?:ed)?|fix(?:ed)?)\b.{0,80}\b(?:registry|resolver|lockfile)\b)/is, content)
refute Regex.match?(~r/(?:\b(?:1\.5\.1|release)\b.{0,80}\b(?:publish(?:ed)?|releas(?:ed|e)|complet(?:ed|ion)|cut)\b|\b(?:publish(?:ed)?|releas(?:ed|e)|complet(?:ed|ion)|cut)\b.{0,80}\b(?:1\.5\.1|release)\b)/is, content)
```

---

_Reviewed: 2026-09-22T21:53:18Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
