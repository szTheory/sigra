---
phase: 260-deterministic-output-before-catalog-and-png-park
reviewed: 2026-11-15T23:00:00Z
depth: standard
files_reviewed: 34
files_reviewed_list:
  - .gitattributes
  - .github/workflows/ci.yml
  - MAINTAINING.md
  - mix.exs
  - priv/templates/sigra.install/admin/sigra_admin.css
  - scripts/brand/catalog-diff.sh
  - scripts/ci/admin-acceptance-smoke.sh
  - scripts/ci/admin-css-conformance.sh
  - scripts/ci/admin-css-conformance.test.sh
  - test/example/lib/example_web/live/admin/design_gallery_live.ex
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts
  - test/example/priv/playwright/tests/admin-design.spec.ts
  - test/example/priv/playwright/tests/admin-generated.spec.ts
  - test/example/priv/playwright/tests/demo-showcase.spec.ts
  - test/example/priv/static/assets/css/app.css
  - test/example/priv/static/assets/sigra_admin.css
  - test/example/priv/static/assets/sigra_auth.css
  - test/example/test/example_web/catalog_test.exs
  - test/example/test/example_web/live/admin_design_gallery_catalog_test.exs
  - test/fixtures/brand/css-undefined-classes.txt
  - test/sigra/brand/catalog_diff_test.exs
  - test/sigra/brand/catalog_test.exs
  - test/sigra/install/asset_parity_test.exs
  - test/sigra/install/css_undefined_classes_test.exs
  - test/sigra/install/double_install_test.exs
  - test/sigra/install/features/admin_test.exs
  - test/sigra/planning/phase_198_contributor_dx_contract_test.exs
  - test/sigra/planning/phase_233_library_economics_contract_test.exs
  - test/sigra/planning/phase_260_ci_alias_contract_test.exs
  - test/sigra/planning/phase_260_png_park_contract_test.exs
  - test/support/brand/catalog.ex
  - test/support/brand/css_gap.ex
  - test/support/brand/regen_guard.ex
  - test/support/ci/library_test_partitions.exs
findings:
  critical: 0
  warning: 4
  info: 4
  total: 8
  necessity: 0
status: issues_found
---

# Phase 260: Code Review Report

**Reviewed:** 2026-11-15T23:00:00Z
**Depth:** standard
**Files Reviewed:** 34
**Status:** issues_found

## Summary

Reviewed the Phase 260 source changes: the before-catalog harness (`Sigra.Test.Brand.Catalog`),
its producers (tier 1 in the root suite, tier 2 in the example app, the generated lane in
`admin-acceptance-smoke.sh --test catalog`), `catalog-diff.sh`, the PNG-compare park
(`SIGRA_PNG_COMPARE_SKIP` in `ci.yml` plus three Playwright specs), the two shipped-CSS guards wired
into `mix ci`, and the CSS moved from the example `app.css` into the shipped `sigra_admin.css`.

What was checked and found sound (verified by running it, not by reading summaries):

- The `SIGRA_PNG_COMPARE_SKIP` expression `${{ github.event_name == 'workflow_dispatch' && '0' || '1' }}`
  is correct: `'0'` is a non-empty string and therefore truthy in Actions expressions, so the
  `a && b || c` idiom does not collapse. The park is complete: only the three named steps set the
  switch, all five `toHaveScreenshot` call sites in the three specs are behind it, and
  `admin-coherence-sweep` / `admin-modal-interaction` mention `toHaveScreenshot` in comments only.
- Normalizer determinism: regenerating the 19 tier-1 files in a fresh VM is byte-identical to the
  committed `test/fixtures/brand/before/tier1-library-admin/`. The relative-time formats the library
  emits (`components.ex:1210-1213`) are exactly the ones normalized.
- Privacy: a scan of the whole committed before catalog finds no home path, no `/private/var`, no
  non-`.test` address, no long opaque token; only `203.0.113.x` documentation IPs and
  `localhost:4000`. The added lines of all 34 files contain no personal path or real-looking address.
- `.gitattributes` `-text` is effective (`git check-attr`: `text: unset`; `git ls-files --eol`: 63 files
  `i/lf w/lf`).
- Shell portability: `catalog-diff.sh` uses no bash 4 features, `LC_ALL=C` for `sort`/`comm`, and
  `diff -u -L`, which runs on both BSD and GNU. `admin-css-conformance.sh` fixes the `\d` grep that
  was a silent no-op under GNU grep (CHECK 3 now actually fires on ubuntu).
- Byte parity: template, example and golden copies of `sigra_admin.css` and `sigra_auth.css` are
  identical. All 793 tests in `test/sigra/{brand,planning,templates}` plus `admin_test.exs`, and the
  asset-parity and css-undefined-classes suites, pass locally; both CSS guards and the
  conformance self-test (24 cases) pass.

