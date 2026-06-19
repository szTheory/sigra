---
phase: 186-token-foundation-l0
reviewed: 2026-06-14T00:00:00Z
depth: standard
files_reviewed: 4
files_reviewed_list:
  - guides/reference/admin-quality-ledger.md
  - guides/reference/admin-token-reference.md
  - test/example/priv/playwright/tests/admin-theme.spec.ts
  - test/sigra/install/features/admin_test.exs
findings:
  critical: 1
  warning: 4
  info: 3
  total: 8
status: issues_found
---

# Phase 186: Code Review Report

**Reviewed:** 2026-06-14
**Depth:** standard
**Files Reviewed:** 4
**Status:** issues_found

## Summary

Reviewed the phase-186 token-foundation-L0 change set: a new per-token rationale doc
(`admin-token-reference.md`), an L0 row in `admin-quality-ledger.md`, a new D-11
dark-block parity ExUnit group in `admin_test.exs`, and new tone-on-soft `contrastRatio()`
Playwright assertions in `admin-theme.spec.ts`.

The two documentation files are high quality: `admin-token-reference.md` is **complete**
(all 96 LHS-defined `--sg-*` tokens in `:root` are documented, every documented token
exists in CSS), every sampled value matches the CSS source, and the `~line 207`
cross-reference into `admin-design-contract.md` resolves to the correct dark-AA note. The
ledger row parses correctly under the real monotonic guard.

The test files are functional and currently pass, but they carry one genuine correctness
defect and several robustness liabilities. The most serious is the OKLab→sRGB conversion
matrix in `admin-theme.spec.ts`, whose constants are mathematically wrong — phase 186's new
`contrastRatio()` assertions read `color-mix(in oklab, ...)` notice backgrounds, which is
exactly the serialization path most likely to route through that broken helper on some
Chromium versions, producing false PASS/FAIL contrast results. The D-11 parity tests lean
on hardcoded line ranges that silently mis-extract if either CSS file shifts.

## Critical Issues

### CR-01: OKLab→linear-sRGB conversion matrix constants are wrong (silently corrupts contrast results)

**File:** `test/example/priv/playwright/tests/admin-theme.spec.ts:157-161`
**Issue:** `oklabChannels()` uses an LMS→linear-sRGB matrix whose rows do **not** sum to 1.0,
so a neutral OKLab color (a=b=0) does not map to a neutral RGB. The row sums are `0.5008`,
`1.0004`, `1.0272` instead of `1, 1, 1`. Concretely, `oklab(1 0 0)` (pure white) returns
`[188, 255, 255]` (cyan) instead of `[255, 255, 255]`. The reference Ottosson matrix is:

```
 4.0767416621  -3.3077115913   0.2309699292
-1.2684380046   2.6097574011  -0.3413193965
-0.0041960863  -0.7034186147   1.7076147010
```

Each reference row sums to 1.0. The constants in the file (`2.4885527, -2.4230963, ...`)
appear to be a corrupted/mistyped variant and are not the correct LMS→sRGB coefficients.

This matters for phase 186 specifically: the new tone-on-soft test (line 1366) and the
metric-icon contrast checks read `getComputedStyle(el).backgroundColor` for elements whose
background is `color-mix(in oklab, ...)` (e.g. `.sg-notice[data-tone]` in
`app.css:2757-2793`). Recent Chromium can serialize such computed colors as `oklab(...)`,
routing through this broken matrix and yielding a wrong luminance → a contrast assertion
that passes or fails for the wrong reason. The bug is latent today only because the colors
currently happen to serialize as `rgb()`/`color(srgb ...)`; a Chromium upgrade can flip
that and the gate becomes unreliable rather than failing loudly.

A secondary defect in the same function: percentage-lightness OKLab (`oklab(62.8% 0.1 0.1)`)
is parsed by `/[-\d.]+/g` as `lightness = 62.8` (should be `0.628`), producing clamped
white. The `%` form is a valid CSS serialization and is not handled.

**Fix:** Replace the matrix constants with the reference Ottosson LMS→linear-sRGB matrix and
normalize percentage lightness before the conversion:

```ts
function oklabChannels(value: string): [number, number, number] {
  const raw = value.match(/[-\d.]+%?/g)?.slice(0, 3);
  if (!raw || raw.length < 3) {
    throw new Error(`Expected a CSS oklab color, got ${value}`);
  }
  const [lightness, a, b] = raw.map((token) =>
    token.endsWith("%") ? Number(token.slice(0, -1)) / 100 : Number(token),
  );

  const longL = lightness + 0.3963377774 * a + 0.2158037573 * b;
  const longM = lightness - 0.1055613458 * a - 0.0638541728 * b;
  const longS = lightness - 0.0894841775 * a + 1.291485548 * b;
  const l = longL ** 3;
  const m = longM ** 3;
  const s = longS ** 3;

  return [
    linearSrgbToChannel(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
    linearSrgbToChannel(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
    linearSrgbToChannel(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
  ];
}
```

Add a unit-style assertion (e.g. that `contrastRatio("oklab(1 0 0)", "oklab(0 0 0)")` is
~21:1) so the helper itself is guarded.

## Warnings

### WR-01: D-11 parity tests depend on hardcoded line ranges that can silently mis-extract

