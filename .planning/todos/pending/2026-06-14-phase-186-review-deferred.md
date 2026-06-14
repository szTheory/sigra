---
created: 2026-06-14T00:00:00.000Z
status: pending
title: harden D-11 parity extractors and minor cleanups (phase 186 deferred review findings)
area: test
files:
  - test/sigra/install/features/admin_test.exs
  - test/example/priv/playwright/tests/admin-theme.spec.ts
  - guides/reference/admin-token-reference.md
source: 186-REVIEW.md (WR-01, WR-02, WR-03, IN-02, IN-03)
---

## Why deferred

Phase 186's code review (`.planning/phases/186-token-foundation-l0/186-REVIEW.md`)
surfaced 8 findings. The verified, clean, low-risk ones were fixed in commit
`7493cc84` (CR-01 OKLab matrix, WR-04 alpha guard, IN-01 doc awk form). The
items below are robustness/maintenance improvements that require a non-trivial
refactor of test extraction logic. The D-11 parity tests **currently pass** and
the brittleness is latent, so refactoring them at phase close carried more
regression risk than value — deferred to a focused pass.

## Findings to address

### WR-01 — D-11 parity extractors use hardcoded line ranges (admin_test.exs:403-423)
`extract_dark_media_props/1` and `extract_explicit_dark_props/1` slice the CSS by
absolute line index (`166..203`, `1511..1542`). A one-line edit above either
block shifts the window; an identical shift in both files can still report
equality while skipping real tokens. Multi-line `--sg-elev-3` continuation values
are dropped from both sides, so a divergence there would be missed. Only the
`--sg-color-brand-strong: #fdba74` membership assertion is a real safety net.
**Fix:** extract by structural delimiters — split on the `@media
(prefers-color-scheme: dark)` opener / `html[data-sg-admin-theme="dark"]
.sg-admin-shell {` anchor and read to matching brace depth; capture full
declarations with `--sg-[\w-]+:\s*([^;]+);` (multi-line safe) rather than
line-by-line `String.contains?("--sg-")`.

### WR-02 — auth_dark_lines uses a fixed 30-line take from first dark match (admin_test.exs:378-383)
`Enum.drop_while(...) |> Enum.take(30)` assumes the three ember tokens fall within
30 lines of the first `.sigra-auth[data-theme="dark"]` block. If that block grows
or an earlier `data-theme="dark"` selector appears, the window silently shifts and
can pass against the wrong block (the `@media` dark block holds the same values,
masking a real explicit-block regression). **Fix:** anchor on the specific
selector and read to its closing brace, or assert token values via a structural
matcher.

### WR-03 — extract_token_value/2 returns first match regardless of context (admin_test.exs:425-438)
Returns the value of the first line `starts_with?(token_name <> ":")`. Light
parity depends on the light value preceding the dark value in source order. If a
dark override is moved above its light definition, the "light parity" check would
silently compare dark vs light. **Fix:** scope the search to the light `:root`
block, or pass an explicit selector/line-range context.

### IN-02 — duplicated readNoticeStyles closure (admin-theme.spec.ts:1383-1391, 1413-1421)
The evaluate-closure is defined identically once per mode loop. **Fix:** hoist a
single `readNoticeStyles(notice)` helper above the loops.

### IN-03 — token-reference completeness claim has no automated guard (admin-token-reference.md:3)
The doc promises "every `--sg-*` custom property in the `:root` layer" (currently
true: 96/96) but nothing stops it rotting when a token is added without a doc row.
**Fix (optional):** a lightweight CI check diffing LHS `--sg-*` defs in
`sigra_admin.css :root` against documented backtick tokens, failing on divergence.
Also consider adding a unit-style guard for `oklabChannels()` itself (e.g.
`contrastRatio("oklab(1 0 0)", "oklab(0 0 0)") ≈ 21:1`) so the CR-01 matrix fix
cannot silently regress.