The defects found are all in guards and the CSS that moved into the shipped file; none is a data-loss
or security issue, so there are no Critical findings.

No necessity findings (`necessity: 0`): the rubric was read; no reachable guard was provable as
defending a state that cannot occur.

## Warnings

### WR-01: Active theme-switch segment loses its keyboard focus indicator

**File:** `priv/templates/sigra.install/admin/sigra_admin.css:581-584` (overridden by `:536-547`)
**Issue:** `.sg-theme-switch__button:focus-visible` (specificity 0,2,0) sets `outline: none` and
`box-shadow: var(--sg-focus-ring)`. The active-segment rule
`html[data-sg-admin-theme-preference="…"] .sg-theme-switch__button[data-theme-value="…"]` (0,3,1) sets
its own `box-shadow` and sits in the same `@layer sg-components`, so it wins on specificity. The
selected segment is the one that keeps focus after a keyboard activation, and it ends up with no
outline and no ring. Verified in headless Chromium against the shipped file: after one Tab, the active
button reports `focusVisible: true`, `outlineStyle: none`,
`boxShadow: rgb(253, 186, 116) 0px 10px 20px -16px` (the drop shadow, not the ring). This is WCAG 2.4.7
(Focus Visible). The rules were moved verbatim from the unlayered example `app.css`, so the defect is
inherited, but moving them into the shipped stylesheet now ships it to every adopter. The new
Playwright assertions only check background and text colour, so nothing would catch it.
**Fix:** Add a focus rule that out-ranks the active rule and keeps the drop shadow, after the active block:
```css
html[data-sg-admin-theme-preference]
  .sg-theme-switch__button[data-theme-value]:focus-visible {
  box-shadow:
    var(--sg-focus-ring),
    0 10px 20px -16px var(--sg-logo-rail-accent);
}
```
(specificity 0,4,1). Add a `toHaveCSS('box-shadow', …)` or screenshot-free computed-style assertion on
the focused active segment in `assertShippedThemeRules`.

### WR-02: The `transition: all` and raw-px guards, now a required gate, are bypassed by ordinary formatting

**File:** `scripts/ci/admin-css-conformance.sh:260` (CHECK 1) and `:312-319` (CHECK 3)
**Issue:** Phase 260 wired this script into `mix ci` (required "Library tests" shard) and rewrote
CHECK 3, but the matchers are literal-text and line-anchored. Reproduced against planted CSS (guard
exits 0 / prints PASS):
- `transition:all .2s;` (no space) and `transition : all 2s` pass CHECK 1 (`grep -n "transition: all"`).
- A multi-line list passes, and this is exactly the shape the shipped file's own formatter emits
  (`sigra_admin.css:793,1124,1198,…` use `transition:` followed by an indented list):
  `transition:\n    all var(--sg-motion-fast) var(--sg-ease);`
- `transition: color 1s, all 2s;` passes.
- CHECK 3 requires the property at the start of the line (`^[0-9]+:[[:space:]]*(padding|…)`), so
  `.b { padding: 13px; }`, `.g { margin: 0 13px; }` and `.i { width: calc(100% - 13px); }` pass;
  only a property on its own line is flagged.
No Prettier check enforces the one-declaration-per-line shape (no `.prettierrc`, no CI step), and the
self-test (`admin-css-conformance.test.sh`) has no negative case for any of these.
**Fix:** Make CHECK 1 whitespace- and newline-tolerant, e.g.
`tr '\n' ' ' < "$CSS_FILE" | grep -oE 'transition[[:space:]]*:[^;}]*(^|[[:space:],:])all([[:space:];,}]|$)'`
(report the match, not a line number), and drop the line-start anchor in CHECK 3 by splitting
declarations on `;`/`{` before filtering. Add the five inputs above as planted controls in the
self-test. If the guard is meant to stay line-oriented, enforce the shape with `prettier --check`
instead.

### WR-03: Committed before-catalog integrity and privacy checks pass vacuously if `MANIFEST.json` is removed

**File:** `test/sigra/brand/catalog_test.exs:359-367` and `:656-667`
**Issue:** Both "committed before catalog" tests branch on `Catalog.committed_status()` and return
`:ok` on `:absent`. That branch existed while the baseline was not yet captured; it is now committed
(63 files), so the branch only matters if `MANIFEST.json` disappears. Deleting or renaming that one
file turns the hash check (`verify_manifest/1`) and the privacy scan of the lane files into no-ops.
Nothing else catches it: `catalog_diff_test.exs:272-278` only asserts more than one file exists under
the directory, and the lane files can then be edited freely. For a baseline whose stated protection is
"by hash" this is a false-passing guard. (`write!(:before)` can also be re-run once the manifest is
gone, gated only by the lib/priv identity check.)
**Fix:** Now that the baseline is committed, make absence a failure:
```elixir
case Catalog.committed_status() do
  :absent -> flunk("test/fixtures/brand/before/MANIFEST.json is missing; the committed baseline is immutable")
  {:present, diff} -> assert diff == [], "committed before catalog drifted: #{inspect(diff)}"
end
```
and the same in the privacy test.

