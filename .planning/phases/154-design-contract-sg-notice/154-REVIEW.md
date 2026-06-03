---
phase: 154-design-contract-sg-notice
reviewed: 2026-06-03T00:00:00Z
depth: standard
files_reviewed: 3
files_reviewed_list:
  - guides/reference/admin-design-contract.md
  - mix.exs
  - test/example/priv/static/assets/css/app.css
findings:
  critical: 0
  warning: 2
  info: 2
  total: 4
status: issues_found
---

# Phase 154: Code Review Report

**Reviewed:** 2026-06-03T00:00:00Z
**Depth:** standard
**Files Reviewed:** 3
**Status:** issues_found

## Summary

Reviewed three changes: (1) a new governance doc `admin-design-contract.md`, (2) a one-line `mix.exs` ExDoc extras registration, and (3) a ~15-rule `.sg-notice` CSS block added inside `@layer sg-components`.

The CSS block is a faithful, behavior-preserving copy of `.sg-list-row[data-tone]`. I verified all five rules (base + four tones) char-for-char against the source pattern at `app.css:945–967`: tokens match, `color-mix(in oklab, …)` arguments match, and the ring-opacity asymmetry the brief flagged (`ok` ring at 18%, `warn`/`risk`/`info` at 20%) is reproduced identically in `.sg-notice`. No token drift, no malformed `color-mix`, no asymmetry bug introduced. The CSS is clean.

The `mix.exs` change is valid Elixir and the new extra routes to the correct ExDoc `Reference` group via `~r{guides/reference/.?}`. Clean.

The one real defect is in the markdown doc: two `app.css` line-number citations are stale **relative to this same changeset**. The `.sg-notice` insertion (26 lines, above the skeleton/reduced-motion blocks) shifted those blocks down, but the doc still cites the pre-insertion line numbers. Because the doc and the CSS landed in the same change, this is an internal-consistency failure within the changeset.

## Warnings

### WR-01: Stale `app.css` line citations in design contract — broken by this changeset's own CSS insertion

**File:** `guides/reference/admin-design-contract.md:114,124,126`
**Issue:** The doc cites the skeleton CSS at `app.css:1395–1417` and the universal `prefers-reduced-motion` rule at `app.css:1437–1447`. Verified against the pre-change file (`b4109b2d^`), those citations were accurate: `.sg-skeleton` began at line 1395 and the reduced-motion `@media` block at line 1437. This changeset inserts the 26-line `.sg-notice` block at `app.css:969–993`, above both. In the committed file the blocks now live at:
- `.sg-skeleton` → lines 1421–1443 (doc says 1395–1417)
- reduced-motion `@media` block → lines 1463–1473 (doc says 1437–1447)

Three references in the doc point at the wrong lines (lines 114 and 126 cite the reduced-motion rule; line 124 cites skeleton). Within the changeset the governance doc — whose stated purpose is to be "the durable, citable authority" — now mis-cites its own companion CSS file. The brief asked the doc be checked for internal consistency only; this fails that bar because the cited file is part of the same change.
**Fix:** Update the citations to the post-insertion line numbers:
```
- app.css:1395–1417  ->  app.css:1421–1443   (skeleton, line 124)
- app.css:1437–1447  ->  app.css:1463–1473   (reduced-motion rule, lines 114 and 126)
```
Better long-term: cite by selector/region name (e.g. "the universal `prefers-reduced-motion` rule in `@layer` epilogue") instead of absolute line numbers, since any insertion above re-breaks line-based citations. The doc already does this elsewhere (selector names); the line-number citations are the fragile outliers.

### WR-02: `.sg-notice` duplicates `.sg-list-row[data-tone]` verbatim with no shared declaration — silent drift risk

**File:** `test/example/priv/static/assets/css/app.css:971–993` (vs source `945–967`)
**Issue:** `.sg-notice` is a 100% literal copy of the `.sg-list-row` base + four tone rules, including the deliberate `ok`-ring-at-18%-vs-others-at-20% asymmetry. This is acceptable as a transitional state (the comment at line 969–970 and the doc both say Phase 156 will migrate call sites to `<.notice>`), but the two blocks now have no shared source of truth. Any future tweak to one tone (e.g. bumping the `ok` ring to 20% for symmetry, or changing the inset-bar width) must be hand-applied to both or they diverge silently — there is no test asserting the two blocks stay in sync. The brief frames this as behavior-preserving, and it is; the risk is forward maintenance, not current behavior.
**Fix:** Either (a) make `.sg-notice` and `.sg-list-row[data-tone]` share a tone group during the migration window, e.g.:
```css
.sg-list-row[data-tone="ok"],
.sg-notice[data-tone="ok"] {
  background: color-mix(in oklab, var(--sg-color-ok-soft) 62%, var(--sg-color-panel));
  box-shadow: inset 3px 0 0 0 var(--sg-color-ok), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-ok) 18%, transparent);
}
/* …warn/risk/info likewise… */
```
or (b) accept the duplication for the Phase 154→156 window but add a tracked TODO (with the Phase 156 ticket reference) so the duplicate is removed, not left behind after call-site migration. If kept duplicated, document that the two must be edited together.

## Info

### IN-01: `ok`-tone ring opacity (18%) differs from `warn`/`risk`/`info` (20%) — asymmetry copied, not corrected

**File:** `test/example/priv/static/assets/css/app.css:980` (`.sg-notice[data-tone="ok"]`)
**Issue:** The `ok` tone uses `color-mix(… var(--sg-color-ok) 18%, transparent)` for its inset ring, while `warn`/`risk`/`info` use `20%`. This is faithfully copied from the `.sg-list-row` source (line 954 uses 18%, lines 958/962/966 use 20%), so the rename introduces no regression. Flagging only because it is a latent inconsistency in the design tokens that now exists in two places. If intentional (e.g. green reads heavier optically), a one-line comment would prevent a future "fix" that breaks parity; if unintentional, normalize to 20% in both blocks.
**Fix:** No action required for this phase. Decide intent and either comment it or normalize, ideally when WR-02's shared-declaration refactor happens.

### IN-02: Markdown `When NOT to use` for `notice` references `sg-error` class not defined in this CSS file

**File:** `guides/reference/admin-design-contract.md:115`
**Issue:** The `notice` "When NOT to use" cell says "use `sg-error` / Phoenix form error helpers." `sg-error` does not appear anywhere in `app.css`. This may be a host-app/generated class or a Phoenix core_components class, in which case the reference is fine, but a reader cross-checking against the example app's CSS will not find it. Purely a documentation-traceability note; not a correctness issue.
**Fix:** If `sg-error` is a real class elsewhere in the codebase, no change needed. If it is aspirational/generated-only, qualify it (e.g. "the host app's form-error helper") so the contract does not imply a token-layer class that the example CSS does not provide.

---

_Reviewed: 2026-06-03T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
