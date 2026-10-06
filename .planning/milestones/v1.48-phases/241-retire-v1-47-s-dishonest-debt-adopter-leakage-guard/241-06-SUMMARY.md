---
phase: 241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard
plan: 06
subsystem: CI prohibition guards and public-docs leakage controls
tags: [p18, surf-04, ratchet, hexdocs, node-test]
dependency_graph:
  requires: [241-05, 237-docs-attribute-scan, 239-v3-vocabulary]
  provides: [doc-range-hard-fail, independent-r1-r2-r3-ratchet]
  affects: [fast_checks-prohibitions-glob, HexDocs-doc-ranges, packaged-docs]
tech_stack:
  added: [node:test, synchronous-JS-doc-range-scanner, TSV-baselines]
  patterns: [floor-before-property, fail-first-fixtures, independent-monotonic-counters]
key_files:
  created:
    - scripts/ci/prohibitions/p18-doc-range.test.mjs
    - scripts/ci/prohibitions/p18-bookkeeping-ratchet.test.mjs
    - scripts/ci/prohibitions/p18-ratchet-baseline.tsv
    - .planning/phases/241-retire-v1-47-s-dishonest-debt-adopter-leakage-guard/241-06-EVIDENCE.md
  modified:
    - scripts/ci/prohibitions/_p18-lib.mjs
    - .planning/todos/pending/2026-09-17-widened-bookkeeping-definition-for-surf-04-p18.md
decisions:
  - R1, R2, and R3 stay independent because a decrease in one surface cannot offset an increase in another.
  - The Phase-237 Python scanner is ported synchronously to JS; Python remains only an evidence cross-check.
  - D-29 declines case-folding and block-aware matching for v1.48; case-folding costs one R2 line and block matching remains unmeasured.
metrics:
  duration: 24m
  completed: 2026-09-19
  tasks_completed: 3
  files_changed: 10
  plan_head_before: bbe79a82dbf5409db95c4a19e19c3b8d9bc12d38
  commits: 3
actuals:
  tokens: 5935
  tasks: 3
  commits: 3
plan_head_before: bbe79a82dbf5409db95c4a19e19c3b8d9bc12d38
commits: 3
status: complete
---

# Phase 241 Plan 06: p18 docs-range hard fail and independent ratchet Summary

Ported the committed Phase-237 HexDocs doc-range scanner to synchronous JS, blocked new zero-history planning artifacts, and installed independent R1/R2/R3 non-increase ratchets at 337/220/58.

## Completed Work

- Added a synchronous JS port of the doc-attribute walker, preserving Python's heredoc-state semantics and opener/closer token counts.
- Added a floor-before-property doc-range guard with a committed single-violation fixture; the real tree is green and the Python/JS totals agree at 337.
- Added separate R1, R2, and R3 TSV baselines and tests. Every counter uses its own vocabulary and surface; no fused total exists.
- Added three known-bad baseline fixtures. Each produces exactly one `P18 RATCHET REGRESSION Rn` diagnostic.
- Recorded all deterministic results and D-29's declined vocabulary widenings. The original V3 todo remains pending but is marked partially folded.

## Verification

- `mix format --check-formatted test/fixtures/prohibitions/p18-doc-range-leak.ex`
- Doc fixture RED contained `P18 DIRTY SURFACE: doc-range planning artifact`; real-tree doc guard passed 2/2.
- Python and JS scanner totals: `337 == 337`.
- Ratchet baseline test passed R1/R2/R3 at `337 / 220 / 58`; the three fixture matrix was `r1 FAIL 1`, `r2 FAIL 1`, `r3 FAIL 1` with the matching named diagnostic each time.
- `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` — 104 passed.
- `mix test test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs` — 7 passed.
- Confirmed the existing CI glob at `.github/workflows/ci.yml:408`; no `ci.yml` or `mix.exs` change is in this phase diff.

## Decisions Made

- Kept the Python script out of the PR guard path; `fast_checks` has no declared Python setup, while the JS port is synchronous and cross-checked once for parity.
- Preserved three counters instead of one total: R1 is narrower doc-range history, R2 is wide V3 comment-line vocabulary, and R3 is literal `.planning/` packaged-docs occurrences.
- Declined D-29's case-folding widening for v1.48 after measuring a 220→221 R2 increase; declined block-aware matching until it can be implemented and measured without cross-line false positives.

## Deviations from Plan

None — plan executed exactly as written.

## Threat Coverage

T-241-20 through T-241-24 are covered by the zero-at-HEAD hard fail, independent baselines and RED fixtures, visible measured-versus-baseline output, security-rationale standing count, and the JS-only runtime guard path.

## Self-Check: PASSED

All ten plan artifacts exist, and task commits `f1a95dee`, `e24ee4ed`, and `a06e0350` are present in git history.