### WR-04: The CSS guards' self-test twins, including the new theme-scope and GNU-portability cases, never run in CI

**File:** `scripts/ci/admin-css-conformance.test.sh` (Tests H-K, `:239-517`); `mix.exs:151-157`;
`test/sigra/planning/phase_260_ci_alias_contract_test.exs:17-20,73-75`
**Issue:** The phase deliberately keeps the `.test.sh` twins out of the `ci` alias (Test G fails on a
dirty tracked tree) and the contract test forbids adding them. But no other caller exists:
`grep -rn "admin-css-conformance.test" .github scripts mix.exs` finds none outside the file itself,
and `fast_checks` runs about twenty sibling `*.test.sh` scripts but not this one or
`admin-token-completeness.test.sh`. So the planted-failure controls for the new awk scope parser
(Tests H-J) and for the `\d`-to-`[0-9]` fix (Test K, whose own comment says it is "only meaningful when
also run under a GNU userland") are executed only by hand on a developer's mac. The required gate runs
the guard but never proves on ubuntu that it can fail, which is the property the rest of this phase
(planted controls everywhere) says it cares about.
**Fix:** Add `bash scripts/ci/admin-css-conformance.test.sh` and
`bash scripts/ci/admin-token-completeness.test.sh` as `fast_checks` steps next to the other twins (CI
checkouts are clean, so Test G passes there), and extend `phase_260_ci_alias_contract_test.exs` to pin
that step so the twin cannot be orphaned.

## Info

### IN-01: Tier-1 catalog copies private LiveView option lists with nothing tying them to the source

**File:** `test/support/brand/catalog.ex:111-137`
**Issue:** `@quick_filter_keys`, `@more_filter_keys`, `@light_color_fields`, `@dark_color_fields` and
`@branding_form_keys` are hand copies of attributes private to `UsersIndexLive` and `BrandingLive`
(`lib/sigra/admin/live/users_index_live.ex:14-15`, `branding_live.ex:14,23`). They match today, but if a
LiveView changes its own list, the Phase 262 "after" catalog will not show the change, because it
renders from the copy. The comment acknowledges this; no test enforces it.
**Fix:** Source the lists from the LiveView's mount assigns (call `mount/3` with a stub socket, or
expose `@doc false` accessors), or add a test that renders the LiveView through its own assigns and
compares one control field.

### IN-02: `double_install_test.exs` raw-delta allow-list is wider than its stated claim

**File:** `test/sigra/install/double_install_test.exs:41,141-142` (claim at `:14-15`)
**Issue:** The moduledoc says the raw difference is "confined to migration filenames and `config/*.exs`
salt lines". The check allows any difference at all under `config/` and `priv/repo/migrations/`
(prefix match). It is backstopped by the normalized-tree leg, which would fail on a non-salt content
difference, so nothing is hidden today, but the raw leg itself would accept a changed migration body or
a new nondeterministic config key.
**Fix:** Reword the moduledoc to say the raw leg only confines differences to those directories and the
normalized leg proves the content, or narrow the allow-list to `~r{^priv/repo/migrations/\d{14}_}` and
`config/*.exs` files.

### IN-03: `admin-acceptance-smoke.sh --help` prints script code, now including the default Cloak key

**File:** `scripts/ci/admin-acceptance-smoke.sh:77`
**Issue:** `--help` runs `sed -n '2,48p'` on the script itself. The header comment is now 24 lines
(this phase added seven), so the fixed range ends at line 48 (`export CLOAK_KEY=…`) and prints `set -euo
pipefail`, the variable defaults and the test-only key instead of stopping at the header. The range was
already past the header before this phase; the phase made the spill larger.
**Fix:** Print only the leading comment block, e.g. `awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"`.

### IN-04: The `:after` catalog writer will delete lane directories in whatever `:out_dir` it is given

**File:** `test/support/brand/catalog.ex:908-917`
**Issue:** `write_after!/2` runs `File.rm_rf!(Path.join(dir, lane))` for the four lane directories and has
no refusal when `dir` already holds a `MANIFEST.json` (the `:before` writer refuses in the converse
case at `:924`). Only an explicit `out_dir:` option (not the env var) can point it at
`test/fixtures/brand/before`, so this needs a caller mistake, but the result would be the committed
baseline's lanes removed while its manifest stays.
**Fix:** In `write_after!/2`, raise when `File.exists?(Path.join(dir, @manifest_file))`.

---

_Reviewed: 2026-11-15T23:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