**File:** `test/sigra/install/features/admin_test.exs:403-423`
**Issue:** `extract_dark_media_props/1` and `extract_explicit_dark_props/1` slice the CSS by
absolute line index (`166..203` and `1511..1542`). A one-line edit anywhere above those
blocks in either CSS file shifts the window, causing the extractor to read a wrong region.
Because the comparison is `Enum.sort/1` of whatever `--sg-` lines land in the window, an
identical shift in both files can still report equality while skipping real tokens, and the
multi-line `--sg-elev-3` continuation lines (which do not contain `--sg-`) are dropped from
both sides — so a divergence in those continuation values would be missed entirely. The
"Line ranges verified 2026-06-14" comment confirms the fragility (it must be hand-reverified
on every CSS edit). The `--sg-color-brand-strong: #fdba74` membership assertion is the only
real safety net, and it covers exactly one token.

**Fix:** Extract the block by structural delimiters instead of absolute line numbers. For the
`@media (prefers-color-scheme: dark)` block, split on the `@media` opener and take until the
matching brace depth returns to zero; for the explicit block, anchor on
`html[data-sg-admin-theme="dark"] .sg-admin-shell {` … `}`. Capture full declarations
(including multi-line values) by matching `--sg-[\w-]+:\s*([^;]+);` across the captured block
rather than line-by-line `String.contains?("--sg-")`.

### WR-02: `auth_dark_lines` extraction relies on a fixed 30-line take from the first dark match

**File:** `test/sigra/install/features/admin_test.exs:378-383`
**Issue:** The auth-parity assertion does
`Enum.drop_while(not contains "data-theme=\"dark\"") |> Enum.take(30)`. This grabs the first
`.sigra-auth[data-theme="dark"]` block (currently lines 56-85) and assumes the three ember
tokens fall within 30 lines. If the explicit auth dark block grows past 30 lines, or if a
second `data-theme="dark"` selector is introduced earlier, the window silently shifts and the
assertions can pass against the wrong block (the `@media` dark block at lines 92-97 holds the
same values, masking a real explicit-block regression).

**Fix:** Anchor on the specific selector line and read until the closing brace, or assert the
token values directly via a structural matcher rather than a fixed-size line window.

### WR-03: `extract_token_value/2` returns the first matching declaration regardless of context

**File:** `test/sigra/install/features/admin_test.exs:425-438`
**Issue:** `extract_token_value/2` returns the value of the **first** line that
`starts_with?(token_name <> ":")`. The light-parity assertions depend on the light value
appearing before the dark value in source order (true today: `--sg-color-risk` at line 80
light vs 191 dark). If a token's dark override is ever moved above its light definition, or a
new earlier definition is added, the "light parity" check would silently compare a dark value
against a light value. The helper has no scoping to the light `:root` block.

**Fix:** Scope the search to the light `:root` block (slice from `:root {` to its closing
brace before searching), or pass an explicit line-range / selector context to
`extract_token_value/2`.

### WR-04: Manual composite uses `as_ ?? 1`, which does not guard a missing alpha group

**File:** `test/example/priv/playwright/tests/admin-theme.spec.ts:1478-1479`
**Issue:** `const [, rs, gs, bs, as_] = brandSoftRgbaMatch.map(Number); const alpha = as_ ?? 1;`
— when the matched color has no alpha group, regex group 4 is `undefined`, and
`Number(undefined)` is `NaN`. `NaN ?? 1` evaluates to `NaN` (nullish-coalescing does not
catch `NaN`), so `alpha` becomes `NaN` and the composited background becomes `NaN`, silently
breaking the contrast computation. The token is always `rgba(...)` today so it is not
triggered, but the guard does not do what it appears to.

**Fix:** `const alpha = Number.isFinite(as_) ? as_ : 1;`

## Info

### IN-01: Ledger doc's documented awk snippet uses `gensub`, but the real guard uses `gsub`

**File:** `guides/reference/admin-quality-ledger.md:20-27`
**Issue:** The "Parsing Rules" code block documents the extractor as
`item=gensub(/^ +| +$/, "", "g", $2)`, but the actual guard
(`scripts/ci/quality-ledger-monotonic.sh`) uses `item=$2; gsub(/^ +| +$/, "", item)`. They
produce equivalent results, but `gensub` is a GNU-awk-only extension and is not the code that
runs in CI; a contributor copying the documented snippet on macOS/BSD awk would get a
different result than the guard.

**Fix:** Update the doc snippet to mirror the script's `gsub` form (assign `$2`/`$4` to a
variable, then `gsub` in place), so the documented and executed extractors match.

### IN-02: Repeated inline `readNoticeStyles` closure duplicated across light and dark loops

**File:** `test/example/priv/playwright/tests/admin-theme.spec.ts:1383-1391, 1413-1421`
**Issue:** The `readNoticeStyles` evaluate-closure is defined identically twice (once per
mode loop). Minor duplication; extracting a single helper (parameterized by the notice
locator) would reduce drift risk if the selector/inner-element contract changes.

**Fix:** Hoist a single `readNoticeStyles(notice)` helper above the loops and call it in both.

### IN-03: Token-reference doc declares "every `--sg-*` property" — guard the claim

**File:** `guides/reference/admin-token-reference.md:3`
**Issue:** The doc opens by promising "every `--sg-*` custom property in the `sigra_admin.css`
`:root` layer." This is currently **true** (verified: 96/96 tokens documented, no extras),
which is excellent — but it is a maintenance-trap claim with no automated guard, so it will
silently rot the first time a token is added to `:root` without a doc row.

**Fix:** Optionally add a lightweight CI check (mirroring the L0 quality intent) that diffs
LHS `--sg-*` definitions in `sigra_admin.css :root` against documented backtick tokens in
`admin-token-reference.md`, failing if the sets diverge.

---

_Reviewed: 2026-06-14_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
